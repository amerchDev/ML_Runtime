import 'package:flutter/services.dart';
import 'package:mlruntime/binding/coreml.dart' as binding;
import 'package:objective_c/objective_c.dart' as objc;
import 'dart:ui' as ui;

import 'package:mlruntime/mlruntime.dart';

export 'package:mlruntime/binding/coreml.dart'
    show DetectorNMSInputProvider, DetectorNMSOutputProvider;

final class DetectedObject {
  final int classId;
  final String? classLabel;
  final ui.Rect box;
  final double conf;

  const DetectedObject(this.classId, this.classLabel, this.box, this.conf);
}

final class DetectorNMS {
  final MLModel model;
  double confidenceThreshold = 0.35;
  double iouThreshold = 0.45;

  DetectorNMS._(this.model);
  static Future<DetectorNMS?> load(AssetBundle bundle, String assetKey,
      {MLComputeUnits computeUnits = MLComputeUnits.MLComputeUnitsAll}) async {
    final config = MLModelConfiguration(computeUnits: computeUnits);
    final model = await MLModel.fromBundle(bundle, assetKey, config);
    if (model != null) {
      return DetectorNMS._(model);
    }
    return null;
  }

  binding.MLFeatureDescription get inputFeatureDescription {
    return binding.MLFeatureDescription.castFrom(model
        .native.modelDescription.inputDescriptionsByName
        .objectForKey_("image".toNSString())!);
  }

  int get expectedWidth {
    return inputFeatureDescription.imageConstraint!.pixelsWide;
  }

  int get expectedHeight {
    return inputFeatureDescription.imageConstraint!.pixelsHigh;
  }

  Future<List<DetectedObject>> predictFromImage(Image detection,
      {double? confidenceThreshold, double? iouThreshold}) async {
    var feature =
        DetectorNMSInputProvider.fromImage_iouThreshold_confidenceThreshold_(
            detection.cvpixelbuffer,
            iouThreshold ?? this.iouThreshold,
            confidenceThreshold ?? this.confidenceThreshold);
    final results = DetectorNMSOutputProvider.fromProvider_(
        await model.predictFromFeatures(feature));
    final conf = MLMultiArray.fromNative(results.confidence);
    final bbox = MLMultiArray.fromNative(results.coordinates);
    assert(conf.shape[0] == bbox.shape[0]);
    final detections = conf.shape[0];

    final labels = model.native.modelDescription.classLabels?.toStringList();
    return List.generate(detections, (int index) {
      final rect = ui.Rect.fromCenter(
          center: ui.Offset(bbox[[index, 0]], bbox[[index, 1]]),
          width: bbox[[index, 2]],
          height: bbox[[index, 3]]);
      int cls = 0;
      double conf_ = conf[[index, 0]];
      for (int i = 0; i < conf.shape[1]; i++) {
        double value = conf[[index, i]];
        if (value > conf_) {
          conf_ = value;
          cls = i;
        }
      }
      return DetectedObject(cls, labels?[cls], rect, conf_);
    });
  }
}
