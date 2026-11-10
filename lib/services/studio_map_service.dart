import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../core/utils/distance_calculator.dart';
import '../features/explore/domain/models/explore_studio.dart';
import '../models/artist.dart';
import 'google_places_service.dart';
import 'location_service.dart';

/// Unified map pin representation for both verified Flash.Ink studios (backed by
/// onboarded Artists in Firestore) and nearby tattoo shops discovered via Google Places.
class StudioMapMarkerData {
  final String id;
  final String name;
  final String address;
  final String cityState;
  final LatLng position;
  final String? placeId;
  final bool isPrivateStudio;
  final bool isVerifiedFlashInkStudio;
  final String studioType;
  final double? rating;
  final int? reviewCount;
  final bool? openNow;
  final String? imageUrl;
  final String? photoReference;
  final List<String> styles;
  final List<Artist> residentArtists;
  final int fallbackArtistCount;
  final double? distanceMiles;

  const StudioMapMarkerData({
    required this.id,
    required this.name,
    required this.address,
    required this.cityState,
    required this.position,
    this.placeId,
    this.isPrivateStudio = false,
    this.isVerifiedFlashInkStudio = false,
    this.studioType = 'Street Shop',
    this.rating,
    this.reviewCount,
    this.openNow,
    this.imageUrl,
    this.photoReference,
    this.styles = const [],
    this.residentArtists = const [],
    this.fallbackArtistCount = 0,
    this.distanceMiles,
  });

  int get residentArtistsCount => residentArtists.isNotEmpty
      ? residentArtists.length
      : fallbackArtistCount;

  String? get formattedDistance => distanceMiles != null
      ? DistanceCalculator.formatMilesAway(distanceMiles!)
      : null;

  factory StudioMapMarkerData.fromExploreStudio(
    ExploreStudio studio, {
    List<Artist> residentArtists = const [],
    GeoPointCoords? clientCoords,
  }) {
    final isPrivate =
        studio.address.trim().toLowerCase().contains('private studio');
    final firstCoords = residentArtists
        .map(
          (a) =>
              a.studioInformation?.discoveryCoordinates ??
              a.discoveryCoordinates,
        )
        .whereType<GeoPointCoords>()
        .firstOrNull;
    final fallbackCoords =
        (studio.latitude != null && studio.longitude != null)
            ? GeoPointCoords(
                latitude: studio.latitude!,
                longitude: studio.longitude!,
              )
            : null;
    final candidateCoords = firstCoords ?? fallbackCoords;
    final safeCoords = candidateCoords != null
        ? (isPrivate ? candidateCoords.coarsened(decimals: 2) : candidateCoords)
        : null;
    final position = safeCoords != null
        ? LatLng(safeCoords.latitude, safeCoords.longitude)
        : StudioMapService.defaultMapCenter;

    double? miles = studio.distanceMiles;
    if (miles == null && clientCoords != null && clientCoords.isValid && safeCoords != null) {
      miles = DistanceCalculator.calculateMiles(
        startLatitude: clientCoords.latitude,
        startLongitude: clientCoords.longitude,
        endLatitude: safeCoords.latitude,
        endLongitude: safeCoords.longitude,
      );
    }

    final placeId = isPrivate
        ? null
        : (studio.placeId ??
            residentArtists
                .map((a) => a.studioInformation?.placeId)
                .whereType<String>()
                .where((id) => id.trim().isNotEmpty)
                .firstOrNull);

    return StudioMapMarkerData(
      id: studio.id,
      name: studio.name,
      address: isPrivate ? 'Private Studio' : studio.address,
      cityState: studio.city,
      position: position,
      placeId: placeId,
      isPrivateStudio: isPrivate,
      isVerifiedFlashInkStudio: studio.isVerified,
      studioType: isPrivate ? 'Private Studio' : 'Street Shop',
      rating: studio.rating,
      reviewCount: studio.reviewCount,
      imageUrl: studio.imageUrl,
      styles: studio.styles,
      residentArtists: residentArtists,
      fallbackArtistCount: studio.residentArtistsCount,
      distanceMiles: miles,
    );
  }

  factory StudioMapMarkerData.fromGooglePlace(
    GooglePlaceStudioSummary place, {
    GeoPointCoords? clientCoords,
    String? resolvedImageUrl,
  }) {
    double? miles;
    if (clientCoords != null && clientCoords.isValid) {
      miles = DistanceCalculator.calculateMiles(
        startLatitude: clientCoords.latitude,
        startLongitude: clientCoords.longitude,
        endLatitude: place.latitude,
        endLongitude: place.longitude,
      );
    }

    return StudioMapMarkerData(
      id: 'gplace_${place.placeId}',
      name: place.name,
      address: place.address,
      cityState: _extractCityState(place.address),
      position: LatLng(place.latitude, place.longitude),
      placeId: place.placeId,
      isPrivateStudio: false,
      isVerifiedFlashInkStudio: false,
      studioType: 'Street Shop',
      rating: place.rating,
      reviewCount: place.userRatingsTotal,
      openNow: place.openNow,
      imageUrl: resolvedImageUrl,
      photoReference: place.photoReference,
      styles: const [],
      residentArtists: const [],
      distanceMiles: miles,
    );
  }

