import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flash_ink/services/auth_service.dart';
import 'package:flash_ink/screens/phone_entry_screen.dart';
import 'package:flash_ink/screens/phone_verification_screen.dart';
import 'package:flash_ink/screens/email_auth_screen.dart';
import 'package:flash_ink/screens/email_verification_screen.dart';
import 'package:flash_ink/screens/client_edit_profile_screen.dart';
import 'package:flash_ink/screens/client_aesthetics_screen.dart';
import 'package:flash_ink/screens/artist_dashboard/artist_edit_profile_screen.dart';
import 'package:flash_ink/screens/artist_dashboard/booking_request_detail_screen.dart';
import 'package:flash_ink/screens/artist_dashboard/appointment_detail_screen.dart';
import 'package:flash_ink/models/artist_dashboard_data.dart';

class MockUser extends Fake implements User {
  @override
  String get uid => 'mock-uid-123';
  @override
  String? get email => 'test@flash.ink';
  @override
  String? get displayName => 'Test User';
}

class FakeAuthService extends Fake implements AuthService {
  final _controller = StreamController<User?>.broadcast();
  User? _currentUser = MockUser();

  @override
  User? get currentUser => _currentUser;

  @override
  Stream<User?> get authStateChanges => _controller.stream;

  @override
  Future<void> signOut() async {
    _currentUser = null;
    _controller.add(null);
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('Pinned Bottom CTA Verification Across All Target Screens', () {
    testWidgets('PhoneEntryScreen: CTA is pinned outside SingleChildScrollView', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PhoneEntryScreen(
            role: 'client',
            authService: FakeAuthService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scrollFinder = find.byType(SingleChildScrollView);
      expect(scrollFinder, findsOneWidget);

      final ctaFinder = find.widgetWithText(ElevatedButton, 'SEND VERIFICATION CODE');
      expect(ctaFinder, findsOneWidget);

      // Verify CTA is NOT inside SingleChildScrollView
      expect(find.descendant(of: scrollFinder, matching: ctaFinder), findsNothing);
    });

    testWidgets('PhoneVerificationScreen: CTA and Resend are pinned outside SingleChildScrollView', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PhoneVerificationScreen(
            phoneNumber: '+15550192834',
            role: 'client',
            authService: FakeAuthService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scrollFinder = find.byType(SingleChildScrollView);
      expect(scrollFinder, findsOneWidget);

      final ctaFinder = find.widgetWithText(ElevatedButton, 'VERIFY');
      expect(ctaFinder, findsOneWidget);
      expect(find.descendant(of: scrollFinder, matching: ctaFinder), findsNothing);

      final resendFinder = find.text('Resend');
      expect(resendFinder, findsOneWidget);
      expect(find.descendant(of: scrollFinder, matching: resendFinder), findsNothing);
    });

    testWidgets('EmailAuthScreen: CTA is pinned outside SingleChildScrollView', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: EmailAuthScreen(
            role: 'client',
            authService: FakeAuthService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scrollFinder = find.byType(SingleChildScrollView);
      expect(scrollFinder, findsOneWidget);

      final ctaFinder = find.widgetWithText(ElevatedButton, 'CREATE ACCOUNT');
      expect(ctaFinder, findsOneWidget);
      expect(find.descendant(of: scrollFinder, matching: ctaFinder), findsNothing);
    });

    testWidgets('EmailVerificationScreen: CTA is pinned outside SingleChildScrollView', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: EmailVerificationScreen(
            role: 'client',
            authService: FakeAuthService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scrollFinder = find.byType(SingleChildScrollView);
      expect(scrollFinder, findsOneWidget);

      final ctaFinder = find.widgetWithText(ElevatedButton, "I've Verified My Email");
      expect(ctaFinder, findsOneWidget);
      expect(find.descendant(of: scrollFinder, matching: ctaFinder), findsNothing);
    });

    testWidgets('ClientEditProfileScreen: CTA is inline inside SingleChildScrollView (Option C)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ClientEditProfileScreen(
            initialUsername: 'flashink_user',
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scrollFinder = find.byType(SingleChildScrollView);
      expect(scrollFinder, findsOneWidget);

      final ctaFinder = find.byKey(const Key('account_save_profile_button'));
      expect(ctaFinder, findsOneWidget);
      expect(find.descendant(of: scrollFinder, matching: ctaFinder), findsOneWidget);
    });

    testWidgets('ClientAestheticsScreen: CTA is inline inside SingleChildScrollView (Option C)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ClientAestheticsScreen(
            initialAesthetics: ['blackwork', 'fine_line'],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scrollFinder = find.byType(SingleChildScrollView);
      expect(scrollFinder, findsOneWidget);

      final ctaFinder = find.byKey(const Key('account_save_aesthetics_button'));
      expect(ctaFinder, findsOneWidget);
      expect(find.descendant(of: scrollFinder, matching: ctaFinder), findsOneWidget);
    });

    testWidgets('ArtistEditProfileScreen: CTA is inline inside SingleChildScrollView (Option C)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ArtistEditProfileScreen(
            initialDisplayName: 'OddMaree',
            initialUsername: 'oddmaree',
            initialBio: 'Tattoo artist in Brooklyn',
            initialLocation: 'Brooklyn, NY',
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scrollFinder = find.byType(SingleChildScrollView);
      expect(scrollFinder, findsOneWidget);

      final ctaFinder = find.byKey(const Key('save_profile_button'));
      expect(ctaFinder, findsOneWidget);
      expect(find.descendant(of: scrollFinder, matching: ctaFinder), findsOneWidget);
    });

