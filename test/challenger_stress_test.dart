import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:flash_ink/screens/account_creation_screen.dart';
import 'package:flash_ink/screens/phone_verification_screen.dart';
import 'package:flash_ink/screens/role_selection_screen.dart';
import 'package:flash_ink/services/auth_service.dart';

class MockUserCredential implements UserCredential {
  @override
  final User? user;
  @override
  final AuthCredential? credential;
  @override
  final AdditionalUserInfo? additionalUserInfo;

  MockUserCredential({this.user, this.credential, this.additionalUserInfo});
}

class FakeUser implements User {
  @override
  final String uid;

  FakeUser({required this.uid});

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class StressFakeAuthService extends AuthService {
  bool failVerifyPhone = false;
  bool throwSyncOnVerifyPhone = false;
  bool failSignInWithPhone = false;
  bool throwSyncOnSignIn = false;
  bool failUpdateStatus = false;
  User? customUser;
  int verifyPhoneCallCount = 0;
  int signInCallCount = 0;
  int updateStatusCallCount = 0;
  int signOutCallCount = 0;
  String? lastPhoneNumberVerified;
  int? lastForceResendingToken;
  String? lastVerificationIdPassed;
  String? lastSmsCodePassed;
  String? lastUpdatedUid;
  String? lastUpdatedPhone;
  String verificationIdToEmit = 'v_id_orig';
  int resendTokenToEmit = 100;

  @override
  User? get currentUser => customUser;

  @override
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(Exception error) onVerificationFailed,
    void Function(PhoneAuthCredential credential)? onVerificationCompleted,
    void Function(String verificationId)? onCodeAutoRetrievalTimeout,
    int? forceResendingToken,
  }) async {
    verifyPhoneCallCount++;
    lastPhoneNumberVerified = phoneNumber;
    lastForceResendingToken = forceResendingToken;

    if (throwSyncOnVerifyPhone) {
      throw Exception('Synchronous SMS provider crash');
    }

    if (failVerifyPhone) {
      onVerificationFailed(Exception('SMS quota exceeded. Please try again later.'));
    } else {
      onCodeSent(verificationIdToEmit, resendTokenToEmit);
    }
  }

  @override
  Future<UserCredential> signInWithPhoneCredential({
    required String verificationId,
    required String smsCode,
  }) async {
    signInCallCount++;
    lastVerificationIdPassed = verificationId;
    lastSmsCodePassed = smsCode;

    if (throwSyncOnSignIn || failSignInWithPhone) {
      throw Exception('The verification code entered is invalid.');
    }
    return MockUserCredential(user: customUser);
  }

  @override
  Future<void> updatePhoneVerificationStatus({
    required String uid,
    required String phoneNumber,
  }) async {
    updateStatusCallCount++;
    lastUpdatedUid = uid;
    lastUpdatedPhone = phoneNumber;
    if (failUpdateStatus) {
      throw Exception('Firestore write timed out');
    }
  }

  @override
  Future<void> signOut() async {
    signOutCallCount++;
  }
}

