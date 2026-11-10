import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/studio_information.dart';

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
      photoRef =
          (photos.first as Map)['photo_reference']?.toString();
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

class GooglePlacesService {
  /// Official Google Places Table A primary type for tattoo & body art studios.
  static const String kBodyArtServiceType = 'body_art_service';

  /// Positive Google Places category identifiers for tattoo shops.
  static const Set<String> tattooPlaceTypes = {
    'body_art_service',
    'tattoo_shop',
    'tattoo_parlor',
  };

  /// Non-tattoo commercial categories that must never be displayed in Flash.Ink
  /// unless the place also explicitly carries a [tattooPlaceTypes] classification.
  static const Set<String> excludedNonTattooTypes = {
    'restaurant',
    'cafe',
    'coffee_shop',
    'bar',
    'bakery',
    'meal_takeaway',
    'meal_delivery',
    'food',
    'grocery_or_supermarket',
    'supermarket',
    'convenience_store',
    'liquor_store',
    'lodging',
    'hotel',
    'motel',
    'hospital',
    'doctor',
    'dentist',
    'medical_lab',
    'skin_care_clinic',
    'pharmacy',
    'drugstore',
    'physiotherapist',
    'veterinary_care',
    'bank',
    'atm',
    'accounting',
    'insurance_agency',
    'real_estate_agency',
    'lawyer',
    'car_dealer',
    'car_rental',
    'car_repair',
    'car_wash',
    'gas_station',
    'parking',
    'transit_station',
    'subway_station',
    'train_station',
    'bus_station',
    'airport',
    'school',
    'primary_school',
    'secondary_school',
    'university',
    'church',
    'mosque',
    'synagogue',
    'hindu_temple',
    'gym',
    'fitness_center',
    'post_office',
    'hardware_store',
    'home_goods_store',
    'furniture_store',
    'electronics_store',
    'clothing_store',
    'shoe_store',
    'jewelry_store',
    'pet_store',
    'book_store',
    'florist',
    'laundry',
    'locksmith',
    'moving_company',
    'painter',
    'plumber',
    'roofing_contractor',
    'electrician',
    'movie_theater',
    'night_club',
    'stadium',
    'amusement_park',
    'park',
    'zoo',
    'nail_salon',
    'barber_shop',
  };

  /// Personal-care types occasionally assigned to older tattoo shops on Google Maps;
  /// permitted only when the shop name contains an explicit tattoo term.
  static const Set<String> _ambiguousPersonalCareTypes = {
    'beauty_salon',
    'hair_care',
    'hair_salon',
    'spa',
  };

  static final RegExp _unambiguousTattooRegex = RegExp(
    r'\b(tattoo\w*|tatuaje\w*|tatouage\w*|irezumi|tebori)\b',
    caseSensitive: false,
  );

  static final RegExp _broadTattooStudioRegex = RegExp(
    r'\b(tattoo\w*|tatuaje\w*|tatouage\w*|irezumi|tebori|body\s*art|ink|inked)\b',
    caseSensitive: false,
  );

  static final RegExp _nonTattooNoiseRegex = RegExp(
    r'\b(tattoo\s+removal|laser\s+removal|removery|laseraway|toner|cartridge\w*|printer\w*|printing|office\s+depot|staples|coffee|espresso|cafe|bistro|kitchen|grill|pizzeria)\b',
    caseSensitive: false,
  );

  final http.Client _client;
  final String? _explicitApiKey;

  GooglePlacesService({http.Client? client, String? apiKey})
      : _client = client ?? http.Client(),
        _explicitApiKey = apiKey;

