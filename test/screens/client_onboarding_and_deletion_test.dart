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

  group('Client Onboarding & Account Deletion Test Suite', () {
    // =========================================================================
    // Tier 1: Skip Photo Routing
    // =========================================================================
    testWidgets(
      'Tier 1: Tapping "Skip" on ProfileSetupScreen bypasses photo and routes to AestheticsSelectionScreen, and FINISH routes to MainFeedScreen',
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
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        // 3. Verify Photo Step is reached and "Skip" button is visible
        expect(find.text('Upload a profile photo'), findsOneWidget);
        final skipButtonFinder = find.text('Skip');
        expect(skipButtonFinder, findsOneWidget);

        // 4. Tap "Skip" without picking an image
        await tester.tap(skipButtonFinder);
        await tester.pumpAndSettle();

        // 5. Verify navigation to AestheticsSelectionScreen
        expect(find.byType(ProfileSetupScreen), findsNothing);
        expect(find.byType(AestheticsSelectionScreen), findsOneWidget);
        expect(find.text('Choose your aesthetics'), findsOneWidget);

        // 6. Select at least one aesthetic (required to proceed) and complete by tapping FINISH
        final traditionalCardFinder = find.text('TRADITIONAL');
        expect(traditionalCardFinder, findsOneWidget);
        await tester.tap(traditionalCardFinder);
        await tester.pumpAndSettle();

        final finishButtonFinder = find.text('Finish');
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
    // Feed Verification: Delete Account Button Removed from Feed
    // =========================================================================
    testWidgets(
      'Delete Account button is not present on the feed (deletion resides in ClientAccountScreen)',
      (WidgetTester tester) async {
        final fakeAuth = FakeClientAuthService();
        await tester.pumpWidget(
          MaterialApp(
            home: MainFeedScreen(authService: fakeAuth),
          ),
        );
        await tester.pumpAndSettle();

        // Verify Delete Account button is not on the feed
        expect(find.byKey(const Key('delete_account_button')), findsNothing);
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
