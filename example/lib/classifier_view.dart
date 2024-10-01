import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as libimage;

import 'package:mlruntime/mlruntime.dart' as mlruntime;
import 'package:mlruntime_example/camera_view.dart';
import 'package:mlruntime_example/main.dart';

import 'package:mlruntime_example/painter/classifier_painter.dart';

class ClassifierView extends StatefulWidget {
  const ClassifierView(this.usePhotoLibrary, this.assetKey, {super.key});

  final bool usePhotoLibrary;
  final String assetKey;

  @override
  State<ClassifierView> createState() => _ClassifierView();
}

class _ClassifierView extends State<ClassifierView> {
  // ignore: prefer_final_fields
  mlruntime.Classifier? detector;
  CameraController? _controller;

  List<ValueNotifier<mlruntime.Image?>> notifier = [];
  List<File> selectedImages = [];

  bool firstLoad = true;

  void _onCameraFrame(CameraImage image) async {
    assert(image.planes.length == 1);
    final nativeimage = mlruntime.Image.initFromImage(image.planes[0].bytes,
        image.width, image.height, mlruntime.ImageFormat.bgra);
    notifier[0].value = nativeimage;
  }

  @override
  void initState() {
    super.initState();
    loadPlatformState();
  }

  @override
  void dispose() {
    super.dispose();
    if (_controller != null && _controller!.value.isInitialized) {
      _controller?.stopImageStream().whenComplete(() => _controller!.dispose());
    }
  }

  void loadPlatformState() async {
    detector = await mlruntime.Classifier.load(rootBundle, widget.assetKey,
        computeUnits:
            mlruntime.MLComputeUnits.MLComputeUnitsCPUAndNeuralEngine);
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> pickImage() async {
    final images = await ImagePicker().pickMultiImage();
    if (mounted) {
      if (images.isEmpty) {
        if (firstLoad) {
          // ignore: use_build_context_synchronously
          Navigator.of(context).pop();
          return;
        }
      }
      notifier = List.generate(images.length, (_) => ValueNotifier(null));
      selectedImages = images.map((v) => File(v.path)).toList();
      setState(() {});

      for (var (i, image) in images.indexed) {
        final imageencoded = await image.readAsBytes();
        final imagedata = libimage.decodeImage(imageencoded)!;

        notifier[i].value = mlruntime.Image.initFromImage(
            imagedata.getBytes(order: libimage.ChannelOrder.bgra),
            imagedata.width,
            imagedata.height,
            mlruntime.ImageFormat.bgra);
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
      body = ClassifierWidget(detector, notifier[0], child: previewBuilder(0));
    } else {
      body = ListView.builder(
        itemCount: notifier.length,
        itemBuilder: (context, index) {
          return ClassifierWidget(detector, notifier[index],
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
          title: Text(widget.assetKey.replaceAll("models/", "")),
        ),
        body: body,
      ),
    );
  }
}

class ClassifierWidget extends StatefulWidget {
  final mlruntime.Classifier? detector;
  final ValueNotifier<mlruntime.Image?> notifier;
  final Widget? child;
  const ClassifierWidget(this.detector, this.notifier, {this.child, super.key});

  @override
  State<StatefulWidget> createState() => _ClassifierWidget();
}

class _ClassifierWidget extends State<ClassifierWidget> {
  ClassifierPainter? painter;
  late mlruntime.ImageProcessor processor;

  int inferTime = 0;
  RangeValues aspectThreshold = const RangeValues(1 / 1.5, 1.5);
  double confThreshold = 0.65;

  @override
  Widget build(BuildContext context) {
    const sliderTheme = SliderThemeData(
        showValueIndicator: ShowValueIndicator.onlyForContinuous);
    makeSlider(Widget widget) {
      return SliderTheme(
        data: sliderTheme,
        child: widget,
      );
    }

    return Column(children: [
      Stack(
        children: [
          CustomPaint(foregroundPainter: painter, child: widget.child),
          Positioned(
            bottom: 0.0,
            left: 0.0,
            right: 0.0,
            child: Column(
              children: [
                makeSlider(Slider(
                  min: 0.01,
                  max: 1.00,
                  label: "${(confThreshold * 100).toInt()}%",
                  value: confThreshold,
                  onChanged: (value) => setState(() {
                    confThreshold = value;
                  }),
                  onChangeEnd: (value) => onNotification(),
                ))
              ],
            ),
          ),
        ],
      ),
      Center(child: Text("Inference Time: $inferTime ms")),
    ]);
  }

  @override
  void initState() {
    super.initState();
    processor = mlruntime.ImageProcessor();
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
    image = await processor.scale(
        image,
        mlruntime.Image.init(
            widget.detector!.expectedWidth, widget.detector!.expectedHeight));
    var stopwatch = Stopwatch();
    stopwatch.start();
    var results = await widget.detector!.predictFromImage(image);
    stopwatch.stop();

    var painter = ClassifierPainter(results.where((object) {
      return object.$2 >= confThreshold;
    }));

    if (mounted) {
      setState(() {
        inferTime = stopwatch.elapsedMilliseconds;
        this.painter = painter;
      });
    }
  }
}
