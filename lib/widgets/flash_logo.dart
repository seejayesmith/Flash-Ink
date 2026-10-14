import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'tattoo_machine_icon.dart';

/// The official Flash.Ink brand logo displaying "Flash" in Kaushan Script
/// with the coil tattoo machine icon trailing seamlessly behind the "h"
/// as if actively writing the signature.
class FlashLogo extends StatelessWidget {
  /// Font size of the "Flash" wordmark.
  final double fontSize;

  /// Brand color of the logo text and tattoo gun icon.
  final Color color;

  /// Optional font weight (defaults to bold).
  final FontWeight? fontWeight;

  /// Optional text shadows.
  final List<Shadow>? shadows;

  /// Counter-clockwise tilt of the whole logo, in degrees.
  final double tiltDegrees;

  const FlashLogo({
    super.key,
    this.fontSize = 76.0,
    this.color = const Color(0xFFEEC200),
    this.fontWeight = FontWeight.bold,
    this.shadows,
    this.tiltDegrees = 20.0,
  });

  // ---------------------------------------------------------------------------
  // Geometry constants (measured by rasterising Kaushan Script Bold and
  // tattoo_gun.svg, expressed as fractions so they scale with [fontSize]).
  // ---------------------------------------------------------------------------

  /// Gun icon height as a fraction of [fontSize].
  static const double _gunHeightFactor = 0.82;

  /// SVG viewBox aspect ratio (60 x 69).
  static const double _gunAspect = 60.0 / 69.0;

  /// Needle tip position inside the SVG box, as fractions of its width/height.
  /// The tip is the bottom-left-most ink point at viewBox (0, 56.7).
  static const double _needleTipX = 0.0;
  static const double _needleTipY = 56.7 / 69.0;

  /// Terminal of the trailing flick on the "h", relative to the text layout
  /// box origin, as fractions of [fontSize]. Nudged ~1px into the stroke so
  /// the needle reads as touching the ink.
  static const double _hTipX = 2.075;
  static const double _hTipY = 1.03;

  /// Extra downward shift applied to the gun, as a fraction of [fontSize].
  static const double _gunDropFactor = 0.05;

  /// Clockwise twist of the gun around its needle tip, in degrees.
  static const double _gunTwistDegrees = 15.0;

  /// Visible ink extents of the wordmark within its text layout box
  /// (fractions of [fontSize]). Used to size the rotated logo tightly.
  static const double _textInkLeft = 0.095;
  static const double _textInkTop = 0.24;
  static const double _textInkBottom = 1.2;

  /// Visible ink extents of the gun within its SVG box (fractions of the box).
  static const double _gunInkTop = 73.0 / 690.0;
  static const double _gunInkRight = 543.0 / 600.0;
  static const double _gunInkBottom = 567.0 / 690.0;

  @override
  Widget build(BuildContext context) {
    final textStyle = GoogleFonts.kaushanScript(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      shadows: shadows,
    );

    // Measure the wordmark so the composite reserves exactly enough space.
    final painter = TextPainter(
      text: TextSpan(text: 'Flash', style: textStyle),
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
      maxLines: 1,
    )..layout();
    final textWidth = painter.width;
    final textHeight = painter.height;
    painter.dispose();

    final gunHeight = fontSize * _gunHeightFactor;
    final gunWidth = gunHeight * _gunAspect;

    // Place the gun so its needle tip lands on the "h" flick terminal,
    // then drop it slightly.
    final gunLeft = fontSize * _hTipX - gunWidth * _needleTipX;
    final rawGunTop = fontSize * (_hTipY + _gunDropFactor) -
        gunHeight * _needleTipY;

    // If the gun would poke above the text box, shift everything down.
    final topInset = rawGunTop < 0 ? -rawGunTop : 0.0;
    final gunTop = rawGunTop + topInset;

    // Positive angle is clockwise in Flutter.
    final gunTwist = _gunTwistDegrees * math.pi / 180.0;
    final needleLocal =
        Offset(gunWidth * _needleTipX, gunHeight * _needleTipY);

    final boxWidth = math.max(gunLeft + gunWidth, textWidth);
    final boxHeight = math.max(gunTop + gunHeight, textHeight + topInset);

    final composite = SizedBox(
      width: boxWidth,
      height: boxHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            top: topInset,
            child: Text(
              'Flash',
              style: textStyle,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.visible,
              textScaler: TextScaler.noScaling,
            ),
          ),
          Positioned(
            left: gunLeft,
            top: gunTop,
            // Pivot about the needle tip so it stays on the "h".
            child: Transform.rotate(
              angle: gunTwist,
              origin: needleLocal - Offset(gunWidth / 2, gunHeight / 2),
              child: TattooMachineIcon(
                height: gunHeight,
                width: gunWidth,
                alignment: Alignment.topLeft,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );

    // Gun ink corners after twisting about the needle tip (composite space).
    final needle = Offset(gunLeft, gunTop) + needleLocal;
    final cosG = math.cos(gunTwist);
    final sinG = math.sin(gunTwist);
    final gunCorners = <Offset>[
      for (final fx in [0.0, _gunInkRight])
        for (final fy in [_gunInkTop, _gunInkBottom])
          Offset(gunLeft + gunWidth * fx, gunTop + gunHeight * fy) - needle,
    ].map((d) => needle +
        Offset(d.dx * cosG - d.dy * sinG, d.dx * sinG + d.dy * cosG));
    final gunXs = gunCorners.map((p) => p.dx);
    final gunYs = gunCorners.map((p) => p.dy);

    // Tight rectangle around the visible ink (text + gun) in composite space.
    final inkLeft = math.min(fontSize * _textInkLeft, gunXs.reduce(math.min));
    final inkRight = gunXs.reduce(math.max);
    final inkTop = math.min(
      topInset + fontSize * _textInkTop,
      gunYs.reduce(math.min),
    );
    final inkBottom = math.max(
      topInset + fontSize * _textInkBottom,
      gunYs.reduce(math.max),
    );
    final inkWidth = inkRight - inkLeft;
    final inkHeight = inkBottom - inkTop;
    final inkCenter = Offset(
      (inkLeft + inkRight) / 2,
      (inkTop + inkBottom) / 2,
    );

    // Bounding box of the ink rectangle after rotation.
    final theta = tiltDegrees * math.pi / 180.0;
    final cosT = math.cos(theta).abs();
    final sinT = math.sin(theta).abs();
    final outWidth = inkWidth * cosT + inkHeight * sinT;
    final outHeight = inkWidth * sinT + inkHeight * cosT;

    // Rotate about the ink centre (Flutter's positive angle is clockwise,
    // so negate for counter-clockwise) and centre it in the output box.
    return SizedBox(
      width: outWidth,
      height: outHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: outWidth / 2 - inkCenter.dx,
            top: outHeight / 2 - inkCenter.dy,
            child: Transform.rotate(
              angle: -theta,
              origin: inkCenter - Offset(boxWidth / 2, boxHeight / 2),
              child: composite,
            ),
          ),
        ],
      ),
    );
  }
}
