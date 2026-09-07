import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:flash_ink/screens/account_creation_screen.dart';
import 'package:flash_ink/screens/phone_verification_screen.dart';
import 'package:flash_ink/screens/profile_setup_screen.dart';
import 'package:flash_ink/screens/role_selection_screen.dart';
import 'package:flash_ink/services/auth_service.dart';

import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';

class MockUser extends Fake implements User {

  @override
  final String uid;
  @override
  final String? phoneNumber;

  MockUser({required this.uid, this.phoneNumber});
}

class MockUserCredential extends Fake implements UserCredential {
  @override
  final User? user;

  MockUserCredential({this.user});
}

class AdversarialFakeAuthService extends AuthService {
  bool failVerifyPhone = false;
  String verifyPhoneErrorCode = 'invalid-phone-number';
  
  bool failSignInWithPhone = false;
  String signInErrorCode = 'invalid-verification-code';
  
  bool failFirestoreUpdate = false;
  
  int verifyPhoneNumberCallCount = 0;
  String? lastPhoneNumberSent;
  int? lastForceResendingToken;
  
  int signInCallCount = 0;
  String? lastVerificationIdUsed;
  String? lastSmsCodeUsed;
  
  int firestoreUpdateCallCount = 0;
  String? lastFirestoreUid;
  String? lastFirestorePhone;
  bool firestorePhoneVerifiedSet = false;

  final String validSmsCode;
  final String initialVerificationId;
  final int initialResendToken;

  AdversarialFakeAuthService({
    this.validSmsCode = '123456',
    this.initialVerificationId = 'vid_initial_111',
    this.initialResendToken = 500,
  });

  @override
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(Exception error) onVerificationFailed,
    void Function(PhoneAuthCredential credential)? onVerificationCompleted,
    void Function(String verificationId)? onCodeAutoRetrievalTimeout,
    int? forceResendingToken,
  }) async {
    verifyPhoneNumberCallCount++;
    lastPhoneNumberSent = phoneNumber;
    lastForceResendingToken = forceResendingToken;

    if (failVerifyPhone) {
      onVerificationFailed(handleFirebaseAuthException(
        FirebaseAuthException(code: verifyPhoneErrorCode),
      ));
    } else {
      final newVid = forceResendingToken != null ? 'vid_resent_222' : initialVerificationId;
      final newToken = forceResendingToken != null ? 777 : initialResendToken;
      onCodeSent(newVid, newToken);
    }
  }

  @override
  Future<UserCredential> signInWithPhoneCredential({
    required String verificationId,
    required String smsCode,
  }) async {
    signInCallCount++;
    lastVerificationIdUsed = verificationId;
    lastSmsCodeUsed = smsCode;

    if (failSignInWithPhone || smsCode != validSmsCode) {
      throw handleFirebaseAuthException(
        FirebaseAuthException(code: signInErrorCode),
      );
    }

    return MockUserCredential(
      user: MockUser(uid: 'test_user_uid_123', phoneNumber: lastPhoneNumberSent),
    );
  }

  @override
  Future<void> updatePhoneVerificationStatus({
    required String uid,
    required String phoneNumber,
  }) async {
    firestoreUpdateCallCount++;
    lastFirestoreUid = uid;
    lastFirestorePhone = phoneNumber;

    if (failFirestoreUpdate) {
      throw Exception('Firestore network timeout or permission denied');
    }

    firestorePhoneVerifiedSet = true;
  }

  int signOutCallCount = 0;
  @override
  Future<void> signOut() async {
    signOutCallCount++;
  }
}

