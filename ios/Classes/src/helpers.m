#include "helpers.h"
#include <CoreFoundation/CoreFoundation.h>
#import <CoreVideo/CoreVideo.h>
#include <Metal/Metal.h>
#include <simd/conversion.h>
#include <simd/vector_types.h>

#define PUSH_SUPRESS_SUPER_WARNING                                             \
  _Pragma("clang diagnostics push")                                            \
      _Pragma("clang diagnostic ignored \"-Wobjc-missing-super-calls\"")
#define POP_SUPRESS_SUPER_WARNING _Pragma("clang diagnostics pop")

static NSDictionary *metalCompatiblityAttributes(void) {
  NSDictionary *attributes = @{
    (NSString *)kCVPixelBufferMetalCompatibilityKey : @true,
    (NSString *)kCVPixelBufferOpenGLCompatibilityKey : @true,
    (NSString *)kCVPixelBufferIOSurfacePropertiesKey : @{
#if TARGET_OS_OSX
      (NSString *)kCVPixelBufferIOSurfaceOpenGLTextureCompatibilityKey : @true,
      (NSString *)kCVPixelBufferIOSurfaceOpenGLFBOCompatibilityKey : @true,
#elif TARGET_OS_IPHONE
      (NSString *)
      kCVPixelBufferIOSurfaceOpenGLESTextureCompatibilityKey : @true,
      (NSString *)kCVPixelBufferIOSurfaceOpenGLESFBOCompatibilityKey : @true,
#endif
      (NSString *)kCVPixelBufferIOSurfaceCoreAnimationCompatibilityKey : @true
    }
  };
  return attributes;
}

@implementation BitmapImage
@synthesize bitmap;
- (instancetype)initWithWidth:(size_t)width height:(size_t)height {
  CFDictionaryRef dict =
      (__bridge CFDictionaryRef)metalCompatiblityAttributes();
  if (self = [super init]) {
    CVPixelBufferCreate(NULL, width, height, kCVPixelFormatType_32BGRA, dict,
                        &bitmap);
  }
  return self;
}

PUSH_SUPRESS_SUPER_WARNING
- (void)dealloc {
  CVPixelBufferRelease(bitmap);
}
POP_SUPRESS_SUPER_WARNING

- (size_t)width {
  return CVPixelBufferGetWidth(bitmap);
}

- (size_t)height {
  return CVPixelBufferGetHeight(bitmap);
}

- (OSType)pixelFormat {
  return CVPixelBufferGetPixelFormatType(bitmap);
}

- (size_t)bytesPerRow {
  return CVPixelBufferGetBytesPerRow(bitmap);
}

- (uint8_t *)data {
  return CVPixelBufferGetBaseAddress(bitmap);
}

- (void)lock:(bool)readOnly {
  CVPixelBufferLockBaseAddress(bitmap,
                               readOnly ? kCVPixelBufferLock_ReadOnly : 0);
}
- (void)unlock:(bool)readOnly {
  CVPixelBufferUnlockBaseAddress(bitmap,
                                 readOnly ? kCVPixelBufferLock_ReadOnly : 0);
}

- (void)blit:(BitmapImage *)dest handler:(void (^)(void))handler {
  BitmapProcessor *processor = [[BitmapProcessor alloc] init];
  [processor blitFrom:self to:dest handler:handler];
}

@end

@implementation BitmapProcessor
id<MTLDevice> device;
id<MTLCommandQueue> commandQueue;
CVMetalTextureCacheRef textureCache;

- (instancetype)init {
  if (self = [super init]) {
    device = MTLCreateSystemDefaultDevice();
    commandQueue = [device newCommandQueue];
    textureCache = NULL;
    CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil,
                              &textureCache);
  }
  return self;
}

PUSH_SUPRESS_SUPER_WARNING
- (void)dealloc {
  if (textureCache) {
    CFRelease(textureCache);
  }
}
POP_SUPRESS_SUPER_WARNING

typedef struct {
  CVMetalTextureRef cvtexture;
  id<MTLTexture> texture;
} TextureImageInfo;

- (id<MTLTexture> _Nullable)createTextureFromImage:(CVPixelBufferRef)pixelBuffer
                                            format:(MTLPixelFormat)pixelFormat
                                             plane:(size_t)plane
                                              info:(TextureImageInfo *_Nonnull)
                                                       info {
  size_t width = CVPixelBufferGetWidthOfPlane(pixelBuffer, plane);
  size_t height = CVPixelBufferGetHeightOfPlane(pixelBuffer, plane);
  CVReturn status = CVMetalTextureCacheCreateTextureFromImage(
      NULL, textureCache, pixelBuffer, nil, pixelFormat, width, height, plane,
      &info->cvtexture);
  if (status == kCVReturnSuccess) {
    info->texture = CVMetalTextureGetTexture(info->cvtexture);
  }
  return info->texture;
}

