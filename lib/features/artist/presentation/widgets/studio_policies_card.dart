import 'package:flutter/material.dart';
import '../../../../theme/app_radius.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_theme.dart';
import '../../../../theme/app_typography.dart';
import '../../domain/models/artist_profile.dart';

/// Card presenting the artist's studio policies, deposit terms, and studio verification badge.
class StudioPoliciesCard extends StatelessWidget {
  final ArtistProfile artist;

  const StudioPoliciesCard({
    super.key,
    required this.artist,
  });

  @override
  Widget build(BuildContext context) {
    final policies = artist.policies;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spaceLg),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.spaceMd),
        decoration: BoxDecoration(
          color: AppTheme.cardBackground,
          borderRadius: BorderRadius.circular(AppRadius.radiusLg),
          border: Border.all(
            color: AppTheme.cardBorder,
            width: 1.2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: Shield Icon, Title, and Verified Studio Badge
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.spaceXxs + 2),
                  decoration: BoxDecoration(
                    color: AppTheme.goldBadgeBackground,
                    borderRadius: BorderRadius.circular(AppRadius.radiusSm),
                  ),
                  child: const Icon(
                    Icons.shield_outlined,
                    color: AppTheme.gold,
                    size: 18,
                  ),
                ),
                const SizedBox(width: AppSpacing.spaceSm - 2),
                Expanded(
                  child: Text(
                    'STUDIO POLICIES & HOUSE RULES',
                    style: AppTypography.labelBold.copyWith(
                      color: AppTheme.textPrimary,
                      fontSize: 12,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                if (artist.isVerifiedStudio)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.spaceXs,
                      vertical: AppSpacing.spaceXxs - 1,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.goldBadgeBackground,
                      borderRadius: BorderRadius.circular(AppRadius.radiusXs),
                      border: Border.all(
                        color: AppTheme.goldBadgeBorder,
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      'VERIFIED STUDIO',
                      style: AppTypography.labelBold.copyWith(
                        color: AppTheme.gold,
                        fontSize: 9,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.spaceLg - 4),

            // Policies items
            ...policies.map((policy) {
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.spaceMd + 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.spaceXxs + 2),
                      decoration: BoxDecoration(
                        color: AppTheme.actionButtonBackground,
                        borderRadius: BorderRadius.circular(AppRadius.radiusXs + 2),
                      ),
                      child: Icon(
                        _getPolicyIcon(policy.iconKey),
                        color: AppTheme.gold,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.spaceSm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            policy.title,
                            style: AppTypography.bodySmallBold.copyWith(
                              color: AppTheme.textPrimary,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.spaceXxs - 1),
                          Text(
                            policy.description,
                            style: AppTypography.label.copyWith(
                              color: AppTheme.navInactive,
                              fontSize: 11,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  IconData _getPolicyIcon(String key) {
    switch (key.toLowerCase()) {
      case 'deposit':
        return Icons.credit_card_outlined;
      case 'health':
        return Icons.health_and_safety_outlined;
      case 'etiquette':
        return Icons.groups_outlined;
      case 'touchup':
        return Icons.auto_awesome_outlined;
      default:
        return Icons.info_outline;
    }
  }
}
