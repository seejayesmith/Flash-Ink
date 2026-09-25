import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/artist.dart';
import '../theme/app_spacing.dart';
import '../widgets/flash_image.dart';
import 'booking/flash_booking_screen.dart';

class FlashDetailsScreen extends StatefulWidget {
  final FlashArtwork flash;
  final Artist? artist;

  const FlashDetailsScreen({
    super.key,
    required this.flash,
    this.artist,
  });

  @override
  State<FlashDetailsScreen> createState() => _FlashDetailsScreenState();
}

class _FlashDetailsScreenState extends State<FlashDetailsScreen> {
  bool _isClaimed = false;
  bool _isFavorited = false;

  @override
  void initState() {
    super.initState();
    _isClaimed = widget.flash.isClaimed;
  }

  void _claimFlash() async {
    final booked = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => FlashBookingScreen(
          flash: widget.flash,
          artist: widget.artist,
        ),
      ),
    );

    if (booked == true && mounted) {
      setState(() {
        _isClaimed = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF1E2020),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: Color(0xFFEEC200), width: 1),
          ),
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Color(0xFFEEC200), size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Reserved "${widget.flash.title}"! Deposit \$${widget.flash.deposit} confirmed.',
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFFF9FAFA),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final flash = widget.flash;
    final artist = widget.artist;

    return Scaffold(
      backgroundColor: const Color(0xFF121414),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121414),
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFFF9FAFA)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Flash Artwork',
          style: GoogleFonts.plusJakartaSans(
            color: const Color(0xFFF9FAFA),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              _isFavorited ? Icons.favorite : Icons.favorite_border,
              color: _isFavorited ? const Color(0xFFEF4444) : const Color(0xFFF9FAFA),
            ),
            onPressed: () {
              setState(() {
                _isFavorited = !_isFavorited;
              });
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spaceLg, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Artwork Hero Image
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B1E1E),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF2E3333)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(120),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: AspectRatio(
                          aspectRatio: 0.95,
                          child: FlashImage(
                            urlOrPath: flash.imageUrl,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Title and Price Row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                flash.title,
                                style: GoogleFonts.plusJakartaSans(
                                  color: const Color(0xFFF9FAFA),
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: _isClaimed
                                      ? const Color(0xFF2E1C1C)
                                      : const Color(0xFF1B281B),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: _isClaimed
                                        ? const Color(0xFF7A3535)
                                        : const Color(0xFF386835),
                                  ),
                                ),
                                child: Text(
                                  _isClaimed ? 'CLAIMED' : 'AVAILABLE (1-OF-1)',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: _isClaimed
                                        ? const Color(0xFFF87171)
                                        : const Color(0xFF4ADE80),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '\$${flash.fullPrice}',
                              style: GoogleFonts.plusJakartaSans(
                                color: const Color(0xFFEEC200),
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Full Price',
                              style: GoogleFonts.plusJakartaSans(
                                color: const Color(0xFF919696),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Specs Container
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B1E1E),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF2E3333)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildSpecItem('PLACEMENT', flash.location),
                          Container(width: 1, height: 32, color: const Color(0xFF333737)),
                          _buildSpecItem('SIZE', flash.size),
                          Container(width: 1, height: 32, color: const Color(0xFF333737)),
                          _buildSpecItem('DEPOSIT', '\$${flash.deposit}', valueColor: const Color(0xFFEEC200)),
                          Container(width: 1, height: 32, color: const Color(0xFF333737)),
                          _buildSpecItem('EST. TIME', flash.estimatedTime),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Artist Info Tile
                    if (artist != null) ...[
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1B1E1E),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFF2E3333)),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundImage: NetworkImage(artist.avatarUrl),
                                backgroundColor: const Color(0xFF262929),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Designed by ${artist.name}',
                                      style: GoogleFonts.plusJakartaSans(
                                        color: const Color(0xFFF9FAFA),
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${artist.location} • ${artist.studioType}',
                                      style: GoogleFonts.plusJakartaSans(
                                        color: const Color(0xFF919696),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right,
                                color: Color(0xFF919696),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Booking Policy Callout
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF181A1A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF2A2D2D)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline, color: Color(0xFFEEC200), size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Claiming reserves this exclusive piece. The \$${flash.deposit} deposit goes directly toward your final tattoo balance.',
                              style: GoogleFonts.plusJakartaSans(
                                color: const Color(0xFFC0C5C5),
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),

            // Bottom CTA
            Container(
              padding: const EdgeInsets.all(AppSpacing.spaceLg),
              decoration: const BoxDecoration(
                color: Color(0xFF151717),
                border: Border(
                  top: BorderSide(color: Color(0xFF262929), width: 1),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isClaimed ? null : _claimFlash,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEEC200),
                    foregroundColor: const Color(0xFF121414),
                    disabledBackgroundColor: const Color(0xFF2E3333),
                    disabledForegroundColor: const Color(0xFF6B7272),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    _isClaimed ? 'PIECE ALREADY CLAIMED' : 'CLAIM & BOOK FLASH',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpecItem(String label, String value, {Color valueColor = const Color(0xFFF9FAFA)}) {
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
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            color: valueColor,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
