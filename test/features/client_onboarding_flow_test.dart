import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flash_ink/services/auth_service.dart';
import 'package:flash_ink/screens/aesthetics_selection_screen.dart';
import 'package:flash_ink/screens/main_feed_screen.dart';
import 'package:flash_ink/features/onboarding/client/client_notifications_screen.dart';

class MockClientUser extends Fake implements User {
  @override
  final String uid = 'client_test_999';
  @override
  final String? email = 'client@flash.ink';
  @override
  final String? displayName = 'Aesthetic Collector';
}

class FakeClientFlowAuthService extends AuthService {
  final MockClientUser user = MockClientUser();

  @override
  User? get currentUser => user;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await Firebase.initializeApp();
  });

  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.physicalSize = const Size(1080, 2400);
    binding.platformDispatcher.views.first.devicePixelRatio = 1.0;
  });

  tearDown(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.resetPhysicalSize();
    binding.platformDispatcher.views.first.resetDevicePixelRatio();
  });

  group('Client Onboarding Flow & Layout Contract Test Suite', () {
    testWidgets('Sequential navigation from AestheticsSelectionScreen through ClientNotificationsScreen to MainFeedScreen', (tester) async {
      final fakeAuth = FakeClientFlowAuthService();

      await tester.pumpWidget(
        MaterialApp(
          home: AestheticsSelectionScreen(
            authService: fakeAuth,
            navigateToOnboarding: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Select Traditional style
      await tester.tap(find.text('TRADITIONAL'));
      await tester.pumpAndSettle();

      // Tap Continue -> advances to Notification Permissions
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Notification Permissions
      expect(find.byType(ClientNotificationsScreen), findsOneWidget);
      expect(find.text('Never miss a drop'), findsOneWidget);
      expect(find.text('Instant Flash Drops'), findsOneWidget);
      expect(find.text('Books Open Alerts'), findsOneWidget);
      expect(find.text('Direct Messages & Updates'), findsOneWidget);

      // Tap DONE
      final doneButton = find.byKey(const Key('client_notifications_done_button'));
      expect(doneButton, findsOneWidget);
      await tester.tap(doneButton);
      await tester.pumpAndSettle();

      // Successfully completes to MainFeedScreen
      expect(find.byType(MainFeedScreen), findsOneWidget);
      expect(find.text('Browse Artists'), findsOneWidget);
    });

    testWidgets('Tapping Skip on ClientNotificationsScreen completes to MainFeedScreen', (tester) async {
      final fakeAuth = FakeClientFlowAuthService();

      await tester.pumpWidget(
        MaterialApp(
          home: ClientNotificationsScreen(authService: fakeAuth),
        ),
      );
      await tester.pumpAndSettle();

      final skipButton = find.byKey(const Key('onboarding_skip_button'));
      expect(skipButton, findsOneWidget);
      await tester.tap(skipButton);
      await tester.pumpAndSettle();

      expect(find.byType(MainFeedScreen), findsOneWidget);
    });
  });
}
