import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/artist.dart';
import '../theme/app_spacing.dart';
import '../widgets/adaptive_glass_container.dart';
import '../widgets/artist_card.dart';

class BrowseArtistsScreen extends StatefulWidget {
  const BrowseArtistsScreen({super.key});

  @override
  State<BrowseArtistsScreen> createState() => _BrowseArtistsScreenState();
}

class _BrowseArtistsScreenState extends State<BrowseArtistsScreen> {
  late List<Artist> _artists;
  int _activeNavIndex = 0;

  // Filter selection state
  bool _filterBooksOpen = true;
  bool _filterQueerArtists = true;
  bool _filterNearby = false;

  @override
  void initState() {
    super.initState();
    _artists = List.from(Artist.mockArtists);
  }

  void _toggleFavorite(int index) {
    setState(() {
      final artist = _artists[index];
      _artists[index] = artist.copyWith(isFavorited: !artist.isFavorited);
    });

    final isFav = _artists[index].isFavorited;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isFav
              ? 'Saved ${_artists[index].name} to favorites'
              : 'Removed ${_artists[index].name} from favorites',
        ),
        duration: const Duration(seconds: 1),
        backgroundColor: const Color(0xFF262929),
      ),
    );
  }

  void _handleViewProfile(Artist artist) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Viewing ${artist.name}\'s profile & flash collection'),
        backgroundColor: const Color(0xFFEEC200),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFF121414),
      body: Stack(
        children: [
          // 1. Edge-to-Edge Feed with Header and Snapping List
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header (Sticky)
                _buildHeader(),

                // Filter Chips Row (Sticky)
                _buildFilterRow(),

                AppGaps.gapSm,

                // Snapping Artist Feed
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      const topOffset = AppSpacing.spaceXs; // 8.0px
                      const cardGap = 18.0; // Consistent 18px gap between cards

                      // Calculate available space for the card so it fits between
                      // the top filters and the floating bottom navigation bar
                      final bottomNavHeight = 64.0;
                      final bottomNavFloatingOffset = mediaQuery.padding.bottom + 12.0;
                      final bottomNavTotalOcclusion = bottomNavFloatingOffset + bottomNavHeight;
                      final bottomBreathingGap = 14.0;
                      final bottomReserved = bottomNavTotalOcclusion + bottomBreathingGap;

                      final cardHeight = (constraints.maxHeight - bottomReserved - topOffset)
                          .clamp(460.0, 600.0);
                      final itemExtent = cardHeight + cardGap;

                      // Allow the last card to scroll up and snap to the exact same top position
                      final bottomPadding = (constraints.maxHeight - itemExtent - topOffset)
                          .clamp(0.0, double.infinity);

                      return ListView.builder(
                        physics: SnappingScrollPhysics(itemHeight: itemExtent),
                        padding: EdgeInsets.only(
                          left: AppSpacing.spaceMd,
                          right: AppSpacing.spaceMd,
                          top: topOffset,
                          bottom: bottomPadding,
                        ),
                        itemCount: _artists.length,
                        itemBuilder: (context, index) {
                          final artist = _artists[index];
                          return SizedBox(
                            height: itemExtent,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: cardGap),
                              child: ArtistCard(
                                artist: artist,
                                onViewProfile: () => _handleViewProfile(artist),
                                onToggleFavorite: () => _toggleFavorite(index),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // 2. Floating Translucent/Glassmorphic Bottom Navigation Bar
          Positioned(
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).padding.bottom + 12,
            child: _buildFloatingBottomNav(),
          ),
        ],
      ),
    );
  }

  /// Sticky Header: "Browse Artists" bold title + user avatar
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.spaceLg,
        vertical: AppSpacing.spaceSm,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Browse Artists',
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFFF9FAFA),
              fontSize: 30,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF4D4530),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(80),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipOval(
              child: Image.network(
                'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=200&q=80',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: const Color(0xFF262929),
                    child: const Icon(
                      Icons.person,
                      color: Color(0xFFEEC200),
                      size: 22,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Sticky Horizontal Filter Row
  Widget _buildFilterRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.spaceLg,
        vertical: AppSpacing.spaceXs,
      ),
      child: Row(
        children: [
          // Outline "Filters" Chip with Settings/Sliders Icon
          _buildOutlineChip(
            icon: Icons.tune,
            label: 'Filters',
            isActive: false,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Filter bottom sheet coming soon'),
                  duration: Duration(milliseconds: 900),
                ),
              );
            },
          ),
          AppGaps.gapSm,

          // Filled Yellow "Books Open" Chip
          _buildFilledChip(
            icon: Icons.menu_book_rounded,
            label: 'Books Open',
            isActive: _filterBooksOpen,
            onTap: () => setState(() => _filterBooksOpen = !_filterBooksOpen),
          ),
          AppGaps.gapSm,

          // Filled Yellow "Queer Artists" Chip with Rainbow Emoji/Icon
          _buildFilledChip(
            emoji: '🌈',
            label: 'Queer Artists',
            isActive: _filterQueerArtists,
            onTap: () => setState(() => _filterQueerArtists = !_filterQueerArtists),
          ),
          AppGaps.gapSm,

          // Outline "Nearby" Chip
          _buildOutlineChip(
            icon: Icons.location_on_outlined,
            label: 'Nearby',
            isActive: _filterNearby,
            onTap: () => setState(() => _filterNearby = !_filterNearby),
          ),
        ],
      ),
    );
  }

  /// Outline Filter Chip
  Widget _buildOutlineChip({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF262929) : const Color(0xFF1E2020),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? const Color(0xFFEEC200) : const Color(0xFF383B3B),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive ? const Color(0xFFEEC200) : const Color(0xFFF9FAFA),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                color: isActive ? const Color(0xFFEEC200) : const Color(0xFFF9FAFA),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Filled Yellow Filter Chip
  Widget _buildFilledChip({
    IconData? icon,
    String? emoji,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFEEC200) : const Color(0xFF1E2020),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? const Color(0xFFEEC200) : const Color(0xFF383B3B),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (emoji != null) ...[
              Text(emoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
            ] else if (icon != null) ...[
              Icon(
                icon,
                size: 16,
                color: isActive ? const Color(0xFF121414) : const Color(0xFFF9FAFA),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                color: isActive ? const Color(0xFF121414) : const Color(0xFFF9FAFA),
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Floating Glassmorphic Bottom Navigation Bar
  Widget _buildFloatingBottomNav() {
    return AdaptiveGlassContainer(
      borderRadius: 36.0,
      blurSigma: 20.0,
      baseTintAlpha: 175,
      selectedBorderColor: const Color(0xFF4D4530),
      unselectedBorderColor: const Color(0xFF4D4530),
      unselectedBorderWidth: 1.5,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(
            index: 0,
            icon: Icons.home_filled,
            label: 'HOME',
          ),
          _buildNavItem(
            index: 1,
            icon: Icons.search,
            label: 'EXPLORE',
          ),
          _buildNavItem(
            index: 2,
            icon: Icons.calendar_today_outlined,
            label: 'APPOINTMENTS',
          ),
          _buildNavItem(
            index: 3,
            icon: Icons.notifications_none_outlined,
            label: 'ALERTS',
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final isActive = _activeNavIndex == index;

    return GestureDetector(
      onTap: () => setState(() => _activeNavIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFEEC200).withAlpha(35) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: isActive ? const Color(0xFFEEC200) : const Color(0xFF919696),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.6,
                color: isActive ? const Color(0xFFEEC200) : const Color(0xFF919696),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom snapping scroll physics that ensures each artist card snaps cleanly
/// into the exact viewport position as the first card.
class SnappingScrollPhysics extends ScrollPhysics {
  final double itemHeight;

  const SnappingScrollPhysics({
    required this.itemHeight,
    super.parent,
  });

  @override
  SnappingScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return SnappingScrollPhysics(
      itemHeight: itemHeight,
      parent: buildParent(ancestor),
    );
  }

  double _getTargetPixels(ScrollMetrics position, Tolerance tolerance, double velocity) {
    double page = position.pixels / itemHeight;
    if (velocity < -tolerance.velocity) {
      page -= 0.5;
    } else if (velocity > tolerance.velocity) {
      page += 0.5;
    }
    return (page.roundToDouble() * itemHeight).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
  }

  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) {
    // If out of range, allow the parent/BouncingScrollPhysics to handle overscroll
    if ((velocity <= 0.0 && position.pixels <= position.minScrollExtent) ||
        (velocity >= 0.0 && position.pixels >= position.maxScrollExtent)) {
      return super.createBallisticSimulation(position, velocity);
    }
    final Tolerance tolerance = toleranceFor(position);
    final double target = _getTargetPixels(position, tolerance, velocity);
    if (target != position.pixels) {
      return ScrollSpringSimulation(
        spring,
        position.pixels,
        target,
        velocity,
        tolerance: tolerance,
      );
    }
    return null;
  }

  @override
  bool get allowImplicitScrolling => false;
}
