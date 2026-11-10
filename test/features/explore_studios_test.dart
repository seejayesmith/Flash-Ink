import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flash_ink/providers/app_providers.dart';
import 'package:flash_ink/features/explore/domain/models/explore_studio.dart';
import 'package:flash_ink/features/explore/presentation/screens/explore_screen.dart';
import 'package:flash_ink/features/explore/presentation/widgets/trending_studios_section.dart';
import 'package:flash_ink/features/explore/presentation/widgets/studio_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final mockStudios = [
    const ExploreStudio(
      id: 'studio_test_1',
      name: 'Electric Tiger Studio',
      address: '100 Main St',
      city: 'Los Angeles, CA',
      imageUrl: 'https://images.unsplash.com/photo-1598371839696-5c5bb00bdc28',
      rating: 4.9,
      reviewCount: 150,
      residentArtistsCount: 5,
      styles: ['Neo-Traditional', 'Fine Line'],
      isVerified: true,
    ),
    const ExploreStudio(
      id: 'studio_test_2',
      name: 'Sacred Heart Tattoo',
      address: '200 Oak Ave',
      city: 'Santa Monica, CA',
      imageUrl: 'https://images.unsplash.com/photo-1611501275019-9b5cda994e8d',
      rating: 4.8,
      reviewCount: 95,
      residentArtistsCount: 3,
      styles: ['Japanese Traditional'],
      isVerified: false,
    ),
  ];

  group('TrendingStudiosSection & StudioCard Widget Tests', () {
    testWidgets('TrendingStudiosSection renders studio header, count, and StudioCards',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TrendingStudiosSection(studios: mockStudios),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('TRENDING SHOPS & STUDIOS'), findsOneWidget);
      expect(find.text('2 Studios'), findsOneWidget);
      expect(find.byType(StudioCard), findsNWidgets(2));
      expect(find.text('Electric Tiger Studio'), findsOneWidget);
      expect(find.text('Sacred Heart Tattoo'), findsOneWidget);
      expect(find.text('5 ARTISTS'), findsOneWidget);
      expect(find.text('3 ARTISTS'), findsOneWidget);
      expect(find.text('Neo-Traditional'), findsOneWidget);
      expect(find.text('Japanese Traditional'), findsOneWidget);
    });

    testWidgets('Tapping on a StudioCard triggers onStudioTap callback',
        (tester) async {
      ExploreStudio? tappedStudio;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TrendingStudiosSection(
                studios: mockStudios,
                onStudioTap: (studio) {
                  tappedStudio = studio;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Electric Tiger Studio'));
      await tester.pumpAndSettle();

      expect(tappedStudio, isNotNull);
      expect(tappedStudio!.id, equals('studio_test_1'));
    });

    testWidgets('ExploreScreen displays nearest studios by default and filters by studio name',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            exploreStudiosProvider.overrideWithValue(
              AsyncValue.data(mockStudios),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ExploreScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('NEAREST TATTOO SHOPS'), findsOneWidget);
      expect(find.text('Electric Tiger Studio'), findsOneWidget);
      expect(find.text('Sacred Heart Tattoo'), findsOneWidget);

      // Filter by "Sacred"
      await tester.enterText(find.byType(TextField), 'Sacred');
      await tester.pumpAndSettle();

      expect(find.text('Sacred Heart Tattoo'), findsOneWidget);
      expect(find.text('Electric Tiger Studio'), findsNothing);

      // Clear search
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.text('Electric Tiger Studio'), findsOneWidget);
      expect(find.text('Sacred Heart Tattoo'), findsOneWidget);
    });

    testWidgets('StudioCard displays TATTOO SHOP badge when residentArtistsCount is 0',
        (tester) async {
      const gplaceStudio = ExploreStudio(
        id: 'gplace_123',
        name: 'Tualatin Ink Studio',
        address: '18880 SW Boones Ferry Rd',
        city: 'Tualatin, OR',
        imageUrl: 'assets/images/tattoo_setup.png',
        rating: 4.9,
        reviewCount: 120,
        residentArtistsCount: 0,
        styles: ['Custom Ink', 'Fine Line'],
        isVerified: false,
        distance: '0.8 mi away',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StudioCard(studio: gplaceStudio),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tualatin Ink Studio'), findsOneWidget);
      expect(find.text('TATTOO SHOP'), findsOneWidget);
      expect(find.textContaining('0.8 mi away'), findsOneWidget);
    });

    testWidgets('ExploreScreen defaults to displaying nearest tattoo shops via initialStudios',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const nearestShops = [
        ExploreStudio(
          id: 'shop_1',
          name: 'Bridge City Tattoo',
          address: '711 SW Alder St',
          city: 'Portland, OR',
          imageUrl: 'assets/images/tattoo_setup.png',
          rating: 4.9,
          reviewCount: 310,
          residentArtistsCount: 0,
          styles: ['Traditional', 'Color'],
          isVerified: false,
          distance: '1.2 mi away',
        ),
        ExploreStudio(
          id: 'shop_2',
          name: 'Historic Tattoo',
          address: '2001 SE Hawthorne Blvd',
          city: 'Portland, OR',
          imageUrl: 'assets/images/tattoo_setup.png',
          rating: 4.8,
          reviewCount: 240,
          residentArtistsCount: 0,
          styles: ['Black & Grey'],
          isVerified: false,
          distance: '2.5 mi away',
        ),
      ];

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ExploreScreen(
                initialStudios: nearestShops,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verified: Section title is NEAREST TATTOO SHOPS by default
      expect(find.text('NEAREST TATTOO SHOPS'), findsOneWidget);
      expect(find.text('2 Studios'), findsOneWidget);
      expect(find.text('Bridge City Tattoo'), findsOneWidget);
      expect(find.text('Historic Tattoo'), findsOneWidget);
      // Artists sections are omitted when no artists are onboarded
      expect(find.text('TRENDING IN YOUR AREA'), findsNothing);
      expect(find.text('FEATURED ARTIST SPOTLIGHT'), findsNothing);
    });
  });
}
