class GooglePlacePrediction {
  final String placeId;
  final String primaryText;
  final String secondaryText;
  final String fullText;
  final List<String> types;

  const GooglePlacePrediction({
    required this.placeId,
    required this.primaryText,
    required this.secondaryText,
    required this.fullText,
    this.types = const [],
  });

  factory GooglePlacePrediction.fromJson(Map<String, dynamic> json) {
    final structured = json['structured_formatting'] as Map<String, dynamic>?;
    final rawTypes = json['types'] as List<dynamic>? ?? const [];
    return GooglePlacePrediction(
      placeId: json['place_id']?.toString() ?? '',
      primaryText: structured?['main_text']?.toString() ??
          json['description']?.toString() ??
          '',
      secondaryText: structured?['secondary_text']?.toString() ?? '',
      fullText: json['description']?.toString() ?? '',
      types: rawTypes.map((e) => e.toString()).toList(growable: false),
    );
  }

  factory GooglePlacePrediction.fromV1Json(Map<String, dynamic> json) {
    final placePrediction =
        (json['placePrediction'] as Map<String, dynamic>?) ?? json;
    final structured =
        placePrediction['structuredFormat'] as Map<String, dynamic>?;
    final mainTextObj = structured?['mainText'] as Map<String, dynamic>?;
    final secondaryTextObj =
        structured?['secondaryText'] as Map<String, dynamic>?;
    final fullTextObj = placePrediction['text'] as Map<String, dynamic>?;
    final rawTypes = placePrediction['types'] as List<dynamic>? ?? const [];

    final fullText = fullTextObj?['text']?.toString() ?? '';
    return GooglePlacePrediction(
      placeId: placePrediction['placeId']?.toString() ?? '',
      primaryText: mainTextObj?['text']?.toString() ?? fullText,
      secondaryText: secondaryTextObj?['text']?.toString() ?? '',
      fullText: fullText,
      types: rawTypes.map((e) => e.toString()).toList(growable: false),
    );
  }
}

class GooglePlaceReview {
  final String authorName;
  final String? authorPhotoUrl;
  final double rating;
  final String relativeTimeDescription;
  final String text;

  const GooglePlaceReview({
    required this.authorName,
    this.authorPhotoUrl,
    required this.rating,
    required this.relativeTimeDescription,
    required this.text,
  });

  factory GooglePlaceReview.fromLegacyJson(Map<String, dynamic> json) {
    return GooglePlaceReview(
      authorName: json['author_name']?.toString() ?? 'Client',
      authorPhotoUrl: json['profile_photo_url']?.toString(),
      rating: (json['rating'] is num)
          ? (json['rating'] as num).toDouble()
          : 5.0,
      relativeTimeDescription:
          json['relative_time_description']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
    );
  }

  factory GooglePlaceReview.fromV1Json(Map<String, dynamic> json) {
    final authorAttr =
        json['authorAttribution'] as Map<String, dynamic>?;
    final textObj = json['text'] as Map<String, dynamic>?;
    return GooglePlaceReview(
      authorName: authorAttr?['displayName']?.toString() ?? 'Client',
      authorPhotoUrl: authorAttr?['photoUri']?.toString(),
      rating: (json['rating'] is num)
          ? (json['rating'] as num).toDouble()
          : 5.0,
      relativeTimeDescription:
          json['relativePublishTimeDescription']?.toString() ?? '',
      text: textObj?['text']?.toString() ?? '',
    );
  }
}

class GooglePlaceStudioSummary {
  final String placeId;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final double? rating;
  final int? userRatingsTotal;
  final bool? openNow;
  final String? photoReference;
  final String? businessStatus;
  final String? primaryType;
  final List<String> types;

  const GooglePlaceStudioSummary({
    required this.placeId,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.rating,
    this.userRatingsTotal,
    this.openNow,
    this.photoReference,
    this.businessStatus,
    this.primaryType,
    this.types = const [],
  });

