// This is a basic Flutter integration test.
//
// Since integration tests run in a full Flutter application, they can interact
// with the host side of a plugin implementation, unlike Dart unit tests.
//
// For more information about Flutter integration tests, please see
// https://docs.flutter.dev/cookbook/testing/integration/introduction

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mlruntime/mlruntime.dart';

import 'package:image/image.dart' as libimage;

const String modelPath = "models/YOLOv3Tiny.mlmodel";
const int imageWidth = 416;
const int imageHeight = 416;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('loadModelAsset test', (_) async {
    bool failed = false;
    try {
      var data = await MLModelAsset.loadModelAssetFromBundle(modelPath);
      expect(data != null, true);
    } catch (_) {
      failed = true;
    }
    expect(failed, false);
  });

  testWidgets('loadModelFromBundle test', (WidgetTester _) async {
    MLModelConfiguration config = MLModelConfiguration(
        computeUnits: MLComputeUnits.MLComputeUnitsCPUAndGPU);
    MLModel? plugin = await MLModel.fromBundle(rootBundle, modelPath, config);
    expect(plugin != null, true);
  });

  testWidgets('various backends', (WidgetTester _) async {
    for (MLComputeUnits setting in MLComputeUnits.values) {
      var config = MLModelConfiguration(computeUnits: setting);
      expect(config.computeUnits, setting);
      var plugin = await MLModel.fromBundle(rootBundle, modelPath, config);
      expect(plugin != null, true);
    }
  });

  testWidgets('feature providers', (WidgetTester _) async {
    DetectorNMSInputProvider provider = DetectorNMSInputProvider.alloc().init();
    Image buf = Image.init(imageWidth, imageHeight);
    provider.image = buf.cvpixelbuffer;
    expect(provider.image, buf.cvpixelbuffer);
  });

  testWidgets('image allocation', (WidgetTester _) async {
    Image? buf = Image.init(imageWidth, imageHeight);
    expect(buf.width, imageWidth);
    expect(buf.height, imageHeight);
  });

  testWidgets('infer async', (WidgetTester _) async {
    MLModelConfiguration config = MLModelConfiguration.createGPUConfig();
    MLModel plugin =
        await MLModel.fromBundle(rootBundle, modelPath, config).then((m) => m!);

    Image buf = Image.init(imageWidth, imageHeight);
    DetectorNMSInputProvider input =
        DetectorNMSInputProvider.fromImage_(buf.cvpixelbuffer);

    var result = await plugin.predictFromFeatures(input);
    var features = DetectorNMSOutputProvider.fromProvider_(result);
    expect(features.coordinates.count >= 0, true);
    expect(features.confidence.count >= 0, true);
  });

  Future<libimage.Image?> loadImage<D extends libimage.Decoder>(
      String path, D decoder) async {
    var encoded = await rootBundle.load(path);
    var image = decoder.decode(encoded.buffer.asUint8List());
    if (image == null) {
      return null;
    }
    return libimage.copyResize(image, width: imageWidth, height: imageHeight);
  }

  testWidgets('yolov3 model wrapper', (WidgetTester _) async {
    var model = await DetectorNMS.load(rootBundle, modelPath);
    var image = await loadImage("images/cat.jpg", libimage.JpegDecoder());
    expect(image != null, true);
    image = libimage.copyResize(image!, width: imageWidth, height: imageHeight);
    var bytes = image.getBytes(order: libimage.ChannelOrder.argb);
    var payload =
        Image.initFromImage(bytes, imageWidth, imageHeight, ImageFormat.argb);

    final results =
        await model!.predictFromImage(payload, confidenceThreshold: 0.40);
    expect(results.length, 1);
    expect(results[0].classLabel!.compareTo("cat"), 0);
  });
}
