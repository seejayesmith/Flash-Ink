import 'package:flutter/material.dart';

/// A stylized vector icon representing a tattoo machine / coil gun.
class TattooMachineIcon extends StatelessWidget {
  final double size;
  final Color color;

  const TattooMachineIcon({
    super.key,
    this.size = 24.0,
    this.color = const Color(0xFFEEC200),
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _TattooMachinePainter(color: color),
    );
  }
}

class _TattooMachinePainter extends CustomPainter {
  final Color color;

  const _TattooMachinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.08
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final scale = size.width / 24.0;
    canvas.save();
    canvas.scale(scale);

    // Frame back upright
    final framePath = Path()
      ..moveTo(4, 20)
      ..lineTo(7, 7)
      ..lineTo(14, 5)
      ..lineTo(15, 8)
      ..lineTo(9, 9)
      ..lineTo(7.5, 17)
      ..close();
    canvas.drawPath(framePath, paint);

    // Coils (two vertical cylinders)
    final coil1 = RRect.fromRectAndRadius(
      const Rect.fromLTWH(8.5, 9, 3, 6),
      const Radius.circular(1),
    );
    final coil2 = RRect.fromRectAndRadius(
      const Rect.fromLTWH(12.5, 8, 3, 6.5),
      const Radius.circular(1),
    );
    canvas.drawRRect(coil1, paint);
    canvas.drawRRect(coil2, paint);

    // Top armature bar
    final barPath = Path()
      ..moveTo(6, 6.5)
      ..lineTo(18, 5)
      ..lineTo(18, 7)
      ..lineTo(6, 8.5)
      ..close();
    canvas.drawPath(barPath, paint);

    // Contact screw
    canvas.drawCircle(const Offset(8, 4), 1.2, paint);

    // Tube / Grip / Needle pointing down-right
    final needlePath = Path()
      ..moveTo(14, 13)
      ..lineTo(20, 19)
      ..lineTo(19, 20)
      ..lineTo(13, 14)
      ..close();
    canvas.drawPath(needlePath, paint);

    // Needle tip extending
    canvas.drawLine(const Offset(19.5, 19.5), const Offset(22, 22), strokePaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TattooMachinePainter oldDelegate) =>
      oldDelegate.color != color;
}
