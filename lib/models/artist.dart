import '../core/mock/mock_fixtures.dart';
import '../core/utils/distance_calculator.dart';
import 'studio_information.dart';

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
  final bool? _isExclusive;

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
    this._isExclusive,
  })  : price = price ?? fullPrice ?? (deposit != null ? deposit * 3 : 150),
        dimensions = dimensions ?? size ?? '5" x 7"',
        deposit = deposit ?? 50;

  bool get isClaimed => status == FlashStatus.claimed;
  bool get isExclusive => _isExclusive ?? (status != FlashStatus.repeatable);
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
    bool? isExclusive,
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
      isExclusive: isExclusive ?? _isExclusive,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'artistId': artistId,
      'title': title,
      'imageUrl': imageUrl,
      'price': price,
      'status': status.name,
      'dimensions': dimensions,
      'estimatedTime': estimatedTime,
      'location': location,
      'deposit': deposit,
      'category': category,
      'artistName': artistName,
      'isExclusive': _isExclusive,
    };
  }

  factory FlashArtwork.fromMap(Map<String, dynamic> map, {String? defaultArtistId, String? defaultArtistName}) {
    return FlashArtwork(
      id: map['id']?.toString() ?? '',
      artistId: map['artistId']?.toString() ?? defaultArtistId ?? '',
      title: map['title']?.toString() ?? 'Flash Artwork',
      imageUrl: map['imageUrl']?.toString() ?? 'assets/images/flash_traditional_panther.jpg',
      price: (map['price'] is num) ? (map['price'] as num).toInt() : null,
      fullPrice: (map['fullPrice'] is num) ? (map['fullPrice'] as num).toInt() : null,
      status: FlashStatus.fromString(map['status']?.toString() ?? 'available'),
      dimensions: map['dimensions']?.toString() ?? map['size']?.toString(),
      estimatedTime: map['estimatedTime']?.toString() ?? '2.5 hrs',
      location: map['location']?.toString() ?? 'Forearm / Calf',
      deposit: (map['deposit'] is num) ? (map['deposit'] as num).toInt() : null,
      category: map['category']?.toString() ?? 'Flash',
      artistName: map['artistName']?.toString() ?? defaultArtistName,
      isExclusive: map['isExclusive'] as bool?,
    );
  }
}

class ArtistFunFact {
  final String label;
  final String value;
  const ArtistFunFact({required this.label, required this.value});

  Map<String, dynamic> toMap() => {'label': label, 'value': value};

  factory ArtistFunFact.fromMap(Map<String, dynamic> map) => ArtistFunFact(
    label: map['label']?.toString() ?? '',
    value: map['value']?.toString() ?? '',
  );
}

class StudioPolicy {
  final String title;
  final String description;
  final String iconKey;
  final bool isEnabled;

  const StudioPolicy({
    required this.title,
    required this.description,
    this.iconKey = 'deposit',
    this.isEnabled = true,
  });

  Map<String, dynamic> toMap() => {
    'title': title,
    'description': description,
    'iconKey': iconKey,
    'isEnabled': isEnabled,
  };

  factory StudioPolicy.fromMap(Map<String, dynamic> map) => StudioPolicy(
    title: map['title']?.toString() ?? '',
    description: map['description']?.toString() ?? '',
    iconKey: map['iconKey']?.toString() ?? 'deposit',
    isEnabled: map['isEnabled'] != false,
  );

  StudioPolicy copyWith({
    String? title,
    String? description,
    String? iconKey,
    bool? isEnabled,
  }) {
    return StudioPolicy(
      title: title ?? this.title,
      description: description ?? this.description,
      iconKey: iconKey ?? this.iconKey,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }
}

class Artist {
  final String id;
  final String name;
  final String username;
  final String instagramHandle;
  final String studioName;
  final String avatarUrl;
  final bool isBooksOpen;
  final String location;
  final String studioType;
  final bool isPrivateStudio;
  final String distance;
  final double? distanceMiles;
  final double? latitude;
  final double? longitude;
  final bool profileCompleted;
  final double rating;
  final int availablePieces;
  final int minDeposit;
  final List<String> images;
  final bool isFavorited;
  final List<String> tags;
  final List<FlashArtwork> flashArtworks;
  final String bio;
  final List<ArtistFunFact> funFacts;
  final List<StudioPolicy> policies;
  final bool isVerifiedStudio;
  final bool customRequestAvailable;
  final StudioInformation? studioInformation;

