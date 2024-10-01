#pragma once

#import <CoreML/CoreML.h>
#import <CoreVideo/CoreVideo.h>
#import <Foundation/Foundation.h>

@interface ClassifierInputProvider : NSObject <MLFeatureProvider>
+ (ClassifierInputProvider *)fromImage:(CVPixelBufferRef)image;

@property(readwrite, nonatomic, nonnull) CVPixelBufferRef image;

@property(readonly, nonatomic, nonnull) NSSet<NSString *> *featureNames;
- (nullable MLFeatureValue *)featureValueForName:(NSString *)featureName;
@end

@interface ClassifierOutputProvider : NSObject <MLFeatureProvider>
+ (ClassifierOutputProvider *)fromProvider:
    (NSObject<MLFeatureProvider> *)provider;

@property(readwrite, nonatomic, retain) NSObject<MLFeatureProvider> *provider;

@property(readonly, nonatomic, nonnull) NSString *classLabel;
@property(readonly, nonatomic, nonnull)
    NSDictionary<NSString *, NSNumber *> *classLabel_probs;

@property(readonly, nonatomic, nonnull) NSSet<NSString *> *featureNames;
- (nullable MLFeatureValue *)featureValueForName:(NSString *)featureName;
@end