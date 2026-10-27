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
  });
}
