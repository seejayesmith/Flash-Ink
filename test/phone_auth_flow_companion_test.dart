import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:flash_ink/screens/account_creation_screen.dart';
import 'package:flash_ink/screens/phone_verification_screen.dart';
import 'package:flash_ink/screens/profile_setup_screen.dart';
import 'package:flash_ink/services/auth_service.dart';
import 'package:flash_ink/theme/app_typography.dart';

/// Test doubles for Firebase Auth objects
class CompanionMockUser extends Fake implements User {
  @override
  final String uid;
  @override
  final String? phoneNumber;
  @override
  final String? displayName;

  CompanionMockUser({
    required this.uid,
    this.phoneNumber,
    this.displayName,
  });
}

class CompanionMockUserCredential extends Fake implements UserCredential {
  @override
  final User? user;

  CompanionMockUserCredential({this.user});
}

/// A comprehensive, stateful FakeAuthService companion test harness.
class CompanionFakeAuthService extends AuthService {
  bool failVerifyPhone = false;
  String verifyPhoneErrorCode = 'invalid-phone-number';
  String? customVerifyErrorMessage;

  bool failSignInWithPhone = false;
  String signInErrorCode = 'invalid-verification-code';
  String? customSignInErrorMessage;

  bool failUpdatePhoneStatus = false;

  final String validSmsCode;
  String currentVerificationId;
  int currentResendToken;

  int verifyPhoneCallCount = 0;
  String? lastPhoneNumberVerified;
  int? lastForceResendingToken;

  int signInCallCount = 0;
  String? lastVerificationIdUsed;
  String? lastSmsCodeUsed;

  int updateStatusCallCount = 0;
  String? lastUpdatedUid;
  String? lastUpdatedPhone;

  int signOutCallCount = 0;

  User? _mockUser;

  CompanionFakeAuthService({
    this.validSmsCode = '123456',
    this.currentVerificationId = 'companion_vid_1001',
    this.currentResendToken = 555,
  }) {
    _mockUser = CompanionMockUser(
      uid: 'companion_user_uid_999',
      phoneNumber: '+15550192834',
      displayName: 'Test Artist',
    );
  }

  @override
  User? get currentUser => _mockUser;

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

    if (failVerifyPhone) {
      if (customVerifyErrorMessage != null) {
        onVerificationFailed(Exception(customVerifyErrorMessage));
      } else {
        onVerificationFailed(handleFirebaseAuthException(
          FirebaseAuthException(code: verifyPhoneErrorCode),
        ));
      }
      return;
    }

    if (forceResendingToken != null) {
      currentVerificationId = 'companion_vid_resent_2002';
      currentResendToken = 777;
    }

    onCodeSent(currentVerificationId, currentResendToken);
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
      if (customSignInErrorMessage != null) {
        throw Exception(customSignInErrorMessage);
      }
      throw handleFirebaseAuthException(
        FirebaseAuthException(code: signInErrorCode),
      );
    }

    return CompanionMockUserCredential(user: _mockUser);
  }

  @override
  Future<void> updatePhoneVerificationStatus({
    required String uid,
    required String phoneNumber,
  }) async {
    updateStatusCallCount++;
    lastUpdatedUid = uid;
    lastUpdatedPhone = phoneNumber;

    if (failUpdatePhoneStatus) {
      throw Exception('Firestore update failure: Connection timed out');
    }
  }

  @override
  Future<void> signOut() async {
    signOutCallCount++;
    _mockUser = null;
  }
}