  /// Array of 4 preview image URLs for the 2x2 artist showcase card.
  List<String> get previewImages => images;

  const Artist({
    required this.id,
    required this.name,
    this.username = '',
    this.instagramHandle = '',
    this.studioName = '',
    required this.avatarUrl,
    this.isBooksOpen = true,
    required this.location,
    required this.studioType,
    this.isPrivateStudio = false,
    this.distance = '',
    this.distanceMiles,
    this.latitude,
    this.longitude,
    this.profileCompleted = true,
    required this.rating,
    required this.availablePieces,
    required this.minDeposit,
    List<String>? images,
    List<String>? previewImages,
    this.isFavorited = false,
    this.tags = const [],
    this.flashArtworks = const [],
    this.bio =
        'A safe, inclusive space for all bodies. Silent appointments are always available upon request.',
    this.funFacts = MockFixtures.defaultFunFacts,
    this.policies = MockFixtures.defaultStudioPolicies,
    this.isVerifiedStudio = true,
    this.customRequestAvailable = true,
    this.studioInformation,
  }) : images = previewImages ?? images ?? const [];

  /// Discovery-safe coordinates for distance calculation.
  GeoPointCoords? get discoveryCoordinates {
    final lat = latitude ?? studioInformation?.latitude;
    final lng = longitude ?? studioInformation?.longitude;
    if (lat == null || lng == null) return null;
    final coords = GeoPointCoords(
      latitude: lat,
      longitude: lng,
      resolvedLabel: location,
    );
    return coords.isValid ? coords : null;
  }

  /// Returns a copy of this [Artist] with live Haversine distance calculated
  /// from [clientCoords]. Preserves existing [distance] when either coordinate
  /// is unavailable.
  Artist withLiveDistanceFrom(GeoPointCoords? clientCoords) {
    final artistCoords = discoveryCoordinates;
    if (clientCoords == null || !clientCoords.isValid || artistCoords == null) {
      return this;
    }
    final miles = DistanceCalculator.calculateMiles(
      startLatitude: clientCoords.latitude,
      startLongitude: clientCoords.longitude,
      endLatitude: artistCoords.latitude,
      endLongitude: artistCoords.longitude,
    );
    return copyWith(
      distanceMiles: miles,
      distance: DistanceCalculator.formatMilesAway(miles),
    );
  }

  FlashArtwork get featuredFlash =>
      flashArtworks.isNotEmpty
          ? flashArtworks.first
          : FlashArtwork(
              id: '${id}_featured',
              artistId: id,
              artistName: name,
              title: '$name Signature Flash',
              imageUrl: images.isNotEmpty
                  ? images.first
                  : 'assets/images/flash_traditional_dagger.jpg',
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
    String? username,
    String? instagramHandle,
    String? studioName,
    String? avatarUrl,
    bool? isBooksOpen,
    String? location,
    String? studioType,
    bool? isPrivateStudio,
    String? distance,
    double? distanceMiles,
    double? latitude,
    double? longitude,
    bool? profileCompleted,
    double? rating,
    int? availablePieces,
    int? minDeposit,
    List<String>? images,
    List<String>? previewImages,
    bool? isFavorited,
    List<String>? tags,
    List<FlashArtwork>? flashArtworks,
    String? bio,
    List<ArtistFunFact>? funFacts,
    List<StudioPolicy>? policies,
    bool? isVerifiedStudio,
    bool? customRequestAvailable,
    StudioInformation? studioInformation,
  }) {
    return Artist(
      id: id ?? this.id,
      name: name ?? this.name,
      username: username ?? this.username,
      instagramHandle: instagramHandle ?? this.instagramHandle,
      studioName: studioName ?? this.studioName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isBooksOpen: isBooksOpen ?? this.isBooksOpen,
      location: location ?? this.location,
      studioType: studioType ?? this.studioType,
      isPrivateStudio: isPrivateStudio ?? this.isPrivateStudio,
      distance: distance ?? this.distance,
      distanceMiles: distanceMiles ?? this.distanceMiles,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      profileCompleted: profileCompleted ?? this.profileCompleted,
      rating: rating ?? this.rating,
      availablePieces: availablePieces ?? this.availablePieces,
      minDeposit: minDeposit ?? this.minDeposit,
      images: previewImages ?? images ?? this.images,
      isFavorited: isFavorited ?? this.isFavorited,
      tags: tags ?? this.tags,
      flashArtworks: flashArtworks ?? this.flashArtworks,
      bio: bio ?? this.bio,
      funFacts: funFacts ?? this.funFacts,
      policies: policies ?? this.policies,
      isVerifiedStudio: isVerifiedStudio ?? this.isVerifiedStudio,
      customRequestAvailable:
          customRequestAvailable ?? this.customRequestAvailable,
      studioInformation: studioInformation ?? this.studioInformation,
    );
  }

