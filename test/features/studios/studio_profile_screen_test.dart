import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:flash_ink/core/utils/distance_calculator.dart';
import 'package:flash_ink/features/explore/domain/models/explore_studio.dart';
import 'package:flash_ink/features/explore/presentation/screens/explore_screen.dart';
import 'package:flash_ink/features/studios/studio_place_details_sheet.dart';
import 'package:flash_ink/features/studios/studio_profile_screen.dart';
import 'package:flash_ink/models/artist.dart';
import 'package:flash_ink/models/studio_information.dart';
import 'package:flash_ink/providers/app_providers.dart';
import 'package:flash_ink/services/auth_service.dart';
import 'package:flash_ink/services/google_places_service.dart';
import 'package:flash_ink/services/studio_map_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const oddmaree = Artist(
    id: 'artist_oddmaree',
    name: 'Oddmaree',
    username: '@oddmaree',
    studioName: 'Reverie',
    avatarUrl: '',
    isBooksOpen: true,
    location: 'Newberg, OR',
    studioType: 'Street Shop',
    isPrivateStudio: false,
    latitude: 45.3001,
    longitude: -122.9731,
    rating: 5.0,
    availablePieces: 12,
    minDeposit: 50,
    tags: ['Fine Line', 'Botanical'],
    policies: [
      StudioPolicy(
        title: 'Touch-ups',
        description: 'Complimentary touch-up within 6 months of session.',
        iconKey: 'touchup',
      ),
    ],
    studioInformation: StudioInformation(
      name: 'Reverie',
      formattedAddress: '608 E 1st St, Newberg, OR 97132',
      city: 'Newberg',
      state: 'OR',
      placeId: 'place_reverie_tattoos',
      latitude: 45.3001,
      longitude: -122.9731,
      isPrivateStudio: false,
      studioType: 'Street Shop',
    ),
  );

  const privateResident = Artist(
    id: 'artist_private_shop',
    name: 'Sora Vale',
    username: '@soravale',
    studioName: 'Hidden Sanctuary',
    avatarUrl: '',
    isBooksOpen: true,
    location: 'Portland, OR',
    studioType: 'Private Studio',
    isPrivateStudio: true,
    latitude: 45.515231,
    longitude: -122.678385,
    rating: 4.9,
    availablePieces: 6,
    minDeposit: 100,
    studioInformation: StudioInformation(
      name: 'Hidden Sanctuary',
      formattedAddress: '742 Evergreen Ter Apt 3C, Portland, OR 97205',
      city: 'Portland',
      state: 'OR',
      placeId: 'secret_place_id',
      latitude: 45.515231,
      longitude: -122.678385,
      isPrivateStudio: true,
      studioType: 'Private Studio',
    ),
  );

  GooglePlacesService createMockReveriePlacesService({
    VoidCallback? onDetailsRequested,
  }) {
    final client = MockClient((request) async {
      if (request.url.path.contains('details')) {
        onDetailsRequested?.call();
        return http.Response(
          jsonEncode({
            'status': 'OK',
            'result': {
              'name': 'Reverie',
              'formatted_address': '608 E 1st St, Newberg, OR 97132',
              'formatted_phone_number': '(503) 555-0199',
              'website': 'https://www.reverietattoos.example.com/',
              'url': 'https://maps.google.com/?cid=999999',
              'rating': 5.0,
              'user_ratings_total': 84,
              'opening_hours': {
                'open_now': true,
                'weekday_text': ['Tuesday: 11:00 AM – 6:00 PM'],
              },
              'reviews': [
                {
                  'author_name': 'Taylor M.',
                  'rating': 5,
                  'relative_time_description': '1 week ago',
                  'text': 'Warmest shop in Newberg and immaculate work.',
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

  group('StudioProfileScreen Widget Tests', () {
    testWidgets(
      'Renders dedicated shop page layout, stats, 3-pill action row, and resident artist card',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final reveriePin = const StudioMapService()
            .mapArtistsToStudios([oddmaree])
            .single
            .copyWith(distanceMiles: 2.0, fallbackArtistCount: 4);

        Artist? tappedArtist;
        bool openedMap = false;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              artistsWithDistanceProvider.overrideWithValue(
                const AsyncValue.data([oddmaree]),
              ),
              // ~2.0 miles north of Reverie
              effectiveClientCoordinatesProvider.overrideWithValue(
                const GeoPointCoords(latitude: 45.3290, longitude: -122.9731),
              ),
            ],
            child: MaterialApp(
              home: StudioProfileScreen(
                studio: reveriePin,
                placesService: createMockReveriePlacesService(),
                authService: AuthService(
                  mockUser: DevMockUser(
                    uid: 'client_1',
                    isAnonymous: false,
                  ),
                ),
                onOpenMap: () => openedMap = true,
                onArtistTap: (artist) => tappedArtist = artist,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Hero title & city/state
        expect(find.byKey(const Key('studio_profile_name')), findsOneWidget);
        expect(find.text('Reverie'), findsOneWidget);
        expect(find.text('Newberg, OR'), findsOneWidget);

        // 3-Column Studio Metrics Card (84 REVIEWS / RATING | ARTISTS | DISTANCE)
        expect(find.byKey(const Key('studio_profile_stats_card')), findsOneWidget);
        expect(find.text('84 REVIEWS'), findsOneWidget);
        expect(find.text('RATING'), findsOneWidget); // On Oddmaree card
        expect(find.text('ARTISTS'), findsOneWidget);
        expect(find.text('DISTANCE'), findsOneWidget);
        expect(find.text('2mi'), findsOneWidget);

        // 3-Pill Quick Actions Row (Website, Phone, Directions)
        expect(find.byKey(const Key('studio_info_website_row')), findsOneWidget);
        expect(find.text('Website'), findsOneWidget);
        expect(find.byKey(const Key('studio_info_phone_row')), findsOneWidget);
        expect(find.text('(503) 555-0199'), findsOneWidget);
        expect(find.byKey(const Key('studio_directions_button')), findsOneWidget);
        expect(find.text('Directions'), findsOneWidget);

        // "Resident Artists & Flash" section & Oddmaree card
        expect(find.byKey(const Key('studio_profile_artists_heading')), findsOneWidget);
        expect(find.text('Resident Artists & Flash'), findsOneWidget);
        expect(
          find.text('Claim ready-to-ink designs or book custom sessions'),
          findsOneWidget,
        );
        expect(find.text('Oddmaree'), findsOneWidget);
        expect(find.text('Books open'), findsOneWidget);
        expect(find.text('12'), findsOneWidget);
        expect(find.text('AVAIL PIECES'), findsOneWidget);
        expect(find.text('\$50'), findsOneWidget);
        expect(find.text('MIN DEPOSIT'), findsOneWidget);
        expect(find.text('View Profile'), findsOneWidget);

        // Hero actions: Directions & Favorite toggle
        await tester.tap(find.byKey(const Key('studio_directions_button')));
        await tester.pump();
        expect(openedMap, isTrue);

        expect(find.byIcon(Icons.favorite_border), findsNWidgets(2));
        await tester.tap(find.byKey(const Key('studio_favorite_button')));
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.favorite), findsOneWidget);

        // Tap VIEW PROFILE on Oddmaree card
        await tester.tap(
          find.byKey(const Key('studio_artist_view_profile_artist_oddmaree')),
        );
        await tester.pumpAndSettle();
        expect(tappedArtist?.id, equals('artist_oddmaree'));
      },
    );

    testWidgets(
      'Renders resident artist flash artwork cards with placement, size, and deposit',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        const oddmareeWithFlash = Artist(
          id: 'artist_oddmaree',
          name: 'Oddmaree',
          username: '@oddmaree',
          studioName: 'Reverie',
          avatarUrl: '',
          isBooksOpen: true,
          location: 'Newberg, OR',
          studioType: 'Street Shop',
          isPrivateStudio: false,
          latitude: 45.3001,
          longitude: -122.9731,
          rating: 5.0,
          availablePieces: 12,
          minDeposit: 50,
          tags: ['Neo-Traditional', 'Dark Illustrative'],
          flashArtworks: [
            FlashArtwork(
              id: 'flash_1',
              artistId: 'artist_oddmaree',
              title: 'Kiku & Serpent Half Sleeve',
              imageUrl: 'assets/images/flash_traditional_dagger.jpg',
              price: 300,
              deposit: 150,
              dimensions: '6" × 12"',
              location: 'Arm / Thigh',
            ),
          ],
        );

        final reveriePin = const StudioMapService()
            .mapArtistsToStudios([oddmareeWithFlash])
            .single;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              artistsWithDistanceProvider.overrideWithValue(
                const AsyncValue.data([oddmareeWithFlash]),
              ),
            ],
            child: MaterialApp(
              home: StudioProfileScreen(
                studio: reveriePin,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Kiku & Serpent Half Sleeve'), findsOneWidget);
        expect(find.text('Placement: Arm / Thigh'), findsOneWidget);
        expect(find.text('Size: 6" × 12"'), findsOneWidget);
        expect(find.textContaining('150'), findsWidgets);
        expect(find.text('Neo-Traditional & Dark Illustrative'), findsOneWidget);
      },
    );

    testWidgets(
      'Enforces strict privacy redaction for private studios and skips external Places calls',
      (tester) async {
        bool detailsRequested = false;
        final privatePin = const StudioMapService()
            .mapArtistsToStudios([privateResident])
            .single;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              artistsWithDistanceProvider.overrideWithValue(
                const AsyncValue.data([privateResident]),
              ),
            ],
            child: MaterialApp(
              home: StudioProfileScreen(
                studio: privatePin,
                placesService: createMockReveriePlacesService(
                  onDetailsRequested: () => detailsRequested = true,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(detailsRequested, isFalse);
        expect(find.textContaining('742 Evergreen Ter'), findsNothing);
        expect(
          find.text('Private Studio • Shared upon booking'),
          findsOneWidget,
        );
        expect(find.text('Sora Vale'), findsOneWidget);
      },
    );

    testWidgets(
      'ExploreScreen StudioCard tap navigates directly to StudioProfileScreen',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        const exploreStudios = [
          ExploreStudio(
            id: 'studio_reverie',
            name: 'Reverie',
            address: '608 E 1st St',
            city: 'Newberg, OR',
            imageUrl: '',
            rating: 5.0,
            reviewCount: 12,
            residentArtistsCount: 1,
            styles: ['Fine Line'],
            isVerified: true,
          ),
        ];

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              exploreStudiosProvider.overrideWithValue(
                const AsyncValue.data(exploreStudios),
              ),
              artistsWithDistanceProvider.overrideWithValue(
                const AsyncValue.data([oddmaree]),
              ),
            ],
            child: const MaterialApp(
              home: ExploreScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Reverie'));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('studio_profile_screen')), findsOneWidget);
        expect(find.text('Oddmaree'), findsOneWidget);
      },
    );

    testWidgets(
      'StudioPlaceDetailsSheet VIEW SHOP PAGE button navigates to StudioProfileScreen',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final mockPlaces = createMockReveriePlacesService();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              artistsWithDistanceProvider.overrideWithValue(
                const AsyncValue.data([oddmaree]),
              ),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: StudioPlaceDetailsSheet(
                  studio: const StudioMapMarkerData(
                    id: 'gplace_reverie',
                    name: 'Reverie',
                    address: '608 E 1st St, Newberg, OR 97132',
                    cityState: 'Newberg, OR',
                    position: LatLng(45.3001, -122.9731),
                    placeId: 'place_reverie_tattoos',
                    rating: 5.0,
                  ),
                  placesService: mockPlaces,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('details_sheet_view_shop_button')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('studio_profile_screen')), findsOneWidget);
        expect(find.text('Oddmaree'), findsOneWidget);
      },
    );
  });
}
