import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';

import 'package:flash_ink/services/auth_service.dart';
import 'package:flash_ink/widgets/inline_phone_verification_tile.dart';

class MockUserForTile extends Fake implements User {
  @override
  final String uid;
  @override
  final String? email;
  @override
  final String? displayName;
  @override
  String? phoneNumber;

  MockUserForTile({
    required this.uid,
    this.email = 'test@flash.ink',
    this.displayName = 'Tile Tester',
    this.phoneNumber,
  });

  @override
  Future<UserCredential> linkWithCredential(AuthCredential credential) async {
    phoneNumber = '+15551234567';
    return MockTileUserCredential(user: this);
  }
}

class MockTileUserCredential extends Fake implements UserCredential {
  @override
  final User? user;
  MockTileUserCredential({this.user});
}

class FakeTileAuthService extends AuthService {
  final MockUserForTile? user;
  int verifyPhoneNumberCallCount = 0;
  int linkWithPhoneCredentialCallCount = 0;
  String? lastPhoneNumberVerified;

  FakeTileAuthService({this.user});

  @override
  User? get currentUser => user;

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
    lastPhoneNumberVerified = phoneNumber;
    onCodeSent('mock_verification_id_123', 456);
  }

  @override
  Future<UserCredential?> linkWithPhoneCredential({
    required String verificationId,
    required String smsCode,
    String? phoneNumber,
  }) async {
    linkWithPhoneCredentialCallCount++;
    if (smsCode == '000000') {
      throw Exception('Invalid verification code.');
    }
    user?.phoneNumber = phoneNumber ?? '+15551234567';
    return MockTileUserCredential(user: user);
  }

  @override
  Future<void> updatePhoneVerificationStatus({
    required String uid,
    required String phoneNumber,
  }) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  group('InlinePhoneVerificationTile Tests', () {
    testWidgets('Renders collapsed tile with "Not added" and "+ Add" button when unverified', (tester) async {
      final mockUser = MockUserForTile(uid: 'user_tile_1');
      final fakeAuth = FakeTileAuthService(user: mockUser);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InlinePhoneVerificationTile(
              phoneNumber: '',
              phoneVerified: false,
              authService: fakeAuth,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Phone Number'), findsOneWidget);
      expect(find.text('Not added'), findsOneWidget);
      expect(find.byKey(const Key('add_phone_button')), findsOneWidget);
      expect(find.byKey(const Key('phone_verified_badge')), findsNothing);
    });

    testWidgets('Renders collapsed tile with formatted phone, VERIFIED badge, and Change button when verified', (tester) async {
      final mockUser = MockUserForTile(uid: 'user_tile_2', phoneNumber: '+15551234567');
      final fakeAuth = FakeTileAuthService(user: mockUser);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InlinePhoneVerificationTile(
              phoneNumber: '+15551234567',
              phoneVerified: true,
              authService: fakeAuth,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('(555) 123-4567'), findsOneWidget);
      expect(find.byKey(const Key('phone_verified_badge')), findsOneWidget);
      expect(find.text('VERIFIED'), findsOneWidget);
      expect(find.byKey(const Key('change_phone_button')), findsOneWidget);
      expect(find.byKey(const Key('add_phone_button')), findsNothing);
    });

    testWidgets('Tapping "+ Add" expands inline form, validates, sends OTP, and verifies code successfully', (tester) async {
      final mockUser = MockUserForTile(uid: 'user_tile_3');
      final fakeAuth = FakeTileAuthService(user: mockUser);
      String? verifiedNumberResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: InlinePhoneVerificationTile(
                phoneNumber: '',
                phoneVerified: false,
                authService: fakeAuth,
                onPhoneVerified: (newNum) {
                  verifiedNumberResult = newNum;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Add button
      await tester.tap(find.byKey(const Key('add_phone_button')));
      await tester.pumpAndSettle();

      // Inline expansion container is visible
      expect(find.byKey(const Key('inline_phone_expansion_container')), findsOneWidget);
      expect(find.text('Add Phone Number'), findsOneWidget);
      expect(find.byKey(const Key('inline_phone_input_field')), findsOneWidget);

      // Attempt to send empty
      await tester.tap(find.byKey(const Key('inline_phone_send_code_button')));
      await tester.pumpAndSettle();
      expect(find.text('Please enter a phone number.'), findsOneWidget);

      // Enter valid phone number
      await tester.enterText(find.byKey(const Key('inline_phone_input_field')), '5551234567');
      await tester.pumpAndSettle();

      // Send OTP
      await tester.tap(find.byKey(const Key('inline_phone_send_code_button')));
      await tester.pumpAndSettle();

      expect(fakeAuth.verifyPhoneNumberCallCount, 1);
      expect(fakeAuth.lastPhoneNumberVerified, '+15551234567');

      // Now on OTP step
      expect(find.text('Enter OTP Code'), findsOneWidget);
      expect(find.byKey(const Key('inline_phone_otp_field')), findsOneWidget);

      // Enter wrong code
      await tester.enterText(find.byKey(const Key('inline_phone_otp_field')), '000000');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('inline_phone_verify_button')));
      await tester.pumpAndSettle();

      expect(find.text('Invalid verification code.'), findsOneWidget);

      // Enter correct code
      await tester.enterText(find.byKey(const Key('inline_phone_otp_field')), '123456');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('inline_phone_verify_button')));
      await tester.pumpAndSettle();

      expect(fakeAuth.linkWithPhoneCredentialCallCount, 2);
      expect(verifiedNumberResult, '+15551234567');
    });

    testWidgets('Tapping Cancel in expanded form collapses back without saving', (tester) async {
      final mockUser = MockUserForTile(uid: 'user_tile_4');
      final fakeAuth = FakeTileAuthService(user: mockUser);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InlinePhoneVerificationTile(
              phoneNumber: '',
              phoneVerified: false,
              authService: fakeAuth,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('add_phone_button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('inline_phone_expansion_container')), findsOneWidget);

      await tester.tap(find.byKey(const Key('inline_phone_cancel_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('inline_phone_expansion_container')), findsNothing);
      expect(find.byKey(const Key('add_phone_button')), findsOneWidget);
    });
  });
}