  StudioMapMarkerData copyWith({
    String? id,
    String? name,
    String? address,
    String? cityState,
    LatLng? position,
    String? placeId,
    bool? isPrivateStudio,
    bool? isVerifiedFlashInkStudio,
    String? studioType,
    double? rating,
    int? reviewCount,
    bool? openNow,
    String? imageUrl,
    String? photoReference,
    List<String>? styles,
    List<Artist>? residentArtists,
    int? fallbackArtistCount,
    double? distanceMiles,
  }) {
    return StudioMapMarkerData(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      cityState: cityState ?? this.cityState,
      position: position ?? this.position,
      placeId: placeId ?? this.placeId,
      isPrivateStudio: isPrivateStudio ?? this.isPrivateStudio,
      isVerifiedFlashInkStudio:
          isVerifiedFlashInkStudio ?? this.isVerifiedFlashInkStudio,
      studioType: studioType ?? this.studioType,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      openNow: openNow ?? this.openNow,
      imageUrl: imageUrl ?? this.imageUrl,
      photoReference: photoReference ?? this.photoReference,
      styles: styles ?? this.styles,
      residentArtists: residentArtists ?? this.residentArtists,
      fallbackArtistCount: fallbackArtistCount ?? this.fallbackArtistCount,
      distanceMiles: distanceMiles ?? this.distanceMiles,
    );
  }

  static String _extractCityState(String address) {
    final parts = address
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (parts.length >= 3) {
      return '${parts[1]}, ${parts[2]}';
    }
    if (parts.length == 2) {
      return parts[1];
    }
    return address;
  }
}

/// Coordinates live Flash.Ink studio discovery from Firestore with Google Places
/// studio pins, distance calculations, privacy coarsening, and map camera bounds.
class StudioMapService {
  /// Default map fallback center (Portland, OR) when GPS/profile/studio coords are absent.
  static const LatLng defaultMapCenter = LatLng(45.5152, -122.6784);

  final FirebaseFirestore? _injectedFirestore;

  const StudioMapService({FirebaseFirestore? firestore})
      : _injectedFirestore = firestore;

