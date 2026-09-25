import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/widgets/flash_bottom_nav_bar.dart';
import '../models/artist.dart';
import '../services/auth_service.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import '../widgets/artist_card.dart';
import 'artist_profile_screen.dart';
import 'splash_screen.dart';
import 'client_account_screen.dart';

class BrowseArtistsScreen extends StatefulWidget {
  final AuthService? authService;
  final bool showBottomNav;

  const BrowseArtistsScreen({
    super.key,
    this.authService,
    this.showBottomNav = true,
  });

  @override
  State<BrowseArtistsScreen> createState() => _BrowseArtistsScreenState();
}

class _BrowseArtistsScreenState extends State<BrowseArtistsScreen> {
  late final AuthService _authService = widget.authService ?? AuthService();
  bool _isDeleting = false;
  late List<Artist> _artists;
  int _activeNavIndex = 0;

  // Filter selection state
  bool _filterBooksOpen = false;
  bool _filterQueerArtists = false;
  bool _filterNearby = false;
  final Set<String> _selectedStyles = <String>{};
  double _maxDeposit = 200.0;
  double _maxPrice = 800.0;

  bool get _hasActiveFilters =>
      _filterBooksOpen ||
      _filterQueerArtists ||
      _filterNearby ||
      _selectedStyles.isNotEmpty ||
      _maxDeposit < 200.0 ||
      _maxPrice < 800.0;

  int get _activeFilterCount {
    int count = 0;
    if (_filterBooksOpen) count++;
    if (_filterQueerArtists) count++;
    if (_filterNearby) count++;
    count += _selectedStyles.length;
    if (_maxDeposit < 200.0) count++;
    if (_maxPrice < 800.0) count++;
    return count;
  }

