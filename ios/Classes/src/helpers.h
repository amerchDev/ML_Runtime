#ifndef OBJECTIVE_C_CVPIXELBUFFER_HELPER
#define OBJECTIVE_C_CVPIXELBUFFER_HELPER

#import <CoreVideo/CoreVideo.h>
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <MetalPerformanceShaders/MetalPerformanceShaders.h>

// BGRA Bitmap
@interface BitmapImage : NSObject
@property(readonly, nonatomic, nonnull) CVPixelBufferRef bitmap;
@property(readonly, nonatomic) size_t width;
@property(readonly, nonatomic) size_t height;
@property(readonly, nonatomic) OSType pixelFormat;
@property(readonly, nonatomic) size_t bytesPerRow;

@property(readonly, nonatomic) uint8_t *data;

- (instancetype _Nonnull)initWithWidth:(size_t)width height:(size_t)height;
- (void)dealloc;
- (void)lock:(bool)readOnly;
- (void)unlock:(bool)readOnly;
- (void)blit:(BitmapImage *_Nonnull)dest
     handler:(void (^_Nonnull)(void))handler;
@end

typedef enum {
  scale,
  scaleFit,
} BitmapProcessorCopyMode;

typedef struct {
  double scaleX;
  double scaleY;
} BitmapProcessCopyScale;

@interface BitmapProcessor : NSObject
- (instancetype _Nonnull)init;
- (BitmapProcessCopyScale)copyFrom:(BitmapImage *_Nonnull)src
                                to:(BitmapImage *_Nonnull)dst
                              mode:(BitmapProcessorCopyMode)mode
                           handler:(void (^_Nonnull)(void))handler;
- (void)blitFrom:(BitmapImage *_Nonnull)src
              to:(BitmapImage *_Nonnull)dst
         handler:(void (^_Nonnull)(void))handler;
- (void)scaleFrom:(BitmapImage *_Nonnull)src
               to:(BitmapImage *_Nonnull)dst
          handler:(void (^_Nonnull)(void))handler;
@end

#endif
