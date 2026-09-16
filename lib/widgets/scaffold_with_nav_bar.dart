import 'package:flutter/material.dart';
import '../core/widgets/flash_bottom_nav_bar.dart';
import '../models/nav_destination_item.dart';
import '../theme/app_theme.dart';

/// A root shell scaffold widget integrating [FlashBottomNavBar] with [IndexedStack].
///
/// Ensures switching between primary destinations preserves page scroll positions,
/// inputs, and view state without triggering unnecessary widget rebuilds.
class ScaffoldWithNavBar extends StatefulWidget {
  /// The list of tab view pages displayed inside the [IndexedStack].
  final List<Widget> pages;

  /// Explicit list of destinations. If null, resolved dynamically via [role].
  final List<NavDestinationItem>? items;

  /// User role ('client' or 'artist') used to resolve default navigation destinations.
  final String? role;

  /// Optional initial index when using internal state management.
  final int initialIndex;

  /// Optional controlled active index. When provided, the widget operates in controlled mode.
  final int? currentIndex;

  /// Optional callback invoked when a navigation destination is tapped.
  final ValueChanged<int>? onDestinationSelected;

  /// Background color for the scaffold surface. Defaults to [AppTheme.onyxBackground].
  final Color backgroundColor;

  /// Whether the body should resize when an onscreen keyboard appears.
  final bool resizeToAvoidBottomInset;

  /// Optional floating navigation bar horizontal margin.
  final double horizontalMargin;

  /// Optional floating navigation bar bottom margin above the safe area.
  final double bottomMargin;

  const ScaffoldWithNavBar({
    super.key,
    required this.pages,
    this.items,
    this.role,
    this.initialIndex = 0,
    this.currentIndex,
    this.onDestinationSelected,
    this.backgroundColor = AppTheme.onyxBackground,
    this.resizeToAvoidBottomInset = false,
    this.horizontalMargin = AppTheme.navBarHorizontalMargin,
    this.bottomMargin = AppTheme.navBarBottomMargin,
  }) : assert(
          items != null || role != null,
          'Either items or role must be provided to ScaffoldWithNavBar.',
        );

  @override
  State<ScaffoldWithNavBar> createState() => _ScaffoldWithNavBarState();
}

class _ScaffoldWithNavBarState extends State<ScaffoldWithNavBar> {
  late int _internalIndex = widget.initialIndex;

  int get _effectiveIndex => widget.currentIndex ?? _internalIndex;

  void _handleDestinationTap(int index) {
    if (widget.currentIndex == null) {
      setState(() {
        _internalIndex = index;
      });
    }
    widget.onDestinationSelected?.call(index);
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final safeBottom = mediaQuery.padding.bottom;

    return Scaffold(
      backgroundColor: widget.backgroundColor,
      resizeToAvoidBottomInset: widget.resizeToAvoidBottomInset,
      body: Stack(
        children: [
          // Primary view stack preserving tab scroll position & view state
          IndexedStack(
            index: _effectiveIndex,
            children: widget.pages,
          ),

          // Floating translucent/glassmorphic bottom navigation bar
          Positioned(
            left: widget.horizontalMargin,
            right: widget.horizontalMargin,
            bottom: safeBottom + widget.bottomMargin,
            child: FlashBottomNavBar(
              currentIndex: _effectiveIndex,
              onTap: _handleDestinationTap,
              items: widget.items,
              role: widget.role,
            ),
          ),
        ],
      ),
    );
  }
}
