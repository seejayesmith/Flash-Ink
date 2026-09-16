import 'package:flutter/material.dart';

/// A reusable background wrapper that renders the underground ink
/// textured background ('assets/images/tattoo_setup.png') with a dark
/// vignette gradient overlay, matching the client onboarding experience.
class TattooBackgroundWrapper extends StatelessWidget {
  final Widget child;

  const TattooBackgroundWrapper({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Background subtle tattoo texture extending edge to edge
        Positioned.fill(
          child: Image.asset(
            'assets/images/tattoo_setup.png',
            fit: BoxFit.cover,
            cacheWidth: 1080,
          ),
        ),
        // Dark vignette gradient overlay for high contrast & text legibility
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withAlpha(230),
                  Colors.black.withAlpha(130),
                  Colors.black.withAlpha(140),
                  Colors.black.withAlpha(210),
                ],
                stops: const [0.0, 0.25, 0.60, 1.0],
              ),
            ),
          ),
        ),
        // Screen content
        child,
      ],
    );
  }
}
