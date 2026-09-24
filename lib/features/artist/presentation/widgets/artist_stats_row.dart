import 'package:flutter/material.dart';
import '../../../../theme/app_radius.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_theme.dart';
import '../../../../theme/app_typography.dart';
import '../../../../widgets/adaptive_glass_container.dart';
import '../../domain/models/artist_profile.dart';

/// Renders the key metrics row for an artist profile:
/// Rating (with gold star), Available Pieces, and Minimum Deposit.
class ArtistStatsRow extends StatelessWidget {
  final ArtistProfile artist;

  const ArtistStatsRow({
    super.key,
    required this.artist,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spaceLg),
      child: AdaptiveGlassContainer(
        borderRadius: AppRadius.radiusLg,
        unselectedBorderColor: AppTheme.cardBorder,
        unselectedBorderWidth: 1.0,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.spaceMd,
            horizontal: AppSpacing.spaceXs,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatItem(
                context,
                icon: Icons.star,
                value: artist.rating.toStringAsFixed(1),
                label: 'RATING',
                valueColor: AppTheme.gold,
              ),
              Container(
                width: 1,
                height: 28,
                color: AppTheme.statDivider,
              ),
              _buildStatItem(
                context,
                value: artist.availablePieces.toString(),
                label: 'AVAIL PIECES',
                valueColor: AppTheme.textPrimary,
              ),
              Container(
                width: 1,
                height: 28,
                color: AppTheme.statDivider,
              ),
              _buildStatItem(
                context,
                value: '\$${artist.minDeposit}',
                label: 'MIN DEPOSIT',
                valueColor: AppTheme.textPrimary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context, {
    IconData? icon,
    required String value,
    required String label,
    required Color valueColor,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, color: valueColor, size: 16),
              const SizedBox(width: AppSpacing.spaceXxs),
            ],
            Text(
              value,
              style: AppTypography.bodyMedBold.copyWith(
                color: valueColor,
                height: 1.1,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.spaceXxs),
        Text(
          label,
          style: AppTypography.labelBold.copyWith(
            color: AppTheme.navInactive,
            letterSpacing: 0.6,
          ),
        ),
      ],
    );
  }
}
