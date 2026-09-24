import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../theme/app_buttons.dart';
import '../../../../theme/app_radius.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_theme.dart';
import '../../../../theme/app_typography.dart';
import '../../domain/models/artist_profile.dart';

/// Anchored frosted glass action bar or bottom sheet container for initiating
/// custom requests and booking inquiries.
class CustomRequestBar extends StatelessWidget {
  final ArtistProfile artist;
  final VoidCallback onActionPressed;
  final String label;

  const CustomRequestBar({
    super.key,
    required this.artist,
    required this.onActionPressed,
    this.label = 'Request Custom Tattoo',
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: AppTheme.glassBlurSigma,
          sigmaY: AppTheme.glassBlurSigma,
        ),
        child: Container(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.spaceLg,
            AppSpacing.spaceSm,
            AppSpacing.spaceLg,
            AppSpacing.spaceSm + bottomInset,
          ),
          decoration: BoxDecoration(
            color: AppTheme.onyxSurface.withAlpha(AppTheme.glassBaseTintAlpha),
            border: const Border(
              top: BorderSide(
                color: AppTheme.goldBorder,
                width: 1.0,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Have a unique piece in mind?',
                      style: AppTypography.label.copyWith(
                        color: AppTheme.navInactive,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.spaceXxs - 2),
                    Text(
                      'Min Deposit \$${artist.minDeposit}',
                      style: AppTypography.bodySmallBold.copyWith(
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.spaceMd),
              AppButtons.primaryCTA(
                width: 180,
                text: label,
                onPressed: onActionPressed,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Modal bottom sheet for booking custom tattoo appointments or quick brief submissions.
class BookingActionSheet extends StatelessWidget {
  final ArtistProfile artist;
  final VoidCallback onConfirm;

  const BookingActionSheet({
    super.key,
    required this.artist,
    required this.onConfirm,
  });

  static Future<void> show(
    BuildContext context, {
    required ArtistProfile artist,
    required VoidCallback onConfirm,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BookingActionSheet(
        artist: artist,
        onConfirm: onConfirm,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.onyxContainer,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.radiusXl),
        ),
        border: Border.all(
          color: AppTheme.goldBorder,
          width: 1.0,
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.spaceLg,
        AppSpacing.spaceMd,
        AppSpacing.spaceLg,
        AppSpacing.spaceLg + bottomPadding,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.darkBorder,
                borderRadius: BorderRadius.circular(AppRadius.radiusFull),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.spaceMd),

          Text(
            'Book with ${artist.name}',
            style: AppTypography.h4.copyWith(
              color: AppTheme.gold,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.spaceXs),
          Text(
            'Submit a custom concept brief or reserve an open calendar slot.',
            style: AppTypography.bodySmall.copyWith(
              color: AppTheme.navInactive,
            ),
          ),
          const SizedBox(height: AppSpacing.spaceLg),

          AppButtons.primaryCTA(
            text: 'Continue to Brief',
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
          ),
        ],
      ),
    );
  }
}
