import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Centralized button geometry tokens and standard wrappers.
class AppButtons {
  // Core Geometry Tokens
  static const double ctaHeightPrimary = 44.0;
  static const double ctaBorderRadius = 22.0;
  static const double ctaHorizontalPadding = 16.0;

  static Widget _buildCtaChild({
    required String text,
    IconData? icon,
    required bool isLoading,
    required Color foregroundColor,
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w700,
    double letterSpacing = 0.8,
  }) {
    if (isLoading) {
      return SizedBox(
        height: 18,
        width: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(foregroundColor),
        ),
      );
    }

    final textWidget = Text(
      text,
      maxLines: 1,
      softWrap: false,
      style: GoogleFonts.plusJakartaSans(
        fontWeight: fontWeight,
        letterSpacing: letterSpacing,
        fontSize: fontSize,
        height: 1.2,
      ),
    );

    final content = icon != null
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 8),
              textWidget,
            ],
          )
        : textWidget;

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: content,
    );
  }

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
      padding: const EdgeInsets.symmetric(horizontal: ctaHorizontalPadding),
    );

    return ElevatedButton(
      key: key,
      onPressed: isLoading ? null : onPressed,
      style: style,
      child: _buildCtaChild(
        text: text,
        icon: icon,
        isLoading: isLoading,
        foregroundColor: foregroundColor,
      ),
    );
  }

  /// A standard secondary/outlined Call-To-Action wrapper sharing pill
  /// geometry (44 dp) with a slightly lighter, more balanced typographic weight
  /// so side-by-side and secondary actions sit cleanly below primary CTAs.
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
    double fontSize = 13.0,
    FontWeight fontWeight = FontWeight.w600,
    double letterSpacing = 0.25,
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
      padding: const EdgeInsets.symmetric(horizontal: ctaHorizontalPadding),
    );

    return OutlinedButton(
      key: key,
      onPressed: isLoading ? null : onPressed,
      style: style,
      child: _buildCtaChild(
        text: text,
        icon: icon,
        isLoading: isLoading,
        foregroundColor: foregroundColor,
        fontSize: fontSize,
        fontWeight: fontWeight,
        letterSpacing: letterSpacing,
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: ctaHorizontalPadding),
    );

    return ElevatedButton(
      key: key,
      onPressed: isLoading ? null : onPressed,
      style: style,
      child: _buildCtaChild(
        text: text,
        icon: icon,
        isLoading: isLoading,
        foregroundColor: foregroundColor,
      ),
    );
  }
}