  /// Privacy-safe public Firestore serialization for `/artists/{uid}`.
  /// Never writes private street/suite/entryCode/phoneNumber/email fields.
  Map<String, dynamic> toMap() {
    final safeCoords = studioInformation?.discoveryCoordinates ?? discoveryCoordinates;
    final effectivePrivateCoords = isPrivateStudio && safeCoords != null
        ? safeCoords.coarsened(decimals: 2)
        : safeCoords;
    return {
      'id': id,
      'name': name,
      'displayName': name,
      if (username.isNotEmpty) 'username': username,
      if (instagramHandle.isNotEmpty) 'instagramHandle': instagramHandle,
      if (studioName.isNotEmpty) 'studioName': studioName,
      'avatarUrl': avatarUrl,
      'photoUrl': avatarUrl,
      'isBooksOpen': isBooksOpen,
      'location': location,
      'city': studioInformation?.city.isNotEmpty == true
          ? studioInformation!.city
          : location,
      if (studioInformation?.state.isNotEmpty == true)
        'state': studioInformation!.state,
      'studioType': studioType,
      'isPrivateStudio': isPrivateStudio,
      if (effectivePrivateCoords != null) 'latitude': effectivePrivateCoords.latitude,
      if (effectivePrivateCoords != null) 'longitude': effectivePrivateCoords.longitude,
      'profileCompleted': profileCompleted,
      'rating': rating,
      'availablePieces': availablePieces,
      'minDeposit': minDeposit,
      'images': images,
      'isFavorited': isFavorited,
      'tags': tags,
      'flashArtworks': flashArtworks.map((f) => f.toMap()).toList(),
      'bio': bio,
      'funFacts': funFacts.map((f) => f.toMap()).toList(),
      'policies': policies.map((p) => p.toMap()).toList(),
      'isVerifiedStudio': isVerifiedStudio,
      'customRequestAvailable': customRequestAvailable,
      if (studioInformation != null)
        'studioInformation': studioInformation!.toPublicMap(),
    };
  }

