import 'package:flutter/material.dart';

class MultilinePainter extends CustomPainter {
  static const borderColorWide = Color.fromARGB(255, 0, 169, 236);
  MultilinePainter(this.points);

  final List<(Offset, Offset)> points;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint borderCustom = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = Colors.blue;
    for (var point in points) {
      canvas.drawLine(
          Offset(point.$1.dx * size.width, point.$1.dy * size.height),
          Offset(point.$2.dx * size.width, point.$2.dy * size.height),
          borderCustom);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
