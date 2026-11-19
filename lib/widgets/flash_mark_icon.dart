import 'package:flutter/material.dart';

/// Displays the stylized gold "F" brand mark from the app's PNG asset.
class FlashMarkIcon extends StatelessWidget {
  final double size;
  final double? width;
  final double? height;
  final AlignmentGeometry alignment;

  const FlashMarkIcon({
    super.key,
    this.size = 36.0,
    this.width,
    this.height,
    this.alignment = Alignment.centerLeft,
  });

  /// Aspect ratio of the cropped `flash_f_icon.png` asset (79 x 142 px).
  static const double _aspectRatio = 79.0 / 142.0;

  @override
  Widget build(BuildContext context) {
    final effectiveHeight = height ?? size;
    final effectiveWidth = width ?? effectiveHeight * _aspectRatio;
    return Image.asset(
      'assets/images/flash_f_icon.png',
      width: effectiveWidth,
      height: effectiveHeight,
      alignment: alignment,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
    );
  }
}
