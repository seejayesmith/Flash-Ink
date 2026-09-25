import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/flash_image.dart';
import '../../domain/models/explore_studio.dart';

/// Card component displaying tattoo studio details, resident artists, and style specialties.
class StudioCard extends StatelessWidget {
  final ExploreStudio studio;
  final VoidCallback? onTap;

  const StudioCard({
    super.key,
    required this.studio,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap ??
          () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Selected studio: ${studio.name}'),
                duration: const Duration(seconds: 1),
              ),
            );
          },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: AppTheme.cardBackground,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.cardBorder, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(90),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Studio Cover Image with rating badge overlay
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
              child: SizedBox(
                height: 120,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    FlashImage(
                      urlOrPath: studio.imageUrl,
                      fit: BoxFit.cover,
                    ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withAlpha(180),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 12,
                      bottom: 10,
                      child: Row(
                        children: [
                          const Icon(Icons.star, color: AppTheme.gold, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            '${studio.rating} (${studio.reviewCount} reviews)',
                            style: GoogleFonts.plusJakartaSans(
                              color: AppTheme.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      right: 12,
                      top: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.goldBadgeBackground,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.goldBadgeBorder),
                        ),
                        child: Text(
                          '${studio.residentArtistsCount} ARTISTS',
                          style: GoogleFonts.plusJakartaSans(
                            color: AppTheme.gold,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Metadata Content
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          studio.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            color: AppTheme.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (studio.isVerified) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.verified, color: AppTheme.gold, size: 16),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, color: AppTheme.navInactive, size: 13),
                      const SizedBox(width: 4),
                      Text(
                        '${studio.address}, ${studio.city}',
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.navInactive,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Styles Chips
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: studio.styles.map((style) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.onyxContainer,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.darkBorder),
                        ),
                        child: Text(
                          style,
                          style: GoogleFonts.plusJakartaSans(
                            color: AppTheme.textPrimary,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
