import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

    testWidgets('ExploreScreen displays trending studios and filters by studio name',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExploreScreen(
              mockStudios: mockStudios,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('TRENDING SHOPS & STUDIOS'), findsOneWidget);
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
  });
}
