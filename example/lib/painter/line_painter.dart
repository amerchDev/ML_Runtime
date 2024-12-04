import 'package:flutter/material.dart';

class LinePainter extends CustomPainter {
  static const borderColorWide = Color.fromARGB(255, 0, 169, 236);
  LinePainter(this.p1, this.p2);

  final Offset p1, p2;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint borderCustom = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = Colors.blue;
    canvas.drawLine(Offset(p1.dx * size.width, p1.dy * size.height),
        Offset(p2.dx * size.width, p2.dy * size.height), borderCustom);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
