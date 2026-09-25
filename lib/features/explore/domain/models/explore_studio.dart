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

  static const List<ExploreStudio> mockStudios = [
    ExploreStudio(
      id: 'studio_1',
      name: 'Obsidian Atelier',
      address: '742 S Santa Fe Ave',
      city: 'Los Angeles, CA',
      imageUrl:
          'https://images.unsplash.com/photo-1598371839696-5c5bb00bdc28?auto=format&fit=crop&w=600&q=80',
      rating: 4.9,
      reviewCount: 184,
      residentArtistsCount: 6,
      styles: ['Blackwork', 'Dark Surrealism', 'Fine Line'],
      isVerified: true,
    ),
    ExploreStudio(
      id: 'studio_2',
      name: 'Void & Bloom Tattoo Studio',
      address: '1280 E 1st St',
      city: 'Los Angeles, CA',
      imageUrl:
          'https://images.unsplash.com/photo-1611501275019-9b5cda994e8d?auto=format&fit=crop&w=600&q=80',
      rating: 4.8,
      reviewCount: 142,
      residentArtistsCount: 4,
      styles: ['Japanese Traditional', 'Neo-Traditional', 'Floral'],
      isVerified: true,
    ),
    ExploreStudio(
      id: 'studio_3',
      name: 'Velvet Needle Parlor',
      address: '310 Sunset Blvd',
      city: 'Venice, CA',
      imageUrl:
          'https://images.unsplash.com/photo-1562962230-16e4623d36e6?auto=format&fit=crop&w=600&q=80',
      rating: 5.0,
      reviewCount: 96,
      residentArtistsCount: 5,
      styles: ['Fine Line', 'Micro-Realism', 'Ornamental'],
      isVerified: true,
    ),
    ExploreStudio(
      id: 'studio_4',
      name: 'Iron & Oak Collective',
      address: '420 N Fairfax Ave',
      city: 'West Hollywood, CA',
      imageUrl:
          'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=600&q=80',
      rating: 4.7,
      reviewCount: 210,
      residentArtistsCount: 8,
      styles: ['American Traditional', 'Illustrative', 'Lettering'],
      isVerified: true,
    ),
  ];
}
