import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Custom painter for the dashed circular guide ring around the profile avatar.
class DashedCirclePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashLength;
  final double gapLength;

  const DashedCirclePainter({
    required this.color,
    this.strokeWidth = 1.5,
    this.dashLength = 6.0,
    this.gapLength = 5.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final radius = (size.width - strokeWidth) / 2;
    final center = Offset(size.width / 2, size.height / 2);
    final circumference = 2 * math.pi * radius;
    final totalDashes = (circumference / (dashLength + gapLength)).floor();
    if (totalDashes <= 0) return;

    final adjustedDashAngle = (2 * math.pi) / totalDashes;
    final dashFraction = dashLength / (dashLength + gapLength);

    for (int i = 0; i < totalDashes; i++) {
      final startAngle = i * adjustedDashAngle;
      final sweepAngle = adjustedDashAngle * dashFraction;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant DashedCirclePainter oldDelegate) =>
      color != oldDelegate.color ||
      strokeWidth != oldDelegate.strokeWidth ||
      dashLength != oldDelegate.dashLength ||
      gapLength != oldDelegate.gapLength;
}

/// Custom painter for the silhouette avatar matching the wireframe:
/// Head with hair sweep, shoulders outline, and camera outline on chest.
class AvatarSilhouettePainter extends CustomPainter {
  final Color strokeColor;

  const AvatarSilhouettePainter({required this.strokeColor});

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Head
    final headCenter = Offset(size.width * 0.5, size.height * 0.36);
    final headRadius = size.width * 0.17;
    canvas.drawCircle(headCenter, headRadius, strokePaint);

    // Hair sweep / parted arc inside head
    final hairPath = Path()
      ..moveTo(headCenter.dx - headRadius * 0.85, headCenter.dy - headRadius * 0.15)
      ..quadraticBezierTo(
        headCenter.dx - headRadius * 0.15,
        headCenter.dy + headRadius * 0.25,
        headCenter.dx + headRadius * 0.15,
        headCenter.dy - headRadius * 0.65,
      );
    canvas.drawPath(hairPath, strokePaint);

    // Shoulders / chest arc
    final shouldersPath = Path()
      ..moveTo(size.width * 0.18, size.height * 0.90)
      ..quadraticBezierTo(
        size.width * 0.22,
        size.height * 0.62,
        size.width * 0.5,
        size.height * 0.62,
      )
      ..quadraticBezierTo(
        size.width * 0.78,
        size.height * 0.62,
        size.width * 0.82,
        size.height * 0.90,
      );
    canvas.drawPath(shouldersPath, strokePaint);

    // Camera outline on chest
    final cameraRect = Rect.fromCenter(
      center: Offset(size.width * 0.5, size.height * 0.75),
      width: size.width * 0.23,
      height: size.height * 0.16,
    );
    final cameraRRect = RRect.fromRectAndRadius(cameraRect, const Radius.circular(3));
    canvas.drawRRect(cameraRRect, strokePaint);

    // Camera lens
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.75),
      size.width * 0.045,
      strokePaint,
    );
  }

  @override
  bool shouldRepaint(covariant AvatarSilhouettePainter oldDelegate) =>
      strokeColor != oldDelegate.strokeColor;
}

/// A wireframe-aligned profile avatar widget supporting:
/// - Empty state: Dashed outer circle, inner onyx container with custom silhouette & camera, plus (+) badge
/// - Selected state: Clean circular image with solid gold border and edit badge
class ProfileAvatarPlaceholder extends StatelessWidget {
  final Uint8List? imageBytes;
  final VoidCallback? onTap;
  final VoidCallback? onBadgeTap;
  final double diameter;
  final double dashedRingDiameter;

  const ProfileAvatarPlaceholder({
    super.key,
    required this.imageBytes,
    this.onTap,
    this.onBadgeTap,
    this.diameter = 160.0,
    this.dashedRingDiameter = 196.0,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasImage = imageBytes != null;

    if (!hasImage) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: dashedRingDiameter,
          height: dashedRingDiameter,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer dashed circular ring
              CustomPaint(
                size: Size(dashedRingDiameter, dashedRingDiameter),
                painter: const DashedCirclePainter(
                  color: Color(0xFF383C3C),
                  strokeWidth: 1.5,
                  dashLength: 6.0,
                  gapLength: 5.0,
                ),
              ),

              // Inner avatar circle with camera icon placeholder
              Container(
                width: diameter,
                height: diameter,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF1E2020),
                  border: Border.all(
                    color: const Color(0xFF333737),
                    width: 2.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(60),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.camera_alt_outlined,
                  size: 56,
                  color: Color(0xFF8C9191),
                ),
              ),

              // Plus (+) circular badge
              Positioned(
                bottom: 10,
                right: 10,
                child: GestureDetector(
                  onTap: onBadgeTap ?? onTap,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.gold,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF121414),
                        width: 3.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(120),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.add,
                      color: Color(0xFF121414),
                      size: 24,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Photo is selected: clean circular preview with solid border and edit badge
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: diameter + 20,
        height: diameter + 20,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: diameter,
              height: diameter,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1E2020),
                border: Border.all(
                  color: AppTheme.gold,
                  width: 2.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.gold.withAlpha(40),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                  BoxShadow(
                    color: Colors.black.withAlpha(140),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.memory(
                  imageBytes!,
                  width: diameter,
                  height: diameter,
                  fit: BoxFit.cover,
                ),
              ),
            ),

            // Edit icon badge
            Positioned(
              bottom: 4,
              right: 4,
              child: GestureDetector(
                onTap: onBadgeTap ?? onTap,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.gold,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF121414),
                      width: 3.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(120),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.edit_outlined,
                    color: Color(0xFF121414),
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
