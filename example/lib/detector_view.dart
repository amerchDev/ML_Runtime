import 'dart:io';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as libimage;

import 'package:mlruntime/mlruntime.dart' as mlruntime;
import 'package:mlruntime_example/camera_view.dart';
import 'package:mlruntime_example/main.dart';

import 'package:mlruntime_example/painter/bounding_box_painter.dart';

class DetectorView extends StatefulWidget {
  const DetectorView(this.usePhotoLibrary, this.assetKey, {super.key});

  final bool usePhotoLibrary;
  final String assetKey;

  @override
  State<DetectorView> createState() => _DetectorView();
}

class _DetectorView extends State<DetectorView> {
  // ignore: prefer_final_fields
  mlruntime.DetectorNMS? detector;
  CameraController? _controller;
  List<ValueNotifier<mlruntime.Image?>> notifier = [];
  List<File> selectedImages = [];

  bool firstLoad = true;

  void _onCameraFrame(CameraImage image) {
    assert(image.planes.length == 1);
    notifier[0].value = mlruntime.Image.initFromImage(image.planes[0].bytes,
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

  Future<void> pickImage() async {
    final images = await ImagePicker().pickMultiImage();
    if (mounted) {
      if (images.isEmpty) {
        if (firstLoad) {
          // ignore: use_build_context_synchronously
          Navigator.of(context).pop();
        }
        return;
      }
      notifier = List.generate(images.length, (_) => ValueNotifier(null));
      selectedImages = images.map((v) => File(v.path)).toList();
      setState(() {});

      for (var (i, image) in images.indexed) {
        var imagedata = await libimage.decodeImageFile(image.path);
        var bytes =
            imagedata!.frames[0].getBytes(order: libimage.ChannelOrder.bgra);
        notifier[i].value = mlruntime.Image.initFromImage(bytes,
            imagedata.width, imagedata.height, mlruntime.ImageFormat.bgra);
      }
    }
  }

  Future<void> pickCamera() async {
    notifier = [ValueNotifier(null)];
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
      if (widget.usePhotoLibrary) {
        pickImage();
      } else {
        pickCamera();
      }
      firstLoad = false;
    }

    previewBuilder(int index) {
      if (widget.usePhotoLibrary) {
        return Image.file(selectedImages[index]);
      } else {
        return CameraView(_controller!);
      }
    }

    final Widget body;
    if (notifier.isEmpty) {
      body = Container();
    } else if (notifier.length == 1) {
      body = Center(
        child: DetectionWidget(detector, notifier[0], child: previewBuilder(0)),
      );
    } else {
      body = ListView.builder(
        itemCount: notifier.length,
        itemBuilder: (context, index) {
          return DetectionWidget(detector, notifier[index],
              child: previewBuilder(index));
        },
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      home: Scaffold(
        appBar: AppBar(
          leading: BackButton(
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            if (widget.usePhotoLibrary)
              IconButton(
                onPressed: () {
                  pickImage();
                },
                icon: const Icon(Icons.photo_album),
              )
          ],
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
  mlruntime.ImageProcessor processor = mlruntime.ImageProcessor();

  String modelSize = "";

  int inferTime = 0;
  RangeValues aspectThreshold = const RangeValues(1 / 1.5, 1.5);
  bool enableAspectThreshold = true;
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

    optionalRangedSlider(
        {required bool enabled,
        required RangeValues values,
        required void Function(bool)? onEnableChanged,
        required void Function(RangeValues)? onValueChanged,
        onValueChangedEnd}) {
      return Row(children: [
        Switch(
          value: enabled,
          onChanged: onEnableChanged,
        ),
        Expanded(
          child: makeSlider(
            child: RangeSlider(
              values: values,
              labels: RangeLabels(values.start.toStringAsFixed(2),
                  values.end.toStringAsFixed(2)),
              min: 1 / 3.0,
              max: 3.0,
              onChanged: enabled ? onValueChanged : null,
              onChangeEnd: onValueChangedEnd,
            ),
          ),
        ),
      ]);
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
      CustomPaint(foregroundPainter: painter, child: widget.child),
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
                  // (faker == null)
                  //     ? const Text("no tensor")
                  //     : Column(
                  //         children: [
                  //           Text("${faker!.width}x${faker!.height}"),
                  //           CustomPaint(
                  //             foregroundPainter: ImagePainter(faker!),
                  //           )
                  //         ],
                  //       ),
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
                    optionalRangedSlider(
                      enabled: enableAspectThreshold,
                      values: aspectThreshold,
                      onEnableChanged: controlLocked
                          ? null
                          : (value) => setState(() {
                                enableAspectThreshold = value;
                              }),
                      onValueChanged: controlLocked
                          ? null
                          : (value) => setState(() {
                                aspectThreshold = value;
                              }),
                    ),
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

    // faker = await tensor.intoUiImage(width: 128, height: 128);
    // print("$scaleX $scaleY");
    modelSize =
        "${targetWidth}x$targetHeight (${(scaleX * targetWidth).toInt()}x${(scaleY * targetHeight).toInt()})";
    var stopwatch = Stopwatch();
    stopwatch.start();
    Iterable<mlruntime.DetectedObject> results =
        await widget.detector!.predictFromImage(tensor);
    stopwatch.stop();

    results = results.where((object) {
      if (enableAspectThreshold) {
        final aspect = object.box.width / object.box.height;
        return aspect >= aspectThreshold.start && aspect <= aspectThreshold.end;
      } else {
        return true;
      }
    });
    results = results.map((value) {
      final bbox = Rect.fromLTRB(
          value.box.left / scaleX,
          value.box.top / scaleY,
          value.box.right / scaleX,
          value.box.bottom / scaleY);
      return mlruntime.DetectedObject(
          value.classId, value.classLabel, bbox, value.conf);
    });

    var painter = ObjectDetectorPainter(results, enableClassLabel);

    if (mounted) {
      setState(() {
        inferTime = stopwatch.elapsedMilliseconds;
        this.painter = painter;
      });
    }
    inFlight = false;
  }
}
