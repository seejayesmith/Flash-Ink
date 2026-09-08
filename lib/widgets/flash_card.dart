import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/artist.dart';
import '../theme/app_buttons.dart';
import '../theme/app_spacing.dart';
import 'flash_image.dart';

/// A card component dedicated to displaying a purchasable tattoo flash design.
///
/// Features:
/// - Flash artwork as the primary visual anchor (framed at 4:5 vertical or custom aspect ratio).
/// - Prominent metadata overlays: Flash title, artist name, price badge, and availability status.
/// - Clear purchasing CTA: "INSTANT CLAIM" / "BOOK FLASH" routing to confirmation.
class FlashCard extends StatelessWidget {
  final FlashArtwork flash;
  final Artist? artist;
  final double aspectRatio;
  final VoidCallback? onSelect;
  final VoidCallback? onClaim;
  final VoidCallback? onToggleFavorite;
  final VoidCallback? onViewArtist;
  final bool isFavorited;
  final bool showFullDetails;

  const FlashCard({
    super.key,
    required this.flash,
    this.artist,
    this.aspectRatio = 4 / 5,
    this.onSelect,
    this.onClaim,
    this.onToggleFavorite,
    this.onViewArtist,
    this.isFavorited = false,
    this.showFullDetails = true,
  });

  String get _artistDisplayName {
    if (artist != null && artist!.name.isNotEmpty) {
      return artist!.name;
    }
    if (flash.artistName != null && flash.artistName!.isNotEmpty) {
      return flash.artistName!;
    }
    return 'Flash Artist';
  }

  String get _locationDisplayName {
    if (artist != null && artist!.location.isNotEmpty) {
      return artist!.location;
    }
    return flash.location;
  }

  void _handleDefaultClaim(BuildContext context) {
    if (onClaim != null) {
      onClaim!();
      return;
    }
    showFlashBookingSheet(context, flash, artist: artist);
  }

  @override
  Widget build(BuildContext context) {
    const cardRadius = 24.0;
    final isClaimed = flash.isClaimed;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF171A1A),
        borderRadius: BorderRadius.circular(cardRadius),
        border: Border.all(
          color: isClaimed ? const Color(0xFF262929) : const Color(0xFF38352A),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(150),
            blurRadius: 16,
            spreadRadius: 1,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(cardRadius),
          onTap: isClaimed ? null : (onSelect ?? () => _handleDefaultClaim(context)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Primary Visual Anchor: Flash Artwork with Badges
              _buildArtworkAnchor(context, cardRadius),

              // 2. Metadata Section & CTA
              Padding(
                padding: const EdgeInsets.all(AppSpacing.spaceMd),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Flash Title + Price Row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            flash.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFFF9FAFA),
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Price Badge
                        _buildPriceBadge(),
                      ],
                    ),

                    const SizedBox(height: 4),

