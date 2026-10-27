import 'package:flutter/material.dart';

/// A sleek cross-fade page route with zero horizontal sliding.
///
/// Designed specifically for onboarding and multi-step flows where screen
/// contents cross-fade smoothly in place while persistent indicators
/// (such as stepper headers or progress indicators) update independently.
class FadePageRoute<T> extends PageRouteBuilder<T> {
  final WidgetBuilder builder;

  FadePageRoute({
    required this.builder,
    super.settings,
    super.transitionDuration = const Duration(milliseconds: 250),
    super.reverseTransitionDuration = const Duration(milliseconds: 250),
    Curve curve = Curves.easeInOut,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => builder(context),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curvedAnimation = CurvedAnimation(
              parent: animation,
              curve: curve,
              reverseCurve: curve,
            );
            return FadeTransition(
              opacity: curvedAnimation,
              child: child,
            );
          },
        );
}
