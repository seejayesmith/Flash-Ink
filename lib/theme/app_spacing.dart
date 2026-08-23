import 'package:flutter/material.dart';

/// Centralized spatial scale based on an 8pt/8dp grid.
class AppSpacing {
  // Core Tokens
  static const double spaceXxs = 4.0; // 0.5x base - micro-spacing, badges, icons
  static const double spaceXs = 8.0; // 1.0x base - compact internal padding, inline items
  static const double spaceSm = 12.0; // 1.5x base - field gaps, tight card spacing
  static const double spaceMd = 16.0; // 2.0x base - standard screen margins, default container padding
  static const double spaceLg = 24.0; // 3.0x base - section breaks, header-to-body margins
  static const double spaceXl = 32.0; // 4.0x base - large module separation
  static const double spaceXxl = 48.0; // 6.0x base - hero banners, large section separators
}

/// Pre-configured EdgeInsets for consistent padding and margins.
class AppPadding {
  static const EdgeInsets screenHorizontal = EdgeInsets.symmetric(horizontal: AppSpacing.spaceMd);
  static const EdgeInsets screenVertical = EdgeInsets.symmetric(vertical: AppSpacing.spaceMd);
  static const EdgeInsets screenAll = EdgeInsets.all(AppSpacing.spaceMd);
  
  static const EdgeInsets card = EdgeInsets.all(AppSpacing.spaceSm);
  static const EdgeInsets cardLg = EdgeInsets.all(AppSpacing.spaceMd);
  
  static const EdgeInsets fieldHorizontal = EdgeInsets.symmetric(horizontal: AppSpacing.spaceSm);
}

/// Helper extension on num to easily add spacing (e.g., `16.gapVertical`).
extension AppSpacingExtension on num {
  SizedBox get gapVertical => SizedBox(height: toDouble());
  SizedBox get gapHorizontal => SizedBox(width: toDouble());
}

/// Pre-configured Spacer widgets for common vertical and horizontal gaps.
class AppGaps {
  static const SizedBox gapXxs = SizedBox(height: AppSpacing.spaceXxs, width: AppSpacing.spaceXxs);
  static const SizedBox gapXs = SizedBox(height: AppSpacing.spaceXs, width: AppSpacing.spaceXs);
  static const SizedBox gapSm = SizedBox(height: AppSpacing.spaceSm, width: AppSpacing.spaceSm);
  static const SizedBox gapMd = SizedBox(height: AppSpacing.spaceMd, width: AppSpacing.spaceMd);
  static const SizedBox gapLg = SizedBox(height: AppSpacing.spaceLg, width: AppSpacing.spaceLg);
  static const SizedBox gapXl = SizedBox(height: AppSpacing.spaceXl, width: AppSpacing.spaceXl);
  static const SizedBox gapXxl = SizedBox(height: AppSpacing.spaceXxl, width: AppSpacing.spaceXxl);
}