- (id<MTLTexture> _Nullable)createTextureWithShape:(MTLSize)size
                                            format:(MTLPixelFormat)format {

  MTLTextureDescriptor *tmpTexDescriptor = [[MTLTextureDescriptor alloc] init];
  tmpTexDescriptor.width = size.width;
  tmpTexDescriptor.height = size.height;
  tmpTexDescriptor.depth = size.depth;
  tmpTexDescriptor.pixelFormat = MTLPixelFormatBGRA8Unorm;
  tmpTexDescriptor.usage =
      MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite;
  id<MTLTexture> texture = [device newTextureWithDescriptor:tmpTexDescriptor];

  return texture;
}

- (BitmapProcessCopyScale)copyFrom:(BitmapImage *_Nonnull)src
                                to:(BitmapImage *_Nonnull)dst
                              mode:(BitmapProcessorCopyMode)mode
                           handler:(void (^_Nonnull)(void))handler {
  TextureImageInfo srcTexInfo, dstTexInfo;
  id<MTLTexture> srcTexture, dstTexture;
  srcTexture = [self createTextureFromImage:src.bitmap
                                     format:MTLPixelFormatBGRA8Unorm
                                      plane:0
                                       info:&srcTexInfo];

  dstTexture = [self createTextureFromImage:dst.bitmap
                                     format:MTLPixelFormatBGRA8Unorm
                                      plane:0
                                       info:&dstTexInfo];
  id<MTLCommandBuffer> commandBuffer = [commandQueue commandBuffer];
  [commandBuffer
      addCompletedHandler:^(id<MTLCommandBuffer> _Nonnull cmdbuffer) {
        handler();
        CFRelease(srcTexInfo.cvtexture);
        CFRelease(dstTexInfo.cvtexture);
      }];
  BitmapProcessCopyScale scale_;
  switch (mode) {
  case scale: {
    const MPSScaleTransform scaleTransform = {
        .scaleX = (double)([dst width]) / (double)([src width]),
        .scaleY = (double)([dst height]) / (double)([src height]),
        .translateX = 0.0,
        .translateY = 0.0,
    };
    scale_.scaleX = scaleTransform.scaleX;
    scale_.scaleY = scaleTransform.scaleY;

    MPSImageBilinearScale *scaler =
        [[MPSImageBilinearScale alloc] initWithDevice:device];
    scaler.scaleTransform = &scaleTransform;
    [scaler encodeToCommandBuffer:commandBuffer
                    sourceTexture:srcTexture
               destinationTexture:dstTexture];
    [commandBuffer commit];

  } break;
  case scaleFit: {
    id<MTLCommandBuffer> commandBuffer = [commandQueue commandBuffer];
    const double scale = ([src width] > [src height])
                             ? (double)[dst width] / (double)[src width]
                             : (double)[dst height] / (double)[src height];
    scale_.scaleX = scale;
    scale_.scaleY = scale;
    const MPSScaleTransform scaleTransform = {
        .scaleX = scale,
        .scaleY = scale,
        .translateX = 0.0,
        .translateY = 0.0,
    };

    id<MTLTexture> tmpTexture =
        [self createTextureWithShape:MTLSizeMake(scale * [src width],
                                                 scale * [src height], 1)
                              format:MTLPixelFormatBGRA8Unorm];

    MPSImageBilinearScale *scaler =
        [[MPSImageBilinearScale alloc] initWithDevice:device];
    scaler.scaleTransform = &scaleTransform;
    [scaler encodeToCommandBuffer:commandBuffer
                    sourceTexture:srcTexture
               destinationTexture:tmpTexture];

    const simd_uchar4 color = {127, 127, 127, 255};
    NSMutableData *data = [NSMutableData
        dataWithLength:(dstTexture.width * dstTexture.height * sizeof(color))];
    simd_uchar4 *dataptr = [data mutableBytes];
    for (size_t i = 0; i < data.length / sizeof(color); i++) {
      dataptr[i] = color;
    }
      MTLRegion fillRegion;
      
      if (tmpTexture.width > tmpTexture.height) {
          fillRegion = MTLRegionMake2D(0, tmpTexture.height, dstTexture.width, dstTexture.height - tmpTexture.height);
      } else {
          fillRegion = MTLRegionMake2D(tmpTexture.width, 0, dstTexture.width - tmpTexture.width, dstTexture.height);
      }
    [dstTexture
        replaceRegion:fillRegion
     mipmapLevel:0
                slice:0
            withBytes:[data bytes]
          bytesPerRow:dstTexture.width * sizeof(color)
        bytesPerImage:0];
    id<MTLBlitCommandEncoder> blitCommandEncoder =
        [commandBuffer blitCommandEncoder];
    MTLRegion sourceRegion =
        MTLRegionMake2D(0, 0, [tmpTexture width], [tmpTexture height]);
    [blitCommandEncoder copyFromTexture:tmpTexture
                            sourceSlice:0
                            sourceLevel:0
                           sourceOrigin:sourceRegion.origin
                             sourceSize:sourceRegion.size
                              toTexture:dstTexture
                       destinationSlice:0
                       destinationLevel:0
                      destinationOrigin:MTLOriginMake(0, 0, 0)];
    [blitCommandEncoder endEncoding];
    [commandBuffer commit];
    CVMetalTextureCacheFlush(textureCache, 0);
  } break;
  }

  return scale_;
}