  String? get apiKey {
    if (_explicitApiKey != null) {
      final trimmed = _explicitApiKey.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    try {
      final key = dotenv.env['GOOGLE_PLACES_API_KEY'] ??
          dotenv.env['GOOGLE_MAPS_API_KEY'];
      if (key != null && key.trim().isNotEmpty) {
        return key.trim();
      }
    } catch (_) {}
    return null;
  }

  bool get hasApiKey => apiKey != null && apiKey!.trim().isNotEmpty;

  /// Verifies whether a candidate Google Place represents an actual tattoo studio
  /// rather than an unrelated establishment (e.g. cafes, print/toner shops, salons, or removal clinics).
  static bool isTattooPlace({
    required String name,
    String? primaryType,
    Iterable<String> types = const [],
    String? businessStatus,
  }) {
    if (businessStatus != null &&
        businessStatus.toUpperCase() == 'CLOSED_PERMANENTLY') {
      return false;
    }

    final trimmedName = name.trim();
    if (trimmedName.isEmpty) return false;

    if (_nonTattooNoiseRegex.hasMatch(trimmedName)) {
      return false;
    }

    final normalizedTypes = <String>{
      if (primaryType != null && primaryType.trim().isNotEmpty)
        primaryType.trim().toLowerCase(),
      ...types.map((t) => t.trim().toLowerCase()).where((t) => t.isNotEmpty),
    };

    if (normalizedTypes.intersection(tattooPlaceTypes).isNotEmpty) {
      return true;
    }

    if (normalizedTypes.intersection(excludedNonTattooTypes).isNotEmpty) {
      return false;
    }

    if (normalizedTypes.intersection(_ambiguousPersonalCareTypes).isNotEmpty) {
      return _unambiguousTattooRegex.hasMatch(trimmedName);
    }

    return _broadTattooStudioRegex.hasMatch(trimmedName);
  }

  /// Verifies whether a [GooglePlaceStudioSummary] is a valid tattoo shop.
  static bool isTattooStudioSummary(GooglePlaceStudioSummary summary) {
    return isTattooPlace(
      name: summary.name,
      primaryType: summary.primaryType,
      types: summary.types,
      businessStatus: summary.businessStatus,
    );
  }

  /// Verifies whether an autocomplete [GooglePlacePrediction] represents a tattoo shop.
  static bool isTattooPrediction(GooglePlacePrediction prediction) {
    return isTattooPlace(
      name: prediction.primaryText.isNotEmpty
          ? prediction.primaryText
          : prediction.fullText,
      types: prediction.types,
    );
  }

  static String _ensureTattooSearchQuery(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return 'tattoo studio';
    if (_broadTattooStudioRegex.hasMatch(trimmed)) {
      return trimmed;
    }
    return '$trimmed tattoo studio';
  }

  String _requireApiKey() {
    final key = apiKey;
    if (key == null || key.trim().isEmpty) {
      throw const GooglePlacesApiKeyMissingException();
    }
    return key;
  }

  /// Constructs a displayable HTTP URL for either a legacy `photo_reference`
  /// or a Places API (New) photo resource name (`places/.../photos/...`).
  String? buildPhotoUrl(String? photoReference, {int maxWidth = 800}) {
    if (photoReference == null || photoReference.trim().isEmpty) return null;
    final ref = photoReference.trim();
    if (ref.startsWith('http://') || ref.startsWith('https://')) {
      return ref;
    }
    final key = apiKey;
    if (key == null || key.isEmpty) return null;

    if (ref.startsWith('places/')) {
      return Uri.https(
        'places.googleapis.com',
        '/v1/$ref/media',
        {
          'maxWidthPx': '$maxWidth',
          'key': key,
        },
      ).toString();
    }

    return Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/photo',
      {
        'maxwidth': '$maxWidth',
        'photo_reference': ref,
        'key': key,
      },
    ).toString();
  }

  /// Autocomplete tattoo studio search.
  /// Anchors legacy establishment queries to tattoo studios and restricts Places API (New)
  /// (`places:autocomplete`) to `includedPrimaryTypes: ["body_art_service"]`, filtering
  /// out any non-tattoo businesses.
  Future<List<GooglePlacePrediction>> searchStudios(
    String query, {
    bool tattooOnly = true,
  }) async {
    final queryText = query.trim();
    if (queryText.isEmpty) return const [];

    final key = _requireApiKey();
    final effectiveLegacyInput =
        (!tattooOnly || _broadTattooStudioRegex.hasMatch(queryText))
            ? queryText
            : '$queryText tattoo';

    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/autocomplete/json',
      {
        'input': effectiveLegacyInput,
        'types': 'establishment',
        'key': key,
      },
    );

    final response = await _client.get(uri);
    if (response.statusCode == 403) {
      return _searchStudiosV1(queryText, key, tattooOnly: tattooOnly);
    }
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch places: HTTP ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final status = data['status']?.toString();
    if (status == 'REQUEST_DENIED') {
      return _searchStudiosV1(queryText, key, tattooOnly: tattooOnly);
    }
    if (status != 'OK' && status != 'ZERO_RESULTS') {
      final errorMsg =
          data['error_message']?.toString() ?? status ?? 'Unknown error';
      throw Exception('Google Places API error: $errorMsg');
    }