  FirebaseFirestore? _resolveFirestore() {
    if (_injectedFirestore != null) return _injectedFirestore;
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  /// Watches onboarded Flash.Ink artists in `/artists` and projects them into
  /// privacy-safe [StudioMapMarkerData] pins with live Haversine distance.
  Stream<List<StudioMapMarkerData>> watchFlashInkStudios({
    GeoPointCoords? clientCoords,
  }) {
    final db = _resolveFirestore();
    if (db == null) {
      return Stream.value(const <StudioMapMarkerData>[]);
    }

    try {
      return db
          .collection('artists')
          .where('profileCompleted', isEqualTo: true)
          .snapshots()
          .map((snapshot) {
        final artists = snapshot.docs
            .map((doc) => Artist.fromMap(doc.data(), doc.id))
            .toList(growable: false);
        return mapArtistsToStudios(artists, clientCoords: clientCoords);
      });
    } catch (_) {
      return Stream.value(const <StudioMapMarkerData>[]);
    }
  }

  /// Converts a list of onboarded [Artist] profiles into grouped, privacy-safe
  /// [StudioMapMarkerData] map markers.
  ///
  /// Privacy guarantee:
  /// - Private studios (`isPrivateStudio == true`) keep coarsened coordinates (~1.1 km),
  ///   strip exact street addresses, omit `placeId`, and do not merge across unrelated artists.
  List<StudioMapMarkerData> mapArtistsToStudios(
    List<Artist> artists, {
    GeoPointCoords? clientCoords,
  }) {
    final grouped = <String, List<Artist>>{};

    for (final artist in artists) {
      final studioInfo = artist.studioInformation;
      final isPrivate =
          artist.isPrivateStudio || (studioInfo?.isPrivateStudio ?? false);

      final rawCoords =
          studioInfo?.discoveryCoordinates ?? artist.discoveryCoordinates;
      if (rawCoords == null || !rawCoords.isValid) continue;

      final safePlaceId =
          (!isPrivate && studioInfo?.placeId?.trim().isNotEmpty == true)
              ? studioInfo!.placeId!.trim()
              : null;

      final studioTitle = _resolveStudioTitle(artist);
      final groupKey = isPrivate
          ? 'private_${artist.id}'
          : (safePlaceId != null
              ? 'place_$safePlaceId'
              : 'name_${_normalizeName(studioTitle)}_${_normalizeName(artist.location)}');

      grouped.putIfAbsent(groupKey, () => <Artist>[]).add(artist);
    }

    final studios = <StudioMapMarkerData>[];

    grouped.forEach((groupKey, members) {
      final lead = members.first;
      final studioInfo = lead.studioInformation;
      final isPrivate =
          lead.isPrivateStudio || (studioInfo?.isPrivateStudio ?? false);
      final baseCoords =
          studioInfo?.discoveryCoordinates ?? lead.discoveryCoordinates;
      if (baseCoords == null || !baseCoords.isValid) return;

      final effectiveCoords =
          isPrivate ? baseCoords.coarsened(decimals: 2) : baseCoords;

      final studioTitle = _resolveStudioTitle(lead);
      final cityLabel = studioInfo?.displayLocation.isNotEmpty == true
          ? studioInfo!.displayLocation
          : lead.location;
      final safeAddress = isPrivate
          ? 'Private Studio'
          : (studioInfo?.formattedAddress.isNotEmpty == true
              ? studioInfo!.formattedAddress
              : cityLabel);
      final safePlaceId =
          (!isPrivate && studioInfo?.placeId?.trim().isNotEmpty == true)
              ? studioInfo!.placeId!.trim()
              : null;

      final mergedStyles = <String>{
        for (final m in members) ...m.tags.where((t) => t.trim().isNotEmpty),
      }.take(6).toList(growable: false);

      final avgRating = members.isEmpty
          ? lead.rating
          : members.fold<double>(0.0, (acc, m) => acc + m.rating) /
              members.length;

      final coverImage = lead.flashArtworks.isNotEmpty
          ? lead.flashArtworks.first.imageUrl
          : (lead.images.isNotEmpty ? lead.images.first : lead.avatarUrl);

      double? distanceMiles;
      if (clientCoords != null && clientCoords.isValid) {
        distanceMiles = DistanceCalculator.calculateMiles(
          startLatitude: clientCoords.latitude,
          startLongitude: clientCoords.longitude,
          endLatitude: effectiveCoords.latitude,
          endLongitude: effectiveCoords.longitude,
        );
      } else {
        distanceMiles = lead.distanceMiles;
      }

      final enrichedMembers = (clientCoords != null && clientCoords.isValid)
          ? members
              .map((m) => m.withLiveDistanceFrom(clientCoords))
              .toList(growable: false)
          : List<Artist>.unmodifiable(members);

      studios.add(
        StudioMapMarkerData(
          id: 'flash_${groupKey.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')}',
          name: studioTitle,
          address: safeAddress,
          cityState: cityLabel,
          position: LatLng(
            effectiveCoords.latitude,
            effectiveCoords.longitude,
          ),
          placeId: safePlaceId,
          isPrivateStudio: isPrivate,
          isVerifiedFlashInkStudio: true,
          studioType: isPrivate ? 'Private Studio' : lead.studioType,
          rating: double.parse(avgRating.toStringAsFixed(1)),
          reviewCount:
              members.fold<int>(0, (total, m) => total + m.availablePieces),
          imageUrl: coverImage.isNotEmpty ? coverImage : null,
          styles: mergedStyles,
          residentArtists: enrichedMembers,
          distanceMiles: distanceMiles,
        ),
      );
    });

