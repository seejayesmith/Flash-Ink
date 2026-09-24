import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flash_ink/models/artist.dart';
import 'package:flash_ink/screens/artist_profile_screen.dart';
import 'package:flash_ink/screens/custom_request_screen.dart';
import 'package:flash_ink/screens/flash_details_screen.dart';
import 'package:flash_ink/widgets/artist_card.dart';

void main() {
  group('FlashArtwork & Artist Model Tests', () {
    test('All mock artists have populated flash artworks and 4 grid images', () {
      expect(Artist.mockArtists.length, 4);

      for (final artist in Artist.mockArtists) {
        // Verify artist avatar is configured
        expect(artist.avatarUrl.isNotEmpty, isTrue);
        expect(artist.avatarUrl.startsWith('https://'), isTrue);

        // Featured flash verification
        expect(artist.featuredFlash.title.isNotEmpty, isTrue);
        expect(artist.featuredFlash.imageUrl.isNotEmpty, isTrue);

        // 2x2 Preview images verification
        expect(artist.previewImages.length, 4);
        expect(artist.images.length, 4);
        for (final img in artist.previewImages) {
          expect(img.isNotEmpty, isTrue);
          expect(img.startsWith('https://') || img.startsWith('assets/'), isTrue);
          expect(img.contains('1590246814883-578337424072'), isFalse);
        }

        // Flash artwork verification
        expect(artist.flashArtworks.length, greaterThanOrEqualTo(6));
        for (final flash in artist.flashArtworks) {
          expect(flash.id.isNotEmpty, isTrue);
          expect(flash.artistId.isNotEmpty, isTrue);
          expect(flash.title.isNotEmpty, isTrue);
          expect(flash.imageUrl.startsWith('https://') || flash.imageUrl.startsWith('assets/'), isTrue);
          expect(flash.imageUrl.contains('1590246814883-578337424072'), isFalse);
          expect(flash.price, greaterThan(0));
          expect(flash.deposit, greaterThan(0));
          expect(flash.dimensions.isNotEmpty, isTrue);
          expect(flash.size.isNotEmpty, isTrue);
          expect(flash.estimatedTime.isNotEmpty, isTrue);
          expect(flash.location.isNotEmpty, isTrue);
          expect(flash.status, isA<FlashStatus>());
        }

        // Fun facts and policies verification
        expect(artist.funFacts.length, 3);
        expect(artist.policies.length, 4);
      }
    });

    test('Artist copyWith supports flashArtworks, funFacts, and policies', () {
      final artist = Artist.mockArtists.first;
      final customPiece = const FlashArtwork(
        id: 'test_1',
        title: 'Custom Tiger',
        imageUrl: 'https://example.com/tiger.jpg',
        location: 'Arm',
        deposit: 100,
        size: '5" x 7"',
      );
      final updated = artist.copyWith(
        flashArtworks: [customPiece],
        funFacts: [
          const ArtistFunFact(label: 'Specialty', value: 'Dragons'),
        ],
      );
      expect(updated.flashArtworks.length, 1);
      expect(updated.flashArtworks.first.title, 'Custom Tiger');
      expect(updated.funFacts.first.value, 'Dragons');
    });
  });

  group('ArtistProfileScreen Widget Tests', () {
    testWidgets('Renders artist details, stats, fun facts, custom request, and policies', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final artist = Artist.mockArtists.first;

      await tester.pumpWidget(
        MaterialApp(
          home: ArtistProfileScreen(artist: artist),
        ),
      );

      // Verify artist name and stats
      expect(find.text(artist.name), findsOneWidget);
      expect(find.text(artist.location), findsOneWidget);
      expect(find.text(artist.studioType), findsOneWidget);
      expect(find.text('Books open'), findsOneWidget);

      // Verify stats
      expect(find.text('RATING'), findsOneWidget);
      expect(find.text('AVAIL PIECES'), findsOneWidget);
      expect(find.text('MIN DEPOSIT'), findsOneWidget);

      // Verify fun facts
      for (final fact in artist.funFacts) {
        expect(find.text(fact.label), findsOneWidget);
        expect(find.text(fact.value), findsOneWidget);
      }

      // Verify Custom Request banner
      expect(find.text('Got an idea? Submit a Custom Request.'), findsOneWidget);

      // Verify segmented view toggles
      expect(find.text('Available'), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);

      // Verify available flash items
      final availablePieces = artist.flashArtworks
          .where((p) => p.status != FlashStatus.claimed)
          .toList();
      for (int i = 0; i < availablePieces.take(6).length; i++) {
        expect(find.text(availablePieces[i].title), findsOneWidget);
      }

      // Verify Studio Policies section
      expect(find.text('STUDIO POLICIES & HOUSE RULES'), findsOneWidget);
      expect(find.text('VERIFIED STUDIO'), findsOneWidget);
      for (final policy in artist.policies) {
        expect(find.text(policy.title), findsOneWidget);
      }
    });

    testWidgets('Switching to Completed tab filters completed pieces', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final artist = Artist.mockArtists.first;

      await tester.pumpWidget(
        MaterialApp(
          home: ArtistProfileScreen(artist: artist),
        ),
      );

      // Tap Completed tab
      await tester.tap(find.text('Completed'));
      await tester.pumpAndSettle();

      final claimedPieces = artist.flashArtworks
          .where((p) => p.status == FlashStatus.claimed)
          .toList();
      for (final piece in claimedPieces) {
        expect(find.text(piece.title), findsOneWidget);
      }
    });

    testWidgets('Tapping Load More reveals additional flash pieces', (tester) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final artist = Artist.mockArtists.first;

      await tester.pumpWidget(
        MaterialApp(
          home: ArtistProfileScreen(artist: artist),
        ),
      );

      // Initially piece #7 is not rendered
      expect(find.text(artist.flashArtworks[6].title), findsNothing);

      // Tap Load More
      final loadMoreFinder = find.text('Load More');
      await tester.ensureVisible(loadMoreFinder);
      await tester.tap(loadMoreFinder);
      await tester.pumpAndSettle();

      // Now piece #7 is visible
      expect(find.text(artist.flashArtworks[6].title), findsOneWidget);
    });

    testWidgets('Tapping a flash piece navigates to FlashDetailsScreen', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final artist = Artist.mockArtists.first;

      await tester.pumpWidget(
        MaterialApp(
          home: ArtistProfileScreen(artist: artist),
        ),
      );

      // Tap first flash piece
      final firstPieceFinder = find.text(artist.flashArtworks[0].title);
      await tester.tap(firstPieceFinder);
      await tester.pumpAndSettle();

      // Verify FlashDetailsScreen opened
      expect(find.byType(FlashDetailsScreen), findsOneWidget);
      expect(find.text('CLAIM & BOOK FLASH'), findsOneWidget);
      expect(find.text('PLACEMENT'), findsOneWidget);
      expect(find.text('SIZE'), findsOneWidget);
      expect(find.text('DEPOSIT'), findsOneWidget);

      // Tap Claim button
      await tester.tap(find.text('CLAIM & BOOK FLASH'));
      await tester.pump();

      // Verify confirmation snackbar
      expect(find.textContaining('Reserved "'), findsOneWidget);
    });

    testWidgets('Tapping Custom Request banner navigates to CustomRequestScreen', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final artist = Artist.mockArtists.first;

      await tester.pumpWidget(
        MaterialApp(
          home: ArtistProfileScreen(artist: artist),
        ),
      );

      // Tap custom request banner
      final bannerFinder = find.text('Got an idea? Submit a Custom Request.');
      await tester.tap(bannerFinder);
      await tester.pumpAndSettle();

      // Verify CustomRequestScreen is displayed
      expect(find.byType(CustomRequestScreen), findsOneWidget);
      expect(find.text('Custom Tattoo Brief'), findsOneWidget);
      expect(find.text('SUBMIT CUSTOM BRIEF'), findsOneWidget);
    });

    testWidgets('AppBar is transparent with surfaceTintColor and scrolledUnderElevation set to 0', (tester) async {
      final artist = Artist.mockArtists.first;
      await tester.pumpWidget(
        MaterialApp(
          home: ArtistProfileScreen(artist: artist),
        ),
      );

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.backgroundColor, Colors.transparent);
      expect(appBar.surfaceTintColor, Colors.transparent);
      expect(appBar.elevation, 0.0);
      expect(appBar.scrolledUnderElevation, 0.0);
    });
  });

  group('ArtistCard Fallback Safety Tests', () {
    testWidgets('ArtistCard safely renders when images list is empty or minimal', (tester) async {
      const minimalArtist = Artist(
        id: 'min_1',
        name: 'Test Artist',
        avatarUrl: 'https://example.com/avatar.jpg',
        location: 'Portland, OR',
        studioType: 'Independent',
        rating: 5.0,
        availablePieces: 2,
        minDeposit: 50,
        images: ['https://example.com/single.jpg'],
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 500,
              width: 380,
              child: ArtistCard(artist: minimalArtist),
            ),
          ),
        ),
      );

      expect(find.text('Test Artist'), findsOneWidget);
      expect(find.text('Independent'), findsOneWidget);
      expect(find.byType(ArtistCard), findsOneWidget);
    });

    testWidgets('ArtistCard renders full 2x2 artwork showcase, stats row, and VIEW PROFILE CTA', (tester) async {
      final artist = Artist.mockArtists.first;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 520,
              width: 380,
              child: ArtistCard(artist: artist),
            ),
          ),
        ),
      );

      // Artist name, Books open, location, and studio
      expect(find.text(artist.name), findsOneWidget);
      expect(find.text('Books open'), findsOneWidget);
      expect(find.text(artist.location), findsOneWidget);
      expect(find.text(artist.studioType), findsOneWidget);

      // 3-column stats pill
      expect(find.text('RATING'), findsOneWidget);
      expect(find.text(artist.rating.toStringAsFixed(1)), findsOneWidget);
      expect(find.text('AVAIL PIECES'), findsOneWidget);
      expect(find.text('${artist.availablePieces}'), findsOneWidget);
      expect(find.text('MIN DEPOSIT'), findsOneWidget);
      expect(find.text('\$${artist.minDeposit}'), findsOneWidget);

      // Action row: VIEW PROFILE + Favorite button
      expect(find.text('VIEW PROFILE'), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    });
  });
}
