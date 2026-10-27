import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:flash_ink/screens/client_account_screen.dart';
import 'package:flash_ink/screens/splash_screen.dart';
import 'package:flash_ink/services/auth_service.dart';
import 'package:flash_ink/widgets/reauthentication_bottom_sheet.dart';

class ReauthTestUser extends Fake implements User {
  @override
  final String uid;
  @override
  final String? email;
  @override
  final String? displayName;
  @override
  final String? phoneNumber;
  @override
  final String? photoURL;
  final List<String> providers;
  bool wasDeleted = false;

  ReauthTestUser({
    this.uid = 'reauth_user_123',
    this.email = 'tester@flash.ink',
    this.displayName = 'Test User',
    this.phoneNumber,
    this.photoURL = 'https://example.com/avatar.jpg',
    this.providers = const ['password'],
  });

  @override
  List<UserInfo> get providerData => providers.map((p) => FakeUserInfo(p)).toList();

  @override
  Future<void> delete() async {
    wasDeleted = true;
  }
}

class FakeUserInfo extends Fake implements UserInfo {
  @override
  final String providerId;
  FakeUserInfo(this.providerId);
}

class FakeReauthAuthService extends AuthService {
  final ReauthTestUser testUser;
  bool throwRequiresRecentLoginOnDelete = false;
  bool throwPasswordError = false;
  int deleteCallCount = 0;
  int reauthPasswordCallCount = 0;
  int reauthPhoneCallCount = 0;
  int reauthGoogleCallCount = 0;
  int sendPhoneCodeCallCount = 0;

  FakeReauthAuthService({ReauthTestUser? user})
      : testUser = user ?? ReauthTestUser();

  @override
  User? get currentUser => testUser;

  @override
  List<String> get currentUserProviders => testUser.providers;

  @override
  Future<void> deleteAccount() async {
    deleteCallCount++;
    if (throwRequiresRecentLoginOnDelete) {
      throw const RequiresRecentLoginException();
    }
    await testUser.delete();
  }

  @override
  Future<UserCredential?> reauthenticateWithPassword(String password) async {
    reauthPasswordCallCount++;
    if (throwPasswordError) {
      throw Exception('Incorrect password. Please try again.');
    }
    // After reauthentication, subsequent deletion should succeed
    throwRequiresRecentLoginOnDelete = false;
    return null;
  }

  @override
  Future<void> sendPhoneReauthCode({
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(Exception error) onVerificationFailed,
    void Function(PhoneAuthCredential credential)? onVerificationCompleted,
  }) async {
    sendPhoneCodeCallCount++;
    onCodeSent('test_sms_verification_id', null);
  }

  @override
  Future<UserCredential?> reauthenticateWithPhoneCredential({
    required String verificationId,
    required String smsCode,
  }) async {
    reauthPhoneCallCount++;
    throwRequiresRecentLoginOnDelete = false;
    return null;
  }

