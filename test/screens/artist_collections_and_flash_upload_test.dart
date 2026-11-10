import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';

import 'package:flash_ink/models/artist.dart';
import 'package:flash_ink/screens/artist_dashboard/artist_collections_screen.dart';
import 'package:flash_ink/screens/artist_dashboard/artist_upload_flash_screen.dart';
import 'package:flash_ink/services/auth_service.dart';

class MockTestUser extends Fake implements User {
  @override
  final String uid;
  @override
  final String? displayName;
  @override
  final String? email;
  @override
  final String? photoURL;

  MockTestUser({
    required this.uid,
    this.displayName = 'Artist Test',
    this.email = 'artist@flash.ink',
    this.photoURL = '',
  });
}

class FakeAuthService extends Fake implements AuthService {
  final User? _user;
  FakeAuthService([this._user]);

  @override
  User? get currentUser => _user;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  group('ArtistCollectionsScreen Widget Tests', () {
    late Artist testArtist;
    late AuthService fakeAuth;

    setUp(() {
      fakeAuth = FakeAuthService(
        MockTestUser(uid: 'artist_123', displayName: 'Elena Rostova'),
      );

      testArtist = const Artist(
        id: 'artist_123',
        name: 'Elena Rostova',
        username: '@elena_ink',
        avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb',
        location: 'Portland, OR',
        studioType: 'Private Studio',
        rating: 4.9,
        availablePieces: 2,
        minDeposit: 80,
        flashArtworks: [
          FlashArtwork(
            id: 'flash_1',
            artistId: 'artist_123',
            title: 'Japanese Dragon',
            imageUrl: 'assets/images/flash_traditional_panther.jpg',
            price: 250,
            deposit: 80,
            dimensions: '6" x 8"',
            status: FlashStatus.available,
            category: 'JAPANESE',
          ),
          FlashArtwork(
            id: 'flash_2',
            artistId: 'artist_123',
            title: 'Blackwork Snake',
            imageUrl: 'assets/images/flash_traditional_panther.jpg',
            price: 180,
            deposit: 80,
            dimensions: '4" x 5"',
            status: FlashStatus.claimed,
            category: 'BLACKWORK',
          ),
          FlashArtwork(
            id: 'flash_3',
            artistId: 'artist_123',
            title: 'Neo Panther Head',
            imageUrl: 'assets/images/flash_traditional_panther.jpg',
            price: 200,
            deposit: 80,
            dimensions: '5" x 5"',
            status: FlashStatus.repeatable,
            category: 'TRADITIONAL',
          ),
        ],
      );
    });

    Widget buildTestScreen(WidgetTester tester, {Artist? artist}) {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      return MaterialApp(
        home: Scaffold(
          body: ArtistCollectionsScreen(
            artist: artist ?? testArtist,
            authService: fakeAuth,
          ),
        ),
      );
    }

    testWidgets('Renders all essential Collections header elements and grid', (tester) async {
      await tester.pumpWidget(buildTestScreen(tester));
      await tester.pumpAndSettle();

      // Top action bar
      expect(find.byKey(const Key('collections_tattoo_machine_logo')), findsOneWidget);
      expect(find.byKey(const Key('top_action_messages_button')), findsOneWidget);
      expect(find.byKey(const Key('collections_artist_avatar_button')), findsOneWidget);

      // Header row
      expect(find.text('Flash Collections'), findsOneWidget);
      expect(find.text('2 available • 3 total pieces'), findsOneWidget);
      expect(find.byKey(const Key('add_new_flash_button')), findsOneWidget);

      // Filter tabs
      expect(find.byKey(const Key('filter_tab_available')), findsOneWidget);
      expect(find.byKey(const Key('filter_tab_claimed')), findsOneWidget);
      expect(find.byKey(const Key('filter_tab_all')), findsOneWidget);

      // Default filter is Available: displays flash_1 and flash_3
      expect(find.text('Japanese Dragon'), findsOneWidget);
      expect(find.text('Neo Panther Head'), findsOneWidget);
      expect(find.text('Blackwork Snake'), findsNothing);
    });

    testWidgets('Switching filter tabs correctly partitions available vs claimed artworks', (tester) async {
      await tester.pumpWidget(buildTestScreen(tester));
      await tester.pumpAndSettle();

      // Switch to Claimed filter
      await tester.tap(find.byKey(const Key('filter_tab_claimed')));
      await tester.pumpAndSettle();

      expect(find.text('Blackwork Snake'), findsOneWidget);
      expect(find.text('Japanese Dragon'), findsNothing);
      expect(find.text('Neo Panther Head'), findsNothing);

      // Switch to All filter
      await tester.tap(find.byKey(const Key('filter_tab_all')));
      await tester.pumpAndSettle();

      expect(find.text('Japanese Dragon'), findsOneWidget);
      expect(find.text('Blackwork Snake'), findsOneWidget);
      expect(find.text('Neo Panther Head'), findsOneWidget);
    });

    testWidgets('Renders empty state when no artworks exist for selected filter', (tester) async {
      final emptyArtist = testArtist.copyWith(flashArtworks: []);

      await tester.pumpWidget(buildTestScreen(tester, artist: emptyArtist));
      await tester.pumpAndSettle();

      expect(find.text('No Flash Works in this Filter'), findsOneWidget);
      expect(find.byKey(const Key('empty_state_upload_flash_button')), findsOneWidget);
    });

    testWidgets('Tapping artwork card opens detail modal with full actions', (tester) async {
      await tester.pumpWidget(buildTestScreen(tester));
      await tester.pumpAndSettle();

      // Tap first available piece card
      await tester.tap(find.text('Japanese Dragon'));
      await tester.pumpAndSettle();

      // Detail sheet verification
      expect(find.text('Price: \$250'), findsOneWidget);
      expect(find.text('Deposit: \$80'), findsOneWidget);
      expect(find.text('Size: 6" x 8"'), findsOneWidget);
      expect(find.text('Style: JAPANESE'), findsOneWidget);

      // Action buttons
      expect(find.byKey(const Key('modal_edit_flash_button')), findsOneWidget);
      expect(find.byKey(const Key('modal_toggle_status_button')), findsOneWidget);
      expect(find.byKey(const Key('modal_delete_flash_button')), findsOneWidget);
    });

    testWidgets('Toggling artwork status switches between Available and Claimed', (tester) async {
      await tester.pumpWidget(buildTestScreen(tester));
      await tester.pumpAndSettle();

      // Open Japanese Dragon modal
      await tester.tap(find.text('Japanese Dragon'));
      await tester.pumpAndSettle();

      // Mark as Claimed
      await tester.tap(find.byKey(const Key('modal_toggle_status_button')));
      await tester.pumpAndSettle();

      // Success SnackBar
      expect(find.text('Flash piece marked as Claimed'), findsOneWidget);

      // Japanese Dragon is now Claimed, so under Available filter it disappears
      expect(find.text('Japanese Dragon'), findsNothing);

      // Switch to Claimed filter -> Japanese Dragon is present
      await tester.tap(find.byKey(const Key('filter_tab_claimed')));
      await tester.pumpAndSettle();

      expect(find.text('Japanese Dragon'), findsOneWidget);
    });

    testWidgets('Deleting an artwork prompts confirmation and removes piece from collection', (tester) async {
      await tester.pumpWidget(buildTestScreen(tester));
      await tester.pumpAndSettle();

      // Open Japanese Dragon modal
      await tester.tap(find.text('Japanese Dragon'));
      await tester.pumpAndSettle();

      // Tap Delete Flash Piece
      await tester.tap(find.byKey(const Key('modal_delete_flash_button')));
      await tester.pumpAndSettle();

      // Confirmation dialog
      expect(find.text('Delete Flash Artwork?'), findsOneWidget);
      final confirmDelete = find.byKey(const Key('confirm_delete_flash_button'));
      expect(confirmDelete, findsOneWidget);

      await tester.tap(confirmDelete);
      await tester.pumpAndSettle();

      // Verification
      expect(find.text('"Japanese Dragon" deleted from Collections'), findsOneWidget);
      expect(find.text('Japanese Dragon'), findsNothing);
    });
  });

