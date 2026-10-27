import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_radius.dart';

/// Centralized utility for showing styled floating SnackBars across Flash.Ink.
class FlashSnackBar {
  static const Color errorColor = Color(0xFFEF4444);
  static const Color successColor = Color(0xFF22C55E);
  static const Color infoColor = Color(0xFF1E2020);

  /// Sanitizes raw error strings (e.g. removing "Exception: ", "FirebaseException: ").
  static String sanitizeMessage(String message) {
    return message
        .replaceFirst(RegExp(r'^Exception:\s*'), '')
        .replaceFirst(RegExp(r'^FirebaseException:\s*'), '')
        .trim();
  }

  /// Displays a floating red error SnackBar with a leading error icon and a close button.
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? showError(
    BuildContext context,
    String message, {
    SnackBarAction? action,
    Duration duration = const Duration(seconds: 4),
    EdgeInsetsGeometry? margin,
  }) {
    if (!context.mounted) return null;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.clearSnackBars();

    return scaffoldMessenger.showSnackBar(
      createSnackBar(
        message: sanitizeMessage(message),
        backgroundColor: errorColor,
        icon: Icons.error_outline_rounded,
        action: action,
        duration: duration,
        margin: margin,
      ),
    );
  }

  /// Displays a floating green success SnackBar with a leading checkmark icon and close button.
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? showSuccess(
    BuildContext context,
    String message, {
    SnackBarAction? action,
    Duration duration = const Duration(seconds: 3),
    EdgeInsetsGeometry? margin,
  }) {
    if (!context.mounted) return null;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.clearSnackBars();

    return scaffoldMessenger.showSnackBar(
      createSnackBar(
        message: sanitizeMessage(message),
        backgroundColor: successColor,
        icon: Icons.check_circle_outline_rounded,
        action: action,
        duration: duration,
        margin: margin,
      ),
    );
  }

  /// Displays a floating dark info SnackBar with a leading info icon and close button.
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? showInfo(
    BuildContext context,
    String message, {
    SnackBarAction? action,
    Duration duration = const Duration(seconds: 3),
    EdgeInsetsGeometry? margin,
  }) {
    if (!context.mounted) return null;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.clearSnackBars();

    return scaffoldMessenger.showSnackBar(
      createSnackBar(
        message: sanitizeMessage(message),
        backgroundColor: infoColor,
        icon: Icons.info_outline_rounded,
        action: action,
        duration: duration,
        margin: margin,
      ),
    );
  }

  /// Builds a standard styled floating SnackBar.
  static SnackBar createSnackBar({
    required String message,
    required Color backgroundColor,
    IconData? icon,
    SnackBarAction? action,
    Duration duration = const Duration(seconds: 4),
    EdgeInsetsGeometry? margin,
  }) {
    return SnackBar(
      behavior: SnackBarBehavior.floating,
      elevation: 6.0,
      shape: RoundedRectangleBorder(
        borderRadius: AppBorderRadius.md,
      ),
      backgroundColor: backgroundColor,
      duration: duration,
      showCloseIcon: true,
      closeIconColor: Colors.white,
      margin: margin,
      action: action,
      content: Row(
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              color: Colors.white,
              size: 20.0,
            ),
            const SizedBox(width: 10.0),
          ],
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14.0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
