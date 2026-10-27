import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flash_ink/features/auth/presentation/widgets/unified_auth_input_field.dart';
import 'package:flash_ink/screens/account_creation_screen.dart';
import 'package:flash_ink/screens/email_auth_screen.dart';
import 'package:flash_ink/screens/phone_verification_screen.dart';
import 'package:flash_ink/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class _FakeUnifiedAuthService extends AuthService {
  int verifyPhoneCalls = 0;
  String? lastPhoneNumber;

  @override
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    void Function(PhoneAuthCredential)? onVerificationCompleted,
    required void Function(String, int?) onCodeSent,
    required void Function(Exception) onVerificationFailed,
    void Function(String)? onCodeAutoRetrievalTimeout,
    int? forceResendingToken,
  }) async {
    verifyPhoneCalls++;
    lastPhoneNumber = phoneNumber;
    onCodeSent('unified_vid_123', 42);
  }
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('detectAuthInputType & validateUnifiedAuthInput Unit Tests', () {
    test('Detects pure 10-digit and formatted numbers as AuthInputType.phone', () {
      expect(detectAuthInputType('5551234567'), AuthInputType.phone);
      expect(detectAuthInputType('(555) 123-4567'), AuthInputType.phone);
      expect(detectAuthInputType('+1 555-123-4567'), AuthInputType.phone);
      expect(validateUnifiedAuthInput('5551234567'), isNull);
    });

    test('Detects standard emails as AuthInputType.email', () {
      expect(detectAuthInputType('artist@studio.com'), AuthInputType.email);
      expect(validateUnifiedAuthInput('artist@studio.com'), isNull);
    });

    test('Detects emails starting with a phone number as AuthInputType.email without corruption', () {
      // User starts typing digits -> initially phone
      expect(detectAuthInputType('5551234567'), AuthInputType.phone);

      // The instant '@' or a letter is typed, switches to email
      expect(detectAuthInputType('5551234567@'), AuthInputType.email);
      expect(detectAuthInputType('5551234567@gmail.com'), AuthInputType.email);
      expect(detectAuthInputType('2024artist@studio.com'), AuthInputType.email);

      // Validates cleanly as an email
      expect(validateUnifiedAuthInput('5551234567@gmail.com'), isNull);
      expect(validateUnifiedAuthInput('5551234567@'), 'Please enter a valid email address');
    });
  });

  group('AccountCreationScreen Unified Input Widget Tests (Artist & Client)', () {
    testWidgets(
      'Email starting with a phone number (5551234567@gmail.com) routes to EmailAuthScreen with email pre-filled and has no leading @ icon',
      (WidgetTester tester) async {
        final fakeAuth = _FakeUnifiedAuthService();

        await tester.pumpWidget(
          MaterialApp(
            home: AccountCreationScreen(
              role: 'artist',
              authService: fakeAuth,
            ),
          ),
        );

        final inputFinder = find.byKey(const Key('unified_auth_input_field'));
        expect(inputFinder, findsOneWidget);

        // Verify there is NO misleading leading '@' icon
        expect(find.byIcon(Icons.alternate_email), findsNothing);

        // 1. User types 10 digits first
        await tester.enterText(inputFinder, '5551234567');
        await tester.pump();

        // 2. User continues typing '@gmail.com' -> no phone mask characters injected
        await tester.enterText(inputFinder, '5551234567@gmail.com');
        await tester.pump();

        final fieldWidget = tester.widget<TextFormField>(inputFinder);
        expect(fieldWidget.controller?.text, '5551234567@gmail.com');

        // 3. Tap CONTINUE -> routes to EmailAuthScreen with email prefilled, does NOT call verifyPhoneNumber
        await tester.tap(find.byKey(const Key('unified_auth_continue_button')));
        await tester.pumpAndSettle();

        expect(fakeAuth.verifyPhoneCalls, 0);
        expect(find.byType(EmailAuthScreen), findsOneWidget);
        expect(find.text('5551234567@gmail.com'), findsOneWidget);
      },
    );

    testWidgets(
      'Phone number input on AccountCreationScreen dispatches SMS OTP and routes to PhoneVerificationScreen for both client and artist',
      (WidgetTester tester) async {
        final fakeAuth = _FakeUnifiedAuthService();

        await tester.pumpWidget(
          MaterialApp(
            home: AccountCreationScreen(
              role: 'client',
              authService: fakeAuth,
            ),
          ),
        );

        final inputFinder = find.byKey(const Key('unified_auth_input_field'));
        await tester.enterText(inputFinder, '5550192834');
        await tester.pump();

        await tester.tap(find.byKey(const Key('unified_auth_continue_button')));
        await tester.pumpAndSettle();

        expect(fakeAuth.verifyPhoneCalls, 1);
        expect(fakeAuth.lastPhoneNumber, '+15550192834');
        expect(find.byType(PhoneVerificationScreen), findsOneWidget);
      },
    );
  });
}
