import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';

/// Standardized empty state widget for client-facing screens.
///
/// Ensures optical vertical centering by factoring in the floating bottom
/// navigation bar height and device safe area. Also supports reserving space
/// for action buttons and normalizing text heights to maintain seamless,
/// jitter-free tab transitions without relying on speculative layout intrinsics.
class ClientEmptyState extends StatelessWidget {
  /// The icon displayed inside the circular badge.
  final IconData icon;

  /// Primary bold headline text.
  final String title;

  /// Secondary muted descriptive text.
  final String subtitle;

  /// Optional action widget (e.g. CTA button) placed below the subtitle.
  final Widget? action;

  /// When true and [action] is null, reserves [actionHeight] so that icon
  /// and text coordinates align identically with sibling tabs that show an action.
  final bool reserveActionSpace;

  /// The vertical clearance reserved when [reserveActionSpace] is true and [action] is null.
  /// Defaults to 68.0 (20.0 spacing + 48.0 standard primary CTA button height).
  final double actionHeight;

  /// Optional minimum height constraint for the title block to normalize multi-line titles.
  final double? minTitleHeight;

  /// Optional minimum height constraint for the subtitle block to normalize multi-line subtitles.
  final double? minSubtitleHeight;

  /// Whether the screen is viewed over the root floating navigation bar shell.
  final bool hasFloatingNavBar;

  /// Optional custom bottom inset override. When provided, takes precedence over
  /// the automatic floating navigation bar offset.
  final double? customBottomReserved;

  /// Key identifying the circular icon container for testing.
  final Key? iconKey;

  const ClientEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
    this.reserveActionSpace = false,
    this.actionHeight = 68.0,
    this.minTitleHeight,
    this.minSubtitleHeight,
    this.hasFloatingNavBar = true,
    this.customBottomReserved,
    this.iconKey,
  });

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final bottomReserved = customBottomReserved ??
        (hasFloatingNavBar
            ? (safeBottom + AppTheme.navBarBottomMargin + AppTheme.navBarHeight)
            : 0.0);

    return Padding(
      padding: EdgeInsets.only(bottom: bottomReserved),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spaceXl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Circular icon badge
              Container(
                key: iconKey,
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.onyxContainer,
                  border: Border.all(color: AppTheme.darkBorder),
                ),
                child: Icon(
                  icon,
                  color: AppTheme.gold,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),

              // Title with top-aligned line 1
              ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: minTitleHeight ?? 0.0,
                ),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),

              // Subtitle with top-aligned line 1
              ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: minSubtitleHeight ?? 0.0,
                ),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.navInactive,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
              ),

              // Action or reserved clearance
              if (action != null) ...[
                const SizedBox(height: 20),
                action!,
              ] else if (reserveActionSpace) ...[
                SizedBox(height: actionHeight),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
