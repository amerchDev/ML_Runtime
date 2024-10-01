#pragma once

#import <CoreML/CoreML.h>
#import <CoreVideo/CoreVideo.h>
#import <Foundation/Foundation.h>

@interface DetectorNMSInputProvider : NSObject <MLFeatureProvider>
+ (DetectorNMSInputProvider *)fromImage:(CVPixelBufferRef)image;

+ (DetectorNMSInputProvider *)fromImage:(CVPixelBufferRef)image
                      iouThreshold:(double)iouThreshold
               confidenceThreshold:(double)confidenceThreshold;

@property(readwrite, nonatomic, nonnull) CVPixelBufferRef image;
@property(readwrite, nonatomic, retain) NSNumber *iouThreshold;
@property(readwrite, nonatomic, retain) NSNumber *confidenceThreshold;

@property(readonly, nonatomic, nonnull) NSSet<NSString *> *featureNames;
- (nullable MLFeatureValue *)featureValueForName:(NSString *)featureName;
@end

@interface DetectorNMSOutputProvider : NSObject <MLFeatureProvider>
+ (DetectorNMSOutputProvider *)fromProvider:(NSObject<MLFeatureProvider> *)provider;

@property(readwrite, nonatomic, retain) NSObject<MLFeatureProvider> *provider;

@property(readonly, nonatomic, nonnull) MLMultiArray *confidence;
@property(readonly, nonatomic, nonnull) MLMultiArray *coordinates;

@property(readonly, nonatomic, nonnull) NSSet<NSString *> *featureNames;
- (nullable MLFeatureValue *)featureValueForName:(NSString *)featureName;
@end