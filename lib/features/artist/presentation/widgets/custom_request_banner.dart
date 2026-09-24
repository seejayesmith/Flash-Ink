import 'package:flutter/material.dart';
import '../../../../screens/custom_request_screen.dart';
import '../../../../theme/app_radius.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_theme.dart';
import '../../../../theme/app_typography.dart';
import '../../domain/models/artist_profile.dart';

/// Interactive mid-page banner inviting clients to submit a custom tattoo brief.
class CustomRequestBanner extends StatelessWidget {
  final ArtistProfile artist;
  final VoidCallback? onTap;

  const CustomRequestBanner({
    super.key,
    required this.artist,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spaceLg),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap ??
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CustomRequestScreen(artist: artist),
                  ),
                );
              },
          borderRadius: BorderRadius.circular(AppRadius.radiusLg),
          child: Ink(
            padding: const EdgeInsets.all(AppSpacing.spaceSm + 2),
            decoration: BoxDecoration(
              color: AppTheme.cardBackground,
              borderRadius: BorderRadius.circular(AppRadius.radiusLg),
              border: Border.all(
                color: AppTheme.goldBorder,
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(80),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                // Tag / Brief Icon Container
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.goldBadgeBackground,
                    borderRadius: BorderRadius.circular(AppRadius.radiusSm + 2),
                  ),
                  child: const Icon(
                    Icons.local_offer_outlined,
                    color: AppTheme.gold,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppSpacing.spaceSm),

                // Copy details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Got an idea? Submit a Custom Request.',
                        style: AppTypography.bodySmallBold.copyWith(
                          color: AppTheme.textPrimary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.spaceXxs - 1),
                      RichText(
                        text: TextSpan(
                          style: AppTypography.label.copyWith(
                            color: AppTheme.navInactive,
                            fontSize: 11,
                          ),
                          children: const [
                            TextSpan(text: 'Skip the DM wait '),
                            TextSpan(
                              text: '• ',
                              style: TextStyle(
                                color: AppTheme.gold,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextSpan(text: '2 minute guided brief'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.spaceXs),

                // Yellow circular CTA button with forward arrow
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: AppTheme.gold,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_forward,
                    color: AppTheme.onyxBackground,
                    size: 16,
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
