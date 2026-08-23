import 'package:flutter/material.dart';

/// Centralized corner radius scale.
class AppRadius {
  static const double radiusNone = 0.0; // sharp corners
  static const double radiusXs = 4.0; // badges, small tags
  static const double radiusSm = 8.0; // text fields, inner elements, toast notifications
  static const double radiusMd = 12.0; // standard cards, flash art cards, dialogs
  static const double radiusLg = 16.0; // bottom sheets, prominent containers
  static const double radiusXl = 24.0; // floating action sheets, large modals
  static const double radiusFull = 999.0; // pills, primary CTA buttons, circular badges
}

/// Pre-configured BorderRadius helpers.
class AppBorderRadius {
  static final BorderRadius sm = BorderRadius.circular(AppRadius.radiusSm);
  static final BorderRadius md = BorderRadius.circular(AppRadius.radiusMd);
  static final BorderRadius lg = BorderRadius.circular(AppRadius.radiusLg);
  static final BorderRadius pill = BorderRadius.circular(AppRadius.radiusFull);
  
  static final BorderRadius topLg = BorderRadius.vertical(top: Radius.circular(AppRadius.radiusLg));
}

/// Pre-configured ShapeBorder helpers.
class AppShapes {
  static final RoundedRectangleBorder card = RoundedRectangleBorder(borderRadius: AppBorderRadius.md);
  static const StadiumBorder pillButton = StadiumBorder();
}
