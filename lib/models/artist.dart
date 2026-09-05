class Artist {
  final String id;
  final String name;
  final String avatarUrl;
  final bool isBooksOpen;
  final String location;
  final String studioType;
  final double rating;
  final int availablePieces;
  final int minDeposit;
  final List<String> images;
  final bool isFavorited;
  final List<String> tags;

  const Artist({
    required this.id,
    required this.name,
    required this.avatarUrl,
    this.isBooksOpen = true,
    required this.location,
    required this.studioType,
    required this.rating,
    required this.availablePieces,
    required this.minDeposit,
    required this.images,
    this.isFavorited = false,
    this.tags = const [],
  });

  Artist copyWith({
    String? id,
    String? name,
    String? avatarUrl,
    bool? isBooksOpen,
    String? location,
    String? studioType,
    double? rating,
    int? availablePieces,
    int? minDeposit,
    List<String>? images,
    bool? isFavorited,
    List<String>? tags,
  }) {
    return Artist(
      id: id ?? this.id,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isBooksOpen: isBooksOpen ?? this.isBooksOpen,
      location: location ?? this.location,
      studioType: studioType ?? this.studioType,
      rating: rating ?? this.rating,
      availablePieces: availablePieces ?? this.availablePieces,
      minDeposit: minDeposit ?? this.minDeposit,
      images: images ?? this.images,
      isFavorited: isFavorited ?? this.isFavorited,
      tags: tags ?? this.tags,
    );
  }

  static const List<Artist> mockArtists = [
    Artist(
      id: 'artist_1',
      name: 'Oddmaree',
      avatarUrl:
          'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=400&q=80',
      isBooksOpen: true,
      location: 'Portland, OR',
      studioType: 'Private Studio',
      rating: 5.0,
      availablePieces: 12,
      minDeposit: 50,
      tags: ['Traditional', 'Queer Artists'],
      images: [
        'https://images.unsplash.com/photo-1598371839696-5c5bb00bdc28?auto=format&fit=crop&w=600&q=80',
        'https://images.unsplash.com/photo-1562962230-16e4623d36e6?auto=format&fit=crop&w=600&q=80',
        'https://images.unsplash.com/photo-1611501275019-9b5cda994e8d?auto=format&fit=crop&w=600&q=80',
        'https://images.unsplash.com/photo-1590246814883-578337424072?auto=format&fit=crop&w=600&q=80',
      ],
    ),
    Artist(
      id: 'artist_2',
      name: 'Kian Forreal',
      avatarUrl:
          'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=400&q=80',
      isBooksOpen: true,
      location: 'San Francisco, CA',
      studioType: 'Black Veil Studio',
      rating: 4.9,
      availablePieces: 8,
      minDeposit: 75,
      tags: ['Japanese', 'Queer Artists'],
      images: [
        'https://images.unsplash.com/photo-1611501275019-9b5cda994e8d?auto=format&fit=crop&w=600&q=80',
        'https://images.unsplash.com/photo-1598371839696-5c5bb00bdc28?auto=format&fit=crop&w=600&q=80',
        'https://images.unsplash.com/photo-1590246814883-578337424072?auto=format&fit=crop&w=600&q=80',
        'https://images.unsplash.com/photo-1562962230-16e4623d36e6?auto=format&fit=crop&w=600&q=80',
      ],
    ),
    Artist(
      id: 'artist_3',
      name: 'Elena Surova',
      avatarUrl:
          'https://images.unsplash.com/photo-1517841905240-472988babdf9?auto=format&fit=crop&w=400&q=80',
      isBooksOpen: false,
      location: 'Brooklyn, NY',
      studioType: 'Rose & Dagger',
      rating: 5.0,
      availablePieces: 15,
      minDeposit: 100,
      tags: ['Fine Line', 'Blackwork'],
      images: [
        'https://images.unsplash.com/photo-1562962230-16e4623d36e6?auto=format&fit=crop&w=600&q=80',
        'https://images.unsplash.com/photo-1611501275019-9b5cda994e8d?auto=format&fit=crop&w=600&q=80',
        'https://images.unsplash.com/photo-1598371839696-5c5bb00bdc28?auto=format&fit=crop&w=600&q=80',
        'https://images.unsplash.com/photo-1590246814883-578337424072?auto=format&fit=crop&w=600&q=80',
      ],
    ),
    Artist(
      id: 'artist_4',
      name: 'Marcus Vex',
      avatarUrl:
          'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=400&q=80',
      isBooksOpen: true,
      location: 'Austin, TX',
      studioType: 'Golden Needle',
      rating: 4.8,
      availablePieces: 6,
      minDeposit: 60,
      tags: ['Realism', 'Traditional'],
      images: [
        'https://images.unsplash.com/photo-1590246814883-578337424072?auto=format&fit=crop&w=600&q=80',
        'https://images.unsplash.com/photo-1562962230-16e4623d36e6?auto=format&fit=crop&w=600&q=80',
        'https://images.unsplash.com/photo-1598371839696-5c5bb00bdc28?auto=format&fit=crop&w=600&q=80',
        'https://images.unsplash.com/photo-1611501275019-9b5cda994e8d?auto=format&fit=crop&w=600&q=80',
      ],
    ),
  ];
}
