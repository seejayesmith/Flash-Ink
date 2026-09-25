import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../models/artist.dart';
import '../../../../screens/flash_details_screen.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/flash_image.dart';

/// Row 3+: Trending flash pieces responsive grid with quick view/claim.
class TrendingFlashGrid extends StatelessWidget {
  final List<FlashArtwork> flashPieces;

  const TrendingFlashGrid({
    super.key,
    required this.flashPieces,
  });

  @override
  Widget build(BuildContext context) {
    if (flashPieces.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TRENDING FLASH DROPS',
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.navInactive,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.9,
                ),
              ),
              Text(
                '${flashPieces.length} Designs',
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.gold,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: flashPieces.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 14,
              childAspectRatio: 0.62,
            ),
            itemBuilder: (context, index) {
              final piece = flashPieces[index];
              return _buildPieceCard(context, piece);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPieceCard(BuildContext context, FlashArtwork piece) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FlashDetailsScreen(flash: piece),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.cardBorder, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(90),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Artwork Image
            Expanded(
              flex: 11,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                child: FlashImage(
                  urlOrPath: piece.imageUrl,
                  fit: BoxFit.cover,
                ),
              ),
            ),

            // Metadata
            Expanded(
              flex: 8,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      piece.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      piece.artistName != null ? 'by ${piece.artistName}' : piece.location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.navInactive,
                        fontSize: 11,
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '\$${piece.price}',
                          style: GoogleFonts.plusJakartaSans(
                            color: AppTheme.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.goldBadgeBackground,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppTheme.goldBadgeBorder),
                          ),
                          child: Text(
                            '\$${piece.deposit} dep',
                            style: GoogleFonts.plusJakartaSans(
                              color: AppTheme.gold,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
