import 'package:flutter/material.dart';

/// The official Flash.Ink brand logo displaying the "Flash" wordmark
/// and trailing tattoo machine emblem as an image asset.
class FlashLogo extends StatelessWidget {
  /// Asset path for the Flash logo image.
  static const String assetPath = 'assets/images/flash_logo.png';

  /// Aspect ratio (width / height) of [assetPath] (464 x 296).
  static const double _aspectRatio = 464.0 / 296.0;

  /// Scale factor mapping [fontSize] to rendered logo height, matching
  /// the prior composite wordmark proportions.
  static const double _heightScale = 1.89;

  /// Reference size used to scale the rendered logo height proportionally.
  final double fontSize;

  /// Retained for API compatibility with existing callers.
  final Color color;

  /// Retained for API compatibility with existing callers.
  final FontWeight? fontWeight;

  /// Retained for API compatibility with existing callers.
  final List<Shadow>? shadows;

  /// Retained for API compatibility with existing callers.
  final double tiltDegrees;

  const FlashLogo({
    super.key,
    this.fontSize = 76.0,
    this.color = const Color(0xFFEEC200),
    this.fontWeight = FontWeight.bold,
    this.shadows,
    this.tiltDegrees = 20.0,
  });

  @override
  Widget build(BuildContext context) {
    final height = fontSize * _heightScale;
    final width = height * _aspectRatio;

    return Image.asset(
      assetPath,
      width: width,
      height: height,
      fit: BoxFit.contain,
      semanticLabel: 'Flash',
    );
  }
}