void main() {
  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  group('Adversarial Test Suite: Phone Auth Flow & Edge Cases', () {
    late AdversarialFakeAuthService authService;

    setUp(() {
      authService = AdversarialFakeAuthService();
    });

    Widget createScreen(Widget child) {
      return MaterialApp(
        home: child,
      );
    }

    // =========================================================================
    // 1. AccountCreationScreen: Phone Number Validation & Formatting Edge Cases
    // =========================================================================
    group('AccountCreationScreen Edge Cases', () {
      testWidgets('Blocks empty or whitespace-only phone number', (WidgetTester tester) async {
        await tester.pumpWidget(createScreen(AccountCreationScreen(
          role: 'client',
          authService: authService,
        )));

        // Open Phone bottom sheet
        await tester.tap(find.text('Continue with Phone'));
        await tester.pumpAndSettle();

        // Leave empty and tap send
        await tester.tap(find.text('SEND VERIFICATION CODE'));
        await tester.pumpAndSettle();

        expect(find.text('Please enter your phone number'), findsOneWidget);
        expect(authService.verifyPhoneNumberCallCount, 0);
        expect(find.byType(PhoneVerificationScreen), findsNothing);
      });

      testWidgets('Blocks short phone numbers under 10 digits', (WidgetTester tester) async {
        await tester.pumpWidget(createScreen(AccountCreationScreen(
          role: 'client',
          authService: authService,
        )));

        await tester.tap(find.text('Continue with Phone'));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextFormField), '555-123');
        await tester.pump();

        await tester.tap(find.text('SEND VERIFICATION CODE'));
        await tester.pumpAndSettle();

        expect(find.text('Please enter a valid 10-digit phone number'), findsOneWidget);
        expect(authService.verifyPhoneNumberCallCount, 0);
        expect(find.byType(PhoneVerificationScreen), findsNothing);
      });

      testWidgets('Formats 10-digit raw number with +1 prefix', (WidgetTester tester) async {
        await tester.pumpWidget(createScreen(AccountCreationScreen(
          role: 'client',
          authService: authService,
        )));

        await tester.tap(find.text('Continue with Phone'));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextFormField), '4155552671');
        await tester.pump();

        await tester.tap(find.text('SEND VERIFICATION CODE'));
        await tester.pumpAndSettle();

        expect(authService.verifyPhoneNumberCallCount, 1);
        expect(authService.lastPhoneNumberSent, '+1 4155552671');
        expect(find.byType(PhoneVerificationScreen), findsOneWidget);
      });

      testWidgets('Does not double-prefix if number already starts with +', (WidgetTester tester) async {
        await tester.pumpWidget(createScreen(AccountCreationScreen(
          role: 'client',
          authService: authService,
        )));

        await tester.tap(find.text('Continue with Phone'));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextFormField), '+44 7911 123456');
        await tester.pump();

        await tester.tap(find.text('SEND VERIFICATION CODE'));
        await tester.pumpAndSettle();

        expect(authService.verifyPhoneNumberCallCount, 1);
        expect(authService.lastPhoneNumberSent, '+44 7911 123456');
        expect(find.byType(PhoneVerificationScreen), findsOneWidget);
      });

      testWidgets('Surfaces SMS failure, keeps modal open, and allows recovery on retry', (WidgetTester tester) async {
        authService.failVerifyPhone = true;
        authService.verifyPhoneErrorCode = 'quota-exceeded';

        await tester.pumpWidget(createScreen(AccountCreationScreen(
          role: 'client',
          authService: authService,
        )));

        await tester.tap(find.text('Continue with Phone'));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextFormField), '5550192834');
        await tester.pump();

        await tester.tap(find.text('SEND VERIFICATION CODE'));
        await tester.pumpAndSettle();

        // Check error surfaced in both banner and snackbar
        expect(find.textContaining('SMS quota exceeded'), findsWidgets);
        // Modal remains open
        expect(find.text('Verify Phone Number'), findsOneWidget);
        expect(find.byType(PhoneVerificationScreen), findsNothing);
        expect(authService.firestorePhoneVerifiedSet, isFalse);

        // RECOVERY: fix error condition and tap again
        authService.failVerifyPhone = false;
        await tester.tap(find.text('SEND VERIFICATION CODE'));
        await tester.pumpAndSettle();

        expect(authService.verifyPhoneNumberCallCount, 2);
        expect(find.byType(PhoneVerificationScreen), findsOneWidget);
      });
    });

    // =========================================================================
    // 2. PhoneVerificationScreen: OTP Edge Cases & Failure Containment
    // =========================================================================
    group('PhoneVerificationScreen Adversarial Containment', () {
      testWidgets('Rejects short code (<6 digits) and prevents service calls or navigation', (WidgetTester tester) async {
        await tester.pumpWidget(createScreen(PhoneVerificationScreen(
          phoneNumber: '+15550192834',
          verificationId: 'vid_initial_111',
          authService: authService,
        )));

        // Empty code
        await tester.tap(find.text('VERIFY'));
        await tester.pump();

        expect(find.text('Please enter a valid 6-digit verification code'), findsOneWidget);
        expect(authService.signInCallCount, 0);
        expect(authService.firestoreUpdateCallCount, 0);
        expect(find.byType(ProfileSetupScreen), findsNothing);

        // 3-digit code
        await tester.enterText(find.byType(TextField), '123');
        await tester.pump();

        await tester.tap(find.text('VERIFY'));
        await tester.pump();

        expect(find.text('Please enter a valid 6-digit verification code'), findsOneWidget);
        expect(authService.signInCallCount, 0);
        expect(authService.firestoreUpdateCallCount, 0);
        expect(find.byType(ProfileSetupScreen), findsNothing);
      });

      testWidgets('CRITICAL: On failed OTP, user CANNOT progress to ProfileSetupScreen and Firestore NEVER updated', (WidgetTester tester) async {
        authService.failSignInWithPhone = true;
        authService.signInErrorCode = 'invalid-verification-code';

        await tester.pumpWidget(createScreen(PhoneVerificationScreen(
          phoneNumber: '+15550192834',
          verificationId: 'vid_initial_111',
          authService: authService,
        )));

        await tester.enterText(find.byType(TextField), '999999');
        await tester.pump();

        // Tap verify or trigger verification
        await tester.tap(find.text('VERIFY'));
        await tester.pumpAndSettle();

        // 1. Error must be surfaced
        expect(find.textContaining('The verification code entered is invalid'), findsOneWidget);

        // 2. User MUST remain on PhoneVerificationScreen
        expect(find.byType(PhoneVerificationScreen), findsOneWidget);
        expect(find.byType(ProfileSetupScreen), findsNothing);

        // 3. Firestore MUST NEVER have phoneVerified=true recorded
        expect(authService.firestorePhoneVerifiedSet, isFalse);
        expect(authService.firestoreUpdateCallCount, 0);

        // 4. Code controller must be cleared
        final TextField field = tester.widget(find.byType(TextField));
        expect(field.controller?.text, isEmpty);
      });

      testWidgets('CRITICAL: On session-expired OTP failure, containment holds', (WidgetTester tester) async {
        authService.failSignInWithPhone = true;
        authService.signInErrorCode = 'session-expired';

        await tester.pumpWidget(createScreen(PhoneVerificationScreen(
          phoneNumber: '+15550192834',
          verificationId: 'vid_initial_111',
          authService: authService,
        )));

        await tester.enterText(find.byType(TextField), '654321');
        await tester.pumpAndSettle();

        expect(find.textContaining('Verification code has expired'), findsOneWidget);
        expect(find.byType(PhoneVerificationScreen), findsOneWidget);
        expect(find.byType(ProfileSetupScreen), findsNothing);
        expect(authService.firestorePhoneVerifiedSet, isFalse);
        expect(authService.firestoreUpdateCallCount, 0);
      });

      testWidgets('CRITICAL: When Firestore updatePhoneVerificationStatus fails, navigation is blocked', (WidgetTester tester) async {
        authService.failFirestoreUpdate = true; // Sign-in succeeds, but Firestore write throws

        await tester.pumpWidget(createScreen(PhoneVerificationScreen(
          phoneNumber: '+15550192834',
          verificationId: 'vid_initial_111',
          authService: authService,
        )));

        await tester.enterText(find.byType(TextField), '123456');
        await tester.pumpAndSettle();

        // Sign in was called, Firestore update was attempted
        expect(authService.signInCallCount, 1);
        expect(authService.firestoreUpdateCallCount, 1);
        expect(authService.firestorePhoneVerifiedSet, isFalse);

        // Crucial: Navigation MUST be blocked because profile status update failed
        expect(find.byType(ProfileSetupScreen), findsNothing);
        expect(find.byType(PhoneVerificationScreen), findsOneWidget);
        expect(find.textContaining('Firestore network timeout or permission denied'), findsOneWidget);
      });

      testWidgets('OTP Failure Recovery: user enters bad code, fails, then enters correct code and progresses', (WidgetTester tester) async {
        authService.failSignInWithPhone = false; // Code '123456' succeeds, other codes fail

        await tester.pumpWidget(createScreen(PhoneVerificationScreen(
          phoneNumber: '+15550192834',
          verificationId: 'vid_initial_111',
          authService: authService,
        )));

        // Step 1: Enter invalid code
        await tester.enterText(find.byType(TextField), '000000');
        await tester.pumpAndSettle();

        expect(find.textContaining('The verification code entered is invalid'), findsOneWidget);
        expect(find.byType(ProfileSetupScreen), findsNothing);
        expect(authService.firestorePhoneVerifiedSet, isFalse);

        // Step 2: Enter correct code
        await tester.enterText(find.byType(TextField), '123456');
        await tester.pumpAndSettle();

        // Now should succeed, update Firestore, and navigate to ProfileSetupScreen
        expect(authService.firestorePhoneVerifiedSet, isTrue);
        expect(authService.lastFirestoreUid, 'test_user_uid_123');
        expect(find.byType(ProfileSetupScreen), findsOneWidget);
      });
    });

    // =========================================================================
    // 3. Resend Code Behavior & Token Propagation
    // =========================================================================
    group('Resend SMS Behavior & Verification ID Updates', () {
      testWidgets('Resend SMS updates verificationId and subsequent verification uses the new ID', (WidgetTester tester) async {
        await tester.pumpWidget(createScreen(PhoneVerificationScreen(
          phoneNumber: '+15550192834',
          verificationId: 'vid_initial_111',
          resendToken: 500,
          authService: authService,
        )));

        // Tap Resend
        await tester.tap(find.text('Resend'));
        await tester.pumpAndSettle();

        expect(authService.verifyPhoneNumberCallCount, 1);
        expect(authService.lastForceResendingToken, 500);
        expect(find.text('A new 6-digit code has been sent.'), findsOneWidget);

        // Enter valid code
        await tester.enterText(find.byType(TextField), '123456');
        await tester.pumpAndSettle();

        // Must have used the NEW verification ID ('vid_resent_222') generated by resend
        expect(authService.lastVerificationIdUsed, 'vid_resent_222');
        expect(authService.firestorePhoneVerifiedSet, isTrue);
        expect(find.byType(ProfileSetupScreen), findsOneWidget);
      });

      testWidgets('Resend failure surfaces error SnackBar and does not change state', (WidgetTester tester) async {
        authService.failVerifyPhone = true;
        authService.verifyPhoneErrorCode = 'too-many-requests';

        await tester.pumpWidget(createScreen(PhoneVerificationScreen(
          phoneNumber: '+15550192834',
          verificationId: 'vid_initial_111',
          resendToken: 500,
          authService: authService,
        )));

        await tester.tap(find.text('Resend'));
        await tester.pumpAndSettle();

        expect(find.textContaining('Too many attempts'), findsOneWidget);
        expect(find.byType(PhoneVerificationScreen), findsOneWidget);
        expect(find.byType(ProfileSetupScreen), findsNothing);
      });
    });

    // =========================================================================
    // 4. Concurrency & Rapid Interaction Stress
    // =========================================================================
    group('Concurrency & Rapid Interaction Stress', () {
      testWidgets('Resend failure preserves initial verificationId and allows successful verification with original code', (WidgetTester tester) async {
        // Initially, resend will fail
        authService.failVerifyPhone = true;
        authService.verifyPhoneErrorCode = 'quota-exceeded';

        await tester.pumpWidget(createScreen(PhoneVerificationScreen(
          phoneNumber: '+15550192834',
          verificationId: 'vid_initial_111',
          resendToken: 500,
          authService: authService,
        )));

        // Tap Resend -> fails
        await tester.tap(find.text('Resend'));
        await tester.pumpAndSettle();

        expect(find.textContaining('SMS quota exceeded'), findsOneWidget);

        // Now enter the original valid SMS code
        await tester.enterText(find.byType(TextField), '123456');
        await tester.pumpAndSettle();

        // Must still have used the original verificationId ('vid_initial_111')
        expect(authService.lastVerificationIdUsed, 'vid_initial_111');
        expect(authService.firestorePhoneVerifiedSet, isTrue);
        expect(find.byType(ProfileSetupScreen), findsOneWidget);
      });

      testWidgets('Multiple sequential failures: user fails twice with invalid codes, then recovers and succeeds', (WidgetTester tester) async {
        await tester.pumpWidget(createScreen(PhoneVerificationScreen(
          phoneNumber: '+15550192834',
          verificationId: 'vid_initial_111',
          authService: authService,
        )));

        // Failure 1
        await tester.enterText(find.byType(TextField), '111111');
        await tester.pumpAndSettle();
        expect(find.textContaining('The verification code entered is invalid'), findsOneWidget);
        expect(find.byType(ProfileSetupScreen), findsNothing);
        expect(authService.firestorePhoneVerifiedSet, isFalse);

        // Failure 2
        await tester.enterText(find.byType(TextField), '222222');
        await tester.pumpAndSettle();
        expect(find.textContaining('The verification code entered is invalid'), findsOneWidget);
        expect(find.byType(ProfileSetupScreen), findsNothing);
        expect(authService.firestorePhoneVerifiedSet, isFalse);

        // Success 3
        await tester.enterText(find.byType(TextField), '123456');
        await tester.pumpAndSettle();
        expect(authService.firestorePhoneVerifiedSet, isTrue);
        expect(find.byType(ProfileSetupScreen), findsOneWidget);
      });

      testWidgets('Rejects whitespace-only 6-character code as short code', (WidgetTester tester) async {
        await tester.pumpWidget(createScreen(PhoneVerificationScreen(
          phoneNumber: '+15550192834',
          verificationId: 'vid_initial_111',
          authService: authService,
        )));

        await tester.enterText(find.byType(TextField), '      ');
        await tester.pump();

        await tester.tap(find.text('VERIFY'));
        await tester.pump();

        expect(find.text('Please enter a valid 6-digit verification code'), findsOneWidget);
        expect(authService.signInCallCount, 0);
      });

      testWidgets('Cancel action calls authService.signOut() and navigates to RoleSelectionScreen', (WidgetTester tester) async {
        await tester.pumpWidget(createScreen(PhoneVerificationScreen(
          phoneNumber: '+15550192834',
          verificationId: 'vid_initial_111',
          authService: authService,
        )));

        // Tap back / cancel button
        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pumpAndSettle();

        expect(authService.signOutCallCount, 1);
        expect(find.byType(RoleSelectionScreen), findsOneWidget);
      });
    });

    group('AuthService Exception Mapper Fallback Edge Cases', () {
      test('Maps unknown error code to fallback message with code', () {
        final exc = authService.handleFirebaseAuthException(
          FirebaseAuthException(code: 'unknown-vendor-error', message: 'Something went wrong in vendor SDK'),
        );
        expect(exc.toString(), contains('Something went wrong in vendor SDK'));
      });
    });
  });
}

