import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:flash_ink/core/utils/distance_calculator.dart';
import 'package:flash_ink/features/studios/studio_map_screen.dart';
import 'package:flash_ink/features/studios/studio_place_details_sheet.dart';
import 'package:flash_ink/models/artist.dart';
import 'package:flash_ink/models/studio_information.dart';
import 'package:flash_ink/providers/app_providers.dart';
import 'package:flash_ink/services/google_places_service.dart';
import 'package:flash_ink/services/studio_map_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const publicArtist = Artist(
    id: 'artist_pub_1',
    name: 'Kai Vesper',
    username: '@kaivesper',
    studioName: 'Iron Lotus Tattoo',
    avatarUrl: '',
    location: 'Los Angeles, CA',
    studioType: 'Street Shop',
    isPrivateStudio: false,
    latitude: 34.0825,
    longitude: -118.2700,
    rating: 4.9,
    availablePieces: 7,
    minDeposit: 120,
    tags: ['Blackwork', 'Japanese'],
    studioInformation: StudioInformation(
      name: 'Iron Lotus Tattoo',
      formattedAddress: '3100 Sunset Blvd, Los Angeles, CA 90026',
      city: 'Los Angeles',
      state: 'CA',
      placeId: 'place_iron_lotus',
      latitude: 34.0825,
      longitude: -118.2700,
      isPrivateStudio: false,
      studioType: 'Street Shop',
    ),
  );

  const privateArtist = Artist(
    id: 'artist_priv_1',
    name: 'Sora Vale',
    username: '@soravale',
    studioName: 'Velvet Sanctuary',
    avatarUrl: '',
    location: 'Silver Lake, CA',
    studioType: 'Private Studio',
    isPrivateStudio: true,
    latitude: 34.086942,
    longitude: -118.270188,
    rating: 5.0,
    availablePieces: 4,
    minDeposit: 150,
    tags: ['Fine Line'],
    studioInformation: StudioInformation(
      name: 'Velvet Sanctuary',
      formattedAddress: '999 Secret Ln Apt 4B, Los Angeles, CA 90026',
      city: 'Los Angeles',
      state: 'CA',
      placeId: 'secret_place_id',
      latitude: 34.086942,
      longitude: -118.270188,
      isPrivateStudio: true,
      studioType: 'Private Studio',
    ),
  );

  group('StudioMapService Unit Tests', () {
    test(
      'Maps public and private studios with strict privacy coarsening & deduplication',
      () {
        const mapService = StudioMapService();
        const clientCoords = GeoPointCoords(
          latitude: 34.0522,
          longitude: -118.2437,
        );

        final flashStudios = mapService.mapArtistsToStudios([
          publicArtist,
          privateArtist,
        ], clientCoords: clientCoords);

        expect(flashStudios.length, 2);

        final pubPin = flashStudios.firstWhere(
          (s) => s.name == 'Iron Lotus Tattoo',
        );
        expect(pubPin.isPrivateStudio, isFalse);
        expect(pubPin.placeId, 'place_iron_lotus');
        expect(pubPin.address, '3100 Sunset Blvd, Los Angeles, CA 90026');
        expect(pubPin.distanceMiles, isNotNull);

        final privPin = flashStudios.firstWhere(
          (s) => s.name == 'Velvet Sanctuary',
        );
        expect(privPin.isPrivateStudio, isTrue);
        expect(privPin.placeId, isNull);
        expect(privPin.address, 'Private Studio');
        // Coordinates coarsened to 2 decimal places
        expect(privPin.position.latitude, closeTo(34.09, 0.001));
        expect(privPin.position.longitude, closeTo(-118.27, 0.001));

        // Merge with Google Places: matching place_iron_lotus deduplicates instead of duplicating
        final merged = mapService.mergeWithGooglePlaces(
          flashInkStudios: flashStudios,
          nearbyPlaces: const [
            GooglePlaceStudioSummary(
              placeId: 'place_iron_lotus',
              name: 'Iron Lotus Tattoo',
              address: '3100 Sunset Blvd, Los Angeles',
              latitude: 34.0825,
              longitude: -118.2700,
              rating: 4.95,
              userRatingsTotal: 312,
              openNow: true,
            ),
            GooglePlaceStudioSummary(
              placeId: 'place_external_shop',
              name: 'Echo Park Ink',
              address: '1800 Echo Park Ave, Los Angeles',
              latitude: 34.0782,
              longitude: -118.2606,
              rating: 4.7,
              userRatingsTotal: 89,
              openNow: false,
            ),
            GooglePlaceStudioSummary(
              placeId: 'place_non_tattoo_cafe',
              name: 'Black Ink Coffee',
              address: '1810 Echo Park Ave, Los Angeles',
              latitude: 34.0785,
              longitude: -118.2608,
              rating: 4.5,
              userRatingsTotal: 140,
              openNow: true,
              types: ['cafe', 'food', 'establishment'],
            ),
          ],
          clientCoords: clientCoords,
        );

        expect(merged.length, 3);
        expect(merged.any((s) => s.name == 'Black Ink Coffee'), isFalse);
        final mergedIronLotus = merged.firstWhere(
          (s) => s.name == 'Iron Lotus Tattoo',
        );
        expect(mergedIronLotus.isVerifiedFlashInkStudio, isTrue);
        expect(mergedIronLotus.residentArtists.length, 1);
        expect(mergedIronLotus.openNow, isTrue);
        expect(mergedIronLotus.reviewCount, 312);
      },
    );
  });

  group('StudioMapScreen & StudioPlaceDetailsSheet Widget Tests', () {
    GooglePlacesService createMockPlacesService() {
      final client = MockClient((request) async {
        if (request.url.path.contains('nearbysearch')) {
          return http.Response(
            jsonEncode({
              'status': 'OK',
              'results': [
                {
                  'place_id': 'place_echo_ink',
                  'name': 'Echo Park Ink',
                  'vicinity': '1800 Echo Park Ave, Los Angeles',
                  'geometry': {
                    'location': {'lat': 34.0782, 'lng': -118.2606},
                  },
                  'rating': 4.8,
                  'user_ratings_total': 94,
                  'opening_hours': {'open_now': true},
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path.contains('details')) {
          return http.Response(
            jsonEncode({
              'status': 'OK',
              'result': {
                'name': 'Iron Lotus Tattoo',
                'formatted_address': '3100 Sunset Blvd, Los Angeles, CA 90026',
                'formatted_phone_number': '(323) 555-0188',
                'website': 'https://ironlotustattoo.example.com',
                'rating': 4.9,
                'user_ratings_total': 312,
                'opening_hours': {
                  'open_now': true,
                  'weekday_text': ['Monday: 11:00 AM – 7:00 PM'],
                },
                'reviews': [
                  {
                    'author_name': 'Devon K.',
                    'rating': 5,
                    'relative_time_description': '3 days ago',
                    'text': 'Super clean linework and welcoming crew.',
                  },
                ],
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });
      return GooglePlacesService(client: client, apiKey: 'test_key');
    }

    testWidgets(
      'StudioMapScreen defaults to user API key, merges studios, filters, and opens details sheet',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        const defaultScreen = StudioMapScreen();
        expect(defaultScreen.apiKey, equals(kDefaultGoogleMapsApiKey));
        expect(defaultScreen.apiKey, isNotEmpty);

        final mockPlaces = createMockPlacesService();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              artistsWithDistanceProvider.overrideWithValue(
                const AsyncValue.data([publicArtist, privateArtist]),
              ),
              effectiveClientCoordinatesProvider.overrideWithValue(
                const GeoPointCoords(latitude: 34.08, longitude: -118.27),
              ),
            ],
            child: MaterialApp(
              home: StudioMapScreen(
                placesService: mockPlaces,
                initialCenter: const LatLng(34.08, -118.27),
                mapOverrideBuilder: (_) =>
                    const ColoredBox(color: Colors.black),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify location button is positioned at the top right, to the right of the search field
        final searchFieldFinder = find.byKey(
          const Key('studio_map_search_field'),
        );
        final myLocationButtonFinder = find.byKey(
          const Key('studio_map_my_location_button'),
        );
        expect(searchFieldFinder, findsOneWidget);
        expect(myLocationButtonFinder, findsOneWidget);
        expect(
          tester.getTopLeft(myLocationButtonFinder).dx,
          greaterThan(tester.getTopRight(searchFieldFinder).dx),
        );

        // Carousel renders Flash.Ink studios + Google Places studio
        expect(find.byKey(const Key('studio_map_carousel')), findsOneWidget);
        expect(find.text('Iron Lotus Tattoo'), findsOneWidget);

        // Filter to Flash.Ink Artists only
        await tester.tap(
          find.byKey(const Key('studio_map_filter_flashInkOnly')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Echo Park Ink'), findsNothing);
        expect(find.text('Iron Lotus Tattoo'), findsOneWidget);

        // Tap Iron Lotus Tattoo preview card -> opens minimal non-scrollable StudioPlaceDetailsSheet
        await tester.tap(find.text('Iron Lotus Tattoo'));
        await tester.pumpAndSettle();

        // Verify minimal preview card contains key information
        expect(
          find.byKey(const Key('studio_place_details_sheet')),
          findsOneWidget,
        );
        expect(find.text('Iron Lotus Tattoo'), findsOneWidget);
        expect(find.text('OPEN NOW'), findsOneWidget);
        expect(find.text('4.9'), findsOneWidget);
        expect(find.text('(312 reviews)'), findsOneWidget);
        expect(find.textContaining('3100 Sunset Blvd'), findsOneWidget);
        expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
        expect(find.byIcon(Icons.near_me_outlined), findsOneWidget);
        expect(find.byIcon(Icons.location_on_outlined), findsOneWidget);

        // Verify floating card decoration has full border around all sides
        final cardContainer = tester.widget<Container>(
          find.byKey(const Key('studio_place_details_sheet')),
        );
        final boxDecoration = cardContainer.decoration as BoxDecoration;
        expect(boxDecoration.border, isA<Border>());
        expect(boxDecoration.border!.isUniform, isTrue);

        // Verify bottom carousel is hidden while preview card is open
        expect(find.byKey(const Key('studio_map_carousel')), findsNothing);

        // Verify minimal card excludes verified badge, quick contact buttons, and hours accordion
        expect(find.byIcon(Icons.verified), findsNothing);
        expect(find.text('(323) 555-0188'), findsNothing);
        expect(
          find.byKey(const Key('details_sheet_hours_toggle')),
          findsNothing,
        );

        // Tap preview card -> navigates to full StudioProfileScreen
        await tester.tap(
          find.byKey(const Key('details_sheet_view_shop_button')),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('studio_profile_screen')), findsOneWidget);
        expect(find.text('(323) 555-0188'), findsOneWidget);
        expect(find.text('Kai Vesper'), findsOneWidget);
        expect(find.text('Devon K.'), findsOneWidget);

        // Toggle Studio Hours accordion on shop page
        await tester.tap(find.byKey(const Key('studio_profile_hours_toggle')));
        await tester.pumpAndSettle();
        expect(find.text('Monday: 11:00 AM – 7:00 PM'), findsOneWidget);
      },
    );

    testWidgets(
      'StudioPlaceDetailsSheet redacts private studio street address and shows privacy banner',
      (tester) async {
        final privPin = const StudioMapService().mapArtistsToStudios([
          privateArtist,
        ]).single;
        final mockPlaces = createMockPlacesService();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StudioPlaceDetailsSheet(
                studio: privPin,
                placesService: mockPlaces,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('private_studio_privacy_banner')),
          findsOneWidget,
        );
        expect(find.textContaining('999 Secret Ln'), findsNothing);
        expect(find.text('Velvet Sanctuary'), findsOneWidget);

        // Tapping opens full shop profile where resident artist Sora Vale is listed
        await tester.tap(
          find.byKey(const Key('details_sheet_view_shop_button')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Sora Vale'), findsOneWidget);
      },
    );
  });
}
