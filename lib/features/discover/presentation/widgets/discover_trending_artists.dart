import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../models/artist.dart';
import '../../../../screens/artist_profile_screen.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_theme.dart';

/// Row 1: Trending artists in the local area rendered as an elegant horizontal scrolling carousel.
class DiscoverTrendingArtists extends StatelessWidget {
  final List<Artist> artists;

  const DiscoverTrendingArtists({
    super.key,
    required this.artists,
  });

  @override
  Widget build(BuildContext context) {
    if (artists.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spaceLg),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TRENDING IN YOUR AREA',
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.navInactive,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.9,
                ),
              ),
              Text(
                'View All',
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.gold,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 148,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spaceLg),
            scrollDirection: Axis.horizontal,
            itemCount: artists.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final artist = artists[index];
              return _buildArtistItem(context, artist);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildArtistItem(BuildContext context, Artist artist) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ArtistProfileScreen(artist: artist),
          ),
        );
      },
      child: Container(
        width: 120,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTheme.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.cardBorder, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(80),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.goldBorder, width: 1.5),
                  ),
                  child: ClipOval(
                    child: Image.network(
                      artist.avatarUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: AppTheme.onyxContainer,
                        child: const Icon(Icons.person, color: AppTheme.gold, size: 26),
                      ),
                    ),
                  ),
                ),
                if (artist.isBooksOpen)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4ADE80),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.cardBackground, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              artist.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.star, color: AppTheme.gold, size: 12),
                const SizedBox(width: 3),
                Text(
                  artist.rating.toStringAsFixed(1),
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              artist.studioType,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.navInactive,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