    testWidgets('BookingRequestDetailScreen: Accept CTA is inline inside SingleChildScrollView (Option C)', (tester) async {
      const mockRequest = BookingRequest(
        id: 'REQ-101',
        clientName: 'Alex Rivera',
        timeAgo: '10m ago',
        conceptDescription: 'Forearm placement',
        sketchImageUrl: 'assets/images/flash_traditional_dagger.jpg',
        estimatedPrice: 250,
        deposit: 50,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: BookingRequestDetailScreen(
            request: mockRequest,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scrollFinder = find.byType(SingleChildScrollView);
      expect(scrollFinder, findsOneWidget);

      final ctaFinder = find.byKey(const Key('accept_request_button'));
      expect(ctaFinder, findsOneWidget);
      expect(find.descendant(of: scrollFinder, matching: ctaFinder), findsOneWidget);

      // Verify secondary actions REMAIN inside the scroll view
      final proposeFinder = find.byKey(const Key('propose_time_button'));
      final declineFinder = find.byKey(const Key('decline_request_button'));
      expect(find.descendant(of: scrollFinder, matching: proposeFinder), findsOneWidget);
      expect(find.descendant(of: scrollFinder, matching: declineFinder), findsOneWidget);
    });

    testWidgets('AppointmentDetailScreen: Message CTA is inline inside SingleChildScrollView (Option C)', (tester) async {
      const mockAppointment = DashboardAppointment(
        id: 'APT-101',
        clientName: 'Maya Lin',
        serviceType: 'Flash Tattoo',
        duration: '2 hours',
        time: '11:00 AM',
        fullPrice: 300,
        depositPaid: 60,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: AppointmentDetailScreen(
            appointment: mockAppointment,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scrollFinder = find.byType(SingleChildScrollView);
      expect(scrollFinder, findsOneWidget);

      final ctaFinder = find.byKey(const Key('message_client_button'));
      expect(ctaFinder, findsOneWidget);
      expect(find.descendant(of: scrollFinder, matching: ctaFinder), findsOneWidget);

      // Verify secondary actions REMAIN inside the scroll view
      final rescheduleFinder = find.byKey(const Key('reschedule_appointment_button'));
      final cancelFinder = find.byKey(const Key('cancel_appointment_button'));
      expect(find.descendant(of: scrollFinder, matching: rescheduleFinder), findsOneWidget);
      expect(find.descendant(of: scrollFinder, matching: cancelFinder), findsOneWidget);
    });
  });
}
