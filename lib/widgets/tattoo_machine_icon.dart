import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// A stylized vector icon representing a tattoo machine / coil gun using Tattoo Gun.svg.
class TattooMachineIcon extends StatelessWidget {
  final double size;
  final double? width;
  final double? height;
  final AlignmentGeometry alignment;
  final Color color;

  const TattooMachineIcon({
    super.key,
    this.size = 24.0,
    this.width,
    this.height,
    this.alignment = Alignment.center,
    this.color = const Color(0xFFEEC200),
  });

  @override
  Widget build(BuildContext context) {
    final effectiveHeight = height ?? size;
    final effectiveWidth = width ?? size;
    return SvgPicture.asset(
      'assets/images/tattoo_gun.svg',
      width: effectiveWidth,
      height: effectiveHeight,
      alignment: alignment,
      fit: BoxFit.contain,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}
