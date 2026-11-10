import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Centralized button geometry tokens and standard wrappers.
class AppButtons {
  // Core Geometry Tokens
  static const double ctaHeightPrimary = 44.0;
  static const double ctaBorderRadius = 22.0;

  /// A standard primary Call-To-Action wrapper ensuring minimum tap target size,
  /// full width capability, strict pill shape, and non-shifting loading states.
  static Widget primaryCTA({
    Key? key,
    required VoidCallback? onPressed,
    required String text,
    IconData? icon,
    bool isLoading = false,
    Color backgroundColor = const Color(0xFFEEC200),
    Color foregroundColor = const Color(0xFF121414),
    Color? disabledBackgroundColor,
    Color? disabledForegroundColor,
    double width = double.infinity,
  }) {
    final style = ElevatedButton.styleFrom(
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      disabledBackgroundColor: disabledBackgroundColor,
      disabledForegroundColor: disabledForegroundColor,
      minimumSize: Size(width, ctaHeightPrimary),
      maximumSize: Size(width, ctaHeightPrimary),
      tapTargetSize: MaterialTapTargetSize.padded,
      shape: const StadiumBorder(),
      elevation: 0,
      padding: EdgeInsets.zero,
    );

    if (isLoading) {
      return ElevatedButton(
        key: key,
        onPressed: null,
        style: style,
        child: SizedBox(
          height: 18,
          width: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(foregroundColor),
          ),
        ),
      );
    }

    final textWidget = Text(
      text,
      style: GoogleFonts.plusJakartaSans(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        fontSize: 14,
        height: 1.2,
      ),
    );

    if (icon != null) {
      return ElevatedButton.icon(
        key: key,
        onPressed: onPressed,
        style: style,
        icon: Icon(icon, size: 20),
        label: textWidget,
      );
    }

    return ElevatedButton(
      key: key,
      onPressed: onPressed,
      style: style,
      child: textWidget,
    );
  }

  /// A standard secondary/outlined Call-To-Action wrapper sharing identical
  /// pill geometry (44 dp) and typography with the primary CTA.
  static Widget secondaryCTA({
    Key? key,
    required VoidCallback? onPressed,
    required String text,
    IconData? icon,
    bool isLoading = false,
    Color borderColor = const Color(0xFF4D4530),
    Color foregroundColor = const Color(0xFFEEC200),
    Color backgroundColor = Colors.transparent,
    double width = double.infinity,
  }) {
    final style = OutlinedButton.styleFrom(
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      side: BorderSide(color: borderColor, width: 1.2),
      minimumSize: Size(width, ctaHeightPrimary),
      maximumSize: Size(width, ctaHeightPrimary),
      tapTargetSize: MaterialTapTargetSize.padded,
      shape: const StadiumBorder(),
      elevation: 0,
      padding: EdgeInsets.zero,
    );

    if (isLoading) {
      return OutlinedButton(
        key: key,
        onPressed: null,
        style: style,
        child: SizedBox(
          height: 18,
          width: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(foregroundColor),
          ),
        ),
      );
    }

    final textWidget = Text(
      text,
      style: GoogleFonts.plusJakartaSans(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        fontSize: 14,
        height: 1.2,
      ),
    );

    if (icon != null) {
      return OutlinedButton.icon(
        key: key,
        onPressed: onPressed,
        style: style,
        icon: Icon(icon, size: 20),
        label: textWidget,
      );
    }

    return OutlinedButton(
      key: key,
      onPressed: onPressed,
      style: style,
      child: textWidget,
    );
  }

  /// A standard destructive Call-To-Action wrapper for critical actions
  /// (e.g. Cancel Appointment, Delete Account).
  static Widget destructiveCTA({
    Key? key,
    required VoidCallback? onPressed,
    required String text,
    IconData? icon,
    bool isLoading = false,
    Color backgroundColor = const Color(0xFFEF4444),
    Color foregroundColor = Colors.white,
    double width = double.infinity,
  }) {
    final style = ElevatedButton.styleFrom(
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      minimumSize: Size(width, ctaHeightPrimary),
      maximumSize: Size(width, ctaHeightPrimary),
      tapTargetSize: MaterialTapTargetSize.padded,
      shape: const StadiumBorder(),
      elevation: 0,
      padding: EdgeInsets.zero,
    );

    if (isLoading) {
      return ElevatedButton(
        key: key,
        onPressed: null,
        style: style,
        child: SizedBox(
          height: 18,
          width: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(foregroundColor),
          ),
        ),
      );
    }

    final textWidget = Text(
      text,
      style: GoogleFonts.plusJakartaSans(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        fontSize: 14,
        height: 1.2,
      ),
    );

    if (icon != null) {
      return ElevatedButton.icon(
        key: key,
        onPressed: onPressed,
        style: style,
        icon: Icon(icon, size: 20),
        label: textWidget,
      );
    }

    return ElevatedButton(
      key: key,
      onPressed: onPressed,
      style: style,
      child: textWidget,
    );
  }
}
