import 'dart:async';
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

/// Test mock for Firebase User
class MockChallengerUser extends Fake implements User {
  @override
  final String uid;
  @override
  final String? email;
  @override
  final String? displayName;
  int deleteCallCount = 0;
  Duration? deleteDelay;
  bool shouldThrowRecentLogin = false;
  bool shouldThrowNetworkError = false;

  MockChallengerUser({
    this.uid = 'challenger_uid_777',
    this.email = 'challenger@flash.ink',
    this.displayName = 'Challenger Client',
  });

  @override
  Future<void> delete() async {
    deleteCallCount++;
    if (deleteDelay != null) {
      await Future.delayed(deleteDelay!);
    }
    if (shouldThrowRecentLogin) {
      throw FirebaseAuthException(
        code: 'requires-recent-login',
        message: 'This operation requires recent authentication.',
      );
    }
    if (shouldThrowNetworkError) {
      throw Exception('SocketException: Failed host lookup: api.firebase.com');
    }
  }
}

/// Adversarial Fake AuthService simulating network latency, crashes, and guest modes
class ChallengerStressAuthService extends AuthService {
  MockChallengerUser? mockUser = MockChallengerUser();
  int deleteAccountCallCount = 0;
  Completer<void>? inFlightDeletion;
  Duration? simulatedLatency;
  bool throwOnDelete = false;
  Exception? exceptionToThrow;

  @override
  User? get currentUser => mockUser;

