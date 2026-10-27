import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import 'skip_pill_button.dart';

/// A reusable, edge-to-edge liquid glassmorphic app bar.
///
/// Implements [PreferredSizeWidget] and wraps a standard [AppBar] with a
/// [BackdropFilter] flexibleSpace to provide silky frosted glass diffusion
/// as scrollable content passes behind the top bar.
class FlashGlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  /// Custom leading widget. If null and [showBackButton] is true, renders
  /// a minimal back arrow [IconButton].
  final Widget? leading;

  /// Optional app bar title.
  final Widget? title;

  /// Explicit actions list. If provided, overrides [onSkipPressed].
  final List<Widget>? actions;

  /// Custom callback for the default back arrow.
  final VoidCallback? onBackPressed;

  /// If provided and [actions] is null, renders an aligned [SkipPillButton].
  final VoidCallback? onSkipPressed;

  /// Key to assign to the automatic [SkipPillButton].
  final Key? skipButtonKey;

  /// Text for the automatic [SkipPillButton]. Defaults to 'Skip'.
  final String skipButtonText;

  /// Whether to display the default back arrow when [leading] is null.
  final bool showBackButton;

  /// Whether the title should be centered. Defaults to true.
  final bool centerTitle;

  /// Diffusion blur sigma. Defaults to [AppTheme.glassBlurSigma] (20.0).
  final double blurSigma;

  /// Subtle translucent liquid tint for readable contrast.
  /// Defaults to Color(0xFF1E2222) with alpha 90 (~35% opacity),
  /// matching [AdaptiveGlassContainer].
  final Color? surfaceColor;

  /// Height of the toolbar. Defaults to [kToolbarHeight].
  final double height;

  /// Optional bottom widget (e.g. TabBar or progress bar).
  final PreferredSizeWidget? bottom;

  /// Status bar overlay styling.
  final SystemUiOverlayStyle? systemOverlayStyle;

  const FlashGlassAppBar({
    super.key,
    this.leading,
    this.title,
    this.actions,
    this.onBackPressed,
    this.onSkipPressed,
    this.skipButtonKey,
    this.skipButtonText = 'Skip',
    this.showBackButton = true,
    this.centerTitle = true,
    this.blurSigma = 0.0,
    this.surfaceColor,
    this.height = kToolbarHeight,
    this.bottom,
    this.systemOverlayStyle,
  });

  @override
  Size get preferredSize =>
      Size.fromHeight(height + (bottom?.preferredSize.height ?? 0.0));

  @override
  Widget build(BuildContext context) {
    final effectiveLeading = leading ??
        (showBackButton
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFFF9FAFA)),
                onPressed: onBackPressed ?? () => Navigator.maybePop(context),
              )
            : null);

    final effectiveActions = actions ??
        (onSkipPressed != null
            ? [
                Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: Center(
                    child: SkipPillButton(
                      key: skipButtonKey,
                      text: skipButtonText,
                      onPressed: onSkipPressed,
                    ),
                  ),
                ),
              ]
            : null);

    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: systemOverlayStyle ??
          const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
          ),
      leading: effectiveLeading,
      title: title,
      centerTitle: centerTitle,
      actions: effectiveActions,
      bottom: bottom,
      flexibleSpace: (blurSigma > 0 || surfaceColor != null)
          ? ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
                child: Container(
                  color: surfaceColor ?? const Color(0xFF1E2222).withAlpha(90),
                ),
              ),
            )
          : null,
    );
  }
}
