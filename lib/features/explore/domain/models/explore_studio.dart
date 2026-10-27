import '../../../../core/mock/mock_fixtures.dart';
import '../../../../models/artist.dart';

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
    );
  }

  /// Quarantined mock studio fixtures preserved in [MockFixtures.studios].
  static const List<ExploreStudio> mockStudios = MockFixtures.studios;
}
