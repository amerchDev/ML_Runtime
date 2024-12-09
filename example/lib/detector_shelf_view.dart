import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:mlruntime/mlruntime.dart' as mlruntime;
import 'package:mlruntime_example/camera_view.dart';
import 'package:mlruntime_example/main.dart';
import 'package:mlruntime_example/math/linear.dart' as linear;

import 'package:mlruntime_example/painter/bounding_box_painter.dart';
import 'package:mlruntime_example/painter/multiline_painter.dart';

import 'utils/tagsearch.dart';

class DetectorShelfView extends StatefulWidget {
  const DetectorShelfView(this.assetKey, {super.key});
  final String assetKey;

  @override
  State<DetectorShelfView> createState() => _DetectorShelfView();
}

class _DetectorShelfView extends State<DetectorShelfView> {
  // ignore: prefer_final_fields
  mlruntime.DetectorNMS? detector;
  CameraController? _controller;
  late ValueNotifier<mlruntime.Image?> notifier;

  bool firstLoad = true;

  void _onCameraFrame(CameraImage image) {
    assert(image.planes.length == 1);
    notifier.value = mlruntime.Image.initFromImage(image.planes[0].bytes,
        image.width, image.height, mlruntime.ImageFormat.bgra);
  }

  @override
  void initState() {
    super.initState();
    loadPlatformState();
  }

  void loadPlatformState() async {
    detector = await mlruntime.DetectorNMS.load(rootBundle, widget.assetKey,
        computeUnits: mlruntime.MLComputeUnits.MLComputeUnitsAll);
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    if (_controller != null && _controller!.value.isInitialized) {
      _controller?.stopImageStream().whenComplete(() => _controller!.dispose());
    }
    super.dispose();
  }

  Future<void> pickCamera() async {
    notifier = ValueNotifier(null);
    _controller = CameraController(cameras[0], ResolutionPreset.high,
        imageFormatGroup: imageFormatGroup);
    await _controller!.initialize();
    await _controller!.startImageStream((image) => _onCameraFrame(image));
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (firstLoad) {
      pickCamera();
      firstLoad = false;
    }

    final Widget body;
    body = Center(
      child:
          DetectionWidget(detector, notifier, child: CameraView(_controller!)),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      home: Scaffold(
        appBar: AppBar(
          leading: BackButton(
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(widget.assetKey.replaceAll("models/", "")),
        ),
        body: Container(
            padding: EdgeInsets.fromLTRB(
                0, 0, 0, MediaQuery.of(context).padding.bottom),
            child: body),
      ),
    );
  }
}

class ImagePainter extends CustomPainter {
  final ui.Image image;
  ImagePainter(this.image);

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    canvas.drawImage(image, const ui.Offset(0, 0), ui.Paint());
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class DetectionWidget extends StatefulWidget {
  final mlruntime.DetectorNMS? detector;
  final ValueNotifier<mlruntime.Image?> notifier;
  final Widget? child;
  const DetectionWidget(this.detector, this.notifier, {this.child, super.key});

  @override
  State<StatefulWidget> createState() => _DetectionWidget();
}

class _DetectionWidget extends State<DetectionWidget> {
  ObjectDetectorPainter? painter;
  MultilinePainter? linePainter;
  mlruntime.ImageProcessor processor = mlruntime.ImageProcessor();

  String modelSize = "";

  int inferTime = 0;
  RangeValues aspectThreshold = const RangeValues(1 / 1.5, 1.5);
  bool enableClassLabel = false;

  bool controlLocked = true;

  bool inFlight = false;

  // ui.Image? faker;

