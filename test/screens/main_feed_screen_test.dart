import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flash_ink/screens/main_feed_screen.dart';
import 'package:flash_ink/screens/browse_artists_screen.dart';
import 'package:flash_ink/features/discover/presentation/screens/discover_screen.dart';
import 'package:flash_ink/features/explore/presentation/screens/explore_screen.dart';

void main() {
  group('MainFeedScreen 5-Tab Navigation Tests', () {
    testWidgets('Renders BrowseArtistsScreen as the default landing tab (Feed)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MainFeedScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Check all 5 navigation tabs in bottom bar
      expect(find.text('Feed'), findsOneWidget);
      expect(find.text('Discover'), findsOneWidget);
      expect(find.text('Explore'), findsOneWidget);
      expect(find.text('Appointments'), findsOneWidget);
      expect(find.text('Messages'), findsOneWidget);

      // Verify BrowseArtistsScreen is displayed
      expect(find.byType(BrowseArtistsScreen), findsOneWidget);
      expect(find.text('Browse Artists'), findsOneWidget);
    });

    testWidgets('Switching to Discover tab switches view to DiscoverScreen', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MainFeedScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on the Discover tab
      await tester.tap(find.text('Discover'));
      await tester.pumpAndSettle();

      // Verify DiscoverScreen is active
      expect(find.byType(DiscoverScreen), findsOneWidget);
      expect(find.text('FLASH'), findsOneWidget);
      expect(find.text('.INK'), findsOneWidget);
    });

    testWidgets('Switching to Explore tab switches view to ExploreScreen', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MainFeedScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on the Explore tab
      await tester.tap(find.text('Explore'));
      await tester.pumpAndSettle();

      // Verify ExploreScreen is active
      expect(find.byType(ExploreScreen), findsOneWidget);
      expect(find.text('Explore Directory'), findsOneWidget);
    });
  });
}
