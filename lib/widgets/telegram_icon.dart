import 'package:flutter/material.dart';

class TelegramIcon extends StatelessWidget {
  final double size;
  final Color? color;

  const TelegramIcon({
    super.key,
    this.size = 14,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = color ?? const Color(0xFF2AABEE);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        size: Size(size, size),
        painter: _TelegramPlanePainter(iconColor),
      ),
    );
  }
}

class _TelegramPlanePainter extends CustomPainter {
  final Color color;
  _TelegramPlanePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // Scale from 24x24 viewport
    final scale = size.width / 24.0;
    canvas.save();
    canvas.scale(scale);

    // Official Telegram paper plane geometry
    final mainPath = Path()
      ..moveTo(21.9, 3.4)
      ..lineTo(2.7, 10.8)
      ..cubicTo(1.6, 11.2, 1.6, 11.9, 2.5, 12.2)
      ..lineTo(7.4, 13.8)
      ..lineTo(18.8, 6.6)
      ..cubicTo(19.4, 6.2, 19.9, 6.4, 19.4, 6.8)
      ..lineTo(10.1, 15.2)
      ..lineTo(9.8, 19.4)
      ..cubicTo(10.2, 19.4, 10.4, 19.2, 10.6, 19.0)
      ..lineTo(12.7, 17.0)
      ..lineTo(17.1, 20.3)
      ..cubicTo(17.9, 20.7, 18.5, 20.5, 18.7, 19.5)
      ..lineTo(22.3, 4.4)
      ..cubicTo(22.6, 3.2, 22.0, 2.7, 21.9, 3.4)
      ..close();

    canvas.drawPath(mainPath, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TelegramPlanePainter oldDelegate) => oldDelegate.color != color;
}