                    // Artist attribution line
                    GestureDetector(
                      onTap: onViewArtist,
                      child: Row(
                        children: [
                          const Icon(
                            Icons.brush_outlined,
                            size: 13,
                            color: Color(0xFFEEC200),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'by $_artistDisplayName',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                color: const Color(0xFFEEC200),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
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
                          Flexible(
                            child: Text(
                              _locationDisplayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                color: const Color(0xFF919696),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (showFullDetails) ...[
                      const SizedBox(height: 12),
                      // Flash Specs Chips Row (Dimensions, Estimated Time, Placement)
                      _buildSpecsRow(),
                    ],

                    const SizedBox(height: 16),

                    // 3. Purchasing Action Row (Instant Claim CTA + Favorite)
                    _buildActionRow(context),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Visual Anchor: Artwork framed cleanly without awkward cropping
  Widget _buildArtworkAnchor(BuildContext context, double cardRadius) {
    return ClipRRect(
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(cardRadius - 1.5),
        topRight: Radius.circular(cardRadius - 1.5),
      ),
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Artwork Image with dark ink framing container
            Container(
              color: const Color(0xFF1F2222),
              child: FlashImage(
                urlOrPath: flash.imageUrl,
                fit: BoxFit.cover,
                errorWidget: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF2B2E2E), Color(0xFF1A1C1C)],
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.draw_outlined,
                          color: Color(0xFFEEC200),
                          size: 38,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          flash.title,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFF919696),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Subtle gradient overlay at bottom for smooth contrast
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 60,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      const Color(0xFF171A1A).withAlpha(180),
                    ],
                  ),
                ),
              ),
            ),

            // Top-Left: Availability Status Badge
            Positioned(
              top: 12,
              left: 12,
              child: _buildStatusBadge(),
            ),

            // Top-Right: Quick Favorite Button
            Positioned(
              top: 10,
              right: 10,
              child: GestureDetector(
                onTap: onToggleFavorite,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF171A1A).withAlpha(200),
                    border: Border.all(
                      color: isFavorited
                          ? const Color(0xFFEEC200)
                          : const Color(0xFF383B3B),
                      width: 1.2,
                    ),
                  ),
                  child: Icon(
                    isFavorited ? Icons.favorite : Icons.favorite_border,
                    color: isFavorited
                        ? const Color(0xFFEEC200)
                        : const Color(0xFFF9FAFA),
                    size: 18,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Status badge overlay: AVAILABLE, CLAIMED, REPEATABLE
  Widget _buildStatusBadge() {
    Color bg;
    Color border;
    Color text;
    String label;
    IconData icon;

    switch (flash.status) {
      case FlashStatus.claimed:
        bg = const Color(0xFF261919).withAlpha(230);
        border = const Color(0xFF7A3535);
        text = const Color(0xFFF87171);
        label = 'CLAIMED (1/1)';
        icon = Icons.lock_outline;
        break;
      case FlashStatus.repeatable:
        bg = const Color(0xFF15222E).withAlpha(230);
        border = const Color(0xFF2B5B84);
        text = const Color(0xFF38BDF8);
        label = 'REPEATABLE';
        icon = Icons.all_inclusive;
        break;
      case FlashStatus.available:
      default:
        bg = const Color(0xFF1A2218).withAlpha(230);
        border = const Color(0xFF436938);
        text = const Color(0xFF4ADE80);
        label = 'AVAILABLE';
        icon = Icons.check_circle_outline;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(80),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: text),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              color: text,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }

  /// Price badge prominently displaying full price and deposit
  Widget _buildPriceBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF262929),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF4D4530),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '\$${flash.price}',
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFFEEC200),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            '\$${flash.deposit} dep',
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFF919696),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// Specs row: Dimensions, estimated duration, placement
  Widget _buildSpecsRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2121),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF2B2F2F), width: 1),
      ),
      child: Row(
        children: [
          Expanded(child: _buildSpecChip(Icons.straighten_outlined, flash.dimensions)),
          Container(width: 1, height: 16, color: const Color(0xFF333737)),
          Expanded(child: _buildSpecChip(Icons.timer_outlined, flash.estimatedTime)),
          Container(width: 1, height: 16, color: const Color(0xFF333737)),
          Expanded(child: _buildSpecChip(Icons.place_outlined, flash.location)),
        ],
      ),
    );
  }

  Widget _buildSpecChip(IconData icon, String text) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 12, color: const Color(0xFF919696)),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFFD1D5DB),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  /// Purchasing Action Row
  Widget _buildActionRow(BuildContext context) {
    if (flash.isClaimed) {
      return Container(
        height: AppButtons.ctaHeightPrimary,
        width: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF222626),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF333737)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 16, color: Color(0xFF6B7280)),
            const SizedBox(width: 6),
            Text(
              'PIECE ALREADY CLAIMED',
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF6B7280),
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: AppButtons.primaryCTA(
            onPressed: () => _handleDefaultClaim(context),
            text: 'INSTANT CLAIM • \$${flash.deposit} DEP',
            backgroundColor: const Color(0xFFEEC200),
            foregroundColor: const Color(0xFF121414),
          ),
        ),
      ],
    );
  }
}

