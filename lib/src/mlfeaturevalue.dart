
import 'dart:ffi';

import 'package:mlruntime/binding/coreml.dart' as binding;
import 'package:objective_c/objective_c.dart' as objc;

class MLFeatureValue {
  final binding.MLFeatureValue _value;
  MLFeatureValue._(this._value);

  static MLFeatureValue initFromInt(int val) {
    return MLFeatureValue._(binding.MLFeatureValue.featureValueWithInt64_(val));
  }

  static MLFeatureValue initFromDouble(double val) {
    return MLFeatureValue._(binding.MLFeatureValue.featureValueWithDouble_(val));
  }

  static MLFeatureValue initFromString(String val) {
    return MLFeatureValue._(
        binding.MLFeatureValue.featureValueWithString_(val.toNSString()));
  }

  static MLFeatureValue initFromMultiArray(binding.MLMultiArray val) {
    return MLFeatureValue._(
        binding.MLFeatureValue.featureValueWithMultiArray_(val));
  }

  static MLFeatureValue? initFromCGImage(Pointer<binding.CGImage> val, int width,
      int height, int pixelFormatType, objc.NSDictionary options) {
    var result = binding.MLFeatureValue
        .featureValueWithCGImage_pixelsWide_pixelsHigh_pixelFormatType_options_error_(
            val, width, height, pixelFormatType, options, nullptr);
    if (result == null) {
      return null;
    }
    return MLFeatureValue._(result);
  }

  binding.MLFeatureType get type {
    return _value.type;
  }

  get intValue {
    return _value.int64Value;
  }

  get doubleValue {
    return _value.doubleValue;
  }

  get stringValue {
    return _value.stringValue.toString();
  }

  get imageBufferValue {
    return _value.imageBufferValue;
  }

  get multiArrayValue {
    return _value.multiArrayValue;
  }
}
