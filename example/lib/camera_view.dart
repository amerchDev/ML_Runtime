import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class CameraView extends StatefulWidget {
  const CameraView(this.controller, {super.key});
  final CameraController controller;

  @override
  State<StatefulWidget> createState() => _CameraView();
}

class _CameraView extends State<CameraView> {
  bool showFocusCircle = false;
  Offset focusPoint = const Offset(0, 0);
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapUp: (details) async {
        if (showFocusCircle) {
          return;
        }
        showFocusCircle = true;
        final x = details.localPosition.dx;
        final y = details.localPosition.dy;
        focusPoint = Offset(x, y);

        double fullWidth = MediaQuery.of(context).size.width;
        double cameraHeight = fullWidth * widget.controller.value.aspectRatio;
        double xp = x / fullWidth;
        double yp = y / cameraHeight;

        Offset point = Offset(xp, yp);

        // Manually focus
        await widget.controller.setFocusPoint(point);
        setState(() {
          Future.delayed(const Duration(milliseconds: 200)).whenComplete(() {
            setState(() {
              showFocusCircle = false;
            });
          });
        });
      },
      child: CameraPreview(
        widget.controller,
        child: (showFocusCircle)
            ? Positioned(
                top: focusPoint.dy - 20,
                left: focusPoint.dx - 20,
                child: Container(
                  height: 40,
                  width: 40,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5)),
                ))
            : null,
      ),
    );
  }
}
