import 'dart:ui';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:mlruntime/mlruntime.dart';

extension _RectExtension on Rect {
  Rect scale(Size size) {
    return Rect.fromLTRB(left * size.width, top * size.height,
        right * size.width, bottom * size.height);
  }

  Rect clamp(Size expected) {
    return Rect.fromLTRB(
        left > 0 ? left : 0,
        top > 0 ? top : 0,
        right < expected.width ? right : expected.width,
        bottom < expected.height ? bottom : expected.height);
  }
}

class ObjectDetectorPainter extends CustomPainter {
  static const borderColorTall = Color.fromARGB(255, 209, 0, 216);
  static const borderColorWide = Color.fromARGB(255, 0, 169, 236);
  ObjectDetectorPainter(this.objects, this.showClassLabels, {this.repainter});

  final Iterable<DetectedObject> objects;
  final bool showClassLabels;
  final Paint? Function(DetectedObject object)? repainter;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint background = Paint()..color = const Color(0x99000000);
    final Paint borderCustom = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    final Paint borderWide = borderCustom..color = borderColorWide;
    final Paint borderTall = borderCustom..color = borderColorTall;
    final ParagraphBuilder legendBuilder = ParagraphBuilder(
      ParagraphStyle(
          textAlign: TextAlign.left,
          fontSize: 16,
          textDirection: TextDirection.ltr),
    );
    // legendBuilder.pushStyle(
    //     ui.TextStyle(color: borderColorWide, background: background));
    // legendBuilder.addText("wide");
    // legendBuilder.pop();
    // legendBuilder.pushStyle(
    //     ui.TextStyle(color: borderColorTall, background: background));
    // legendBuilder.addText("\ntall");
    // legendBuilder.pop();
    canvas.drawParagraph(
      legendBuilder.build()
        ..layout(ParagraphConstraints(
          width: size.width,
        )),
      const Offset(0, 0),
    );

    for (final DetectedObject detectedObject in objects) {
      final ParagraphBuilder builder = ParagraphBuilder(
        ParagraphStyle(
            textAlign: TextAlign.left,
            fontSize: 16,
            textDirection: TextDirection.ltr),
      );
      if (showClassLabels) {
        builder.pushStyle(ui.TextStyle(
            color: const Color.fromRGBO(178, 255, 89, 1),
            background: background));
        builder.addText(
            "${detectedObject.classLabel} - ${(detectedObject.conf * 100).toStringAsPrecision(2)}%");
        builder.pop();
      }
      final Rect bbox = detectedObject.box.scale(size).clamp(size);
      final aspect = bbox.width / bbox.height;

      Paint? border;
      if (repainter != null) {
        final paint = repainter!(detectedObject);
        if (paint != null) {
          border = paint;
        }
      }

      if (border == null) {
        if (aspect > 1.0) {
          border = borderWide;
        } else {
          border = borderTall;
        }
      }
      canvas.drawRect(bbox, border);

      canvas.drawParagraph(
        builder.build()
          ..layout(ParagraphConstraints(
            width: size.width - bbox.left,
          )),
        Offset(bbox.left, bbox.top),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
