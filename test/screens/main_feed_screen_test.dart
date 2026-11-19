import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flash_ink/features/appointments/presentation/screens/appointments_screen.dart';
import 'package:flash_ink/features/explore/presentation/screens/explore_screen.dart';
import 'package:flash_ink/features/messages/presentation/screens/messages_screen.dart';
import 'package:flash_ink/screens/browse_artists_screen.dart';
import 'package:flash_ink/screens/main_feed_screen.dart';
import 'package:flash_ink/widgets/scaffold_with_nav_bar.dart';

void main() {
  group('MainFeedScreen 4-Tab Navigation Tests', () {
    testWidgets('Renders BrowseArtistsScreen as the default landing tab (Feed)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MainFeedScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Check all 4 navigation tabs in bottom bar
      expect(find.text('Feed'), findsOneWidget);
      expect(find.text('Explore'), findsOneWidget);
      expect(find.text('Bookings'), findsOneWidget);
      expect(find.text('Messages'), findsOneWidget);

      // Verify BrowseArtistsScreen is displayed
      expect(find.byType(BrowseArtistsScreen), findsOneWidget);
      expect(find.text('Browse Artists'), findsOneWidget);
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
      expect(find.text('Explore'), findsWidgets); // Title
    });

    testWidgets('Messages back button returns to the previously active client tab', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MainFeedScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Feed (0) -> Messages (3) -> Back -> Feed (0)
      await tester.tap(find.text('Messages'));
      await tester.pumpAndSettle();
      expect(tester.widget<ScaffoldWithNavBar>(find.byType(ScaffoldWithNavBar)).currentIndex, 3);
      expect(find.byKey(const Key('messages_back_button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('messages_back_button')));
      await tester.pumpAndSettle();
      expect(tester.widget<ScaffoldWithNavBar>(find.byType(ScaffoldWithNavBar)).currentIndex, 0);
      expect(find.byType(BrowseArtistsScreen), findsOneWidget);

      // Explore (1) -> Messages (3) -> tapping Messages again -> Back -> Explore (1)
      await tester.tap(find.text('Explore'));
      await tester.pumpAndSettle();
      expect(tester.widget<ScaffoldWithNavBar>(find.byType(ScaffoldWithNavBar)).currentIndex, 1);

      await tester.tap(find.text('Messages'));
      await tester.pumpAndSettle();
      expect(tester.widget<ScaffoldWithNavBar>(find.byType(ScaffoldWithNavBar)).currentIndex, 3);

      // Re-tapping Messages while already on Messages must not overwrite previous tab
      await tester.tap(find.text('Messages').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('messages_back_button')));
      await tester.pumpAndSettle();
      expect(tester.widget<ScaffoldWithNavBar>(find.byType(ScaffoldWithNavBar)).currentIndex, 1);
      expect(find.byType(ExploreScreen), findsOneWidget);

      // Bookings (2) -> Messages (3) -> Back -> Bookings (2)
      await tester.tap(find.text('Bookings'));
      await tester.pumpAndSettle();
      expect(tester.widget<ScaffoldWithNavBar>(find.byType(ScaffoldWithNavBar)).currentIndex, 2);

      await tester.tap(find.text('Messages'));
      await tester.pumpAndSettle();
      expect(tester.widget<ScaffoldWithNavBar>(find.byType(ScaffoldWithNavBar)).currentIndex, 3);

      await tester.tap(find.byKey(const Key('messages_back_button')));
      await tester.pumpAndSettle();
      expect(tester.widget<ScaffoldWithNavBar>(find.byType(ScaffoldWithNavBar)).currentIndex, 2);
      expect(find.byType(AppointmentsScreen), findsOneWidget);
    });

    testWidgets('Messages back button falls back to Feed tab when landing directly on Messages', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MainFeedScreen(initialIndex: 3),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.widget<ScaffoldWithNavBar>(find.byType(ScaffoldWithNavBar)).currentIndex, 3);
      expect(find.byType(MessagesScreen), findsOneWidget);

      await tester.tap(find.byKey(const Key('messages_back_button')));
      await tester.pumpAndSettle();

      expect(tester.widget<ScaffoldWithNavBar>(find.byType(ScaffoldWithNavBar)).currentIndex, 0);
      expect(find.byType(BrowseArtistsScreen), findsOneWidget);
    });
  });
}
