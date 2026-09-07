import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/artist.dart';
import '../theme/app_spacing.dart';
import '../widgets/adaptive_glass_container.dart';

class ArtistProfileScreen extends StatefulWidget {
  final Artist artist;

  const ArtistProfileScreen({super.key, required this.artist});

  @override
  State<ArtistProfileScreen> createState() => _ArtistProfileScreenState();
}

class _ArtistProfileScreenState extends State<ArtistProfileScreen> {
  late bool _isFavorited;

  @override
  void initState() {
    super.initState();
    _isFavorited = widget.artist.isFavorited;
  }

  void _toggleFavorite() {
    setState(() {
      _isFavorited = !_isFavorited;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121414),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1E2020).withAlpha(150),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Color(0xFFF9FAFA)),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCoverAndHeader(),
            _buildAboutSection(),
            _buildStatsSection(),
            _buildFlashGrid(),
            const SizedBox(height: 40), // Bottom padding
          ],
        ),
      ),
    );
  }

  Widget _buildCoverAndHeader() {
    final coverImage = widget.artist.images.isNotEmpty
        ? widget.artist.images[0]
        : 'https://images.unsplash.com/photo-1598371839696-5c5bb00bdc28?auto=format&fit=crop&w=600&q=80';

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Cover Image with Gradient
        SizedBox(
          height: 320,
          width: double.infinity,
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.network(
                  coverImage,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: const Color(0xFF1E2020),
                    );
                  },
                ),
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        const Color(0xFF121414).withAlpha(150),
                        const Color(0xFF121414),
                      ],
                      stops: const [0.4, 0.8, 1.0],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Content over cover
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spaceLg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Profile Avatar
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF4D4530), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(100),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.network(
                      widget.artist.avatarUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: const Color(0xFF262929),
                          child: const Icon(
                            Icons.person,
                            color: Color(0xFFEEC200),
                            size: 40,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.spaceMd),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              widget.artist.name,
                              style: GoogleFonts.plusJakartaSans(
                                color: const Color(0xFFEEC200),
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Row(
                            children: [
                              _buildCircleAction(
                                icon: Icons.share_outlined,
                                onTap: () {},
                              ),
                              const SizedBox(width: 8),
                              _buildCircleAction(
                                icon: _isFavorited ? Icons.favorite : Icons.favorite_border,
                                color: _isFavorited ? const Color(0xFFEF4444) : const Color(0xFFF9FAFA),
                                onTap: _toggleFavorite,
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (widget.artist.isBooksOpen)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4D4530),
                                border: Border.all(color: const Color(0xFF4D4530)),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Books open',
                                style: GoogleFonts.plusJakartaSans(
                                  color: const Color(0xFFEEC200),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, color: Color(0xFF919696), size: 14),
                          const SizedBox(width: 4),
                          Text(
                            widget.artist.location,
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFF919696),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Icon(Icons.storefront_outlined, color: Color(0xFF919696), size: 14),
                          const SizedBox(width: 4),
                          Text(
                            widget.artist.studioType,
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFF919696),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCircleAction({required IconData icon, Color color = const Color(0xFFF9FAFA), required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF1E2020).withAlpha(200),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  Widget _buildAboutSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.spaceLg, AppSpacing.spaceLg, AppSpacing.spaceLg, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'About',
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFF919696),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'A safe, inclusive space for all bodies. Silent appointments are always available upon request.',
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFFF9FAFA),
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spaceLg, vertical: AppSpacing.spaceLg),
      child: AdaptiveGlassContainer(
        borderRadius: 12.0,
        unselectedBorderColor: const Color(0xFF262929),
        unselectedBorderWidth: 1.0,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatItem(
                icon: Icons.star,
                value: widget.artist.rating.toStringAsFixed(1),
                label: 'RATING',
                valueColor: const Color(0xFFEEC200),
              ),
              Container(width: 1, height: 30, color: const Color(0xFF262929)),
              _buildStatItem(
                value: widget.artist.availablePieces.toString(),
                label: 'AVAIL PIECES',
              ),
              Container(width: 1, height: 30, color: const Color(0xFF262929)),
              _buildStatItem(
                value: '\$${widget.artist.minDeposit}',
                label: 'MIN DEPOSIT',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem({IconData? icon, required String value, required String label, Color valueColor = const Color(0xFFF9FAFA)}) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: valueColor, size: 16),
              const SizedBox(width: 4),
            ],
            Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                color: valueColor,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: const Color(0xFF919696),
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildFlashGrid() {
    final flashArtworks = widget.artist.flashArtworks.isNotEmpty
        ? widget.artist.flashArtworks
        : List.generate(
            widget.artist.images.length,
            (index) => FlashArtwork(
              id: 'flash_fallback_$index',
              title: 'Original Flash #${index + 1}',
              imageUrl: widget.artist.images[index],
              location: 'Arms / Legs',
              deposit: widget.artist.minDeposit,
              size: '5" x 7"',
            ),
          );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Row(
                children: [
                  Text(
                    'Available Flash',
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFFF9FAFA),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF262929),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFF383B3B),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      '${flashArtworks.length}',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFFEEC200),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                'Tap piece to claim',
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF919696),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Flash Grid
          GridView.builder(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 16,
              childAspectRatio: 0.60,
            ),
            itemCount: flashArtworks.length,
            itemBuilder: (context, index) {
              final item = flashArtworks[index];
              return GestureDetector(
                onTap: () => _showFlashDetailsSheet(context, item),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B1E1E),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFF2D3131),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(100),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Flash Artwork Image with Tag Overlay
                      Expanded(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(12),
                              ),
                              child: Image.network(
                                item.imageUrl,
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Container(
                                    color: const Color(0xFF262929),
                                    child: const Center(
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            Color(0xFF4D5252),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: const Color(0xFF262929),
                                    child: const Center(
                                      child: Icon(
                                        Icons.draw_outlined,
                                        color: Color(0xFF4D5252),
                                        size: 28,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            // Top Status Badge
                            Positioned(
                              top: 8,
                              left: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: item.isClaimed
                                      ? const Color(0xFF261919).withAlpha(220)
                                      : const Color(0xFF1A2218).withAlpha(220),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: item.isClaimed
                                        ? const Color(0xFF7A3535)
                                        : const Color(0xFF436938),
                                    width: 0.8,
                                  ),
                                ),
                                child: Text(
                                  item.status.label.toUpperCase(),
                                  style: GoogleFonts.plusJakartaSans(
                                    color: item.isClaimed
                                        ? const Color(0xFFF87171)
                                        : const Color(0xFF4ADE80),
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ),
                            ),
                            // Top Deposit Badge
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF121414).withAlpha(210),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: const Color(0xFFEEC200).withAlpha(120),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  '\$${item.deposit} DEP',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: const Color(0xFFEEC200),
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Details Section
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                color: const Color(0xFFF9FAFA),
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            _buildFlashMetaRow(
                              icon: Icons.place_outlined,
                              label: item.location,
                            ),
                            const SizedBox(height: 3),
                            _buildFlashMetaRow(
                              icon: Icons.straighten_outlined,
                              label: item.size,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFlashMetaRow({
    required IconData icon,
    required String label,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 11,
          color: const Color(0xFF919696),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFF919696),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  void _showFlashDetailsSheet(BuildContext context, FlashArtwork item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (modalContext) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF171A1A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(color: Color(0xFF38352A), width: 1.5),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Sheet Grab Handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4D5252),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Image Preview
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: 1.2,
                  child: Image.network(
                    item.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: const Color(0xFF262929),
                        child: const Center(
                          child: Icon(
                            Icons.draw_outlined,
                            color: Color(0xFF4D5252),
                            size: 48,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title and Price
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      item.title,
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFFF9FAFA),
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (item.fullPrice != null)
                    Text(
                      '\$${item.fullPrice}',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFFEEC200),
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Specs Grid
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF202323),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF2D3131)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildSpecCol('PLACEMENT', item.location),
                    Container(width: 1, height: 24, color: const Color(0xFF333737)),
                    _buildSpecCol('SIZE', item.size),
                    Container(width: 1, height: 24, color: const Color(0xFF333737)),
                    _buildSpecCol('DEPOSIT', '\$${item.deposit}'),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Claim Button
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(modalContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Claimed "${item.title}"! Proceeding to booking deposit...'),
                      backgroundColor: const Color(0xFF262929),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEEC200),
                  foregroundColor: const Color(0xFF121414),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'CLAIM & BOOK FLASH',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSpecCol(String title, String val) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            color: const Color(0xFF919696),
            fontSize: 9,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          val,
          style: GoogleFonts.plusJakartaSans(
            color: const Color(0xFFF9FAFA),
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
