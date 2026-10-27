import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/studio_information.dart';

class GooglePlacePrediction {
  final String placeId;
  final String primaryText;
  final String secondaryText;
  final String fullText;

  const GooglePlacePrediction({
    required this.placeId,
    required this.primaryText,
    required this.secondaryText,
    required this.fullText,
  });

  factory GooglePlacePrediction.fromJson(Map<String, dynamic> json) {
    final structured = json['structured_formatting'] as Map<String, dynamic>?;
    return GooglePlacePrediction(
      placeId: json['place_id']?.toString() ?? '',
      primaryText: structured?['main_text']?.toString() ??
          json['description']?.toString() ??
          '',
      secondaryText: structured?['secondary_text']?.toString() ?? '',
      fullText: json['description']?.toString() ?? '',
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
  final http.Client _client;
  final String? _explicitApiKey;

  GooglePlacesService({http.Client? client, String? apiKey})
      : _client = client ?? http.Client(),
        _explicitApiKey = apiKey;

  String? get apiKey {
    if (_explicitApiKey != null && _explicitApiKey.isNotEmpty) {
      return _explicitApiKey;
    }
    try {
      final key = dotenv.env['GOOGLE_PLACES_API_KEY'];
      if (key != null && key.isNotEmpty) {
        return key;
      }
    } catch (_) {}
    return null;
  }

  bool get hasApiKey => apiKey != null && apiKey!.trim().isNotEmpty;

  /// Autocomplete studio / business search
  Future<List<GooglePlacePrediction>> searchStudios(String query) async {
    final queryText = query.trim();
    if (queryText.isEmpty) return const [];

    final key = apiKey;
    if (key == null || key.trim().isEmpty) {
      throw const GooglePlacesApiKeyMissingException();
    }

    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/autocomplete/json',
      {
        'input': queryText,
        'types': 'establishment',
        'key': key,
      },
    );

    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch places: HTTP ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final status = data['status']?.toString();
    if (status != 'OK' && status != 'ZERO_RESULTS') {
      final errorMsg = data['error_message']?.toString() ?? status ?? 'Unknown error';
      throw Exception('Google Places API error: $errorMsg');
    }

    final predictions = data['predictions'] as List<dynamic>? ?? [];
    return predictions
        .whereType<Map<String, dynamic>>()
        .map((p) => GooglePlacePrediction.fromJson(p))
        .toList();
  }

  /// Fetches detailed business info for a selected placeId and converts to [StudioInformation].
  Future<StudioInformation> getStudioDetails(
    String placeId, {
    String? fallbackName,
  }) async {
    final key = apiKey;
    if (key == null || key.trim().isEmpty) {
      throw const GooglePlacesApiKeyMissingException();
    }

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
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch place details: HTTP ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final status = data['status']?.toString();
    if (status != 'OK') {
      final errorMsg = data['error_message']?.toString() ?? status ?? 'Unknown error';
      throw Exception('Google Place Details error: $errorMsg');
    }

    final result = data['result'] as Map<String, dynamic>? ?? {};
    final studioName = result['name']?.toString() ?? fallbackName ?? 'Tattoo Studio';
    final formattedAddress = result['formatted_address']?.toString() ?? '';

    String city = '';
    String state = '';
    String postalCode = '';

    final components = result['address_components'] as List<dynamic>? ?? [];
    for (final comp in components.whereType<Map<String, dynamic>>()) {
      final types = (comp['types'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
      if (types.contains('locality') || types.contains('sublocality') || types.contains('postal_town')) {
        if (city.isEmpty) {
          city = comp['long_name']?.toString() ?? '';
        }
      }
      if (types.contains('administrative_area_level_1')) {
        state = comp['short_name']?.toString() ?? comp['long_name']?.toString() ?? '';
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
      lat = (location['lat'] is num) ? (location['lat'] as num).toDouble() : null;
      lng = (location['lng'] is num) ? (location['lng'] as num).toDouble() : null;
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

  void dispose() {
    _client.close();
  }
}
