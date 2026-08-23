import 'package:flutter/material.dart';

/// Centralized button geometry tokens and standard wrappers.
class AppButtons {
  // Core Geometry Tokens
  static const double ctaHeightPrimary = 42.0;
  static const double buttonHeightSm = 32.0;

  /// A standard primary Call-To-Action wrapper ensuring minimum tap target size,
  /// full width capability, strict pill shape, and non-shifting loading states.
  static Widget primaryCTA({
    required VoidCallback? onPressed,
    required String text,
    IconData? icon,
    bool isLoading = false,
    Color backgroundColor = const Color(0xFFEEC200),
    Color foregroundColor = const Color(0xFF121414),
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
        onPressed: null,
        style: style,
        child: const SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF121414)),
          ),
        ),
      );
    }

    final textWidget = Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
        fontSize: 15,
        height: 1.2,
      ),
    );

    if (icon != null) {
      return ElevatedButton.icon(
        onPressed: onPressed,
        style: style,
        icon: Icon(icon, size: 24),
        label: textWidget,
      );
    }

    return ElevatedButton(
      onPressed: onPressed,
      style: style,
      child: textWidget,
    );
  }
}
