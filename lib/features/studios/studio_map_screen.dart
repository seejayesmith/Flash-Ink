import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/utils/distance_calculator.dart';
import '../../models/artist.dart';
import '../../providers/app_providers.dart';
import '../../services/google_places_service.dart';
import '../../services/location_service.dart';
import '../../services/studio_map_service.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';
import '../../widgets/flash_image.dart';
import '../../widgets/flash_snack_bar.dart';
import 'studio_place_details_sheet.dart';

/// Default Google Maps & Places API key configured for Flash.Ink.
const String kDefaultGoogleMapsApiKey =
    'AIzaSyAMPnEDNfBY3i5RfEjcsMeJ6M6ScWt3OJ8';

enum StudioMapFilter {
  all('All Studios'),
  flashInkOnly('Flash.Ink Artists'),
  openNow('Open Now');

  final String label;
  const StudioMapFilter(this.label);
}

/// Interactive dark-mode Google Map screen combining live verified Flash.Ink
/// studios from Firestore with nearby tattoo shops discovered via Google Places.
class StudioMapScreen extends StatelessWidget {
  final String apiKey;
  final GooglePlacesService? placesService;
  final StudioMapService? mapService;
  final LatLng? initialCenter;
  final double initialZoom;
  final StudioMapMarkerData? initialSelectedStudio;
  final bool openDetailsOnLoad;
  final String? initialSearchQuery;
  final WidgetBuilder? mapOverrideBuilder;
  final bool autoCenterOnUserLocation;

  const StudioMapScreen({
    super.key,
    this.apiKey = kDefaultGoogleMapsApiKey,
    this.placesService,
    this.mapService,
    this.initialCenter,
    this.initialZoom = 13.0,
    this.initialSelectedStudio,
    this.openDetailsOnLoad = true,
    this.initialSearchQuery,
    this.mapOverrideBuilder,
    this.autoCenterOnUserLocation = false,
  });

  @override
  Widget build(BuildContext context) {
    final content = _StudioMapScreenContent(
      apiKey: apiKey,
      placesService: placesService,
      mapService: mapService,
      initialCenter: initialCenter,
      initialZoom: initialZoom,
      initialSelectedStudio: initialSelectedStudio,
      openDetailsOnLoad: openDetailsOnLoad,
      initialSearchQuery: initialSearchQuery,
      mapOverrideBuilder: mapOverrideBuilder,
      autoCenterOnUserLocation: autoCenterOnUserLocation,
    );

    final hasScope =
        context.findAncestorWidgetOfExactType<ProviderScope>() != null ||
            context.findAncestorWidgetOfExactType<UncontrolledProviderScope>() !=
                null;
    return hasScope ? content : ProviderScope(child: content);
  }
}

class _StudioMapScreenContent extends ConsumerStatefulWidget {
  final String apiKey;
  final GooglePlacesService? placesService;
  final StudioMapService? mapService;
  final LatLng? initialCenter;
  final double initialZoom;
  final StudioMapMarkerData? initialSelectedStudio;
  final bool openDetailsOnLoad;
  final String? initialSearchQuery;
  final WidgetBuilder? mapOverrideBuilder;
  final bool autoCenterOnUserLocation;

  const _StudioMapScreenContent({
    required this.apiKey,
    this.placesService,
    this.mapService,
    this.initialCenter,
    required this.initialZoom,
    this.initialSelectedStudio,
    required this.openDetailsOnLoad,
    this.initialSearchQuery,
    this.mapOverrideBuilder,
    this.autoCenterOnUserLocation = false,
  });

  @override
  ConsumerState<_StudioMapScreenContent> createState() =>
      _StudioMapScreenContentState();
}

