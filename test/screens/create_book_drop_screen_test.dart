import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flash_ink/core/mock/mock_data_config.dart';
import 'package:flash_ink/models/artist_dashboard_data.dart';
import 'package:flash_ink/screens/artist_dashboard/create_book_drop_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  group('CreateBookDropScreen Full-Screen Wizard Tests', () {
    setUp(() {
      MockDataConfig.debugOverride = true;
      ArtistDashboardRepository.resetMockData();
    });

    tearDown(() {
      MockDataConfig.resetDebugOverride();
    });

    testWidgets('Renders Step 1 with dates grid and advances through all 4 steps to celebration', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CreateBookDropScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Step 1: Dates & Working Windows
      expect(find.text('STEP 1 OF 4'), findsOneWidget);
      expect(find.text('Select Open Booking Days'), findsOneWidget);
      expect(find.text('DROP SNAPSHOT'), findsOneWidget);

      // Advance to Step 2
      final continueBtn = find.text('Continue ➔');
      expect(continueBtn, findsOneWidget);
      await tester.tap(continueBtn);
      await tester.pumpAndSettle();

      // Step 2: Intake Scope
      expect(find.text('STEP 2 OF 4'), findsOneWidget);
      expect(find.text('Intake Scope & Limits'), findsOneWidget);
      expect(find.text('Flash Tattoos'), findsOneWidget);
      expect(find.text('Custom Concepts'), findsOneWidget);

      // Advance to Step 3
      await tester.tap(continueBtn);
      await tester.pumpAndSettle();

      // Step 3: Launch Strategy & VIP
      expect(find.text('STEP 3 OF 4'), findsOneWidget);
      expect(find.text('Release Strategy & VIP'), findsOneWidget);
      expect(find.text('VIP Waitlist First Dibs'), findsOneWidget);

      // Advance to Step 4: Review
      await tester.tap(continueBtn);
      await tester.pumpAndSettle();

      // Step 4: Review & Commit
      expect(find.text('STEP 4 OF 4'), findsOneWidget);
      expect(find.text('Review & Commit Drop'), findsOneWidget);
      final commitBtn = find.byKey(const Key('commit_book_drop_button'));
      expect(commitBtn, findsOneWidget);

      // Commit Drop
      await tester.tap(commitBtn);
      await tester.pumpAndSettle();

      // Celebration Step
      expect(find.text('Your Booking Drop is Live!'), findsOneWidget);
      expect(find.text('flash.ink/@artist/books'), findsOneWidget);
      expect(find.text('Done & Return to Dashboard'), findsOneWidget);

      // Verify repository updated
      expect(ArtistDashboardRepository.bookingMode, BookingMode.drops);
      expect(ArtistDashboardRepository.currentBookDrop, isNotNull);
    });

    testWidgets('Scheduling a future drop displays launch date/time pickers and commits as scheduled', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CreateBookDropScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final continueBtn = find.text('Continue ➔');
      await tester.tap(continueBtn); // Step 1 -> 2
      await tester.pumpAndSettle();

      await tester.tap(continueBtn); // Step 2 -> 3
      await tester.pumpAndSettle();

      // Select Schedule Future Launch Date & Time
      final scheduleOption = find.text('Schedule Future Launch Date & Time');
      await tester.ensureVisible(scheduleOption);
      await tester.tap(scheduleOption);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('scheduled_launch_date_picker')), findsOneWidget);
      expect(find.byKey(const Key('scheduled_launch_time_picker')), findsOneWidget);

      await tester.tap(continueBtn); // Step 3 -> 4
      await tester.pumpAndSettle();

      expect(find.textContaining('Scheduled:'), findsOneWidget);

      final commitBtn = find.byKey(const Key('commit_book_drop_button'));
      await tester.tap(commitBtn);
      await tester.pumpAndSettle();

      expect(find.text('Your Booking Drop is Scheduled!'), findsOneWidget);
      expect(ArtistDashboardRepository.currentBookDrop?.status, BookDropStatus.scheduled);
      expect(ArtistDashboardRepository.booksSchedule.isBooksOpen, isFalse);
    });
  });
}
