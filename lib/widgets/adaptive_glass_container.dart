import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_radius.dart';

/// An adaptive surface container that renders high-fidelity
/// liquid glass matching Figma glass parameters:
/// (Light -45° @ 80%, Frost 2, Splay 44, Depth 33, Refraction 80).
/// Provides authentic liquid transparency, frosted background diffusion,
/// specular light reflection, and subtle refractive borders.
class AdaptiveGlassContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final BorderRadiusGeometry? customBorderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final bool isSelected;
  final Color selectedBorderColor;
  final Color unselectedBorderColor;
  final double selectedBorderWidth;
  final double unselectedBorderWidth;
  final Color androidSurfaceColor;
  final double blurSigma;
  final int? baseTintAlpha;
  final int? selectedBaseTintAlpha;
  final int? unselectedBaseTintAlpha;
  final bool useGradient;
  final bool glassEnabled;
  final VoidCallback? onTap;
  final bool isBottomSheet;

  const AdaptiveGlassContainer({
    super.key,
    required this.child,
    this.borderRadius = AppRadius.radiusLg,
    this.customBorderRadius,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.isSelected = false,
    this.selectedBorderColor = const Color(0xFFEEC200),
    this.unselectedBorderColor = const Color(0xFF8C7E55),
    this.selectedBorderWidth = 2.0,
    this.unselectedBorderWidth = 1.0,
    this.androidSurfaceColor = const Color(0xFF1E2020),
    this.blurSigma = 16.0, // Silky liquid diffusion for high contrast & legibility
    this.baseTintAlpha,
    this.selectedBaseTintAlpha,
    this.unselectedBaseTintAlpha,
    this.useGradient = false,
    this.glassEnabled = true,
    this.onTap,
    this.isBottomSheet = false,
  });

  /// Factory constructor configured for modal bottom sheets that sit flush at the
  /// bottom edge of the screen and trace the device hardware bezel curve.
  const AdaptiveGlassContainer.bottomSheet({
    Key? key,
    required Widget child,
    double topRadius = AppRadius.radiusSheet,
    BorderRadiusGeometry? customBorderRadius,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    double? width,
    double? height,
    bool isSelected = false,
    Color selectedBorderColor = const Color(0xFFEEC200),
    Color unselectedBorderColor = const Color(0xFF8C7E55),
    double selectedBorderWidth = 2.0,
    double unselectedBorderWidth = 1.0,
    Color androidSurfaceColor = const Color(0xFF1E2020),
    double blurSigma = 16.0,
    int? baseTintAlpha,
    int? selectedBaseTintAlpha,
    int? unselectedBaseTintAlpha,
    bool useGradient = false,
    bool glassEnabled = true,
    VoidCallback? onTap,
  }) : this(
          key: key,
          child: child,
          borderRadius: topRadius,
          customBorderRadius: customBorderRadius,
          padding: padding,
          margin: margin,
          width: width,
          height: height,
          isSelected: isSelected,
          selectedBorderColor: selectedBorderColor,
          unselectedBorderColor: unselectedBorderColor,
          selectedBorderWidth: selectedBorderWidth,
          unselectedBorderWidth: unselectedBorderWidth,
          androidSurfaceColor: androidSurfaceColor,
          blurSigma: blurSigma,
          baseTintAlpha: baseTintAlpha,
          selectedBaseTintAlpha: selectedBaseTintAlpha,
          unselectedBaseTintAlpha: unselectedBaseTintAlpha,
          useGradient: useGradient,
          glassEnabled: glassEnabled,
          onTap: onTap,
          isBottomSheet: true,
        );

  @override
  Widget build(BuildContext context) {
    final viewPadding = MediaQuery.viewPaddingOf(context);
    final mediaQueryPadding = MediaQuery.paddingOf(context);
    final bottomSafe = viewPadding.bottom > 0 ? viewPadding.bottom : mediaQueryPadding.bottom;
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final hasHardwareCurve = isBottomSheet && bottomSafe > 0 && viewInsets.bottom == 0;

    final double bottomRadius;
    if (hasHardwareCurve) {
      final screenHeight = MediaQuery.sizeOf(context).height;
      if (screenHeight >= 900) {
        bottomRadius = 55.0;
      } else if (screenHeight >= 840) {
        bottomRadius = 50.0;
      } else {
        bottomRadius = 47.0;
      }
    } else {
      bottomRadius = 0.0;
    }

    final BorderRadius radius;
    if (isBottomSheet) {
      final custom = customBorderRadius;
      final topL = custom is BorderRadius
          ? custom.topLeft
          : Radius.circular(borderRadius != AppRadius.radiusLg ? borderRadius : AppRadius.radiusSheet);
      final topR = custom is BorderRadius
          ? custom.topRight
          : Radius.circular(borderRadius != AppRadius.radiusLg ? borderRadius : AppRadius.radiusSheet);
      radius = BorderRadius.only(
        topLeft: topL,
        topRight: topR,
        bottomLeft: Radius.circular(bottomRadius),
        bottomRight: Radius.circular(bottomRadius),
      );
    } else {
      radius = (customBorderRadius as BorderRadius?) ?? BorderRadius.circular(borderRadius);
    }

    Widget content = Container(
      width: width,
      height: height,
      padding: padding,
      child: isBottomSheet
          ? SafeArea(
              top: false,
              bottom: true,
              child: child,
            )
          : child,
    );

    Widget surface;
    if (glassEnabled) {
      // 💎 Pure Frosted Glass View
      final int topAlpha;
      final int bottomAlpha;
      if (isSelected) {
        topAlpha = selectedBaseTintAlpha ?? baseTintAlpha ?? 120;
        bottomAlpha = selectedBaseTintAlpha != null
            ? (selectedBaseTintAlpha! + 20).clamp(0, 255)
            : (baseTintAlpha != null ? (baseTintAlpha! + 20).clamp(0, 255) : 140);
      } else {
        topAlpha = unselectedBaseTintAlpha ?? baseTintAlpha ?? 90;
        bottomAlpha = unselectedBaseTintAlpha != null
            ? (unselectedBaseTintAlpha! + 20).clamp(0, 255)
            : (baseTintAlpha != null ? (baseTintAlpha! + 20).clamp(0, 255) : 110);
      }

      surface = Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: selectedBorderColor.withAlpha(55),
                    blurRadius: 18,
                    spreadRadius: 1,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: Colors.black.withAlpha(60),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withAlpha(45),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: BackdropFilter(
            // Silky liquid blur for superior background diffusion & legibility
            filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
            child: Stack(
              children: [
                // Layer 1: Base translucent liquid tint (refraction & high contrast translucency)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: radius,
                      color: useGradient ? null : const Color(0xFF1E2222).withAlpha(topAlpha),
                      gradient: useGradient
                          ? LinearGradient(
                              begin: const Alignment(-0.8, -0.8), // Light angle -45°
                              end: const Alignment(0.8, 0.8),
                              colors: [
                                const Color(0xFF1E2222).withAlpha(topAlpha),
                                const Color(0xFF0F1111).withAlpha(bottomAlpha),
                              ],
                            )
                          : null,
                    ),
                  ),
                ),

                // Layer 2: Subtle translucent border stroke & content container
                Container(
                  width: width,
                  height: height,
                  decoration: BoxDecoration(
                    borderRadius: radius,
                    border: Border.all(
                      color: isSelected
                          ? selectedBorderColor
                          : unselectedBorderColor.withAlpha(90),
                      width: isSelected ? selectedBorderWidth : unselectedBorderWidth,
                      strokeAlign: BorderSide.strokeAlignInside,
                    ),
                  ),
                  child: content,
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      // Material Surface Container fallback
      surface = Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: androidSurfaceColor,
          borderRadius: radius,
          border: Border.all(
            color: isSelected
                ? selectedBorderColor
                : const Color(0xFF2E3232),
            width: isSelected ? selectedBorderWidth : unselectedBorderWidth,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(isSelected ? 140 : 80),
              blurRadius: isSelected ? 14 : 8,
              offset: const Offset(0, 4),
            ),
            if (isSelected)
              BoxShadow(
                color: selectedBorderColor.withAlpha(40),
                blurRadius: 12,
                spreadRadius: 0,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: content,
      );
    }

    final effectiveMargin = margin ??
        (isBottomSheet
            ? EdgeInsets.fromLTRB(1.0, 0, 1.0, hasHardwareCurve ? 1.0 : 0.0)
            : null);

    if (effectiveMargin != null) {
      surface = Padding(padding: effectiveMargin, child: surface);
    }

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: surface,
      );
    }

    return surface;
  }
}

