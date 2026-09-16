import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';

import 'package:flash_ink/models/artist.dart';
import 'package:flash_ink/screens/artist_dashboard/artist_calendar_screen.dart';
import 'package:flash_ink/screens/artist_dashboard/artist_dashboard_screen.dart';
import 'package:flash_ink/screens/artist_dashboard/appointment_detail_screen.dart';
import 'package:flash_ink/services/auth_service.dart';

class MockTestUser extends Fake implements User {
  @override
  final String uid;
  @override
  final String? displayName;

  MockTestUser({required this.uid, this.displayName});
}

class FakeDashboardAuthService extends AuthService {
  final MockTestUser user = MockTestUser(uid: 'artist_oddmaree', displayName: 'OddMaree');
  bool signedOut = false;

  @override
  User? get currentUser => user;

  @override
  Future<void> signOut() async {
    signedOut = true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  group('Artist Calendar Screen Tests', () {
    late FakeDashboardAuthService fakeAuth;

    setUp(() {
      fakeAuth = FakeDashboardAuthService();
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      binding.platformDispatcher.views.first.physicalSize = const Size(1080, 2400);
      binding.platformDispatcher.views.first.devicePixelRatio = 1.0;
    });

    tearDown(() {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      binding.platformDispatcher.views.first.resetPhysicalSize();
      binding.platformDispatcher.views.first.resetDevicePixelRatio();
    });

    Widget buildCalendarTestWidget({Artist? artist, bool isEmbedded = false}) {
      return MaterialApp(
        home: ArtistCalendarScreen(
          artist: artist,
          authService: fakeAuth,
          isEmbeddedInTab: isEmbedded,
        ),
      );
    }

    testWidgets('Renders all visual components matching the Figma mockup', (tester) async {
      await tester.pumpWidget(buildCalendarTestWidget());
      await tester.pumpAndSettle();

      // Top action bar
      expect(find.byKey(const Key('calendar_tattoo_machine_logo')), findsOneWidget);
      expect(find.byKey(const Key('calendar_artist_avatar_button')), findsOneWidget);

      // Title
      expect(find.text('Calendar'), findsOneWidget);

      // Month & Year dropdowns
      expect(find.byKey(const Key('calendar_month_dropdown')), findsOneWidget);
      expect(find.byKey(const Key('calendar_year_dropdown')), findsOneWidget);
      expect(find.text('Sep'), findsOneWidget);
      expect(find.text('2026'), findsOneWidget);

      // Weekday headers
      for (final day in ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa']) {
        expect(find.text(day), findsOneWidget);
      }

      // Selected day 9
      expect(find.byKey(const Key('calendar_day_9')), findsOneWidget);

      // Schedule header
      expect(find.text("Today's Schedule"), findsOneWidget);
      expect(find.byKey(const Key('calendar_view_all_button')), findsOneWidget);
      expect(find.text('VIEW ALL'), findsOneWidget);

      // Initial appointments for Sep 9
      expect(find.text('Marcus Cole'), findsWidgets);
      expect(find.text('Elena Rostova'), findsOneWidget);
      expect(find.text('Jennie Banks'), findsWidgets);
      expect(find.text('2:00 PM'), findsWidgets);
      expect(find.text('3:30 PM'), findsOneWidget);
      expect(find.text('6:30 PM'), findsWidgets);
    });

    testWidgets('Tapping a date updates selection and filters schedule', (tester) async {
      await tester.pumpWidget(buildCalendarTestWidget());
      await tester.pumpAndSettle();

      // Tap on Day 12
      final day12Finder = find.byKey(const Key('calendar_day_12'));
      expect(day12Finder, findsOneWidget);
      await tester.tap(day12Finder);
      await tester.pumpAndSettle();

      // Header should update to "Sep 12 Schedule"
      expect(find.text('Sep 12 Schedule'), findsOneWidget);

      // Schedule should now display Sarah Jenkins
      expect(find.text('Sarah Jenkins'), findsOneWidget);
      expect(find.text('Neo-traditional TIGER • 3 hrs'), findsOneWidget);
    });

    testWidgets('Tapping the trailing arrow button toggles inline details accordion', (tester) async {
      await tester.pumpWidget(buildCalendarTestWidget());
      await tester.pumpAndSettle();

      // Elena Rostova appointment
      expect(find.byKey(const Key('calendar_arrow_cal_apt_elena_1')), findsOneWidget);
      expect(find.byKey(const Key('calendar_expanded_panel_cal_apt_elena_1')), findsNothing);

      // Tap arrow to expand
      await tester.tap(find.byKey(const Key('calendar_arrow_cal_apt_elena_1')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('calendar_expanded_panel_cal_apt_elena_1')), findsOneWidget);
      expect(find.text('Message Client'), findsOneWidget);
      expect(find.text('Full Details'), findsOneWidget);
      expect(find.text('Placement: Upper Arm / Half Sleeve'), findsOneWidget);

      // Tap arrow again to collapse
      await tester.tap(find.byKey(const Key('calendar_arrow_cal_apt_elena_1')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('calendar_expanded_panel_cal_apt_elena_1')), findsNothing);
    });

    testWidgets('Tapping appointment item navigates to AppointmentDetailScreen', (tester) async {
      await tester.pumpWidget(buildCalendarTestWidget());
      await tester.pumpAndSettle();

      final itemFinder = find.byKey(const Key('calendar_appointment_item_cal_apt_elena_1'));
      expect(itemFinder, findsOneWidget);

      await tester.tap(itemFinder);
      await tester.pumpAndSettle();

      expect(find.byType(AppointmentDetailScreen), findsOneWidget);
      expect(find.text('Appointment Details'), findsOneWidget);
    });

    testWidgets('Tapping VIEW ALL opens all appointments bottom sheet', (tester) async {
      await tester.pumpWidget(buildCalendarTestWidget());
      await tester.pumpAndSettle();

      final viewAllBtn = find.byKey(const Key('calendar_view_all_button'));
      await tester.tap(viewAllBtn);
      await tester.pumpAndSettle();

      expect(find.text('All Scheduled Sessions'), findsOneWidget);
      expect(find.byKey(const Key('all_appointments_sheet_item_cal_apt_marcus_2')), findsOneWidget);
    });

    testWidgets('Tapping avatar opens profile settings modal', (tester) async {
      await tester.pumpWidget(buildCalendarTestWidget());
      await tester.pumpAndSettle();

      final avatarBtn = find.byKey(const Key('calendar_artist_avatar_button'));
      await tester.tap(avatarBtn);
      await tester.pumpAndSettle();

      expect(find.text('View Public Profile'), findsOneWidget);
      expect(find.text('Edit Pricing & Policies'), findsOneWidget);
      expect(find.text('Sign Out'), findsOneWidget);
    });

    testWidgets('Selecting Tab 1 on ArtistDashboardScreen displays ArtistCalendarScreen', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ArtistDashboardScreen(
            authService: fakeAuth,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Bottom nav item for Calendar is nav_item_1
      final calendarTabFinder = find.byKey(const Key('nav_item_1'));
      expect(calendarTabFinder, findsOneWidget);

      await tester.tap(calendarTabFinder);
      await tester.pumpAndSettle();

      // Calendar screen is now visible
      expect(find.byType(ArtistCalendarScreen), findsOneWidget);
      expect(find.text('Calendar'), findsOneWidget);
      expect(find.byKey(const Key('calendar_day_9')), findsOneWidget);
    });
  });
}
