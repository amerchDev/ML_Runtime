#import "DetectorNMS.h"
#include <CoreML/CoreML.h>
#import <CoreML/MLFeatureValue.h>
#include <CoreVideo/CoreVideo.h>
#import <Foundation/Foundation.h>
#include <objc/NSObject.h>
#include <stdio.h>

@implementation DetectorNMSInputProvider
@synthesize image, iouThreshold, confidenceThreshold;
+ (DetectorNMSInputProvider *)fromImage:(CVPixelBufferRef)image {
  DetectorNMSInputProvider *ptr = [[DetectorNMSInputProvider alloc] init];
  ptr.image = image;
  return ptr;
}

+ (DetectorNMSInputProvider *)fromImage:(CVPixelBufferRef)image
                      iouThreshold:(double)iouThreshold
               confidenceThreshold:(double)confidenceThreshold {
  DetectorNMSInputProvider *ptr = [DetectorNMSInputProvider fromImage:image];
  ptr.iouThreshold = [NSNumber numberWithDouble:iouThreshold];
  ptr.confidenceThreshold = [NSNumber numberWithDouble:confidenceThreshold];
  return ptr;
}

- (NSSet<NSString *> *)featureNames {
  NSArray<NSString *> *names =
      @[ @"image", @"iouThreshold", @"confidenceThreshold" ];
  return [NSSet setWithArray:names];
}

- (nullable MLFeatureValue *)featureValueForName:(NSString *)featureName {
  if ([featureName isEqualToString:@"image"]) {
    return [MLFeatureValue featureValueWithPixelBuffer:image];
  } else if ([featureName isEqualToString:@"iouThreshold"]) {
    return iouThreshold == nil
               ? nil
               : [MLFeatureValue
                     featureValueWithDouble:iouThreshold.doubleValue];
  } else if ([featureName isEqualToString:@"confidenceThreshold"]) {
    return confidenceThreshold == nil
               ? nil
               : [MLFeatureValue
                     featureValueWithDouble:confidenceThreshold.doubleValue];
  }
  return nil;
}
@end

@implementation DetectorNMSOutputProvider
@synthesize provider;

+ (DetectorNMSOutputProvider *)fromProvider:(NSObject<MLFeatureProvider> *)provider {
  DetectorNMSOutputProvider *this = [[DetectorNMSOutputProvider alloc] init];
  this.provider = provider;
  return this;
}

- (MLMultiArray *)confidence {
  return [[self featureValueForName:@"confidence"] multiArrayValue];
}
- (MLMultiArray *)coordinates {
  return [[self featureValueForName:@"coordinates"] multiArrayValue];
}

- (NSSet<NSString *> *)featureNames {
  return [provider featureNames];
}
- (nullable MLFeatureValue *)featureValueForName:(NSString *)featureName {
  return [provider featureValueForName:featureName];
}
@end