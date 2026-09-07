import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flash_ink/models/artist.dart';
import 'package:flash_ink/widgets/flash_card.dart';

void main() {
  group('FlashCard Widget Tests', () {
    const testFlash = FlashArtwork(
      id: 'flash_test_1',
      artistId: 'artist_1',
      artistName: 'Oddmaree',
      title: 'Sacred Dagger & Serpent',
      imageUrl: 'https://images.unsplash.com/photo-1598371839696-5c5bb00bdc28',
      price: 220,
      deposit: 60,
      dimensions: '5" x 8"',
      estimatedTime: '2.5 hrs',
      location: 'Forearm / Calf',
      status: FlashStatus.available,
    );

    testWidgets('Renders flash artwork visual anchor, title, artist, price, and status badge',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                width: 380,
                child: FlashCard(flash: testFlash),
              ),
            ),
          ),
        ),
      );

      // Flash title
      expect(find.text('Sacred Dagger & Serpent'), findsOneWidget);

      // Artist attribution
      expect(find.textContaining('by Oddmaree'), findsOneWidget);

      // Price badge
      expect(find.text('\$220'), findsOneWidget);
      expect(find.text('\$60 dep'), findsOneWidget);

      // Status badge
      expect(find.text('AVAILABLE'), findsOneWidget);

      // Specs
      expect(find.text('5" x 8"'), findsOneWidget);
      expect(find.text('2.5 hrs'), findsOneWidget);
      expect(find.text('Forearm / Calf'), findsAtLeastNWidgets(1));

      // Purchasing CTA
      expect(find.text('INSTANT CLAIM • \$60 DEP'), findsOneWidget);
    });

    testWidgets('Tapping instant claim calls onClaim callback', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      bool claimCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                width: 380,
                child: FlashCard(
                  flash: testFlash,
                  onClaim: () => claimCalled = true,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('INSTANT CLAIM • \$60 DEP'));
      await tester.pumpAndSettle();

      expect(claimCalled, isTrue);
    });

    testWidgets('Displays CLAIMED badge and disabled CTA when piece is claimed',
        (tester) async {
      final claimedFlash = testFlash.copyWith(status: FlashStatus.claimed);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                width: 380,
                child: FlashCard(flash: claimedFlash),
              ),
            ),
          ),
        ),
      );

      expect(find.text('CLAIMED (1/1)'), findsOneWidget);
      expect(find.text('PIECE ALREADY CLAIMED'), findsOneWidget);
      expect(find.text('INSTANT CLAIM • \$60 DEP'), findsNothing);
    });

    testWidgets('Displays REPEATABLE badge for repeatable flash', (tester) async {
      final repeatableFlash = testFlash.copyWith(status: FlashStatus.repeatable);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                width: 380,
                child: FlashCard(flash: repeatableFlash),
              ),
            ),
          ),
        ),
      );

      expect(find.text('REPEATABLE'), findsOneWidget);
    });
  });
}
