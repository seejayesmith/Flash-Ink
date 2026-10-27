import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_radius.dart';

/// A sleek minimal line/dot indicator for the 3-step artist onboarding flow.
///
/// Displays an elongated gold capsule pill for the active phase, a compact gold pill
/// for completed phases, and a compact muted pill for upcoming phases, paired with
/// subtle labels below each segment.
///
/// Anchored as a persistent Hero widget so it remains stationary at the top of the
/// screen during onboarding transitions while animating pill widths and states
/// independently in place.
class ArtistStepperHeader extends StatelessWidget {
  /// 1: Setup account, 2: Create profile, 3: Share link
  final int currentStep;
  final EdgeInsetsGeometry padding;
  final Object? heroTag;

  const ArtistStepperHeader({
    super.key,
    required this.currentStep,
    this.padding = const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
    this.heroTag = 'artist_stepper_header',
  });

  @override
  Widget build(BuildContext context) {
    final content = Material(
      type: MaterialType.transparency,
      child: _ArtistStepperHeaderContent(
        currentStep: currentStep,
        padding: padding,
      ),
    );

    if (heroTag == null) {
      return content;
    }

    return Hero(
      tag: heroTag!,
      flightShuttleBuilder: (
        flightContext,
        animation,
        flightDirection,
        fromHeroContext,
        toHeroContext,
      ) {
        int extractStep(BuildContext ctx, int fallback) {
          try {
            final hero = ctx.widget as Hero;
            final mat = hero.child as Material;
            final body = mat.child as _ArtistStepperHeaderContent;
            return body.currentStep;
          } catch (_) {
            return fallback;
          }
        }

        final fromStep = extractStep(fromHeroContext, currentStep);
        final toStep = extractStep(toHeroContext, currentStep);

        return Material(
          type: MaterialType.transparency,
          child: AnimatedBuilder(
            animation: animation,
            builder: (context, _) {
              final curved = CurvedAnimation(
                parent: animation,
                curve: Curves.easeInOut,
              );
              return _ArtistStepperHeaderTransitionContent(
                fromStep: fromStep,
                toStep: toStep,
                progress: curved.value,
                padding: padding,
              );
            },
          ),
        );
      },
      child: content,
    );
  }
}

class _ArtistStepperHeaderContent extends StatelessWidget {
  final int currentStep;
  final EdgeInsetsGeometry padding;

  const _ArtistStepperHeaderContent({
    required this.currentStep,
    required this.padding,
  });

  static const List<String> _stepLabels = ['Account', 'Profile', 'Share'];

  Widget _buildStepItem(int stepNumber, String label) {
    final isCompleted = currentStep > stepNumber;
    final isActive = currentStep == stepNumber;

    final Color pillColor = (isActive || isCompleted)
        ? const Color(0xFFEEC200)
        : const Color(0xFF333737);

    final double pillWidth = isActive ? 24.0 : 12.0;

    final Color labelColor = isActive
        ? const Color(0xFFF9FAFA)
        : (isCompleted ? const Color(0xFFD8DDDD) : const Color(0xFF8C9191));

    return SizedBox(
      width: 52,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            key: Key('artist_step_indicator_$stepNumber'),
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            width: pillWidth,
            height: 4.0,
            decoration: BoxDecoration(
              color: pillColor,
              borderRadius: BorderRadius.circular(AppRadius.dragHandle),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            key: Key('artist_step_label_$stepNumber'),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              height: 1.2,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              color: labelColor,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildStepItem(1, _stepLabels[0]),
          const SizedBox(width: 16),
          _buildStepItem(2, _stepLabels[1]),
          const SizedBox(width: 16),
          _buildStepItem(3, _stepLabels[2]),
        ],
      ),
    );
  }
}

class _ArtistStepperHeaderTransitionContent extends StatelessWidget {
  final int fromStep;
  final int toStep;
  final double progress;
  final EdgeInsetsGeometry padding;

  const _ArtistStepperHeaderTransitionContent({
    required this.fromStep,
    required this.toStep,
    required this.progress,
    required this.padding,
  });

  static const List<String> _stepLabels = ['Account', 'Profile', 'Share'];

  Widget _buildStepItem(int stepNumber, String label) {
    final fromActive = fromStep == stepNumber;
    final fromCompleted = fromStep > stepNumber;
    final toActive = toStep == stepNumber;
    final toCompleted = toStep > stepNumber;

    final fromWidth = fromActive ? 24.0 : 12.0;
    final toWidth = toActive ? 24.0 : 12.0;
    final width = lerpDouble(fromWidth, toWidth, progress) ?? toWidth;

    final fromPillColor = (fromActive || fromCompleted)
        ? const Color(0xFFEEC200)
        : const Color(0xFF333737);
    final toPillColor = (toActive || toCompleted)
        ? const Color(0xFFEEC200)
        : const Color(0xFF333737);
    final pillColor = Color.lerp(fromPillColor, toPillColor, progress) ?? toPillColor;

    final fromLabelColor = fromActive
        ? const Color(0xFFF9FAFA)
        : (fromCompleted ? const Color(0xFFD8DDDD) : const Color(0xFF8C9191));
    final toLabelColor = toActive
        ? const Color(0xFFF9FAFA)
        : (toCompleted ? const Color(0xFFD8DDDD) : const Color(0xFF8C9191));
    final labelColor = Color.lerp(fromLabelColor, toLabelColor, progress) ?? toLabelColor;

    return SizedBox(
      width: 52,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            key: Key('artist_step_indicator_$stepNumber'),
            width: width,
            height: 4.0,
            decoration: BoxDecoration(
              color: pillColor,
              borderRadius: BorderRadius.circular(AppRadius.dragHandle),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            key: Key('artist_step_label_$stepNumber'),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              height: 1.2,
              fontWeight: (progress < 0.5 ? fromActive : toActive)
                  ? FontWeight.w600
                  : FontWeight.w500,
              color: labelColor,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildStepItem(1, _stepLabels[0]),
          const SizedBox(width: 16),
          _buildStepItem(2, _stepLabels[1]),
          const SizedBox(width: 16),
          _buildStepItem(3, _stepLabels[2]),
        ],
      ),
    );
  }
}
