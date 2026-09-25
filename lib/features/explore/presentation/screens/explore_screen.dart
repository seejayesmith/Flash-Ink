import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../models/artist.dart';
import '../../../../screens/artist_profile_screen.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/artist_card.dart';
import '../../domain/models/explore_studio.dart';
import '../widgets/explore_search_bar.dart';
import '../widgets/studio_card.dart';

/// ExploreScreen:
/// Search & discovery interface with sticky search bar, horizontal filter chips,
/// segmented toggle between "Artists" and "Studios", and directory results.
class ExploreScreen extends StatefulWidget {
  final List<Artist>? mockArtists;
  final List<ExploreStudio>? mockStudios;

  const ExploreScreen({
    super.key,
    this.mockArtists,
    this.mockStudios,
  });

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final _searchController = TextEditingController();
  int _viewMode = 0; // 0: Artists, 1: Studios
  String _selectedFilter = 'All';
  String _query = '';

  late List<Artist> _artists;
  late List<ExploreStudio> _studios;

  @override
  void initState() {
    super.initState();
    _artists = widget.mockArtists ?? List.from(Artist.mockArtists);
    _studios = widget.mockStudios ?? List.from(ExploreStudio.mockStudios);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Artist> get _filteredArtists {
    return _artists.where((artist) {
      final matchesQuery = _query.isEmpty ||
          artist.name.toLowerCase().contains(_query.toLowerCase()) ||
          artist.location.toLowerCase().contains(_query.toLowerCase()) ||
          artist.studioType.toLowerCase().contains(_query.toLowerCase()) ||
          artist.tags.any((t) => t.toLowerCase().contains(_query.toLowerCase()));

      if (!matchesQuery) return false;

      if (_selectedFilter == 'All') return true;
      if (_selectedFilter == 'Books Open') return artist.isBooksOpen;
      if (_selectedFilter == 'Nearby') return true;

      // Filter by tag/style
      return artist.tags.any(
        (t) => t.toLowerCase().contains(_selectedFilter.toLowerCase()),
      );
    }).toList();
  }

  List<ExploreStudio> get _filteredStudios {
    return _studios.where((studio) {
      final matchesQuery = _query.isEmpty ||
          studio.name.toLowerCase().contains(_query.toLowerCase()) ||
          studio.address.toLowerCase().contains(_query.toLowerCase()) ||
          studio.city.toLowerCase().contains(_query.toLowerCase()) ||
          studio.styles.any((s) => s.toLowerCase().contains(_query.toLowerCase()));

      if (!matchesQuery) return false;

      if (_selectedFilter == 'All') return true;
      if (_selectedFilter == 'Books Open' || _selectedFilter == 'Nearby') return true;

      return studio.styles.any(
        (s) => s.toLowerCase().contains(_selectedFilter.toLowerCase()),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final artists = _filteredArtists;
    final studios = _filteredStudios;

    return Scaffold(
      backgroundColor: AppTheme.onyxBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.onyxBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Explore Directory',
          style: GoogleFonts.plusJakartaSans(
            color: AppTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Sticky Search & Filter Bar
            ExploreSearchBar(
              controller: _searchController,
              onQueryChanged: (query) {
                setState(() {
                  _query = query;
                });
              },
              selectedFilter: _selectedFilter,
              onFilterSelected: (filter) {
                setState(() {
                  _selectedFilter = filter;
                });
              },
            ),
            const SizedBox(height: 12),

            // Segmented View Toggle (Artists vs Studios)
            _buildSegmentedToggle(artists.length, studios.length),
            const SizedBox(height: 12),

            // Directory Content List
            Expanded(
              child: _viewMode == 0
                  ? _buildArtistsList(artists, bottomInset)
                  : _buildStudiosList(studios, bottomInset),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentedToggle(int artistCount, int studioCount) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spaceLg),
      child: Container(
        height: 38,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: AppTheme.onyxContainer,
          borderRadius: BorderRadius.circular(19),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: Row(
          children: [
            Expanded(
              child: _buildToggleItem(0, 'Artists ($artistCount)'),
            ),
            Expanded(
              child: _buildToggleItem(1, 'Studios ($studioCount)'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleItem(int index, String label) {
    final isSelected = _viewMode == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _viewMode = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.gold : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              color: isSelected ? AppTheme.onyxBackground : AppTheme.navInactive,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildArtistsList(List<Artist> artists, double bottomInset) {
    if (artists.isEmpty) {
      return _buildEmptyState('No artists found matching your criteria.');
    }

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.spaceLg,
        4,
        AppSpacing.spaceLg,
        AppSpacing.spaceXxl + AppTheme.navBarHeight + bottomInset,
      ),
      itemCount: artists.length,
      itemBuilder: (context, index) {
        final artist = artists[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: SizedBox(
            height: 480,
            child: ArtistCard(
              artist: artist,
              onViewProfile: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ArtistProfileScreen(artist: artist),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildStudiosList(List<ExploreStudio> studios, double bottomInset) {
    if (studios.isEmpty) {
      return _buildEmptyState('No tattoo studios found matching your criteria.');
    }

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.spaceLg,
        4,
        AppSpacing.spaceLg,
        AppSpacing.spaceXxl + AppTheme.navBarHeight + bottomInset,
      ),
      itemCount: studios.length,
      itemBuilder: (context, index) {
        return StudioCard(studio: studios[index]);
      },
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spaceXl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, color: AppTheme.navInactive, size: 48),
            const SizedBox(height: 12),
            Text(
              'No Results',
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.navInactive,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
