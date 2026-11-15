import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/utils/device_corner_radius.dart';
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
  final bool avoidKeyboard;
  final double maxScreenHeightFraction;

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
    this.avoidKeyboard = true,
    this.maxScreenHeightFraction = 0.90,
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
    bool avoidKeyboard = true,
    double maxScreenHeightFraction = 0.90,
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
          avoidKeyboard: avoidKeyboard,
          maxScreenHeightFraction: maxScreenHeightFraction,
        );

  /// Edge clearance inset (in dp) applied to curved bottom sheets so borders
  /// sit concentrically inside the hardware display bezel without clipping.
  static const double sheetEdgeInset = 2.0;

  @override
  Widget build(BuildContext context) {
    if (!isBottomSheet) {
      return _buildCardSurface(context);
    }

    DeviceCornerRadius.ensureInitialized(Theme.of(context).platform);

    return ValueListenableBuilder<({double bottomLeft, double bottomRight})?>(
      valueListenable: DeviceCornerRadius.iosRadiiNotifier,
      builder: (context, _, _) => _buildBottomSheetSurface(context),
    );
  }

  static void _dismissKeyboard(BuildContext context) {
    FocusManager.instance.primaryFocus?.unfocus();
    FocusScope.of(context).unfocus();
  }

  static bool _hasEditableTextFocus() {
    final focusContext = FocusManager.instance.primaryFocus?.context;
    if (focusContext == null || !focusContext.mounted) return false;
    return focusContext.widget is EditableText ||
        focusContext.findAncestorStateOfType<EditableTextState>() != null;
  }

  Widget _buildCardSurface(BuildContext context) {
    final radius = (customBorderRadius as BorderRadius?) ?? BorderRadius.circular(borderRadius);
    final content = SizedBox(
      width: width,
      height: height,
      child: Container(
        padding: padding,
        child: child,
      ),
    );

    Widget surface = _buildSurfaceLayer(
      radius: radius,
      content: content,
      useSuperellipse: false,
    );

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

  Widget _buildBottomSheetSurface(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final rawRadii = DeviceCornerRadius.resolveBottomRadii(context);
    final hasHardwareCurve =
        viewInsets.bottom == 0 && (rawRadii.bottomLeft > 0 || rawRadii.bottomRight > 0);

    final bottomLeftRadius = hasHardwareCurve && rawRadii.bottomLeft > 0
        ? math.max(rawRadii.bottomLeft - sheetEdgeInset, 0.0)
        : 0.0;
    final bottomRightRadius = hasHardwareCurve && rawRadii.bottomRight > 0
        ? math.max(rawRadii.bottomRight - sheetEdgeInset, 0.0)
        : 0.0;

    final custom = customBorderRadius;
    final topL = custom is BorderRadius
        ? custom.topLeft
        : Radius.circular(borderRadius != AppRadius.radiusLg ? borderRadius : AppRadius.radiusSheet);
    final topR = custom is BorderRadius
        ? custom.topRight
        : Radius.circular(borderRadius != AppRadius.radiusLg ? borderRadius : AppRadius.radiusSheet);
    final radius = BorderRadius.only(
      topLeft: topL,
      topRight: topR,
      bottomLeft: Radius.circular(bottomLeftRadius),
      bottomRight: Radius.circular(bottomRightRadius),
    );

    final hasKeyboard = avoidKeyboard && viewInsets.bottom > 0;
    final Widget effectiveChild;
    if (hasKeyboard) {
      effectiveChild = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            fit: FlexFit.loose,
            child: Container(
              padding: padding,
              child: child,
            ),
          ),
          // Subtle hairline accent divider visually separating sheet content from keyboard
          Container(
            key: const Key('sheet_keyboard_hairline_divider'),
            height: 1.0,
            color: const Color(0xFF2E3232),
          ),
          // Spacer extending behind the software keyboard, filled with surface background
          SizedBox(
            key: const Key('sheet_keyboard_spacer'),
            height: viewInsets.bottom,
          ),
        ],
      );
    } else {
      effectiveChild = Container(
        padding: padding,
        child: SafeArea(
          top: false,
          bottom: true,
          child: child,
        ),
      );
    }

    final content = SizedBox(
      width: width,
      height: height,
      child: Material(
        type: MaterialType.transparency,
        child: effectiveChild,
      ),
    );

    Widget surface = _buildSurfaceLayer(
      radius: radius,
      content: content,
      useSuperellipse: true,
    );

    if (hasKeyboard) {
      final maxHeight = MediaQuery.sizeOf(context).height * maxScreenHeightFraction;
      surface = ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: surface,
      );
    }

    final effectiveMargin = margin ??
        EdgeInsets.fromLTRB(
          sheetEdgeInset,
          0,
          sheetEdgeInset,
          hasHardwareCurve ? sheetEdgeInset : 0.0,
        );
    surface = Padding(padding: effectiveMargin, child: surface);

    final interactiveSheet = GestureDetector(
      behavior: onTap != null ? HitTestBehavior.opaque : HitTestBehavior.translucent,
      onTap: () {
        _dismissKeyboard(context);
        onTap?.call();
      },
      child: surface,
    );

    return ListenableBuilder(
      listenable: FocusManager.instance,
      builder: (context, cachedChild) {
        final hasEditableFocus = _hasEditableTextFocus();
        return PopScope(
          canPop: !hasEditableFocus,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) {
              _dismissKeyboard(context);
            }
          },
          child: cachedChild!,
        );
      },
      child: interactiveSheet,
    );
  }

  Widget _buildSurfaceLayer({
    required BorderRadius radius,
    required Widget content,
    required bool useSuperellipse,
  }) {
    if (glassEnabled) {
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

      final shadows = isSelected
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
            ];

      final gradient = useGradient
          ? LinearGradient(
              begin: const Alignment(-0.8, -0.8), // Light angle -45°
              end: const Alignment(0.8, 0.8),
              colors: [
                const Color(0xFF1E2222).withAlpha(topAlpha),
                const Color(0xFF0F1111).withAlpha(bottomAlpha),
              ],
            )
          : null;
      final tintColor = useGradient ? null : const Color(0xFF1E2222).withAlpha(topAlpha);
      final borderSide = BorderSide(
        color: isSelected ? selectedBorderColor : unselectedBorderColor.withAlpha(90),
        width: isSelected ? selectedBorderWidth : unselectedBorderWidth,
        strokeAlign: BorderSide.strokeAlignInside,
      );

      final blurStack = BackdropFilter(
        // Silky liquid blur for superior background diffusion & legibility
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Stack(
          children: [
            // Layer 1: Base translucent liquid tint (refraction & high contrast translucency)
            Positioned.fill(
              child: Container(
                decoration: useSuperellipse
                    ? ShapeDecoration(
                        shape: RoundedSuperellipseBorder(borderRadius: radius),
                        color: tintColor,
                        gradient: gradient,
                      )
                    : BoxDecoration(
                        borderRadius: radius,
                        color: tintColor,
                        gradient: gradient,
                      ),
              ),
            ),
            // Layer 2: Subtle translucent border stroke & content container
            Container(
              width: width,
              height: height,
              decoration: useSuperellipse
                  ? ShapeDecoration(
                      shape: RoundedSuperellipseBorder(
                        borderRadius: radius,
                        side: borderSide,
                      ),
                    )
                  : BoxDecoration(
                      borderRadius: radius,
                      border: Border.fromBorderSide(borderSide),
                    ),
              child: content,
            ),
          ],
        ),
      );

      return Container(
        width: width,
        height: height,
        decoration: useSuperellipse
            ? ShapeDecoration(
                shape: RoundedSuperellipseBorder(borderRadius: radius),
                shadows: shadows,
              )
            : BoxDecoration(
                borderRadius: radius,
                boxShadow: shadows,
              ),
        child: useSuperellipse
            ? ClipRSuperellipse(borderRadius: radius, child: blurStack)
            : ClipRRect(borderRadius: radius, child: blurStack),
      );
    }

    final borderSide = BorderSide(
      color: isSelected ? selectedBorderColor : const Color(0xFF2E3232),
      width: isSelected ? selectedBorderWidth : unselectedBorderWidth,
      strokeAlign: BorderSide.strokeAlignInside,
    );
    final shadows = [
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
    ];

    if (useSuperellipse) {
      return Container(
        width: width,
        height: height,
        decoration: ShapeDecoration(
          color: androidSurfaceColor,
          shape: RoundedSuperellipseBorder(borderRadius: radius),
          shadows: shadows,
        ),
        foregroundDecoration: ShapeDecoration(
          shape: RoundedSuperellipseBorder(
            borderRadius: radius,
            side: borderSide,
          ),
        ),
        child: ClipRSuperellipse(
          borderRadius: radius,
          child: content,
        ),
      );
    }

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: androidSurfaceColor,
        borderRadius: radius,
        border: Border.fromBorderSide(borderSide),
        boxShadow: shadows,
      ),
      child: content,
    );
  }
}

