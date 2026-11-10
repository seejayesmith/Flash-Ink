import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../../core/utils/distance_calculator.dart';
import '../../../../models/artist.dart';
import '../../../../providers/app_providers.dart';
import '../../../../screens/location_settings_screen.dart';
import '../../../../services/auth_service.dart';
import '../../../../services/google_places_service.dart';
import '../../../../services/location_service.dart';
import '../../../../services/studio_map_service.dart';
import '../../../../widgets/flash_snack_bar.dart';
import '../../../../widgets/flash_tab_header.dart';
import '../../../../widgets/outward_reveal_route.dart';
import '../../../../theme/app_buttons.dart';
import '../../../../theme/app_radius.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/client_empty_state.dart';
import '../../domain/models/explore_studio.dart';
import '../../../studios/studio_map_screen.dart';
import '../../../studios/studio_profile_screen.dart';
import 'saved_bookmarks_screen.dart';
import '../widgets/discover_trending_artists.dart';
import '../widgets/featured_artist_spotlight.dart';
import '../widgets/trending_studios_section.dart';

/// ExploreScreen (Search & Discovery):
/// - Standalone search bar
/// - Defaults to displaying nearest tattoo shops
/// - Displays trending & featured artists when onboarded to the app
class ExploreScreen extends StatelessWidget {
  final AuthService? authService;
  final String apiKey;
  final GooglePlacesService? placesService;
  final StudioMapService? mapService;
  final List<ExploreStudio>? initialStudios;

  const ExploreScreen({
    super.key,
    this.authService,
    this.apiKey = kDefaultGoogleMapsApiKey,
    this.placesService,
    this.mapService,
    this.initialStudios,
  });

  @override
  Widget build(BuildContext context) {
    final content = _ExploreScreenContent(
      authService: authService,
      apiKey: apiKey,
      placesService: placesService,
      mapService: mapService,
      initialStudios: initialStudios,
    );
    final hasScope = context.findAncestorWidgetOfExactType<ProviderScope>() !=
            null ||
        context.findAncestorWidgetOfExactType<UncontrolledProviderScope>() !=
            null;
    return hasScope ? content : ProviderScope(child: content);
  }
}

class _ExploreScreenContent extends ConsumerStatefulWidget {
  final AuthService? authService;
  final String apiKey;
  final GooglePlacesService? placesService;
  final StudioMapService? mapService;
  final List<ExploreStudio>? initialStudios;

  const _ExploreScreenContent({
    required this.authService,
    required this.apiKey,
    this.placesService,
    this.mapService,
    this.initialStudios,
  });

  @override
  ConsumerState<_ExploreScreenContent> createState() =>
      _ExploreScreenContentState();
}

class _ExploreScreenContentState extends ConsumerState<_ExploreScreenContent> {
  late final GooglePlacesService _placesService;
  late final StudioMapService _mapService;
  final TextEditingController _searchController = TextEditingController();
  final GlobalKey _mapKey = GlobalKey();
  String _searchQuery = '';

  List<ExploreStudio> _nearbyStudios = const [];
  bool _isLoadingNearby = false;
  String? _nearbyError;
  LatLng? _lastLoadedCenter;

