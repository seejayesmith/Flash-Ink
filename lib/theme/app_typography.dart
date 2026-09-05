import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Centralized typography foundation based on "Plus Jakarta Sans".
///
/// Implements the exact type scale and line-height specifications:
/// - Title: 40/50 Bold
/// - H1: 36/50 Bold
/// - H2: 32/50 Regular
/// - H3: 28/50 Regular
/// - H4: 24/50 Regular
/// - H5: 20/50 Regular
/// - Body Large: 18/24 Regular
/// - Body Large Bold: 18/50 Bold
/// - Body Med: 16/24 Regular
/// - Body Med Bold: 16/50 Bold
/// - Body Small: 12/14 Regular
/// - Body Small Bold: 12/16 Bold
/// - Label: 10/12 Regular
/// - Label Bold: 10/50 Bold
/// - Logo: 32/50
class AppTypography {
  static const String fontFamily = 'Plus Jakarta Sans';

  // ---------------------------------------------------------------------------
  // Headings & Titles
  // ---------------------------------------------------------------------------

  /// Title · 40/50 (Bold)
  static TextStyle get title => GoogleFonts.plusJakartaSans(
        fontSize: 40,
        height: 50 / 40,
        fontWeight: FontWeight.bold,
      );

  /// H1 · 36/50 (Bold)
  static TextStyle get h1 => GoogleFonts.plusJakartaSans(
        fontSize: 36,
        height: 50 / 36,
        fontWeight: FontWeight.bold,
      );

  /// H2 · 32/50 (Regular)
  static TextStyle get h2 => GoogleFonts.plusJakartaSans(
        fontSize: 32,
        height: 50 / 32,
        fontWeight: FontWeight.normal,
      );

  /// H3 · 28/50 (Regular)
  static TextStyle get h3 => GoogleFonts.plusJakartaSans(
        fontSize: 28,
        height: 50 / 28,
        fontWeight: FontWeight.normal,
      );

  /// H4 · 24/50 (Regular)
  static TextStyle get h4 => GoogleFonts.plusJakartaSans(
        fontSize: 24,
        height: 50 / 24,
        fontWeight: FontWeight.normal,
      );

  /// H5 · 20/50 (Regular)
  static TextStyle get h5 => GoogleFonts.plusJakartaSans(
        fontSize: 20,
        height: 50 / 20,
        fontWeight: FontWeight.normal,
      );

  // ---------------------------------------------------------------------------
  // Body Styles & Variants
  // ---------------------------------------------------------------------------

  /// Body Large · 18/24 (Regular)
  static TextStyle get bodyLarge => GoogleFonts.plusJakartaSans(
        fontSize: 18,
        height: 24 / 18,
        fontWeight: FontWeight.normal,
      );

  /// Body Large Bold · 18/50 (Bold)
  static TextStyle get bodyLargeBold => GoogleFonts.plusJakartaSans(
        fontSize: 18,
        height: 50 / 18,
        fontWeight: FontWeight.bold,
      );

  /// Body Med · 16/24 (Regular)
  static TextStyle get bodyMed => GoogleFonts.plusJakartaSans(
        fontSize: 16,
        height: 24 / 16,
        fontWeight: FontWeight.normal,
      );

  /// Body Med Bold · 16/50 (Bold)
  static TextStyle get bodyMedBold => GoogleFonts.plusJakartaSans(
        fontSize: 16,
        height: 50 / 16,
        fontWeight: FontWeight.bold,
      );

  /// Body Small · 12/14 (Regular)
  static TextStyle get bodySmall => GoogleFonts.plusJakartaSans(
        fontSize: 12,
        height: 14 / 12,
        fontWeight: FontWeight.normal,
      );

  /// Body Small Bold · 12/16 (Bold)
  static TextStyle get bodySmallBold => GoogleFonts.plusJakartaSans(
        fontSize: 12,
        height: 16 / 12,
        fontWeight: FontWeight.bold,
      );

  // ---------------------------------------------------------------------------
  // Labels & Logo
  // ---------------------------------------------------------------------------

  /// Label · 10/12 (Regular)
  static TextStyle get label => GoogleFonts.plusJakartaSans(
        fontSize: 10,
        height: 12 / 10,
        fontWeight: FontWeight.normal,
      );

  /// Label Bold · 10/50 (Bold)
  static TextStyle get labelBold => GoogleFonts.plusJakartaSans(
        fontSize: 10,
        height: 50 / 10,
        fontWeight: FontWeight.bold,
      );

  /// Logo · 32/50
  static TextStyle get logo => GoogleFonts.plusJakartaSans(
        fontSize: 32,
        height: 50 / 32,
        fontWeight: FontWeight.w600,
      );

  // ---------------------------------------------------------------------------
  // Material TextTheme Mapping for ThemeData
  // ---------------------------------------------------------------------------

  /// Creates a complete Material 3 TextTheme populated with Plus Jakarta Sans
  /// and aligned with the typography foundation scale.
  static TextTheme textTheme([Color defaultColor = const Color(0xFFF9FAFA)]) {
    final base = GoogleFonts.plusJakartaSansTextTheme();
    return base.copyWith(
      displayLarge: title.copyWith(color: defaultColor),
      displayMedium: h1.copyWith(color: defaultColor),
      displaySmall: h2.copyWith(color: defaultColor),
      headlineLarge: h2.copyWith(color: defaultColor),
      headlineMedium: h3.copyWith(color: defaultColor),
      headlineSmall: h4.copyWith(color: defaultColor),
      titleLarge: h3.copyWith(fontWeight: FontWeight.bold, color: defaultColor),
      titleMedium: h4.copyWith(fontWeight: FontWeight.bold, color: defaultColor),
      titleSmall: h5.copyWith(fontWeight: FontWeight.bold, color: defaultColor),
      bodyLarge: bodyLarge.copyWith(color: defaultColor),
      bodyMedium: bodyMed.copyWith(color: defaultColor),
      bodySmall: bodySmall.copyWith(color: const Color(0xFF919696)),
      labelLarge: bodySmallBold.copyWith(color: defaultColor),
      labelMedium: label.copyWith(color: const Color(0xFF919696)),
      labelSmall: label.copyWith(color: const Color(0xFF919696)),
    );
  }
}
