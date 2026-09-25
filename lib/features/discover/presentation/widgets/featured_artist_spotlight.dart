import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../models/artist.dart';
import '../../../../screens/artist_profile_screen.dart';
import '../../../../theme/app_buttons.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/flash_image.dart';

/// Row 2: Featured Artist spotlight card (not location based).
class FeaturedArtistSpotlight extends StatelessWidget {
  final Artist artist;

  const FeaturedArtistSpotlight({
    super.key,
    required this.artist,
  });

  @override
  Widget build(BuildContext context) {
    final previewPieces = artist.flashArtworks.take(3).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FEATURED ARTIST SPOTLIGHT',
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.navInactive,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.9,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.cardBackground,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.goldBorder, width: 1.4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(120),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Artist Header Row
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.gold, width: 2),
                      ),
                      child: ClipOval(
                        child: Image.network(
                          artist.avatarUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: AppTheme.onyxContainer,
                            child: const Icon(Icons.person, color: AppTheme.gold),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  artist.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.plusJakartaSans(
                                    color: AppTheme.textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.verified, color: AppTheme.gold, size: 16),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${artist.studioType} • ${artist.location}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              color: AppTheme.gold,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(Icons.star, color: AppTheme.gold, size: 13),
                              const SizedBox(width: 3),
                              Text(
                                '${artist.rating} rating • ${artist.availablePieces} available designs',
                                style: GoogleFonts.plusJakartaSans(
                                  color: AppTheme.navInactive,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (artist.bio.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    artist.bio,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFFC0C5C5),
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 14),

                // Artwork Preview Row
                if (previewPieces.isNotEmpty)
                  Row(
                    children: List.generate(previewPieces.length, (index) {
                      final piece = previewPieces[index];
                      return Expanded(
                        child: Container(
                          margin: EdgeInsets.only(
                            right: index < previewPieces.length - 1 ? 8 : 0,
                          ),
                          height: 90,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.darkBorder),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: FlashImage(
                              urlOrPath: piece.imageUrl,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                const SizedBox(height: 16),

                // Action Button
                AppButtons.primaryCTA(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ArtistProfileScreen(artist: artist),
                      ),
                    );
                  },
                  text: 'VIEW ARTIST & DESIGNS',
                  backgroundColor: AppTheme.gold,
                  foregroundColor: AppTheme.onyxBackground,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
