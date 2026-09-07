enum FlashStatus {
  available('Available'),
  claimed('Claimed'),
  repeatable('Repeatable');

  final String label;
  const FlashStatus(this.label);

  static FlashStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'claimed':
        return FlashStatus.claimed;
      case 'repeatable':
        return FlashStatus.repeatable;
      case 'available':
      default:
        return FlashStatus.available;
    }
  }
}

class FlashArtwork {
  final String id;
  final String artistId;
  final String title;
  final String imageUrl;
  final int price;
  final FlashStatus status;
  final String dimensions;
  final String estimatedTime;
  final String location;
  final int deposit;
  final String category;
  final String? artistName;

  const FlashArtwork({
    required this.id,
    this.artistId = '',
    required this.title,
    required this.imageUrl,
    int? price,
    int? fullPrice,
    this.status = FlashStatus.available,
    String? dimensions,
    String? size,
    this.estimatedTime = '2.5 hrs',
    this.location = 'Forearm / Calf',
    int? deposit,
    this.category = 'Flash',
    this.artistName,
  })  : price = price ?? fullPrice ?? (deposit != null ? deposit * 3 : 150),
        dimensions = dimensions ?? size ?? '5" x 7"',
        deposit = deposit ?? 50;

  bool get isClaimed => status == FlashStatus.claimed;
  int get fullPrice => price;
  String get size => dimensions;

  FlashArtwork copyWith({
    String? id,
    String? artistId,
    String? title,
    String? imageUrl,
    int? price,
    FlashStatus? status,
    String? dimensions,
    String? estimatedTime,
    String? location,
    int? deposit,
    String? category,
    String? artistName,
  }) {
    return FlashArtwork(
      id: id ?? this.id,
      artistId: artistId ?? this.artistId,
      title: title ?? this.title,
      imageUrl: imageUrl ?? this.imageUrl,
      price: price ?? this.price,
      status: status ?? this.status,
      dimensions: dimensions ?? this.dimensions,
      estimatedTime: estimatedTime ?? this.estimatedTime,
      location: location ?? this.location,
      deposit: deposit ?? this.deposit,
      category: category ?? this.category,
      artistName: artistName ?? this.artistName,
    );
  }