    studios.sort(_compareStudios);
    return studios;
  }

  /// Merges verified Flash.Ink studios with nearby Google Places tattoo studios,
  /// deduplicating overlapping public shops by `placeId` or close proximity + name.
  List<StudioMapMarkerData> mergeWithGooglePlaces({
    required List<StudioMapMarkerData> flashInkStudios,
    required List<GooglePlaceStudioSummary> nearbyPlaces,
    GooglePlacesService? placesService,
    GeoPointCoords? clientCoords,
  }) {
    final merged = List<StudioMapMarkerData>.of(flashInkStudios);
    final consumedPlaceIds = <String>{
      for (final s in flashInkStudios)
        if (!s.isPrivateStudio && s.placeId != null && s.placeId!.isNotEmpty)
          s.placeId!,
    };

    for (final place in nearbyPlaces) {
      if (place.placeId.isEmpty) continue;
      if (!GooglePlacesService.isTattooStudioSummary(place)) continue;

      final existingIdx = merged.indexWhere((studio) {
        if (studio.isPrivateStudio) return false;
        if (studio.placeId != null && studio.placeId == place.placeId) {
          return true;
        }
        final sameName =
            _normalizeName(studio.name) == _normalizeName(place.name);
        if (!sameName) return false;
        final milesApart = DistanceCalculator.calculateMiles(
          startLatitude: studio.position.latitude,
          startLongitude: studio.position.longitude,
          endLatitude: place.latitude,
          endLongitude: place.longitude,
        );
        return milesApart <= 0.15;
      });

      final resolvedPhotoUrl =
          placesService?.buildPhotoUrl(place.photoReference, maxWidth: 800);

      if (existingIdx != -1) {
        final existing = merged[existingIdx];
        merged[existingIdx] = existing.copyWith(
          placeId: existing.placeId ?? place.placeId,
          openNow: existing.openNow ?? place.openNow,
          photoReference: existing.photoReference ?? place.photoReference,
          imageUrl: (existing.imageUrl != null && existing.imageUrl!.isNotEmpty)
              ? existing.imageUrl
              : resolvedPhotoUrl,
          rating: place.rating ?? existing.rating,
          reviewCount: place.userRatingsTotal ?? existing.reviewCount,
        );
        consumedPlaceIds.add(place.placeId);
      } else if (!consumedPlaceIds.contains(place.placeId)) {
        consumedPlaceIds.add(place.placeId);
        merged.add(
          StudioMapMarkerData.fromGooglePlace(
            place,
            clientCoords: clientCoords,
            resolvedImageUrl: resolvedPhotoUrl,
          ),
        );
      }
    }

    merged.sort(_compareStudios);
    return merged;
  }

  /// Resolves the best initial camera target for `StudioMapScreen`.
  Future<LatLng> resolveInitialCenter({
    GeoPointCoords? clientCoords,
    List<StudioMapMarkerData> initialStudios = const [],
  }) async {
    if (clientCoords != null && clientCoords.isValid) {
      return LatLng(clientCoords.latitude, clientCoords.longitude);
    }

    final isWidgetTest =
        WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (!isWidgetTest) {
      final permitted = await LocationService.tryGetPermittedCoordinates();
      if (permitted != null && permitted.isValid) {
        return LatLng(permitted.latitude, permitted.longitude);
      }
    }

    return defaultMapCenter;
  }

  /// Computes a safe [LatLngBounds] framing all [studios], adding a minimum span
  /// delta when all markers share a single point.
  LatLngBounds? computeBounds(List<StudioMapMarkerData> studios) {
    if (studios.isEmpty) return null;

    double minLat = studios.first.position.latitude;
    double maxLat = studios.first.position.latitude;
    double minLng = studios.first.position.longitude;
    double maxLng = studios.first.position.longitude;

    for (final studio in studios.skip(1)) {
      minLat = math.min(minLat, studio.position.latitude);
      maxLat = math.max(maxLat, studio.position.latitude);
      minLng = math.min(minLng, studio.position.longitude);
      maxLng = math.max(maxLng, studio.position.longitude);
    }

    const minSpan = 0.012;
    if ((maxLat - minLat).abs() < minSpan) {
      minLat = (minLat - minSpan / 2).clamp(-89.9, 89.9);
      maxLat = (maxLat + minSpan / 2).clamp(-89.9, 89.9);
    }
    if ((maxLng - minLng).abs() < minSpan) {
      minLng = (minLng - minSpan / 2).clamp(-179.9, 179.9);
      maxLng = (maxLng + minSpan / 2).clamp(-179.9, 179.9);
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  static String _resolveStudioTitle(Artist artist) {
    if (artist.studioName.trim().isNotEmpty) {
      return artist.studioName.trim();
    }
    final infoName = artist.studioInformation?.name.trim() ?? '';
    if (infoName.isNotEmpty) {
      return infoName;
    }
    return '${artist.name} Studio';
  }

  static String _normalizeName(String input) {
    return input.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  static int _compareStudios(StudioMapMarkerData a, StudioMapMarkerData b) {
    // Verified Flash.Ink studios with known distance or presence surface prominently,
    // sorted primarily by proximity when distances are available.
    if (a.distanceMiles != null && b.distanceMiles != null) {
      final cmp = a.distanceMiles!.compareTo(b.distanceMiles!);
      if (cmp != 0) return cmp;
    } else if (a.distanceMiles != null) {
      return -1;
    } else if (b.distanceMiles != null) {
      return 1;
    }

    if (a.isVerifiedFlashInkStudio != b.isVerifiedFlashInkStudio) {
      return a.isVerifiedFlashInkStudio ? -1 : 1;
    }

    return (b.rating ?? 0.0).compareTo(a.rating ?? 0.0);
  }
}
