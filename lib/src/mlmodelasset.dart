import 'dart:ffi';

import 'package:flutter/services.dart';
import 'package:mlruntime/binding/coreml.dart' as binding;
import 'package:objective_c/objective_c.dart';

class MLModelAsset {
  binding.MLModelAsset asset;
  MLModelAsset._(this.asset);

  static Future<MLModelAsset?> loadModelAssetFromBundle(
      String bundleKey) async {
    var data = await rootBundle.load(bundleKey);
    return MLModelAsset.loadModelAsset(data);
  }

  static MLModelAsset? loadModelAsset(ByteData data) {
    var nsdata = data.buffer.asUint8List(data.offsetInBytes).toNSData();
    var asset = binding.MLModelAsset.modelAssetWithSpecificationData_error_(
        nsdata, nullptr);
    if (asset != null) {
      return MLModelAsset._(asset);
    } else {
      return null;
    }
  }
}
