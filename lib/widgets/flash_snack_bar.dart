import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';

/// Marks a subtree as having a floating [FlashBottomNavBar] at the bottom
/// so [FlashSnackBar] automatically positions itself above the navigation pill.
class FlashNavBarScope extends InheritedWidget {
  final bool hasFloatingNavBar;

  const FlashNavBarScope({
    super.key,
    this.hasFloatingNavBar = true,
    required super.child,
  });

  static bool of(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<FlashNavBarScope>()
            ?.hasFloatingNavBar ??
        false;
  }

  @override
  bool updateShouldNotify(FlashNavBarScope oldWidget) =>
      hasFloatingNavBar != oldWidget.hasFloatingNavBar;
}

/// Semantic variants for [FlashSnackBar].
enum FlashSnackBarType {
  success,
  error,
  info,
}

/// Centralized utility for showing styled floating SnackBars across Flash.Ink.
class FlashSnackBar {
  static const Color errorColor = Color(0xFFF87171);
  static const Color successColor = Color(0xFF4ADE80);
  static const Color infoColor = AppTheme.gold;

  static const Color _surfaceColor = Color(0xEB191B1B);

  /// Sanitizes raw error strings (e.g. removing "Exception: ", "FirebaseException: ").
  static String sanitizeMessage(String message) {
    return message
        .replaceFirst(RegExp(r'^Exception:\s*'), '')
        .replaceFirst(RegExp(r'^FirebaseException:\s*'), '')
        .trim();
  }

  /// Displays a floating error SnackBar with a leading error badge and dismiss button.
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? showError(
    BuildContext context,
    String message, {
    SnackBarAction? action,
    Duration duration = const Duration(seconds: 4),
    EdgeInsetsGeometry? margin,
  }) {
    return _show(
      context,
      message: message,
      type: FlashSnackBarType.error,
      action: action,
      duration: duration,
      margin: margin,
    );
  }

  /// Displays a floating success SnackBar with a leading checkmark badge and dismiss button.
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? showSuccess(
    BuildContext context,
    String message, {
    SnackBarAction? action,
    Duration duration = const Duration(seconds: 3),
    EdgeInsetsGeometry? margin,
  }) {
    return _show(
      context,
      message: message,
      type: FlashSnackBarType.success,
      action: action,
      duration: duration,
      margin: margin,
    );
  }

  /// Displays a floating info SnackBar with a leading info badge and dismiss button.
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? showInfo(
    BuildContext context,
    String message, {
    SnackBarAction? action,
    Duration duration = const Duration(seconds: 3),
    EdgeInsetsGeometry? margin,
  }) {
    return _show(
      context,
      message: message,
      type: FlashSnackBarType.info,
      action: action,
      duration: duration,
      margin: margin,
    );
  }

  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? _show(
    BuildContext context, {
    required String message,
    required FlashSnackBarType type,
    SnackBarAction? action,
    required Duration duration,
    EdgeInsetsGeometry? margin,
  }) {
    if (!context.mounted) return null;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.clearSnackBars();

    final hasFloatingNavBar = FlashNavBarScope.of(context);
    final bottomMargin = hasFloatingNavBar
        ? AppTheme.navBarHeight + AppTheme.navBarBottomMargin + AppSpacing.spaceSm
        : AppSpacing.spaceMd;

    final resolvedMargin = margin ??
        EdgeInsets.fromLTRB(
          AppSpacing.screenGutter,
          0,
          AppSpacing.screenGutter,
          bottomMargin,
        );

    return scaffoldMessenger.showSnackBar(
      createSnackBar(
        message: sanitizeMessage(message),
        type: type,
        action: action,
        duration: duration,
        margin: resolvedMargin,
        onDismiss: scaffoldMessenger.hideCurrentSnackBar,
      ),
    );
  }

  /// Builds a standard styled floating SnackBar matching Flash.Ink's dark glassmorphic UI.
  static SnackBar createSnackBar({
    required String message,
    FlashSnackBarType type = FlashSnackBarType.info,
    Color? accentColor,
    IconData? icon,
    SnackBarAction? action,
    Duration duration = const Duration(seconds: 4),
    EdgeInsetsGeometry? margin,
    VoidCallback? onDismiss,
  }) {
    final resolvedAccent = accentColor ?? _accentForType(type);
    final resolvedIcon = icon ?? _iconForType(type);
    final borderColor = _borderForType(type, resolvedAccent);
    final radius = BorderRadius.circular(AppRadius.radiusLg);

    return SnackBar(
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      backgroundColor: Colors.transparent,
      padding: EdgeInsets.zero,
      duration: duration,
      margin: margin ??
          const EdgeInsets.fromLTRB(
            AppSpacing.screenGutter,
            0,
            AppSpacing.screenGutter,
            AppSpacing.spaceMd,
          ),
      content: Container(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(115),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: _surfaceColor,
                borderRadius: radius,
                border: Border.all(
                  color: borderColor,
                  width: 1.0,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: resolvedAccent.withAlpha(32),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      resolvedIcon,
                      color: resolvedAccent,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      message,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                        height: 1.3,
                      ),
                    ),
                  ),
                  if (action != null) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        action.onPressed();
                        onDismiss?.call();
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.goldContainer,
                          borderRadius: BorderRadius.circular(AppRadius.radiusSm),
                        ),
                        child: Text(
                          action.label,
                          style: GoogleFonts.plusJakartaSans(
                            color: action.textColor ?? AppTheme.gold,
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 4),
                  Builder(
                    builder: (innerContext) => InkWell(
                      onTap: onDismiss ??
                          () => ScaffoldMessenger.maybeOf(innerContext)
                              ?.hideCurrentSnackBar(),
                      borderRadius: BorderRadius.circular(AppRadius.radiusFull),
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(
                          Icons.close,
                          color: AppTheme.navInactive,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Color _accentForType(FlashSnackBarType type) {
    switch (type) {
      case FlashSnackBarType.success:
        return successColor;
      case FlashSnackBarType.error:
        return errorColor;
      case FlashSnackBarType.info:
        return infoColor;
    }
  }

  static IconData _iconForType(FlashSnackBarType type) {
    switch (type) {
      case FlashSnackBarType.success:
        return Icons.check_circle_outline_rounded;
      case FlashSnackBarType.error:
        return Icons.error_outline_rounded;
      case FlashSnackBarType.info:
        return Icons.info_outline_rounded;
    }
  }

  static Color _borderForType(FlashSnackBarType type, Color accent) {
    switch (type) {
      case FlashSnackBarType.success:
        return accent.withAlpha(80);
      case FlashSnackBarType.error:
        return accent.withAlpha(90);
      case FlashSnackBarType.info:
        return AppTheme.goldBorder.withAlpha(150);
    }
  }
}
