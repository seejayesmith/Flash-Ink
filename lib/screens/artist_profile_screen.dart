import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/artist.dart';
import '../theme/app_spacing.dart';
import '../widgets/adaptive_glass_container.dart';
import '../widgets/flash_image.dart';
import 'custom_request_screen.dart';
import 'flash_details_screen.dart';

class ArtistProfileScreen extends StatefulWidget {
  final Artist artist;

  const ArtistProfileScreen({super.key, required this.artist});

  @override
  State<ArtistProfileScreen> createState() => _ArtistProfileScreenState();
}

class _ArtistProfileScreenState extends State<ArtistProfileScreen> {
  late bool _isFavorited;
  int _visibleFlashCount = 6;
  bool _isLoadingMore = false;

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

  void _handleLoadMore(int totalCount) async {
    if (_visibleFlashCount >= totalCount) return;

    setState(() {
      _isLoadingMore = true;
    });

    await Future.delayed(const Duration(milliseconds: 400));

    if (!mounted) return;

    setState(() {
      _isLoadingMore = false;
      _visibleFlashCount = (_visibleFlashCount + 6).clamp(0, totalCount);
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
        systemOverlayStyle: const SystemUiOverlayStyle(
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
              icon: const Icon(Icons.arrow_back, color: Color(0xFFF9FAFA), size: 20),
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
            _buildFunFactsSection(),
            _buildStatsSection(),
            _buildCustomRequestBanner(),
            _buildFlashGrid(),
            _buildStudioPoliciesSection(),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverAndHeader() {
    final coverImage = widget.artist.images.isNotEmpty
        ? widget.artist.images[0]
        : 'assets/images/flash_traditional_dagger.jpg';

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Cover Image with Gradient
        SizedBox(
          height: 280,
          width: double.infinity,
          child: Stack(
            children: [
              Positioned.fill(
                child: FlashImage(
                  urlOrPath: coverImage,
                  fit: BoxFit.cover,
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
                        const Color(0xFF121414).withAlpha(120),
                        const Color(0xFF121414).withAlpha(220),
                        const Color(0xFF121414),
                      ],
                      stops: const [0.2, 0.6, 0.85, 1.0],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Content over cover: Avatar, Name, Badges, Action Icons
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spaceLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Avatar and Action Icons
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Profile Avatar
                    Container(
                      width: 86,
                      height: 86,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF5A4D2E), width: 2.0),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(140),
                            blurRadius: 12,
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
                                size: 42,
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                    // Top-right circular action buttons (Share & Favorite)
                    Row(
                      children: [
                        _buildCircleAction(
                          icon: Icons.share_outlined,
                          onTap: () {
                            Clipboard.setData(ClipboardData(
                              text: 'https://flashink.app/artist/${widget.artist.id}',
                            ));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Artist profile link copied to clipboard!'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 10),
                        _buildCircleAction(
                          icon: _isFavorited ? Icons.favorite : Icons.favorite_border,
                          color: _isFavorited ? const Color(0xFFEF4444) : const Color(0xFFF9FAFA),
                          onTap: _toggleFavorite,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Name and Books Open Badge Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      widget.artist.name,
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFFEEC200),
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (widget.artist.isBooksOpen)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF38351F),
                          border: Border.all(color: const Color(0xFF7A6B29), width: 1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Books open',
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFFEEC200),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                // Location and Studio Type Row
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, color: Color(0xFF919696), size: 15),
                    const SizedBox(width: 4),
                    Text(
                      widget.artist.location,
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF919696),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Icon(Icons.storefront_outlined, color: Color(0xFF919696), size: 15),
                    const SizedBox(width: 4),
                    Text(
                      widget.artist.studioType,
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF919696),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCircleAction({
    required IconData icon,
    Color color = const Color(0xFFF9FAFA),
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: const Color(0xFF1E2020).withAlpha(190),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF333737), width: 0.8),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }

  Widget _buildAboutSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.spaceLg, 18, AppSpacing.spaceLg, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'About',
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFF919696),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.artist.bio,
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFFF9FAFA),
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFunFactsSection() {
    final facts = widget.artist.funFacts;
    if (facts.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.spaceLg, 18, AppSpacing.spaceLg, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: facts.map((fact) {
          return Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fact.label,
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF919696),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  fact.value,
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFFF9FAFA),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStatsSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.spaceLg, 20, AppSpacing.spaceLg, 0),
      child: AdaptiveGlassContainer(
        borderRadius: 14.0,
        unselectedBorderColor: const Color(0xFF262929),
        unselectedBorderWidth: 1.0,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatItem(
                icon: Icons.star,
                value: widget.artist.rating.toStringAsFixed(1),
                label: 'RATING',
                valueColor: const Color(0xFFEEC200),
              ),
              Container(width: 1, height: 28, color: const Color(0xFF2A2E2E)),
              _buildStatItem(
                value: widget.artist.availablePieces.toString(),
                label: 'AVAIL PIECES',
              ),
              Container(width: 1, height: 28, color: const Color(0xFF2A2E2E)),
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

  Widget _buildStatItem({
    IconData? icon,
    required String value,
    required String label,
    Color valueColor = const Color(0xFFF9FAFA),
  }) {
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

  Widget _buildCustomRequestBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.spaceLg, 16, AppSpacing.spaceLg, 0),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CustomRequestScreen(artist: widget.artist),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF181B1B),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFF423B22),
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
              // Ticket / Tag Icon Container
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF38331A),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.local_offer_outlined,
                  color: Color(0xFFEEC200),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),

              // Banner Titles
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Got an idea? Submit a Custom Request.',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFFF9FAFA),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    RichText(
                      text: TextSpan(
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF919696),
                          fontSize: 11,
                        ),
                        children: const [
                          TextSpan(text: 'Skip the DM wait '),
                          TextSpan(
                            text: '• ',
                            style: TextStyle(color: Color(0xFFEEC200), fontWeight: FontWeight.bold),
                          ),
                          TextSpan(text: '2-minute guided brief'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Circular Yellow Right-Arrow Button
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: Color(0xFFEEC200),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_forward,
                  color: Color(0xFF121414),
                  size: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFlashGrid() {
    final allPieces = widget.artist.flashArtworks.isNotEmpty
        ? widget.artist.flashArtworks
        : List.generate(
            widget.artist.images.length,
            (index) => FlashArtwork(
              id: 'flash_fallback_$index',
              title: 'Original Flash #${index + 1}',
              imageUrl: widget.artist.images[index],
              location: 'Arm / Thigh',
              deposit: widget.artist.minDeposit,
              size: '6" × 12"',
            ),
          );

    final visiblePieces = allPieces.take(_visibleFlashCount).toList();
    final hasMore = visiblePieces.length < allPieces.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.spaceLg, 20, AppSpacing.spaceLg, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GridView.builder(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 16,
              childAspectRatio: 0.58,
            ),
            itemCount: visiblePieces.length,
            itemBuilder: (context, index) {
              final item = visiblePieces[index];
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FlashDetailsScreen(
                        flash: item,
                        artist: widget.artist,
                      ),
                    ),
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF171A1A),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFF262929),
                      width: 1.2,
                    ),
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
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(13),
                          ),
                          child: FlashImage(
                            urlOrPath: item.imageUrl,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),

                      // Card Details
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
                            _buildCardMetaRow(
                              label: 'Placement:',
                              value: item.location,
                            ),
                            const SizedBox(height: 3),
                            _buildCardMetaRow(
                              label: 'Size:',
                              value: item.size,
                            ),
                            const SizedBox(height: 3),
                            _buildCardMetaRow(
                              label: 'Deposit:',
                              value: '\$${item.deposit}',
                              valueColor: const Color(0xFFEEC200),
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
          const SizedBox(height: 18),

          // Load More Button
          if (hasMore)
            OutlinedButton(
              onPressed: _isLoadingMore ? null : () => _handleLoadMore(allPieces.length),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF5A4D2E), width: 1.2),
                backgroundColor: const Color(0xFF171A1A),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoadingMore
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFEEC200),
                      ),
                    )
                  : Text(
                      'Load More',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFFEEC200),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
        ],
      ),
    );
  }

  Widget _buildCardMetaRow({
    required String label,
    required String value,
    Color valueColor = const Color(0xFFF9FAFA),
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: const Color(0xFF919696),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: GoogleFonts.plusJakartaSans(
              color: valueColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStudioPoliciesSection() {
    final policies = widget.artist.policies;

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.spaceLg, 28, AppSpacing.spaceLg, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF171A1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF262929),
            width: 1.2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: Shield Icon, Title, and Verified Studio Badge
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF38351F),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.shield_outlined,
                    color: Color(0xFFEEC200),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'STUDIO POLICIES & HOUSE RULES',
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFFF9FAFA),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                if (widget.artist.isVerifiedStudio)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF38351F),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFF635626), width: 0.8),
                    ),
                    child: Text(
                      'VERIFIED STUDIO',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFFEEC200),
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),

            // Policy Items List
            ...policies.map((policy) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF202323),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        _getPolicyIcon(policy.iconKey),
                        color: const Color(0xFFEEC200),
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            policy.title,
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFFF9FAFA),
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            policy.description,
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFF919696),
                              fontSize: 11,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  IconData _getPolicyIcon(String key) {
    switch (key.toLowerCase()) {
      case 'deposit':
        return Icons.credit_card_outlined;
      case 'health':
        return Icons.health_and_safety_outlined;
      case 'etiquette':
        return Icons.groups_outlined;
      case 'touchup':
        return Icons.auto_awesome_outlined;
      default:
        return Icons.info_outline;
    }
  }
}
