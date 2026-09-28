import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flash_ink/models/artist.dart';
import 'package:flash_ink/models/artist_dashboard_data.dart';
import 'package:flash_ink/screens/artist_dashboard/artist_books_screen.dart';
import 'package:flash_ink/services/auth_service.dart';

class MockBooksUser extends Fake implements User {
  @override
  final String uid;
  @override
  final String? displayName;
  @override
  final String? email;

  MockBooksUser({
    required this.uid,
    this.displayName,
    this.email,
  });
}

class FakeBooksAuthService extends AuthService {
  final User? _user;
  FakeBooksAuthService([this._user]);

  @override
  User? get currentUser => _user;
}

void main() {
  setupFirebaseAuthMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  group('ArtistBooksScreen Widget Tests', () {
    late FakeBooksAuthService fakeAuth;

    setUp(() {
      fakeAuth = FakeBooksAuthService(
        MockBooksUser(uid: 'test_artist', displayName: 'OddMaree', email: 'artist@flash.ink'),
      );
      // Reset default schedule
      ArtistDashboardRepository.updateBooksSchedule(
        const ArtistBooksSchedule(
          isBooksOpen: true,
          bookingWindowStart: DateTime(2026, 10, 1),
          bookingWindowEnd: DateTime(2026, 12, 31),
          workingDays: {2, 3, 4, 5, 6},
          startTime: TimeOfDay(hour: 11, minute: 0),
          endTime: TimeOfDay(hour: 19, minute: 0),
          slotDurationMinutes: 120,
          bufferDurationMinutes: 30,
          defaultDepositAmount: 80,
          acceptFlash: true,
          acceptCustom: true,
          acceptTouchUps: true,
          locationNote: 'OddMaree Studio • Portland, OR',
        ),
      );
    });

    Widget buildTestWidget({bool isEmbedded = true, Artist? artist}) {
      return MaterialApp(
        home: Scaffold(
          body: ArtistBooksScreen(
            artist: artist,
            authService: fakeAuth,
            isEmbeddedInTab: isEmbedded,
          ),
        ),
      );
    }

    testWidgets('Renders all primary sections matching design', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Header
      expect(find.text('Books & Schedule'), findsOneWidget);
      expect(find.text('Manage your client booking windows, working days, and session rules.'), findsOneWidget);

      // Status hero card
      expect(find.byKey(const Key('books_status_card')), findsOneWidget);
      expect(find.text('BOOKS OPEN'), findsOneWidget);
      expect(find.text('Accepting New Appointments'), findsOneWidget);
      expect(find.byKey(const Key('books_status_switch')), findsOneWidget);

      // Booking window
      expect(find.text('BOOKING WINDOW'), findsOneWidget);
      expect(find.byKey(const Key('booking_window_picker_button')), findsOneWidget);
      expect(find.text('OPEN DATE'), findsOneWidget);
      expect(find.text('CLOSE DATE'), findsOneWidget);

      // Weekly working days
      expect(find.text('WEEKLY WORKING DAYS'), findsOneWidget);
      for (int i = 1; i <= 7; i++) {
        expect(find.byKey(Key('working_day_$i')), findsOneWidget);
      }

      // Hours & slot sizing
      expect(find.text('HOURS & SLOT SIZING'), findsOneWidget);
      expect(find.byKey(const Key('books_start_time_button')), findsOneWidget);
      expect(find.byKey(const Key('books_end_time_button')), findsOneWidget);
      expect(find.text('DEFAULT SLOT DURATION'), findsOneWidget);
      expect(find.text('BUFFER BETWEEN SESSIONS'), findsOneWidget);

      // Accepted types
      expect(find.text('ACCEPTED SESSION TYPES'), findsOneWidget);
      expect(find.text('Flash Tattoos'), findsOneWidget);
      expect(find.text('Custom Concepts'), findsOneWidget);
      expect(find.text('Touch-ups & Consultations'), findsOneWidget);

      // Location
      expect(find.text('STUDIO OR GUEST SPOT LOCATION'), findsOneWidget);
      expect(find.byKey(const Key('books_location_field')), findsOneWidget);

      // Save button
      expect(find.byKey(const Key('save_books_schedule_button')), findsOneWidget);
      expect(find.text('Save Books Schedule'), findsOneWidget);
    });

    testWidgets('Toggling Books Open switch updates status text dynamically', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('BOOKS OPEN'), findsOneWidget);
      expect(find.text('Accepting New Appointments'), findsOneWidget);

      // Toggle switch to closed
      await tester.tap(find.byKey(const Key('books_status_switch')));
      await tester.pumpAndSettle();

      expect(find.text('BOOKS CLOSED'), findsOneWidget);
      expect(find.text('Currently Closed to Inquiries'), findsOneWidget);

      // Toggle switch back to open
      await tester.tap(find.byKey(const Key('books_status_switch')));
      await tester.pumpAndSettle();

      expect(find.text('BOOKS OPEN'), findsOneWidget);
      expect(find.text('Accepting New Appointments'), findsOneWidget);
    });

    testWidgets('Tapping working day toggles day selection', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Monday (1) is initially inactive in default {2,3,4,5,6}
      final monChip = find.byKey(const Key('working_day_1'));
      expect(monChip, findsOneWidget);

      // Tap Monday to activate
      await tester.tap(monChip);
      await tester.pumpAndSettle();

      // Tap Saturday (6) to deactivate
      final satChip = find.byKey(const Key('working_day_6'));
      await tester.tap(satChip);
      await tester.pumpAndSettle();

      // Tap Save
      await tester.tap(find.byKey(const Key('save_books_schedule_button')));
      await tester.pumpAndSettle();

      // Verify repository updated working days contains 1 and not 6
      expect(ArtistDashboardRepository.booksSchedule.workingDays.contains(1), isTrue);
      expect(ArtistDashboardRepository.booksSchedule.workingDays.contains(6), isFalse);
    });

    testWidgets('Editing location and saving updates repository and shows SnackBar', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Enter new studio location
      final locationField = find.byKey(const Key('books_location_field'));
      await tester.enterText(locationField, 'Guest Spot: Black Rabbit Tattoo, Seattle');
      await tester.pumpAndSettle();

      // Tap save
      final saveButton = find.byKey(const Key('save_books_schedule_button'));
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      // Verify SnackBar
      expect(find.text('Books schedule saved successfully!'), findsOneWidget);

      // Verify repository was updated
      expect(
        ArtistDashboardRepository.booksSchedule.locationNote,
        'Guest Spot: Black Rabbit Tattoo, Seattle',
      );
    });
  });
}
