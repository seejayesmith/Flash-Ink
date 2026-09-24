import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';

import 'package:flash_ink/models/artist.dart';
import 'package:flash_ink/screens/artist_dashboard/artist_dashboard_screen.dart';
import 'package:flash_ink/screens/artist_dashboard/appointment_detail_screen.dart';
import 'package:flash_ink/screens/artist_dashboard/artist_calendar_screen.dart';
import 'package:flash_ink/screens/artist_dashboard/artist_earnings_screen.dart';
import 'package:flash_ink/screens/artist_dashboard/booking_request_detail_screen.dart';
import 'package:flash_ink/screens/artist_onboarding/artist_share_link_screen.dart';
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

  group('Artist Dashboard Tests', () {
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

    Widget buildTestWidget({Artist? artist}) {
      return MaterialApp(
        home: ArtistDashboardScreen(
          artist: artist,
          authService: fakeAuth,
        ),
      );
    }

    testWidgets('Renders all essential dashboard sections matching design', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // 1. Top action bar
      expect(find.byKey(const Key('tattoo_machine_logo')), findsOneWidget);
      expect(find.byKey(const Key('artist_avatar_button')), findsOneWidget);

      // 2. Header row
      expect(find.text('OddMaree'), findsOneWidget);

      // 3. Metrics cards
      expect(find.byKey(const Key('metric_bookings_this_week')), findsOneWidget);
      expect(find.byKey(const Key('metric_new_requests')), findsOneWidget);
      expect(find.text('12'), findsWidgets); // Booking metric + badge
      expect(find.text('2'), findsWidgets);
      expect(find.text('BOOKINGS THIS WEEK'), findsOneWidget);
      expect(find.text('NEW REQUESTS'), findsOneWidget);

      // 4. Hero Next Appointment card
      expect(find.byKey(const Key('hero_next_appointment_card')), findsOneWidget);
      expect(find.text('Next Appointment'), findsOneWidget);
      expect(find.text('10:00 AM'), findsOneWidget);
      expect(find.text('Sarah Jenkins'), findsWidgets);
      expect(find.text('Neo-traditional TIGER • 3 hrs'), findsOneWidget);
      expect(find.byKey(const Key('hero_view_details_button')), findsOneWidget);

      // 5. Today's Schedule section
      expect(find.text("Today's Schedule"), findsOneWidget);
      expect(find.byKey(const Key('schedule_view_all_button')), findsOneWidget);
      expect(find.text('Sally McField'), findsOneWidget);
      expect(find.text('Tom Hanks'), findsOneWidget);
      expect(find.text('Jennie Banks'), findsOneWidget);

      // 6. Pending Requests section
      expect(find.text('Pending Requests'), findsOneWidget);
      expect(find.text('Neo-traditional panther head on outer thigh. Looking for heavy blackwork.'), findsOneWidget);

      // 7. Bottom Navigation bar
      expect(find.text('DASHBOARD'), findsOneWidget);
      expect(find.text('CALENDAR'), findsOneWidget);
      expect(find.text('MESSAGES'), findsOneWidget);
      expect(find.text('EARNINGS'), findsOneWidget);
    });

    testWidgets('Tapping View Details on Next Appointment opens AppointmentDetailScreen', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final viewDetailsButton = find.byKey(const Key('hero_view_details_button'));
      expect(viewDetailsButton, findsOneWidget);
      await tester.tap(viewDetailsButton);
      await tester.pumpAndSettle();

      expect(find.byType(AppointmentDetailScreen), findsOneWidget);
      expect(find.text('Appointment Details'), findsOneWidget);
      expect(find.text('Message Client'), findsOneWidget);
      expect(find.text('Reschedule Appointment'), findsOneWidget);
      expect(find.text('Cancel Appointment'), findsOneWidget);
      expect(find.text('Balance Due Upon Completion'), findsOneWidget);

      // Tap back button
      await tester.tap(find.byKey(const Key('appointment_back_button')));
      await tester.pumpAndSettle();
      expect(find.byType(ArtistDashboardScreen), findsOneWidget);
    });

    testWidgets('Tapping a schedule row opens AppointmentDetailScreen', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sally McField'));
      await tester.pumpAndSettle();

      expect(find.byType(AppointmentDetailScreen), findsOneWidget);
      expect(find.text('Sally McField'), findsOneWidget);
      expect(find.text('Consultation'), findsWidgets);

      await tester.tap(find.byKey(const Key('appointment_back_button')));
      await tester.pumpAndSettle();
      expect(find.byType(ArtistDashboardScreen), findsOneWidget);
    });

    testWidgets('Tapping schedule arrows expands appointment inline within container and collapses on tap again', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Initially, expanded panels are not visible
      expect(find.byKey(const Key('expanded_schedule_panel_apt_sally')), findsNothing);
      expect(find.byKey(const Key('expanded_schedule_panel_apt_tom')), findsNothing);

      // Tap the arrow for Sally McField
      final sallyArrow = find.byKey(const Key('schedule_arrow_apt_sally'));
      expect(sallyArrow, findsOneWidget);
      await tester.tap(sallyArrow);
      await tester.pumpAndSettle();

      // Expanded panel for Sally is now visible with details
      expect(find.byKey(const Key('expanded_schedule_panel_apt_sally')), findsOneWidget);
      expect(find.text('Backpiece Discussion'), findsOneWidget);
      expect(find.text('Initial consultation to map out placement, flow, and references for full back dragon.'), findsOneWidget);
      expect(find.text('Due: '), findsWidgets);
      expect(find.text('\$50'), findsWidgets);
      expect(find.byKey(const Key('expanded_view_details_apt_sally')), findsOneWidget);
      expect(find.byKey(const Key('expanded_message_apt_sally')), findsOneWidget);

      // Tap the arrow for Tom Hanks as well (multiple appointments can expand independently)
      final tomArrow = find.byKey(const Key('schedule_arrow_apt_tom'));
      expect(tomArrow, findsOneWidget);
      await tester.tap(tomArrow);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('expanded_schedule_panel_apt_sally')), findsOneWidget);
      expect(find.byKey(const Key('expanded_schedule_panel_apt_tom')), findsOneWidget);
      expect(find.text('Traditional anchor & swallow flash piece with red banner.'), findsOneWidget);
      expect(find.text('\$220'), findsOneWidget);

      // Tap View Details inside expanded Sally card opens AppointmentDetailScreen
      await tester.tap(find.byKey(const Key('expanded_view_details_apt_sally')));
      await tester.pumpAndSettle();
      expect(find.byType(AppointmentDetailScreen), findsOneWidget);
      expect(find.text('Sally McField'), findsOneWidget);

      // Return to dashboard
      await tester.tap(find.byKey(const Key('appointment_back_button')));
      await tester.pumpAndSettle();
      expect(find.byType(ArtistDashboardScreen), findsOneWidget);

      // Tap Sally's arrow again to collapse it
      await tester.tap(find.byKey(const Key('schedule_arrow_apt_sally')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('expanded_schedule_panel_apt_sally')), findsNothing);
      // Tom should remain expanded
      expect(find.byKey(const Key('expanded_schedule_panel_apt_tom')), findsOneWidget);
    });

    testWidgets('Tapping View details on pending request opens BookingRequestDetailScreen', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final firstPendingLink = find.byKey(const Key('view_details_link_req_sarah_1'));
      await tester.ensureVisible(firstPendingLink);
      await tester.pumpAndSettle();

      await tester.tap(firstPendingLink);
      await tester.pumpAndSettle();

      expect(find.byType(BookingRequestDetailScreen), findsOneWidget);
      expect(find.text('Request Details'), findsOneWidget);
      expect(find.text('Accept Request'), findsOneWidget);
      expect(find.text('Propose New Time'), findsOneWidget);
      expect(find.text('Decline Request'), findsOneWidget);

      // Back navigation
      await tester.tap(find.byKey(const Key('request_back_button')));
      await tester.pumpAndSettle();
      expect(find.byType(ArtistDashboardScreen), findsOneWidget);
    });

    testWidgets('Tapping avatar opens profile modal with View Public Profile', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('artist_avatar_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('modal_view_public_profile')), findsOneWidget);
      expect(find.byKey(const Key('modal_sign_out')), findsOneWidget);
    });

    testWidgets('Bottom navigation tabs switch smoothly between views', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Tap Calendar
      await tester.tap(find.byKey(const Key('nav_item_1')));
      await tester.pumpAndSettle();
      expect(find.byType(ArtistCalendarScreen), findsOneWidget);
      expect(find.byKey(const Key('calendar_day_9')), findsOneWidget);

      // Tap Messages
      await tester.tap(find.byKey(const Key('nav_item_2')));
      await tester.pumpAndSettle();
      expect(find.text('Client Messages'), findsOneWidget);

      // Tap Earnings
      await tester.tap(find.byKey(const Key('nav_item_3')));
      await tester.pumpAndSettle();
      expect(find.byType(ArtistEarningsScreen), findsOneWidget);
      expect(find.byKey(const Key('next_payout_card')), findsOneWidget);

      // Return to Bookings
      await tester.tap(find.byKey(const Key('nav_item_0')));
      await tester.pumpAndSettle();
      expect(find.text("Today's Schedule"), findsOneWidget);
    });

    testWidgets('ArtistShareLinkScreen completes onboarding and navigates to ArtistDashboardScreen', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ArtistShareLinkScreen(
            artistName: 'OddMaree',
            authService: fakeAuth,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final doneButton = find.byKey(const Key('done_share_button'));
      expect(doneButton, findsOneWidget);

      await tester.ensureVisible(doneButton);
      await tester.pumpAndSettle();

      await tester.tap(doneButton);
      await tester.pumpAndSettle();

      expect(find.byType(ArtistDashboardScreen), findsOneWidget);
      expect(find.text('OddMaree'), findsOneWidget);
    });
  });
}