  @override
  Widget build(BuildContext context) {
    const sliderTheme = SliderThemeData(
        showValueIndicator: ShowValueIndicator.onlyForContinuous);
    makeSlider({String? label, required Widget child}) {
      return SliderTheme(
        data: sliderTheme,
        child: child,
      );
    }

    lockableSlider(BuildContext context,
        {required bool locked,
        required double value,
        void Function(double)? onValueChanged,
        void Function(double)? onValueChangedEnd,
        String? label}) {
      return Row(
        children: [
          Expanded(
            child: makeSlider(
              child: Slider(
                  value: value,
                  min: 0.01,
                  max: 1.00,
                  label: "$label ${(value * 100).toInt()}%",
                  onChanged: (!locked) ? onValueChanged : null,
                  onChangeEnd: onValueChangedEnd),
            ),
          ),
          label != null
              ? Text(label, style: Theme.of(context).textTheme.bodyMedium)
              : Container(),
        ],
      );
    }

    return Stack(children: [
      CustomPaint(
        foregroundPainter: linePainter,
        child: CustomPaint(foregroundPainter: painter, child: widget.child),
      ),
      Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Switch(
                    value: enableClassLabel,
                    onChanged: (value) => setState(() {
                      enableClassLabel = value;
                    }),
                  ),
                  IconButton.filled(
                    onPressed: () {
                      controlLocked ^= true;
                    },
                    icon: controlLocked
                        ? const Icon(Icons.lock)
                        : const Icon(Icons.lock_open, color: Colors.red),
                  ),
                ],
              ),
              Text(
                modelSize,
                style: TextStyle(backgroundColor: Colors.white.withAlpha(127)),
              ),
            ],
          )),
      Positioned(
        bottom: 0.0,
        left: 0.0,
        right: 0.0,
        child: Theme(
          data: Theme.of(context).copyWith(
            textTheme: Theme.of(context).textTheme.apply(
                  bodyColor: Colors.white,
                  displayColor: Colors.white,
                ),
          ),
          child: Builder(
            builder: (context) => Container(
              decoration: BoxDecoration(color: Colors.black.withOpacity(0.50)),
              child: IntrinsicWidth(
                child: Column(
                  children: [
                    lockableSlider(
                      context,
                      value: widget.detector?.confidenceThreshold ?? 0.01,
                      label: "conf",
                      locked: controlLocked,
                      onValueChanged: (widget.detector != null)
                          ? (value) => setState(() {
                                widget.detector!.confidenceThreshold = value;
                              })
                          : null,
                      onValueChangedEnd: (value) => onNotification(),
                    ),
                    Text("Inference Time: $inferTime ms",
                        style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ]);
  }

  @override
  void initState() {
    super.initState();
    widget.notifier.addListener(onNotification);
  }

  @override
  void dispose() {
    widget.notifier.removeListener(onNotification);
    processor.dispose();
    super.dispose();
  }

  void onNotification() {
    final image = widget.notifier.value;
    if (image != null) {
      onFrame(image);
    }
  }

  Future<void> onFrame(mlruntime.Image image) async {
    const int numBins = 7;
    const bool drawBins = false;
    if (widget.detector == null) {
      return;
    }
    if (inFlight) {
      return;
    }
    inFlight = true;
    var detector = widget.detector!;

    final int targetWidth = detector.expectedWidth;
    final int targetHeight = detector.expectedHeight;

    late final mlruntime.Image tensor;
    late double scaleX, scaleY;

    (tensor, (scaleX, scaleY)) = await processor.copy(
        image,
        mlruntime.Image.init(targetWidth, targetHeight),
        mlruntime.BitmapProcessorCopyMode.scaleFit);
    scaleX *= image.width.toDouble() / targetWidth.toDouble();
    scaleY *= image.height.toDouble() / targetHeight.toDouble();

    modelSize =
        "${targetWidth}x$targetHeight (${(scaleX * targetWidth).toInt()}x${(scaleY * targetHeight).toInt()})";
    var stopwatch = Stopwatch();
    stopwatch.start();
    Iterable<mlruntime.DetectedObject> results =
        await widget.detector!.predictFromImage(tensor);
    stopwatch.stop();

    results = results.map((value) {
      final bbox = Rect.fromLTRB(
          value.box.left / scaleX,
          value.box.top / scaleY,
          value.box.right / scaleX,
          value.box.bottom / scaleY);
      return mlruntime.DetectedObject(
          value.classId, value.classLabel, bbox, value.conf);
    });
    final resultsList = results.toList();

    final bins =
        binnedObjects(resultsList, expectedLabel: "price_tag", numBins: numBins)
            .where((obj) => obj.isNotEmpty)
            .toList();

    var lines = bins.where((obj) => obj.length > 4).map((bin) {
      var (m, b) = linear.regression(bin.map((obj) => obj.box.center));

      return (Offset(0, b), Offset(1, m * 1 + b));
    }).toList();

    // ignore: dead_code
    if (drawBins) {
      for (int i = 0; i < numBins; i++) {
        final double low = i / numBins;
        lines.add((
          Offset(0.0, low),
          Offset(1.0, low),
        ));
      }
    }
    Paint? Function(mlruntime.DetectedObject object)? repainter;
    if (bins.isNotEmpty) {
      mlruntime.DetectedObject? segmentTag = findSegmentTag(bins);

      if (segmentTag != null) {
        lines.add((
          Offset(segmentTag.box.center.dx, 0.0),
          Offset(segmentTag.box.center.dx, 1.0),
        ));
        final mlruntime.DetectedObject segmentTag_ = segmentTag;
        repainter = (mlruntime.DetectedObject object) {
          if (object == segmentTag_) {
            return Paint()..color = Colors.blue;
          }
          if (object.classLabel != "price_tag") return null;

          if (segmentTag_.box.center.dx < 0.5) {
            // Left
            if (object.box.center.dx > segmentTag_.box.center.dx) {
              return Paint()..color = Colors.green;
            } else {
              return Paint()..color = Colors.red;
            }
          } else {
            // Right
            if (object.box.center.dx < segmentTag_.box.center.dx) {
              return Paint()..color = Colors.green;
            } else {
              return Paint()..color = Colors.red;
            }
          }
        };
      }
    }
    MultilinePainter? linePainter = MultilinePainter(lines);
    var painter = ObjectDetectorPainter(resultsList, enableClassLabel,
        repainter: repainter);

    if (mounted) {
      setState(() {
        inferTime = stopwatch.elapsedMilliseconds;
        this.painter = painter;
        this.linePainter = linePainter;
      });
    }
    inFlight = false;
  }
}
