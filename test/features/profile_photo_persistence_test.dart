import 'dart:typed_data';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';

import 'package:flash_ink/models/artist.dart';
import 'package:flash_ink/providers/app_providers.dart';
import 'package:flash_ink/repositories/artist_repository.dart';
import 'package:flash_ink/services/auth_service.dart';
import 'package:flash_ink/screens/artist_profile_screen.dart';
import 'package:flash_ink/screens/client_account_screen.dart';
import 'package:flash_ink/screens/artist_dashboard/artist_account_screen.dart';
import 'package:flash_ink/screens/profile_setup_screen.dart';
import 'package:flash_ink/screens/artist_onboarding/artist_profile_photo_screen.dart';

final sampleBytes = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

class TestUser extends Fake implements User {
  @override
  final String uid;
  @override
  final String? email;
  @override
  final String? displayName;
  @override
  String? photoURL;

  TestUser({
    this.uid = 'test_user_photo',
    this.email = 'tester@flash.ink',
    this.displayName = 'Photo Tester',
    this.photoURL,
  });

  @override
  Future<void> updatePhotoURL(String? photoUri) async {
    photoURL = photoUri;
  }

  @override
  Future<void> reload() async {}
}

class TestAuthService extends AuthService {
  final TestUser? testUser;
  TestAuthService({this.testUser});

