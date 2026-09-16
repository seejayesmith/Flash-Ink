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
import 'package:flash_ink/screens/splash_screen.dart';
import 'package:flash_ink/services/auth_service.dart';

/// Test double for Firebase User to record deletion
class MockAuthUser extends Fake implements User {
  @override
  final String uid;
  @override
  final String? email;
  @override
  final String? displayName;
  bool wasDeleted = false;

  MockAuthUser({
    this.uid = 'test_client_uid_101',
    this.email = 'client@flash.ink',
    this.displayName = 'Flash Client',
  });

  @override
  Future<void> delete() async {
    wasDeleted = true;
  }
}

/// Fake AuthService tracking account deletion and providing configurable responses
class FakeClientAuthService extends AuthService {
  final MockAuthUser mockUser = MockAuthUser();
  int deleteCallCount = 0;
  bool throwRequiresRecentLogin = false;
  bool throwGenericError = false;

  @override
  User? get currentUser => mockUser;

  @override
  Future<void> deleteAccount() async {
    deleteCallCount++;
    if (throwRequiresRecentLogin) {
      throw handleFirebaseAuthException(
        FirebaseAuthException(
          code: 'requires-recent-login',
          message: 'Requires recent login before account deletion.',
        ),
      );
    }
    if (throwGenericError) {
      throw Exception('Failed to delete account');
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

  group('Client Onboarding & Account Deletion Test Suite', () {
    // =========================================================================
    // Tier 1: Skip Photo Routing
    // =========================================================================
    testWidgets(
      'Tier 1: Tapping "SKIP" on ProfileSetupScreen bypasses photo and routes to AestheticsSelectionScreen, and FINISH routes to MainFeedScreen',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: ProfileSetupScreen(),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Verify username step
        expect(find.text('Add a username'), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);

        // 2. Enter valid username and tap CONTINUE
        await tester.enterText(find.byType(TextField), '@FlashClient');
        await tester.pump();
        await tester.tap(find.text('CONTINUE'));
        await tester.pumpAndSettle();

        // 3. Verify Photo Step is reached and "SKIP" button is visible
        expect(find.text('Upload a profile photo'), findsOneWidget);
        final skipButtonFinder = find.text('SKIP');
        expect(skipButtonFinder, findsOneWidget);

        // 4. Tap "SKIP" without picking an image
        await tester.tap(skipButtonFinder);
        await tester.pumpAndSettle();

        // 5. Verify navigation to AestheticsSelectionScreen
        expect(find.byType(ProfileSetupScreen), findsNothing);
        expect(find.byType(AestheticsSelectionScreen), findsOneWidget);
        expect(find.text('Choose your aesthetics'), findsOneWidget);

        // 6. Complete aesthetics by tapping FINISH
        final finishButtonFinder = find.text('FINISH');
        await tester.ensureVisible(finishButtonFinder);
        await tester.tap(finishButtonFinder);
        await tester.pumpAndSettle();

        // 7. Verify navigation to MainFeedScreen
        expect(find.byType(AestheticsSelectionScreen), findsNothing);
        expect(find.byType(MainFeedScreen), findsOneWidget);
        expect(find.text('Browse Artists'), findsOneWidget);
      },
    );

    // =========================================================================
    // Tier 1: Delete Account Button & Modal Cancellation
    // =========================================================================
    testWidgets(
      'Tier 1: Delete Account button is visible at bottom of feed, tapping opens centered confirmation modal, Cancel dismisses without deletion',
      (WidgetTester tester) async {
        final fakeAuth = FakeClientAuthService();
        await tester.pumpWidget(
          MaterialApp(
            home: MainFeedScreen(authService: fakeAuth),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Scroll until "Delete Account" button is visible
        final deleteButtonFinder = find.byKey(const Key('delete_account_button'));
        await tester.scrollUntilVisible(deleteButtonFinder, 500.0, scrollable: feedScrollable());
        expect(deleteButtonFinder, findsOneWidget);

        // 2. Tap "Delete Account" button
        await tester.tap(deleteButtonFinder);
        await tester.pumpAndSettle();

        // 3. Verify centered confirmation modal appears
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.byKey(const Key('delete_account_modal_title')), findsOneWidget);
        expect(find.text('Delete Account'), findsWidgets);
        expect(
          find.text('Are you sure you want to delete your account? This action cannot be undone.'),
          findsOneWidget,
        );
        expect(find.byKey(const Key('delete_account_cancel_button')), findsOneWidget);
        expect(find.byKey(const Key('delete_account_confirm_button')), findsOneWidget);

        // 4. Tap "Cancel" button
        await tester.tap(find.byKey(const Key('delete_account_cancel_button')));
        await tester.pumpAndSettle();

        // 5. Verify modal dismissed and user remains on MainFeedScreen with no deletion
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.byType(MainFeedScreen), findsOneWidget);
        expect(fakeAuth.deleteCallCount, 0);
        expect(fakeAuth.mockUser.wasDeleted, isFalse);
      },
    );

    // =========================================================================
    // Tier 1: Confirm Deletion & Root Navigation
    // =========================================================================
    testWidgets(
      'Tier 1: Confirming account deletion executes deleteAccount, displays simulated email confirmation SnackBar, and routes to SplashScreen',
      (WidgetTester tester) async {
        final fakeAuth = FakeClientAuthService();
        await tester.pumpWidget(
          MaterialApp(
            home: MainFeedScreen(authService: fakeAuth),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Scroll to "Delete Account" button and tap it
        final deleteButtonFinder = find.byKey(const Key('delete_account_button'));
        await tester.scrollUntilVisible(deleteButtonFinder, 500.0, scrollable: feedScrollable());
        await tester.tap(deleteButtonFinder);
        await tester.pumpAndSettle();

        // 2. Confirm deletion in modal
        final confirmButtonFinder = find.byKey(const Key('delete_account_confirm_button'));
        expect(confirmButtonFinder, findsOneWidget);
        await tester.tap(confirmButtonFinder);
        await tester.pump(); // Dismiss dialog
        await tester.pump(); // Complete async deletion and push SplashScreen

        // 3. Verify deletion invocation
        expect(fakeAuth.deleteCallCount, 1);
        expect(fakeAuth.mockUser.wasDeleted, isTrue);

        // 4. Verify simulated email confirmation SnackBar
        expect(
          find.text('Account deleted. A confirmation email has been sent.'),
          findsOneWidget,
        );

        // 5. Verify user is routed to SplashScreen and backstack is completely cleared
        expect(find.byType(SplashScreen), findsOneWidget);
        final navigator = tester.state<NavigatorState>(find.byType(Navigator));
        expect(navigator.canPop(), isFalse);
      },
    );

    // =========================================================================
    // Tier 2: Error Handling on Deletion (requires-recent-login)
    // =========================================================================
    testWidgets(
      'Tier 2: When deleteAccount fails with requires-recent-login, displays error SnackBar and stays on MainFeedScreen',
      (WidgetTester tester) async {
        final fakeAuth = FakeClientAuthService()..throwRequiresRecentLogin = true;
        await tester.pumpWidget(
          MaterialApp(
            home: MainFeedScreen(authService: fakeAuth),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Scroll to and tap "Delete Account"
        final deleteButtonFinder = find.byKey(const Key('delete_account_button'));
        await tester.scrollUntilVisible(deleteButtonFinder, 500.0, scrollable: feedScrollable());
        await tester.tap(deleteButtonFinder);
        await tester.pumpAndSettle();

        // 2. Confirm deletion
        await tester.tap(find.byKey(const Key('delete_account_confirm_button')));
        await tester.pumpAndSettle();

        // 3. Verify deletion attempt occurred but user was not deleted
        expect(fakeAuth.deleteCallCount, 1);
        expect(fakeAuth.mockUser.wasDeleted, isFalse);

        // 4. Verify error SnackBar is displayed with user-friendly message
        expect(find.byType(SnackBar), findsOneWidget);
        expect(
          find.text('This action requires recent authentication. Please log in again before deleting your account.'),
          findsOneWidget,
        );

        // 5. Verify user remains safely on MainFeedScreen
        expect(find.byType(MainFeedScreen), findsOneWidget);
      },
    );

    // =========================================================================
    // Tier 2: Generic Error Handling on Deletion
    // =========================================================================
    testWidgets(
      'Tier 2: When deleteAccount throws a generic error, displays error SnackBar and stays on MainFeedScreen',
      (WidgetTester tester) async {
        final fakeAuth = FakeClientAuthService()..throwGenericError = true;
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

        await tester.tap(find.byKey(const Key('delete_account_confirm_button')));
        await tester.pumpAndSettle();

        expect(fakeAuth.deleteCallCount, 1);
        expect(fakeAuth.mockUser.wasDeleted, isFalse);
        expect(find.byType(SnackBar), findsOneWidget);
        expect(find.text('Failed to delete account'), findsOneWidget);
        expect(find.byType(MainFeedScreen), findsOneWidget);
      },
    );
  });

  group('AuthService Unit Tests', () {
    test('deleteAccount returns safely without error if currentUser is null', () async {
      final authService = AuthService();
      await expectLater(authService.deleteAccount(), completes);
    });

    test('_handleFirebaseAuthException maps requires-recent-login to friendly message', () {
      final authService = AuthService();
      final exception = FirebaseAuthException(
        code: 'requires-recent-login',
        message: 'This operation requires recent authentication.',
      );
      final mapped = authService.handleFirebaseAuthException(exception);
      expect(
        mapped.toString(),
        contains('This action requires recent authentication. Please log in again before deleting your account.'),
      );
    });
  });
}
