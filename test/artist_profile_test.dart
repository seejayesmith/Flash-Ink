import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flash_ink/features/artist/presentation/widgets/artist_stats_row.dart';
import 'package:flash_ink/features/artist/presentation/widgets/custom_request_banner.dart';
import 'package:flash_ink/models/artist.dart';
import 'package:flash_ink/screens/artist_profile_screen.dart';
import 'package:flash_ink/screens/custom_request_screen.dart';
import 'package:flash_ink/screens/flash_details_screen.dart';
import 'package:flash_ink/features/artist/presentation/widgets/flash_piece_card.dart';
import 'package:flash_ink/models/artist_dashboard_data.dart';
import 'package:flash_ink/screens/booking/flash_booking_screen.dart';
import 'package:flash_ink/services/booking_sync_service.dart';
import 'package:flash_ink/theme/app_theme.dart';
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
      tester.view.physicalSize = const Size(800, 3600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final artist = Artist.mockArtists.first;

      await tester.pumpWidget(
        MaterialApp(
          home: ArtistProfileScreen(artist: artist),
        ),
      );

      // Verify artist name, studio name, and books open
      expect(find.text(artist.name), findsOneWidget);
      expect(find.text(artist.studioType), findsOneWidget);
      expect(find.text('Books open'), findsOneWidget);

      // Verify stats
      expect(find.text('DISTANCE'), findsOneWidget);
      expect(find.text(artist.distance), findsOneWidget);
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

      // Verify caption directly below the CTA button
      expect(
        find.text('\$${artist.flashArtworks[0].deposit} deposit reserves this exclusive piece • Applied to final balance'),
        findsOneWidget,
      );
      // Verify old standalone deposit info card is removed
      expect(
        find.textContaining('Claiming reserves this exclusive piece. The \$'),
        findsNothing,
      );

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

    testWidgets('ArtistStatsRow renders with solid card background and no gradients', (tester) async {
      final artist = Artist.mockArtists.first;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ArtistStatsRow(artist: artist),
          ),
        ),
      );

      final containerFinder = find.descendant(
        of: find.byType(ArtistStatsRow),
        matching: find.byType(Container),
      );
      expect(containerFinder, findsWidgets);

      final container = tester.widget<Container>(containerFinder.first);
      final decoration = container.decoration as BoxDecoration?;
      expect(decoration, isNotNull);
      expect(decoration!.color, equals(AppTheme.cardBackground));
      expect(decoration.gradient, isNull);
    });

    testWidgets('CustomRequestBanner renders with subtle gold-to-dark gradient decoration', (tester) async {
      final artist = Artist.mockArtists.first;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomRequestBanner(artist: artist),
          ),
        ),
      );

      final inkFinder = find.descendant(
        of: find.byType(CustomRequestBanner),
        matching: find.byType(Ink),
      );
      expect(inkFinder, findsOneWidget);

      final ink = tester.widget<Ink>(inkFinder);
      final decoration = ink.decoration as BoxDecoration?;
      expect(decoration, isNotNull);
      expect(decoration!.gradient, isA<LinearGradient>());
      final gradient = decoration.gradient as LinearGradient;
      expect(gradient.colors, equals(const [Color(0xFF262218), Color(0xFF141717)]));
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

      // Artist name, Books open, and studio
      expect(find.text(artist.name), findsOneWidget);
      expect(find.text('Books open'), findsOneWidget);
      expect(find.text(artist.studioType), findsOneWidget);

      // 3-column stats pill
      expect(find.text('DISTANCE'), findsOneWidget);
      expect(find.text(artist.distance), findsOneWidget);
      expect(find.text('AVAIL PIECES'), findsOneWidget);
      expect(find.text('${artist.availablePieces}'), findsOneWidget);
      expect(find.text('MIN DEPOSIT'), findsOneWidget);
      expect(find.text('\$${artist.minDeposit}'), findsOneWidget);

      // Action row: VIEW PROFILE + Favorite button
      expect(find.text('VIEW PROFILE'), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    });
  });

  group('FlashDetailsScreen Bottom Bar Caption Tests', () {
    testWidgets('Shows fallback caption for non-exclusive / repeatable piece', (tester) async {
      final artist = Artist.mockArtists.first;
      const repeatablePiece = FlashArtwork(
        id: 'repeatable_1',
        title: 'Wave Motif',
        imageUrl: 'https://example.com/wave.jpg',
        deposit: 75,
        status: FlashStatus.repeatable,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: FlashDetailsScreen(
            flash: repeatablePiece,
            artist: artist,
          ),
        ),
      );

      // Verify repeatable piece fallback caption
      expect(
        find.text('\$75 deposit goes towards final balance'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
      expect(find.text('Designed by ${artist.name}'), findsOneWidget);
    });

    testWidgets('Hides deposit caption when piece is already claimed', (tester) async {
      final artist = Artist.mockArtists.first;
      const claimedPiece = FlashArtwork(
        id: 'claimed_1',
        title: 'Sacred Serpent',
        imageUrl: 'https://example.com/serpent.jpg',
        deposit: 60,
        status: FlashStatus.claimed,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: FlashDetailsScreen(
            flash: claimedPiece,
            artist: artist,
          ),
        ),
      );

      // Button should reflect claimed state
      expect(find.text('PIECE ALREADY CLAIMED'), findsOneWidget);

      // Caption should be hidden
      expect(
        find.textContaining('deposit reserves this exclusive piece'),
        findsNothing,
      );
      expect(
        find.textContaining('deposit goes towards final balance'),
        findsNothing,
      );
    });

    testWidgets('Disclaimer caption is below the CTA button, centered, and does not truncate', (tester) async {
      final artist = Artist.mockArtists.first;
      const exclusivePiece = FlashArtwork(
        id: 'ex_1',
        title: 'Sacred Serpent',
        imageUrl: 'https://example.com/serpent.jpg',
        deposit: 60,
        status: FlashStatus.available,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: FlashDetailsScreen(
            flash: exclusivePiece,
            artist: artist,
          ),
        ),
      );

      final ctaFinder = find.widgetWithText(ElevatedButton, 'CLAIM & BOOK FLASH');
      final disclaimerFinder = find.text('\$60 deposit reserves this exclusive piece • Applied to final balance');

      expect(ctaFinder, findsOneWidget);
      expect(disclaimerFinder, findsOneWidget);

      // Verify disclaimer is positioned below the CTA button
      final ctaBottomY = tester.getBottomLeft(ctaFinder).dy;
      final disclaimerTopY = tester.getTopLeft(disclaimerFinder).dy;
      expect(disclaimerTopY, greaterThan(ctaBottomY));

      // Verify text is centered and not truncated
      final textWidget = tester.widget<Text>(disclaimerFinder);
      expect(textWidget.textAlign, TextAlign.center);
      expect(textWidget.maxLines, isNull);
      expect(textWidget.overflow, isNull);
    });
  });

  group('Exclusive Badge Widget & Model Tests', () {
    test('FlashArtwork.isExclusive defaults correctly and supports explicit override', () {
      const availablePiece = FlashArtwork(
        id: 'ex_1',
        title: 'Exclusive Piece',
        imageUrl: 'https://example.com/ex1.jpg',
        status: FlashStatus.available,
      );
      expect(availablePiece.isExclusive, isTrue);

      const repeatablePiece = FlashArtwork(
        id: 'rep_1',
        title: 'Repeatable Piece',
        imageUrl: 'https://example.com/rep1.jpg',
        status: FlashStatus.repeatable,
      );
      expect(repeatablePiece.isExclusive, isFalse);

      const claimedPiece = FlashArtwork(
        id: 'claim_1',
        title: 'Claimed Piece',
        imageUrl: 'https://example.com/claim1.jpg',
        status: FlashStatus.claimed,
      );
      expect(claimedPiece.isExclusive, isTrue);

      final explicitOverride = repeatablePiece.copyWith(isExclusive: true);
      expect(explicitOverride.isExclusive, isTrue);
    });

    testWidgets('FlashPieceCard renders EXCLUSIVE badge for available 1-of-1 piece', (tester) async {
      const exclusivePiece = FlashArtwork(
        id: 'ex_card_1',
        title: 'Lone Wolf',
        imageUrl: 'assets/images/flash_traditional_dagger.jpg',
        location: 'Forearm',
        size: '5" x 7"',
        deposit: 60,
        status: FlashStatus.available,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 180,
              height: 280,
              child: FlashPieceCard(piece: exclusivePiece),
            ),
          ),
        ),
      );

      expect(find.text('EXCLUSIVE'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    });

    testWidgets('FlashPieceCard does not render EXCLUSIVE badge for repeatable piece', (tester) async {
      const repeatablePiece = FlashArtwork(
        id: 'rep_card_1',
        title: 'Wave Motif',
        imageUrl: 'assets/images/flash_traditional_dagger.jpg',
        location: 'Forearm',
        size: '5" x 7"',
        deposit: 60,
        status: FlashStatus.repeatable,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 180,
              height: 280,
              child: FlashPieceCard(piece: repeatablePiece),
            ),
          ),
        ),
      );

      expect(find.text('EXCLUSIVE'), findsNothing);
      expect(find.text('REPEATABLE'), findsNothing);
    });

    testWidgets('FlashPieceCard renders CLAIMED badge for claimed piece', (tester) async {
      const claimedPiece = FlashArtwork(
        id: 'claimed_card_1',
        title: 'Sacred Dagger',
        imageUrl: 'assets/images/flash_traditional_dagger.jpg',
        location: 'Forearm',
        size: '5" x 7"',
        deposit: 60,
        status: FlashStatus.claimed,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 180,
              height: 280,
              child: FlashPieceCard(piece: claimedPiece),
            ),
          ),
        ),
      );

      expect(find.text('CLAIMED'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    });

    testWidgets('ArtistProfileScreen renders EXCLUSIVE badges on available 1-of-1 pieces', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final artist = Artist.mockArtists.first;

      await tester.pumpWidget(
        MaterialApp(
          home: ArtistProfileScreen(artist: artist),
        ),
      );
      await tester.pumpAndSettle();

      // In available tab, 1-of-1 pieces have EXCLUSIVE badge
      expect(find.text('EXCLUSIVE'), findsWidgets);
    });

    testWidgets('Claiming and booking an exclusive piece navigates back to ArtistProfileScreen when closing confirmation and piece disappears', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      ArtistDashboardRepository.resetMockData();
      BookingSyncService.resetSyncState();

      final artist = Artist.mockArtists.first;
      final exclusivePiece = artist.flashArtworks.firstWhere((p) => p.isExclusive);

      await tester.pumpWidget(
        MaterialApp(
          home: ArtistProfileScreen(artist: artist),
        ),
      );
      await tester.pumpAndSettle();

      // Piece is initially present on artist page
      expect(find.text(exclusivePiece.title), findsOneWidget);

      // Tap the exclusive flash piece
      await tester.tap(find.text(exclusivePiece.title));
      await tester.pumpAndSettle();

      // Verify on FlashDetailsScreen
      expect(find.byType(FlashDetailsScreen), findsOneWidget);

      // Tap CLAIM & BOOK FLASH
      await tester.tap(find.text('CLAIM & BOOK FLASH'));
      await tester.pumpAndSettle();

      // Verify on FlashBookingScreen step 1
      expect(find.byType(FlashBookingScreen), findsOneWidget);
      expect(find.text('SELECT DATE'), findsOneWidget);

      // Step 1 -> Step 2
      await tester.tap(find.text('CONTINUE TO DETAILS'));
      await tester.pumpAndSettle();

      // Step 2 -> Step 3
      await tester.tap(find.text('CONTINUE TO PAYMENT'));
      await tester.pumpAndSettle();

      // Step 3 -> Pay
      await tester.tap(find.textContaining('DEPOSIT & CONFIRM'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pumpAndSettle();

      // Verify confirmation screen (Step 4)
      expect(find.text('Flash Claimed & Booked!'), findsOneWidget);
      expect(find.text('DONE'), findsOneWidget);

      // Close confirmation screen via DONE button
      await tester.ensureVisible(find.text('DONE'));
      await tester.tap(find.text('DONE'));
      await tester.pumpAndSettle();

      // Verify navigated back to ArtistProfileScreen
      expect(find.byType(ArtistProfileScreen), findsOneWidget);
      expect(find.byType(FlashDetailsScreen), findsNothing);
      expect(find.byType(FlashBookingScreen), findsNothing);

      // Verify the exclusive flash piece has disappeared from the artist page
      expect(find.text(exclusivePiece.title), findsNothing);

      // Switch to Completed tab and verify it has also disappeared from artist page
      await tester.tap(find.text('Completed'));
      await tester.pumpAndSettle();
      expect(find.text(exclusivePiece.title), findsNothing);
    });

    testWidgets('Closing confirmation screen via close icon navigates back to ArtistProfileScreen and exclusive piece disappears', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      ArtistDashboardRepository.resetMockData();
      BookingSyncService.resetSyncState();

      final artist = Artist.mockArtists.first;
      final exclusivePiece = artist.flashArtworks.firstWhere((p) => p.isExclusive);

      await tester.pumpWidget(
        MaterialApp(
          home: ArtistProfileScreen(artist: artist),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the exclusive flash piece
      await tester.tap(find.text(exclusivePiece.title));
      await tester.pumpAndSettle();

      // Tap CLAIM & BOOK FLASH
      await tester.tap(find.text('CLAIM & BOOK FLASH'));
      await tester.pumpAndSettle();

      // Step 1 -> Step 2 -> Step 3 -> Pay
      await tester.tap(find.text('CONTINUE TO DETAILS'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CONTINUE TO PAYMENT'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('DEPOSIT & CONFIRM'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pumpAndSettle();

      // Verify confirmation screen
      expect(find.text('Flash Claimed & Booked!'), findsOneWidget);

      // Close confirmation screen via AppBar close icon
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // Verify back on ArtistProfileScreen and exclusive piece disappeared
      expect(find.byType(ArtistProfileScreen), findsOneWidget);
      expect(find.byType(FlashDetailsScreen), findsNothing);
      expect(find.text(exclusivePiece.title), findsNothing);
    });

    testWidgets('Claiming and booking a repeatable flash piece navigates back to ArtistProfileScreen and piece remains visible', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      ArtistDashboardRepository.resetMockData();
      BookingSyncService.resetSyncState();

      final artist = Artist.mockArtists.first;
      final repeatablePiece = artist.flashArtworks.firstWhere((p) => !p.isExclusive);

      await tester.pumpWidget(
        MaterialApp(
          home: ArtistProfileScreen(artist: artist),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the repeatable flash piece
      await tester.tap(find.text(repeatablePiece.title));
      await tester.pumpAndSettle();

      // Tap CLAIM & BOOK FLASH
      await tester.tap(find.text('CLAIM & BOOK FLASH'));
      await tester.pumpAndSettle();

      // Step 1 -> Step 2 -> Step 3 -> Pay
      await tester.tap(find.text('CONTINUE TO DETAILS'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CONTINUE TO PAYMENT'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('DEPOSIT & CONFIRM'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pumpAndSettle();

      // Close confirmation screen
      await tester.ensureVisible(find.text('DONE'));
      await tester.tap(find.text('DONE'));
      await tester.pumpAndSettle();

      // Verify back on ArtistProfileScreen
      expect(find.byType(ArtistProfileScreen), findsOneWidget);
      expect(find.byType(FlashDetailsScreen), findsNothing);

      // Repeatable piece is STILL visible on the artist page
      expect(find.text(repeatablePiece.title), findsOneWidget);
    });
  });
}
