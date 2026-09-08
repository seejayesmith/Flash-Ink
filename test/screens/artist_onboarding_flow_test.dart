import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';

import 'package:flash_ink/widgets/artist_stepper_header.dart';
import 'package:flash_ink/screens/artist_onboarding/artist_sign_up_screen.dart';
import 'package:flash_ink/screens/artist_onboarding/artist_phone_verification_screen.dart';
import 'package:flash_ink/screens/artist_onboarding/artist_profile_photo_screen.dart';
import 'package:flash_ink/screens/artist_onboarding/artist_share_link_screen.dart';
import 'package:flash_ink/services/auth_service.dart';

class MockUser extends Fake implements User {
  @override
  final String uid;
  @override
  final String? email;
  @override
  final String? displayName;

  MockUser({required this.uid, this.email, this.displayName});

  @override
  Future<void> updateDisplayName(String? name) async {}

  @override
  Future<void> updatePhotoURL(String? photoUri) async {}
}

class MockUserCredential extends Fake implements UserCredential {
  @override
  final User? user;

  MockUserCredential({this.user});
}

class FakeArtistAuthService extends AuthService {
  bool failVerifyPhone = false;
  bool failSignIn = false;

  int verifyCallCount = 0;
  String? lastPhoneSent;

  final MockUser mockUser = MockUser(uid: 'artist_123', email: 'ink@studio.com', displayName: 'OddMaree');

  @override
  User? get currentUser => mockUser;

  @override
  Future<UserCredential> signUpWithEmailAndPassword(String email, String password) async {
    return MockUserCredential(user: mockUser);
  }

  @override
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(Exception error) onVerificationFailed,
    void Function(PhoneAuthCredential credential)? onVerificationCompleted,
    void Function(String verificationId)? onCodeAutoRetrievalTimeout,
    int? forceResendingToken,
  }) async {
    verifyCallCount++;
    lastPhoneSent = phoneNumber;
    if (failVerifyPhone) {
      onVerificationFailed(Exception('Verification failed: invalid-phone-number'));
    } else {
      onCodeSent('vid_test_123', 456);
    }
  }

  @override
  Future<UserCredential> signInWithPhoneCredential({
    required String verificationId,
    required String smsCode,
  }) async {
    if (failSignIn) {
      throw Exception('Invalid verification code');
    }
    return MockUserCredential(user: mockUser);
  }

  @override
  Future<void> updatePhoneVerificationStatus({
    required String uid,
    required String phoneNumber,
  }) async {}
}

