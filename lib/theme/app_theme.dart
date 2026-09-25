import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_typography.dart';

/// Centralized design tokens and theme constants for Flash.Ink.
///
/// Provides consistent colors, geometry, glassmorphism parameters,
/// and navigation tokens across both Client and Artist interfaces.
class AppTheme {
  // ---------------------------------------------------------------------------
  // Core Color Tokens
  // ---------------------------------------------------------------------------

  /// Signature primary gold accent.
  static const Color gold = Color(0xFFEEC200);

  /// Semi-transparent gold for active container pills (~14% opacity).
  static const Color goldContainer = Color(0x24EEC200);

  /// Translucent charcoal/gray tint for the active navigation destination pill (~12% white opacity over glass).
  static const Color navActivePillBackground = Color(0x1FFFFFFF);

  /// Refined border stroke color with warm gold undertones.
  static const Color goldBorder = Color(0xFF4D4530);

  /// Deep onyx background for screens and edge-to-edge layouts.
  static const Color onyxBackground = Color(0xFF121414);

  /// Primary onyx surface color for docked elements and bottom bars.
  static const Color onyxSurface = Color(0xFF141616);

  /// Elevated card & sheet container color.
  static const Color onyxContainer = Color(0xFF1E2020);

  /// Subtle dark divider & border line color.
  static const Color darkBorder = Color(0xFF2E3232);

  /// Muted grey for unselected icons and inactive labels.
  static const Color navInactive = Color(0xFF919696);

  /// Secondary muted grey for artist components and metadata.
  static const Color navInactiveAlt = Color(0xFF8C9191);

  /// Bright primary text color.
  static const Color textPrimary = Color(0xFFF9FAFA);

  /// Background color for books open / verified badges.
  static const Color goldBadgeBackground = Color(0xFF38351F);

  /// Border color for gold badges.
  static const Color goldBadgeBorder = Color(0xFF7A6B29);

  /// Surface color for cards, flash tiles, and policy containers.
  static const Color cardBackground = Color(0xFF171A1A);

  /// Border color for standard cards and flash tiles.
  static const Color cardBorder = Color(0xFF262929);

  /// Subtle divider color for stat rows.
  static const Color statDivider = Color(0xFF2A2E2E);

  /// Active favorite heart color.
  static const Color favoriteActive = Color(0xFFEF4444);

  /// Action icon container background color.
  static const Color actionButtonBackground = Color(0xFF1E2020);

  /// Action icon container border color.
  static const Color actionButtonBorder = Color(0xFF333737);

  /// Border color for artist avatar stroke.
  static const Color avatarBorder = Color(0xFF5A4D2E);

  /// Shimmer base color for image placeholders.
  static const Color shimmerBase = Color(0xFF1E2020);

  /// Shimmer highlight color for image placeholders.
  static const Color shimmerHighlight = Color(0xFF2E3232);

  // ---------------------------------------------------------------------------
  // Glassmorphic Surface Tokens (Figma Spec)
  // ---------------------------------------------------------------------------

  /// Gradient top tint for liquid glass refraction (-45° light angle).
  static const Color glassTopTint = Color(0xFF1E2222);

  /// Gradient bottom tint for dark refraction contrast.
  static const Color glassBottomTint = Color(0xFF0F1111);

  /// Default alpha channel for liquid glass backdrop.
  static const int glassBaseTintAlpha = 175;

  /// Default blur radius for silky background diffusion.
  static const double glassBlurSigma = 20.0;

  /// Default border stroke color for liquid glass pills.
  static const Color glassBorderColor = Color(0xFF4D4530);

  /// Glass border width.
  static const double glassBorderWidth = 1.5;

  // ---------------------------------------------------------------------------
  // Bottom Navigation Bar Geometry Tokens
  // ---------------------------------------------------------------------------

  /// Total standard height of the bottom navigation bar container.
  static const double navBarHeight = 64.0;

  /// Pill corner radius ensuring strict stadium curvature.
  static const double navBarBorderRadius = 36.0;

  /// Horizontal margin from screen edge for floating positioning.
  static const double navBarHorizontalMargin = 20.0;

  /// Vertical margin above the system navigation / home bar safe area.
  static const double navBarBottomMargin = 12.0;

  /// Internal padding for the floating navigation pill container.
  static const EdgeInsets navBarPadding = EdgeInsets.symmetric(
    horizontal: 6.0,
    vertical: 2.0,
  );

  /// Padding around each individual destination item.
  static const EdgeInsets navItemPadding = EdgeInsets.symmetric(
    horizontal: 10.0,
    vertical: 4.0,
  );

  /// Corner radius for active destination indicator pill.
  static const double navItemBorderRadius = 20.0;

  /// Icon size for navigation destinations.
  static const double navIconSize = 22.0;

  /// Spacing between destination icon and text label.
  static const double navIconLabelSpacing = 2.0;

  /// Minimum touch target size meeting accessibility standards (48x48dp).
  static const Size navItemMinTouchTarget = Size(48.0, 48.0);

  /// Animation duration for active destination state transitions.
  static const Duration navAnimationDuration = Duration(milliseconds: 280);

  /// Animation curve for fluid liquid glass destination transitions.
  static const Curve navAnimationCurve = Curves.easeInOutCubic;

  // ---------------------------------------------------------------------------
  // Navigation Typography Tokens
  // ---------------------------------------------------------------------------

  /// Active destination label style.
  static TextStyle get navLabelActive => GoogleFonts.plusJakartaSans(
        fontSize: 10.0,
        height: 1.1,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.6,
        color: gold,
      );

  /// Inactive destination label style.
  static TextStyle get navLabelInactive => GoogleFonts.plusJakartaSans(
        fontSize: 10.0,
        height: 1.1,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.6,
        color: navInactive,
      );

  /// Standard drop shadow for floating navigation pills.
  static List<BoxShadow> get navBarShadow => [
        BoxShadow(
          color: Colors.black.withAlpha(90),
          blurRadius: 18.0,
          spreadRadius: 1.0,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: Colors.black.withAlpha(50),
          blurRadius: 8.0,
          offset: const Offset(0, 2),
        ),
      ];

  // ---------------------------------------------------------------------------
  // ThemeData Integration
  // ---------------------------------------------------------------------------

  /// Creates a unified dark ThemeData configured with centralized tokens.
  static ThemeData darkTheme() {
    return ThemeData(
      useMaterial3: true,
      textTheme: AppTypography.textTheme(),
      colorScheme: ColorScheme.fromSeed(
        seedColor: gold,
        brightness: Brightness.dark,
        primary: gold,
        surface: onyxSurface,
      ),
      scaffoldBackgroundColor: onyxBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }
}