    final predictions = data['predictions'] as List<dynamic>? ?? [];
    final parsed = predictions
        .whereType<Map<String, dynamic>>()
        .map((p) => GooglePlacePrediction.fromJson(p));
    return (tattooOnly ? parsed.where(isTattooPrediction) : parsed).toList();
  }

  Future<List<GooglePlacePrediction>> _searchStudiosV1(
    String queryText,
    String key, {
    bool tattooOnly = true,
  }) async {
    final uri = Uri.https('places.googleapis.com', '/v1/places:autocomplete');
    final body = <String, dynamic>{
      'input': queryText,
      if (tattooOnly) 'includedPrimaryTypes': [kBodyArtServiceType],
    };

    final response = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': key,
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to fetch places (v1): HTTP ${response.statusCode}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final suggestions = data['suggestions'] as List<dynamic>? ?? const [];
    final parsed = suggestions
        .whereType<Map>()
        .map(
          (s) => GooglePlacePrediction.fromV1Json(
            Map<String, dynamic>.from(s),
          ),
        )
        .where((p) => p.placeId.isNotEmpty);

    // When Google returns predictions explicitly constrained by includedPrimaryTypes: ["body_art_service"],
    // suggestions may not echo `types` even if their name doesn't contain "Tattoo" (e.g. "Shamrock Social Club").
    return parsed
        .where((p) {
          if (!tattooOnly) return true;
          if (_nonTattooNoiseRegex.hasMatch(p.primaryText)) return false;
          if (p.types.isEmpty) return true;
          return isTattooPrediction(p);
        })
        .toList();
  }

  /// Fetches detailed business info for a selected [placeId] and converts to [StudioInformation].
  Future<StudioInformation> getStudioDetails(
    String placeId, {
    String? fallbackName,
  }) async {
    final key = _requireApiKey();

    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/details/json',
      {
        'place_id': placeId,
        'fields': 'name,formatted_address,address_components,geometry',
        'key': key,
      },
    );

    final response = await _client.get(uri);
    if (response.statusCode == 403) {
      return _getStudioDetailsV1(placeId, key, fallbackName: fallbackName);
    }
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to fetch place details: HTTP ${response.statusCode}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final status = data['status']?.toString();
    if (status == 'REQUEST_DENIED') {
      return _getStudioDetailsV1(placeId, key, fallbackName: fallbackName);
    }
    if (status != 'OK') {
      final errorMsg =
          data['error_message']?.toString() ?? status ?? 'Unknown error';
      throw Exception('Google Place Details error: $errorMsg');
    }

    final result = data['result'] as Map<String, dynamic>? ?? {};
    final studioName =
        result['name']?.toString() ?? fallbackName ?? 'Tattoo Studio';
    final formattedAddress = result['formatted_address']?.toString() ?? '';

    String city = '';
    String state = '';
    String postalCode = '';

    final components = result['address_components'] as List<dynamic>? ?? [];
    for (final comp in components.whereType<Map<String, dynamic>>()) {
      final types = (comp['types'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [];
      if (types.contains('locality') ||
          types.contains('sublocality') ||
          types.contains('postal_town')) {
        if (city.isEmpty) {
          city = comp['long_name']?.toString() ?? '';
        }
      }
      if (types.contains('administrative_area_level_1')) {
        state = comp['short_name']?.toString() ??
            comp['long_name']?.toString() ??
            '';
      }
      if (types.contains('postal_code')) {
        postalCode = comp['long_name']?.toString() ?? '';
      }
    }

    double? lat;
    double? lng;
    final geometry = result['geometry'] as Map<String, dynamic>?;
    final location = geometry?['location'] as Map<String, dynamic>?;
    if (location != null) {
      lat = (location['lat'] is num)
          ? (location['lat'] as num).toDouble()
          : null;
      lng = (location['lng'] is num)
          ? (location['lng'] as num).toDouble()
          : null;
    }

    return StudioInformation(
      name: studioName,
      formattedAddress: formattedAddress,
      city: city,
      state: state,
      postalCode: postalCode,
      placeId: placeId,
      latitude: lat,
      longitude: lng,
      isPrivateStudio: false,
      studioType: 'Street Shop',
    );
  }

  Future<StudioInformation> _getStudioDetailsV1(
    String placeId,
    String key, {
    String? fallbackName,
  }) async {
    final uri = Uri.https('places.googleapis.com', '/v1/places/$placeId');
    final response = await _client.get(
      uri,
      headers: {
        'X-Goog-Api-Key': key,
        'X-Goog-FieldMask':
            'id,displayName,formattedAddress,addressComponents,location',
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to fetch place details (v1): HTTP ${response.statusCode}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final displayName = data['displayName'] as Map<String, dynamic>?;
    final studioName =
        displayName?['text']?.toString() ?? fallbackName ?? 'Tattoo Studio';
    final formattedAddress = data['formattedAddress']?.toString() ?? '';

    String city = '';
    String state = '';
    String postalCode = '';

    final components = data['addressComponents'] as List<dynamic>? ?? const [];
    for (final comp in components.whereType<Map>()) {
      final types = (comp['types'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [];
      if (types.contains('locality') ||
          types.contains('sublocality') ||
          types.contains('postal_town')) {
        if (city.isEmpty) {
          city = comp['longText']?.toString() ?? '';
        }
      }
      if (types.contains('administrative_area_level_1')) {
        state = comp['shortText']?.toString() ??
            comp['longText']?.toString() ??
            '';
      }
      if (types.contains('postal_code')) {
        postalCode = comp['longText']?.toString() ?? '';
      }
    }

    final location = data['location'] as Map<String, dynamic>?;
    final lat = (location?['latitude'] is num)
        ? (location!['latitude'] as num).toDouble()
        : null;
    final lng = (location?['longitude'] is num)
        ? (location!['longitude'] as num).toDouble()
        : null;

    return StudioInformation(
      name: studioName,
      formattedAddress: formattedAddress,
      city: city,
      state: state,
      postalCode: postalCode,
      placeId: placeId,
      latitude: lat,
      longitude: lng,
      isPrivateStudio: false,
      studioType: 'Street Shop',
    );
  }

  /// Discovers nearby tattoo studios around [latitude], [longitude] within [radiusMeters].
  /// Strictly returns verified tattoo/body-art studios.
  Future<List<GooglePlaceStudioSummary>> searchNearbyTattooStudios({
    required double latitude,
    required double longitude,
    double radiusMeters = 8000,
    String keyword = 'tattoo studio',
  }) async {
    final key = _requireApiKey();
    final effectiveKeyword = _ensureTattooSearchQuery(keyword);

    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/nearbysearch/json',
      {
        'location': '$latitude,$longitude',
        'radius': '${radiusMeters.round()}',
        'keyword': effectiveKeyword,
        'key': key,
      },
    );

    final response = await _client.get(uri);
    if (response.statusCode == 403) {
      return _searchTattooStudiosTextV1(
        textQuery: effectiveKeyword,
        key: key,
        latitude: latitude,
        longitude: longitude,
        radiusMeters: radiusMeters,
      );
    }
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to search nearby studios: HTTP ${response.statusCode}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final status = data['status']?.toString();
    if (status == 'REQUEST_DENIED') {
      return _searchTattooStudiosTextV1(
        textQuery: effectiveKeyword,
        key: key,
        latitude: latitude,
        longitude: longitude,
        radiusMeters: radiusMeters,
      );
    }
    if (status != 'OK' && status != 'ZERO_RESULTS') {
      final errorMsg =
          data['error_message']?.toString() ?? status ?? 'Unknown error';
      throw Exception('Google Nearby Search error: $errorMsg');
    }

    final results = data['results'] as List<dynamic>? ?? const [];
    return results
        .whereType<Map>()
        .map(
          (r) => GooglePlaceStudioSummary.tryFromLegacyJson(
            Map<String, dynamic>.from(r),
          ),
        )
        .whereType<GooglePlaceStudioSummary>()
        .where(isTattooStudioSummary)
        .toList(growable: false);
  }

  /// Performs a freeform text search strictly scoped to tattoo shops/studios
  /// (e.g. "fine line Brooklyn" -> "fine line Brooklyn tattoo studio").
  Future<List<GooglePlaceStudioSummary>> searchTattooStudiosByText(
    String query, {
    double? latitude,
    double? longitude,
    double radiusMeters = 15000,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    final key = _requireApiKey();
    final effectiveQuery = _ensureTattooSearchQuery(trimmed);

    final params = <String, String>{
      'query': effectiveQuery,
      'key': key,
      if (latitude != null && longitude != null)
        'location': '$latitude,$longitude',
      if (latitude != null && longitude != null)
        'radius': '${radiusMeters.round()}',
    };

    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/textsearch/json',
      params,
    );

    final response = await _client.get(uri);
    if (response.statusCode == 403) {
      return _searchTattooStudiosTextV1(
        textQuery: effectiveQuery,
        key: key,
        latitude: latitude,
        longitude: longitude,
        radiusMeters: radiusMeters,
      );
    }
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to text-search studios: HTTP ${response.statusCode}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final status = data['status']?.toString();
    if (status == 'REQUEST_DENIED') {
      return _searchTattooStudiosTextV1(
        textQuery: effectiveQuery,
        key: key,
        latitude: latitude,
        longitude: longitude,
        radiusMeters: radiusMeters,
      );
    }
    if (status != 'OK' && status != 'ZERO_RESULTS') {
      final errorMsg =
          data['error_message']?.toString() ?? status ?? 'Unknown error';
      throw Exception('Google Text Search error: $errorMsg');
    }

    final results = data['results'] as List<dynamic>? ?? const [];
    return results
        .whereType<Map>()
        .map(
          (r) => GooglePlaceStudioSummary.tryFromLegacyJson(
            Map<String, dynamic>.from(r),
          ),
        )
        .whereType<GooglePlaceStudioSummary>()
        .where(isTattooStudioSummary)
        .toList(growable: false);
  }

  Future<List<GooglePlaceStudioSummary>> _searchTattooStudiosTextV1({
    required String textQuery,
    required String key,
    double? latitude,
    double? longitude,
    double radiusMeters = 8000,
  }) async {
    final uri = Uri.https('places.googleapis.com', '/v1/places:searchText');
    final body = <String, dynamic>{
      'textQuery': _ensureTattooSearchQuery(textQuery),
      'includedType': kBodyArtServiceType,
      'strictTypeFiltering': false,
      'maxResultCount': 20,
      if (latitude != null && longitude != null)
        'locationBias': {
          'circle': {
            'center': {
              'latitude': latitude,
              'longitude': longitude,
            },
            'radius': radiusMeters.clamp(500.0, 50000.0),
          },
        },
    };

    final response = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': key,
        'X-Goog-FieldMask':
            'places.id,places.displayName,places.formattedAddress,places.shortFormattedAddress,places.location,places.rating,places.userRatingCount,places.currentOpeningHours,places.photos,places.businessStatus,places.primaryType,places.types',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to search studios (v1): HTTP ${response.statusCode}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final places = data['places'] as List<dynamic>? ?? const [];
    return places
        .whereType<Map>()
        .map(
          (p) => GooglePlaceStudioSummary.tryFromV1Json(
            Map<String, dynamic>.from(p),
          ),
        )
        .whereType<GooglePlaceStudioSummary>()
        .where(isTattooStudioSummary)
        .toList(growable: false);
  }

  /// Fetches rich Google Place Details (ratings, reviews, hours, photos, phone, website)
  /// for rendering inside `StudioPlaceDetailsSheet`.
  Future<GooglePlaceStudioDetails> getRichPlaceDetails(String placeId) async {
    final trimmedId = placeId.trim();
    if (trimmedId.isEmpty) {
      throw ArgumentError('placeId must not be empty');
    }

    final key = _requireApiKey();

    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/details/json',
      {
        'place_id': trimmedId,
        'fields':
            'name,formatted_address,formatted_phone_number,international_phone_number,website,url,geometry,rating,user_ratings_total,opening_hours,photos,reviews,editorial_summary,types',
        'key': key,
      },
    );

    final response = await _client.get(uri);
    if (response.statusCode == 403) {
      return _getRichPlaceDetailsV1(trimmedId, key);
    }
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to fetch rich place details: HTTP ${response.statusCode}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final status = data['status']?.toString();
    if (status == 'REQUEST_DENIED') {
      return _getRichPlaceDetailsV1(trimmedId, key);
    }
    if (status != 'OK') {
      final errorMsg =
          data['error_message']?.toString() ?? status ?? 'Unknown error';
      throw Exception('Google Place Details error: $errorMsg');
    }

    final result = data['result'] as Map<String, dynamic>? ?? {};
    return GooglePlaceStudioDetails.fromLegacyJson(trimmedId, result);
  }

  Future<GooglePlaceStudioDetails> _getRichPlaceDetailsV1(
    String placeId,
    String key,
  ) async {
    final uri = Uri.https('places.googleapis.com', '/v1/places/$placeId');
    final response = await _client.get(
      uri,
      headers: {
        'X-Goog-Api-Key': key,
        'X-Goog-FieldMask':
            'id,displayName,formattedAddress,nationalPhoneNumber,internationalPhoneNumber,websiteUri,googleMapsUri,location,rating,userRatingCount,currentOpeningHours,regularOpeningHours,photos,reviews,editorialSummary,primaryType,types',
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to fetch rich place details (v1): HTTP ${response.statusCode}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return GooglePlaceStudioDetails.fromV1Json(
      data,
      fallbackPlaceId: placeId,
    );
  }

  void dispose() {
    _client.close();
  }
}
