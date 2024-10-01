#import "Classifier.h"
#include <CoreML/CoreML.h>
#include <Foundation/Foundation.h>

@implementation ClassifierInputProvider
@synthesize image;
+ (ClassifierInputProvider *)fromImage:(CVPixelBufferRef)image {
  ClassifierInputProvider *ptr = [[ClassifierInputProvider alloc] init];
  ptr.image = image;
  return ptr;
}

- (NSSet<NSString *> *)featureNames {
  NSArray<NSString *> *names = @[ @"image", @"data" ];
  return [NSSet setWithArray:names];
}

- (nullable MLFeatureValue *)featureValueForName:(NSString *)featureName {
  if ([featureName isEqualToString:@"image"]) {
    return [MLFeatureValue featureValueWithPixelBuffer:image];
  } else if ([featureName isEqualToString:@"data"]) {
    return [MLFeatureValue featureValueWithPixelBuffer:image];
  }
  return nil;
}
@end

@implementation ClassifierOutputProvider
@synthesize provider;

+ (ClassifierOutputProvider *)fromProvider:
    (NSObject<MLFeatureProvider> *)provider {
  ClassifierOutputProvider *this = [[ClassifierOutputProvider alloc] init];
  this.provider = provider;
  return this;
}

- (NSString *)classLabel {
  return [[self featureValueForName:@"classLabel"] stringValue];
}
- (NSDictionary<NSString *, NSNumber *> *)classLabel_probs {
  MLFeatureValue *value;
  if ((value = [provider featureValueForName:@"classLabel_probs"])) {
    return [value dictionaryValue];
  } else if ((value = [provider featureValueForName:@"loss"])) {
    return [value dictionaryValue];
  }
  return NULL;
}

- (NSSet<NSString *> *)featureNames {
  return [provider featureNames];
}
- (nullable MLFeatureValue *)featureValueForName:(NSString *)featureName {
  return [provider featureValueForName:featureName];
}
@end