  @override
  User? get currentUser => testUser ?? TestUser();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  group('Profile Photo Persistence & DevMockUser Tests', () {
    test('DevMockUser updates and preserves photoURL', () async {
      final mock = DevMockUser(
        uid: 'dev_user_1',
        displayName: 'Dev Tester',
        email: 'dev@flash.ink',
      );

      expect(mock.photoURL, isNull);

      await mock.updatePhotoURL('https://example.com/new_avatar.png');
      expect(mock.photoURL, 'https://example.com/new_avatar.png');

      await mock.updatePhotoURL(null);
      expect(mock.photoURL, isNull);
    });

    testWidgets('ProfileSetupScreen renders Add a profile photo title and avatar placeholder', (tester) async {
      final user = TestUser();
      final auth = TestAuthService(testUser: user);

      await tester.pumpWidget(
        MaterialApp(
          home: ProfileSetupScreen(authService: auth),
        ),
      );
      await tester.pumpAndSettle();

      // Enter username to advance to photo step
      await tester.enterText(find.byType(TextField), 'OddMaree');
      await tester.pump();
      await tester.tap(find.text('CONTINUE'));
      await tester.pumpAndSettle();

      // Verify title is "Add a profile photo"
      expect(find.text('Add a profile photo'), findsOneWidget);
      expect(find.text('Show the community who you are!\nYou can always change this later.'), findsOneWidget);
    });

    testWidgets('ClientAccountScreen displays photoURL when present on user', (tester) async {
      final userWithPhoto = TestUser(photoURL: 'https://example.com/custom_avatar.png');
      final auth = TestAuthService(testUser: userWithPhoto);

      await tester.pumpWidget(
        MaterialApp(
          home: ClientAccountScreen(authService: auth),
        ),
      );
      await tester.pumpAndSettle();

      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);
      final imageWidget = tester.widget<Image>(imageFinder);
      expect((imageWidget.image as NetworkImage).url, 'https://example.com/custom_avatar.png');
    });

    testWidgets('ArtistProfilePhotoScreen renders with initial photo and calls updatePhotoURL on continue', (tester) async {
      final user = TestUser();
      final auth = TestAuthService(testUser: user);

      await tester.pumpWidget(
        MaterialApp(
          home: ArtistProfilePhotoScreen(
            artistName: 'OddMaree',
            initialImageBytes: sampleBytes,
            authService: auth,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Add a profile photo'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // After continuing, user.photoURL is updated (fallback or downloadUrl)
      expect(user.photoURL, isNotNull);
    });

    testWidgets('ArtistAccountScreen displays updated photoURL', (tester) async {
      final user = TestUser(photoURL: 'https://example.com/artist_photo.png');
      final auth = TestAuthService(testUser: user);

      await tester.pumpWidget(
        MaterialApp(
          home: ArtistAccountScreen(authService: auth),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('artist_account_avatar_edit')), findsOneWidget);
    });

    testWidgets('ArtistProfilePhotoScreen pre-fills existing account photo with Continue enabled', (tester) async {
      final fakeDb = FakeFirebaseFirestore();
      final user = TestUser(
        uid: 'existing_client_uid',
        photoURL: 'https://example.com/existing_poodle.jpg',
      );
      final auth = TestAuthService(testUser: user);

      await tester.pumpWidget(
        MaterialApp(
          home: ArtistProfilePhotoScreen(
            artistName: 'CJ Smith',
            authService: auth,
            firestore: fakeDb,
          ),
        ),
      );
      await tester.pump();

      // Existing photo hides "Skip for now" and enables "Continue"
      expect(find.text('Skip for now'), findsNothing);
      expect(find.text('Continue'), findsOneWidget);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Navigates to Studio Bio step and syncs photo to /artists/{uid} and /users/{uid}
      expect(find.text('Where do you tattoo?'), findsOneWidget);
      final artistSnap = await fakeDb.collection('artists').doc('existing_client_uid').get();
      expect(artistSnap.data()?['avatarUrl'], 'https://example.com/existing_poodle.jpg');
      final userSnap = await fakeDb.collection('users').doc('existing_client_uid').get();
      expect(userSnap.data()?['photoUrl'], 'https://example.com/existing_poodle.jpg');
    });

    test('saveArtistOnboarding inherits existing photo from /users/{uid} when avatarUrl is empty', () async {
      final fakeDb = FakeFirebaseFirestore();
      await fakeDb.collection('users').doc('artist_123').set({
        'uid': 'artist_123',
        'displayName': 'CJ Smith',
        'photoUrl': 'https://example.com/client_photo.jpg',
      });

      final repo = ArtistRepository(firestore: fakeDb);
      final saved = await repo.saveArtistOnboarding(
        uid: 'artist_123',
        displayName: 'CJ Smith',
        avatarUrl: '',
        fallbackLocation: 'Portland, OR',
      );

      expect(saved.avatarUrl, 'https://example.com/client_photo.jpg');
      final artistSnap = await fakeDb.collection('artists').doc('artist_123').get();
      expect(artistSnap.data()?['avatarUrl'], 'https://example.com/client_photo.jpg');
      expect(artistSnap.data()?['photoUrl'], 'https://example.com/client_photo.jpg');
    });

    test('syncUnifiedProfilePhoto syncs upload and removal across /users/{uid} and /artists/{uid}', () async {
      final fakeDb = FakeFirebaseFirestore();
      await fakeDb.collection('users').doc('dual_uid').set({'uid': 'dual_uid'});
      await fakeDb.collection('artists').doc('dual_uid').set({
        'id': 'dual_uid',
        'name': 'CJ Smith',
        'profileCompleted': true,
      });

      await ArtistRepository.syncUnifiedProfilePhoto(
        uid: 'dual_uid',
        photoUrl: 'https://example.com/unified.png',
        firestore: fakeDb,
      );

      var userSnap = await fakeDb.collection('users').doc('dual_uid').get();
      var artistSnap = await fakeDb.collection('artists').doc('dual_uid').get();
      expect(userSnap.data()?['photoUrl'], 'https://example.com/unified.png');
      expect(artistSnap.data()?['avatarUrl'], 'https://example.com/unified.png');

      // Removing photo clears both
      await ArtistRepository.syncUnifiedProfilePhoto(
        uid: 'dual_uid',
        photoUrl: null,
        firestore: fakeDb,
      );

      userSnap = await fakeDb.collection('users').doc('dual_uid').get();
      artistSnap = await fakeDb.collection('artists').doc('dual_uid').get();
      expect(userSnap.data()?['photoUrl'], isNull);
      expect(artistSnap.data()?['avatarUrl'], '');
    });

    testWidgets('artistsWithDistanceProvider backfills empty artist avatarUrl from active user photo', (tester) async {
      final fakeDb = FakeFirebaseFirestore();
      await fakeDb.collection('users').doc('cj_uid').set({
        'uid': 'cj_uid',
        'photoUrl': 'https://example.com/poodle.jpg',
      });
      await fakeDb.collection('artists').doc('cj_uid').set({
        'id': 'cj_uid',
        'name': 'CJ Smith',
        'avatarUrl': '',
        'photoUrl': '',
        'profileCompleted': true,
      });

      final container = ProviderContainer(
        overrides: [
          firebaseFirestoreProvider.overrideWithValue(fakeDb),
          activeUidProvider.overrideWithValue('cj_uid'),
        ],
      );
      addTearDown(container.dispose);

      final sub = container.listen(
        artistsWithDistanceProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(sub.close);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final artistsAsync = container.read(artistsWithDistanceProvider);
      final artists = artistsAsync.value ?? const [];
      expect(artists, hasLength(1));
      expect(artists.first.avatarUrl, 'https://example.com/poodle.jpg');

      await tester.pump(const Duration(milliseconds: 50));
      final artistSnap = await fakeDb.collection('artists').doc('cj_uid').get();
      expect(artistSnap.data()?['avatarUrl'], 'https://example.com/poodle.jpg');
    });

    test('Artist.effectiveBannerUrl defaults to most recent flash photo, uses custom bannerUrl when set, and returns empty when 0 flash exist', () {
      const artistWithThreeFlash = Artist(
        id: 'cj_1',
        name: 'CJ Smith',
        avatarUrl: 'https://example.com/poodle.jpg',
        location: 'Portland, OR',
        studioType: 'Street Shop',
        rating: 5.0,
        availablePieces: 3,
        minDeposit: 20,
        flashArtworks: [
          FlashArtwork(
            id: 'flash_1',
            title: 'Oldest Flash (Poodle)',
            imageUrl: 'https://example.com/flash_1_poodle.jpg',
          ),
          FlashArtwork(
            id: 'flash_2',
            title: 'Middle Flash (Figurine)',
            imageUrl: 'https://example.com/flash_2_figurine.jpg',
          ),
          FlashArtwork(
            id: 'flash_3',
            title: 'Most Recent Flash (Cat)',
            imageUrl: 'https://example.com/flash_3_cat.jpg',
          ),
        ],
      );

      // Default banner is the most recently uploaded flash piece (flash_3_cat.jpg), NOT flash_1_poodle.jpg
      expect(
        artistWithThreeFlash.effectiveBannerUrl,
        'https://example.com/flash_3_cat.jpg',
      );

      // When custom bannerUrl is set, it overrides the default
      final withCustomBanner = artistWithThreeFlash.copyWith(
        bannerUrl: 'https://example.com/custom_studio_banner.jpg',
      );
      expect(
        withCustomBanner.effectiveBannerUrl,
        'https://example.com/custom_studio_banner.jpg',
      );

      // When artist has 0 flash photos and no custom banner, effectiveBannerUrl is empty
      const artistWithNoFlash = Artist(
        id: 'empty_1',
        name: 'New Artist',
        avatarUrl: 'https://example.com/avatar.jpg',
        location: 'Portland, OR',
        studioType: 'Private Studio',
        rating: 5.0,
        availablePieces: 0,
        minDeposit: 50,
      );
      expect(artistWithNoFlash.effectiveBannerUrl, isEmpty);
    });

    testWidgets('ArtistProfileScreen replaces Favorite button with Edit Banner button on own profile and persists banner changes', (tester) async {
      final fakeDb = FakeFirebaseFirestore();
      const artist = Artist(
        id: 'cj_uid',
        name: 'CJ Smith',
        avatarUrl: 'assets/images/flash_traditional_panther.jpg',
        location: 'Portland, OR',
        studioType: 'Street Shop',
        rating: 5.0,
        availablePieces: 2,
        minDeposit: 20,
        flashArtworks: [
          FlashArtwork(
            id: 'f1',
            title: 'First Flash',
            imageUrl: 'assets/images/flash_traditional_panther.jpg',
          ),
          FlashArtwork(
            id: 'f2',
            title: 'Latest Flash',
            imageUrl: 'assets/images/flash_traditional_dagger.jpg',
          ),
        ],
      );
      await fakeDb.collection('artists').doc('cj_uid').set(artist.toMap());

      final ownerUser = TestUser(uid: 'cj_uid', displayName: 'CJ Smith');
      final ownerAuth = TestAuthService(testUser: ownerUser);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            firebaseFirestoreProvider.overrideWithValue(fakeDb),
            activeUidProvider.overrideWithValue('cj_uid'),
          ],
          child: MaterialApp(
            home: ArtistProfileScreen(
              artist: artist,
              authService: ownerAuth,
              firestore: fakeDb,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Favorite heart button is replaced by Edit Banner button on own profile
      expect(find.byKey(const Key('artist_edit_banner_button')), findsOneWidget);
      expect(find.byKey(const Key('artist_favorite_profile_button')), findsNothing);

      // Default banner is the most recent flash (flash_traditional_dagger.jpg)
      expect(
        find.byKey(const ValueKey('artist_banner_image_assets/images/flash_traditional_dagger.jpg')),
        findsOneWidget,
      );

      // Tap Edit Banner button to open bottom sheet
      await tester.tap(find.byKey(const Key('artist_edit_banner_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('banner_source_bottom_sheet')), findsOneWidget);
      expect(find.text('Profile Header Banner'), findsOneWidget);

      // Select the older flash piece (index 1 in newest-first list) as custom banner
      await tester.tap(find.byKey(const Key('banner_flash_option_1')));
      await tester.pumpAndSettle();

      final updatedSnap = await fakeDb.collection('artists').doc('cj_uid').get();
      expect(
        updatedSnap.data()?['bannerUrl'],
        'assets/images/flash_traditional_panther.jpg',
      );
      expect(
        find.byKey(const ValueKey('artist_banner_image_assets/images/flash_traditional_panther.jpg')),
        findsOneWidget,
      );

      // Re-open sheet and reset to most recent flash
      await tester.tap(find.byKey(const Key('artist_edit_banner_button')));
      await tester.pumpAndSettle();
      final resetFinder = find.byKey(const Key('banner_source_reset'));
      expect(resetFinder, findsOneWidget);
      await tester.ensureVisible(resetFinder);
      await tester.tap(resetFinder);
      await tester.pumpAndSettle();

      final resetSnap = await fakeDb.collection('artists').doc('cj_uid').get();
      expect(resetSnap.data()?['bannerUrl'], '');
      expect(
        find.byKey(const ValueKey('artist_banner_image_assets/images/flash_traditional_dagger.jpg')),
        findsOneWidget,
      );
    });
  });
}
