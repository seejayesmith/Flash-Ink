import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/artist.dart';
import '../theme/app_buttons.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import 'flash_image.dart';
import 'animated_favorite_button.dart';

/// Full artist showcase card for the "Browse Artists" feed.
///
/// Features:
/// 1. Top Section: Dynamic Artwork Area showcasing 0 to 4 preview images of flash artwork/tattoos
///    (0: minimalist branded "F" logo placeholder, 1: full hero, 2: 2 vertical columns,
///     3: 3 vertical columns, 4: 2x2 grid).
/// 2. Middle Section: Overlapping circular artist avatar, display name, "Books open" tag,
///    and studio sub-details.
/// 3. Stats Row: Contained 3-column pill for Distance, Available Flash Count, and Min Deposit.
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

  /// Resolves the preview images to display on the card (up to 4 items).
  ///
  /// Priority:
  /// 1. Available/repeatable artworks from [artist.flashArtworks].
  /// 2. Fallback to [artist.previewImages] / [artist.images].
  /// 3. Returns empty if [artist.availablePieces] is 0 or no images exist.
  List<String> _getDisplayImages() {
    if (artist.availablePieces == 0) {
      return const [];
    }

    if (artist.flashArtworks.isNotEmpty) {
      final availableArtworks = artist.flashArtworks
          .where((f) => f.status != FlashStatus.claimed && f.imageUrl.isNotEmpty)
          .map((f) => f.imageUrl)
          .take(4)
          .toList();
      return availableArtworks;
    }

    final list = artist.previewImages.isNotEmpty ? artist.previewImages : artist.images;
    if (list.isNotEmpty) {
      return list.where((url) => url.isNotEmpty).take(4).toList();
    }

    return const [];
  }

  @override
  Widget build(BuildContext context) {
    const cardRadius = AppRadius.radiusLg;

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
          // 1. Top Section: Dynamic Artwork Area with Overlapping Circular Avatar
          Expanded(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Dynamic Artwork Area (0 to 4 pieces) with top rounded corners
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(cardRadius - 1.5),
                      topRight: Radius.circular(cardRadius - 1.5),
                    ),
                    child: _buildArtworkArea(),
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
                // Profile Details (aligned next to the overlapping avatar) with top-aligned Books open badge
                Padding(
                  padding: const EdgeInsets.only(left: 90.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Artist Name
                            Text(
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
                            const SizedBox(height: 3),
                            // Studio Name Row
                            Row(
                              children: [
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
                      if (artist.isBooksOpen) ...[
                        const SizedBox(width: AppSpacing.spaceSm),
                        Container(
                          padding: const EdgeInsets.fromLTRB(8, 2, 8, 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1D16),
                            borderRadius: BorderRadius.circular(AppRadius.radiusXs),
                            border: Border.all(
                              color: const Color(0xFF8C7E55),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            'Books open',
                            maxLines: 1,
                            softWrap: false,
                            textHeightBehavior: const TextHeightBehavior(
                              leadingDistribution: TextLeadingDistribution.even,
                            ),
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFFEEC200),
                              fontSize: 10,
                              height: 1.0,
                              fontWeight: FontWeight.w600,
                            ).copyWith(
                              leadingDistribution: TextLeadingDistribution.even,
                            ),
                          ),
                        ),
                      ],
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

  /// Dynamically builds the artwork display area according to the available flash count (0 to 4).
  Widget _buildArtworkArea() {
    final images = _getDisplayImages();
    switch (images.length) {
      case 0:
        return _buildZeroState();
      case 1:
        return _buildSingleImageLayout(images[0]);
      case 2:
        return _buildTwoImageLayout(images);
      case 3:
        return _buildThreeImageLayout(images);
      case 4:
      default:
        return _buildFourImageLayout(images);
    }
  }

  /// Minimalist empty state when 0 flash pieces are available:
  /// Dark gradient backdrop with a large stylized "F" brand logo in Kaushan Script.
  Widget _buildZeroState() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF222626),
            Color(0xFF151818),
          ],
        ),
      ),
      child: Center(
        child: Text(
          'F',
          style: GoogleFonts.kaushanScript(
            fontSize: 78,
            fontWeight: FontWeight.bold,
            color: const Color(0xFFEEC200).withAlpha(140),
            shadows: const [
              Shadow(
                color: Color(0x33EEC200),
                blurRadius: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Single full-bleed hero artwork
  Widget _buildSingleImageLayout(String url) {
    return _buildGridImage(url);
  }

  /// Two equal vertical side-by-side columns with a 2px gap
  Widget _buildTwoImageLayout(List<String> images) {
    return Row(
      children: [
        Expanded(child: _buildGridImage(images[0])),
        const SizedBox(width: 2),
        Expanded(child: _buildGridImage(images[1])),
      ],
    );
  }

  /// Three equal vertical side-by-side columns with 2px gaps
  Widget _buildThreeImageLayout(List<String> images) {
    return Row(
      children: [
        Expanded(child: _buildGridImage(images[0])),
        const SizedBox(width: 2),
        Expanded(child: _buildGridImage(images[1])),
        const SizedBox(width: 2),
        Expanded(child: _buildGridImage(images[2])),
      ],
    );
  }

  /// Standard 2x2 Image Grid with 2px dividers
  Widget _buildFourImageLayout(List<String> images) {
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(child: _buildGridImage(images[0])),
              const SizedBox(width: 2),
              Expanded(child: _buildGridImage(images[1])),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Expanded(
          child: Row(
            children: [
              Expanded(child: _buildGridImage(images[2])),
              const SizedBox(width: 2),
              Expanded(child: _buildGridImage(images[3])),
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
        width: double.infinity,
        height: double.infinity,
      ),
    );
  }

  /// Stats Row container with 3 columns (Distance, Avail Pieces, Min Deposit)
  Widget _buildStatsRow() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF202323),
        borderRadius: BorderRadius.circular(AppRadius.radiusMd),
        border: Border.all(
          color: const Color(0xFF2D3131),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Column 1: Distance
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: Color(0xFF919696),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        artist.distance.isNotEmpty
                            ? artist.distance
                            : (artist.location.isNotEmpty
                                ? artist.location
                                : 'Location set'),
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFFF9FAFA),
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'DISTANCE',
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
        // Circular Outline Heart Button with micro-pulse animation
        AnimatedFavoriteButton(
          isFavorited: artist.isFavorited,
          onToggle: onToggleFavorite,
          size: AppButtons.ctaHeightPrimary,
          iconSize: 20,
        ),
      ],
    );
  }
}
