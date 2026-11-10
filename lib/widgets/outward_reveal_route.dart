import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A custom [PageRouteBuilder] that animates the entrance of a page
/// by expanding outward in a circular clipping path from an [origin] point.
class OutwardRevealPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  final Offset? origin;

  OutwardRevealPageRoute({
    required this.page,
    this.origin,
    super.settings,
    super.transitionDuration = const Duration(milliseconds: 500),
    super.reverseTransitionDuration = const Duration(milliseconds: 400),
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curvedAnimation = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );

            return LayoutBuilder(
              builder: (context, constraints) {
                final screenSize = constraints.biggest;
                final effectiveOrigin = origin ??
                    Offset(screenSize.width - 40, 100);

                // Compute maximum radius to reach all 4 corners of the screen
                final maxRadius = _calcMaxRadius(effectiveOrigin, screenSize);

                return AnimatedBuilder(
                  animation: curvedAnimation,
                  builder: (context, childWidget) {
                    final currentRadius = curvedAnimation.value * maxRadius;
                    return ClipPath(
                      clipper: _CircularRevealClipper(
                        center: effectiveOrigin,
                        radius: currentRadius,
                      ),
                      child: childWidget,
                    );
                  },
                  child: child,
                );
              },
            );
          },
        );

  static double _calcMaxRadius(Offset center, Size size) {
    final d1 = (center - const Offset(0, 0)).distance;
    final d2 = (center - Offset(size.width, 0)).distance;
    final d3 = (center - Offset(0, size.height)).distance;
    final d4 = (center - Offset(size.width, size.height)).distance;
    return math.max(math.max(d1, d2), math.max(d3, d4));
  }
}

class _CircularRevealClipper extends CustomClipper<Path> {
  final Offset center;
  final double radius;

  _CircularRevealClipper({required this.center, required this.radius});

  @override
  Path getClip(Size size) {
    final path = Path();
    if (radius <= 0) {
      return path;
    }
    path.addOval(Rect.fromCircle(center: center, radius: radius));
    return path;
  }

  @override
  bool shouldReclip(_CircularRevealClipper oldClipper) {
    return oldClipper.center != center || oldClipper.radius != radius;
  }
}
