import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/nav_destination_item.dart';
import '../../theme/app_theme.dart';

/// A unified, reusable floating liquid glassmorphic bottom navigation bar.
///
/// Designed to provide consistent geometry, elevation, frosted glass styling,
/// and interactive destination states across both Client and Artist interfaces.
class FlashBottomNavBar extends StatelessWidget {
  /// The active destination index.
  final int currentIndex;

  /// Callback fired when a destination is selected.
  final ValueChanged<int> onTap;

  /// Explicit list of destinations. If null, resolved dynamically from [role].
  final List<NavDestinationItem>? items;

  /// Active user role ('client' or 'artist') used to resolve default destinations.
  final String? role;

  /// Whether to trigger subtle haptic feedback on destination selection.
  final bool enableHaptics;

  /// Custom corner radius for the pill container. Defaults to [AppTheme.navBarBorderRadius].
  final double borderRadius;

  /// Custom blur sigma for liquid diffusion. Defaults to [AppTheme.glassBlurSigma].
  final double blurSigma;

  /// Custom container height. Defaults to [AppTheme.navBarHeight].
  final double height;

  /// Custom background color for the glass surface. Defaults to subtle translucent onyx tint.
  final Color? backgroundColor;

  const FlashBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.items,
    this.role,
    this.enableHaptics = true,
    this.borderRadius = AppTheme.navBarBorderRadius,
    this.blurSigma = AppTheme.glassBlurSigma,
    this.height = AppTheme.navBarHeight,
    this.backgroundColor,
  }) : assert(
          items != null || role != null,
          'Either items or role must be provided to FlashBottomNavBar.',
        );

  /// Helper factory to position the navigation bar as a floating widget inside a Stack,
  /// automatically calculating device safe area insets and horizontal margins.
  static Widget floating({
    Key? key,
    required int currentIndex,
    required ValueChanged<int> onTap,
    List<NavDestinationItem>? items,
    String? role,
    bool enableHaptics = true,
    Color? backgroundColor,
    double horizontalMargin = AppTheme.navBarHorizontalMargin,
    double bottomMargin = AppTheme.navBarBottomMargin,
  }) {
    return Builder(
      key: key,
      builder: (context) {
        final safeBottom = MediaQuery.paddingOf(context).bottom;
        return Positioned(
          left: horizontalMargin,
          right: horizontalMargin,
          bottom: safeBottom + bottomMargin,
          child: FlashBottomNavBar(
            currentIndex: currentIndex,
            onTap: onTap,
            items: items,
            role: role,
            enableHaptics: enableHaptics,
            backgroundColor: backgroundColor,
          ),
        );
      },
    );
  }

  /// Resolves the list of destinations to render.
  List<NavDestinationItem> get resolvedItems {
    if (items != null) return items!;
    return NavDestinationItem.forRole(role ?? 'client');
  }

  @override
  Widget build(BuildContext context) {
    final navItems = resolvedItems;
    final radius = BorderRadius.circular(borderRadius);

    return Semantics(
      container: true,
      label: 'Bottom Navigation',
      child: Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: AppTheme.navBarShadow,
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: BackdropFilter(
            // Silky liquid diffusion
            filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
            child: Stack(
              children: [
                // Layer 1: Enhanced translucent liquid glass tint (flat background, increased transparency, no gradient)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: radius,
                      color: backgroundColor ?? AppTheme.onyxBackground.withAlpha(85), // ~33% opacity for high transparency
                    ),
                  ),
                ),

                // Layer 2: Subtle border stroke, gliding active pill, and destination items row
                Positioned.fill(
                  child: Container(
                    padding: AppTheme.navBarPadding,
                    decoration: BoxDecoration(
                      borderRadius: radius,
                      border: Border.all(
                        color: AppTheme.glassBorderColor.withAlpha(120),
                        width: AppTheme.glassBorderWidth,
                      ),
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final itemCount = navItems.length;
                        final totalWidth = constraints.hasBoundedWidth
                            ? constraints.maxWidth
                            : (itemCount * 80.0);
                        final slotWidth =
                            itemCount > 0 ? totalWidth / itemCount : 0.0;
                        final hasValidSelection =
                            currentIndex >= 0 && currentIndex < itemCount;

                        return Stack(
                          children: [
                            // Gliding liquid glass indicator pill
                            if (hasValidSelection && slotWidth > 0)
                              AnimatedPositioned(
                                duration: AppTheme.navAnimationDuration,
                                curve: AppTheme.navAnimationCurve,
                                left: currentIndex * slotWidth + 4.0,
                                top: 4.0,
                                bottom: 4.0,
                                width: (slotWidth - 8.0).clamp(0.0, double.infinity),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: AppTheme.navActivePillBackground,
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.navItemBorderRadius,
                                    ),
                                  ),
                                ),
                              ),

                            // Destination items row
                            Positioned.fill(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: List.generate(navItems.length, (index) {
                                  final item = navItems[index];
                                  final isSelected = currentIndex == index;

                                  return Expanded(
                                    child: _FlashNavDestinationButton(
                                      key: item.key ?? Key('nav_item_$index'),
                                      item: item,
                                      isSelected: isSelected,
                                      onTap: () {
                                        if (enableHaptics) {
                                          HapticFeedback.selectionClick();
                                        }
                                        onTap(index);
                                      },
                                    ),
                                  );
                                }),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Standardized destination element for [FlashBottomNavBar].
///
/// Guarantees consistent tap targets, active gold pill indicator,
/// typography, icon scaling, and notification badges.
class _FlashNavDestinationButton extends StatelessWidget {
  final NavDestinationItem item;
  final bool isSelected;
  final VoidCallback onTap;

  const _FlashNavDestinationButton({
    super.key,
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = AppTheme.gold;
    final inactiveColor = AppTheme.navInactive;
    final foregroundColor = isSelected ? activeColor : inactiveColor;
    final iconData = isSelected ? item.effectiveActiveIcon : item.icon;

    return Semantics(
      selected: isSelected,
      button: true,
      label: item.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.navItemBorderRadius),
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          child: Center(
            child: Padding(
              padding: AppTheme.navItemPadding,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icon with optional notification badge
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        iconData,
                        size: AppTheme.navIconSize,
                        color: foregroundColor,
                      ),
                      if (item.hasNotificationBadge || (item.badgeCount != null && item.badgeCount! > 0))
                        Positioned(
                          top: -2,
                          right: -3,
                          child: item.badgeCount != null && item.badgeCount! > 0
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: activeColor,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                                  child: Text(
                                    '${item.badgeCount}',
                                    style: const TextStyle(
                                      color: AppTheme.onyxBackground,
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                )
                              : Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    color: activeColor,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: activeColor.withAlpha(120),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.navIconLabelSpacing),
                  // Standardized label token
                  Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: isSelected
                        ? AppTheme.navLabelActive
                        : AppTheme.navLabelInactive,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
