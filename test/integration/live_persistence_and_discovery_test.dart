import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:flash_ink/core/mock/mock_data_config.dart';
import 'package:flash_ink/core/mock/mock_fixtures.dart';
import 'package:flash_ink/core/utils/distance_calculator.dart';
import 'package:flash_ink/features/appointments/domain/models/appointment_item.dart';
import 'package:flash_ink/features/artist/presentation/screens/artist_profile_screen.dart';
import 'package:flash_ink/features/messages/domain/models/message_thread.dart';
import 'package:flash_ink/models/artist.dart';
import 'package:flash_ink/models/studio_information.dart';
import 'package:flash_ink/models/user.dart';
import 'package:flash_ink/providers/app_providers.dart';
import 'package:flash_ink/repositories/artist_repository.dart';
import 'package:flash_ink/repositories/user_repository.dart';
import 'package:flash_ink/screens/browse_artists_screen.dart';
import 'package:flash_ink/services/auth_service.dart';
import 'package:flash_ink/widgets/artist_card.dart';

class _FakeAuthUser extends Fake implements User {
  @override
  final String uid;
  @override
  final String? email;
  @override
  final String? displayName;
  @override
  String? get photoURL => null;

  _FakeAuthUser({
    required this.uid,
    this.email,
    this.displayName,
  });
}

///Controllable [AuthService] fake that simulates Artist -> SignOut -> Client
///account switching on the same device and broadcasts real-time auth state changes.
class _SwitchableFakeAuthService extends AuthService {
  final StreamController<User?> _controller =
      StreamController<User?>.broadcast();
  User? _activeUser;

  _SwitchableFakeAuthService({required super.firestore});

  @override
  User? get currentUser => _activeUser;

  @override
  Stream<User?> get authStateChanges async* {
    yield _activeUser;
    yield* _controller.stream;
  }

  void signInAs(_FakeAuthUser user) {
    _activeUser = user;
    _controller.add(user);
  }

  @override
  Future<void> signOut() async {
    _activeUser = null;
    AuthService.invalidateSessionState();
    _controller.add(null);
  }

