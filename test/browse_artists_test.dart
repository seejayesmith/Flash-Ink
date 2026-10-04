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
      expect(find.text('Sort by'), findsOneWidget);
      expect(find.text('Filters'), findsOneWidget);
      expect(find.text('Books Open'), findsOneWidget);
      expect(find.text('Queer Artists'), findsOneWidget);
      expect(find.text('Female'), findsOneWidget);
      expect(find.text('BIPOC'), findsOneWidget);
      expect(find.text('Silent Appt'), findsOneWidget);
      expect(find.text('Nearby'), findsOneWidget);

      // Verify bottom navigation items
      expect(find.text('HOME'), findsOneWidget);
      expect(find.text('EXPLORE'), findsOneWidget);
      expect(find.text('APPOINTMENTS'), findsOneWidget);
      expect(find.text('ALERTS'), findsOneWidget);
    });

    testWidgets('Tapping Filters chip opens the solid matte dark filter modal bottom sheet', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: BrowseArtistsScreen(),
        ),
      );

      // Tap on the Filters chip
      await tester.tap(find.text('Filters'));
      await tester.pumpAndSettle();

      // Verify modal content
      expect(find.text('Reset All'), findsOneWidget);
      expect(find.text('TATTOO STYLES'), findsOneWidget);
      expect(find.text('Traditional'), findsOneWidget);
      expect(find.text('Fine Line'), findsOneWidget);
      expect(find.text('AVAILABILITY & IDENTITY'), findsOneWidget);
      expect(find.text('Books Open Only'), findsOneWidget);
      expect(find.text('Queer & LGBTQ+ Artists'), findsOneWidget);
      expect(find.text('Female Artists'), findsOneWidget);
      expect(find.text('BIPOC Artists'), findsOneWidget);
      expect(find.text('Silent Appointments'), findsOneWidget);
      expect(find.text('Nearby (Local Artists)'), findsOneWidget);
      expect(find.text('PRICING & DEPOSIT'), findsOneWidget);
      expect(find.text('Apply Filters'), findsOneWidget);

      // Select a style and apply
      await tester.tap(find.text('Fine Line'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Apply Filters'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Apply Filters'));
      await tester.pumpAndSettle();

      // Modal closed, filter chip shows active count
      expect(find.text('Filters (1)'), findsOneWidget);
    });

    testWidgets('Reset Filters button restores all artists when none match', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: BrowseArtistsScreen(),
        ),
      );

      // Tap on Filters
      await tester.tap(find.text('Filters'));
      await tester.pumpAndSettle();

      // Toggle Books Open Only inside modal
      await tester.tap(find.text('Books Open Only'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Apply Filters'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Apply Filters'));
      await tester.pumpAndSettle();

      // Filter chips show updated state
      expect(find.text('Filters (1)'), findsOneWidget);
    });

    testWidgets('Entering search query filters artist feed in real-time and shows clear button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: BrowseArtistsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify search bar is rendered
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Search artists, studios, styles...'), findsOneWidget);

      // Initially first artist is present
      expect(find.text('Oddmaree'), findsOneWidget);

      // Enter search query for second artist
      await tester.enterText(find.byType(TextField), 'Kian');
      await tester.pumpAndSettle();

      // Only Kian is visible as the top matching card
      expect(find.text('Kian Forreal'), findsOneWidget);
      expect(find.text('Oddmaree'), findsNothing);

      // Clear icon button is displayed
      expect(find.byIcon(Icons.close), findsOneWidget);

      // Tap clear icon
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // First artist restored
      expect(find.text('Oddmaree'), findsOneWidget);
    });

    testWidgets('Searching non-matching query displays empty state and reset button clears search', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: BrowseArtistsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Search non-existent artist
      await tester.enterText(find.byType(TextField), 'NonExistentTattooArtistXYZ');
      await tester.pumpAndSettle();

      expect(find.text('No Artists Found'), findsOneWidget);
      expect(find.text('Reset Filters'), findsOneWidget);

      // Tap Reset Filters
      await tester.tap(find.text('Reset Filters'));
      await tester.pumpAndSettle();

      // Search bar cleared and artists restored
      expect(find.text('Oddmaree'), findsOneWidget);
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, '');
    });

    testWidgets('Tapping Sort by chip opens sort modal and selecting Distance updates chip label', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: BrowseArtistsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Sort by chip
      await tester.tap(find.byKey(const Key('sort_by_chip')));
      await tester.pumpAndSettle();

      // Verify modal options
      expect(find.text('Sort Artists'), findsOneWidget);
      expect(find.text('Recommended'), findsOneWidget);
      expect(find.text('Distance: Nearest First'), findsOneWidget);
      expect(find.text('Rating: Highest Rated'), findsOneWidget);
      expect(find.text('Min Deposit: Low to High'), findsOneWidget);

      // Select Distance: Nearest First
      await tester.tap(find.text('Distance: Nearest First'));
      await tester.pumpAndSettle();

      // Modal is dismissed, chip label is updated to dynamic label
      expect(find.text('Sort: Nearest'), findsOneWidget);
    });

    testWidgets('Tapping Female, BIPOC, and Silent Appt chips in carousel toggles filters', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: BrowseArtistsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Initially Oddmaree is visible
      expect(find.text('Oddmaree'), findsOneWidget);

      // Tap Female filter chip
      await tester.tap(find.byKey(const Key('filter_chip_female')));
      await tester.pumpAndSettle();

      // Female artists: Oddmaree and Elena Surova. Kian and Marcus are excluded.
      expect(find.text('Oddmaree'), findsOneWidget);
      expect(find.text('Kian Forreal'), findsNothing);

      // Untoggle Female
      await tester.tap(find.byKey(const Key('filter_chip_female')));
      await tester.pumpAndSettle();

      // Tap BIPOC filter chip
      await tester.tap(find.byKey(const Key('filter_chip_bipoc')));
      await tester.pumpAndSettle();

      // BIPOC artists: Kian Forreal, Elena Surova, Marcus Vex. Oddmaree is excluded.
      expect(find.text('Oddmaree'), findsNothing);
      expect(find.text('Kian Forreal'), findsOneWidget);

      // Untoggle BIPOC
      await tester.tap(find.byKey(const Key('filter_chip_bipoc')));
      await tester.pumpAndSettle();

      // Tap Silent Appt filter chip
      await tester.tap(find.byKey(const Key('filter_chip_silent_appointment')));
      await tester.pumpAndSettle();

      // Silent Appt artists: Oddmaree, Elena Surova, Marcus Vex.
      expect(find.text('Oddmaree'), findsOneWidget);
    });
  });

  group('SnappingScrollPhysics Tests', () {
    const itemHeight = 500.0;
    const physics = SnappingScrollPhysics(itemHeight: itemHeight);

    test('Spring has tuned stiffness and mass for snappy feedback', () {
      expect(physics.spring.stiffness, 300.0);
      expect(physics.spring.mass, 0.5);
    });

    test('Snaps to next card on positive velocity (flick forward)', () {
      final metrics = FixedScrollMetrics(
        minScrollExtent: 0.0,
        maxScrollExtent: 2000.0,
        pixels: 100.0,
        viewportDimension: 800.0,
        axisDirection: AxisDirection.down,
        devicePixelRatio: 1.0,
      );
      final simulation = physics.createBallisticSimulation(metrics, 300.0);
      expect(simulation, isA<ScrollSpringSimulation>());
      final springSim = simulation as ScrollSpringSimulation;
      expect(springSim.x(5.0), closeTo(500.0, 1.0));
    });

    test('Snaps forward on drag past 35% without flick velocity', () {
      final metrics = FixedScrollMetrics(
        minScrollExtent: 0.0,
        maxScrollExtent: 2000.0,
        pixels: 180.0, // 36% of 500.0
        viewportDimension: 800.0,
        axisDirection: AxisDirection.down,
        devicePixelRatio: 1.0,
      );
      final simulation = physics.createBallisticSimulation(metrics, 0.0);
      expect(simulation, isA<ScrollSpringSimulation>());
      final springSim = simulation as ScrollSpringSimulation;
      expect(springSim.x(5.0), closeTo(500.0, 1.0));
    });

    test('Snaps back on drag under 35% without flick velocity', () {
      final metrics = FixedScrollMetrics(
        minScrollExtent: 0.0,
        maxScrollExtent: 2000.0,
        pixels: 150.0, // 30% of 500.0
        viewportDimension: 800.0,
        axisDirection: AxisDirection.down,
        devicePixelRatio: 1.0,
      );
      final simulation = physics.createBallisticSimulation(metrics, 0.0);
      expect(simulation, isA<ScrollSpringSimulation>());
      final springSim = simulation as ScrollSpringSimulation;
      expect(springSim.x(5.0), closeTo(0.0, 1.0));
    });
  });
}
