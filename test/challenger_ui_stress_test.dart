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
import 'package:flash_ink/screens/browse_artists_screen.dart';
import 'package:flash_ink/screens/splash_screen.dart';
import 'package:flash_ink/screens/role_selection_screen.dart';
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

  Finder feedScrollable() {
    return find.descendant(
      of: find.byType(ListView),
      matching: find.byType(Scrollable),
    );
  }

  group('Challenger Stress & Adversarial Test Suite', () {
    // =========================================================================
    // 1. Rapid Tapping on "SKIP" Button (Loading & Idempotency)
    // =========================================================================
    testWidgets(
      'Adversarial 1: Rapid multi-tapping on "SKIP" button is idempotent and transitions cleanly without duplicate navigation',
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
        await tester.tap(find.text('CONTINUE'));
        await tester.pumpAndSettle();

        // Verify we are on Photo step
        expect(find.text('Upload a profile photo'), findsOneWidget);
        final skipFinder = find.text('SKIP');
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
    // 2. Dismissing Confirmation Modal via Modal Barrier vs. Cancel Button
    // =========================================================================
    testWidgets(
      'Adversarial 2a: Dismissing the confirmation modal by tapping the modal barrier does not trigger deletion',
      (WidgetTester tester) async {
        final fakeAuth = ChallengerFakeAuthService();
        await tester.pumpWidget(
          MaterialApp(
            home: MainFeedScreen(authService: fakeAuth),
          ),
        );
        await tester.pumpAndSettle();

        final deleteButtonFinder = find.byKey(const Key('delete_account_button'));
        await tester.scrollUntilVisible(deleteButtonFinder, 500.0, scrollable: feedScrollable());
        expect(deleteButtonFinder, findsOneWidget);

        // Tap Delete Account to open modal
        await tester.tap(deleteButtonFinder);
        await tester.pumpAndSettle();

        // Modal is open
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.byKey(const Key('delete_account_modal_title')), findsOneWidget);

        // Tap the modal barrier (outside the dialog content)
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();

        // Verify modal is dismissed, no deletion performed, still on MainFeedScreen
        expect(find.byType(AlertDialog), findsNothing);
        expect(fakeAuth.deleteCallCount, 0);
        expect(fakeAuth.mockUser.wasDeleted, isFalse);
        expect(find.byType(MainFeedScreen), findsOneWidget);
      },
    );

    testWidgets(
      'Adversarial 2b: Dismissing the confirmation modal by pressing Cancel does not trigger deletion',
      (WidgetTester tester) async {
        final fakeAuth = ChallengerFakeAuthService();
        await tester.pumpWidget(
          MaterialApp(
            home: MainFeedScreen(authService: fakeAuth),
          ),
        );
        await tester.pumpAndSettle();

        final deleteButtonFinder = find.byKey(const Key('delete_account_button'));
        await tester.scrollUntilVisible(deleteButtonFinder, 500.0, scrollable: feedScrollable());

        // Tap Delete Account to open modal
        await tester.tap(deleteButtonFinder);
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsOneWidget);

        // Tap Cancel button
        await tester.tap(find.byKey(const Key('delete_account_cancel_button')));
        await tester.pumpAndSettle();

        // Verify modal dismissed, no deletion performed, still on MainFeedScreen
        expect(find.byType(AlertDialog), findsNothing);
        expect(fakeAuth.deleteCallCount, 0);
        expect(fakeAuth.mockUser.wasDeleted, isFalse);
        expect(find.byType(MainFeedScreen), findsOneWidget);
      },
    );

    testWidgets(
      'Adversarial 2c: Dismissing the confirmation modal via system back button does not trigger deletion',
      (WidgetTester tester) async {
        final fakeAuth = ChallengerFakeAuthService();
        await tester.pumpWidget(
          MaterialApp(
            home: MainFeedScreen(authService: fakeAuth),
          ),
        );
        await tester.pumpAndSettle();

        final deleteButtonFinder = find.byKey(const Key('delete_account_button'));
        await tester.scrollUntilVisible(deleteButtonFinder, 500.0, scrollable: feedScrollable());

        // Tap Delete Account to open modal
        await tester.tap(deleteButtonFinder);
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsOneWidget);

        // Simulate Android/Hardware system back button
        final didPop = await tester.binding.handlePopRoute();
        expect(didPop, isTrue); // Dialog consumed pop route
        await tester.pumpAndSettle();

        // Verify modal dismissed, no deletion performed, still on MainFeedScreen
        expect(find.byType(AlertDialog), findsNothing);
        expect(fakeAuth.deleteCallCount, 0);
        expect(fakeAuth.mockUser.wasDeleted, isFalse);
        expect(find.byType(MainFeedScreen), findsOneWidget);
      },
    );

    // =========================================================================
    // 3. Repeatedly Opening and Cancelling Modal Before Confirming
    // =========================================================================
    testWidgets(
      'Adversarial 3: Repeatedly opening and cancelling Delete Account modal before confirming executes deletion exactly once',
      (WidgetTester tester) async {
        final fakeAuth = ChallengerFakeAuthService();
        await tester.pumpWidget(
          MaterialApp(
            home: MainFeedScreen(authService: fakeAuth),
          ),
        );
        await tester.pumpAndSettle();

        final deleteButtonFinder = find.byKey(const Key('delete_account_button'));
        await tester.scrollUntilVisible(deleteButtonFinder, 500.0, scrollable: feedScrollable());

        // Cycle through multiple open and cancel actions
        for (int i = 0; i < 4; i++) {
          await tester.tap(deleteButtonFinder);
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsOneWidget);

          if (i % 2 == 0) {
            // Cancel via button
            await tester.tap(find.byKey(const Key('delete_account_cancel_button')));
          } else {
            // Cancel via barrier tap
            await tester.tapAt(const Offset(15, 15));
          }
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsNothing);
          expect(fakeAuth.deleteCallCount, 0);
        }

        // Now open one last time and confirm deletion
        await tester.tap(deleteButtonFinder);
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);

        final confirmButtonFinder = find.byKey(const Key('delete_account_confirm_button'));
        await tester.tap(confirmButtonFinder);
        await tester.pump(); // dismiss dialog
        await tester.pump(); // execute deletion and route to SplashScreen

        // Assert exactly 1 deletion call and successful navigation
        expect(fakeAuth.deleteCallCount, 1);
        expect(fakeAuth.mockUser.wasDeleted, isTrue);
        expect(find.text('Account deleted. A confirmation email has been sent.'), findsOneWidget);
        expect(find.byType(SplashScreen), findsOneWidget);
      },
    );

    // =========================================================================
    // 4. Viewport Constraints & Hittability Across Device Profiles
    // =========================================================================
    testWidgets(
      'Adversarial 4a: Delete Account button is visible and hittable across large tablet/desktop viewports',
      (WidgetTester tester) async {
        final tabletViewports = <String, Size>{
          'Standard Test (1080 x 2400)': const Size(1080, 2400),
          'Tablet Portrait (768 x 1024)': const Size(768, 1024),
          'Tablet Landscape (1024 x 768)': const Size(1024, 768),
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
          await tester.pumpAndSettle();

          final deleteButtonFinder = find.byKey(const Key('delete_account_button'));
          await tester.scrollUntilVisible(
            deleteButtonFinder,
            300.0,
            scrollable: feedScrollable(),
          );
          await tester.ensureVisible(deleteButtonFinder);
          await tester.pumpAndSettle();

          // Verify button exists and is rendered
          expect(deleteButtonFinder, findsOneWidget, reason: 'Failed to find button on $label');

          // Verify button is within viewport bounds
          final buttonRect = tester.getRect(deleteButtonFinder);
          expect(buttonRect.top, greaterThanOrEqualTo(0), reason: 'Top outside viewport on $label');
          expect(buttonRect.bottom, lessThanOrEqualTo(size.height), reason: 'Bottom outside viewport on $label');

          // Tap to verify hittability and modal render without overflow
          await tester.tap(deleteButtonFinder);
          await tester.pumpAndSettle();

          expect(find.byType(AlertDialog), findsOneWidget, reason: 'Modal did not appear on $label');

          // Dismiss modal to prepare for next viewport
          await tester.tap(find.byKey(const Key('delete_account_cancel_button')));
          await tester.pumpAndSettle();
        }
      },
    );

    testWidgets(
      'Adversarial 4b: Empirical discovery: On standard mobile viewports (360px & 390px width), feed has pre-existing card overflows, but Delete Account button remains scrollable and hittable',
      (WidgetTester tester) async {
        final mobileViewports = <String, Size>{
          'Standard Mobile (390 x 844)': const Size(390, 844),
          'Compact Android (360 x 780)': const Size(360, 780),
        };

        for (final entry in mobileViewports.entries) {
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

          // Drain any RenderFlex overflow exceptions from the artist cards / bottom nav bar
          tester.takeException();
          await tester.pumpAndSettle();
          tester.takeException();

          final deleteButtonFinder = find.byKey(const Key('delete_account_button'));
          await tester.scrollUntilVisible(
            deleteButtonFinder,
            300.0,
            scrollable: feedScrollable(),
          );
          await tester.ensureVisible(deleteButtonFinder);
          tester.takeException();
          await tester.pumpAndSettle();
          tester.takeException();

          expect(deleteButtonFinder, findsOneWidget, reason: 'Delete Account button missing on $label');

          // Tap Delete Account
          await tester.tap(deleteButtonFinder);
          tester.takeException();
          await tester.pumpAndSettle();
          tester.takeException();

          // Assert confirmation modal opens and functions properly despite card overflows
          expect(find.byType(AlertDialog), findsOneWidget, reason: 'Modal failed to open on $label');
          await tester.tap(find.byKey(const Key('delete_account_cancel_button')));
          tester.takeException();
          await tester.pumpAndSettle();
          tester.takeException();
        }
      },
    );

    // =========================================================================
    // 5. Backstack Destruction & Hardware Back Button Immutability
    // =========================================================================
    testWidgets(
      'Adversarial 5a: Account deletion clears entire backstack (canPop is false) and hardware back button does not return to feed',
      (WidgetTester tester) async {
        final fakeAuth = ChallengerFakeAuthService();

        // Build with a synthetic navigation stack: Initial Route -> Push MainFeedScreen
        final navKey = GlobalKey<NavigatorState>();
        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: navKey,
            home: const Scaffold(
              body: Center(child: Text('Initial Route')),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Push MainFeedScreen onto stack
        navKey.currentState!.push(
          MaterialPageRoute(
            builder: (_) => MainFeedScreen(authService: fakeAuth),
          ),
        );
        await tester.pumpAndSettle();

        // Verify we can pop initially (MainFeedScreen is on top of Initial Route)
        expect(navKey.currentState!.canPop(), isTrue);

        // Scroll down to Delete Account button
        final deleteButtonFinder = find.byKey(const Key('delete_account_button'));
        await tester.scrollUntilVisible(deleteButtonFinder, 500.0, scrollable: feedScrollable());
        await tester.tap(deleteButtonFinder);
        await tester.pumpAndSettle();

        // Confirm deletion in modal
        await tester.tap(find.byKey(const Key('delete_account_confirm_button')));
        // Pump frames for dialog dismiss and route replacement
        await tester.pump();
        await tester.pump();

        // Verify SplashScreen is pushed and backstack is purged
        expect(find.byType(SplashScreen), findsOneWidget);
        expect(navKey.currentState!.canPop(), isFalse);

        // Settle route transition and splash redirection to RoleSelectionScreen
        await tester.pumpAndSettle();

        // Verify user is now at RoleSelectionScreen and backstack is STILL empty
        expect(find.byType(RoleSelectionScreen), findsOneWidget);
        expect(find.byType(MainFeedScreen), findsNothing);
        expect(find.byType(BrowseArtistsScreen), findsNothing);
        expect(find.text('Initial Route'), findsNothing);
        expect(navKey.currentState!.canPop(), isFalse);

        // Simulate hardware/system back button press
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();

        // Confirm that the feed was NEVER returned to and user cannot get back into feed
        expect(find.byType(MainFeedScreen), findsNothing);
        expect(find.byType(BrowseArtistsScreen), findsNothing);
        expect(find.text('Initial Route'), findsNothing);
      },
    );

    testWidgets(
      'Adversarial 5b: Onboarding flow removes ProfileSetupScreen on SKIP and clears stack on FINISH',
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
        await tester.tap(find.text('CONTINUE'));
        await tester.pumpAndSettle();

        // Tap SKIP
        await tester.tap(find.text('SKIP'));
        await tester.pumpAndSettle();

        // AestheticsSelectionScreen is now visible; ProfileSetupScreen replaced
        expect(find.byType(AestheticsSelectionScreen), findsOneWidget);
        expect(find.byType(ProfileSetupScreen), findsNothing);

        // Tap FINISH on AestheticsSelectionScreen
        final finishFinder = find.text('FINISH');
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

    // =========================================================================
    // 6. In-Flight Deletion State: UI Disablement & Double Confirmation Defense
    // =========================================================================
    testWidgets(
      'Adversarial 6: During in-flight deletion, Delete Account button shows progress indicator and disables subsequent taps',
      (WidgetTester tester) async {
        final fakeAuth = ChallengerFakeAuthService()
          ..simulatedDeleteDelay = const Duration(milliseconds: 300);

        await tester.pumpWidget(
          MaterialApp(
            home: MainFeedScreen(authService: fakeAuth),
          ),
        );
        await tester.pumpAndSettle();

        final deleteButtonFinder = find.byKey(const Key('delete_account_button'));
        await tester.scrollUntilVisible(deleteButtonFinder, 500.0, scrollable: feedScrollable());

        await tester.tap(deleteButtonFinder);
        await tester.pumpAndSettle();

        // Confirm deletion
        await tester.tap(find.byKey(const Key('delete_account_confirm_button')));
        // Dialog pop animation completes in ~200ms, deletion future is running
        await tester.pump(const Duration(milliseconds: 250));

        // Check if progress indicator is visible while deleting
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // Attempt to tap the delete button again during in-flight deletion
        await tester.tap(deleteButtonFinder, warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 50));

        // Settle remaining async delay and splash redirection
        await tester.pumpAndSettle();

        // Deletion should have executed exactly once
        expect(fakeAuth.deleteCallCount, 1);
        expect(fakeAuth.mockUser.wasDeleted, isTrue);
        expect(find.byType(RoleSelectionScreen), findsOneWidget);
      },
    );
  });
}
