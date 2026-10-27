import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../theme/app_buttons.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';

/// Standardized layout container that strictly guarantees any primary CTA button
/// is pinned below the scrollable content area, outside the scroll view.
///
/// Architectural Rules:
/// 1. The primary Call-To-Action (CTA) is pinned at the bottom of the screen
///    outside [SingleChildScrollView], preventing it from ever being hidden or
///    scrolled out of view.
/// 2. Context-dependent bottom bar styling:
///    - `isDocked: false` (Default): Floating transparent padding for auth/onboarding
///      screens so underlying tattoo background textures remain visible.
///    - `isDocked: true`: Solid dark container (`#151717`) with a 1px top border
///      (`#262929`) for detail/management screens.
/// 3. Keyboard Avoidance:
///    - Root scaffold sets `resizeToAvoidBottomInset: false` so the CTA remains anchored
///      to the screen bottom beneath the software keyboard.
///    - The scroll view dynamically appends `viewInsets.bottom` so form inputs can be
///      scrolled into full view above the keyboard.
/// 4. Secondary Actions:
///    - Lightweight linked actions (e.g. "Resend Code" or "Skip for now") can be placed
///      in [secondaryAction], positioned beneath the primary CTA.
///    - Heavy secondary buttons (e.g. "Decline", "Reschedule") should remain in the
///      scrollable content body.
class PinnedBottomActionScaffold extends StatelessWidget {
  /// Optional standard or glassmorphic app bar.
  final PreferredSizeWidget? appBar;

  /// Whether the body should extend behind the app bar (useful for transparent app bars).
  final bool extendBodyBehindAppBar;

  /// Full-bleed background widget (e.g. tattoo texture and gradients).
  final Widget? background;

  /// Scaffold background color.
  final Color backgroundColor;

  /// Scrollable content placed in the scroll view.
  final Widget child;

  /// Content horizontal and vertical padding. Defaults to `AppSpacing.screenGutter` horizontal.
  final EdgeInsetsGeometry? contentPadding;

  /// Physics for the internal [SingleChildScrollView].
  final ScrollPhysics scrollPhysics;

  /// Scroll controller for the internal scroll view.
  final ScrollController? scrollController;

  /// Alignment of children within the scrollable column.
  final CrossAxisAlignment crossAxisAlignment;

  /// Whether the child is centered vertically when content is smaller than viewport.
  final bool centerContent;

  /// If true, does not wrap [child] in a [SingleChildScrollView].
  final bool childIsScrollable;

  /// Fully custom bottom action widget. If supplied, overrides [ctaText] and [onCtaPressed].
  final Widget? bottomCta;

  /// Label for standard primary CTA button.
  final String? ctaText;

  /// Callback when primary CTA is pressed.
  final VoidCallback? onCtaPressed;

  /// Shows loading spinner in place of CTA label.
  final bool isCtaLoading;

  /// Disables CTA interaction and applies disabled theme colors.
  final bool isCtaEnabled;

  /// Leading icon for standard primary CTA.
  final IconData? ctaIcon;

  /// Key for automated testing of primary CTA button.
  final Key? ctaKey;

  /// Custom background color for primary CTA button.
  final Color? ctaBackgroundColor;

  /// Custom text/icon color for primary CTA button.
  final Color? ctaForegroundColor;

  /// Optional secondary action widget placed beneath the primary CTA.
  final Widget? secondaryAction;

  /// Whether the bottom container is docked with a solid dark surface and top divider (`true`)
  /// or floating with transparent padding (`false`).
  final bool isDocked;

  /// Top spacing below the app bar or safe area.
  /// When [extendBodyBehindAppBar] is true, defaults to [AppSpacing.headerTop] (24.0)
  /// to match [FlowPageLayout]. Otherwise defaults to 12.0.
  final double? topSpacing;

  /// When true, renders the CTA inline at the bottom of the scroll view (Option C),
  /// matching the seamless flow of [OnboardingStepScaffold] without a pinned bottom bar or cutoff shelf.
  final bool inlineCTA;

