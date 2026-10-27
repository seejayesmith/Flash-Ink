import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_buttons.dart';
import '../theme/app_spacing.dart';

/// Standardized layout container for onboarding and multi-step flow screens.
/// 
/// Enforces consistent spatial rules across the app:
/// - 20px horizontal screen margins (`AppSpacing.screenMargin`)
/// - 24px top spacing below the app bar / stepper (`AppSpacing.headerTop`)
/// - Fixed top-aligned headers (no vertical position jumping across steps)
/// - 8px title-to-subtitle gap (`AppSpacing.headerTitleSubtitleGap`)
/// - 24px subtitle-to-content gap (`AppSpacing.headerContentGap`)
/// - 52px bottom-anchored CTA button outside the scroll area (never layered over content)
class FlowPageLayout extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final Widget? headerWidget;
  final Widget child;
  final Widget? bottomBar;
  final String? ctaText;
  final VoidCallback? onCtaPressed;
  final bool isCtaLoading;
  final IconData? ctaIcon;
  final Key? ctaKey;
  final CrossAxisAlignment crossAxisAlignment;
  final bool renderInternalHeaderAndCTA;

  const FlowPageLayout({
    super.key,
    this.title,
    this.subtitle,
    this.headerWidget,
    required this.child,
    this.bottomBar,
    this.ctaText,
    this.onCtaPressed,
    this.isCtaLoading = false,
    this.ctaIcon,
    this.ctaKey,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.renderInternalHeaderAndCTA = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!renderInternalHeaderAndCTA) {
      return child;
    }
    final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final hasBottomAction = bottomBar != null || onCtaPressed != null;

    return Column(
      children: [
        // Spacing for extended transparent app bar
        SizedBox(height: topInset),
        // Scrollable content area
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenMargin),
              child: Column(
                crossAxisAlignment: crossAxisAlignment,
                children: [
                  AppGaps.belowAppBar,
                  if (headerWidget != null) ...[
                    headerWidget!,
                    AppGaps.headerContent,
                  ] else ...[
                    if (title != null) ...[
                      Text(
                        title!,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFF9FAFA),
                          height: 1.15,
                        ),
                      ),
                    ],
                    if (subtitle != null) ...[
                      AppGaps.headerTitleSubtitle,
                      Text(
                        subtitle!,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          color: const Color(0xFF919696),
                          height: 1.4,
                        ),
                      ),
                    ],
                    if (title != null || subtitle != null) AppGaps.headerContent,
                  ],
                  child,
                  const SizedBox(height: AppSpacing.spaceLg),
                ],
              ),
            ),
          ),
        ),
        // Anchored bottom CTA
        if (hasBottomAction) ...[
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.screenMargin,
              12,
              AppSpacing.screenMargin,
              bottomInset + AppSpacing.ctaBottomPadding,
            ),
            child: bottomBar ??
                AppButtons.primaryCTA(
                  key: ctaKey,
                  onPressed: onCtaPressed,
                  text: ctaText ?? 'CONTINUE',
                  icon: ctaIcon,
                  isLoading: isCtaLoading,
                ),
          ),
        ],
      ],
    );
  }
}