  static GooglePlaceStudioSummary? tryFromLegacyJson(
    Map<String, dynamic> json,
  ) {
    final placeId = json['place_id']?.toString() ?? '';
    final geometry = json['geometry'] as Map<String, dynamic>?;
    final location = geometry?['location'] as Map<String, dynamic>?;
    final lat = (location?['lat'] is num)
        ? (location!['lat'] as num).toDouble()
        : null;
    final lng = (location?['lng'] is num)
        ? (location!['lng'] as num).toDouble()
        : null;
    if (placeId.isEmpty || lat == null || lng == null) return null;

    final openingHours = json['opening_hours'] as Map<String, dynamic>?;
    final photos = json['photos'] as List<dynamic>?;
    String? photoRef;
    if (photos != null && photos.isNotEmpty && photos.first is Map) {
      photoRef = (photos.first as Map)['photo_reference']?.toString();
    }

    final rawTypes = json['types'] as List<dynamic>? ?? const [];

    return GooglePlaceStudioSummary(
      placeId: placeId,
      name: json['name']?.toString() ?? 'Tattoo Studio',
      address: json['vicinity']?.toString() ??
          json['formatted_address']?.toString() ??
          '',
      latitude: lat,
      longitude: lng,
      rating: (json['rating'] is num)
          ? (json['rating'] as num).toDouble()
          : null,
      userRatingsTotal: (json['user_ratings_total'] is num)
          ? (json['user_ratings_total'] as num).toInt()
          : null,
      openNow: openingHours?['open_now'] is bool
          ? openingHours!['open_now'] as bool
          : null,
      photoReference: photoRef,
      businessStatus: json['business_status']?.toString(),
      types: rawTypes.map((e) => e.toString()).toList(growable: false),
    );
  }

  static GooglePlaceStudioSummary? tryFromV1Json(
    Map<String, dynamic> json,
  ) {
    final placeId = json['id']?.toString() ?? '';
    final location = json['location'] as Map<String, dynamic>?;
    final lat = (location?['latitude'] is num)
        ? (location!['latitude'] as num).toDouble()
        : null;
    final lng = (location?['longitude'] is num)
        ? (location!['longitude'] as num).toDouble()
        : null;
    if (placeId.isEmpty || lat == null || lng == null) return null;

    final displayName = json['displayName'] as Map<String, dynamic>?;
    final openingHours =
        json['currentOpeningHours'] as Map<String, dynamic>? ??
            json['regularOpeningHours'] as Map<String, dynamic>?;
    final photos = json['photos'] as List<dynamic>?;
    String? photoRef;
    if (photos != null && photos.isNotEmpty && photos.first is Map) {
      photoRef = (photos.first as Map)['name']?.toString();
    }

    final rawTypes = json['types'] as List<dynamic>? ?? const [];

    return GooglePlaceStudioSummary(
      placeId: placeId,
      name: displayName?['text']?.toString() ?? 'Tattoo Studio',
      address: json['shortFormattedAddress']?.toString() ??
          json['formattedAddress']?.toString() ??
          '',
      latitude: lat,
      longitude: lng,
      rating: (json['rating'] is num)
          ? (json['rating'] as num).toDouble()
          : null,
      userRatingsTotal: (json['userRatingCount'] is num)
          ? (json['userRatingCount'] as num).toInt()
          : null,
      openNow: openingHours?['openNow'] is bool
          ? openingHours!['openNow'] as bool
          : null,
      photoReference: photoRef,
      businessStatus: json['businessStatus']?.toString(),
      primaryType: json['primaryType']?.toString(),
      types: rawTypes.map((e) => e.toString()).toList(growable: false),
    );
  }
}

class GooglePlaceStudioDetails {
  final String placeId;
  final String name;
  final String formattedAddress;
  final String? formattedPhoneNumber;
  final String? websiteUri;
  final String? googleMapsUri;
  final double? latitude;
  final double? longitude;
  final double? rating;
  final int userRatingsTotal;
  final bool? openNow;
  final List<String> weekdayDescriptions;
  final List<String> photoReferences;
  final List<GooglePlaceReview> reviews;
  final String? editorialSummary;
  final String? primaryType;
  final List<String> types;

  const GooglePlaceStudioDetails({
    required this.placeId,
    required this.name,
    required this.formattedAddress,
    this.formattedPhoneNumber,
    this.websiteUri,
    this.googleMapsUri,
    this.latitude,
    this.longitude,
    this.rating,
    this.userRatingsTotal = 0,
    this.openNow,
    this.weekdayDescriptions = const [],
    this.photoReferences = const [],
    this.reviews = const [],
    this.editorialSummary,
    this.primaryType,
    this.types = const [],
  });