Widget buildCompanionApp({
  required AuthService authService,
  String role = 'client',
}) {
  return MaterialApp(
    title: 'Flash Ink Flow Test',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      textTheme: AppTypography.textTheme(),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFEEC200),
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xFF121414),
    ),
    home: AccountCreationScreen(
      role: role,
      authService: authService,
    ),
  );
}

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  group('Milestone M2 Companion Suite — Phone Auth E2E Headless Flow', () {
    late CompanionFakeAuthService authService;

    setUp(() {
      authService = CompanionFakeAuthService();
    });

    // =========================================================================
    // Branch A: Valid Flow (Phone Entry -> 6-Digit OTP -> ProfileSetupScreen)
    // =========================================================================
    testWidgets(
      'Branch A (Valid Flow): User enters valid phone number -> enters valid 6-digit OTP code -> UI correctly transitions to ProfileSetupScreen',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(buildCompanionApp(authService: authService));
        await tester.pumpAndSettle();

        // 1. Verify AccountCreationScreen is displayed
        expect(find.byType(AccountCreationScreen), findsOneWidget);
        expect(find.text('Continue with Phone'), findsOneWidget);

        // 2. Tap 'Continue with Phone' to open the modal bottom sheet
        await tester.tap(find.text('Continue with Phone'));
        await tester.pumpAndSettle();

        // Verify bottom sheet modal is open
        expect(find.text('Verify Phone Number'), findsOneWidget);
        expect(
          find.text('Enter your mobile number to receive a 6-digit verification code.'),
          findsOneWidget,
        );
        expect(find.text('SEND VERIFICATION CODE'), findsOneWidget);

        // 3. Enter valid 10-digit phone number
        final phoneFieldFinder = find.byType(TextFormField);
        await tester.enterText(phoneFieldFinder, '5550192834');
        await tester.pump();

        // 4. Tap 'SEND VERIFICATION CODE'
        await tester.tap(find.text('SEND VERIFICATION CODE'));
        await tester.pumpAndSettle();

        // 5. Verify AuthService received verifyPhoneNumber with formatted number
        expect(authService.verifyPhoneCallCount, 1);
        expect(authService.lastPhoneNumberVerified, '+1 5550192834');

        // 6. Verify bottom sheet modal is dismissed and UI transitioned to PhoneVerificationScreen
        expect(find.text('Verify Phone Number'), findsNothing);
        expect(find.byType(PhoneVerificationScreen), findsOneWidget);
        expect(find.text('Security Check'), findsOneWidget);
        expect(find.text('Verify your number.'), findsOneWidget);
        expect(find.textContaining('5550192834'), findsOneWidget);

        // 7. Enter valid 6-digit OTP code into the code field
        final codeInputFinder = find.byType(TextField);
        expect(codeInputFinder, findsOneWidget);
        await tester.enterText(codeInputFinder, '123456');
        await tester.pumpAndSettle();

        // 8. Verify AuthService handled signInWithPhoneCredential & Firestore update
        expect(authService.signInCallCount, 1);
        expect(authService.lastVerificationIdUsed, 'companion_vid_1001');
        expect(authService.lastSmsCodeUsed, '123456');
        expect(authService.updateStatusCallCount, 1);
        expect(authService.lastUpdatedUid, 'companion_user_uid_999');
        expect(authService.lastUpdatedPhone, '+1 5550192834');

        // 9. Verify UI correctly transitioned to ProfileSetupScreen
        expect(find.byType(PhoneVerificationScreen), findsNothing);
        expect(find.byType(ProfileSetupScreen), findsOneWidget);
        expect(find.text('Profile Setup'), findsOneWidget);
      },
    );

    // =========================================================================
    // Branch B: Simulated SMS Dispatch Failure
    // =========================================================================
    testWidgets(
      'Branch B (Simulated SMS Dispatch Failure): User enters invalid phone / simulated network failure -> error is visibly displayed, modal remains open, does NOT navigate to PhoneVerificationScreen',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        // Configure failure on SMS dispatch
        authService.failVerifyPhone = true;
        authService.verifyPhoneErrorCode = 'invalid-phone-number';

        await tester.pumpWidget(buildCompanionApp(authService: authService));
        await tester.pumpAndSettle();

        // 1. Open phone entry modal
        await tester.tap(find.text('Continue with Phone'));
        await tester.pumpAndSettle();
        expect(find.text('Verify Phone Number'), findsOneWidget);

        // 2. Enter phone number
        final phoneFieldFinder = find.byType(TextFormField);
        await tester.enterText(phoneFieldFinder, '5550000000');
        await tester.pump();

        // 3. Trigger SMS send
        await tester.tap(find.text('SEND VERIFICATION CODE'));
        await tester.pumpAndSettle();

        // 4. Verify AuthService was invoked
        expect(authService.verifyPhoneCallCount, 1);

        // 5. Verify error is visibly displayed in UI:
        // - Inline alert container in modal displays mapped error message
        expect(find.text('Please enter a valid phone number.'), findsWidgets);
        expect(find.byIcon(Icons.error_outline), findsWidgets);
        // - Error SnackBar is visible
        expect(find.byType(SnackBar), findsOneWidget);

        // 6. Verify modal REMAINS OPEN
        expect(find.text('Verify Phone Number'), findsOneWidget);
        expect(find.text('SEND VERIFICATION CODE'), findsOneWidget);
        expect(find.text('5550000000'), findsOneWidget);

        // 7. Verify UI does NOT navigate to PhoneVerificationScreen or ProfileSetupScreen
        expect(find.byType(PhoneVerificationScreen), findsNothing);
        expect(find.byType(ProfileSetupScreen), findsNothing);

        // 8. Verify Error Recovery: user fixes phone number, failure cleared, can progress
        authService.failVerifyPhone = false;
        await tester.enterText(phoneFieldFinder, '5550192834');
        await tester.pump();

        await tester.tap(find.text('SEND VERIFICATION CODE'));
        await tester.pumpAndSettle();

        // Now modal dismissed and navigated to PhoneVerificationScreen
        expect(find.text('Verify Phone Number'), findsNothing);
        expect(find.byType(PhoneVerificationScreen), findsOneWidget);
      },
    );

    testWidgets(
      'Branch B Variant: Simulated quota-exceeded SMS failure displays specific error and retains modal state',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        authService.failVerifyPhone = true;
        authService.verifyPhoneErrorCode = 'quota-exceeded';

        await tester.pumpWidget(buildCompanionApp(authService: authService));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Continue with Phone'));
        await tester.pumpAndSettle();

        final phoneFieldFinder = find.byType(TextFormField);
        await tester.enterText(phoneFieldFinder, '5551234567');
        await tester.pump();

        await tester.tap(find.text('SEND VERIFICATION CODE'));
        await tester.pumpAndSettle();

        // Mapped error message must be visibly surfaced
        expect(
          find.text('SMS quota exceeded. Please try again later.'),
          findsWidgets,
        );
        expect(find.byIcon(Icons.error_outline), findsWidgets);
        expect(find.text('Verify Phone Number'), findsOneWidget);
        expect(find.byType(PhoneVerificationScreen), findsNothing);
      },
    );

    // =========================================================================
    // Branch C: Simulated Code Verification Failure
    // =========================================================================
    testWidgets(
      'Branch C (Simulated Code Verification Failure): User enters invalid OTP code -> error is visibly displayed in red SnackBar, user remains on PhoneVerificationScreen, does NOT navigate to ProfileSetupScreen, and code field is cleared',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        // Start from AccountCreationScreen to exercise the complete multi-screen transition
        await tester.pumpWidget(buildCompanionApp(authService: authService));
        await tester.pumpAndSettle();

        // Navigate through phone entry to PhoneVerificationScreen
        await tester.tap(find.text('Continue with Phone'));
        await tester.pumpAndSettle();

        final phoneFieldFinder = find.byType(TextFormField);
        await tester.enterText(phoneFieldFinder, '5550192834');
        await tester.pump();

        await tester.tap(find.text('SEND VERIFICATION CODE'));
        await tester.pumpAndSettle();

        expect(find.byType(PhoneVerificationScreen), findsOneWidget);

        // 1. Enter INVALID 6-digit OTP code ('999999')
        final otpFieldFinder = find.byType(TextField);
        expect(otpFieldFinder, findsOneWidget);

        await tester.enterText(otpFieldFinder, '999999');
        await tester.pumpAndSettle();

        // 2. Verify AuthService rejected the code
        expect(authService.signInCallCount, 1);
        expect(authService.lastSmsCodeUsed, '999999');

        // 3. Verify error is visibly displayed in UI:
        // - Red floating SnackBar with mapped error message
        final snackBarFinder = find.byType(SnackBar);
        expect(snackBarFinder, findsOneWidget);
        final SnackBar snackBarWidget = tester.widget(snackBarFinder);
        expect(snackBarWidget.backgroundColor, const Color(0xFFEF4444));
        expect(
          find.text('Verification failed: The verification code entered is invalid.'),
          findsOneWidget,
        );

        // 4. Verify user REMAINS on PhoneVerificationScreen
        expect(find.byType(PhoneVerificationScreen), findsOneWidget);

        // 5. Verify does NOT navigate to ProfileSetupScreen
        expect(find.byType(ProfileSetupScreen), findsNothing);

        // 6. Verify code field is CLEARED
        final TextField textFieldWidget = tester.widget(otpFieldFinder);
        expect(textFieldWidget.controller?.text, isEmpty);

        // 7. Verify Firestore status update was NEVER called
        expect(authService.updateStatusCallCount, 0);

        // 8. Verify Error Recovery: User now enters correct OTP code ('123456')
        await tester.enterText(otpFieldFinder, '123456');
        await tester.pumpAndSettle();

        // 9. Verify successful transition to ProfileSetupScreen
        expect(authService.signInCallCount, 2);
        expect(authService.updateStatusCallCount, 1);
        expect(find.byType(PhoneVerificationScreen), findsNothing);
        expect(find.byType(ProfileSetupScreen), findsOneWidget);
        expect(find.text('Profile Setup'), findsOneWidget);
      },
    );

    testWidgets(
      'Branch C Variant: Simulated session-expired failure surfaces descriptive error, clears code, blocks progression',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        authService.failSignInWithPhone = true;
        authService.signInErrorCode = 'session-expired';

        await tester.pumpWidget(buildCompanionApp(authService: authService));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Continue with Phone'));
        await tester.pumpAndSettle();

        final phoneFieldFinder = find.byType(TextFormField);
        await tester.enterText(phoneFieldFinder, '5550192834');
        await tester.pump();

        await tester.tap(find.text('SEND VERIFICATION CODE'));
        await tester.pumpAndSettle();

        expect(find.byType(PhoneVerificationScreen), findsOneWidget);

        final otpFieldFinder = find.byType(TextField);
        await tester.enterText(otpFieldFinder, '123456');
        await tester.pumpAndSettle();

        // Verify session-expired message displayed
        expect(
          find.text('Verification failed: Verification code has expired. Please request a new code.'),
          findsOneWidget,
        );
        expect(find.byType(PhoneVerificationScreen), findsOneWidget);
        expect(find.byType(ProfileSetupScreen), findsNothing);

        // Verify code input was cleared
        final TextField textFieldWidget = tester.widget(otpFieldFinder);
        expect(textFieldWidget.controller?.text, isEmpty);
      },
    );

    // =========================================================================
    // Resend Flow Integration Test
    // =========================================================================
    testWidgets(
      'Resend Code Flow: Tapping Resend triggers verifyPhoneNumber with resendToken and notifies user',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(buildCompanionApp(authService: authService));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Continue with Phone'));
        await tester.pumpAndSettle();

        final phoneFieldFinder = find.byType(TextFormField);
        await tester.enterText(phoneFieldFinder, '5550192834');
        await tester.pump();

        await tester.tap(find.text('SEND VERIFICATION CODE'));
        await tester.pumpAndSettle();

        expect(find.byType(PhoneVerificationScreen), findsOneWidget);
        expect(authService.verifyPhoneCallCount, 1);

        // Tap 'Resend' button
        final resendFinder = find.text('Resend');
        expect(resendFinder, findsOneWidget);
        await tester.tap(resendFinder);
        await tester.pumpAndSettle();

        // Verify verifyPhoneNumber called again with resend token
        expect(authService.verifyPhoneCallCount, 2);
        expect(authService.lastForceResendingToken, 555);

        // Confirmation SnackBar displayed
        expect(find.text('A new 6-digit code has been sent.'), findsOneWidget);

        // Now verify with new code
        final otpFieldFinder = find.byType(TextField);
        await tester.enterText(otpFieldFinder, '123456');
        await tester.pumpAndSettle();

        expect(find.byType(ProfileSetupScreen), findsOneWidget);
      },
    );
  });
}
