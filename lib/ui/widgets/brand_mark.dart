import 'package:flutter/material.dart';

import '../theme.dart';

/// Original geometric mark: image frame and two direction arrows.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 42});
  final double size;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'ImageShift 图标',
    child: CustomPaint(size: Size.square(size), painter: const BrandPainter()),
  );
}

class BrandPainter extends CustomPainter {
  const BrandPainter();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    final paint = Paint()..color = ShiftTheme.teal;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, 100, 100),
        const Radius.circular(24),
      ),
      paint,
    );
    paint
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
      Path()
        ..moveTo(29, 29)
        ..lineTo(76, 29)
        ..lineTo(76, 59),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(24, 41)
        ..lineTo(24, 71)
        ..lineTo(71, 71),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(65, 20)
        ..lineTo(76, 29)
        ..lineTo(65, 38),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(35, 62)
        ..lineTo(24, 71)
        ..lineTo(35, 80),
      paint,
    );
    paint
      ..style = PaintingStyle.fill
      ..color = const Color(0xffb5e7d8);
    canvas.drawPath(
      Path()
        ..moveTo(35, 58)
        ..lineTo(46, 43)
        ..lineTo(57, 57)
        ..lineTo(64, 48)
        ..lineTo(68, 61)
        ..lineTo(35, 61)
        ..close(),
      paint,
    );
    canvas.drawCircle(const Offset(61, 41), 4, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(BrandPainter oldDelegate) => false;
}
