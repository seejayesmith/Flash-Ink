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
import 'package:flash_ink/features/onboarding/client/client_placement_preferences_screen.dart';
import 'package:flash_ink/features/onboarding/client/client_location_screen.dart';
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
    testWidgets('Full 4-Step sequential navigation through Client Onboarding to MainFeedScreen', (tester) async {
      final fakeAuth = FakeClientFlowAuthService();

      await tester.pumpWidget(
        MaterialApp(
          home: ClientStyleDiscoveryScreen(authService: fakeAuth),
        ),
      );
      await tester.pumpAndSettle();

      // Step 1: Style Discovery
      expect(find.text('Discover your style'), findsOneWidget);
      expect(find.text('Pick the styles you love. We\'ll tailor your feed and artist recommendations.'), findsOneWidget);

      // Select Traditional style
      final traditionalChip = find.byKey(const Key('style_tag_traditional'));
      expect(traditionalChip, findsOneWidget);
      await tester.tap(traditionalChip);
      await tester.pumpAndSettle();

      // Tap CONTINUE
      final step1Continue = find.byKey(const Key('client_styles_continue_button'));
      expect(step1Continue, findsOneWidget);
      await tester.tap(step1Continue);
      await tester.pumpAndSettle();

      // Step 2: Placement Preferences
      expect(find.byType(ClientPlacementPreferencesScreen), findsOneWidget);
      expect(find.text('Target placement'), findsOneWidget);
      expect(find.text('Where do you envision your ink? Artists use this to evaluate custom and flash requests.'), findsOneWidget);

      // Select Forearm
      final forearmChip = find.byKey(const Key('placement_tag_forearm'));
      expect(forearmChip, findsOneWidget);
      await tester.tap(forearmChip);
      await tester.pumpAndSettle();

      // Tap CONTINUE
      final step2Continue = find.byKey(const Key('client_placements_continue_button'));
      expect(step2Continue, findsOneWidget);
      await tester.tap(step2Continue);
      await tester.pumpAndSettle();

      // Step 3: Location / ZIP Selection
      expect(find.byType(ClientLocationScreen), findsOneWidget);
      expect(find.text('Your home base'), findsOneWidget);
      expect(find.text('Enter your ZIP code to find studios near you and calibrate your travel radius.'), findsOneWidget);

      // Enter ZIP
      final zipField = find.byKey(const Key('client_zip_input_field'));
      expect(zipField, findsOneWidget);
      await tester.enterText(zipField, '90210');
      await tester.pumpAndSettle();

      // Tap 50mi radius pill
      final radiusPill = find.byKey(const Key('radius_pill_50'));
      expect(radiusPill, findsOneWidget);
      await tester.tap(radiusPill);
      await tester.pumpAndSettle();

      // Tap CONTINUE
      final step3Continue = find.byKey(const Key('client_location_continue_button'));
      expect(step3Continue, findsOneWidget);
      await tester.tap(step3Continue);
      await tester.pumpAndSettle();

      // Step 4: Notification Permissions
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

    testWidgets('Header typography and content baseline remain invariant across all 4 Client Onboarding steps', (tester) async {
      final fakeAuth = FakeClientFlowAuthService();

      // Step 1 Positions
      await tester.pumpWidget(
        MaterialApp(home: ClientStyleDiscoveryScreen(authService: fakeAuth)),
      );
      await tester.pumpAndSettle();

      final titleTopStep1 = tester.getTopLeft(find.byKey(const Key('onboarding_title'))).dy;
      final subtitleTopStep1 = tester.getTopLeft(find.byKey(const Key('onboarding_subtitle'))).dy;
      final ctaTopStep1 = tester.getTopLeft(find.byType(ElevatedButton)).dy;

      // Step 2 Positions
      await tester.pumpWidget(
        MaterialApp(home: ClientPlacementPreferencesScreen(authService: fakeAuth)),
      );
      await tester.pumpAndSettle();

      final titleTopStep2 = tester.getTopLeft(find.byKey(const Key('onboarding_title'))).dy;
      final subtitleTopStep2 = tester.getTopLeft(find.byKey(const Key('onboarding_subtitle'))).dy;
      final ctaTopStep2 = tester.getTopLeft(find.byType(ElevatedButton)).dy;

      // Step 3 Positions
      await tester.pumpWidget(
        MaterialApp(home: ClientLocationScreen(authService: fakeAuth)),
      );
      await tester.pumpAndSettle();

      final titleTopStep3 = tester.getTopLeft(find.byKey(const Key('onboarding_title'))).dy;
      final subtitleTopStep3 = tester.getTopLeft(find.byKey(const Key('onboarding_subtitle'))).dy;
      final ctaTopStep3 = tester.getTopLeft(find.byType(ElevatedButton)).dy;

      // Step 4 Positions
      await tester.pumpWidget(
        MaterialApp(home: ClientNotificationsScreen(authService: fakeAuth)),
      );
      await tester.pumpAndSettle();

      final titleTopStep4 = tester.getTopLeft(find.byKey(const Key('onboarding_title'))).dy;
      final subtitleTopStep4 = tester.getTopLeft(find.byKey(const Key('onboarding_subtitle'))).dy;
      final ctaTopStep4 = tester.getTopLeft(find.byType(ElevatedButton)).dy;

      // Assert identical coordinates across all steps (zero visual jitter)
      expect(titleTopStep2, equals(titleTopStep1), reason: 'Title offset invariant S1 -> S2');
      expect(titleTopStep3, equals(titleTopStep1), reason: 'Title offset invariant S1 -> S3');
      expect(titleTopStep4, equals(titleTopStep1), reason: 'Title offset invariant S1 -> S4');

      expect(subtitleTopStep2, equals(subtitleTopStep1), reason: 'Subtitle offset invariant S1 -> S2');
      expect(subtitleTopStep3, equals(subtitleTopStep1), reason: 'Subtitle offset invariant S1 -> S3');
      expect(subtitleTopStep4, equals(subtitleTopStep1), reason: 'Subtitle offset invariant S1 -> S4');

      expect(ctaTopStep2, equals(ctaTopStep1), reason: 'CTA offset invariant S1 -> S2');
      expect(ctaTopStep3, equals(ctaTopStep1), reason: 'CTA offset invariant S1 -> S3');
      expect(ctaTopStep4, equals(ctaTopStep1), reason: 'CTA offset invariant S1 -> S4');
    });

    testWidgets('Tapping Skip on Client Onboarding steps advances forward seamlessly', (tester) async {
      final fakeAuth = FakeClientFlowAuthService();

      await tester.pumpWidget(
        MaterialApp(
          home: ClientStyleDiscoveryScreen(authService: fakeAuth),
        ),
      );
      await tester.pumpAndSettle();

      // Skip on Step 1 -> advances to Step 2
      final skipButton1 = find.byKey(const Key('onboarding_skip_button'));
      expect(skipButton1, findsOneWidget);
      await tester.tap(skipButton1);
      await tester.pumpAndSettle();

      expect(find.byType(ClientPlacementPreferencesScreen), findsOneWidget);

      // Skip on Step 2 -> advances to Step 3
      final skipButton2 = find.byKey(const Key('onboarding_skip_button'));
      await tester.tap(skipButton2);
      await tester.pumpAndSettle();

      expect(find.byType(ClientLocationScreen), findsOneWidget);

      // Skip on Step 3 -> advances to Step 4
      final skipButton3 = find.byKey(const Key('onboarding_skip_button'));
      await tester.tap(skipButton3);
      await tester.pumpAndSettle();

      expect(find.byType(ClientNotificationsScreen), findsOneWidget);

      // Skip on Step 4 -> completes to MainFeedScreen
      final skipButton4 = find.byKey(const Key('onboarding_skip_button'));
      await tester.tap(skipButton4);
      await tester.pumpAndSettle();

      expect(find.byType(MainFeedScreen), findsOneWidget);
    });
  });
}
