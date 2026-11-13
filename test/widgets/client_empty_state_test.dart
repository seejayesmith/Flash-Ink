import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flash_ink/widgets/client_empty_state.dart';
import 'package:flash_ink/features/appointments/presentation/screens/appointments_screen.dart';
import 'package:flash_ink/features/messages/presentation/screens/messages_screen.dart';
import 'package:flash_ink/theme/app_theme.dart';

void main() {
  group('ClientEmptyState Widget Tests', () {
    testWidgets('Renders icon, title, subtitle and action button properly',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ClientEmptyState(
              icon: Icons.bookmark_border_rounded,
              title: 'Saved Flash',
              subtitle: 'Browse designs and save your favorites',
              action: ElevatedButton(
                onPressed: () {},
                child: const Text('EXPLORE'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.bookmark_border_rounded), findsOneWidget);
      expect(find.text('Saved Flash'), findsOneWidget);
      expect(find.text('Browse designs and save your favorites'), findsOneWidget);
      expect(find.text('EXPLORE'), findsOneWidget);
    });

    testWidgets('Calculates bottom padding offset for floating nav bar',
        (tester) async {
      const safeBottom = 34.0;

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            padding: EdgeInsets.only(bottom: safeBottom),
          ),
          child: const MaterialApp(
            home: Scaffold(
              body: ClientEmptyState(
                icon: Icons.calendar_today_outlined,
                title: 'No Appointments',
                subtitle: 'No appointments scheduled yet',
                hasFloatingNavBar: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find the outermost padding of ClientEmptyState
      final paddingFinder = find.descendant(
        of: find.byType(ClientEmptyState),
        matching: find.byType(Padding),
      );
      final paddingWidget = tester.widget<Padding>(paddingFinder.first);
      final insets = paddingWidget.padding as EdgeInsets;

      final expectedBottom = safeBottom +
          AppTheme.navBarBottomMargin +
          AppTheme.navBarHeight;
      expect(insets.bottom, equals(expectedBottom));
    });

    testWidgets('Does not add navbar offset when hasFloatingNavBar is false',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ClientEmptyState(
              icon: Icons.favorite_border,
              title: 'Empty',
              subtitle: 'No items',
              hasFloatingNavBar: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final paddingFinder = find.descendant(
        of: find.byType(ClientEmptyState),
        matching: find.byType(Padding),
      );
      final paddingWidget = tester.widget<Padding>(paddingFinder.first);
      final insets = paddingWidget.padding as EdgeInsets;

      expect(insets.bottom, equals(0.0));
    });
  });

  group('AppointmentsScreen Empty State Alignment Tests', () {
    testWidgets(
        'Empty Upcoming and Past tabs maintain identical vertical coordinates for icon and title',
        (tester) async {
      tester.view.physicalSize = const Size(393, 852); // iPhone 15 Pro resolution
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      bool exploreTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppointmentsScreen(
              mockUpcoming: const [],
              mockPast: const [],
              onExploreTap: () => exploreTapped = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Starts on Upcoming empty state
      expect(find.text('No Upcoming Appointments'), findsOneWidget);
      expect(find.text('Browse Flash Designs'), findsOneWidget);

      final upcomingIconCenter =
          tester.getCenter(find.byIcon(Icons.calendar_today_outlined));
      final upcomingTitleTop =
          tester.getTopLeft(find.text('No Upcoming Appointments')).dy;

      // Tap CTA button
      await tester.tap(find.text('Browse Flash Designs'));
      await tester.pumpAndSettle();
      expect(exploreTapped, isTrue);

      // Switch to Past tab
      await tester.tap(find.textContaining('Past (0)'));
      await tester.pumpAndSettle();

      expect(find.text('No Past Sessions'), findsOneWidget);
      expect(find.text('Browse Flash Designs'), findsNothing);

      final pastIconCenter =
          tester.getCenter(find.byIcon(Icons.calendar_today_outlined));
      final pastTitleTop =
          tester.getTopLeft(find.text('No Past Sessions')).dy;

      // Crucial: The icon and title must remain at the exact same vertical coordinate!
      expect(pastIconCenter.dy, equals(upcomingIconCenter.dy));
      expect(pastTitleTop, equals(upcomingTitleTop));
    });
  });

  group('MessagesScreen Empty State Tests', () {
    testWidgets('Displays styled empty state when thread list is empty',
        (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MessagesScreen(
              mockThreads: [],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsOneWidget);
      expect(find.text('No Conversations Yet'), findsOneWidget);
      expect(
        find.text(
            'When you book an appointment or message an artist, your conversations will appear here.'),
        findsOneWidget,
      );
    });

    testWidgets('Displays search empty state when filter matches nothing',
        (tester) async {
      tester.view.physicalSize = const Size(393, 852);
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

      // Enter search query that matches nothing
      await tester.enterText(find.byType(TextField), 'zzzznonexistent');
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.search_off_rounded), findsOneWidget);
      expect(find.text('No Conversations Found'), findsOneWidget);
      expect(
        find.text('No messages match "zzzznonexistent". Try a different search.'),
        findsOneWidget,
      );
    });
  });
}