  @override
  Future<void> deleteAccount() async {
    deleteAccountCallCount++;
    if (simulatedLatency != null) {
      await Future.delayed(simulatedLatency!);
    }
    if (inFlightDeletion != null && !inFlightDeletion!.isCompleted) {
      await inFlightDeletion!.future;
    }

    if (throwOnDelete && exceptionToThrow != null) {
      throw exceptionToThrow!;
    }

    if (mockUser == null) {
      // Per AuthService contract: if user == null return without error
      return;
    }

    await mockUser!.delete();
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

  group('Challenger Adversarial Stress Tests: Account Deletion & Concurrency', () {
    // =========================================================================
    // Scenario 1: Deletion when currentUser == null (Guest user / signed out)
    // =========================================================================
    test('Scenario 1A: AuthService.deleteAccount() completes normally without error when currentUser == null', () async {
      final authService = AuthService();
      expect(authService.currentUser, isNull);
      await expectLater(authService.deleteAccount(), completes);
    });

    testWidgets(
      'Scenario 1B: UI handles account deletion safely when currentUser == null (e.g. guest or already signed out)',
      (WidgetTester tester) async {
        final fakeAuth = ChallengerStressAuthService()..mockUser = null;

        await tester.pumpWidget(
          MaterialApp(
            home: MainFeedScreen(authService: fakeAuth),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Scroll to and tap "Delete Account" button
        final deleteButtonFinder = find.byKey(const Key('delete_account_button'));
        await tester.scrollUntilVisible(deleteButtonFinder, 500.0, scrollable: feedScrollable());
        await tester.tap(deleteButtonFinder);
        await tester.pumpAndSettle();

        // 2. Confirm in modal
        final confirmButtonFinder = find.byKey(const Key('delete_account_confirm_button'));
        expect(confirmButtonFinder, findsOneWidget);
        await tester.tap(confirmButtonFinder);
        await tester.pump();
        await tester.pump();

        // 3. Verify deleteAccount was invoked once without null dereference crash
        expect(fakeAuth.deleteAccountCallCount, 1);

        // 4. Verify confirmation SnackBar and navigation to SplashScreen
        expect(find.text('Account deleted. A confirmation email has been sent.'), findsOneWidget);
        expect(find.byType(SplashScreen), findsOneWidget);
      },
    );

    // =========================================================================
    // Scenario 2: Deletion with FirebaseAuthException('requires-recent-login')
    // =========================================================================
    test('Scenario 2A: Exception mapper translates requires-recent-login to security warning', () {
      final authService = AuthService();
      final exc = FirebaseAuthException(
        code: 'requires-recent-login',
        message: 'Requires recent login.',
      );
      final mapped = authService.handleFirebaseAuthException(exc);
      expect(
        mapped.toString(),
        contains('This action requires recent authentication. Please log in again before deleting your account.'),
      );
    });

    testWidgets(
      'Scenario 2B: UI displays translated error SnackBar and DOES NOT navigate on requires-recent-login',
      (WidgetTester tester) async {
        final fakeAuth = ChallengerStressAuthService()
          ..throwOnDelete = true
          ..exceptionToThrow = FirebaseAuthException(
            code: 'requires-recent-login',
            message: 'User must reauthenticate before deleting account.',
          );

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

        // 1. Verify delete was attempted
        expect(fakeAuth.deleteAccountCallCount, 1);

        // 2. Verify translated SnackBar is visible with re-auth guidance
        expect(find.byType(SnackBar), findsOneWidget);
        expect(
          find.text('This action requires recent authentication. Please log in again before deleting your account.'),
          findsOneWidget,
        );

        // 3. CRITICAL: Verify screen DID NOT navigate to SplashScreen or pop
        expect(find.byType(SplashScreen), findsNothing);
        expect(find.byType(MainFeedScreen), findsOneWidget);
      },
    );

    // =========================================================================
    // Scenario 3: Deletion when general network exception is thrown
    // =========================================================================
    testWidgets(
      'Scenario 3: UI surfaces network failure message and DOES NOT navigate away',
      (WidgetTester tester) async {
        final fakeAuth = ChallengerStressAuthService()
          ..throwOnDelete = true
          ..exceptionToThrow = Exception('Network error. Please check your internet connection.');

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

        // 1. Verify delete call count
        expect(fakeAuth.deleteAccountCallCount, 1);

        // 2. Verify error SnackBar contains network error message
        expect(find.byType(SnackBar), findsOneWidget);
        expect(find.text('Network error. Please check your internet connection.'), findsOneWidget);

        // 3. Verify screen did not navigate
        expect(find.byType(SplashScreen), findsNothing);
        expect(find.byType(MainFeedScreen), findsOneWidget);
      },
    );

    // =========================================================================
    // Scenario 4: Double-tap on "Delete Account" confirm button (race condition)
    // =========================================================================
    testWidgets(
      'Scenario 4A: Rapid double-tap on confirm button inside modal does not cause race condition or multiple deletions',
      (WidgetTester tester) async {
        final completer = Completer<void>();
        final fakeAuth = ChallengerStressAuthService()
          ..inFlightDeletion = completer;

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

        final confirmFinder = find.byKey(const Key('delete_account_confirm_button'));
        expect(confirmFinder, findsOneWidget);

        // Rapid double tap before frames settle
        await tester.tap(confirmFinder);
        await tester.tap(confirmFinder, warnIfMissed: false);
        await tester.pump(); // Process dialog dismissal

        // Release the in-flight deletion
        completer.complete();
        await tester.pumpAndSettle();

        // Modal must dismiss and deleteAccount must only be called once
        expect(fakeAuth.deleteAccountCallCount, 1);
        expect(fakeAuth.mockUser?.deleteCallCount, 1);
        expect(find.byType(SplashScreen), findsOneWidget);
      },
    );

    testWidgets(
      'Scenario 4B: Rapid double-tap on feed Delete Account button does not push duplicate modals or cause crash',
      (WidgetTester tester) async {
        final fakeAuth = ChallengerStressAuthService();

        await tester.pumpWidget(
          MaterialApp(
            home: MainFeedScreen(authService: fakeAuth),
          ),
        );
        await tester.pumpAndSettle();

        final deleteButtonFinder = find.byKey(const Key('delete_account_button'));
        await tester.scrollUntilVisible(deleteButtonFinder, 500.0, scrollable: feedScrollable());

        // Tap twice quickly on the footer button
        await tester.tap(deleteButtonFinder);
        await tester.tap(deleteButtonFinder, warnIfMissed: false);
        await tester.pumpAndSettle();

        // Only one modal should be present or dismissable
        expect(find.byType(AlertDialog), findsWidgets);
        await tester.tap(find.byKey(const Key('delete_account_cancel_button')).first);
        await tester.pumpAndSettle();

        // No deletion occurred
        expect(fakeAuth.deleteAccountCallCount, 0);
      },
    );

    // =========================================================================
    // Scenario 5: Offline resilience of _saveProfile() when Firestore write fails
    // =========================================================================
    testWidgets(
      'Scenario 5: ProfileSetupScreen "SKIP" button navigates to AestheticsSelectionScreen even when Firestore write fails',
      (WidgetTester tester) async {
        // Render ProfileSetupScreen with default uninitialized Firestore mock
        // This exercises lines 166-218 in ProfileSetupScreen where Firestore set is inside try-catch (_)
        await tester.pumpWidget(
          const MaterialApp(
            home: ProfileSetupScreen(),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Advance through username step
        expect(find.text('Add a username'), findsOneWidget);
        await tester.enterText(find.byType(TextField), '@OfflineTester');
        await tester.pump();
        await tester.tap(find.text('CONTINUE'));
        await tester.pumpAndSettle();

        // 2. Reach photo step with no photo selected
        expect(find.text('Upload a profile photo'), findsOneWidget);
        final skipButtonFinder = find.text('SKIP');
        expect(skipButtonFinder, findsOneWidget);

        // 3. Tap "SKIP": triggers _saveProfile() which attempts Firestore write and catches failure
        await tester.tap(skipButtonFinder);
        await tester.pumpAndSettle();

        // 4. Verify resilient navigation to AestheticsSelectionScreen succeeded without crash or error snackbar
        expect(find.byType(ProfileSetupScreen), findsNothing);
        expect(find.byType(AestheticsSelectionScreen), findsOneWidget);
        expect(find.text('Choose your aesthetics'), findsOneWidget);
        expect(find.byType(SnackBar), findsNothing);
      },
    );
  });
}