/// Modal bottom sheet for booking/claiming a flash design
void showFlashBookingSheet(
  BuildContext context,
  FlashArtwork flash, {
  Artist? artist,
  VoidCallback? onConfirmed,
}) {
  final artistName = artist?.name ?? flash.artistName ?? 'Artist';
  final artistLocation = artist?.location ?? flash.location;

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (modalContext) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          return Container(
            decoration: const BoxDecoration(
              color: Color(0xFF171A1A),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(
                top: BorderSide(color: Color(0xFF38352A), width: 1.5),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Grab Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4D5252),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Header with Title and Artist
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              flash.title,
                              style: GoogleFonts.plusJakartaSans(
                                color: const Color(0xFFF9FAFA),
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'by $artistName • $artistLocation',
                              style: GoogleFonts.plusJakartaSans(
                                color: const Color(0xFFEEC200),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A2218),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF436938)),
                        ),
                        child: Text(
                          flash.status.label.toUpperCase(),
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFF4ADE80),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Flash Artwork Preview
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: AspectRatio(
                      aspectRatio: 1.3,
                      child: Image.network(
                        flash.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: const Color(0xFF262929),
                            child: const Center(
                              child: Icon(
                                Icons.draw_outlined,
                                color: Color(0xFFEEC200),
                                size: 48,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Price Breakdown Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF202323),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF2D3131)),
                    ),
                    child: Column(
                      children: [
                        _buildPriceRow('Total Flash Price', '\$${flash.price}', isBold: false),
                        const SizedBox(height: 6),
                        _buildPriceRow('Deposit Due Today', '\$${flash.deposit}', isBold: true, highlight: true),
                        const Divider(color: Color(0xFF333737), height: 16),
                        _buildPriceRow(
                          'Balance Due at Appointment',
                          '\$${flash.price - flash.deposit}',
                          isBold: false,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Specs Row (Dimensions, Estimated Time, Placement)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1E1E),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF2B2F2F)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildSpecItem('SIZE', flash.dimensions),
                        Container(width: 1, height: 24, color: const Color(0xFF333737)),
                        _buildSpecItem('EST. TIME', flash.estimatedTime),
                        Container(width: 1, height: 24, color: const Color(0xFF333737)),
                        _buildSpecItem('PLACEMENT', flash.location),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Policy notice
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline, size: 14, color: Color(0xFF919696)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Flash pieces are tattooed as illustrated. The deposit reserves this design and your studio session time.',
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFF919696),
                            fontSize: 11,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Confirm Claim Button
                  AppButtons.primaryCTA(
                    onPressed: () {
                      Navigator.pop(modalContext);
                      if (onConfirmed != null) {
                        onConfirmed();
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Claimed "${flash.title}" by $artistName! Deposit confirmed.',
                          ),
                          backgroundColor: const Color(0xFF262929),
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    },
                    text: 'CONFIRM CLAIM & PAY \$${flash.deposit} DEPOSIT',
                    backgroundColor: const Color(0xFFEEC200),
                    foregroundColor: const Color(0xFF121414),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

Widget _buildPriceRow(String label, String value, {bool isBold = false, bool highlight = false}) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          color: highlight ? const Color(0xFFF9FAFA) : const Color(0xFF919696),
          fontSize: 13,
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      Text(
        value,
        style: GoogleFonts.plusJakartaSans(
          color: highlight ? const Color(0xFFEEC200) : const Color(0xFFF9FAFA),
          fontSize: highlight ? 15 : 13,
          fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
        ),
      ),
    ],
  );
}

Widget _buildSpecItem(String label, String value) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          color: const Color(0xFF919696),
          fontSize: 9,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
      const SizedBox(height: 3),
      Text(
        value,
        style: GoogleFonts.plusJakartaSans(
          color: const Color(0xFFF9FAFA),
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    ],
  );
}