  @override
  Future<UserCredential?> reauthenticateWithGoogle() async {
    reauthGoogleCallCount++;
    throwRequiresRecentLoginOnDelete = false;
    return null;
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

  group('Reauthentication & Deletion Flow Tests', () {
    test('RequiresRecentLoginException mapping and type check', () {
      final authService = AuthService();
      final exc = FirebaseAuthException(
        code: 'requires-recent-login',
        message: 'This operation requires recent authentication.',
      );
      final mapped = authService.handleFirebaseAuthException(exc);

      expect(mapped, isA<RequiresRecentLoginException>());
      expect(
        mapped.toString(),
        contains('This action requires recent authentication. Please log in again before deleting your account.'),
      );
    });

    testWidgets(
      'ReauthenticationBottomSheet: Password flow reauthenticates and executes deletion',
      (WidgetTester tester) async {
        final fakeAuth = FakeReauthAuthService();
        bool successCalled = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    ReauthenticationBottomSheet.show(
                      context: context,
                      authService: fakeAuth,
                      onSuccess: () => successCalled = true,
                    );
                  },
                  child: const Text('Open Sheet'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Open bottom sheet
        await tester.tap(find.text('Open Sheet'));
        await tester.pumpAndSettle();

        // Verify sheet UI
        expect(find.byKey(const Key('reauth_modal_title')), findsOneWidget);
        expect(find.byKey(const Key('reauth_password_field')), findsOneWidget);
        expect(find.byKey(const Key('reauth_confirm_button')), findsOneWidget);

        // Enter password and submit
        await tester.enterText(find.byKey(const Key('reauth_password_field')), 'secret123');
        await tester.tap(find.byKey(const Key('reauth_confirm_button')));
        await tester.pumpAndSettle();

        expect(fakeAuth.reauthPasswordCallCount, 1);
        expect(fakeAuth.deleteCallCount, 1);
        expect(fakeAuth.testUser.wasDeleted, isTrue);
        expect(successCalled, isTrue);
      },
    );

    testWidgets(
      'ReauthenticationBottomSheet: Shows inline error on invalid credentials without closing',
      (WidgetTester tester) async {
        final fakeAuth = FakeReauthAuthService()..throwPasswordError = true;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    ReauthenticationBottomSheet.show(
                      context: context,
                      authService: fakeAuth,
                      onSuccess: () {},
                    );
                  },
                  child: const Text('Open Sheet'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open Sheet'));
        await tester.pumpAndSettle();

        await tester.enterText(find.byKey(const Key('reauth_password_field')), 'wrong_pass');
        await tester.tap(find.byKey(const Key('reauth_confirm_button')));
        await tester.pumpAndSettle();

        expect(fakeAuth.reauthPasswordCallCount, 1);
        expect(fakeAuth.testUser.wasDeleted, isFalse);
        expect(find.byKey(const Key('reauth_error_banner')), findsOneWidget);
        expect(find.text('Incorrect password. Please try again.'), findsOneWidget);
      },
    );

    testWidgets(
      'ReauthenticationBottomSheet: Phone flow sends SMS, enters OTP, and deletes',
      (WidgetTester tester) async {
        final fakeAuth = FakeReauthAuthService(
          user: ReauthTestUser(
            phoneNumber: '+15551234567',
            providers: ['phone'],
          ),
        );
        bool successCalled = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    ReauthenticationBottomSheet.show(
                      context: context,
                      authService: fakeAuth,
                      onSuccess: () => successCalled = true,
                    );
                  },
                  child: const Text('Open Sheet'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open Sheet'));
        await tester.pumpAndSettle();

        // 1. Verify "Send Verification SMS" button is present
        expect(find.byKey(const Key('reauth_send_code_button')), findsOneWidget);

        // 2. Tap to send code
        await tester.tap(find.byKey(const Key('reauth_send_code_button')));
        await tester.pumpAndSettle();

        expect(fakeAuth.sendPhoneCodeCallCount, 1);
        expect(find.byKey(const Key('reauth_sms_code_field')), findsOneWidget);

        // 3. Enter 6-digit code and submit
        await tester.enterText(find.byKey(const Key('reauth_sms_code_field')), '123456');
        await tester.tap(find.byKey(const Key('reauth_confirm_button')));
        await tester.pumpAndSettle();

        expect(fakeAuth.reauthPhoneCallCount, 1);
        expect(fakeAuth.deleteCallCount, 1);
        expect(fakeAuth.testUser.wasDeleted, isTrue);
        expect(successCalled, isTrue);
      },
    );

    testWidgets(
      'ReauthenticationBottomSheet: Google flow triggers reauthenticateWithGoogle',
      (WidgetTester tester) async {
        final fakeAuth = FakeReauthAuthService(
          user: ReauthTestUser(
            email: 'googleuser@gmail.com',
            providers: ['google.com'],
          ),
        );
        bool successCalled = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    ReauthenticationBottomSheet.show(
                      context: context,
                      authService: fakeAuth,
                      onSuccess: () => successCalled = true,
                    );
                  },
                  child: const Text('Open Sheet'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open Sheet'));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('reauth_google_button')), findsOneWidget);
        await tester.tap(find.byKey(const Key('reauth_google_button')));
        await tester.pumpAndSettle();

        expect(fakeAuth.reauthGoogleCallCount, 1);
        expect(fakeAuth.deleteCallCount, 1);
        expect(fakeAuth.testUser.wasDeleted, isTrue);
        expect(successCalled, isTrue);
      },
    );

    testWidgets(
      'ClientAccountScreen: Prompts reauthentication sheet on requires-recent-login and deletes cleanly',
      (WidgetTester tester) async {
        final fakeAuth = FakeReauthAuthService()
          ..throwRequiresRecentLoginOnDelete = true;

        await tester.pumpWidget(
          MaterialApp(
            home: ClientAccountScreen(
              authService: fakeAuth,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Scroll to delete button
        final deleteBtn = find.byKey(const Key('account_delete_account_button'));
        await tester.ensureVisible(deleteBtn);
        await tester.tap(deleteBtn);
        await tester.pumpAndSettle();

        // 2. Confirm in initial dialog
        await tester.tap(find.byKey(const Key('delete_account_confirm_button')));
        await tester.pumpAndSettle();

        // First attempt failed with requires-recent-login, bottom sheet should open!
        expect(fakeAuth.deleteCallCount, 1);
        expect(find.byKey(const Key('reauth_modal_title')), findsOneWidget);
        expect(find.byKey(const Key('reauth_password_field')), findsOneWidget);

        // 3. User enters credentials in the reauth sheet
        await tester.enterText(find.byKey(const Key('reauth_password_field')), 'mypassword');
        await tester.tap(find.byKey(const Key('reauth_confirm_button')));
        await tester.pump();
        await tester.pump();
        await tester.pump();

        // 4. Verification and second deletion attempt succeeded
        expect(fakeAuth.reauthPasswordCallCount, 1);
        expect(fakeAuth.deleteCallCount, 2);
        expect(fakeAuth.testUser.wasDeleted, isTrue);

        // 5. Success SnackBar and navigation to SplashScreen
        expect(find.text('Account deleted. A confirmation email has been sent.'), findsOneWidget);
        expect(find.byType(SplashScreen), findsOneWidget);
      },
    );

    testWidgets(
      'ClientAccountScreen: Cancelling reauth sheet displays SnackBar with Verify action button',
      (WidgetTester tester) async {
        final fakeAuth = FakeReauthAuthService()
          ..throwRequiresRecentLoginOnDelete = true;

        await tester.pumpWidget(
          MaterialApp(
            home: ClientAccountScreen(
              authService: fakeAuth,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Scroll and tap delete button
        final deleteBtn = find.byKey(const Key('account_delete_account_button'));
        await tester.ensureVisible(deleteBtn);
        await tester.tap(deleteBtn);
        await tester.pumpAndSettle();

        // Confirm in dialog -> triggers requires-recent-login and opens sheet
        await tester.tap(find.byKey(const Key('delete_account_confirm_button')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('reauth_modal_title')), findsOneWidget);

        // Tap cancel in the sheet
        await tester.tap(find.byKey(const Key('reauth_cancel_button')));
        await tester.pumpAndSettle();

        // Sheet dismissed, SnackBar with Verify action should appear
        expect(find.byKey(const Key('reauth_modal_title')), findsNothing);
        expect(find.byType(SnackBar), findsOneWidget);
        expect(
          find.text('This action requires recent authentication. Please log in again before deleting your account.'),
          findsOneWidget,
        );
        expect(find.text('Verify'), findsOneWidget);

        // Tapping Verify re-opens the reauthentication sheet
        await tester.tap(find.text('Verify'));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('reauth_modal_title')), findsOneWidget);
      },
    );
  });
}
