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
      'Scenario 1B: Delete Account button is NOT present on the feed (deletion relocated to ClientAccountScreen)',
      (WidgetTester tester) async {
        final fakeAuth = ChallengerStressAuthService()..mockUser = null;

        await tester.pumpWidget(
          MaterialApp(
            home: MainFeedScreen(authService: fakeAuth),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('delete_account_button')), findsNothing);
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

    // =========================================================================
    // Scenario 5: Offline resilience of _saveProfile() when Firestore write fails
    // =========================================================================
    testWidgets(
      'Scenario 5: ProfileSetupScreen "Skip" button navigates to AestheticsSelectionScreen even when Firestore write fails',
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
        final skipButtonFinder = find.text('Skip');
        expect(skipButtonFinder, findsOneWidget);

        // 3. Tap "Skip": triggers _saveProfile() which attempts Firestore write and catches failure
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