  void dispose() {
    _controller.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    MockDataConfig.resetDebugOverride();
    ClientAppointment.clearSessionAppointments();
    MessageThread.clearSessionThreads();
  });

  tearDown(() {
    MockDataConfig.resetDebugOverride();
    ClientAppointment.clearSessionAppointments();
    MessageThread.clearSessionThreads();
  });

  group('Phase 5 Verification Suite — Live Persistence, Isolation & Discovery', () {
    // =========================================================================
    // TEST 1: Mock Isolation & Non-Destructive Quarantine Verification
    // =========================================================================
    testWidgets(
      'Test 1 (Mock Isolation): Default repository/provider graph and BrowseArtistsScreen emit zero mock records on a clean Firestore instance while preserving quarantined fixtures',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // 1. Verify mock flag is disabled by default while 100% of fixtures are preserved
        expect(kEnableMockData, isFalse);
        expect(MockDataConfig.isEnabled, isFalse);
        expect(MockFixtures.artists.length, 4);
        expect(MockFixtures.studios.length, 4);
        expect(MockFixtures.createUpcomingAppointments(), isNotEmpty);
        expect(MockFixtures.createPastAppointments(), isNotEmpty);
        expect(MockFixtures.createMessageThreads(), isNotEmpty);

        // 2. Verify clean FakeFirebaseFirestore emits zero records across repositories & providers
        final fakeDb = FakeFirebaseFirestore();
        final fakeAuth = _SwitchableFakeAuthService(firestore: fakeDb);
        addTearDown(fakeAuth.dispose);

        final container = ProviderContainer(
          overrides: [
            firebaseFirestoreProvider.overrideWithValue(fakeDb),
            authServiceProvider.overrideWithValue(fakeAuth),
          ],
        );
        addTearDown(container.dispose);

        final discoverySub = container.listen(
          artistsWithDistanceProvider,
          (_, _) {},
          fireImmediately: true,
        );
        final studiosSub = container.listen(
          exploreStudiosProvider,
          (_, _) {},
          fireImmediately: true,
        );
        addTearDown(() {
          discoverySub.close();
          studiosSub.close();
        });

        // Pump FakeAsync microtasks + zero-duration timers so FakeFirebaseFirestore delivers initial snapshot
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(container.read(artistDiscoveryStreamProvider).value, isEmpty);
        expect(container.read(artistsWithDistanceProvider).value, isEmpty);
        expect(container.read(exploreStudiosProvider).value, isEmpty);
        expect(ClientAppointment.activeUpcoming, isEmpty);
        expect(ClientAppointment.activePast, isEmpty);
        expect(MessageThread.activeThreads, isEmpty);

        // 3. Pump BrowseArtistsScreen against clean Firestore and assert honest empty state
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: BrowseArtistsScreen(authService: fakeAuth),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(ArtistCard), findsNothing);
        expect(find.text('No Artists Available Yet'), findsOneWidget);
        for (final mockArtist in MockFixtures.artists) {
          expect(find.text(mockArtist.name), findsNothing);
        }
      },
    );

    // =========================================================================
    // TEST 2: Full Artist & Client Onboarding Persistence + Privacy Boundary
    // =========================================================================
    test(
      'Test 2 (Artist & Client Creation Persistence): Full onboarding persists all fields and valid discovery coordinates atomically while redacting private street addresses',
      () async {
        final fakeDb = FakeFirebaseFirestore();
        final artistRepo = ArtistRepository(firestore: fakeDb);
        final userRepo = UserRepository(firestore: fakeDb);

        // 1. Simulate full Private-Studio Artist onboarding with exact street address & PII
        const artistUid = 'artist_live_uid_001';
        const privateStudio = StudioInformation(
          name: 'Velvet Needle Atelier',
          placeId: 'ChIJ_private_place_123',
          formattedAddress: '742 Evergreen Terrace, Suite 4B, Portland, OR 97214',
          city: 'Portland',
          state: 'OR',
          postalCode: '97214',
          latitude: 45.51354,
          longitude: -122.65318,
          isPrivateStudio: true,
          studioType: 'Private Studio',
        );

        final savedArtist = await artistRepo.saveArtistOnboarding(
          uid: artistUid,
          displayName: 'Clara Vance',
          username: 'claravance_ink',
          instagramHandle: '@claravance.tattoo',
          email: 'clara.private@flash.ink',
          phoneNumber: '+15035550199',
          avatarUrl: 'https://example.com/clara_avatar.jpg',
          bio: 'Botanical blackwork & illustrative etching in Southeast Portland.',
          styles: const ['Blackwork', 'Botanical', 'Fine Line'],
          identityTags: const ['Female Artist', 'Queer Friendly', 'Silent Appointments'],
          studioInformation: privateStudio,
          minDeposit: 120,
          isBooksOpen: true,
          customRequestAvailable: true,
          flashArtworks: const [
            FlashArtwork(
              id: 'flash_clara_1',
              title: 'Nightshade Moth',
              imageUrl: 'https://example.com/moth.jpg',
              location: 'Forearm',
              size: '4" x 6"',
              price: 320,
              deposit: 120,
              status: FlashStatus.available,
            ),
          ],
          policies: const [
            StudioPolicy(
              iconKey: 'deposit',
              title: 'Non-Refundable Deposit',
              description: '\$120 deposit applied toward final tattoo balance.',
            ),
          ],
          funFacts: const [
            ArtistFunFact(label: 'Experience', value: '7 Years'),
          ],
        );

        expect(savedArtist.profileCompleted, isTrue);
        expect(savedArtist.name, 'Clara Vance');
        expect(savedArtist.username, 'claravance_ink');
        expect(savedArtist.instagramHandle, '@claravance.tattoo');
        expect(savedArtist.minDeposit, 120);
        expect(savedArtist.availablePieces, 1);

        // 2. Assert public `/artists/{uid}` redacts street address & coarsens coords (~2 decimals)
        final rawArtistDoc =
            await fakeDb.collection('artists').doc(artistUid).get();
        expect(rawArtistDoc.exists, isTrue);
        final publicMap = rawArtistDoc.data()!;
        expect(publicMap['profileCompleted'], isTrue);
        expect(publicMap['email'], isNull);
        expect(publicMap['phoneNumber'], isNull);
        expect(publicMap['latitude'], closeTo(45.51, 0.001));
        expect(publicMap['longitude'], closeTo(-122.65, 0.001));

        final publicStudioMap =
            Map<String, dynamic>.from(publicMap['studioInformation'] as Map);
        expect(publicStudioMap['formattedAddress'], 'Portland, OR');
        expect(
          publicStudioMap['formattedAddress'],
          isNot(contains('742 Evergreen')),
        );
        expect(
          publicStudioMap['formattedAddress'],
          isNot(contains('Suite 4B')),
        );
        expect(publicStudioMap['postalCode'], isEmpty);
        expect(publicStudioMap['placeId'], isNull);
        expect(publicStudioMap['city'], 'Portland');
        expect(publicStudioMap['state'], 'OR');

        // 3. Assert isolated `/artists/{uid}/private/settings` preserves operational details
        final privateDoc = await fakeDb
            .collection('artists')
            .doc(artistUid)
            .collection('private')
            .doc('settings')
            .get();
        expect(privateDoc.exists, isTrue);
        expect(privateDoc.data()!['email'], 'clara.private@flash.ink');
        expect(privateDoc.data()!['phoneNumber'], '+15035550199');
        expect(
          privateDoc.data()!['streetAddress'],
          '742 Evergreen Terrace, Suite 4B, Portland, OR 97214',
        );

        // 4. Hydrate Artist back from Firestore and verify all fields round-trip cleanly
        final hydratedArtist = await artistRepo.getArtist(artistUid);
        expect(hydratedArtist, isNotNull);
        expect(hydratedArtist!.name, 'Clara Vance');
        expect(hydratedArtist.bio, contains('Botanical blackwork'));
        expect(hydratedArtist.tags, containsAll(['Blackwork', 'Female Artist']));
        expect(hydratedArtist.flashArtworks.single.title, 'Nightshade Moth');
        expect(hydratedArtist.policies.single.title, 'Non-Refundable Deposit');
        expect(hydratedArtist.discoveryCoordinates, isNotNull);
        expect(hydratedArtist.discoveryCoordinates!.isValid, isTrue);

        // 5. Verify automatic coordinate guarantee when Artist enters city/ZIP without GPS coords
        const manualStudioNoGps = StudioInformation(
          name: 'Pearl District Tattoo',
          city: 'Portland',
          state: 'OR',
          postalCode: '97209',
          isPrivateStudio: false,
          studioType: 'Street Shop',
        );
        final manualArtist = await artistRepo.saveArtistOnboarding(
          uid: 'artist_manual_zip_002',
          displayName: 'Julian Mercer',
          studioInformation: manualStudioNoGps,
          styles: const ['Traditional'],
        );
        expect(manualArtist.discoveryCoordinates, isNotNull);
        expect(manualArtist.discoveryCoordinates!.latitude, closeTo(45.5286, 0.01));
        expect(manualArtist.discoveryCoordinates!.longitude, closeTo(-122.6845, 0.01));

        // 6. Verify Client onboarding atomic persistence + ZIP coordinate resolution
        const clientUid = 'client_newberg_001';
        await userRepo.saveClientOnboarding(
          uid: clientUid,
          email: 'maya@collector.ink',
          username: 'mayacollects',
          aesthetics: const ['blackwork', 'fineline'],
          placements: const ['Forearm', 'Collarbone'],
          zipCode: '97132',
          travelRadiusMiles: 35,
          notificationsEnabled: true,
          profileCompleted: true,
        );

        final hydratedClient = await userRepo.getUserProfile(clientUid);
        expect(hydratedClient, isNotNull);
        expect(hydratedClient!.uid, clientUid);
        expect(hydratedClient.role, 'client');
        expect(hydratedClient.username, 'mayacollects');
        expect(hydratedClient.aesthetics, equals(['blackwork', 'fineline']));
        expect(hydratedClient.placements, equals(['Forearm', 'Collarbone']));
        expect(hydratedClient.travelRadiusMiles, 35);
        expect(hydratedClient.cityState, 'Newberg, OR');
        expect(hydratedClient.savedCoordinates, isNotNull);
        expect(hydratedClient.savedCoordinates!.latitude, closeTo(45.3001, 0.001));
        expect(hydratedClient.savedCoordinates!.longitude, closeTo(-122.9731, 0.001));
      },
    );

    // =========================================================================
    // TEST 3: Cross-Role Session Switch + Real-Time Discovery Stream + Distance
    // =========================================================================
    testWidgets(
      'Test 3 (Cross-Role Real-Time Stream + Distance): Artist onboarding -> Sign Out -> Client login (Newberg, OR) streams newly created Artist in real time with accurate Haversine distance and reactive coordinate updates',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final fakeDb = FakeFirebaseFirestore();
        final fakeAuth = _SwitchableFakeAuthService(firestore: fakeDb);
        addTearDown(fakeAuth.dispose);

        final container = ProviderContainer(
          overrides: [
            firebaseFirestoreProvider.overrideWithValue(fakeDb),
            authServiceProvider.overrideWithValue(fakeAuth),
          ],
        );
        addTearDown(container.dispose);

        // Keep listeners active on auth/profile/discovery providers across role switch
        final profileEvents = <UserProfile?>[];
        final discoveryEvents = <List<Artist>>[];
        final profileSub = container.listen<AsyncValue<UserProfile?>>(
          currentUserProfileProvider,
          (_, next) {
            if (next.hasValue) profileEvents.add(next.value);
          },
          fireImmediately: true,
        );
        final discoverySub = container.listen<AsyncValue<List<Artist>>>(
          artistsWithDistanceProvider,
          (_, next) {
            if (next.hasValue) discoveryEvents.add(next.value!);
          },
          fireImmediately: true,
        );
        addTearDown(() {
          profileSub.close();
          discoverySub.close();
        });

        // ---------------------------------------------------------------------
        // STEP A: Authenticate as Artist in Portland, OR (45.5152, -122.6784)
        // ---------------------------------------------------------------------
        const artistUid = 'artist_portland_rowan';
        fakeAuth.signInAs(
          _FakeAuthUser(
            uid: artistUid,
            email: 'rowan@blackthorn.ink',
            displayName: 'Rowan Vale',
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        await container.read(artistRepositoryProvider).saveArtistOnboarding(
              uid: artistUid,
              displayName: 'Rowan Vale',
              username: 'rowanvale',
              bio: 'Woodcut & Neo-Traditional flash in Downtown Portland.',
              styles: const ['Neo-Traditional', 'Blackwork'],
              studioInformation: const StudioInformation(
                name: 'Blackthorn Ink',
                formattedAddress: '515 SW Broadway, Portland, OR 97205',
                city: 'Portland',
                state: 'OR',
                postalCode: '97205',
                latitude: 45.5152,
                longitude: -122.6784,
                isPrivateStudio: false,
                studioType: 'Street Shop',
              ),
              minDeposit: 80,
              isBooksOpen: true,
              flashArtworks: const [
                FlashArtwork(
                  id: 'rowan_flash_1',
                  title: 'Iron Raven',
                  imageUrl: 'assets/images/flash_traditional_dagger.jpg',
                  location: 'Upper Arm',
                  size: '5" x 7"',
                  price: 280,
                  deposit: 80,
                  status: FlashStatus.available,
                ),
              ],
            );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(container.read(activeUidProvider), artistUid);
        final artistUserProfile =
            container.read(currentUserProfileProvider).value;
        expect(artistUserProfile?.displayName, 'Rowan Vale');
        expect(artistUserProfile?.onboardingRole, 'artist');

        // ---------------------------------------------------------------------
        // STEP B: Sign out of Artist account — verify clean session invalidation
        // ---------------------------------------------------------------------
        await fakeAuth.signOut();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(container.read(activeUidProvider), isNull);
        expect(container.read(currentUserProfileProvider).value, isNull);
        expect(container.read(liveGpsCoordinatesProvider), isNull);
        expect(container.read(effectiveClientCoordinatesProvider), isNull);

        // ---------------------------------------------------------------------
        // STEP C: Sign in on same device as Client in Newberg, OR (45.3001, -122.9731)
        // ---------------------------------------------------------------------
        const clientUid = 'client_newberg_liam';
        fakeAuth.signInAs(
          _FakeAuthUser(
            uid: clientUid,
            email: 'liam@newberg.org',
            displayName: 'Liam Chen',
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        await container.read(userRepositoryProvider).saveClientOnboarding(
              uid: clientUid,
              email: 'liam@newberg.org',
              username: 'liam_or',
              aesthetics: const ['neotraditional', 'blackwork'],
              placements: const ['Upper Arm'],
              zipCode: '97132',
              cityState: 'Newberg, OR',
              latitude: 45.3001,
              longitude: -122.9731,
              travelRadiusMiles: 50,
              profileCompleted: true,
            );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        final activeClientProfile =
            container.read(currentUserProfileProvider).value;
        expect(activeClientProfile, isNotNull);
        expect(activeClientProfile!.uid, clientUid);
        expect(activeClientProfile.username, 'liam_or');
        // Zero stale Artist state bled into Client profile
        expect(activeClientProfile.onboardingRole, isNull);

        // Verify expected Haversine distance between Newberg, OR & Portland, OR (~20.6 mi)
        final expectedMiles = DistanceCalculator.calculateMiles(
          startLatitude: 45.3001,
          startLongitude: -122.9731,
          endLatitude: 45.5152,
          endLongitude: -122.6784,
        );
        expect(expectedMiles, closeTo(20.6, 0.2));
        final expectedDistanceLabel =
            DistanceCalculator.formatMilesAway(expectedMiles);
        expect(expectedDistanceLabel, '20.6 mi away');

        final discoveredArtists =
            container.read(artistsWithDistanceProvider).value;
        expect(discoveredArtists, isNotNull);
        expect(discoveredArtists!.length, 1);
        expect(discoveredArtists.single.name, 'Rowan Vale');
        expect(discoveredArtists.single.distanceMiles, closeTo(20.6, 0.2));
        expect(discoveredArtists.single.distance, expectedDistanceLabel);

        // ---------------------------------------------------------------------
        // STEP D: Render Client BrowseArtistsScreen & verify live UI + real-time updates
        // ---------------------------------------------------------------------
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: BrowseArtistsScreen(authService: fakeAuth),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(ArtistCard), findsOneWidget);
        expect(find.text('Rowan Vale'), findsOneWidget);
        expect(find.text('20.6 mi away'), findsOneWidget);

        // Real-time stream verification: A 2nd Artist completes onboarding in Beaverton, OR
        // while the Client discovery screen is open (no restart!).
        await container.read(artistRepositoryProvider).saveArtistOnboarding(
              uid: 'artist_beaverton_soren',
              displayName: 'Soren Pike',
              username: 'sorenpike',
              styles: const ['Fine Line'],
              studioInformation: const StudioInformation(
                name: 'Cedar & Ash Studio',
                city: 'Beaverton',
                state: 'OR',
                postalCode: '97005',
                latitude: 45.4871,
                longitude: -122.8037,
                isPrivateStudio: false,
                studioType: 'Street Shop',
              ),
              minDeposit: 90,
              isBooksOpen: true,
            );
        await tester.pumpAndSettle();

        // Stream immediately emits 2 live artists without app restart
        final updatedList = container.read(artistsWithDistanceProvider).value!;
        expect(updatedList.length, 2);
        final beavertonArtist =
            updatedList.firstWhere((a) => a.id == 'artist_beaverton_soren');
        final expectedBeavertonMiles = DistanceCalculator.calculateMiles(
          startLatitude: 45.3001,
          startLongitude: -122.9731,
          endLatitude: 45.4871,
          endLongitude: -122.8037,
        );
        expect(
          beavertonArtist.distance,
          DistanceCalculator.formatMilesAway(expectedBeavertonMiles),
        );

        // Open Rowan Vale's ArtistProfileScreen and verify live distance on profile header/stats
        await tester.tap(find.text('VIEW PROFILE').first);
        await tester.pumpAndSettle();

        expect(find.byType(ArtistProfileScreen), findsOneWidget);
        expect(find.text('20.6 mi away'), findsOneWidget);

        // Dynamically update Client's live GPS coordinates (simulating Client driving into Downtown Portland)
        container.read(liveGpsCoordinatesProvider.notifier).setCoordinates(
              const GeoPointCoords(
                latitude: 45.5202,
                longitude: -122.6844,
              ),
            );
        await tester.pumpAndSettle();

        final updatedDowntownMiles = DistanceCalculator.calculateMiles(
          startLatitude: 45.5202,
          startLongitude: -122.6844,
          endLatitude: 45.5152,
          endLongitude: -122.6784,
        );
        final updatedDowntownLabel =
            DistanceCalculator.formatMilesAway(updatedDowntownMiles);
        expect(updatedDowntownMiles, closeTo(0.45, 0.1));

        // ArtistProfileScreen reactively updates to the new live distance without navigation or restart!
        expect(find.text(updatedDowntownLabel), findsOneWidget);
        expect(find.text('20.6 mi away'), findsNothing);
      },
    );
  });
}
