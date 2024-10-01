import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:mlruntime_example/classifier_view.dart';
import 'package:mlruntime_example/detector_view.dart';

const ImageFormatGroup imageFormatGroup = ImageFormatGroup.bgra8888;

late List<CameraDescription> cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  cameras = await availableCameras();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

enum ModelType { detector, classifier }

class _MyAppState extends State<MyApp> {
  static const models = [
    ("models/mobiledet_amerch.mlpackage.zip", ModelType.detector),
    ("models/yolov9m_amerch.mlpackage.zip", ModelType.detector),
  ];
  bool usePhotoLibrary = false;

  @override
  Widget build(BuildContext context) {
    WakelockPlus.enable();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          title: const Text("Object Detector"),
          actions: [
            Switch(
                value: usePhotoLibrary,
                onChanged: (value) => setState(() {
                      usePhotoLibrary = value;
                    })),
          ],
        ),
        body: ListView.builder(
            shrinkWrap: false,
            padding: const EdgeInsets.all(8),
            itemCount: models.length,
            itemBuilder: (BuildContext context, int idx) {
              var modelKey = models[idx];
              return TextButton(
                onPressed: () {
                  if (context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => switch (modelKey.$2) {
                          ModelType.detector =>
                            DetectorView(usePhotoLibrary, modelKey.$1),
                          ModelType.classifier =>
                            ClassifierView(usePhotoLibrary, modelKey.$1),
                        },
                      ),
                    );
                  }
                },
                child: Text(modelKey.$1),
              );
            }),
      ),
    );
  }
}
