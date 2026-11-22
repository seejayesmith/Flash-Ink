import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/google_place_models.dart';
import '../models/studio_information.dart';
import 'places/tattoo_place_classifier.dart';

class GooglePlacesService {
  static const String kBodyArtServiceType =
      TattooPlaceClassifier.kBodyArtServiceType;

  static const Set<String> tattooPlaceTypes =
      TattooPlaceClassifier.tattooPlaceTypes;

  static const Set<String> excludedNonTattooTypes =
      TattooPlaceClassifier.excludedNonTattooTypes;

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

  static bool isTattooPlace({
    required String name,
    String? primaryType,
    Iterable<String> types = const [],
    String? businessStatus,
  }) =>
      TattooPlaceClassifier.isTattooPlace(
        name: name,
        primaryType: primaryType,
        types: types,
        businessStatus: businessStatus,
      );

  static bool isTattooStudioSummary(GooglePlaceStudioSummary summary) =>
      TattooPlaceClassifier.isTattooStudioSummary(summary);

  static bool isTattooPrediction(GooglePlacePrediction prediction) =>
      TattooPlaceClassifier.isTattooPrediction(prediction);

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

  static ({String city, String state, String postalCode}) _parseAddressParts(
    List<dynamic> components, {
    required String longKey,
    required String shortKey,
  }) {
    String city = '';
    String state = '';
    String postalCode = '';

    for (final comp in components.whereType<Map>()) {
      final types = (comp['types'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [];
      if (types.contains('locality') ||
          types.contains('sublocality') ||
          types.contains('postal_town')) {
        if (city.isEmpty) {
          city = comp[longKey]?.toString() ?? '';
        }
      }
      if (types.contains('administrative_area_level_1')) {
        state = comp[shortKey]?.toString() ?? comp[longKey]?.toString() ?? '';
      }
      if (types.contains('postal_code')) {
        postalCode = comp[longKey]?.toString() ?? '';
      }
    }

    return (city: city, state: state, postalCode: postalCode);
  }

  /// Autocomplete tattoo studio search.
  Future<List<GooglePlacePrediction>> searchStudios(
    String query, {
    bool tattooOnly = true,
  }) async {
    final queryText = query.trim();
    if (queryText.isEmpty) return const [];

    final key = _requireApiKey();
    final effectiveLegacyInput = (!tattooOnly ||
            TattooPlaceClassifier.broadTattooStudioRegex.hasMatch(queryText))
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

    return parsed
        .where((p) {
          if (!tattooOnly) return true;
          if (TattooPlaceClassifier.nonTattooNoiseRegex
              .hasMatch(p.primaryText)) {
            return false;
          }
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
    final addressParts = _parseAddressParts(
      result['address_components'] as List<dynamic>? ?? const [],
      longKey: 'long_name',
      shortKey: 'short_name',
    );

    final geometry = result['geometry'] as Map<String, dynamic>?;
    final location = geometry?['location'] as Map<String, dynamic>?;
    final lat = (location?['lat'] is num)
        ? (location!['lat'] as num).toDouble()
        : null;
    final lng = (location?['lng'] is num)
        ? (location!['lng'] as num).toDouble()
        : null;

    return StudioInformation(
      name: studioName,
      formattedAddress: formattedAddress,
      city: addressParts.city,
      state: addressParts.state,
      postalCode: addressParts.postalCode,
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
    final addressParts = _parseAddressParts(
      data['addressComponents'] as List<dynamic>? ?? const [],
      longKey: 'longText',
      shortKey: 'shortText',
    );

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
      city: addressParts.city,
      state: addressParts.state,
      postalCode: addressParts.postalCode,
      placeId: placeId,
      latitude: lat,
      longitude: lng,
      isPrivateStudio: false,
      studioType: 'Street Shop',
    );
  }

  /// Discovers nearby tattoo studios around [latitude], [longitude] within [radiusMeters].
  Future<List<GooglePlaceStudioSummary>> searchNearbyTattooStudios({
    required double latitude,
    required double longitude,
    double radiusMeters = 8000,
    String keyword = 'tattoo studio',
  }) async {
    final key = _requireApiKey();
    final effectiveKeyword =
        TattooPlaceClassifier.ensureTattooSearchQuery(keyword);

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

  /// Performs a freeform text search strictly scoped to tattoo shops/studios.
  Future<List<GooglePlaceStudioSummary>> searchTattooStudiosByText(
    String query, {
    double? latitude,
    double? longitude,
    double radiusMeters = 15000,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    final key = _requireApiKey();
    final effectiveQuery =
        TattooPlaceClassifier.ensureTattooSearchQuery(trimmed);

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
      'textQuery': TattooPlaceClassifier.ensureTattooSearchQuery(textQuery),
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

  /// Fetches rich Google Place Details for rendering inside `StudioPlaceDetailsSheet`.
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
