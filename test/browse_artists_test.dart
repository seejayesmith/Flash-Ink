import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flash_ink/models/artist.dart';
import 'package:flash_ink/screens/browse_artists_screen.dart';

void main() {
  group('Artist Model Tests', () {
    test('Mock artists contains 4 pre-configured artists', () {
      expect(Artist.mockArtists.length, 4);
      final first = Artist.mockArtists.first;
      expect(first.name, 'Oddmaree');
      expect(first.rating, 5.0);
      expect(first.availablePieces, 12);
      expect(first.minDeposit, 50);
      expect(first.images.length, 4);
    });

    test('copyWith updates fields correctly', () {
      final artist = Artist.mockArtists.first;
      final updated = artist.copyWith(isFavorited: true, rating: 4.8);
      expect(updated.isFavorited, isTrue);
      expect(updated.rating, 4.8);
      expect(updated.name, artist.name);
    });
  });

  group('BrowseArtistsScreen Widget Tests', () {
    testWidgets('Renders header and filter chips', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: BrowseArtistsScreen(),
        ),
      );

      // Verify header title
      expect(find.text('Browse Artists'), findsOneWidget);

      // Verify filter chips
      expect(find.text('Filters'), findsOneWidget);
      expect(find.text('Books Open'), findsOneWidget);
      expect(find.text('Queer Artists'), findsOneWidget);
      expect(find.text('Nearby'), findsOneWidget);

      // Verify bottom navigation items
      expect(find.text('HOME'), findsOneWidget);
      expect(find.text('EXPLORE'), findsOneWidget);
      expect(find.text('APPOINTMENTS'), findsOneWidget);
      expect(find.text('ALERTS'), findsOneWidget);
    });
  });
}