  static List<FlashArtwork> get mockFlashPieces {
    final pieces = <FlashArtwork>[];
    for (final artist in Artist.mockArtists) {
      pieces.addAll(artist.flashArtworks);
    }
    return pieces;
  }
}

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
  final List<FlashArtwork> flashArtworks;

  /// Array of 4 preview image URLs for the 2x2 artist showcase card.
  List<String> get previewImages => images;

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
    List<String>? images,
    List<String>? previewImages,
    this.isFavorited = false,
    this.tags = const [],
    this.flashArtworks = const [],
  }) : images = previewImages ?? images ?? const [];

  FlashArtwork get featuredFlash =>
      flashArtworks.isNotEmpty
          ? flashArtworks.first
          : FlashArtwork(
              id: '${id}_featured',
              artistId: id,
              artistName: name,
              title: '$name Signature Flash',
              imageUrl: images.isNotEmpty ? images.first : avatarUrl,
              price: minDeposit * 3,
              deposit: minDeposit,
              dimensions: '5" x 7"',
              estimatedTime: '2.5 hrs',
              location: location,
              status: FlashStatus.available,
            );

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
    List<String>? previewImages,
    bool? isFavorited,
    List<String>? tags,
    List<FlashArtwork>? flashArtworks,
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
      images: previewImages ?? images ?? this.images,
      isFavorited: isFavorited ?? this.isFavorited,
      tags: tags ?? this.tags,
      flashArtworks: flashArtworks ?? this.flashArtworks,
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
      previewImages: [
        'https://images.unsplash.com/photo-1598371839696-5c5bb00bdc28?auto=format&fit=crop&w=600&q=80',
        'https://images.unsplash.com/photo-1562962230-16e4623d36e6?auto=format&fit=crop&w=600&q=80',
        'https://images.unsplash.com/photo-1611501275019-9b5cda994e8d?auto=format&fit=crop&w=600&q=80',
        'https://images.unsplash.com/photo-1568515045052-f9a854d70bfd?auto=format&fit=crop&w=600&q=80',
      ],
      flashArtworks: [
        FlashArtwork(
          id: 'flash_1_1',
          artistId: 'artist_1',
          artistName: 'Oddmaree',
          title: 'Sacred Dagger & Serpent',
          imageUrl:
              'https://images.unsplash.com/photo-1598371839696-5c5bb00bdc28?auto=format&fit=crop&w=600&q=80',
          price: 220,
          deposit: 60,
          status: FlashStatus.available,
          dimensions: '5" x 8"',
          estimatedTime: '2.5 hrs',
          location: 'Forearm / Calf',
          category: 'Traditional',
        ),
        FlashArtwork(
          id: 'flash_1_2',
          artistId: 'artist_1',
          artistName: 'Oddmaree',
          title: 'Botanical Sun Skull',
          imageUrl:
              'https://images.unsplash.com/photo-1562962230-16e4623d36e6?auto=format&fit=crop&w=600&q=80',
          price: 260,
          deposit: 70,
          status: FlashStatus.available,
          dimensions: '6" x 9"',
          estimatedTime: '3.0 hrs',
          location: 'Thigh / Outer Arm',
          category: 'Traditional',
        ),
        FlashArtwork(
          id: 'flash_1_3',
          artistId: 'artist_1',
          artistName: 'Oddmaree',
          title: 'Crying Heart Dagger',
          imageUrl:
              'https://images.unsplash.com/photo-1611501275019-9b5cda994e8d?auto=format&fit=crop&w=600&q=80',
          price: 190,
          deposit: 50,
          status: FlashStatus.claimed,
          dimensions: '4" x 6"',
          estimatedTime: '2.0 hrs',
          location: 'Upper Arm / Chest',
          category: 'Traditional',
        ),
        FlashArtwork(
          id: 'flash_1_4',
          artistId: 'artist_1',
          artistName: 'Oddmaree',
          title: 'Celestial Luna Moth',
          imageUrl:
              'https://images.unsplash.com/photo-1568515045052-f9a854d70bfd?auto=format&fit=crop&w=600&q=80',
          price: 300,
          deposit: 80,
          status: FlashStatus.repeatable,
          dimensions: '7" x 5"',
          estimatedTime: '3.5 hrs',
          location: 'Sternum / Back',
          category: 'Neo-Traditional',
        ),
        FlashArtwork(
          id: 'flash_1_5',
          artistId: 'artist_1',
          artistName: 'Oddmaree',
          title: 'Wild Rose & Thorn',
          imageUrl:
              'https://images.unsplash.com/photo-1579783900882-c0d3dad7b119?auto=format&fit=crop&w=600&q=80',
          price: 170,
          deposit: 50,
          status: FlashStatus.available,
          dimensions: '3" x 6"',
          estimatedTime: '1.5 hrs',
          location: 'Inner Forearm',
          category: 'Traditional',
        ),
        FlashArtwork(
          id: 'flash_1_6',
          artistId: 'artist_1',
          artistName: 'Oddmaree',
          title: 'Twin Swallow Flight',
          imageUrl:
              'https://images.unsplash.com/photo-1581338834647-b0fb40704e21?auto=format&fit=crop&w=600&q=80',
          price: 240,
          deposit: 65,
          status: FlashStatus.available,
          dimensions: '5" x 5"',
          estimatedTime: '2.5 hrs',
          location: 'Shoulders / Chest',
          category: 'Traditional',
        ),
        FlashArtwork(
          id: 'flash_1_7',
          artistId: 'artist_1',
          artistName: 'Oddmaree',
          title: 'Ornate Key of Life',
          imageUrl:
              'https://images.unsplash.com/photo-1560707303-4e980ce876ad?auto=format&fit=crop&w=600&q=80',
          price: 160,
          deposit: 50,
          status: FlashStatus.available,
          dimensions: '3" x 5"',
          estimatedTime: '1.5 hrs',
          location: 'Ankle / Wrist',
          category: 'Traditional',
        ),
        FlashArtwork(
          id: 'flash_1_8',
          artistId: 'artist_1',
          artistName: 'Oddmaree',
          title: 'Mystic Wolf Totem',
          imageUrl:
              'https://images.unsplash.com/photo-1549465220-1a8b9238cd48?auto=format&fit=crop&w=600&q=80',
          price: 320,
          deposit: 80,
          status: FlashStatus.claimed,
          dimensions: '6" x 10"',
          estimatedTime: '3.5 hrs',
          location: 'Bicep / Thigh',
          category: 'Neo-Traditional',
        ),
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
      previewImages: [
        'https://images.unsplash.com/photo-1542382257-80dedb725088?auto=format&fit=crop&w=600&q=80',
        'https://images.unsplash.com/photo-1550537687-c91072c4792d?auto=format&fit=crop&w=600&q=80',
        'https://images.unsplash.com/photo-1614036417651-efe5912149d8?auto=format&fit=crop&w=600&q=80',
        'https://images.unsplash.com/photo-1578301978693-85fa9c0320b9?auto=format&fit=crop&w=600&q=80',
      ],
      flashArtworks: [
        FlashArtwork(
          id: 'flash_2_1',
          artistId: 'artist_2',
          artistName: 'Kian Forreal',
          title: 'Dragon Koi Ascending',
          imageUrl:
              'https://images.unsplash.com/photo-1542382257-80dedb725088?auto=format&fit=crop&w=600&q=80',
          price: 340,
          deposit: 85,
          status: FlashStatus.available,
          dimensions: '6" x 12"',
          estimatedTime: '4.0 hrs',
          location: 'Forearm / Calf',
          category: 'Japanese',
        ),
        FlashArtwork(
          id: 'flash_2_2',
          artistId: 'artist_2',
          artistName: 'Kian Forreal',
          title: 'Oni Mask & Blossoms',
          imageUrl:
              'https://images.unsplash.com/photo-1550537687-c91072c4792d?auto=format&fit=crop&w=600&q=80',
          price: 400,
          deposit: 100,
          status: FlashStatus.available,
          dimensions: '7" x 10"',
          estimatedTime: '4.5 hrs',
          location: 'Thigh / Upper Arm',
          category: 'Japanese',
        ),
        FlashArtwork(
          id: 'flash_2_3',
          artistId: 'artist_2',
          artistName: 'Kian Forreal',
          title: 'Great Wave Talisman',
          imageUrl:
              'https://images.unsplash.com/photo-1614036417651-efe5912149d8?auto=format&fit=crop&w=600&q=80',
          price: 270,
          deposit: 75,
          status: FlashStatus.repeatable,
          dimensions: '5" x 7"',
          estimatedTime: '2.5 hrs',
          location: 'Forearm / Shoulder',
          category: 'Japanese',
        ),
        FlashArtwork(
          id: 'flash_2_4',
          artistId: 'artist_2',
          artistName: 'Kian Forreal',
          title: 'Fujin Wind Crest',
          imageUrl:
              'https://images.unsplash.com/photo-1578301978693-85fa9c0320b9?auto=format&fit=crop&w=600&q=80',
          price: 440,
          deposit: 110,
          status: FlashStatus.claimed,
          dimensions: '8" x 10"',
          estimatedTime: '5.0 hrs',
          location: 'Back / Ribs',
          category: 'Japanese',
        ),
        FlashArtwork(
          id: 'flash_2_5',
          artistId: 'artist_2',
          artistName: 'Kian Forreal',
          title: 'Tiger Stalking Bamboo',
          imageUrl:
              'https://images.unsplash.com/photo-1582794543139-8ac9cb0f7b11?auto=format&fit=crop&w=600&q=80',
          price: 360,
          deposit: 90,
          status: FlashStatus.available,
          dimensions: '6" x 11"',
          estimatedTime: '4.0 hrs',
          location: 'Calf / Thigh',
          category: 'Japanese',
        ),
        FlashArtwork(
          id: 'flash_2_6',
          artistId: 'artist_2',
          artistName: 'Kian Forreal',
          title: 'Chrysanthemum Bloom',
          imageUrl:
              'https://images.unsplash.com/photo-1561055657-b9e0bf0fa360?auto=format&fit=crop&w=600&q=80',
          price: 290,
          deposit: 75,
          status: FlashStatus.available,
          dimensions: '5" x 5"',
          estimatedTime: '3.0 hrs',
          location: 'Knee / Elbow',
          category: 'Japanese',
        ),
        FlashArtwork(
          id: 'flash_2_7',
          artistId: 'artist_2',
          artistName: 'Kian Forreal',
          title: 'Golden Carp Crest',
          imageUrl:
              'https://images.unsplash.com/photo-1580618672591-eb180b1a973f?auto=format&fit=crop&w=600&q=80',
          price: 260,
          deposit: 70,
          status: FlashStatus.available,
          dimensions: '4" x 7"',
          estimatedTime: '2.5 hrs',
          location: 'Forearm',
          category: 'Japanese',
        ),
        FlashArtwork(
          id: 'flash_2_8',
          artistId: 'artist_2',
          artistName: 'Kian Forreal',
          title: 'Demon Slayer Katana',
          imageUrl:
              'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?auto=format&fit=crop&w=600&q=80',
          price: 310,
          deposit: 80,
          status: FlashStatus.available,
          dimensions: '5" x 9"',
          estimatedTime: '3.0 hrs',
          location: 'Outer Arm',
          category: 'Japanese',
        ),
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
      previewImages: [
        'https://images.unsplash.com/photo-1607604276583-eef5d076aa5f?auto=format&fit=crop&w=600&q=80',
        'https://images.unsplash.com/photo-1581338834647-b0fb40704e21?auto=format&fit=crop&w=600&q=80',
        'https://images.unsplash.com/photo-1560707303-4e980ce876ad?auto=format&fit=crop&w=600&q=80',
        'https://images.unsplash.com/photo-1549465220-1a8b9238cd48?auto=format&fit=crop&w=600&q=80',
      ],
      flashArtworks: [
        FlashArtwork(
          id: 'flash_3_1',
          artistId: 'artist_3',
          artistName: 'Elena Surova',
          title: 'Fine Line Flora Study',
          imageUrl:
              'https://images.unsplash.com/photo-1607604276583-eef5d076aa5f?auto=format&fit=crop&w=600&q=80',
          price: 330,
          deposit: 100,
          status: FlashStatus.available,
          dimensions: '4" x 8"',
          estimatedTime: '3.0 hrs',
          location: 'Inner Bicep / Ribs',
          category: 'Fine Line',
        ),
        FlashArtwork(
          id: 'flash_3_2',
          artistId: 'artist_3',
          artistName: 'Elena Surova',
          title: 'Minimalist Silhouette',
          imageUrl:
              'https://images.unsplash.com/photo-1581338834647-b0fb40704e21?auto=format&fit=crop&w=600&q=80',
          price: 250,
          deposit: 80,
          status: FlashStatus.claimed,
          dimensions: '3" x 5"',
          estimatedTime: '2.0 hrs',
          location: 'Shoulder / Nape',
          category: 'Fine Line',
        ),
        FlashArtwork(
          id: 'flash_3_3',
          artistId: 'artist_3',
          artistName: 'Elena Surova',
          title: 'Blackwork Sacred Geometry',
          imageUrl:
              'https://images.unsplash.com/photo-1560707303-4e980ce876ad?auto=format&fit=crop&w=600&q=80',
          price: 380,
          deposit: 100,
          status: FlashStatus.available,
          dimensions: '5" x 10"',
          estimatedTime: '3.5 hrs',
          location: 'Forearm / Spine',
          category: 'Blackwork',
        ),
        FlashArtwork(
          id: 'flash_3_4',
          artistId: 'artist_3',
          artistName: 'Elena Surova',
          title: 'Botanical Fern Arch',
          imageUrl:
              'https://images.unsplash.com/photo-1549465220-1a8b9238cd48?auto=format&fit=crop&w=600&q=80',
          price: 300,
          deposit: 90,
          status: FlashStatus.repeatable,
          dimensions: '4" x 7"',
          estimatedTime: '2.5 hrs',
          location: 'Collarbone / Arm',
          category: 'Fine Line',
        ),
        FlashArtwork(
          id: 'flash_3_5',
          artistId: 'artist_3',
          artistName: 'Elena Surova',
          title: 'Constellation Needle Map',
          imageUrl:
              'https://images.unsplash.com/photo-1577083552431-6e5fd01aa342?auto=format&fit=crop&w=600&q=80',
          price: 280,
          deposit: 85,
          status: FlashStatus.available,
          dimensions: '3" x 9"',
          estimatedTime: '2.5 hrs',
          location: 'Spine / Forearm',
          category: 'Fine Line',
        ),
        FlashArtwork(
          id: 'flash_3_6',
          artistId: 'artist_3',
          artistName: 'Elena Surova',
          title: 'Micro-Realism Swallow',
          imageUrl:
              'https://images.unsplash.com/photo-1579783928621-7a13d66a62d1?auto=format&fit=crop&w=600&q=80',
          price: 230,
          deposit: 80,
          status: FlashStatus.available,
          dimensions: '2" x 3"',
          estimatedTime: '1.5 hrs',
          location: 'Wrist / Behind Ear',
          category: 'Fine Line',
        ),
        FlashArtwork(
          id: 'flash_3_7',
          artistId: 'artist_3',
          artistName: 'Elena Surova',
          title: 'Hourglass & Wild Peony',
          imageUrl:
              'https://images.unsplash.com/photo-1577720643272-265f09367456?auto=format&fit=crop&w=600&q=80',
          price: 400,
          deposit: 110,
          status: FlashStatus.available,
          dimensions: '6" x 9"',
          estimatedTime: '3.5 hrs',
          location: 'Thigh / Outer Arm',
          category: 'Fine Line',
        ),
        FlashArtwork(
          id: 'flash_3_8',
          artistId: 'artist_3',
          artistName: 'Elena Surova',
          title: 'Whispering Moon Phases',
          imageUrl:
              'https://images.unsplash.com/photo-1544816155-12df9643f363?auto=format&fit=crop&w=600&q=80',
          price: 320,
          deposit: 95,
          status: FlashStatus.claimed,
          dimensions: '2" x 12"',
          estimatedTime: '3.0 hrs',
          location: 'Spine / Forearm',
          category: 'Blackwork',
        ),
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
      previewImages: [
        'https://images.unsplash.com/photo-1582794543139-8ac9cb0f7b11?auto=format&fit=crop&w=600&q=80',
        'https://images.unsplash.com/photo-1561055657-b9e0bf0fa360?auto=format&fit=crop&w=600&q=80',
        'https://images.unsplash.com/photo-1580618672591-eb180b1a973f?auto=format&fit=crop&w=600&q=80',
        'https://images.unsplash.com/photo-1604014237800-1c9102c219da?auto=format&fit=crop&w=600&q=80',
      ],
      flashArtworks: [
        FlashArtwork(
          id: 'flash_4_1',
          artistId: 'artist_4',
          artistName: 'Marcus Vex',
          title: 'Gothic Gargoyle Relic',
          imageUrl:
              'https://images.unsplash.com/photo-1582794543139-8ac9cb0f7b11?auto=format&fit=crop&w=600&q=80',
          price: 290,
          deposit: 60,
          status: FlashStatus.available,
          dimensions: '5" x 8"',
          estimatedTime: '2.5 hrs',
          location: 'Forearm / Calf',
          category: 'Blackwork',
        ),
        FlashArtwork(
          id: 'flash_4_2',
          artistId: 'artist_4',
          artistName: 'Marcus Vex',
          title: 'Vintage Anchor & Rose',
          imageUrl:
              'https://images.unsplash.com/photo-1561055657-b9e0bf0fa360?auto=format&fit=crop&w=600&q=80',
          price: 230,
          deposit: 60,
          status: FlashStatus.repeatable,
          dimensions: '4" x 6"',
          estimatedTime: '2.0 hrs',
          location: 'Bicep / Calf',
          category: 'Traditional',
        ),
        FlashArtwork(
          id: 'flash_4_3',
          artistId: 'artist_4',
          artistName: 'Marcus Vex',
          title: 'Grim Reaper Hourglass',
          imageUrl:
              'https://images.unsplash.com/photo-1580618672591-eb180b1a973f?auto=format&fit=crop&w=600&q=80',
          price: 320,
          deposit: 70,
          status: FlashStatus.available,
          dimensions: '6" x 10"',
          estimatedTime: '3.0 hrs',
          location: 'Outer Thigh / Arm',
          category: 'Traditional',
        ),
        FlashArtwork(
          id: 'flash_4_4',
          artistId: 'artist_4',
          artistName: 'Marcus Vex',
          title: 'American Eagle Crest',
          imageUrl:
              'https://images.unsplash.com/photo-1579783900882-c0d3dad7b119?auto=format&fit=crop&w=600&q=80',
          price: 350,
          deposit: 80,
          status: FlashStatus.claimed,
          dimensions: '7" x 9"',
          estimatedTime: '3.5 hrs',
          location: 'Chest / Back',
          category: 'Traditional',
        ),
        FlashArtwork(
          id: 'flash_4_5',
          artistId: 'artist_4',
          artistName: 'Marcus Vex',
          title: 'Dagger Through Skull',
          imageUrl:
              'https://images.unsplash.com/photo-1604014237800-1c9102c219da?auto=format&fit=crop&w=600&q=80',
          price: 260,
          deposit: 60,
          status: FlashStatus.available,
          dimensions: '5" x 8"',
          estimatedTime: '2.5 hrs',
          location: 'Forearm',
          category: 'Traditional',
        ),
        FlashArtwork(
          id: 'flash_4_6',
          artistId: 'artist_4',
          artistName: 'Marcus Vex',
          title: 'Panther Head Snarl',
          imageUrl:
              'https://images.unsplash.com/photo-1560066984-138dadb4c035?auto=format&fit=crop&w=600&q=80',
          price: 280,
          deposit: 65,
          status: FlashStatus.available,
          dimensions: '5" x 5"',
          estimatedTime: '2.5 hrs',
          location: 'Shoulder / Calf',
          category: 'Traditional',
        ),
      ],
    ),
  ];
}
