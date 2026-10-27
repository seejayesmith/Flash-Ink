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
  // Standard Screen & Component Tokens
  static const double screenGutter = 12.0; // Canonical horizontal keyline (1.5x base)
  static const double screenMargin = screenGutter; // Standard screen horizontal margin (12.0)
  static const double cardPadding = 16.0; // Uniform internal padding for glass cards
  static const double headerTop = 24.0; // Vertical distance below app bar / stepper to header title
  static const double headerTitleSubtitleGap = 8.0; // Gap between title and subtitle
  static const double headerContentGap = 24.0; // Gap between header subtitle and content card
  static const double ctaHeight = 52.0; // Primary Call-To-Action button height
  static const double ctaBottomPadding = 16.0; // Padding between bottom safe area and CTA
}

/// Pre-configured EdgeInsets for consistent padding and margins.
class AppPadding {
  static const EdgeInsets screenHorizontal = EdgeInsets.symmetric(horizontal: AppSpacing.screenMargin);
  static const EdgeInsets card = EdgeInsets.all(AppSpacing.cardPadding);
  static const EdgeInsets screenContent = EdgeInsets.fromLTRB(
    AppSpacing.screenMargin,
    AppSpacing.headerTop,
    AppSpacing.screenMargin,
    AppSpacing.ctaBottomPadding,
  );
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

  // Semantic Flow Gaps
  static const SizedBox headerTitleSubtitle = SizedBox(height: AppSpacing.headerTitleSubtitleGap);
  static const SizedBox headerContent = SizedBox(height: AppSpacing.headerContentGap);
  static const SizedBox belowAppBar = SizedBox(height: AppSpacing.headerTop);
}
