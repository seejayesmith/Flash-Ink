import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:flash_ink/main.dart';
import 'package:flash_ink/screens/splash_screen.dart';
import 'package:flash_ink/screens/phone_verification_screen.dart';
import 'package:flash_ink/screens/account_creation_screen.dart';
import 'package:flash_ink/services/auth_service.dart';

class FakeUserCredential implements UserCredential {
  @override
  final User? user;
  @override
  final AuthCredential? credential;
  @override
  final AdditionalUserInfo? additionalUserInfo;

  FakeUserCredential({this.user, this.credential, this.additionalUserInfo});
}

class FakeAuthService extends AuthService {
  bool failVerifyPhone = false;
  bool failSignInWithPhone = false;
  int resendCallCount = 0;
  int? lastForceResendingToken;

  @override
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(Exception error) onVerificationFailed,
    void Function(PhoneAuthCredential credential)? onVerificationCompleted,
    void Function(String verificationId)? onCodeAutoRetrievalTimeout,
    int? forceResendingToken,
  }) async {
    resendCallCount++;
    lastForceResendingToken = forceResendingToken;
    if (failVerifyPhone) {
      onVerificationFailed(Exception('Please enter a valid phone number.'));
    } else {
      onCodeSent('fake_verification_id_123', 888);
    }
  }

  @override
  Future<UserCredential> signInWithPhoneCredential({
    required String verificationId,
    required String smsCode,
  }) async {
    if (failSignInWithPhone || smsCode != '123456') {
      throw Exception('The verification code entered is invalid.');
    }
    return FakeUserCredential();
  }

  @override
  Future<void> updatePhoneVerificationStatus({
    required String uid,
    required String phoneNumber,
  }) async {
    // No-op for fake service
  }
}

void main() {
  testWidgets('SplashScreen renders branding and progress indicator cleanly', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify SplashScreen and branding elements are displayed
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.text('Flash'), findsOneWidget);
    expect(find.byIcon(Icons.electric_bolt), findsOneWidget);
    expect(find.text('TATTOO DISCOVERY & BOOKING'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  group('AuthService Exception Handling', () {
    final authService = AuthService();

    test('maps invalid-phone-number', () {
      final exc = authService.handleFirebaseAuthException(
        FirebaseAuthException(code: 'invalid-phone-number'),
      );
      expect(exc.toString(), contains('Please enter a valid phone number.'));
    });

    test('maps invalid-verification-code', () {
      final exc = authService.handleFirebaseAuthException(
        FirebaseAuthException(code: 'invalid-verification-code'),
      );
      expect(exc.toString(), contains('The verification code entered is invalid.'));
    });

    test('maps session-expired', () {
      final exc = authService.handleFirebaseAuthException(
        FirebaseAuthException(code: 'session-expired'),
      );
      expect(exc.toString(), contains('Verification code has expired.'));
    });

    test('maps quota-exceeded', () {
      final exc = authService.handleFirebaseAuthException(
        FirebaseAuthException(code: 'quota-exceeded'),
      );
      expect(exc.toString(), contains('SMS quota exceeded.'));
    });

    test('maps too-many-requests', () {
      final exc = authService.handleFirebaseAuthException(
        FirebaseAuthException(code: 'too-many-requests'),
      );
      expect(exc.toString(), contains('Too many attempts.'));
    });
  });

  group('PhoneVerificationScreen Widget Tests', () {
    testWidgets('Displays error SnackBar when short code entered', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PhoneVerificationScreen(
            phoneNumber: '+15550192834',
            verificationId: 'test_vid',
          ),
        ),
      );

      await tester.tap(find.text('VERIFY'));
      await tester.pump();

      expect(find.text('Please enter a valid 6-digit verification code'), findsOneWidget);
    });

    testWidgets('Displays error SnackBar on invalid verification code failure', (WidgetTester tester) async {
      final fakeAuth = FakeAuthService()..failSignInWithPhone = true;

      await tester.pumpWidget(
        MaterialApp(
          home: PhoneVerificationScreen(
            phoneNumber: '+15550192834',
            verificationId: 'test_vid',
            authService: fakeAuth,
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), '000000');
      await tester.pump();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('The verification code entered is invalid'), findsOneWidget);
      expect(find.byType(PhoneVerificationScreen), findsOneWidget);
    });

    testWidgets('Resend button triggers verifyPhoneNumber with forceResendingToken', (WidgetTester tester) async {
      final fakeAuth = FakeAuthService();

      await tester.pumpWidget(
        MaterialApp(
          home: PhoneVerificationScreen(
            phoneNumber: '+15550192834',
            verificationId: 'test_vid',
            resendToken: 42,
            authService: fakeAuth,
          ),
        ),
      );

      await tester.tap(find.text('Resend'));
      await tester.pump();

      expect(fakeAuth.resendCallCount, 1);
      expect(fakeAuth.lastForceResendingToken, 42);
      expect(find.text('A new 6-digit code has been sent.'), findsOneWidget);
    });
  });

  group('AccountCreationScreen Phone Auth Tests', () {
    testWidgets('Surfaces error when phone verification fails', (WidgetTester tester) async {
      final fakeAuth = FakeAuthService()..failVerifyPhone = true;

      await tester.pumpWidget(
        MaterialApp(
          home: AccountCreationScreen(
            role: 'client',
            authService: fakeAuth,
          ),
        ),
      );

      // Tap 'Continue with Phone'
      await tester.tap(find.text('Continue with Phone'));
      await tester.pumpAndSettle();

      // Enter phone number
      await tester.enterText(find.byType(TextFormField), '5550192834');
      await tester.pump();

      // Tap 'SEND VERIFICATION CODE'
      await tester.tap(find.text('SEND VERIFICATION CODE'));
      await tester.pumpAndSettle();

      // Error should be displayed and modal should remain open
      expect(find.textContaining('Please enter a valid phone number.'), findsWidgets);
      expect(find.text('Verify Phone Number'), findsOneWidget);
    });

    testWidgets('Navigates to PhoneVerificationScreen when phone verification succeeds', (WidgetTester tester) async {
      final fakeAuth = FakeAuthService();

      await tester.pumpWidget(
        MaterialApp(
          home: AccountCreationScreen(
            role: 'client',
            authService: fakeAuth,
          ),
        ),
      );

      // Tap 'Continue with Phone'
      await tester.tap(find.text('Continue with Phone'));
      await tester.pumpAndSettle();

      // Enter phone number
      await tester.enterText(find.byType(TextFormField), '5550192834');
      await tester.pump();

      // Tap 'SEND VERIFICATION CODE'
      await tester.tap(find.text('SEND VERIFICATION CODE'));
      await tester.pumpAndSettle();

      // Should have navigated to PhoneVerificationScreen
      expect(find.byType(PhoneVerificationScreen), findsOneWidget);
      expect(find.textContaining('5550192834'), findsOneWidget);
    });
  });
}
