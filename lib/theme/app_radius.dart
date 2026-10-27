import 'package:flutter/material.dart';

/// Centralized corner radius scale.
class AppRadius {
  static const double dragHandle = 2.0; // modal sheet grab handles
  static const double radiusXs = 4.0; // badges, small tags
  static const double radiusSm = 8.0; // text fields, inner elements, toast notifications
  static const double radiusMd = 12.0; // standard cards, flash art cards, dialogs
  static const double radiusLg = 16.0; // prominent containers
  static const double radiusXl = 20.0; // hero containers, spotlight cards
  static const double radiusSheet = 28.0; // modal bottom sheets tracing hardware bezels
  static const double radiusFull = 999.0; // pills, primary CTA buttons, circular badges
}

/// Pre-configured BorderRadius helpers.
class AppBorderRadius {
  static final BorderRadius md = BorderRadius.circular(AppRadius.radiusMd);
  static final BorderRadius pill = BorderRadius.circular(AppRadius.radiusFull);
}

/// Pre-configured ShapeBorder helpers.
class AppShapes {
  static final RoundedRectangleBorder card = RoundedRectangleBorder(borderRadius: AppBorderRadius.md);
}
