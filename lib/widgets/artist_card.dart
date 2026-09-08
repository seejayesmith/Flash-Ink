import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/artist.dart';
import '../theme/app_spacing.dart';
import '../theme/app_buttons.dart';
import 'flash_image.dart';

/// Full artist showcase card for the "Browse Artists" feed.
///
/// Features:
/// 1. Top Section: 2x2 Artwork Grid showcasing 4 preview images of flash artwork/tattoos.
/// 2. Middle Section: Overlapping circular artist avatar, display name, "Books open" tag,
///    and location/studio sub-details.
/// 3. Stats Row: Contained 3-column pill for Rating, Available Flash Count, and Min Deposit.
/// 4. Action Row: Full-width "VIEW PROFILE" primary accent CTA and circular favorite heart button.
class ArtistCard extends StatelessWidget {
  final Artist artist;
  final VoidCallback? onViewProfile;
  final VoidCallback? onToggleFavorite;
  final void Function(FlashArtwork flash)? onClaimFlash;

  const ArtistCard({
    super.key,
    required this.artist,
    this.onViewProfile,
    this.onToggleFavorite,
    this.onClaimFlash,
  });

  String _imageUrlAt(int index) {
    final list = artist.previewImages.isNotEmpty ? artist.previewImages : artist.images;
    if (list.isNotEmpty) {
      final img = list[index % list.length];
      if (img.isNotEmpty) return img;
    }
    if (artist.flashArtworks.isNotEmpty) {
      final img = artist.flashArtworks[index % artist.flashArtworks.length].imageUrl;
      if (img.isNotEmpty) return img;
    }
    return 'assets/images/flash_traditional_dagger.jpg';
  }

  @override
  Widget build(BuildContext context) {
    const cardRadius = 24.0;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF171A1A),
        borderRadius: BorderRadius.circular(cardRadius),
        border: Border.all(
          color: const Color(0xFF38352A), // Subtle brass/golden-tinted border
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(160),
            blurRadius: 18,
            spreadRadius: 1,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Top Section: 2x2 Artwork Grid with Overlapping Circular Avatar
          Expanded(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // 2x2 Image Grid with top rounded corners
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(cardRadius - 1.5),
                      topRight: Radius.circular(cardRadius - 1.5),
                    ),
                    child: _buildImageGrid(),
                  ),
                ),

                // Overlapping Circular Artist Avatar
                Positioned(
                  left: AppSpacing.spaceLg,
                  bottom: -52,
                  child: Container(
                    width: 82,
                    height: 82,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF171A1A),
                        width: 3.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(120),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.network(
                        artist.avatarUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: const Color(0xFF262929),
                            child: const Icon(
                              Icons.person,
                              color: Color(0xFFEEC200),
                              size: 38,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. Middle Section, Stats Row, and Action Row
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.spaceLg,
              right: AppSpacing.spaceLg,
              top: AppSpacing.spaceSm,
              bottom: 18.0,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Details (aligned next to the overlapping avatar)
                Padding(
                  padding: const EdgeInsets.only(left: 90.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Artist Name + Books Open Tag
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              artist.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                color: const Color(0xFFEEC200),
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                          if (artist.isBooksOpen) ...[
                            AppGaps.gapSm,
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A1D16),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: const Color(0xFF8C7E55),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                'Books open',
                                style: GoogleFonts.plusJakartaSans(
                                  color: const Color(0xFFEEC200),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      // Location and Studio Type Row
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: Color(0xFF919696),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            artist.location,
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFF919696),
                              fontSize: 13,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Text(
                              '•',
                              style: GoogleFonts.plusJakartaSans(
                                color: const Color(0xFF6B7280),
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.storefront_outlined,
                            size: 14,
                            color: Color(0xFF919696),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              artist.studioType,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                color: const Color(0xFF919696),
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // 3. Stats Row (Contained Card/Pill)
                _buildStatsRow(),

                const SizedBox(height: 18),

                // 4. Action Row: "VIEW PROFILE" full-width CTA + Favorite Button
                _buildActionRow(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 2x2 Image Grid with 2px dividers showcasing 4 flash preview images
  Widget _buildImageGrid() {
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(child: _buildGridImage(_imageUrlAt(0))),
              const SizedBox(width: 2),
              Expanded(child: _buildGridImage(_imageUrlAt(1))),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Expanded(
          child: Row(
            children: [
              Expanded(child: _buildGridImage(_imageUrlAt(2))),
              const SizedBox(width: 2),
              Expanded(child: _buildGridImage(_imageUrlAt(3))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGridImage(String url) {
    return Container(
      color: const Color(0xFF262929),
      child: FlashImage(
        urlOrPath: url,
        fit: BoxFit.cover,
      ),
    );
  }

  /// Stats Row container with 3 columns (Rating, Avail Pieces, Min Deposit)
  Widget _buildStatsRow() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF202323),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF2D3131),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Column 1: Rating
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.star,
                      size: 15,
                      color: Color(0xFFEEC200),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      artist.rating.toStringAsFixed(1),
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFFF9FAFA),
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'RATING',
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF919696),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),

          // Divider 1
          Container(
            width: 1,
            height: 26,
            color: const Color(0xFF333737),
          ),

          // Column 2: Available Pieces
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${artist.availablePieces}',
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFFF9FAFA),
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'AVAIL PIECES',
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF919696),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),

          // Divider 2
          Container(
            width: 1,
            height: 26,
            color: const Color(0xFF333737),
          ),

          // Column 3: Min Deposit
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '\$${artist.minDeposit}',
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFFF9FAFA),
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'MIN DEPOSIT',
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF919696),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Action Row: full-width "VIEW PROFILE" primary CTA + circular outline heart button
  Widget _buildActionRow() {
    return Row(
      children: [
        // "VIEW PROFILE" full-width CTA adhering to 42.0px height
        Expanded(
          child: AppButtons.primaryCTA(
            onPressed: onViewProfile,
            text: 'VIEW PROFILE',
            backgroundColor: const Color(0xFFEEC200),
            foregroundColor: const Color(0xFF121414),
          ),
        ),
        AppGaps.gapSm,
        // Circular Outline Heart Button
        GestureDetector(
          onTap: onToggleFavorite,
          child: Container(
            width: AppButtons.ctaHeightPrimary, // 42.0px height & width
            height: AppButtons.ctaHeightPrimary,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF1E2020),
              border: Border.all(
                color: artist.isFavorited
                    ? const Color(0xFFEEC200)
                    : const Color(0xFF4D5252),
                width: 1.5,
              ),
            ),
            child: Icon(
              artist.isFavorited ? Icons.favorite : Icons.favorite_border,
              color: artist.isFavorited
                  ? const Color(0xFFEEC200)
                  : const Color(0xFFF9FAFA),
              size: 20,
            ),
          ),
        ),
      ],
    );
  }
}
