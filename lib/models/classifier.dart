import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:mlruntime/binding/coreml.dart' as binding;
import 'package:mlruntime/src/image.dart';
import 'package:mlruntime/src/mlcomputeunits.dart';
import 'package:mlruntime/src/mlmodel.dart';
import 'package:mlruntime/src/mlmodelconfiguration.dart';
import 'package:objective_c/objective_c.dart';

export 'package:mlruntime/binding/coreml.dart'
    show ClassifierInputProvider, ClassifierOutputProvider;

final class Classifier {
  final MLModel model;
  Classifier._(this.model);

  static Future<Classifier?> load(AssetBundle bundle, String assetKey,
      {MLComputeUnits computeUnits = MLComputeUnits.MLComputeUnitsAll}) async {
    final config = MLModelConfiguration(computeUnits: computeUnits);
    final model = await MLModel.fromBundle(bundle, assetKey, config);
    if (model != null) {
      return Classifier._(model);
    }
    return null;
  }

  static Future<Classifier?> loadFile(File file,
      {MLComputeUnits computeUnits = MLComputeUnits.MLComputeUnitsAll}) async {
    final config = MLModelConfiguration(computeUnits: computeUnits);
    final model = await MLModel.fromFile(file, config);
    if (model != null) {
      return Classifier._(model);
    }
    return null;
  }

  binding.MLFeatureDescription get inputFeatureDescription {
    var descriptionDict = model.native.modelDescription.inputDescriptionsByName;
    var keys = descriptionDict.allKeys;
    if (keys.containsObject_("image".toNSString())) {
      return binding.MLFeatureDescription.castFrom(
          descriptionDict.objectForKey_("image".toNSString())!);
    } else if (keys.containsObject_("data".toNSString())) {
      return binding.MLFeatureDescription.castFrom(
          descriptionDict.objectForKey_("data".toNSString())!);
    }
    throw Error();
  }

  int get expectedWidth {
    return inputFeatureDescription.imageConstraint!.pixelsWide;
  }

  int get expectedHeight {
    return inputFeatureDescription.imageConstraint!.pixelsHigh;
  }

  Future<List<(String, double)>> predictFromImage(Image detection,
      {int top = 5}) async {
    var feature =
        binding.ClassifierInputProvider.fromImage_(detection.cvpixelbuffer);
    var results = await model.predictFromFeatures(feature);
    var results_ = binding.ClassifierOutputProvider.fromProvider_(results);
    if (top == 1) {
      var label = results_.classLabel.toString();
      var confidence = NSNumber.castFrom(
              results_.classLabel_probs.objectForKey_(results_.classLabel)!)
          .doubleValue;
      return [(label, confidence)];
    } else {
      final keys = results_.classLabel_probs.allKeys;
      var scores = List.generate(keys.count, (int index) {
        var key = keys.objectAtIndex_(index);
        var val = results_.classLabel_probs.objectForKey_(key)!;
        return (
          NSString.castFrom(key).toString(),
          NSNumber.castFrom(val).doubleValue
        );
      });
      scores.sort((a, b) => b.$2.compareTo(a.$2));
      return scores.take(min(top, scores.length)).toList();
    }
  }
}