void main() {
  group('AuthService Exception Mapping Stress Tests', () {
    final authService = AuthService();

    test('verifies all standard phone auth exception codes', () {
      final codeMap = {
        'invalid-phone-number': 'Please enter a valid phone number.',
        'invalid-verification-code': 'The verification code entered is invalid.',
        'session-expired': 'Verification code has expired. Please request a new code.',
        'quota-exceeded': 'SMS quota exceeded. Please try again later.',
        'too-many-requests': 'Too many attempts. Please try again later.',
      };

      for (final entry in codeMap.entries) {
        final exc = authService.handleFirebaseAuthException(
          FirebaseAuthException(code: entry.key),
        );
        expect(exc.toString(), contains(entry.value), reason: 'Failed mapping for ${entry.key}');
      }
    });

    test('verifies general auth exception codes and fallbacks', () {
      final generalCodes = {
        'invalid-email': 'The email address is invalid.',
        'user-disabled': 'This account has been disabled.',
        'user-not-found': 'No account found with this email.',
        'wrong-password': 'Incorrect password or credentials.',
        'invalid-credential': 'Incorrect password or credentials.',
        'email-already-in-use': 'An account already exists for this email.',
        'operation-not-allowed': 'Anonymous authentication is disabled',
        'admin-restricted-operation': 'Anonymous authentication is disabled',
        'weak-password': 'The password provided is too weak.',
        'credential-already-in-use': 'This account is already linked to another user.',
        'network-request-failed': 'Network error. Please check your internet connection.',
      };

      for (final entry in generalCodes.entries) {
        final exc = authService.handleFirebaseAuthException(
          FirebaseAuthException(code: entry.key),
        );
        expect(exc.toString(), contains(entry.value), reason: 'Failed mapping for ${entry.key}');
      }

      // Fallback with custom message
      final customFallback = authService.handleFirebaseAuthException(
        FirebaseAuthException(code: 'custom-error', message: 'Custom server error description'),
      );
      expect(customFallback.toString(), contains('Custom server error description'));

      // Fallback with null message
      final nullFallback = authService.handleFirebaseAuthException(
        FirebaseAuthException(code: 'unknown-code', message: null),
      );
      expect(nullFallback.toString(), contains('Authentication error (unknown-code).'));
    });

    test('AuthService instantiation is safe without Firebase initialization', () {
      expect(() => AuthService(), returnsNormally);
      expect(() => AuthService(auth: null, firestore: null), returnsNormally);
    });
  });

  group('AccountCreationScreen Empirical Verification & Stress Tests', () {
    testWidgets('Validation blocks invalid phone numbers', (WidgetTester tester) async {
      final fakeAuth = StressFakeAuthService();
      await tester.pumpWidget(
        MaterialApp(
          home: AccountCreationScreen(role: 'client', authService: fakeAuth),
        ),
      );

      // Open phone modal
      await tester.tap(find.text('Continue with Phone'));
      await tester.pumpAndSettle();

      // Submit empty
      await tester.tap(find.text('SEND VERIFICATION CODE'));
      await tester.pump();
      expect(find.text('Please enter your phone number'), findsOneWidget);
      expect(fakeAuth.verifyPhoneCallCount, 0);

      // Enter short number (< 10 digits)
      await tester.enterText(find.byType(TextFormField), '12345');
      await tester.tap(find.text('SEND VERIFICATION CODE'));
      await tester.pump();
      expect(find.text('Please enter a valid 10-digit phone number'), findsOneWidget);
      expect(fakeAuth.verifyPhoneCallCount, 0);
    });

    testWidgets('Surfaces SMS failure in inline alert container and SnackBar without dismissing modal', (WidgetTester tester) async {
      final fakeAuth = StressFakeAuthService()..failVerifyPhone = true;

      await tester.pumpWidget(
        MaterialApp(
          home: AccountCreationScreen(role: 'client', authService: fakeAuth),
        ),
      );

      await tester.tap(find.text('Continue with Phone'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), '5551234567');
      await tester.pump();

      await tester.tap(find.text('SEND VERIFICATION CODE'));
      await tester.pumpAndSettle();

      // 1. Verify phone service was invoked with formatted phone (+1 5551234567)
      expect(fakeAuth.verifyPhoneCallCount, 1);
      expect(fakeAuth.lastPhoneNumberVerified, '+1 5551234567');

      // 2. Verify modal remains visible
      expect(find.text('Verify Phone Number'), findsOneWidget);
      expect(find.text('SEND VERIFICATION CODE'), findsOneWidget);

      // 3. Verify error is surfaced in inline alert container
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.textContaining('SMS quota exceeded. Please try again later.'), findsWidgets);

      // 4. Verify floating SnackBar was surfaced
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('Surfaces synchronous SMS exception cleanly in UI without crashing', (WidgetTester tester) async {
      final fakeAuth = StressFakeAuthService()..throwSyncOnVerifyPhone = true;

      await tester.pumpWidget(
        MaterialApp(
          home: AccountCreationScreen(role: 'client', authService: fakeAuth),
        ),
      );

      await tester.tap(find.text('Continue with Phone'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), '5559876543');
      await tester.pump();

      await tester.tap(find.text('SEND VERIFICATION CODE'));
      await tester.pumpAndSettle();

      // Error caught by try/catch in _showPhoneEntryModal
      expect(find.textContaining('Synchronous SMS provider crash'), findsWidgets);
      expect(find.text('Verify Phone Number'), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('Formats numbers correctly: preserves existing + country code', (WidgetTester tester) async {
      final fakeAuth = StressFakeAuthService();

      await tester.pumpWidget(
        MaterialApp(
          home: AccountCreationScreen(role: 'client', authService: fakeAuth),
        ),
      );

      await tester.tap(find.text('Continue with Phone'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), '+447911123456');
      await tester.pump();

      await tester.tap(find.text('SEND VERIFICATION CODE'));
      await tester.pumpAndSettle();

      expect(fakeAuth.lastPhoneNumberVerified, '+447911123456');
      expect(find.byType(PhoneVerificationScreen), findsOneWidget);
    });
  });

  group('PhoneVerificationScreen Empirical Verification & Stress Tests', () {
    testWidgets('Short code (< 6 digits) shows SnackBar and does not call auth service', (WidgetTester tester) async {
      final fakeAuth = StressFakeAuthService();

      await tester.pumpWidget(
        MaterialApp(
          home: PhoneVerificationScreen(
            phoneNumber: '+15550192834',
            verificationId: 'v_id_test',
            authService: fakeAuth,
          ),
        ),
      );

      // Enter 3 digits and tap VERIFY
      await tester.enterText(find.byType(TextField), '123');
      await tester.pump();

      await tester.tap(find.text('VERIFY'));
      await tester.pump();

      expect(find.text('Please enter a valid 6-digit verification code'), findsOneWidget);
      expect(fakeAuth.signInCallCount, 0);
    });

    testWidgets('Invalid OTP code displays floating error SnackBar, clears text input, and remains on screen', (WidgetTester tester) async {
      final fakeAuth = StressFakeAuthService()..failSignInWithPhone = true;

      await tester.pumpWidget(
        MaterialApp(
          home: PhoneVerificationScreen(
            phoneNumber: '+15550192834',
            verificationId: 'v_id_test',
            authService: fakeAuth,
          ),
        ),
      );

      // Enter 6 digits
      await tester.enterText(find.byType(TextField), '654321');
      await tester.pump();

      // Triggered by onChanged when length == 6
      expect(fakeAuth.signInCallCount, 1);
      expect(fakeAuth.lastSmsCodePassed, '654321');
      expect(fakeAuth.lastVerificationIdPassed, 'v_id_test');

      // Verify SnackBar displayed
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Verification failed: The verification code entered is invalid.'), findsOneWidget);

      // Verify text field was cleared
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, '');

      // Verify still on PhoneVerificationScreen
      expect(find.byType(PhoneVerificationScreen), findsOneWidget);
    });

    testWidgets('Resend code updates verificationId and token and surfaces confirmation', (WidgetTester tester) async {
      final fakeAuth = StressFakeAuthService()
        ..verificationIdToEmit = 'v_id_new_456'
        ..resendTokenToEmit = 999
        ..failSignInWithPhone = true; // prevent navigation to ProfileSetupScreen

      await tester.pumpWidget(
        MaterialApp(
          home: PhoneVerificationScreen(
            phoneNumber: '+15550192834',
            verificationId: 'v_id_init',
            resendToken: 111,
            authService: fakeAuth,
          ),
        ),
      );

      await tester.tap(find.text('Resend'));
      await tester.pump();

      expect(fakeAuth.verifyPhoneCallCount, 1);
      expect(fakeAuth.lastForceResendingToken, 111);
      expect(find.text('A new 6-digit code has been sent.'), findsOneWidget);

      // Subsequent OTP submission uses the updated verification ID
      await tester.enterText(find.byType(TextField), '123456');
      await tester.pump();

      expect(fakeAuth.lastVerificationIdPassed, 'v_id_new_456');
    });

    testWidgets('Resend code error surfaces in error SnackBar', (WidgetTester tester) async {
      final fakeAuth = StressFakeAuthService()..failVerifyPhone = true;

      await tester.pumpWidget(
        MaterialApp(
          home: PhoneVerificationScreen(
            phoneNumber: '+15550192834',
            verificationId: 'v_id_init',
            authService: fakeAuth,
          ),
        ),
      );

      await tester.tap(find.text('Resend'));
      await tester.pump();

      expect(fakeAuth.verifyPhoneCallCount, 1);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('SMS quota exceeded. Please try again later.'), findsOneWidget);
    });

    testWidgets('Firestore status update failure surfaces in error SnackBar and clears input', (WidgetTester tester) async {
      final fakeAuth = StressFakeAuthService()
        ..customUser = FakeUser(uid: 'uid_test_123')
        ..failUpdateStatus = true;

      await tester.pumpWidget(
        MaterialApp(
          home: PhoneVerificationScreen(
            phoneNumber: '+15550192834',
            verificationId: 'v_id_init',
            authService: fakeAuth,
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), '123456');
      await tester.pump();

      expect(fakeAuth.signInCallCount, 1);
      expect(fakeAuth.updateStatusCallCount, 1);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('Firestore write timed out'), findsOneWidget);

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, '');
      expect(find.byType(PhoneVerificationScreen), findsOneWidget);
    });

    testWidgets('Cancel navigation calls signOut and redirects to RoleSelectionScreen', (WidgetTester tester) async {
      final fakeAuth = StressFakeAuthService();

      await tester.pumpWidget(
        MaterialApp(
          home: PhoneVerificationScreen(
            phoneNumber: '+15550192834',
            verificationId: 'v_id_init',
            authService: fakeAuth,
          ),
        ),
      );

      // Tap back button
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(fakeAuth.signOutCallCount, 1);
      expect(find.byType(RoleSelectionScreen), findsOneWidget);
    });
  });
}
