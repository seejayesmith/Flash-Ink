import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flash_ink/services/auth_service.dart';
import 'package:flash_ink/screens/main_feed_screen.dart';
import 'package:flash_ink/features/onboarding/client/client_style_discovery_screen.dart';
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
    testWidgets('Sequential navigation through Style Discovery and Notifications to MainFeedScreen (Home Base removed)', (tester) async {
      final fakeAuth = FakeClientFlowAuthService();

      await tester.pumpWidget(
        MaterialApp(
          home: ClientStyleDiscoveryScreen(authService: fakeAuth),
        ),
      );
      await tester.pumpAndSettle();

      // Style Discovery
      expect(find.text('Discover your style'), findsOneWidget);
      expect(find.text('Pick the styles you love. We\'ll tailor your feed and artist recommendations.'), findsOneWidget);

      // Select Traditional style
      final traditionalChip = find.byKey(const Key('style_tag_traditional'));
      expect(traditionalChip, findsOneWidget);
      await tester.tap(traditionalChip);
      await tester.pumpAndSettle();

      // Tap CONTINUE -> advances directly to Notification Permissions (Home Base removed)
      final step1Continue = find.byKey(const Key('client_styles_continue_button'));
      expect(step1Continue, findsOneWidget);
      await tester.tap(step1Continue);
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

    testWidgets('Header typography and content baseline remain invariant across Client Onboarding steps', (tester) async {
      final fakeAuth = FakeClientFlowAuthService();

      // Style Discovery Positions
      await tester.pumpWidget(
        MaterialApp(home: ClientStyleDiscoveryScreen(authService: fakeAuth)),
      );
      await tester.pumpAndSettle();

      final titleTopStep1 = tester.getTopLeft(find.byKey(const Key('onboarding_title'))).dy;
      final subtitleTopStep1 = tester.getTopLeft(find.byKey(const Key('onboarding_subtitle'))).dy;
      final ctaTopStep1 = tester.getTopLeft(find.byType(ElevatedButton)).dy;

      // Notifications Positions
      await tester.pumpWidget(
        MaterialApp(home: ClientNotificationsScreen(authService: fakeAuth)),
      );
      await tester.pumpAndSettle();

      final titleTopStep2 = tester.getTopLeft(find.byKey(const Key('onboarding_title'))).dy;
      final subtitleTopStep2 = tester.getTopLeft(find.byKey(const Key('onboarding_subtitle'))).dy;
      final ctaTopStep2 = tester.getTopLeft(find.byType(ElevatedButton)).dy;

      // Assert identical coordinates across steps (zero visual jitter)
      expect(titleTopStep2, equals(titleTopStep1), reason: 'Title offset invariant across client onboarding steps');
      expect(subtitleTopStep2, equals(subtitleTopStep1), reason: 'Subtitle offset invariant across client onboarding steps');
      expect(ctaTopStep2, equals(ctaTopStep1), reason: 'CTA offset invariant across client onboarding steps');
    });

    testWidgets('Tapping Skip on Client Onboarding steps advances forward seamlessly', (tester) async {
      final fakeAuth = FakeClientFlowAuthService();

      await tester.pumpWidget(
        MaterialApp(
          home: ClientStyleDiscoveryScreen(authService: fakeAuth),
        ),
      );
      await tester.pumpAndSettle();

      // Skip on Style Discovery -> advances directly to Notifications
      final skipButton1 = find.byKey(const Key('onboarding_skip_button'));
      expect(skipButton1, findsOneWidget);
      await tester.tap(skipButton1);
      await tester.pumpAndSettle();

      expect(find.byType(ClientNotificationsScreen), findsOneWidget);

      // Skip on Notifications -> completes to MainFeedScreen
      final skipButton2 = find.byKey(const Key('onboarding_skip_button'));
      await tester.tap(skipButton2);
      await tester.pumpAndSettle();

      expect(find.byType(MainFeedScreen), findsOneWidget);
    });
  });
}