  factory Artist.fromMap(Map<String, dynamic> map, [String? docId]) {
    final id = docId ?? map['id']?.toString() ?? '';
    final name = map['name']?.toString() ?? map['displayName']?.toString() ?? 'Artist';

    // Parse images
    List<String> images = [];
    if (map['images'] is List) {
      images = (map['images'] as List).map((e) => e.toString()).toList();
    } else if (map['previewImages'] is List) {
      images = (map['previewImages'] as List).map((e) => e.toString()).toList();
    }

    // Parse tags
    List<String> tags = [];
    if (map['tags'] is List) {
      tags = (map['tags'] as List).map((e) => e.toString()).toList();
    }

    // Parse flashArtworks
    List<FlashArtwork> flashArtworks = [];
    if (map['flashArtworks'] is List) {
      flashArtworks = (map['flashArtworks'] as List)
          .whereType<Map>()
          .map((item) => FlashArtwork.fromMap(
                Map<String, dynamic>.from(item),
                defaultArtistId: id,
                defaultArtistName: name,
              ))
          .toList();
    }

    // Parse fun facts
    List<ArtistFunFact>? funFacts;
    if (map['funFacts'] is List) {
      funFacts = (map['funFacts'] as List)
          .whereType<Map>()
          .map((item) => ArtistFunFact.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    }

    // Parse policies
    List<StudioPolicy>? policies;
    if (map['policies'] is List) {
      policies = (map['policies'] as List)
          .whereType<Map>()
          .map((item) => StudioPolicy.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    }

    StudioInformation? studioInfo;
    if (map['studioInformation'] is Map) {
      studioInfo = StudioInformation.fromMap(
        Map<String, dynamic>.from(map['studioInformation'] as Map),
      );
    } else if (map['studioName'] != null) {
      studioInfo = StudioInformation(
        name: map['studioName'].toString(),
        formattedAddress: map['studioAddress']?.toString() ?? '',
        city: map['city']?.toString() ?? '',
        state: map['state']?.toString() ?? '',
        latitude: (map['latitude'] is num) ? (map['latitude'] as num).toDouble() : null,
        longitude: (map['longitude'] is num) ? (map['longitude'] as num).toDouble() : null,
        isPrivateStudio: map['isPrivateStudio'] == true,
        studioType: map['studioType']?.toString() ?? 'Street Shop',
      );
    }

    final rawAvatar = map['avatarUrl'] ?? map['photoUrl'] ?? map['photoURL'];
    final avatarUrl = (rawAvatar is String && !rawAvatar.startsWith('local://'))
        ? rawAvatar
        : '';

    final parsedLat = (map['latitude'] is num)
        ? (map['latitude'] as num).toDouble()
        : studioInfo?.latitude;
    final parsedLng = (map['longitude'] is num)
        ? (map['longitude'] as num).toDouble()
        : studioInfo?.longitude;

    final bookableCount = flashArtworks
        .where((f) => !f.isClaimed)
        .length;

    return Artist(
      id: id,
      name: name,
      username: map['username']?.toString() ?? '',
      instagramHandle: map['instagramHandle']?.toString() ?? '',
      studioName: map['studioName']?.toString() ?? studioInfo?.name ?? '',
      avatarUrl: avatarUrl,
      isBooksOpen: map['isBooksOpen'] == true || map['isBooksOpen'] == null,
      location: map['location']?.toString() ??
          studioInfo?.displayLocation ??
          map['city']?.toString() ??
          '',
      studioType: map['studioType']?.toString() ??
          studioInfo?.studioType ??
          'Private Studio',
      isPrivateStudio: map['isPrivateStudio'] == true ||
          (studioInfo?.isPrivateStudio ?? false),
      distance: map['distance']?.toString() ?? '',
      latitude: parsedLat,
      longitude: parsedLng,
      profileCompleted: map['profileCompleted'] == true,
      rating: (map['rating'] is num) ? (map['rating'] as num).toDouble() : 5.0,
      availablePieces: (map['availablePieces'] is num)
          ? (map['availablePieces'] as num).toInt()
          : bookableCount,
      minDeposit: (map['minDeposit'] is num) ? (map['minDeposit'] as num).toInt() : 100,
      images: images,
      isFavorited: map['isFavorited'] == true,
      tags: tags,
      flashArtworks: flashArtworks,
      bio: map['bio']?.toString() ?? '',
      funFacts: funFacts ?? MockFixtures.defaultFunFacts,
      policies: policies ?? MockFixtures.defaultStudioPolicies,
      isVerifiedStudio: map['isVerifiedStudio'] != false,
      customRequestAvailable: map['customRequestAvailable'] != false,
      studioInformation: studioInfo,
    );
  }

  /// Quarantined fixture forwarder retained for unit/widget test compatibility.
  static const List<Artist> mockArtists = MockFixtures.artists;
}