  const PinnedBottomActionScaffold({
    super.key,
    this.appBar,
    this.extendBodyBehindAppBar = false,
    this.background,
    this.backgroundColor = AppTheme.onyxBackground,
    required this.child,
    this.contentPadding,
    this.topSpacing,
    this.scrollPhysics = const BouncingScrollPhysics(),
    this.scrollController,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.centerContent = false,
    this.childIsScrollable = false,
    this.bottomCta,
    this.ctaText,
    this.onCtaPressed,
    this.isCtaLoading = false,
    this.isCtaEnabled = true,
    this.ctaIcon,
    this.ctaKey,
    this.ctaBackgroundColor,
    this.ctaForegroundColor,
    this.secondaryAction,
    this.isDocked = false,
    this.inlineCTA = false,
  });

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomSafeArea = mediaQuery.padding.bottom;
    final topSafeArea = mediaQuery.padding.top;
    final keyboardInset = mediaQuery.viewInsets.bottom;

    final hasBottomAction = bottomCta != null ||
        ctaText != null ||
        onCtaPressed != null ||
        secondaryAction != null;

    final topInset = extendBodyBehindAppBar
        ? topSafeArea + (appBar?.preferredSize.height ?? kToolbarHeight)
        : 0.0;

    final isIOS = Theme.of(context).platform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.iOS;
    final isAccessoryToolbarVisible = isIOS && keyboardInset > 0;
    const accessoryToolbarHeight = 44.0;

    final basePadding = contentPadding ??
        const EdgeInsets.symmetric(horizontal: AppSpacing.screenGutter);

    final effectiveTopSpacing = topSpacing ??
        (extendBodyBehindAppBar ? AppSpacing.headerTop : 12.0);

    // Dynamic scroll padding that expands when the keyboard is open,
    // allowing all form fields to be scrolled into full view above the keyboard.
    final dynamicScrollPadding = basePadding.add(
      EdgeInsets.only(
        top: extendBodyBehindAppBar ? topInset + effectiveTopSpacing : effectiveTopSpacing,
        bottom: keyboardInset +
            (isAccessoryToolbarVisible ? accessoryToolbarHeight : 0.0) +
            (isDocked ? AppSpacing.spaceLg : 16.0),
      ),
    );