  factory GooglePlaceStudioDetails.fromLegacyJson(
    String placeId,
    Map<String, dynamic> result,
  ) {
    final geometry = result['geometry'] as Map<String, dynamic>?;
    final location = geometry?['location'] as Map<String, dynamic>?;
    final openingHours = result['opening_hours'] as Map<String, dynamic>?;
    final weekdayText = openingHours?['weekday_text'] as List<dynamic>? ?? [];
    final photos = result['photos'] as List<dynamic>? ?? [];
    final rawReviews = result['reviews'] as List<dynamic>? ?? [];
    final editorial = result['editorial_summary'] as Map<String, dynamic>?;
    final rawTypes = result['types'] as List<dynamic>? ?? const [];

    return GooglePlaceStudioDetails(
      placeId: placeId,
      name: result['name']?.toString() ?? 'Tattoo Studio',
      formattedAddress: result['formatted_address']?.toString() ?? '',
      formattedPhoneNumber: result['formatted_phone_number']?.toString() ??
          result['international_phone_number']?.toString(),
      websiteUri: result['website']?.toString(),
      googleMapsUri: result['url']?.toString(),
      latitude: (location?['lat'] is num)
          ? (location!['lat'] as num).toDouble()
          : null,
      longitude: (location?['lng'] is num)
          ? (location!['lng'] as num).toDouble()
          : null,
      rating: (result['rating'] is num)
          ? (result['rating'] as num).toDouble()
          : null,
      userRatingsTotal: (result['user_ratings_total'] is num)
          ? (result['user_ratings_total'] as num).toInt()
          : 0,
      openNow: openingHours?['open_now'] is bool
          ? openingHours!['open_now'] as bool
          : null,
      weekdayDescriptions:
          weekdayText.map((e) => e.toString()).toList(growable: false),
      photoReferences: photos
          .whereType<Map>()
          .map((p) => p['photo_reference']?.toString() ?? '')
          .where((ref) => ref.isNotEmpty)
          .toList(growable: false),
      reviews: rawReviews
          .whereType<Map>()
          .map(
            (r) => GooglePlaceReview.fromLegacyJson(
              Map<String, dynamic>.from(r),
            ),
          )
          .toList(growable: false),
      editorialSummary: editorial?['overview']?.toString(),
      types: rawTypes.map((e) => e.toString()).toList(growable: false),
    );
  }

  factory GooglePlaceStudioDetails.fromV1Json(
    Map<String, dynamic> json, {
    String? fallbackPlaceId,
  }) {
    final displayName = json['displayName'] as Map<String, dynamic>?;
    final location = json['location'] as Map<String, dynamic>?;
    final currentHours =
        json['currentOpeningHours'] as Map<String, dynamic>?;
    final regularHours =
        json['regularOpeningHours'] as Map<String, dynamic>?;
    final weekdayText =
        (regularHours?['weekdayDescriptions'] as List<dynamic>?) ??
            (currentHours?['weekdayDescriptions'] as List<dynamic>?) ??
            const [];
    final photos = json['photos'] as List<dynamic>? ?? const [];
    final rawReviews = json['reviews'] as List<dynamic>? ?? const [];
    final editorial = json['editorialSummary'] as Map<String, dynamic>?;
    final rawTypes = json['types'] as List<dynamic>? ?? const [];

    return GooglePlaceStudioDetails(
      placeId: json['id']?.toString() ?? fallbackPlaceId ?? '',
      name: displayName?['text']?.toString() ?? 'Tattoo Studio',
      formattedAddress: json['formattedAddress']?.toString() ?? '',
      formattedPhoneNumber: json['nationalPhoneNumber']?.toString() ??
          json['internationalPhoneNumber']?.toString(),
      websiteUri: json['websiteUri']?.toString(),
      googleMapsUri: json['googleMapsUri']?.toString(),
      latitude: (location?['latitude'] is num)
          ? (location!['latitude'] as num).toDouble()
          : null,
      longitude: (location?['longitude'] is num)
          ? (location!['longitude'] as num).toDouble()
          : null,
      rating: (json['rating'] is num)
          ? (json['rating'] as num).toDouble()
          : null,
      userRatingsTotal: (json['userRatingCount'] is num)
          ? (json['userRatingCount'] as num).toInt()
          : 0,
      openNow: (currentHours?['openNow'] is bool)
          ? currentHours!['openNow'] as bool
          : (regularHours?['openNow'] is bool
              ? regularHours!['openNow'] as bool
              : null),
      weekdayDescriptions:
          weekdayText.map((e) => e.toString()).toList(growable: false),
      photoReferences: photos
          .whereType<Map>()
          .map((p) => p['name']?.toString() ?? '')
          .where((ref) => ref.isNotEmpty)
          .toList(growable: false),
      reviews: rawReviews
          .whereType<Map>()
          .map(
            (r) => GooglePlaceReview.fromV1Json(
              Map<String, dynamic>.from(r),
            ),
          )
          .toList(growable: false),
      editorialSummary: editorial?['text']?.toString(),
      primaryType: json['primaryType']?.toString(),
      types: rawTypes.map((e) => e.toString()).toList(growable: false),
    );
  }
}

class GooglePlacesApiKeyMissingException implements Exception {
  final String message;
  const GooglePlacesApiKeyMissingException([
    this.message = 'GOOGLE_PLACES_API_KEY is not configured in .env',
  ]);

  @override
  String toString() => 'GooglePlacesApiKeyMissingException: $message';
}