  List<Artist> get _filteredArtists {
    return _artists.where((artist) {
      if (_filterBooksOpen && !artist.isBooksOpen) {
        return false;
      }
      if (_filterQueerArtists) {
        final isQueer = artist.tags.any((t) =>
            t.toLowerCase().contains('queer') ||
            t.toLowerCase().contains('lgbt'));
        if (!isQueer) return false;
      }
      if (_filterNearby) {
        final loc = artist.location.toLowerCase();
        final isNearby = loc.contains('los angeles') ||
            loc.contains('silver lake') ||
            loc.contains('downtown') ||
            loc.contains('arts district') ||
            loc.contains('little tokyo');
        if (!isNearby) return false;
      }
      if (_selectedStyles.isNotEmpty) {
        final matchesStyle = artist.tags.any((tag) =>
            _selectedStyles.any((sel) => tag.toLowerCase().contains(sel.toLowerCase())));
        if (!matchesStyle) return false;
      }
      if (artist.minDeposit > _maxDeposit) {
        return false;
      }
      if (artist.flashArtworks.isNotEmpty) {
        final hasAffordablePiece = artist.flashArtworks.any((p) => p.price <= _maxPrice);
        if (!hasAffordablePiece) return false;
      }
      return true;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _artists = List.from(Artist.mockArtists);
  }

  void _toggleFavorite(Artist targetArtist) {
    setState(() {
      final index = _artists.indexWhere((a) => a.id == targetArtist.id);
      if (index != -1) {
        final artist = _artists[index];
        _artists[index] = artist.copyWith(isFavorited: !artist.isFavorited);
      }
    });

    final isFav = !targetArtist.isFavorited;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isFav
              ? 'Saved ${targetArtist.name} to favorites'
              : 'Removed ${targetArtist.name} from favorites',
        ),
        duration: const Duration(seconds: 1),
        backgroundColor: const Color(0xFF262929),
      ),
    );
  }

  void _handleViewProfile(Artist artist) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ArtistProfileScreen(artist: artist),
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
                      final bottomNavHeight = AppTheme.navBarHeight;
                      final bottomNavFloatingOffset = mediaQuery.padding.bottom + AppTheme.navBarBottomMargin;
                      final bottomNavTotalOcclusion = bottomNavFloatingOffset + bottomNavHeight;
                      final bottomBreathingGap = 14.0;
                      final bottomReserved = bottomNavTotalOcclusion + bottomBreathingGap;

                      final cardHeight = (constraints.maxHeight - bottomReserved - topOffset)
                          .clamp(460.0, 600.0);
                      final itemExtent = cardHeight + cardGap;

                      // Allow the last card to scroll up and snap to the exact same top position
                      final bottomPadding = (constraints.maxHeight - itemExtent - topOffset)
                          .clamp(0.0, double.infinity);

                      final displayArtists = _filteredArtists;

                      if (displayArtists.isEmpty) {
                        return _buildEmptyState(bottomReserved);
                      }

                      return ListView.builder(
                        physics: SnappingScrollPhysics(itemHeight: itemExtent),
                        padding: EdgeInsets.only(
                          left: AppSpacing.spaceMd,
                          right: AppSpacing.spaceMd,
                          top: topOffset,
                          bottom: bottomPadding,
                        ),
                        itemCount: displayArtists.length + 1,
                        itemBuilder: (context, index) {
                          if (index == displayArtists.length) {
                            return _buildDeleteAccountFooter(bottomReserved);
                          }
                          final artist = displayArtists[index];
                          return SizedBox(
                            height: itemExtent,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: cardGap),
                              child: ArtistCard(
                                artist: artist,
                                onViewProfile: () => _handleViewProfile(artist),
                                onToggleFavorite: () => _toggleFavorite(artist),
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

          // 2. Floating Translucent/Glassmorphic Bottom Navigation Bar (if standalone)
          if (widget.showBottomNav)
            Positioned(
              left: AppTheme.navBarHorizontalMargin,
              right: AppTheme.navBarHorizontalMargin,
              bottom: mediaQuery.padding.bottom + AppTheme.navBarBottomMargin,
              child: FlashBottomNavBar(
                currentIndex: _activeNavIndex,
                onTap: (index) => setState(() => _activeNavIndex = index),
                role: 'legacy_client',
              ),
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
          GestureDetector(
            key: const Key('client_avatar_button'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ClientAccountScreen(
                    authService: widget.authService ?? _authService,
                  ),
                ),
              );
            },
            child: Container(
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
          ),
        ],
      ),
    );
  }

  /// Sticky Horizontal Filter Row
  Widget _buildFilterRow() {
    final activeCount = _activeFilterCount;
    final filterLabel = activeCount > 0 ? 'Filters ($activeCount)' : 'Filters';

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
            label: filterLabel,
            isActive: _hasActiveFilters,
            onTap: _showFilterModal,
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

  /// Empty state rendered when active filters yield 0 artist matches
  Widget _buildEmptyState(double bottomReserved) {
    return Center(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.spaceLg,
          32,
          AppSpacing.spaceLg,
          bottomReserved,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFF1E2020),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF383B3B)),
              ),
              child: const Icon(
                Icons.search_off_rounded,
                color: Color(0xFFEEC200),
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No Artists Found',
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFFF9FAFA),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No artists match your active filter criteria.\nTry clearing or adjusting your filters.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF919696),
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF262929),
                foregroundColor: const Color(0xFFEEC200),
                side: const BorderSide(color: Color(0xFFEEC200)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                setState(() {
                  _filterBooksOpen = false;
                  _filterQueerArtists = false;
                  _filterNearby = false;
                  _selectedStyles.clear();
                  _maxDeposit = 200.0;
                  _maxPrice = 800.0;
                });
              },
              child: Text(
                'Reset Filters',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Solid matte dark sheet modal for advanced filtering
  void _showFilterModal() {
    bool tempBooksOpen = _filterBooksOpen;
    bool tempQueerArtists = _filterQueerArtists;
    bool tempNearby = _filterNearby;
    final Set<String> tempSelectedStyles = Set<String>.from(_selectedStyles);
    double tempMaxDeposit = _maxDeposit;
    double tempMaxPrice = _maxPrice;

    const availableStyles = [
      'Traditional',
      'Fine Line',
      'Blackwork',
      'Japanese',
      'Realism',
      'Neo-Traditional',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final mediaQuery = MediaQuery.of(context);
            return Container(
              constraints: BoxConstraints(
                maxHeight: mediaQuery.size.height * 0.85,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFF1E2020),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(
                  top: BorderSide(color: Color(0xFF383B3B), width: 1.0),
                ),
              ),
              padding: EdgeInsets.fromLTRB(
                AppSpacing.spaceLg,
                AppSpacing.spaceMd,
                AppSpacing.spaceLg,
                mediaQuery.padding.bottom + AppSpacing.spaceLg,
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
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
                          color: const Color(0xFF5A5E5E),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Title Header & Reset Button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Filters',
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFFF9FAFA),
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setModalState(() {
                              tempBooksOpen = false;
                              tempQueerArtists = false;
                              tempNearby = false;
                              tempSelectedStyles.clear();
                              tempMaxDeposit = 200.0;
                              tempMaxPrice = 800.0;
                            });
                          },
                          child: Text(
                            'Reset All',
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFFEEC200),
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Section 1: Tattoo Styles
                    Text(
                      'TATTOO STYLES',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF919696),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: availableStyles.map((style) {
                        final isSelected = tempSelectedStyles.contains(style);
                        return GestureDetector(
                          onTap: () {
                            setModalState(() {
                              if (isSelected) {
                                tempSelectedStyles.remove(style);
                              } else {
                                tempSelectedStyles.add(style);
                              }
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFFEEC200)
                                  : const Color(0xFF262929),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFFEEC200)
                                    : const Color(0xFF383B3B),
                                width: 1.0,
                              ),
                            ),
                            child: Text(
                              style,
                              style: GoogleFonts.plusJakartaSans(
                                color: isSelected
                                    ? const Color(0xFF121414)
                                    : const Color(0xFFF9FAFA),
                                fontSize: 13,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 22),

                    // Section 2: Availability & Identity
                    Text(
                      'AVAILABILITY & IDENTITY',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF919696),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildModalSwitchTile(
                      icon: Icons.menu_book_rounded,
                      title: 'Books Open Only',
                      subtitle: 'Artists currently accepting new bookings',
                      value: tempBooksOpen,
                      onChanged: (val) => setModalState(() => tempBooksOpen = val),
                    ),
                    const SizedBox(height: 8),
                    _buildModalSwitchTile(
                      emoji: '🌈',
                      title: 'Queer & LGBTQ+ Artists',
                      subtitle: 'Highlight LGBTQ+ community artists',
                      value: tempQueerArtists,
                      onChanged: (val) => setModalState(() => tempQueerArtists = val),
                    ),
                    const SizedBox(height: 8),
                    _buildModalSwitchTile(
                      icon: Icons.location_on_outlined,
                      title: 'Nearby (Local Artists)',
                      subtitle: 'Artists located in Los Angeles area',
                      value: tempNearby,
                      onChanged: (val) => setModalState(() => tempNearby = val),
                    ),
                    const SizedBox(height: 22),

                    // Section 3: Pricing & Deposits
                    Text(
                      'PRICING & DEPOSIT',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF919696),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Max Deposit',
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFFF9FAFA),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          tempMaxDeposit >= 200 ? 'Any' : '\$${tempMaxDeposit.round()}',
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFFEEC200),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: const Color(0xFFEEC200),
                        inactiveTrackColor: const Color(0xFF383B3B),
                        thumbColor: const Color(0xFFEEC200),
                        overlayColor: const Color(0xFFEEC200).withAlpha(40),
                        trackHeight: 3.0,
                      ),
                      child: Slider(
                        value: tempMaxDeposit,
                        min: 50.0,
                        max: 200.0,
                        divisions: 15,
                        onChanged: (val) => setModalState(() => tempMaxDeposit = val),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Max Piece Price',
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFFF9FAFA),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          tempMaxPrice >= 800 ? 'Any' : '\$${tempMaxPrice.round()}',
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFFEEC200),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: const Color(0xFFEEC200),
                        inactiveTrackColor: const Color(0xFF383B3B),
                        thumbColor: const Color(0xFFEEC200),
                        overlayColor: const Color(0xFFEEC200).withAlpha(40),
                        trackHeight: 3.0,
                      ),
                      child: Slider(
                        value: tempMaxPrice,
                        min: 100.0,
                        max: 800.0,
                        divisions: 14,
                        onChanged: (val) => setModalState(() => tempMaxPrice = val),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Apply Button
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEEC200),
                        foregroundColor: const Color(0xFF121414),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () {
                        setState(() {
                          _filterBooksOpen = tempBooksOpen;
                          _filterQueerArtists = tempQueerArtists;
                          _filterNearby = tempNearby;
                          _selectedStyles.clear();
                          _selectedStyles.addAll(tempSelectedStyles);
                          _maxDeposit = tempMaxDeposit;
                          _maxPrice = tempMaxPrice;
                        });
                        Navigator.pop(modalContext);
                      },
                      child: Text(
                        'Apply Filters',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
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

  static Widget _buildModalSwitchTile({
    IconData? icon,
    String? emoji,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF262929),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: value ? const Color(0xFFEEC200).withAlpha(120) : const Color(0xFF383B3B),
              width: 1.0,
            ),
          ),
          child: Row(
            children: [
              if (emoji != null) ...[
                Text(emoji, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 12),
              ] else if (icon != null) ...[
                Icon(
                  icon,
                  size: 20,
                  color: value ? const Color(0xFFEEC200) : const Color(0xFF919696),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFFF9FAFA),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF919696),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: value,
                activeColor: const Color(0xFFEEC200),
                activeTrackColor: const Color(0xFFEEC200).withAlpha(80),
                inactiveThumbColor: const Color(0xFF919696),
                inactiveTrackColor: const Color(0xFF1E2020),
                onChanged: onChanged,
              ),
            ],
          ),
        ),
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

  /// Delete Account Footer at the bottom of the artist feed
  Widget _buildDeleteAccountFooter(double bottomReserved) {
    return Padding(
      padding: EdgeInsets.only(
        top: AppSpacing.spaceLg,
        bottom: bottomReserved + 24.0,
        left: AppSpacing.spaceMd,
        right: AppSpacing.spaceMd,
      ),
      child: Center(
        child: OutlinedButton.icon(
          key: const Key('delete_account_button'),
          onPressed: _isDeleting ? null : _confirmDeleteAccount,
          icon: const Icon(
            Icons.delete_outline,
            color: Color(0xFFEF4444),
            size: 18,
          ),
          label: _isDeleting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEF4444)),
                  ),
                )
              : Text(
                  'Delete Account',
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFFEF4444),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    letterSpacing: 0.8,
                  ),
                ),
          style: OutlinedButton.styleFrom(
            backgroundColor: const Color(0xFF1E2020),
            side: BorderSide(
              color: const Color(0xFFEF4444).withAlpha(128),
              width: 1.5,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }

  /// Displays a centered confirmation dialog for account deletion
  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E2020),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Center(
            child: Text(
              'Delete Account',
              key: const Key('delete_account_modal_title'),
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFFF9FAFA),
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          content: Text(
            'Are you sure you want to delete your account? This action cannot be undone.',
            key: const Key('delete_account_modal_message'),
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFF919696),
              fontSize: 14,
              height: 1.4,
            ),
          ),
          actionsAlignment: MainAxisAlignment.spaceEvenly,
          actions: [
            TextButton(
              key: const Key('delete_account_cancel_button'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                'Cancel',
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF919696),
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            ElevatedButton(
              key: const Key('delete_account_confirm_button'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                'Delete Account',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      await _performDeleteAccount();
    }
  }

  /// Executes account deletion, displays simulated email SnackBar, and routes to SplashScreen
  Future<void> _performDeleteAccount() async {
    setState(() => _isDeleting = true);
    try {
      await _authService.deleteAccount();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Account deleted. A confirmation email has been sent.',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            backgroundColor: const Color(0xFF22C55E),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const SplashScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        final errorMessage = e is FirebaseAuthException
            ? _authService.handleFirebaseAuthException(e).toString().replaceFirst('Exception: ', '')
            : e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              errorMessage,
              style: GoogleFonts.plusJakartaSans(color: Colors.white),
            ),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
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
