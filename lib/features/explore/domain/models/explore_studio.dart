import '../../../../models/artist.dart';
import '../../../../services/google_places_service.dart';
import '../../../../services/studio_map_service.dart';

/// Strongly typed tattoo studio model for the Explore directory.
class ExploreStudio {
  final String id;
  final String name;
  final String address;
  final String city;
  final String imageUrl;
  final double rating;
  final int reviewCount;
  final int residentArtistsCount;
  final List<String> styles;
  final bool isVerified;
  final String? distance;
  final double? distanceMiles;
  final String? placeId;
  final double? latitude;
  final double? longitude;

  const ExploreStudio({
    required this.id,
    required this.name,
    required this.address,
    required this.city,
    required this.imageUrl,
    required this.rating,
    required this.reviewCount,
    required this.residentArtistsCount,
    required this.styles,
    this.isVerified = true,
    this.distance,
    this.distanceMiles,
    this.placeId,
    this.latitude,
    this.longitude,
  });

  /// Builds a privacy-safe live studio card from an onboarded [Artist].
  factory ExploreStudio.fromArtist(
    Artist artist, {
    int residentArtistsCount = 1,
  }) {
    final studioInfo = artist.studioInformation;
    final studioTitle = artist.studioName.isNotEmpty
        ? artist.studioName
        : (studioInfo?.name.isNotEmpty == true
            ? studioInfo!.name
            : '${artist.name} Studio');
    final isPrivate =
        artist.isPrivateStudio || (studioInfo?.isPrivateStudio ?? true);
    final cityLabel = studioInfo?.displayLocation.isNotEmpty == true
        ? studioInfo!.displayLocation
        : artist.location;
    final safeAddress = isPrivate
        ? 'Private Studio'
        : (studioInfo?.formattedAddress.isNotEmpty == true
            ? studioInfo!.formattedAddress
            : cityLabel);
    final coverImage = artist.flashArtworks.isNotEmpty
        ? artist.flashArtworks.first.imageUrl
        : (artist.images.isNotEmpty ? artist.images.first : artist.avatarUrl);

    final rawCoords =
        studioInfo?.discoveryCoordinates ?? artist.discoveryCoordinates;
    final safeCoords =
        rawCoords != null && rawCoords.isValid ? (isPrivate ? rawCoords.coarsened(decimals: 2) : rawCoords) : null;

    final placeId = isPrivate ? null : studioInfo?.placeId;

    return ExploreStudio(
      id: 'studio_${artist.id}',
      name: studioTitle,
      address: safeAddress,
      city: cityLabel,
      imageUrl: coverImage,
      rating: artist.rating,
      reviewCount: artist.availablePieces,
      residentArtistsCount: residentArtistsCount,
      styles: artist.tags,
      isVerified: artist.isVerifiedStudio,
      distance: artist.distance.isNotEmpty ? artist.distance : null,
      distanceMiles: artist.distanceMiles,
      placeId: placeId,
      latitude: safeCoords?.latitude,
      longitude: safeCoords?.longitude,
    );
  }

  /// Builds an [ExploreStudio] card directly from a [StudioMapMarkerData].
  factory ExploreStudio.fromMarker(
    StudioMapMarkerData marker, {
    GooglePlacesService? placesService,
  }) {
    final photoUrl = marker.imageUrl ??
        (marker.photoReference != null && placesService != null
            ? placesService.buildPhotoUrl(marker.photoReference, maxWidth: 800)
            : null);

    return ExploreStudio(
      id: marker.id,
      name: marker.name,
      address: marker.address,
      city: marker.cityState,
      imageUrl: (photoUrl != null && photoUrl.trim().isNotEmpty)
          ? photoUrl
          : 'assets/images/tattoo_setup.png',
      rating: marker.rating ?? 4.8,
      reviewCount: marker.reviewCount ?? 0,
      residentArtistsCount: marker.residentArtistsCount,
      styles: marker.styles.isNotEmpty
          ? marker.styles
          : const ['Tattoo Studio', 'Custom Ink'],
      isVerified: marker.isVerifiedFlashInkStudio,
      distance: marker.formattedDistance,
      distanceMiles: marker.distanceMiles,
      placeId: marker.placeId,
      latitude: marker.position.latitude,
      longitude: marker.position.longitude,
    );
  }
}