  group('ArtistUploadFlashScreen Widget Tests', () {
    late AuthService fakeAuth;
    late Artist testArtist;

    setUp(() {
      fakeAuth = FakeAuthService(
        MockTestUser(uid: 'artist_123', displayName: 'Elena Rostova'),
      );

      testArtist = const Artist(
        id: 'artist_123',
        name: 'Elena Rostova',
        username: '@elena_ink',
        avatarUrl: '',
        location: 'Portland, OR',
        studioType: 'Private Studio',
        rating: 4.9,
        availablePieces: 1,
        minDeposit: 80,
      );
    });

    Widget buildUploadScreen(WidgetTester tester, {FlashArtwork? existingArtwork}) {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      return MaterialApp(
        home: ArtistUploadFlashScreen(
          artist: testArtist,
          existingArtwork: existingArtwork,
          authService: fakeAuth,
          initialAssetPath: 'assets/images/flash_traditional_panther.jpg',
        ),
      );
    }

    testWidgets('Renders all creation form fields in default state', (tester) async {
      await tester.pumpWidget(buildUploadScreen(tester));
      await tester.pumpAndSettle();

      expect(find.text('Upload Flash Piece'), findsOneWidget);
      expect(find.byKey(const Key('flash_artwork_photo_selector')), findsOneWidget);
      expect(find.byKey(const Key('flash_title_input')), findsOneWidget);
      expect(find.byKey(const Key('flash_price_input')), findsOneWidget);
      expect(find.byKey(const Key('flash_deposit_input')), findsOneWidget);
      expect(find.byKey(const Key('flash_dimensions_input')), findsOneWidget);
      expect(find.byKey(const Key('flash_repeatable_switch')), findsOneWidget);
      expect(find.byKey(const Key('publish_flash_button')), findsOneWidget);
      expect(find.text('PUBLISH FLASH'), findsOneWidget);
    });

    testWidgets('Validation blocks submission when required title is empty', (tester) async {
      await tester.pumpWidget(buildUploadScreen(tester));
      await tester.pumpAndSettle();

      // Clear title and tap Publish
      await tester.enterText(find.byKey(const Key('flash_title_input')), '');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('publish_flash_button')));
      await tester.pumpAndSettle();

      expect(find.text('Title is required'), findsOneWidget);
    });

