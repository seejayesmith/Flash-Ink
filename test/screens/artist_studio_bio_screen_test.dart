import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:flash_ink/models/studio_information.dart';
import 'package:flash_ink/screens/artist_onboarding/artist_studio_bio_screen.dart';
import 'package:flash_ink/screens/artist_onboarding/artist_policies_screen.dart';
import 'package:flash_ink/services/google_places_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.physicalSize = const Size(1080, 2400);
    binding.platformDispatcher.views.first.devicePixelRatio = 1.0;
  });

  tearDown(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.resetPhysicalSize();
    binding.platformDispatcher.views.first.resetDevicePixelRatio();
  });

  GooglePlacesService createMockPlacesService({bool hasKey = true}) {
    final mockClient = MockClient((request) async {
      if (request.url.path.contains('autocomplete')) {
        return http.Response(
          jsonEncode({
            'status': 'OK',
            'predictions': [
              {
                'place_id': 'place_rose_1',
                'description': 'Rose Water Tattoo, Portland, OR',
                'structured_formatting': {
                  'main_text': 'Rose Water Tattoo',
                  'secondary_text': 'Portland, OR',
                },
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      } else if (request.url.path.contains('details')) {
        return http.Response(
          jsonEncode({
            'status': 'OK',
            'result': {
              'name': 'Rose Water Tattoo',
              'formatted_address': '123 SE Hawthorne Blvd, Portland, OR 97214',
              'address_components': [
                {'long_name': 'Portland', 'short_name': 'Portland', 'types': ['locality']},
                {'long_name': 'Oregon', 'short_name': 'OR', 'types': ['administrative_area_level_1']},
                {'long_name': '97214', 'short_name': '97214', 'types': ['postal_code']},
              ],
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('Not Found', 404);
    });

    return GooglePlacesService(
      client: mockClient,
      apiKey: hasKey ? 'test_api_key' : null,
    );
  }

  Widget buildTestWidget({
    GooglePlacesService? service,
    StudioInformation? initialStudio,
    String? initialBio,
  }) {
    return MaterialApp(
      home: ArtistStudioBioScreen(
        artistName: 'OddMaree',
        googlePlacesService: service ?? createMockPlacesService(),
        initialStudio: initialStudio,
        initialBio: initialBio,
      ),
    );
  }

  group('ArtistStudioBioScreen Widget Tests', () {
    testWidgets('Renders header, step indicator, and empty state with disabled CTA', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Where do you tattoo?'), findsOneWidget);
      expect(find.text('STUDIO OR SHOP LOCATION'), findsOneWidget);
      expect(find.text('ARTIST BIO'), findsOneWidget);
      expect(find.byKey(const Key('studio_search_field')), findsOneWidget);
      expect(find.byKey(const Key('artist_bio_field')), findsOneWidget);

      // Verify Continue button is initially disabled
      final continueButton = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(continueButton.onPressed, isNull);
    });

    testWidgets('Shows missing API key banner when key is not configured', (tester) async {
      final noKeyService = createMockPlacesService(hasKey: false);
      await tester.pumpWidget(buildTestWidget(service: noKeyService));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('places_api_key_missing_banner')), findsOneWidget);
      expect(find.text('Maps API Key Required in .env'), findsOneWidget);
    });

    testWidgets('Search query triggers predictions and selects a studio', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Enter search query
      await tester.enterText(find.byKey(const Key('studio_search_field')), 'Rose');
      await tester.pump(const Duration(milliseconds: 350)); // Wait for debounce
      await tester.pumpAndSettle();

      // Suggestions should appear
      expect(find.byKey(const Key('studio_predictions_list')), findsOneWidget);
      expect(find.text('Rose Water Tattoo'), findsOneWidget);

      // Tap the prediction
      await tester.tap(find.byKey(const Key('prediction_item_0')));
      await tester.pumpAndSettle();

      // Selected studio card should be displayed
      expect(find.byKey(const Key('selected_studio_card')), findsOneWidget);
      expect(find.byKey(const Key('selected_studio_name')), findsOneWidget);
      expect(find.text('Rose Water Tattoo'), findsOneWidget);

      // Continue button should now be enabled
      final continueButton = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(continueButton.onPressed, isNotNull);

      // Tap Change Studio
      await tester.tap(find.byKey(const Key('change_studio_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('selected_studio_card')), findsNothing);
      expect(find.byKey(const Key('studio_search_field')), findsOneWidget);
    });

    testWidgets('Manual studio entry flow enables Continue and transitions to Policies screen', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Tap switch to manual entry
      await tester.tap(find.byKey(const Key('toggle_manual_studio_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('manual_studio_form')), findsOneWidget);
      expect(find.byKey(const Key('manual_studio_name_field')), findsOneWidget);
      expect(find.byKey(const Key('manual_studio_location_field')), findsOneWidget);

      // Enter manual studio details
      await tester.enterText(find.byKey(const Key('manual_studio_name_field')), 'Scapegoat Tattoo');
      await tester.enterText(find.byKey(const Key('manual_studio_location_field')), 'Portland, OR');
      await tester.pumpAndSettle();

      // Verify Continue button is now enabled
      final continueButton = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(continueButton.onPressed, isNotNull);

      // Tap Continue and verify it navigates to ArtistPoliciesScreen
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      expect(find.byType(ArtistPoliciesScreen), findsOneWidget);
    });

    testWidgets('Bio character counter updates and inspiration prompt inserts text', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('0/500'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('artist_bio_field')), 'Hello world');
      await tester.pumpAndSettle();

      expect(find.text('11/500'), findsOneWidget);

      // Tap an inspiration chip
      await tester.tap(find.text('+ Resident artist with 5+ yrs experience'));
      await tester.pumpAndSettle();

      final bioField = tester.widget<TextField>(find.byKey(const Key('artist_bio_field')));
      expect(bioField.controller!.text, contains('Resident artist with 5+ yrs experience'));
    });

    testWidgets('Toggles Private Studio mode and Studio Type chips', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Tap Private Studio ChoiceChip
      await tester.tap(find.byKey(const Key('studio_type_chip_Private Studio')));
      await tester.pumpAndSettle();

      // Verify Private Studio switch turned on
      expect(find.byKey(const Key('private_studio_switch')), findsOneWidget);
    });
  });
}
