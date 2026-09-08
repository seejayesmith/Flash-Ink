import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flash_ink/models/artist.dart';
import 'package:flash_ink/screens/artist_profile_screen.dart';
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
          // Verify broken 404 URL is not present
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
      }
    });

    test('Artist copyWith supports flashArtworks', () {
      final artist = Artist.mockArtists.first;
      final customPiece = const FlashArtwork(
        id: 'test_1',
        title: 'Custom Tiger',
        imageUrl: 'https://example.com/tiger.jpg',
        location: 'Arm',
        deposit: 100,
        size: '5" x 7"',
      );
      final updated = artist.copyWith(flashArtworks: [customPiece]);
      expect(updated.flashArtworks.length, 1);
      expect(updated.flashArtworks.first.title, 'Custom Tiger');
    });
  });

  group('ArtistProfileScreen Widget Tests', () {
    testWidgets('Renders artist details, stats, and expanded flash artwork list', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
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
      expect(find.text('Available Flash'), findsOneWidget);
      expect(find.text('${artist.flashArtworks.length}'), findsOneWidget);

      // Verify flash artwork titles render
      expect(find.text(artist.flashArtworks[0].title), findsOneWidget);
      expect(find.text(artist.flashArtworks[1].title), findsOneWidget);
    });

    testWidgets('Tapping a flash piece opens the detail bottom sheet', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final artist = Artist.mockArtists.first;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ArtistProfileScreen(artist: artist),
          ),
        ),
      );

      // Tap first piece
      final firstPieceFinder = find.text(artist.flashArtworks[0].title);
      await tester.tap(firstPieceFinder);
      await tester.pumpAndSettle();

      // Bottom sheet should open with claim button
      expect(find.text('CLAIM & BOOK FLASH'), findsOneWidget);
      expect(find.text('PLACEMENT'), findsOneWidget);
      expect(find.text('SIZE'), findsOneWidget);
      expect(find.text('DEPOSIT'), findsOneWidget);

      // Tap Claim button
      await tester.tap(find.text('CLAIM & BOOK FLASH'));
      await tester.pumpAndSettle();

      // Verify sheet dismissed and confirmation snackbar shown
      expect(find.text('CLAIM & BOOK FLASH'), findsNothing);
      expect(find.textContaining('Proceeding to booking deposit'), findsOneWidget);
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