class _StudioMapScreenContentState
    extends ConsumerState<_StudioMapScreenContent> {
  late final GooglePlacesService _placesService;
  late final bool _ownsPlacesService;
  late final StudioMapService _mapService;
  late final TextEditingController _searchController;

  GoogleMapController? _mapController;
  Timer? _debounceTimer;

  late LatLng _cameraTarget;
  LatLng? _lastSearchedCenter;
  bool _showSearchAreaButton = false;
  bool _myLocationPermitted = false;

  List<GooglePlaceStudioSummary> _nearbyPlaces = const [];
  List<GooglePlacePrediction> _predictions = const [];
  bool _isLoadingPlaces = false;
  bool _isAutocompleteLoading = false;
  String? _placesError;

  StudioMapFilter _activeFilter = StudioMapFilter.all;
  String? _selectedStudioId;

  bool get _isWidgetTest =>
      WidgetsBinding.instance.runtimeType.toString().contains('Test');

  @override
  void initState() {
    super.initState();
    _ownsPlacesService = widget.placesService == null;
    _placesService =
        widget.placesService ?? GooglePlacesService(apiKey: widget.apiKey);
    _mapService = widget.mapService ?? const StudioMapService();
    _searchController = TextEditingController(
      text: widget.initialSearchQuery ?? '',
    );

    final clientCoords = ref.read(effectiveClientCoordinatesProvider);
    final hasClientCoords = clientCoords != null && clientCoords.isValid;
    final effectiveInitialCenter = widget.initialCenter ??
        (widget.autoCenterOnUserLocation && hasClientCoords
            ? LatLng(clientCoords.latitude, clientCoords.longitude)
            : null);

    _cameraTarget = widget.initialSelectedStudio?.position ??
        effectiveInitialCenter ??
        StudioMapService.defaultMapCenter;
    _selectedStudioId = widget.initialSelectedStudio?.id;
    _myLocationPermitted = hasClientCoords;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeLocationAndPlaces();
    });
  }

  Future<void> _initializeLocationAndPlaces() async {
    if (!mounted) return;
    final clientCoords = ref.read(effectiveClientCoordinatesProvider);
    final artists = ref.read(artistsWithDistanceProvider).maybeWhen(
          data: (list) => list,
          orElse: () => const <Artist>[],
        );
    final flashStudios = _mapService.mapArtistsToStudios(
      artists,
      clientCoords: clientCoords,
    );

    final shouldAutoCenter = widget.autoCenterOnUserLocation ||
        (widget.initialCenter == null &&
            widget.initialSelectedStudio == null &&
            (widget.initialSearchQuery == null ||
                widget.initialSearchQuery!.trim().isEmpty));

    if (shouldAutoCenter) {
      await _centerOnUserLocation(silent: true);
    } else {
      if (widget.initialCenter == null && widget.initialSelectedStudio == null) {
        final resolved = await _mapService.resolveInitialCenter(
          clientCoords: clientCoords,
          initialStudios: flashStudios,
        );
        if (!mounted) return;
        setState(() {
          _cameraTarget = resolved;
        });
        _mapController?.animateCamera(CameraUpdate.newLatLng(resolved));
      }

      if (!_isWidgetTest) {
        final permitted = await LocationService.tryGetPermittedCoordinates();
        if (mounted && permitted != null && permitted.isValid) {
          setState(() {
            _myLocationPermitted = true;
          });
        }
      }
    }

    if (widget.initialSearchQuery != null &&
        widget.initialSearchQuery!.trim().isNotEmpty) {
      await _submitTextSearch(widget.initialSearchQuery!);
    } else if (_placesService.hasApiKey && _lastSearchedCenter == null) {
      await _fetchNearbyStudios(_cameraTarget);
    }

    if (mounted &&
        widget.initialSelectedStudio != null &&
        widget.openDetailsOnLoad) {
      _openDetailsSheet(widget.initialSelectedStudio!);
    }
  }

  Future<void> _fetchNearbyStudios(LatLng center) async {
    if (!_placesService.hasApiKey) return;

    setState(() {
      _isLoadingPlaces = true;
      _placesError = null;
      _showSearchAreaButton = false;
      _lastSearchedCenter = center;
    });

    try {
      final results = await _placesService.searchNearbyTattooStudios(
        latitude: center.latitude,
        longitude: center.longitude,
      );
      if (mounted) {
        setState(() {
          _nearbyPlaces = results;
          _isLoadingPlaces = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingPlaces = false;
          _placesError = 'Showing Flash.Ink studios (Google Places unavailable)';
        });
      }
    }
  }

  void _onSearchInputChanged(String raw) {
    _debounceTimer?.cancel();
    final query = raw.trim();
    setState(() {});

    if (query.isEmpty || !_placesService.hasApiKey) {
      setState(() {
        _predictions = const [];
        _isAutocompleteLoading = false;
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted) return;
      setState(() {
        _isAutocompleteLoading = true;
      });
      try {
        final predictions = await _placesService.searchStudios(query);
        if (mounted) {
          setState(() {
            _predictions = predictions;
            _isAutocompleteLoading = false;
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _predictions = const [];
            _isAutocompleteLoading = false;
          });
        }
      }
    });
  }

  Future<void> _submitTextSearch(String query) async {
    _debounceTimer?.cancel();
    FocusManager.instance.primaryFocus?.unfocus();
    final trimmed = query.trim();
    if (trimmed.isEmpty || !_placesService.hasApiKey) return;

    setState(() {
      _predictions = const [];
      _isLoadingPlaces = true;
      _placesError = null;
      _showSearchAreaButton = false;
    });

    try {
      final results = await _placesService.searchTattooStudiosByText(
        trimmed,
        latitude: _cameraTarget.latitude,
        longitude: _cameraTarget.longitude,
      );
      if (!mounted) return;
      setState(() {
        _nearbyPlaces = results;
        _isLoadingPlaces = false;
        if (results.isNotEmpty) {
          final firstTarget =
              LatLng(results.first.latitude, results.first.longitude);
          _cameraTarget = firstTarget;
          _lastSearchedCenter = firstTarget;
          _selectedStudioId = 'gplace_${results.first.placeId}';
        }
      });

      if (results.isNotEmpty) {
        final studioPins = results
            .map(
              (p) => StudioMapMarkerData.fromGooglePlace(
                p,
                resolvedImageUrl:
                    _placesService.buildPhotoUrl(p.photoReference),
              ),
            )
            .toList(growable: false);
        final bounds = _mapService.computeBounds(studioPins);
        if (bounds != null) {
          _mapController?.animateCamera(
            CameraUpdate.newLatLngBounds(bounds, 64),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingPlaces = false;
          _placesError = 'Unable to search studios for "$trimmed".';
        });
      }
    }
  }

  Future<void> _handleSelectPrediction(GooglePlacePrediction prediction) async {
    _debounceTimer?.cancel();
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _predictions = const [];
      _searchController.text = prediction.primaryText;
      _isLoadingPlaces = true;
    });

    try {
      final studioInfo = await _placesService.getStudioDetails(
        prediction.placeId,
        fallbackName: prediction.primaryText,
      );
      if (!mounted) return;

      if (studioInfo.latitude != null && studioInfo.longitude != null) {
        final target = LatLng(studioInfo.latitude!, studioInfo.longitude!);
        setState(() {
          _cameraTarget = target;
        });
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(target, 14.5),
        );
        await _fetchNearbyStudios(target);

        if (!mounted) return;
        final isVerifiedTattooPlace = GooglePlacesService.isTattooPlace(
          name: studioInfo.name,
          types: prediction.types,
        );
        if (isVerifiedTattooPlace) {
          final matchingExisting = _nearbyPlaces
              .where((p) => p.placeId == prediction.placeId)
              .firstOrNull;
          final selectedMarker = matchingExisting != null
              ? StudioMapMarkerData.fromGooglePlace(
                  matchingExisting,
                  resolvedImageUrl: _placesService
                      .buildPhotoUrl(matchingExisting.photoReference),
                )
              : StudioMapMarkerData(
                  id: 'gplace_${prediction.placeId}',
                  name: studioInfo.name,
                  address: studioInfo.formattedAddress,
                  cityState: studioInfo.displayLocation,
                  position: target,
                  placeId: prediction.placeId,
                  isPrivateStudio: false,
                  isVerifiedFlashInkStudio: false,
                  studioType: 'Street Shop',
                );
          if (matchingExisting == null) {
            setState(() {
              _nearbyPlaces = [
                GooglePlaceStudioSummary(
                  placeId: prediction.placeId,
                  name: studioInfo.name,
                  address: studioInfo.formattedAddress,
                  latitude: target.latitude,
                  longitude: target.longitude,
                  primaryType: GooglePlacesService.kBodyArtServiceType,
                  types: prediction.types.isNotEmpty
                      ? prediction.types
                      : const [GooglePlacesService.kBodyArtServiceType],
                ),
                ..._nearbyPlaces,
              ];
            });
          }
          setState(() {
            _selectedStudioId = selectedMarker.id;
          });
          _openDetailsSheet(selectedMarker);
        }
      } else {
        setState(() => _isLoadingPlaces = false);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingPlaces = false;
        });
      }
    }
  }

  Future<void> _centerOnUserLocation({bool silent = false}) async {
    UserLocationResult? location;
    try {
      location = await LocationService.getCurrentLocation();
    } catch (_) {}

    GeoPointCoords? coords;
    if (location != null) {
      coords = GeoPointCoords(
        latitude: location.latitude,
        longitude: location.longitude,
        resolvedLabel: location.cityStateLabel,
      );
    } else {
      // Fallback: check permitted coordinates or effective client coordinates
      final permitted = await LocationService.tryGetPermittedCoordinates();
      if (permitted != null && permitted.isValid) {
        coords = permitted;
      } else {
        final clientCoords = ref.read(effectiveClientCoordinatesProvider);
        if (clientCoords != null && clientCoords.isValid) {
          coords = clientCoords;
        }
      }
    }

    if (!mounted) return;

    if (coords == null || !coords.isValid) {
      if (!silent) {
        FlashSnackBar.showInfo(
          context,
          'Enable location access to center on your position.',
        );
      }
      return;
    }

    ref.read(liveGpsCoordinatesProvider.notifier).setCoordinates(coords);

    final target = LatLng(coords.latitude, coords.longitude);
    setState(() {
      _myLocationPermitted = true;
      _cameraTarget = target;
    });
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(target, 13.5));
    await _fetchNearbyStudios(target);
  }

  void _onCameraMove(CameraPosition position) {
    _cameraTarget = position.target;
  }

  void _onCameraIdle() {
    final anchor = _lastSearchedCenter;
    if (anchor == null || !_placesService.hasApiKey) return;
    final movedMiles = DistanceCalculator.calculateMiles(
      startLatitude: anchor.latitude,
      startLongitude: anchor.longitude,
      endLatitude: _cameraTarget.latitude,
      endLongitude: _cameraTarget.longitude,
    );
    if (movedMiles >= 0.75 && !_showSearchAreaButton && mounted) {
      setState(() {
        _showSearchAreaButton = true;
      });
    }
  }

  void _selectStudio(StudioMapMarkerData studio, {bool openSheet = true}) {
    setState(() {
      _selectedStudioId = studio.id;
      _cameraTarget = studio.position;
    });
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(studio.position, 14.5),
    );
    if (openSheet) {
      _openDetailsSheet(studio);
    }
  }

  Future<void> _openDetailsSheet(StudioMapMarkerData studio) async {
    await StudioPlaceDetailsSheet.show(
      context,
      studio: studio,
      placesService: _placesService,
    );
    if (mounted) {
      setState(() {
        _selectedStudioId = null;
      });
    }
  }

  List<StudioMapMarkerData> _applyFilter(List<StudioMapMarkerData> studios) {
    switch (_activeFilter) {
      case StudioMapFilter.all:
        return studios;
      case StudioMapFilter.flashInkOnly:
        return studios
            .where((s) => s.isVerifiedFlashInkStudio)
            .toList(growable: false);
      case StudioMapFilter.openNow:
        return studios
            .where((s) =>
                s.openNow == true ||
                (s.isVerifiedFlashInkStudio &&
                    s.residentArtists.any((a) => a.isBooksOpen)))
            .toList(growable: false);
    }
  }

  Set<Marker> _buildMarkers(List<StudioMapMarkerData> studios) {
    return studios.map((studio) {
      final hue = studio.isVerifiedFlashInkStudio
          ? BitmapDescriptor.hueYellow
          : BitmapDescriptor.hueOrange;

      return Marker(
        markerId: MarkerId(studio.id),
        position: studio.position,
        icon: BitmapDescriptor.defaultMarkerWithHue(hue),
        infoWindow: InfoWindow(
          title: studio.name,
          snippet: studio.isPrivateStudio
              ? 'Private Studio • ${studio.cityState}'
              : studio.address,
          onTap: () => _openDetailsSheet(studio),
        ),
        onTap: () => _selectStudio(studio, openSheet: true),
      );
    }).toSet();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _mapController?.dispose();
    if (_ownsPlacesService) {
      _placesService.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clientCoords = ref.watch(effectiveClientCoordinatesProvider);
    final artistsAsync = ref.watch(artistsWithDistanceProvider);
    final artists = artistsAsync.maybeWhen(
      data: (list) => list,
      orElse: () => const <Artist>[],
    );

    final flashInkStudios = _mapService.mapArtistsToStudios(
      artists,
      clientCoords: clientCoords,
    );

    var mergedStudios = _mapService.mergeWithGooglePlaces(
      flashInkStudios: flashInkStudios,
      nearbyPlaces: _nearbyPlaces,
      placesService: _placesService,
      clientCoords: clientCoords,
    );

    if (widget.initialSelectedStudio != null &&
        !mergedStudios.any((s) => s.id == widget.initialSelectedStudio!.id)) {
      mergedStudios = [widget.initialSelectedStudio!, ...mergedStudios];
    }

    final visibleStudios = _applyFilter(mergedStudios);
    final markers = _buildMarkers(visibleStudios);
    final safeTop = MediaQuery.of(context).padding.top;
    final safeBottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      key: const Key('studio_map_screen'),
      backgroundColor: AppTheme.onyxBackground,
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Google Map Canvas
          if (widget.mapOverrideBuilder != null)
            widget.mapOverrideBuilder!(context)
          else
            GoogleMap(
              key: const Key('studio_google_map'),
              initialCameraPosition: CameraPosition(
                target: _cameraTarget,
                zoom: widget.initialZoom,
              ),
              style: _kOnyxMapStyle,
              markers: markers,
              myLocationEnabled: _myLocationPermitted,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              compassEnabled: false,
              onMapCreated: (controller) {
                _mapController = controller;
                if (_cameraTarget != StudioMapService.defaultMapCenter) {
                  controller.animateCamera(
                    CameraUpdate.newLatLngZoom(_cameraTarget, 13.5),
                  );
                }
              },
              onCameraMove: _onCameraMove,
              onCameraIdle: _onCameraIdle,
            ),

          // 2. Top Search Bar, Autocomplete Predictions & Filter Chips
          Positioned(
            top: safeTop + 10,
            left: AppSpacing.screenGutter,
            right: AppSpacing.screenGutter,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    if (Navigator.of(context).canPop()) ...[
                      Material(
                        color: AppTheme.onyxContainer.withAlpha(245),
                        shape: const CircleBorder(
                          side: BorderSide(color: AppTheme.darkBorder, width: 1.2),
                        ),
                        elevation: 4,
                        shadowColor: Colors.black.withAlpha(110),
                        child: InkWell(
                          key: const Key('studio_map_back_button'),
                          customBorder: const CircleBorder(),
                          onTap: () => Navigator.of(context).pop(),
                          child: const SizedBox(
                            width: 46,
                            height: 46,
                            child: Icon(
                              Icons.arrow_back_rounded,
                              color: AppTheme.textPrimary,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Container(
                        height: 46,
                        decoration: BoxDecoration(
                          color: AppTheme.onyxContainer.withAlpha(245),
                          borderRadius:
                              BorderRadius.circular(AppRadius.radiusFull),
                          border:
                              Border.all(color: AppTheme.darkBorder, width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(110),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: TextField(
                          key: const Key('studio_map_search_field'),
                          controller: _searchController,
                          textInputAction: TextInputAction.search,
                          textAlignVertical: TextAlignVertical.center,
                          onChanged: _onSearchInputChanged,
                          onSubmitted: _submitTextSearch,
                          style: GoogleFonts.plusJakartaSans(
                            color: AppTheme.textPrimary,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: 'Search tattoo shops or cities...',
                            hintStyle: GoogleFonts.plusJakartaSans(
                              color: AppTheme.navInactive,
                              fontSize: 13,
                            ),
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              color: AppTheme.gold,
                              size: 20,
                            ),
                            prefixIconConstraints: const BoxConstraints(
                              minWidth: 44,
                              minHeight: 46,
                            ),
                            suffixIcon: (_isAutocompleteLoading ||
                                    _isLoadingPlaces)
                                ? const Padding(
                                    padding: EdgeInsets.all(13),
                                    child: SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppTheme.gold,
                                      ),
                                    ),
                                  )
                                : (_searchController.text.isNotEmpty
                                    ? IconButton(
                                        key: const Key(
                                          'studio_map_clear_search_button',
                                        ),
                                        icon: const Icon(
                                          Icons.close_rounded,
                                          color: AppTheme.navInactive,
                                          size: 18,
                                        ),
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() {
                                            _predictions = const [];
                                          });
                                        },
                                      )
                                    : null),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Material(
                      color: AppTheme.onyxContainer.withAlpha(245),
                      shape: const CircleBorder(
                        side: BorderSide(
                          color: AppTheme.darkBorder,
                          width: 1.2,
                        ),
                      ),
                      elevation: 4,
                      shadowColor: Colors.black.withAlpha(110),
                      child: InkWell(
                        key: const Key('studio_map_my_location_button'),
                        customBorder: const CircleBorder(),
                        onTap: () => _centerOnUserLocation(silent: false),
                        child: const SizedBox(
                          width: 46,
                          height: 46,
                          child: Icon(
                            Icons.my_location_rounded,
                            color: AppTheme.gold,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // Filter Chips Row
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: StudioMapFilter.values.map((filter) {
                      final isSelected = _activeFilter == filter;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          key: Key('studio_map_filter_${filter.name}'),
                          onTap: () => setState(() => _activeFilter = filter),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.gold
                                  : AppTheme.onyxContainer.withAlpha(235),
                              borderRadius:
                                  BorderRadius.circular(AppRadius.radiusFull),
                              border: Border.all(
                                color: isSelected
                                    ? AppTheme.gold
                                    : AppTheme.darkBorder,
                              ),
                            ),
                            child: Text(
                              filter.label,
                              style: GoogleFonts.plusJakartaSans(
                                color: isSelected
                                    ? AppTheme.onyxBackground
                                    : AppTheme.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                // Search This Area Floating Pill
                if (_showSearchAreaButton) ...[
                  const SizedBox(height: 10),
                  Center(
                    child: Material(
                      color: AppTheme.gold,
                      borderRadius: BorderRadius.circular(AppRadius.radiusFull),
                      elevation: 4,
                      child: InkWell(
                        key: const Key('search_this_area_button'),
                        borderRadius:
                            BorderRadius.circular(AppRadius.radiusFull),
                        onTap: () => _fetchNearbyStudios(_cameraTarget),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.refresh_rounded,
                                color: AppTheme.onyxBackground,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Search this area',
                                style: GoogleFonts.plusJakartaSans(
                                  color: AppTheme.onyxBackground,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],

                if (_placesError != null) ...[
                  const SizedBox(height: 8),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.onyxContainer.withAlpha(235),
                        borderRadius:
                            BorderRadius.circular(AppRadius.radiusFull),
                        border: Border.all(color: AppTheme.darkBorder),
                      ),
                      child: Text(
                        _placesError!,
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.navInactive,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                ],

                // Autocomplete Suggestions Dropdown
                if (_predictions.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    key: const Key('studio_map_predictions_list'),
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: Material(
                      color: AppTheme.onyxContainer.withAlpha(250),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.radiusMd),
                        side: const BorderSide(color: AppTheme.darkBorder),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        itemCount: _predictions.length,
                        separatorBuilder: (_, _) => const Divider(
                          color: AppTheme.darkBorder,
                          height: 1,
                        ),
                        itemBuilder: (context, index) {
                          final item = _predictions[index];
                          return ListTile(
                            key: Key('studio_map_prediction_$index'),
                            dense: true,
                            leading: const Icon(
                              Icons.place_outlined,
                              color: AppTheme.gold,
                              size: 19,
                            ),
                            title: Text(
                              item.primaryText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                color: AppTheme.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: item.secondaryText.isNotEmpty
                                ? Text(
                                    item.secondaryText,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.plusJakartaSans(
                                      color: AppTheme.navInactive,
                                      fontSize: 11,
                                    ),
                                  )
                                : null,
                            onTap: () => _handleSelectPrediction(item),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // 3. Bottom Horizontal Studio Preview Cards
          if (visibleStudios.isNotEmpty && _selectedStudioId == null)
            Positioned(
              left: 0,
              right: 0,
              bottom: safeBottom + 16,
              child: SizedBox(
                height: 114,
                child: ListView.separated(
                  key: const Key('studio_map_carousel'),
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenGutter,
                  ),
                  itemCount: visibleStudios.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final studio = visibleStudios[index];
                    final isSelected = studio.id == _selectedStudioId;
                    return _StudioMapPreviewCard(
                      studio: studio,
                      placesService: _placesService,
                      isSelected: isSelected,
                      onTap: () => _selectStudio(studio, openSheet: true),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StudioMapPreviewCard extends StatelessWidget {
  final StudioMapMarkerData studio;
  final GooglePlacesService placesService;
  final bool isSelected;
  final VoidCallback onTap;

  const _StudioMapPreviewCard({
    required this.studio,
    required this.placesService,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedThumb = (studio.imageUrl != null &&
            studio.imageUrl!.isNotEmpty)
        ? studio.imageUrl!
        : (placesService.buildPhotoUrl(studio.photoReference, maxWidth: 400) ??
            '');

    return GestureDetector(
      key: Key('studio_preview_card_${studio.id}'),
      onTap: onTap,
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTheme.onyxContainer.withAlpha(248),
          borderRadius: BorderRadius.circular(AppRadius.radiusLg),
          border: Border.all(
            color: isSelected ? AppTheme.gold : AppTheme.cardBorder,
            width: isSelected ? 1.6 : 1.1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(110),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.radiusMd),
              child: SizedBox(
                width: 86,
                height: double.infinity,
                child: FlashImage(
                  urlOrPath: resolvedThumb,
                  width: 86,
                  height: 92,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          studio.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            color: AppTheme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (studio.isVerifiedFlashInkStudio) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.verified,
                          color: AppTheme.gold,
                          size: 14,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    studio.isPrivateStudio
                        ? 'Private Studio • ${studio.cityState}'
                        : studio.address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.navInactive,
                      fontSize: 11.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (studio.rating != null) ...[
                        const Icon(
                          Icons.star_rounded,
                          color: AppTheme.gold,
                          size: 14,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          studio.rating!.toStringAsFixed(1),
                          style: GoogleFonts.plusJakartaSans(
                            color: AppTheme.textPrimary,
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (studio.formattedDistance != null)
                        Flexible(
                          child: Text(
                            studio.formattedDistance!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              color: AppTheme.gold,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      else if (studio.residentArtistsCount > 0)
                        Text(
                          '${studio.residentArtistsCount} Artist${studio.residentArtistsCount == 1 ? "" : "s"}',
                          style: GoogleFonts.plusJakartaSans(
                            color: AppTheme.gold,
                            fontSize: 11,
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
    );
  }
}

const String _kOnyxMapStyle = '''
[
  {"elementType": "geometry", "stylers": [{"color": "#141616"}]},
  {"elementType": "labels.icon", "stylers": [{"visibility": "off"}]},
  {"elementType": "labels.text.fill", "stylers": [{"color": "#8c9191"}]},
  {"elementType": "labels.text.stroke", "stylers": [{"color": "#121416"}]},
  {"featureType": "administrative.locality", "elementType": "labels.text.fill", "stylers": [{"color": "#f9fafa"}]},
  {"featureType": "poi", "elementType": "labels", "stylers": [{"visibility": "off"}]},
  {"featureType": "poi.business", "stylers": [{"visibility": "off"}]},
  {"featureType": "poi", "elementType": "geometry", "stylers": [{"color": "#181a1a"}]},
  {"featureType": "poi.park", "elementType": "geometry", "stylers": [{"color": "#161c1a"}]},
  {"featureType": "road", "elementType": "geometry", "stylers": [{"color": "#262929"}]},
  {"featureType": "road", "elementType": "geometry.stroke", "stylers": [{"color": "#121414"}]},
  {"featureType": "road.highway", "elementType": "geometry", "stylers": [{"color": "#38351f"}]},
  {"featureType": "road.highway", "elementType": "geometry.stroke", "stylers": [{"color": "#4d4530"}]},
  {"featureType": "transit", "elementType": "geometry", "stylers": [{"color": "#1e2020"}]},
  {"featureType": "transit", "elementType": "labels", "stylers": [{"visibility": "off"}]},
  {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#0b0d0d"}]},
  {"featureType": "water", "elementType": "labels.text.fill", "stylers": [{"color": "#4d5252"}]}
]
''';
