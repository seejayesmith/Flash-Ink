import 'dart:ui';
import 'package:flutter/material.dart';

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
  final bool isSelected;
  final Color selectedBorderColor;
  final Color unselectedBorderColor;
  final double selectedBorderWidth;
  final double unselectedBorderWidth;
  final Color androidSurfaceColor;
  final double blurSigma;
  final int? baseTintAlpha;
  final bool glassEnabled;
  final VoidCallback? onTap;

  const AdaptiveGlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 16.0,
    this.customBorderRadius,
    this.padding,
    this.margin,
    this.isSelected = false,
    this.selectedBorderColor = const Color(0xFFEEC200),
    this.unselectedBorderColor = const Color(0xFF8C7E55),
    this.selectedBorderWidth = 2.0,
    this.unselectedBorderWidth = 1.0,
    this.androidSurfaceColor = const Color(0xFF1E2020),
    this.blurSigma = 16.0, // Silky liquid diffusion for high contrast & legibility
    this.baseTintAlpha,
    this.glassEnabled = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = (customBorderRadius as BorderRadius?) ?? BorderRadius.circular(borderRadius);

    Widget content = Container(
      padding: padding,
      child: child,
    );

    Widget surface;
    if (glassEnabled) {
      // 💎 High-fidelity Liquid Glass View
      final topAlpha = baseTintAlpha ?? (isSelected ? 165 : 130);
      final bottomAlpha = baseTintAlpha != null ? (baseTintAlpha! + 25).clamp(0, 255) : (isSelected ? 190 : 155);

      surface = ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          // Silky liquid blur for superior background diffusion & legibility
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Stack(
            children: [
              // Layer 1: Base dark liquid tint (refraction & high contrast translucency)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: radius,
                    gradient: LinearGradient(
                      begin: const Alignment(-0.8, -0.8), // Light angle -45°
                      end: const Alignment(0.8, 0.8),
                      colors: [
                        const Color(0xFF1E2222).withAlpha(topAlpha),
                        const Color(0xFF0F1111).withAlpha(bottomAlpha),
                      ],
                    ),
                  ),
                ),
              ),

              // Layer 2: Light reflection & Splay 44 (-45° specular light highlight)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: radius,
                    gradient: LinearGradient(
                      begin: const Alignment(-1.0, -1.0),
                      end: const Alignment(0.6, 0.6),
                      colors: [
                        Colors.white.withAlpha(isSelected ? 50 : 35), // Liquid specular light reflection
                        Colors.white.withAlpha(12),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.30, 0.75],
                    ),
                  ),
                ),
              ),

              // Layer 3: Golden/light bevel border stroke & selection aura
              Container(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  border: Border.all(
                    color: isSelected
                        ? selectedBorderColor
                        : unselectedBorderColor.withAlpha(90),
                    width: isSelected ? selectedBorderWidth : unselectedBorderWidth,
                  ),
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
                child: content,
              ),
            ],
          ),
        ),
      );
    } else {
      // Material Surface Container fallback
      surface = Container(
        decoration: BoxDecoration(
          color: androidSurfaceColor,
          borderRadius: radius,
          border: Border.all(
            color: isSelected
                ? selectedBorderColor
                : const Color(0xFF2E3232),
            width: isSelected ? selectedBorderWidth : unselectedBorderWidth,
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

    if (margin != null) {
      surface = Padding(padding: margin!, child: surface);
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