    testWidgets('Submitting valid form closes screen and returns new FlashArtwork', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      FlashArtwork? createdResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                key: const Key('open_upload_button'),
                onPressed: () async {
                  createdResult = await Navigator.push<FlashArtwork?>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ArtistUploadFlashScreen(
                        artist: testArtist,
                        authService: fakeAuth,
                        initialAssetPath: 'assets/images/flash_traditional_panther.jpg',
                      ),
                    ),
                  );
                },
                child: const Text('Open Upload'),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open screen
      await tester.tap(find.byKey(const Key('open_upload_button')));
      await tester.pumpAndSettle();

      // Enter details
      await tester.enterText(find.byKey(const Key('flash_title_input')), 'Cyber Skull');
      await tester.enterText(find.byKey(const Key('flash_price_input')), '300');
      await tester.enterText(find.byKey(const Key('flash_deposit_input')), '100');
      await tester.enterText(find.byKey(const Key('flash_dimensions_input')), '5" x 7"');
      await tester.pumpAndSettle();

      // Select Realism style
      await tester.tap(find.byKey(const Key('style_chip_realism')));
      await tester.pumpAndSettle();

      // Publish
      await tester.tap(find.byKey(const Key('publish_flash_button')));
      await tester.pumpAndSettle();

      expect(createdResult, isNotNull);
      expect(createdResult!.title, 'Cyber Skull');
      expect(createdResult!.price, 300);
      expect(createdResult!.deposit, 100);
      expect(createdResult!.dimensions, '5" x 7"');
      expect(createdResult!.category, 'REALISM');
    });

    testWidgets('Editing existing artwork pre-populates fields and shows SAVE CHANGES CTA', (tester) async {
      const existing = FlashArtwork(
        id: 'flash_existing_1',
        title: 'Original Panther',
        imageUrl: 'assets/images/flash_traditional_panther.jpg',
        price: 160,
        deposit: 60,
        dimensions: '3" x 3"',
        status: FlashStatus.available,
        category: 'TRADITIONAL',
      );

      await tester.pumpWidget(buildUploadScreen(tester, existingArtwork: existing));
      await tester.pumpAndSettle();

      expect(find.text('Edit Flash Piece'), findsOneWidget);
      expect(find.text('SAVE CHANGES'), findsOneWidget);
      expect(find.text('Original Panther'), findsOneWidget);
      expect(find.text('160'), findsOneWidget);
      expect(find.text('60'), findsOneWidget);
      expect(find.text('3" x 3"'), findsOneWidget);
    });
  });
}
