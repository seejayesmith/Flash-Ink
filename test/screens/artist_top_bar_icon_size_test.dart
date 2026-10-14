import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';

import 'package:flash_ink/screens/artist_dashboard/artist_dashboard_screen.dart';
import 'package:flash_ink/screens/artist_dashboard/artist_books_screen.dart';
import 'package:flash_ink/screens/artist_dashboard/artist_calendar_screen.dart';
import 'package:flash_ink/screens/artist_dashboard/artist_earnings_screen.dart';
import 'package:flash_ink/services/auth_service.dart';
import 'package:flash_ink/widgets/tattoo_machine_icon.dart';

class MockUser extends Fake implements User {
  @override
  final String uid = 'test_artist';
  @override
  final String? displayName = 'OddMaree';
  @override
  final String? email = 'artist@test.com';
}

class FakeAuthService extends AuthService {
  final MockUser _user = MockUser();

  @override
  User? get currentUser => _user;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  group('Artist Top Left TattooMachineIcon Size Tests', () {
    testWidgets('ArtistDashboardScreen tab 0 has TattooMachineIcon with size 43', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ArtistDashboardScreen(
            authService: FakeAuthService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final iconFinder = find.byKey(const Key('tattoo_machine_logo'));
      expect(iconFinder, findsOneWidget);
      final TattooMachineIcon icon = tester.widget(iconFinder);
      expect(icon.size, equals(43));
    });

    testWidgets('ArtistDashboardScreen messages tab has top action bar with TattooMachineIcon size 43 and avatar', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ArtistDashboardScreen(
            authService: FakeAuthService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap messages tab (index 2)
      final messagesTabFinder = find.byIcon(Icons.chat_bubble_outline_rounded);
      expect(messagesTabFinder, findsOneWidget);
      await tester.tap(messagesTabFinder);
      await tester.pumpAndSettle();

      final messagesLogoFinder = find.byKey(const Key('messages_tattoo_machine_logo'));
      expect(messagesLogoFinder, findsOneWidget);
      final TattooMachineIcon icon = tester.widget(messagesLogoFinder);
      expect(icon.size, equals(43));

      expect(find.byKey(const Key('messages_artist_avatar_button')), findsOneWidget);
    });

    testWidgets('ArtistCalendarScreen has TattooMachineIcon with size 43', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ArtistCalendarScreen(
            authService: FakeAuthService(),
            isEmbeddedInTab: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final iconFinder = find.byKey(const Key('calendar_tattoo_machine_logo'));
      expect(iconFinder, findsOneWidget);
      final TattooMachineIcon icon = tester.widget(find.descendant(of: iconFinder, matching: find.byType(TattooMachineIcon)));
      expect(icon.size, equals(43));
    });

    testWidgets('ArtistBooksScreen has TattooMachineIcon with size 43', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ArtistBooksScreen(
              authService: FakeAuthService(),
              isEmbeddedInTab: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final iconFinder = find.byKey(const Key('tattoo_machine_logo'));
      expect(iconFinder, findsOneWidget);
      final TattooMachineIcon icon = tester.widget(iconFinder);
      expect(icon.size, equals(43));
    });

    testWidgets('ArtistEarningsScreen has TattooMachineIcon with size 43', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ArtistEarningsScreen(
            authService: FakeAuthService(),
            isEmbeddedInTab: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final iconFinder = find.byKey(const Key('earnings_tattoo_logo'));
      expect(iconFinder, findsOneWidget);
      final TattooMachineIcon icon = tester.widget(iconFinder);
      expect(icon.size, equals(43));
    });
  });
}