void main() {
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  group('ArtistStepperHeader Tests', () {
    testWidgets('Step 1 renders correctly with no checkmarks', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ArtistStepperHeader(currentStep: 1),
          ),
        ),
      );

      expect(find.text('Setup\nyour\naccount'), findsOneWidget);
      expect(find.text('Create\nyour\nprofile'), findsOneWidget);
      expect(find.text('Share\nyour\nlink'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsNothing);
    });

    testWidgets('Step 2 renders with Step 1 checkmark and Step 2 active', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ArtistStepperHeader(currentStep: 2),
          ),
        ),
      );

      expect(find.byIcon(Icons.check), findsOneWidget); // Step 1 is checkmarked
      expect(find.text('2'), findsOneWidget); // Step 2 is active
      expect(find.text('3'), findsOneWidget); // Step 3 is upcoming
    });

    testWidgets('Step 3 renders with Steps 1 & 2 checkmarks and Step 3 active', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ArtistStepperHeader(currentStep: 3),
          ),
        ),
      );

      expect(find.byIcon(Icons.check), findsNWidgets(2)); // Steps 1 and 2 checkmarked
      expect(find.text('3'), findsOneWidget);
    });
  });

  group('ArtistSignUpScreen Tests', () {
    testWidgets('Renders all fields, labels, and social buttons', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ArtistSignUpScreen(authService: FakeArtistAuthService()),
        ),
      );

      expect(find.text('Create an\naccount'), findsOneWidget);
      expect(find.text('Join the underground ink community.'), findsOneWidget);
      expect(find.text('Name'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Phone Number'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('CREATE ACCOUNT'), findsOneWidget);
      expect(find.text('Google'), findsOneWidget);
      expect(find.text('Apple'), findsOneWidget);
      expect(find.text('Already have an account? '), findsOneWidget);
    });

    testWidgets('Form validation blocks submit when empty', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ArtistSignUpScreen(authService: FakeArtistAuthService()),
        ),
      );

      await tester.tap(find.text('CREATE ACCOUNT'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter your name or artist handle'), findsOneWidget);
      expect(find.text('Please enter your email'), findsOneWidget);
    });

    testWidgets('Skip button bypasses email and password directly to photo screen', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ArtistSignUpScreen(authService: FakeArtistAuthService()),
        ),
      );

      expect(find.text('Skip'), findsWidgets);
      await tester.tap(find.text('Skip').first);
      await tester.pumpAndSettle();

      expect(find.text('Upload a\nprofile photo'), findsOneWidget);
    });
  });

  group('ArtistPhoneVerificationScreen Tests', () {
    testWidgets('Renders 6-digit inputs, verify button, and resend prompt', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ArtistPhoneVerificationScreen(
            phoneNumber: '+15551234567',
            verificationId: 'vid_123',
            artistName: 'OddMaree',
            artistEmail: 'ink@studio.com',
            authService: FakeArtistAuthService(),
          ),
        ),
      );

      expect(find.text('Verify your phone\nnumber'), findsOneWidget);
      expect(find.byIcon(Icons.chat_bubble), findsOneWidget);
      expect(find.text('VERIFY'), findsOneWidget);
      expect(find.text("Didn't receive code? "), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(6));
      expect(find.text('Skip (Dev)'), findsOneWidget);
      expect(find.text('Skip Verification (Dev)'), findsOneWidget);
    });

    testWidgets('Tapping Skip (Dev) bypasses verification and navigates to photo screen', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ArtistPhoneVerificationScreen(
            phoneNumber: '+15551234567',
            verificationId: 'vid_123',
            artistName: 'OddMaree',
            artistEmail: 'ink@studio.com',
            authService: FakeArtistAuthService(),
          ),
        ),
      );

      await tester.tap(find.text('Skip (Dev)'));
      await tester.pumpAndSettle();

      expect(find.text('Upload a profile\nphoto'), findsOneWidget);
    });
  });

  group('ArtistProfilePhotoScreen Tests', () {
    testWidgets('Renders Upload Photo state with CHANGE and SELECT PHOTO buttons', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ArtistProfilePhotoScreen(
            artistName: 'OddMaree',
            authService: FakeArtistAuthService(),
          ),
        ),
      );

      expect(find.text('Upload a profile\nphoto'), findsOneWidget);
      expect(find.text('CHANGE'), findsOneWidget);
      expect(find.text('SELECT PHOTO'), findsOneWidget);
      expect(find.byIcon(Icons.camera_alt), findsOneWidget);
    });

    testWidgets('Renders Looks Good preview state when photo is present', (tester) async {
      // 1x1 transparent PNG bytes for mock
      final sampleBytes = Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
        0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
        0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
        0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
        0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: ArtistProfilePhotoScreen(
            artistName: 'OddMaree',
            initialImageBytes: sampleBytes,
            authService: FakeArtistAuthService(),
          ),
        ),
      );

      expect(find.text('Looks good'), findsOneWidget);
      expect(find.text('CONTINUE'), findsOneWidget);
      expect(find.text('CHANGE'), findsOneWidget);
    });
  });

  group('ArtistShareLinkScreen Tests', () {
    testWidgets('Renders share link, copy button, and explore button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ArtistShareLinkScreen(
            artistName: 'OddMaree',
          ),
        ),
      );

      expect(find.text('Share your\nlink'), findsOneWidget);
      expect(find.text('flash.ink/@oddmaree'), findsOneWidget);
      expect(find.text('OddMaree'), findsOneWidget);
      expect(find.byIcon(Icons.copy), findsOneWidget);
      expect(find.text('GO TO FLASH.INK'), findsOneWidget);
    });
  });
}
