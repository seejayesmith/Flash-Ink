import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flash_ink/models/artist.dart';
import 'package:flash_ink/widgets/artist_card.dart';
import 'package:flash_ink/widgets/flash_image.dart';
import 'package:flash_ink/widgets/animated_favorite_button.dart';

void main() {
  const dummyAvatar = 'https://example.com/avatar.jpg';

  Artist createTestArtist({
    int availablePieces = 4,
    List<FlashArtwork> flashArtworks = const [],
    List<String>? images,
  }) {
    return Artist(
      id: 'test_artist',
      name: 'Ink Artist',
      avatarUrl: dummyAvatar,
      location: 'Portland, OR',
      studioType: 'Private Studio',
      rating: 5.0,
      availablePieces: availablePieces,
      minDeposit: 50,
      images: images,
      flashArtworks: flashArtworks,
    );
  }

  FlashArtwork createFlash(String id, {FlashStatus status = FlashStatus.available}) {
    return FlashArtwork(
      id: id,
      title: 'Flash $id',
      imageUrl: 'assets/images/flash_traditional_dagger.jpg',
      status: status,
    );
  }

  Widget buildCard(Artist artist, {VoidCallback? onViewProfile, VoidCallback? onToggleFavorite}) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: 600,
          width: 400,
          child: ArtistCard(
            artist: artist,
            onViewProfile: onViewProfile,
            onToggleFavorite: onToggleFavorite,
          ),
        ),
      ),
    );
  }

  group('ArtistCard Dynamic Artwork Area Tests (0 to 4 pieces)', () {
    testWidgets('0 pieces: Renders stylized F logo empty state when availablePieces is 0', (tester) async {
      final artist = createTestArtist(
        availablePieces: 0,
        images: ['img1.jpg', 'img2.jpg'],
      );

      await tester.pumpWidget(buildCard(artist));

      // Stylized 'F' logo is visible
      expect(find.text('F'), findsOneWidget);
      // No FlashImage artwork rendered
      expect(find.byType(FlashImage), findsNothing);
      // AVAIL PIECES stat is 0
      expect(find.text('0'), findsOneWidget);
    });

    testWidgets('0 pieces: Renders stylized F logo when all flash artworks are claimed', (tester) async {
      final artist = createTestArtist(
        availablePieces: 0,
        flashArtworks: [
          createFlash('f1', status: FlashStatus.claimed),
          createFlash('f2', status: FlashStatus.claimed),
        ],
      );

      await tester.pumpWidget(buildCard(artist));

      expect(find.text('F'), findsOneWidget);
      expect(find.byType(FlashImage), findsNothing);
    });

    testWidgets('1 piece: Renders single full-bleed hero artwork', (tester) async {
      final artist = createTestArtist(
        availablePieces: 1,
        images: ['assets/images/flash_traditional_dagger.jpg'],
      );

      await tester.pumpWidget(buildCard(artist));

      expect(find.text('F'), findsNothing);
      expect(find.byType(FlashImage), findsOneWidget);
    });

    testWidgets('2 pieces: Renders 2 vertical side-by-side columns', (tester) async {
      final artist = createTestArtist(
        availablePieces: 2,
        images: [
          'assets/images/flash_traditional_dagger.jpg',
          'assets/images/flash_blackwork_skull.jpg',
        ],
      );

      await tester.pumpWidget(buildCard(artist));

      expect(find.byType(FlashImage), findsNWidgets(2));
    });

    testWidgets('3 pieces: Renders 3 vertical side-by-side columns', (tester) async {
      final artist = createTestArtist(
        availablePieces: 3,
        images: [
          'assets/images/flash_traditional_dagger.jpg',
          'assets/images/flash_blackwork_skull.jpg',
          'assets/images/flash_traditional_heart.jpg',
        ],
      );

      await tester.pumpWidget(buildCard(artist));

      expect(find.byType(FlashImage), findsNWidgets(3));
    });

    testWidgets('4 pieces: Renders 2x2 grid', (tester) async {
      final artist = createTestArtist(
        availablePieces: 4,
        images: [
          'assets/images/flash_traditional_dagger.jpg',
          'assets/images/flash_blackwork_skull.jpg',
          'assets/images/flash_traditional_heart.jpg',
          'assets/images/flash_traditional_moth.jpg',
        ],
      );

      await tester.pumpWidget(buildCard(artist));

      expect(find.byType(FlashImage), findsNWidgets(4));
    });

    testWidgets('Filtering claimed flash: only available/repeatable pieces are displayed', (tester) async {
      final artist = createTestArtist(
        availablePieces: 2,
        flashArtworks: [
          createFlash('f1', status: FlashStatus.available),
          createFlash('f2', status: FlashStatus.claimed),
          createFlash('f3', status: FlashStatus.repeatable),
          createFlash('f4', status: FlashStatus.claimed),
        ],
      );

      await tester.pumpWidget(buildCard(artist));

      // 2 available/repeatable pieces shown
      expect(find.byType(FlashImage), findsNWidgets(2));
    });

    testWidgets('Touch targets: CTA and Favorite button respond to taps', (tester) async {
      bool profileTapped = false;
      bool favoriteTapped = false;

      final artist = createTestArtist(
        availablePieces: 2,
        images: [
          'assets/images/flash_traditional_dagger.jpg',
          'assets/images/flash_blackwork_skull.jpg',
        ],
      );

      await tester.pumpWidget(
        buildCard(
          artist,
          onViewProfile: () => profileTapped = true,
          onToggleFavorite: () => favoriteTapped = true,
        ),
      );

      await tester.tap(find.text('VIEW PROFILE'));
      await tester.pump();
      expect(profileTapped, isTrue);

      await tester.tap(find.byType(AnimatedFavoriteButton));
      await tester.pump();
      expect(favoriteTapped, isTrue);
    });
  });
}
