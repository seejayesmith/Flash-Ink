import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:flash_ink/screens/profile_setup_screen.dart';
import 'package:flash_ink/screens/aesthetics_selection_screen.dart';
import 'package:flash_ink/screens/main_feed_screen.dart';
import 'package:flash_ink/services/auth_service.dart';

/// Test double for Firebase User to record deletion
class ChallengerMockAuthUser extends Fake implements User {
  @override
  final String uid;
  @override
  final String? email;
  @override
  final String? displayName;
  bool wasDeleted = false;

  ChallengerMockAuthUser({
    this.uid = 'challenger_uid_777',
    this.email = 'challenger@flash.ink',
    this.displayName = 'Challenger Verifier',
  });

  @override
  Future<void> delete() async {
    wasDeleted = true;
  }
}

/// Fake AuthService tracking deletion invocations, supporting delays and exceptions
class ChallengerFakeAuthService extends AuthService {
  final ChallengerMockAuthUser mockUser = ChallengerMockAuthUser();
  int deleteCallCount = 0;
  Duration? simulatedDeleteDelay;
  bool throwRequiresRecentLogin = false;
  bool throwGenericError = false;

  @override
  User? get currentUser => mockUser;

  @override
  Future<void> deleteAccount() async {
    deleteCallCount++;
    if (simulatedDeleteDelay != null) {
      await Future.delayed(simulatedDeleteDelay!);
    }
    if (throwRequiresRecentLogin) {
      throw handleFirebaseAuthException(
        FirebaseAuthException(
          code: 'requires-recent-login',
          message: 'Requires recent login before account deletion.',
        ),
      );
    }
    if (throwGenericError) {
      throw Exception('Server error: failed to delete account.');
    }
    await mockUser.delete();
  }
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

  group('Challenger Stress & Adversarial Test Suite', () {
    // =========================================================================
    // 1. Rapid Tapping on "Skip" Button (Loading & Idempotency)
    // =========================================================================
    testWidgets(
      'Adversarial 1: Rapid multi-tapping on "Skip" button is idempotent and transitions cleanly without duplicate navigation',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: ProfileSetupScreen(),
          ),
        );
        await tester.pumpAndSettle();

        // Fill username to reach photo step
        await tester.enterText(find.byType(TextField), '@rapid_skipper');
        await tester.pump();
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        // Verify we are on Photo step
        expect(find.text('Upload a profile photo'), findsOneWidget);
        final skipFinder = find.text('Skip');
        expect(skipFinder, findsOneWidget);

        // Rapid tapping: simulate 5 rapid tap events in quick succession
        await tester.tap(skipFinder);
        // Dispatch additional taps immediately
        await tester.tap(skipFinder, warnIfMissed: false);
        await tester.tap(skipFinder, warnIfMissed: false);
        await tester.tap(skipFinder, warnIfMissed: false);
        await tester.tap(skipFinder, warnIfMissed: false);

        // Settle all asynchronous and routing frames
        await tester.pumpAndSettle();

        // Assert that exactly one AestheticsSelectionScreen is present and ProfileSetupScreen is replaced
        expect(find.byType(ProfileSetupScreen), findsNothing);
        expect(find.byType(AestheticsSelectionScreen), findsOneWidget);
        expect(find.text('Choose your aesthetics'), findsOneWidget);
      },
    );

    // =========================================================================
    // 2. Feed Verification: Delete Account button is NOT present on the feed
    // =========================================================================
    testWidgets(
      'Adversarial 2: Delete Account button is absent from MainFeedScreen across viewports',
      (WidgetTester tester) async {
        final tabletViewports = <String, Size>{
          'Standard Test (1080 x 2400)': const Size(1080, 2400),
          'Tablet Portrait (768 x 1024)': const Size(768, 1024),
          'Tablet Landscape (1024 x 768)': const Size(1024, 768),
          'Standard Mobile (390 x 844)': const Size(390, 844),
        };

        for (final entry in tabletViewports.entries) {
          final label = entry.key;
          final size = entry.value;

          final binding = TestWidgetsFlutterBinding.ensureInitialized();
          binding.platformDispatcher.views.first.physicalSize = size;
          binding.platformDispatcher.views.first.devicePixelRatio = 1.0;

          final fakeAuth = ChallengerFakeAuthService();
          await tester.pumpWidget(
            MaterialApp(
              home: MainFeedScreen(authService: fakeAuth),
            ),
          );
          tester.takeException();
          await tester.pumpAndSettle();
          tester.takeException();

          // Verify Delete Account button is NOT found on feed
          expect(
            find.byKey(const Key('delete_account_button')),
            findsNothing,
            reason: 'Delete account button should not exist on feed on $label',
          );
        }
      },
    );

    // =========================================================================
    // 3. Onboarding Flow Stack Management
    // =========================================================================
    testWidgets(
      'Adversarial 3: Onboarding flow removes ProfileSetupScreen on Skip and clears stack on FINISH',
      (WidgetTester tester) async {
        final navKey = GlobalKey<NavigatorState>();
        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: navKey,
            home: const ProfileSetupScreen(),
          ),
        );
        await tester.pumpAndSettle();

        // Fill username
        await tester.enterText(find.byType(TextField), '@onboarding_skipper');
        await tester.pump();
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        // Tap Skip
        await tester.tap(find.text('Skip'));
        await tester.pumpAndSettle();

        // AestheticsSelectionScreen is now visible; ProfileSetupScreen replaced
        expect(find.byType(AestheticsSelectionScreen), findsOneWidget);
        expect(find.byType(ProfileSetupScreen), findsNothing);

        // Select at least one aesthetic (required to enable FINISH)
        final traditionalCardFinder = find.text('TRADITIONAL');
        expect(traditionalCardFinder, findsOneWidget);
        await tester.tap(traditionalCardFinder);
        await tester.pumpAndSettle();

        // Tap FINISH on AestheticsSelectionScreen
        final finishFinder = find.text('Finish');
        await tester.ensureVisible(finishFinder);
        await tester.tap(finishFinder);
        await tester.pumpAndSettle();

        // MainFeedScreen is visible; AestheticsSelectionScreen is purged from backstack
        expect(find.byType(MainFeedScreen), findsOneWidget);
        expect(find.byType(AestheticsSelectionScreen), findsNothing);
        expect(navKey.currentState!.canPop(), isFalse);

        // Hardware back button cannot pop to onboarding
        final didPop = await tester.binding.handlePopRoute();
        expect(didPop, isFalse);
        expect(find.byType(MainFeedScreen), findsOneWidget);
      },
    );
  });
}