    Widget scrollableBody;
    if (childIsScrollable) {
      scrollableBody = child;
    } else {
      Widget bodyContent = child;
      if (centerContent) {
        bodyContent = Center(child: bodyContent);
      }

      scrollableBody = LayoutBuilder(
        builder: (context, constraints) {
          final minContentHeight =
              (constraints.maxHeight - dynamicScrollPadding.vertical).clamp(0.0, double.infinity);

          Widget contentColumn = Column(
            crossAxisAlignment: crossAxisAlignment,
            mainAxisSize: inlineCTA ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: centerContent
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: [
              bodyContent,
              if (inlineCTA && hasBottomAction) ...[
                const Spacer(),
                const SizedBox(height: AppSpacing.spaceLg),
                _buildInlineBottomBar(context, bottomSafeArea),
              ],
            ],
          );

          return SingleChildScrollView(
            controller: scrollController,
            physics: scrollPhysics,
            padding: dynamicScrollPadding,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: minContentHeight,
              ),
              child: inlineCTA ? IntrinsicHeight(child: contentColumn) : contentColumn,
            ),
          );
        },
      );
    }

    final mainBody = SafeArea(
      top: !extendBodyBehindAppBar,
      bottom: false,
      child: scrollableBody,
    );

    final interactiveBody = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        FocusManager.instance.primaryFocus?.unfocus();
        FocusScope.of(context).unfocus();
      },
      child: mainBody,
    );

    final Widget effectiveBody;
    if (background == null && !isAccessoryToolbarVisible) {
      effectiveBody = interactiveBody;
    } else {
      effectiveBody = Stack(
        children: [
          ?background,
          interactiveBody,
          if (isAccessoryToolbarVisible)
            Positioned(
              left: 0,
              right: 0,
              bottom: keyboardInset,
              child: _buildKeyboardAccessoryToolbar(context),
            ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      resizeToAvoidBottomInset: false,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      extendBody: true,
      appBar: appBar,
      body: effectiveBody,
      bottomNavigationBar: (hasBottomAction && !inlineCTA)
          ? _buildBottomBar(context, bottomSafeArea)
          : null,
    );
  }

  Widget _buildKeyboardAccessoryToolbar(BuildContext context) {
    return Container(
      height: 44.0,
      decoration: const BoxDecoration(
        color: Color(0xFF1E2121),
        border: Border(
          top: BorderSide(
            color: Color(0xFF2E3232),
            width: 1.0,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            key: const Key('scaffold_collapse_keyboard_button'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () {
              FocusManager.instance.primaryFocus?.unfocus();
              FocusScope.of(context).unfocus();
            },
            child: const Text(
              'Done',
              style: TextStyle(
                color: Color(0xFFEEC200),
                fontSize: 16.0,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineBottomBar(BuildContext context, double bottomSafeArea) {
    Widget? primaryWidget;

    if (bottomCta != null) {
      primaryWidget = bottomCta!;
    } else if (ctaText != null || onCtaPressed != null) {
      final enabled = isCtaEnabled && !isCtaLoading && onCtaPressed != null;
      primaryWidget = AppButtons.primaryCTA(
        key: ctaKey,
        onPressed: enabled ? onCtaPressed : null,
        text: ctaText ?? 'CONTINUE',
        icon: ctaIcon,
        isLoading: isCtaLoading,
        backgroundColor: ctaBackgroundColor ??
            (enabled ? AppTheme.gold : const Color(0xFF262929)),
        foregroundColor: ctaForegroundColor ??
            (enabled ? const Color(0xFF121414) : const Color(0xFF6B7272)),
      );
    }

    final actionColumn = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ?primaryWidget,
        if (secondaryAction != null) ...[
          const SizedBox(height: 10.0),
          secondaryAction!,
        ],
      ],
    );

    return Padding(
      padding: EdgeInsets.only(
        top: AppSpacing.spaceLg,
        bottom: bottomSafeArea > 0 ? bottomSafeArea : AppSpacing.spaceMd,
      ),
      child: actionColumn,
    );
  }

  Widget _buildBottomBar(BuildContext context, double bottomSafeArea) {
    Widget? primaryWidget;

    if (bottomCta != null) {
      primaryWidget = bottomCta!;
    } else if (ctaText != null || onCtaPressed != null) {
      final enabled = isCtaEnabled && !isCtaLoading && onCtaPressed != null;
      primaryWidget = AppButtons.primaryCTA(
        key: ctaKey,
        onPressed: enabled ? onCtaPressed : null,
        text: ctaText ?? 'CONTINUE',
        icon: ctaIcon,
        isLoading: isCtaLoading,
        backgroundColor: ctaBackgroundColor ??
            (enabled ? AppTheme.gold : const Color(0xFF262929)),
        foregroundColor: ctaForegroundColor ??
            (enabled ? const Color(0xFF121414) : const Color(0xFF6B7272)),
      );
    }

    final actionColumn = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ?primaryWidget,
        if (secondaryAction != null) ...[
          const SizedBox(height: 10.0),
          secondaryAction!,
        ],
      ],
    );

    if (isDocked) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(
          AppSpacing.screenGutter,
          AppSpacing.spaceMd,
          AppSpacing.screenGutter,
          bottomSafeArea + AppSpacing.spaceMd,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFF151717),
          border: Border(
            top: BorderSide(color: Color(0xFF262929), width: 1.0),
          ),
        ),
        child: actionColumn,
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screenGutter,
        12.0,
        AppSpacing.screenGutter,
        bottomSafeArea + AppSpacing.ctaBottomPadding,
      ),
      child: actionColumn,
    );
  }
}
