import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flash_ink/core/widgets/flash_bottom_nav_bar.dart';
import 'package:flash_ink/features/appointments/presentation/screens/appointments_screen.dart';
import 'package:flash_ink/features/appointments/presentation/widgets/appointment_card.dart';
import 'package:flash_ink/features/appointments/presentation/widgets/appointment_detail_modal.dart';
import 'package:flash_ink/features/explore/presentation/screens/explore_screen.dart';
import 'package:flash_ink/features/messages/presentation/screens/chat_conversation_screen.dart';
import 'package:flash_ink/features/messages/presentation/screens/messages_screen.dart';
import 'package:flash_ink/features/messages/presentation/widgets/message_thread_tile.dart';
import 'package:flash_ink/models/nav_destination_item.dart';
import 'package:flash_ink/screens/main_feed_screen.dart';
import 'package:flash_ink/screens/browse_artists_screen.dart';

void main() {
  group('Navigation Shell & 4 Primary Root Screens Tests', () {
    testWidgets('FlashBottomNavBar renders the 4 updated client destinations',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      int selectedIndex = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FlashBottomNavBar(
              currentIndex: selectedIndex,
              onTap: (index) => selectedIndex = index,
              items: NavDestinationItem.clientDestinations,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Feed'), findsOneWidget);
      expect(find.text('Explore'), findsOneWidget);
      expect(find.text('Appointments'), findsOneWidget);
      expect(find.text('Messages'), findsOneWidget);

      // Verify unread notification badge on Messages
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('MainFeedScreen navigates smoothly between all 4 tabs preserving state',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: MainFeedScreen(initialIndex: 1),
        ),
      );
      await tester.pumpAndSettle();

      // Tab 1: ExploreScreen
      expect(find.byType(ExploreScreen), findsOneWidget);
      expect(find.text('TRENDING IN YOUR AREA'), findsOneWidget);
      expect(find.text('FEATURED ARTIST SPOTLIGHT'), findsOneWidget);
      expect(find.text('TRENDING SHOPS & STUDIOS'), findsOneWidget);

      // Switch to Tab 2: Appointments
      await tester.tap(find.text('Appointments'));
      await tester.pumpAndSettle();

      expect(find.byType(AppointmentsScreen), findsOneWidget);
      expect(find.textContaining('Upcoming ('), findsOneWidget);
      expect(find.textContaining('Past ('), findsOneWidget);
      expect(find.byType(AppointmentCard), findsWidgets);

      // Switch to Tab 3: Messages
      await tester.tap(find.text('Messages'));
      await tester.pumpAndSettle();

      expect(find.byType(MessagesScreen), findsOneWidget);
      expect(find.byType(MessageThreadTile), findsWidgets);

      // Switch back to Tab 0: Feed
      await tester.tap(find.text('Feed'));
      await tester.pumpAndSettle();
      
      expect(find.byType(BrowseArtistsScreen), findsOneWidget);
    });

    testWidgets('AppointmentsScreen toggles between Upcoming and Past, and opens detail modal',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppointmentsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Starts on Upcoming
      expect(find.text('Sacred Serpent & Peony'), findsOneWidget);

      // Toggle to Past
      await tester.tap(find.textContaining('Past ('));
      await tester.pumpAndSettle();

      expect(find.text('Chrysanthemum Silhouette'), findsOneWidget);

      // Tap card to open detail modal
      await tester.tap(find.byType(AppointmentCard));
      await tester.pumpAndSettle();

      expect(find.byType(AppointmentDetailModal), findsOneWidget);
      expect(find.text('Total Session Price'), findsOneWidget);
      expect(find.text('DIRECTIONS'), findsOneWidget);
      expect(find.text('CONTACT'), findsOneWidget);
    });

    testWidgets('ExploreScreen search filters artists and studios',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ExploreScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('TRENDING IN YOUR AREA'), findsOneWidget);
      expect(find.text('TRENDING SHOPS & STUDIOS'), findsOneWidget);

      // Enter search query
      await tester.enterText(find.byType(TextField), 'Obsidian');
      await tester.pumpAndSettle();

      // Check for results
      expect(find.text('Obsidian Atelier'), findsOneWidget);
    });

    testWidgets('MessagesScreen displays threads and navigates to ChatConversationScreen',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MessagesScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('OddMaree'), findsOneWidget);
      expect(find.text('Maree Raven'), findsOneWidget);

      // Tap on OddMaree's thread
      await tester.tap(find.text('OddMaree'));
      await tester.pumpAndSettle();

      // Verify ChatConversationScreen is opened
      expect(find.byType(ChatConversationScreen), findsOneWidget);
      expect(find.textContaining('Regarding: '), findsOneWidget);
      expect(find.text('Sacred Serpent & Peony'), findsOneWidget);
      expect(find.text('Looking forward to our session! Make sure to stay hydrated beforehand.'),
          findsOneWidget);

      // Type and send a new message
      await tester.enterText(find.byType(TextField), 'Sounds good! See you then.');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      expect(find.text('Sounds good! See you then.'), findsOneWidget);
    });
  });
}
