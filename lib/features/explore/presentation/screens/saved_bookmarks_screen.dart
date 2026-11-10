import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/mock/mock_fixtures.dart';
import '../../../../models/artist.dart';
import '../../../../providers/app_providers.dart';
import '../../../../screens/artist_profile_screen.dart';
import '../../../../screens/flash_details_screen.dart';
import '../../../../services/auth_service.dart';
import '../../../../theme/app_radius.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/artist_card.dart';
import '../../../../widgets/client_empty_state.dart';
import '../../../../widgets/flash_card.dart';

/// Screen dedicated to displaying the user's bookmarked flash pieces and favorited artists.
class SavedBookmarksScreen extends StatelessWidget {
  final AuthService? authService;

  const SavedBookmarksScreen({
    super.key,
    this.authService,
  });

  @override
  Widget build(BuildContext context) {
    final content = _SavedBookmarksScreenContent(
      authService: authService,
    );
    final hasScope = context.findAncestorWidgetOfExactType<ProviderScope>() !=
            null ||
        context.findAncestorWidgetOfExactType<UncontrolledProviderScope>() !=
            null;
    return hasScope ? content : ProviderScope(child: content);
  }
}

class _SavedBookmarksScreenContent extends ConsumerStatefulWidget {
  final AuthService? authService;

  const _SavedBookmarksScreenContent({
    this.authService,
  });

  @override
  ConsumerState<_SavedBookmarksScreenContent> createState() =>
      _SavedBookmarksScreenContentState();
}

class _SavedBookmarksScreenContentState
    extends ConsumerState<_SavedBookmarksScreenContent> {
  int _selectedTabIndex = 0; // 0 = Artists, 1 = Flash

  // Local state allowing bookmarks to be toggled/removed during testing and user session
  late List<Artist> _savedArtists;
  late List<FlashArtwork> _savedFlashArtworks;
  bool _initialized = false;

  void _initializeBookmarks(List<Artist> liveArtists) {
    if (_initialized) return;

    // Favorited artists from live/mock providers
    final favorited = liveArtists.where((a) => a.isFavorited).toList();
    if (favorited.isNotEmpty) {
      _savedArtists = List<Artist>.from(favorited);
    } else {
      // Curated sample saved artists as default initial state
      _savedArtists = MockFixtures.artists
          .take(3)
          .map((a) => a.copyWith(isFavorited: true))
          .toList();
    }

    // Flash pieces from saved artists
    final flashList = <FlashArtwork>[];
    for (final artist in _savedArtists) {
      flashList.addAll(artist.flashArtworks);
    }
    if (flashList.isNotEmpty) {
      _savedFlashArtworks = flashList;
    } else {
      // Curated sample flash pieces
      _savedFlashArtworks = MockFixtures.artists.first.flashArtworks;
    }

    _initialized = true;
  }

  void _removeArtist(Artist artist) {
    setState(() {
      _savedArtists.removeWhere((a) => a.id == artist.id);
    });
  }

  void _removeFlash(FlashArtwork flash) {
    setState(() {
      _savedFlashArtworks.removeWhere((f) => f.id == flash.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final artistsAsync = ref.watch(artistsWithDistanceProvider);
    final allArtists = artistsAsync.maybeWhen(
      data: (list) => list,
      orElse: () => const <Artist>[],
    );

    _initializeBookmarks(allArtists);

    return Scaffold(
      backgroundColor: AppTheme.onyxBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.onyxBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          key: const Key('saved_bookmarks_back_button'),
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppTheme.textPrimary,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
        title: Text(
          'Saved & Bookmarks',
          style: GoogleFonts.plusJakartaSans(
            color: AppTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          // Segmented Tabs: "Artists" & "Flash"
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenGutter,
              vertical: AppSpacing.spaceSm,
            ),
            child: Container(
              height: 44,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppTheme.onyxContainer,
                borderRadius: BorderRadius.circular(AppRadius.radiusFull),
                border: Border.all(color: AppTheme.darkBorder),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _TabButton(
                      label: 'Artists (${_savedArtists.length})',
                      isSelected: _selectedTabIndex == 0,
                      key: const Key('bookmarks_tab_artists'),
                      onTap: () => setState(() => _selectedTabIndex = 0),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _TabButton(
                      label: 'Flash (${_savedFlashArtworks.length})',
                      isSelected: _selectedTabIndex == 1,
                      key: const Key('bookmarks_tab_flash'),
                      onTap: () => setState(() => _selectedTabIndex = 1),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Content view
          Expanded(
            child: _selectedTabIndex == 0
                ? _buildArtistsTab()
                : _buildFlashTab(),
          ),
        ],
      ),
    );
  }

  Widget _buildArtistsTab() {
    if (_savedArtists.isEmpty) {
      return _buildEmptyState(
        icon: Icons.person_search_rounded,
        title: 'No favorited artists yet',
        subtitle:
            'Explore local and trending artists and tap the heart icon to save them to your bookmarks.',
      );
    }

    return ListView.separated(
      key: const Key('saved_artists_list'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenGutter,
        vertical: AppSpacing.spaceMd,
      ),
      itemCount: _savedArtists.length,
      separatorBuilder: (_, _) => const SizedBox(height: 20),
      itemBuilder: (context, index) {
        final artist = _savedArtists[index];
        return SizedBox(
          height: 480,
          child: ArtistCard(
            artist: artist,
            onViewProfile: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ArtistProfileScreen(
                    artist: artist,
                  ),
                ),
              );
            },
            onToggleFavorite: () => _removeArtist(artist),
          ),
        );
      },
    );
  }

  Widget _buildFlashTab() {
    if (_savedFlashArtworks.isEmpty) {
      return _buildEmptyState(
        icon: Icons.bookmark_border_rounded,
        title: 'No saved flash pieces',
        subtitle:
            'Browse available designs in the feed and tap the bookmark or heart icon to save your favorites.',
      );
    }

    return ListView.separated(
      key: const Key('saved_flash_list'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenGutter,
        vertical: AppSpacing.spaceMd,
      ),
      itemCount: _savedFlashArtworks.length,
      separatorBuilder: (_, _) => const SizedBox(height: 20),
      itemBuilder: (context, index) {
        final flash = _savedFlashArtworks[index];
        return FlashCard(
          flash: flash,
          isFavorited: true,
          onSelect: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FlashDetailsScreen(
                  flash: flash,
                ),
              ),
            );
          },
          onToggleFavorite: () => _removeFlash(flash),
        );
      },
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return ClientEmptyState(
      icon: icon,
      title: title,
      subtitle: subtitle,
      hasFloatingNavBar: false,
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabButton({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.gold : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.radiusFull),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: isSelected ? Colors.black : AppTheme.navInactive,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
