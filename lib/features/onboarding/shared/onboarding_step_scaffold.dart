import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_buttons.dart';
import '../../../theme/app_radius.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/skip_pill_button.dart';

/// Architectural Layout Contract for all multi-step onboarding screens.
///
/// Strictly enforces layout consistency across steps to eliminate vertical
/// visual jumping during forward/backward navigation:
/// 1. Pinned Navigation/Progress Bar:
///    - Fixed 48px height anchored at the top safe area.
///    - Back button (or placeholder), Segmented progress pill indicators, Skip button.
/// 2. Fixed Typography Anchoring:
///    - 32px fixed margin below progress bar to Header Title.
///    - Title: 34pt w800 (`headlineLarge`), top-anchored at identical vertical offset.
///    - 8px fixed gap between Title and Subhead.
///    - Subhead: 15pt muted (`bodyMedium`), 1.4 line-height.
///    - 24px fixed gap between Subhead and Content Area.
/// 3. Content Box Rules (Downward Expansion):
///    - Starts at the exact same vertical baseline (immediately 24px below subhead).
///    - Middle container expands DOWNWARD toward the bottom CTA.
///    - Never centers the content card vertically in remaining viewport space.
///    - Bounded within `Expanded` + `SingleChildScrollView` (when scrollable is true)
///      so dynamic lists/cards expand without pushing or pulling header typography.
/// 4. Action Button Positioning (Zero Keyboard Avoidance):
///    - Zero keyboard avoidance: `resizeToAvoidBottomInset: false` on the Scaffold.
///    - Short screens (content fits within viewport): CTA pins flush to the bottom safe-area edge;
///      keyboard sits *over* the CTA rather than pushing it up.
///    - Scrollable screens (content exceeds viewport): CTA anchors at the very bottom of the
///      scrollable page content body—not as a floating sticky overlay.
///    - Unified single layout structure: `CustomScrollView` with `SliverFillRemaining(hasScrollBody: false)`.
///    - Scroll-to-dismiss: `keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag`.
class OnboardingStepScaffold extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final VoidCallback? onBack;
  final VoidCallback? onSkip;
  final String skipText;
  final Key? backKey;
  final Key? skipKey;
  final String title;
  final String? subtitle;
  final Widget child;
  final String ctaText;
  final VoidCallback? onCtaPressed;
  final bool isCtaLoading;
  final bool isCtaEnabled;
  final IconData? ctaIcon;
  final Key? ctaKey;
  final Widget? bottomBar;
  final Widget? backgroundOverlay;
  final bool scrollable;
  final bool resizeToAvoidBottomInset;
  final Widget? progressIndicator;
  final EdgeInsetsGeometry? contentPadding;

  const OnboardingStepScaffold({
    super.key,
    required this.currentStep,
    this.totalSteps = 4,
    this.onBack,
    this.onSkip,
    this.skipText = 'Skip',
    this.backKey,
    this.skipKey,
    required this.title,
    this.subtitle,
    required this.child,
    this.ctaText = 'CONTINUE',
    this.onCtaPressed,
    this.isCtaLoading = false,
    this.isCtaEnabled = true,
    this.ctaIcon,
    this.ctaKey,
    this.bottomBar,
    this.backgroundOverlay,
    this.scrollable = true,
    this.resizeToAvoidBottomInset = false,
    this.progressIndicator,
    this.contentPadding,
  });

  @override
  Widget build(BuildContext context) {
    final ctaButtonWidget = Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenGutter, vertical: 16),
      child: bottomBar ??
          AppButtons.primaryCTA(
            key: ctaKey ?? const Key('onboarding_cta_button'),
            text: ctaText,
            icon: ctaIcon,
            isLoading: isCtaLoading,
            onPressed: (isCtaEnabled && !isCtaLoading) ? onCtaPressed : null,
            backgroundColor: (isCtaEnabled && !isCtaLoading)
                ? AppTheme.gold
                : const Color(0xFF262929),
            foregroundColor: (isCtaEnabled && !isCtaLoading)
                ? const Color(0xFF121414)
                : const Color(0xFF6B7272),
          ),
    );

    final scaffoldContent = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Pinned Navigation/Progress Bar (Fixed 48px height)
            SizedBox(
              height: 48,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenGutter),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Centered Segmented Progress Pill Indicator or custom indicator
                    progressIndicator ??
                        _SegmentedProgressPills(
                          currentStep: currentStep,
                          totalSteps: totalSteps,
                        ),

                    // Left: Back Button Slot (or 48x48 placeholder)
                    if (onBack != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          key: backKey ?? const Key('onboarding_back_button'),
                          icon: const Icon(
                            Icons.arrow_back_ios_new,
                            size: 20,
                            color: AppTheme.textPrimary,
                          ),
                          onPressed: () {
                            FocusManager.instance.primaryFocus?.unfocus();
                            onBack!();
                          },
                          tooltip: 'Back',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                        ),
                      )
                    else
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: SizedBox(width: 48, height: 48),
                      ),

                    // Right: Skip Button Slot (or 48x48 placeholder)
                    if (onSkip != null)
                      Align(
                        alignment: Alignment.centerRight,
                        child: SkipPillButton(
                          key: skipKey ?? const Key('onboarding_skip_button'),
                          text: skipText,
                          onPressed: () {
                            FocusManager.instance.primaryFocus?.unfocus();
                            onSkip!();
                          },
                        ),
                      )
                    else
                      const Align(
                        alignment: Alignment.centerRight,
                        child: SizedBox(width: 48, height: 48),
                      ),
                  ],
                ),
              ),
            ),

            // Scrollable Content Area + Anchored CTA
            Expanded(
              child: CustomScrollView(
                physics: scrollable
                    ? const BouncingScrollPhysics()
                    : const NeverScrollableScrollPhysics(),
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 2. Fixed Typography Anchoring (Fixed 32px gap below navigation bar)
                        const SizedBox(height: 32),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenGutter),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                title,
                                key: const Key('onboarding_title'),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFFF9FAFA),
                                  height: 1.15,
                                ),
                              ),
                              if (subtitle != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  subtitle!,
                                  key: const Key('onboarding_subtitle'),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 15,
                                    color: const Color(0xFF919696),
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        // 3. Fixed Baseline Gap (Fixed 24px gap between Subhead and Content)
                        const SizedBox(height: 24),

                        // 4. Content Area
                        Padding(
                          padding: contentPadding ??
                              const EdgeInsets.symmetric(horizontal: AppSpacing.screenGutter),
                          child: child,
                        ),
                      ],
                    ),
                  ),
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Column(
                      children: [
                        const Spacer(),
                        ctaButtonWidget,
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return Scaffold(
      backgroundColor: AppTheme.onyxBackground,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        toolbarHeight: 0,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: backgroundOverlay != null
          ? Stack(
              children: [
                backgroundOverlay!,
                scaffoldContent,
              ],
            )
          : scaffoldContent,
    );
  }
}

/// Segmented progress pill indicator showing `totalSteps` horizontal dashes.
class SegmentedProgressPills extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const SegmentedProgressPills({
    super.key,
    required this.currentStep,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const Key('onboarding_progress_bar'),
      mainAxisSize: MainAxisSize.min,
      children: List.generate(totalSteps, (index) {
        final stepNumber = index + 1;
        final isActive = stepNumber <= currentStep;
        final isCurrent = stepNumber == currentStep;

        return AnimatedContainer(
          key: Key('onboarding_step_indicator_$stepNumber'),
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          margin: EdgeInsets.only(right: index < totalSteps - 1 ? 6.0 : 0.0),
          width: isCurrent ? 32.0 : 20.0,
          height: 4.0,
          decoration: BoxDecoration(
            color: isActive ? AppTheme.gold : const Color(0xFF2E3232),
            borderRadius: BorderRadius.circular(AppRadius.dragHandle),
          ),
        );
      }),
    );
  }
}

typedef _SegmentedProgressPills = SegmentedProgressPills;
