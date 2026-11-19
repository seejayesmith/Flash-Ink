import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';

import 'package:flash_ink/screens/artist_onboarding/artist_info_screen.dart';
import 'package:flash_ink/screens/artist_onboarding/artist_phone_verification_screen.dart';
import 'package:flash_ink/screens/artist_onboarding/artist_profile_photo_screen.dart';
import 'package:flash_ink/screens/auth_routing.dart';
import 'package:flash_ink/services/auth_service.dart';
import 'package:flash_ink/widgets/phone_number_input_formatter.dart';

class MockUserInfo extends Fake implements UserInfo {
  @override
  final String providerId;

  MockUserInfo(this.providerId);
}

class MockUserWithPhone extends Fake implements User {
  @override
  final String uid;
  @override
  final String? email;
  @override
  final String? displayName;
  @override
  final String? phoneNumber;
  final List<String> providers;

  MockUserWithPhone({
    required this.uid,
    this.email,
    this.displayName,
    this.phoneNumber,
    this.providers = const [],
  });

  @override
  List<UserInfo> get providerData =>
      providers.map((id) => MockUserInfo(id)).toList();

  @override
  Future<void> updateDisplayName(String? name) async {}

  @override
  Future<void> updatePhotoURL(String? photoUri) async {}

  @override
  Future<String> getIdToken([bool forceRefresh = false]) async => 'mock_token';
}

class FakeTestAuthService extends AuthService {
  final MockUserWithPhone? user;
  int verifyPhoneNumberCallCount = 0;
  String? lastPhoneNumberVerified;

  FakeTestAuthService({this.user});

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
    onCodeSent('test_vid', 123);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  group('PhoneNumberInputFormatter & Display Helper Tests', () {
    test('AuthService.formatDisplayPhoneNumber formats correctly', () {
      expect(AuthService.formatDisplayPhoneNumber(null), '');
      expect(AuthService.formatDisplayPhoneNumber(''), '');
      expect(AuthService.formatDisplayPhoneNumber('+15551234567'), '(555) 123-4567');
      expect(AuthService.formatDisplayPhoneNumber('5551234567'), '(555) 123-4567');
      expect(AuthService.formatDisplayPhoneNumber('15551234567'), '(555) 123-4567');
      expect(AuthService.formatDisplayPhoneNumber('(555) 123-4567'), '(555) 123-4567');
      expect(AuthService.formatDisplayPhoneNumber('+447911123456'), '+447911123456');
    });

    test('PhoneNumberInputFormatter formats domestic digits incrementally', () {
      const formatter = PhoneNumberInputFormatter();

      var result = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: '5', selection: TextSelection.collapsed(offset: 1)),
      );
      expect(result.text, '(5');

      result = formatter.formatEditUpdate(
        result,
        const TextEditingValue(text: '(555', selection: TextSelection.collapsed(offset: 4)),
      );
      expect(result.text, '(555');

      result = formatter.formatEditUpdate(
        result,
        const TextEditingValue(text: '(5551', selection: TextSelection.collapsed(offset: 5)),
      );
      expect(result.text, '(555) 1');

      result = formatter.formatEditUpdate(
        result,
        const TextEditingValue(text: '5551234567', selection: TextSelection.collapsed(offset: 10)),
      );
      expect(result.text, '(555) 123-4567');
    });

