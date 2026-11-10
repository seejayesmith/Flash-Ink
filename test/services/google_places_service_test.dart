import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flash_ink/services/google_places_service.dart';

void main() {
  group('GooglePlacesService Tests', () {
    test('Throws GooglePlacesApiKeyMissingException if no API key is provided', () async {
      final service = GooglePlacesService(apiKey: '');
      expect(service.hasApiKey, isFalse);

      expect(
        () => service.searchStudios('Tattoo'),
        throwsA(isA<GooglePlacesApiKeyMissingException>()),
      );
      expect(
        () => service.getStudioDetails('place_123'),
        throwsA(isA<GooglePlacesApiKeyMissingException>()),
      );
    });

    test('Returns empty list when search query is empty or whitespace', () async {
      final service = GooglePlacesService(apiKey: 'fake_key');
      final result = await service.searchStudios('   ');
      expect(result, isEmpty);
    });

    test('Parses autocomplete predictions correctly', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/maps/api/place/autocomplete/json');
        expect(request.url.queryParameters['input'], 'Rose Tattoo');
        expect(request.url.queryParameters['key'], 'test_api_key');

        final responseJson = {
          'status': 'OK',
          'predictions': [
            {
              'place_id': 'place_rose_1',
              'description': 'Rose Water Tattoo, Portland, OR, USA',
              'structured_formatting': {
                'main_text': 'Rose Water Tattoo',
                'secondary_text': 'Portland, OR, USA',
              },
            },
            {
              'place_id': 'place_rose_2',
              'description': 'Black Rose Tattoo, Seattle, WA, USA',
              'structured_formatting': {
                'main_text': 'Black Rose Tattoo',
                'secondary_text': 'Seattle, WA, USA',
              },
            },
          ],
        };

        return http.Response(jsonEncode(responseJson), 200, headers: {'content-type': 'application/json'});
      });

      final service = GooglePlacesService(client: mockClient, apiKey: 'test_api_key');
      final predictions = await service.searchStudios('Rose Tattoo');

      expect(predictions.length, 2);
      expect(predictions[0].placeId, 'place_rose_1');
      expect(predictions[0].primaryText, 'Rose Water Tattoo');
      expect(predictions[0].secondaryText, 'Portland, OR, USA');
      expect(predictions[0].fullText, 'Rose Water Tattoo, Portland, OR, USA');

      expect(predictions[1].placeId, 'place_rose_2');
      expect(predictions[1].primaryText, 'Black Rose Tattoo');
    });

    test('Parses place details into StudioInformation correctly', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/maps/api/place/details/json');
        expect(request.url.queryParameters['place_id'], 'place_rose_1');
        expect(request.url.queryParameters['key'], 'test_api_key');

        final responseJson = {
          'status': 'OK',
          'result': {
            'name': 'Rose Water Tattoo',
            'formatted_address': '123 SE Hawthorne Blvd, Portland, OR 97214, USA',
            'address_components': [
              {
                'long_name': 'Portland',
                'short_name': 'Portland',
                'types': ['locality', 'political'],
              },
              {
                'long_name': 'Oregon',
                'short_name': 'OR',
                'types': ['administrative_area_level_1', 'political'],
              },
              {
                'long_name': '97214',
                'short_name': '97214',
                'types': ['postal_code'],
              },
            ],
            'geometry': {
              'location': {
                'lat': 45.5152,
                'lng': -122.6543,
              },
            },
          },
        };

        return http.Response(jsonEncode(responseJson), 200, headers: {'content-type': 'application/json'});
      });

      final service = GooglePlacesService(client: mockClient, apiKey: 'test_api_key');
      final studio = await service.getStudioDetails('place_rose_1');

      expect(studio.name, 'Rose Water Tattoo');
      expect(studio.formattedAddress, '123 SE Hawthorne Blvd, Portland, OR 97214, USA');
      expect(studio.city, 'Portland');
      expect(studio.state, 'OR');
      expect(studio.postalCode, '97214');
      expect(studio.latitude, 45.5152);
      expect(studio.longitude, -122.6543);
      expect(studio.displayLocation, 'Portland, OR');
      expect(studio.isPrivateStudio, isFalse);
    });

    test('Searches nearby tattoo studios and falls back to Places API v1 when legacy is REQUEST_DENIED', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/maps/api/place/nearbysearch/json') {
          return http.Response(
            jsonEncode({
              'status': 'REQUEST_DENIED',
              'error_message': 'Legacy Places API is not enabled.',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.host == 'places.googleapis.com' &&
            request.url.path == '/v1/places:searchText') {
          expect(request.headers['X-Goog-Api-Key'], 'test_api_key');
          return http.Response(
            jsonEncode({
              'places': [
                {
                  'id': 'place_v1_ink',
                  'displayName': {'text': 'Electric Gold Tattoo'},
                  'shortFormattedAddress': '742 Abbot Kinney Blvd, Venice, CA',
                  'location': {'latitude': 33.9911, 'longitude': -118.4695},
                  'rating': 4.9,
                  'userRatingCount': 210,
                  'currentOpeningHours': {'openNow': true},
                  'photos': [
                    {'name': 'places/place_v1_ink/photos/photo_abc'},
                  ],
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final service = GooglePlacesService(
        client: mockClient,
        apiKey: 'test_api_key',
      );
      final nearby = await service.searchNearbyTattooStudios(
        latitude: 33.99,
        longitude: -118.47,
      );

      expect(nearby.length, 1);
      expect(nearby.first.placeId, 'place_v1_ink');
      expect(nearby.first.name, 'Electric Gold Tattoo');
      expect(nearby.first.rating, 4.9);
      expect(nearby.first.userRatingsTotal, 210);
      expect(nearby.first.openNow, isTrue);

      final v1PhotoUrl = service.buildPhotoUrl(nearby.first.photoReference);
      expect(v1PhotoUrl, contains('places.googleapis.com/v1/places/place_v1_ink/photos/photo_abc/media'));

      final legacyPhotoUrl = service.buildPhotoUrl('legacy_ref_xyz');
      expect(legacyPhotoUrl, contains('maps.googleapis.com/maps/api/place/photo'));
    });

    test('Parses getRichPlaceDetails hours, contact info, and reviews', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/maps/api/place/details/json');
        return http.Response(
          jsonEncode({
            'status': 'OK',
            'result': {
              'name': 'Obsidian Needle Collective',
              'formatted_address': '450 Valencia St, San Francisco, CA 94103',
              'formatted_phone_number': '(415) 555-0192',
              'website': 'https://obsidianneedle.example.com',
              'rating': 4.95,
              'user_ratings_total': 128,
              'opening_hours': {
                'open_now': true,
                'weekday_text': [
                  'Monday: 12:00 – 8:00 PM',
                  'Tuesday: 12:00 – 8:00 PM',
                ],
              },
              'photos': [
                {'photo_reference': 'photo_1'},
              ],
              'reviews': [
                {
                  'author_name': 'Maya R.',
                  'rating': 5,
                  'relative_time_description': '2 weeks ago',
                  'text': 'Incredible blackwork flash and spotless studio!',
                },
              ],
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = GooglePlacesService(
        client: mockClient,
        apiKey: 'test_api_key',
      );
      final details = await service.getRichPlaceDetails('place_sf_1');

      expect(details.name, 'Obsidian Needle Collective');
      expect(details.formattedPhoneNumber, '(415) 555-0192');
      expect(details.websiteUri, 'https://obsidianneedle.example.com');
      expect(details.openNow, isTrue);
      expect(details.weekdayDescriptions.length, 2);
      expect(details.reviews.length, 1);
      expect(details.reviews.first.authorName, 'Maya R.');
    });

    test('Strictly filters out non-tattoo businesses across nearby search, autocomplete, and classifier', () async {
      // 1. Direct classifier verification across real-world false positives
      expect(
        GooglePlacesService.isTattooPlace(
          name: 'Shamrock Social Club',
          primaryType: 'body_art_service',
          types: ['body_art_service', 'establishment'],
        ),
        isTrue,
      );
      expect(
        GooglePlacesService.isTattooPlace(
          name: 'Black Ink Coffee',
          types: ['cafe', 'food', 'establishment'],
        ),
        isFalse,
      );
      expect(
        GooglePlacesService.isTattooPlace(
          name: 'Tattooed Mom',
          types: ['bar', 'restaurant', 'establishment'],
        ),
        isFalse,
      );
      expect(
        GooglePlacesService.isTattooPlace(
          name: 'Cartridge World Ink & Toner',
          types: ['store', 'establishment'],
        ),
        isFalse,
      );
      expect(
        GooglePlacesService.isTattooPlace(
          name: 'Glow Beauty Salon',
          types: ['beauty_salon', 'establishment'],
        ),
        isFalse,
      );
      expect(
        GooglePlacesService.isTattooPlace(
          name: 'Removery Tattoo Removal',
          types: ['point_of_interest', 'establishment'],
        ),
        isFalse,
      );
      expect(
        GooglePlacesService.isTattooPlace(
          name: 'Old Street Tattoo',
          types: ['body_art_service'],
          businessStatus: 'CLOSED_PERMANENTLY',
        ),
        isFalse,
      );

      // 2. Verify v1 searchText sends includedType: body_art_service and strips mixed non-tattoo results
      final mockClient = MockClient((request) async {
        if (request.url.path == '/maps/api/place/nearbysearch/json') {
          return http.Response(
            jsonEncode({'status': 'REQUEST_DENIED'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.host == 'places.googleapis.com' &&
            request.url.path == '/v1/places:searchText') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['includedType'], 'body_art_service');
          return http.Response(
            jsonEncode({
              'places': [
                {
                  'id': 'valid_shop_1',
                  'displayName': {'text': 'Shamrock Social Club'},
                  'shortFormattedAddress': '9026 Sunset Blvd',
                  'location': {'latitude': 34.0901, 'longitude': -118.3887},
                  'primaryType': 'body_art_service',
                  'types': ['body_art_service', 'establishment'],
                },
                {
                  'id': 'invalid_cafe_1',
                  'displayName': {'text': 'Sunset Espresso'},
                  'shortFormattedAddress': '9030 Sunset Blvd',
                  'location': {'latitude': 34.0902, 'longitude': -118.3889},
                  'primaryType': 'coffee_shop',
                  'types': ['coffee_shop', 'cafe', 'food'],
                },
                {
                  'id': 'invalid_salon_1',
                  'displayName': {'text': 'Luxe Nail & Hair Spa'},
                  'shortFormattedAddress': '9040 Sunset Blvd',
                  'location': {'latitude': 34.0905, 'longitude': -118.3891},
                  'primaryType': 'nail_salon',
                  'types': ['nail_salon', 'beauty_salon'],
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/maps/api/place/autocomplete/json') {
          expect(request.url.queryParameters['input'], 'Sunset tattoo');
          return http.Response(
            jsonEncode({'status': 'REQUEST_DENIED'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.host == 'places.googleapis.com' &&
            request.url.path == '/v1/places:autocomplete') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['includedPrimaryTypes'], ['body_art_service']);
          return http.Response(
            jsonEncode({
              'suggestions': [
                {
                  'placePrediction': {
                    'placeId': 'pred_tattoo_1',
                    'structuredFormat': {
                      'mainText': {'text': 'Sunset Strip Tattoo'},
                      'secondaryText': {'text': 'West Hollywood, CA'},
                    },
                    'types': ['body_art_service', 'establishment'],
                  },
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final service = GooglePlacesService(
        client: mockClient,
        apiKey: 'test_api_key',
      );

      final nearby = await service.searchNearbyTattooStudios(
        latitude: 34.09,
        longitude: -118.39,
      );
      expect(nearby.map((s) => s.name).toList(), ['Shamrock Social Club']);

      final predictions = await service.searchStudios('Sunset');
      expect(predictions.map((p) => p.primaryText).toList(), ['Sunset Strip Tattoo']);
    });
  });
}