  @override
  void initState() {
    super.initState();
    _placesService = widget.placesService ??
        GooglePlacesService(apiKey: widget.apiKey);
    _mapService = widget.mapService ?? const StudioMapService();

    if (widget.initialStudios != null && widget.initialStudios!.isNotEmpty) {
      _nearbyStudios = widget.initialStudios!;
      _isLoadingNearby = false;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initializeAndFetchNearbyStudios();
      });
    }
  }

  Future<void> _initializeAndFetchNearbyStudios({bool forceRefresh = false}) async {
    if (!mounted) return;

    // 1. Resolve coordinates from GPS or user profile
    GeoPointCoords? clientCoords = ref.read(effectiveClientCoordinatesProvider);

    if (clientCoords == null || !clientCoords.isValid) {
      final userProfile = ref.read(currentUserProfileProvider).value;
      if (userProfile?.cityState != null &&
          userProfile!.cityState!.trim().isNotEmpty) {
        clientCoords = await DistanceCalculator.resolveCoordinates(
          freeformLocation: userProfile.cityState,
        );
        if (clientCoords != null && clientCoords.isValid && mounted) {
          ref
              .read(liveGpsCoordinatesProvider.notifier)
              .setCoordinates(clientCoords);
        }
      }
    }

    final isWidgetTest =
        WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if ((clientCoords == null || !clientCoords.isValid) && !isWidgetTest) {
      final permitted = await LocationService.tryGetPermittedCoordinates();
      if (permitted != null && permitted.isValid && mounted) {
        clientCoords = permitted;
        ref
            .read(liveGpsCoordinatesProvider.notifier)
            .setCoordinates(permitted);
      }
    }

    final targetCoords = (clientCoords != null && clientCoords.isValid)
        ? LatLng(clientCoords.latitude, clientCoords.longitude)
        : StudioMapService.defaultMapCenter;

    // Avoid redundant network fetch if already loaded around this coordinate
    if (!forceRefresh && _lastLoadedCenter != null) {
      final dist = DistanceCalculator.calculateMiles(
        startLatitude: _lastLoadedCenter!.latitude,
        startLongitude: _lastLoadedCenter!.longitude,
        endLatitude: targetCoords.latitude,
        endLongitude: targetCoords.longitude,
      );
      if (dist < 1.0 && _nearbyStudios.isNotEmpty) {
        return;
      }
    }

    if (!_placesService.hasApiKey) {
      return;
    }

    if (mounted) {
      setState(() {
        _isLoadingNearby = true;
        _nearbyError = null;
      });
    }

    try {
      final places = await _placesService.searchNearbyTattooStudios(
        latitude: targetCoords.latitude,
        longitude: targetCoords.longitude,
        radiusMeters: 15000,
      );

      if (!mounted) return;

      final artists = ref.read(artistsWithDistanceProvider).maybeWhen(
            data: (list) => list,
            orElse: () => const <Artist>[],
          );

      final flashStudios = _mapService.mapArtistsToStudios(
        artists,
        clientCoords: clientCoords,
      );

      final merged = _mapService.mergeWithGooglePlaces(
        flashInkStudios: flashStudios,
        nearbyPlaces: places,
        placesService: _placesService,
        clientCoords: clientCoords,
      );

      final studios = merged
          .map(
            (marker) => ExploreStudio.fromMarker(
              marker,
              placesService: _placesService,
            ),
          )
          .toList(growable: false);

      if (mounted) {
        setState(() {
          _nearbyStudios = studios;
          _isLoadingNearby = false;
          _lastLoadedCenter = targetCoords;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingNearby = false;
          _nearbyError = e.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openMapWithOutwardAnimation() {
    Offset? origin;
    try {
      final renderBox =
          _mapKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox != null) {
        final pos = renderBox.localToGlobal(Offset.zero);
        origin = Offset(
          pos.dx + renderBox.size.width / 2,
          pos.dy + renderBox.size.height / 2,
        );
      }
    } catch (_) {}

    final clientCoords = ref.read(effectiveClientCoordinatesProvider);
    final initialCenter = (clientCoords != null && clientCoords.isValid)
        ? LatLng(clientCoords.latitude, clientCoords.longitude)
        : null;

    Navigator.push(
      context,
      OutwardRevealPageRoute(
        page: StudioMapScreen(
          initialCenter: initialCenter,
          autoCenterOnUserLocation: true,
        ),
        origin: origin,
      ),
    );
  }

  List<Artist> _filterArtists(List<Artist> source) {
    if (_searchQuery.isEmpty) return source;
    final lowerQuery = _searchQuery.toLowerCase();
    return source.where((artist) {
      return artist.name.toLowerCase().contains(lowerQuery) ||
          artist.username.toLowerCase().contains(lowerQuery) ||
          artist.studioName.toLowerCase().contains(lowerQuery) ||
          artist.location.toLowerCase().contains(lowerQuery) ||
          artist.studioType.toLowerCase().contains(lowerQuery) ||
          artist.tags.any((t) => t.toLowerCase().contains(lowerQuery));
    }).toList();
  }

  List<ExploreStudio> _filterStudios(List<ExploreStudio> source) {
    if (_searchQuery.isEmpty) return source;
    final lowerQuery = _searchQuery.toLowerCase();
    return source.where((studio) {
      return studio.name.toLowerCase().contains(lowerQuery) ||
          studio.address.toLowerCase().contains(lowerQuery) ||
          studio.city.toLowerCase().contains(lowerQuery) ||
          studio.styles.any((s) => s.toLowerCase().contains(lowerQuery));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<GeoPointCoords?>(effectiveClientCoordinatesProvider, (prev, next) {
      if (next != null && next.isValid && (prev == null || prev != next)) {
        _initializeAndFetchNearbyStudios();
      }
    });

    final clientCoords = ref.watch(effectiveClientCoordinatesProvider);
    final userProfile = ref.watch(currentUserProfileProvider).maybeWhen(
          data: (u) => u,
          orElse: () => null,
        );
    final artistsAsync = ref.watch(artistsWithDistanceProvider);
    final studiosAsync = ref.watch(exploreStudiosProvider);

    final allArtists = artistsAsync.maybeWhen(
      data: (list) => list,
      orElse: () => const <Artist>[],
    );

    final List<ExploreStudio> providerStudios =
        studiosAsync.maybeWhen<List<ExploreStudio>>(
      data: (list) => list,
      orElse: () => const <ExploreStudio>[],
    );

    // Merge provider studios (e.g. onboarded Flash.Ink studios) with nearby discovered studios
    final List<ExploreStudio> combinedStudios;
    if (providerStudios.isNotEmpty && _nearbyStudios.isNotEmpty) {
      final seenIds = <String>{};
      final seenNames = <String>{};
      final list = <ExploreStudio>[];
      for (final s in providerStudios) {
        seenIds.add(s.id);
        seenNames.add(s.name.trim().toLowerCase());
        list.add(s);
      }
      for (final s in _nearbyStudios) {
        if (!seenIds.contains(s.id) &&
            !seenNames.contains(s.name.trim().toLowerCase())) {
          list.add(s);
        }
      }
      combinedStudios = list;
    } else if (providerStudios.isNotEmpty) {
      combinedStudios = providerStudios;
    } else {
      combinedStudios = _nearbyStudios;
    }

    final hasGps = clientCoords != null && clientCoords.isValid;
    final headerLocation = (userProfile?.cityState != null &&
            userProfile!.cityState!.trim().isNotEmpty)
        ? userProfile.cityState!.split(',').first.trim()
        : (hasGps ? 'Near You' : 'All Locations');

    final bottomInset = MediaQuery.of(context).padding.bottom;
    final filteredArtists = _filterArtists(allArtists);
    final trendingArtists = filteredArtists.take(5).toList();
    Artist? featuredArtist;
    if (filteredArtists.isNotEmpty) {
      featuredArtist = filteredArtists.reduce((curr, next) {
        if (next.rating > curr.rating) return next;
        if (next.rating == curr.rating &&
            next.availablePieces > curr.availablePieces) {
          return next;
        }
        return curr;
      });
    }
    final studios = _filterStudios(combinedStudios);
    final studioSectionTitle = trendingArtists.isNotEmpty
        ? 'TRENDING SHOPS & STUDIOS'
        : 'NEAREST TATTOO SHOPS';

    return Scaffold(
      backgroundColor: AppTheme.onyxBackground,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context, headerLocation),
            _buildSearchBar(),
            Expanded(
              child: CustomScrollView(
                slivers: [
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),

                  // Row 1: Trending artists in the local area (visible when artists are onboarded)
          if (trendingArtists.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: DiscoverTrendingArtists(artists: trendingArtists),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
          ],

          // Row 2: Featured artist spotlight (visible when artists are onboarded)
          if (featuredArtist != null) ...[
            SliverToBoxAdapter(
              child: FeaturedArtistSpotlight(artist: featuredArtist),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
          ],

          // Loading indicator while discovering nearby tattoo shops
          if (_isLoadingNearby && combinedStudios.isEmpty) ...[
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        color: AppTheme.gold,
                        strokeWidth: 2.5,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Finding nearest tattoo shops...',
                        style: TextStyle(
                          color: AppTheme.navInactive,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],

          // Row 3+ (or default view): Nearest tattoo shops
          if (studios.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: TrendingStudiosSection(
                title: studioSectionTitle,
                studios: studios,
                onStudioTap: (studio) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StudioProfileScreen.fromExploreStudio(
                        exploreStudio: studio,
                        allArtists: allArtists,
                        clientCoords: clientCoords,
                        apiKey: widget.apiKey,
                        placesService: _placesService,
                        authService: widget.authService,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
          ],

          if (!_isLoadingNearby && trendingArtists.isEmpty && studios.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: ClientEmptyState(
                icon: _searchQuery.trim().isEmpty
                    ? Icons.explore_off_outlined
                    : Icons.search_off_rounded,
                title: _searchQuery.trim().isEmpty
                    ? (_nearbyError != null ? 'Unable to Load Shops' : 'No Tattoo Shops Found')
                    : 'No Results Found',
                subtitle: _searchQuery.trim().isEmpty
                    ? (_nearbyError != null
                        ? 'Could not connect to Google Places near $headerLocation.'
                        : 'No tattoo shops found near $headerLocation.')
                    : 'No results found for "$_searchQuery"',
                action: AppButtons.secondaryCTA(
                  key: const Key('explore_search_map_button'),
                  backgroundColor: AppTheme.onyxContainer,
                  foregroundColor: AppTheme.gold,
                  borderColor: AppTheme.goldBorder,
                  icon: Icons.map_outlined,
                  text: 'Search shops on Map',
                  width: 220,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StudioMapScreen(
                          initialSearchQuery: _searchQuery.trim(),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

          // Safe area bottom inset clearance for floating nav bar
          if (trendingArtists.isNotEmpty || studios.isNotEmpty)
            SliverToBoxAdapter(
              child: SizedBox(
                height: AppSpacing.spaceXxl + AppTheme.navBarHeight + bottomInset,
              ),
            ),
        ],
      ),
    ),
  ],
),
),
);
}

  /// Sticky standardized 30pt header for Explore
  Widget _buildHeader(BuildContext context, String headerLocation) {
    return FlashTabHeader(
      title: 'Explore',
      titleAccessory: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const LocationSettingsScreen(),
            ),
          );
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppTheme.onyxContainer,
            borderRadius: BorderRadius.circular(AppRadius.radiusFull),
            border: Border.all(color: AppTheme.darkBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_on, color: AppTheme.gold, size: 12),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  headerLocation,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_none_rounded, color: AppTheme.textPrimary),
          onPressed: () {
            FlashSnackBar.showInfo(
              context,
              'No new notifications',
              duration: const Duration(seconds: 1),
            );
          },
        ),
        IconButton(
          key: const Key('explore_bookmark_button'),
          tooltip: 'Saved & Bookmarks',
          icon: const Icon(
            Icons.bookmark_outline_rounded,
            color: AppTheme.textPrimary,
            size: 24,
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SavedBookmarksScreen(
                  authService: widget.authService,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  /// Sticky standardized search bar for Explore (46px height with gold icon & map button)
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenGutter,
        vertical: AppSpacing.spaceXs,
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: AppTheme.cardBackground,
                borderRadius: BorderRadius.circular(AppRadius.radiusFull),
                border: Border.all(color: AppTheme.cardBorder, width: 1.2),
              ),
              child: TextField(
                controller: _searchController,
                textAlignVertical: TextAlignVertical.center,
                textInputAction: TextInputAction.search,
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
                onSubmitted: (val) {
                  final query = val.trim();
                  if (query.isNotEmpty) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StudioMapScreen(
                          initialSearchQuery: query,
                        ),
                      ),
                    );
                  }
                },
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Search artists, styles, studios...',
                  hintStyle: GoogleFonts.plusJakartaSans(
                    color: AppTheme.navInactive,
                    fontSize: 13,
                  ),
                  prefixIcon: const Icon(Icons.search, color: AppTheme.gold, size: 20),
                  prefixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 46),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close, color: AppTheme.navInactive, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  suffixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 46),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          GestureDetector(
            key: const Key('explore_map_tab_button'),
            onTap: _openMapWithOutwardAnimation,
            behavior: HitTestBehavior.opaque,
            child: Container(
              key: _mapKey,
              width: 44,
              height: 46,
              alignment: Alignment.center,
              child: const Icon(
                Icons.map_outlined,
                color: AppTheme.textPrimary,
                size: 28,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