    test('PhoneNumberInputFormatter preserves international numbers with + prefix', () {
      const formatter = PhoneNumberInputFormatter();

      final result = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: '+44 7911 123456', selection: TextSelection.collapsed(offset: 15)),
      );
      expect(result.text, '+447911123456');
    });
  });

  group('ArtistInfoScreen Adaptive Contact & Verification Flow Tests', () {
    testWidgets('Phone-OTP artist hides verified phone field and prompts for optional Backup Email', (tester) async {
      final mockUser = MockUserWithPhone(
        uid: 'artist_phone_user',
        displayName: 'InkMaster',
        phoneNumber: '+15551234567',
        providers: const ['phone'],
      );
      final fakeAuth = FakeTestAuthService(user: mockUser);

      await tester.pumpWidget(
        MaterialApp(
          home: ArtistInfoScreen(authService: fakeAuth),
        ),
      );
      await tester.pumpAndSettle();

      // Handle and optional Backup Email are shown; already-verified Phone field is hidden
      expect(find.byKey(const Key('artist_name_handle_field')), findsOneWidget);
      expect(find.byKey(const Key('artist_backup_email_field')), findsOneWidget);
      expect(find.byKey(const Key('artist_phone_field')), findsNothing);
      expect(find.text('(555) 123-4567'), findsNothing);
      expect(
        find.text('Enter your artist name and an optional backup email to get set up.'),
        findsOneWidget,
      );
    });

    testWidgets('Email artist hides email field, prompts for optional Phone Number, and skips SMS when left blank', (tester) async {
      final mockUser = MockUserWithPhone(
        uid: 'artist_email_user',
        displayName: 'OddMaree',
        email: 'artist@studio.com',
        providers: const ['password'],
      );
      final fakeAuth = FakeTestAuthService(user: mockUser);

      await tester.pumpWidget(
        MaterialApp(
          home: ArtistInfoScreen(authService: fakeAuth),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('artist_name_handle_field')), findsOneWidget);
      expect(find.byKey(const Key('artist_phone_field')), findsOneWidget);
      expect(find.byKey(const Key('artist_backup_email_field')), findsNothing);
      expect(
        find.text('Enter your artist name and an optional phone number to get set up.'),
        findsOneWidget,
      );

      // Agree to terms and continue with optional phone left blank
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('continue_artist_info_button')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(fakeAuth.verifyPhoneNumberCallCount, 0);
      expect(find.byType(ArtistProfilePhotoScreen), findsOneWidget);
      expect(find.byType(ArtistPhoneVerificationScreen), findsNothing);
    });

    testWidgets('Email artist entering optional phone number triggers SMS verification', (tester) async {
      final mockUser = MockUserWithPhone(
        uid: 'artist_email_user_2',
        displayName: 'OddMaree',
        email: 'artist@studio.com',
        providers: const ['password'],
      );
      final fakeAuth = FakeTestAuthService(user: mockUser);

      await tester.pumpWidget(
        MaterialApp(
          home: ArtistInfoScreen(authService: fakeAuth),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('artist_phone_field')), '5559876543');
      await tester.pumpAndSettle();

      // Check terms box
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      // Tap CONTINUE
      await tester.tap(find.byKey(const Key('continue_artist_info_button')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // Verify AuthService.verifyPhoneNumber WAS invoked with entered number
      expect(fakeAuth.verifyPhoneNumberCallCount, 1);
      expect(fakeAuth.lastPhoneNumberVerified, '+15559876543');

      // Navigated to ArtistPhoneVerificationScreen
      expect(find.byType(ArtistPhoneVerificationScreen), findsOneWidget);
    });

    testWidgets('Apple sign-in artist only sees handle field and Terms checkbox and proceeds directly to Profile Photo', (tester) async {
      final appleUser = MockUserWithPhone(
        uid: 'artist_apple_user',
        displayName: 'AppleInk',
        email: 'hidden@privaterelay.appleid.com',
        providers: const ['apple.com'],
      );
      final fakeAuth = FakeTestAuthService(user: appleUser);

      await tester.pumpWidget(
        MaterialApp(
          home: ArtistInfoScreen(authService: fakeAuth),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('artist_name_handle_field')), findsOneWidget);
      expect(find.byKey(const Key('artist_phone_field')), findsNothing);
      expect(find.byKey(const Key('artist_backup_email_field')), findsNothing);
      expect(find.text('Enter your artist name to get set up.'), findsOneWidget);

      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('continue_artist_info_button')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(fakeAuth.verifyPhoneNumberCallCount, 0);
      expect(find.byType(ArtistProfilePhotoScreen), findsOneWidget);
    });

    testWidgets('Phone-OTP artist leaving optional Backup Email blank advances directly to Profile Photo without SMS verification', (tester) async {
      final mockUser = MockUserWithPhone(
        uid: 'artist_phone_user',
        displayName: 'OddMaree',
        phoneNumber: '+15551234567',
        providers: const ['phone'],
      );
      final fakeAuth = FakeTestAuthService(user: mockUser);

      await tester.pumpWidget(
        MaterialApp(
          home: ArtistInfoScreen(authService: fakeAuth),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('continue_artist_info_button')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(fakeAuth.verifyPhoneNumberCallCount, 0);
      expect(find.byType(ArtistProfilePhotoScreen), findsOneWidget);
      expect(find.byType(ArtistPhoneVerificationScreen), findsNothing);
    });

    testWidgets('AuthRouting passes user.phoneNumber to ArtistInfoScreen and prompts phone user for optional Backup Email', (tester) async {
      final mockUser = MockUserWithPhone(
        uid: 'new_artist_uid',
        displayName: 'InkArtist',
        phoneNumber: '+15552223333',
        providers: const ['phone'],
      );
      final fakeAuth = FakeTestAuthService(user: mockUser);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  AuthRouting.routeUserAfterAuth(
                    context,
                    mockUser,
                    defaultRole: 'artist',
                    authService: fakeAuth,
                  );
                },
                child: const Text('Route'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Route'));
      await tester.pumpAndSettle();

      final infoScreen = tester.widget<ArtistInfoScreen>(find.byType(ArtistInfoScreen));
      expect(infoScreen.initialPhone, '+15552223333');
      expect(find.byKey(const Key('artist_backup_email_field')), findsOneWidget);
      expect(find.byKey(const Key('artist_phone_field')), findsNothing);
    });
  });
}