- (void)blitFrom:(BitmapImage *_Nonnull)src
              to:(BitmapImage *_Nonnull)dst
         handler:(void (^_Nonnull)(void))handler {
  TextureImageInfo srcTexInfo, dstTexInfo;

  id<MTLTexture> srcTexture, dstTexture;
  srcTexture = [self createTextureFromImage:src.bitmap
                                     format:MTLPixelFormatBGRA8Unorm
                                      plane:0
                                       info:&srcTexInfo];
  dstTexture = [self createTextureFromImage:dst.bitmap
                                     format:MTLPixelFormatBGRA8Unorm
                                      plane:0
                                       info:&dstTexInfo];

  id<MTLCommandBuffer> commandBuffer = [commandQueue commandBuffer];
  id<MTLBlitCommandEncoder> blitCommandEncoder =
      [commandBuffer blitCommandEncoder];
  MTLRegion sourceRegion =
      MTLRegionMake3D(0, 0, 0, [src width], [src height], 1);
  [blitCommandEncoder copyFromTexture:srcTexture
                          sourceSlice:0
                          sourceLevel:0
                         sourceOrigin:sourceRegion.origin
                           sourceSize:sourceRegion.size
                            toTexture:dstTexture
                     destinationSlice:0
                     destinationLevel:0
                    destinationOrigin:MTLOriginMake(0, 0, 0)];
  [blitCommandEncoder endEncoding];

  [commandBuffer
      addCompletedHandler:^(id<MTLCommandBuffer> _Nonnull cmdbuffer) {
        handler();
        CFRelease(srcTexInfo.cvtexture);
        CFRelease(dstTexInfo.cvtexture);
      }];
  [commandBuffer commit];
}

- (void)scaleFrom:(BitmapImage *_Nonnull)src
               to:(BitmapImage *_Nonnull)dst
          handler:(void (^_Nonnull)(void))handler {
  TextureImageInfo srcTexInfo, dstTexInfo;

  id<MTLTexture> srcTexture, dstTexture;
  srcTexture = [self createTextureFromImage:src.bitmap
                                     format:MTLPixelFormatBGRA8Unorm
                                      plane:0
                                       info:&srcTexInfo];

  dstTexture = [self createTextureFromImage:dst.bitmap
                                     format:MTLPixelFormatBGRA8Unorm
                                      plane:0
                                       info:&dstTexInfo];

  id<MTLCommandBuffer> commandBuffer = [commandQueue commandBuffer];

  const MPSScaleTransform scaleTransform = {
      .scaleX = (double)([dst width]) / (double)([src width]),
      .scaleY = (double)([dst height]) / (double)([src height]),
      .translateX = 0.0,
      .translateY = 0.0,
  };

  MPSImageBilinearScale *scaler =
      [[MPSImageBilinearScale alloc] initWithDevice:device];
  scaler.scaleTransform = &scaleTransform;
  [scaler encodeToCommandBuffer:commandBuffer
                  sourceTexture:srcTexture
             destinationTexture:dstTexture];

  [commandBuffer
      addCompletedHandler:^(id<MTLCommandBuffer> _Nonnull cmdbuffer) {
        handler();
        CFRelease(srcTexInfo.cvtexture);
        CFRelease(dstTexInfo.cvtexture);
      }];
  [commandBuffer commit];
}

@end
