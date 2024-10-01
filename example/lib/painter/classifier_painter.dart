import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class ClassifierPainter extends CustomPainter {
  final Iterable<(String, double)> results;
  ClassifierPainter(this.results);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint background = Paint()..color = const Color(0x99000000);
    final textStyle = ui.TextStyle(
        color: const Color.fromRGBO(178, 255, 89, 1), background: background);

    final ui.ParagraphBuilder builder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
          textAlign: TextAlign.left,
          fontSize: 16,
          textDirection: TextDirection.ltr),
    );
    builder.pushStyle(textStyle);
    final text = results.map((pair) {
      var (label, score) = pair;
      return "${(score * 100).toInt().toString()}% - $label";
    }).join("\n");
    builder.addText(text);
    builder.pop();

    canvas.drawParagraph(
      builder.build()
        ..layout(ui.ParagraphConstraints(
          width: size.width.abs(),
        )),
      const Offset(0, 0),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
