import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';

import 'package:flash_ink/widgets/artist_stepper_header.dart';
import 'package:flash_ink/widgets/tattoo_background_wrapper.dart';
import 'package:flash_ink/widgets/adaptive_glass_container.dart';
import 'package:flash_ink/screens/artist_onboarding/artist_sign_up_screen.dart';
import 'package:flash_ink/screens/artist_onboarding/artist_phone_verification_screen.dart';
import 'package:flash_ink/screens/artist_onboarding/artist_profile_photo_screen.dart';
import 'package:flash_ink/screens/artist_onboarding/artist_instagram_screen.dart';
import 'package:flash_ink/screens/artist_onboarding/artist_set_price_screen.dart';
import 'package:flash_ink/screens/artist_onboarding/artist_flash_upload_screen.dart';
import 'package:flash_ink/screens/artist_onboarding/artist_identity_tags_screen.dart';
import 'package:flash_ink/screens/artist_onboarding/artist_choose_style_screen.dart';
import 'package:flash_ink/screens/artist_onboarding/artist_share_link_screen.dart';
import 'package:flash_ink/screens/artist_dashboard/artist_dashboard_screen.dart';
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

final samplePngBytes = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
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

  group('ArtistStepperHeader Tests', () {
    testWidgets('Renders all three steps with correct labels', (tester) async {
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
    });

    testWidgets('Current step 1 shows step 1 active and steps 2 & 3 inactive', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ArtistStepperHeader(currentStep: 1),
          ),
        ),
      );

      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsNothing);
    });

    testWidgets('Current step 2 shows step 1 completed with checkmark and step 2 active', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ArtistStepperHeader(currentStep: 2),
          ),
        ),
      );

      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('Current step 3 shows steps 1 and 2 completed with checkmarks', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ArtistStepperHeader(currentStep: 3),
          ),
        ),
      );

      expect(find.byIcon(Icons.check), findsNWidgets(2));
      expect(find.text('3'), findsOneWidget);
    });
  });

  group('ArtistSignUpScreen Tests', () {
    testWidgets('Renders all fields, labels, buttons and social logins', (tester) async {
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
      expect(find.byType(TattooBackgroundWrapper), findsOneWidget);
      expect(find.byType(AdaptiveGlassContainer), findsWidgets);
      expect(find.byWidgetPredicate((w) => w is RichText && w.text.toPlainText().contains('Already have an account')), findsOneWidget);
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

    testWidgets('Skip button bypasses all onboarding directly to ArtistDashboardScreen', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ArtistSignUpScreen(authService: FakeArtistAuthService()),
        ),
      );

      expect(find.text('Skip'), findsWidgets);
      await tester.tap(find.text('Skip').first);
      await tester.pumpAndSettle();

      expect(find.byType(ArtistDashboardScreen), findsOneWidget);
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
      expect(find.text('Skip Verification (Dev)'), findsOneWidget);
    });

    testWidgets('Tapping Skip Verification (Dev) bypasses verification and navigates to photo screen', (tester) async {
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

      await tester.tap(find.text('Skip Verification (Dev)'));
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
      await tester.pumpWidget(
        MaterialApp(
          home: ArtistProfilePhotoScreen(
            artistName: 'OddMaree',
            initialImageBytes: samplePngBytes,
            authService: FakeArtistAuthService(),
          ),
        ),
      );

      expect(find.text('Looks good'), findsOneWidget);
      expect(find.text('CONTINUE'), findsOneWidget);
      expect(find.text('CHANGE'), findsOneWidget);
    });

    testWidgets('Tapping CONTINUE navigates to ArtistInstagramScreen (Screen 6)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ArtistProfilePhotoScreen(
            artistName: 'OddMaree',
            initialImageBytes: samplePngBytes,
            authService: FakeArtistAuthService(),
          ),
        ),
      );

      await tester.tap(find.text('CONTINUE'));
      await tester.pumpAndSettle();

      expect(find.text('Keep your\naudience'), findsOneWidget);
      expect(find.text('Add your instagram handle to your artist profile'), findsOneWidget);
    });
  });

  group('ArtistInstagramScreen (Screen 6) Tests', () {
    testWidgets('Renders handle input, continue button, and mockup profile card', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ArtistInstagramScreen(
            artistName: 'OddMaree',
          ),
        ),
      );

      expect(find.text('Keep your\naudience'), findsOneWidget);
      expect(find.byKey(const Key('instagram_handle_field')), findsOneWidget);
      expect(find.text('CONTINUE'), findsOneWidget);
      expect(find.byKey(const Key('continue_to_price_button')), findsOneWidget);
      expect(find.text('Skip (Dev)'), findsOneWidget);
    });

    testWidgets('Tapping CONTINUE navigates to ArtistSetPriceScreen (Screens 7 & 8)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ArtistInstagramScreen(
            artistName: 'OddMaree',
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('continue_to_price_button')));
      await tester.pumpAndSettle();

      expect(find.text('Set your price'), findsOneWidget);
      expect(find.text('Set your minimum deposit. This will be displayed on your profile.'), findsOneWidget);
    });
  });

  group('ArtistSetPriceScreen (Screens 7 & 8) Tests', () {
    testWidgets('Renders price card, numeric keypad, and skip/continue buttons', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ArtistSetPriceScreen(
            artistName: 'OddMaree',
            instagramHandle: '@OddMaree',
          ),
        ),
      );

      expect(find.text('Set your price'), findsOneWidget);
      expect(find.byKey(const Key('price_display_card')), findsOneWidget);
      expect(find.text('100'), findsOneWidget);
      expect(find.byKey(const Key('keypad_1')), findsOneWidget);
      expect(find.byKey(const Key('keypad_backspace')), findsOneWidget);
      expect(find.text('CONTINUE'), findsOneWidget);
      expect(find.text('SKIP'), findsOneWidget);
    });

    testWidgets('Keypad entry and backspace updates price', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ArtistSetPriceScreen(
            artistName: 'OddMaree',
            instagramHandle: '@OddMaree',
          ),
        ),
      );

      // Tap backspace twice
      await tester.tap(find.byKey(const Key('keypad_backspace')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('keypad_backspace')));
      await tester.pump();

      // Now price should be '1'
      expect(find.text('1'), findsWidgets);

      // Tap 5
      await tester.tap(find.byKey(const Key('keypad_5')));
      await tester.pump();

      // Tap 0
      await tester.tap(find.byKey(const Key('keypad_0')));
      await tester.pump();

      expect(find.text('150'), findsOneWidget);
    });

    testWidgets('Tapping CONTINUE navigates to ArtistFlashUploadScreen (Screens 9-12)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ArtistSetPriceScreen(
            artistName: 'OddMaree',
            instagramHandle: '@OddMaree',
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('continue_price_button')));
      await tester.pumpAndSettle();

      expect(find.text('Showcase your\nwork'), findsOneWidget);
      expect(find.text('Upload some custom flash work you plan on selling'), findsOneWidget);
    });
  });

  group('ArtistFlashUploadScreen (Screens 9-12) Tests', () {
    testWidgets('Renders upload trigger box and SKIP button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ArtistFlashUploadScreen(
            artistName: 'OddMaree',
            instagramHandle: '@OddMaree',
            minDeposit: 100,
          ),
        ),
      );

      expect(find.text('Showcase your\nwork'), findsOneWidget);
      expect(find.byKey(const Key('upload_flash_trigger')), findsOneWidget);
      expect(find.text('High-resolution JPEG or PNG.\nMax 10MB.'), findsOneWidget);
      expect(find.byKey(const Key('skip_flash_button')), findsOneWidget);
    });

    testWidgets('Tapping SKIP navigates to ArtistIdentityTagsScreen (Screen 13)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ArtistFlashUploadScreen(
            artistName: 'OddMaree',
            instagramHandle: '@OddMaree',
            minDeposit: 100,
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('skip_flash_button')));
      await tester.pumpAndSettle();

      expect(find.text('Tell them who\nyou are'), findsOneWidget);
      expect(find.text('Help clients find a space where they feel welcome by tagging your identity, vibe, and accommodations'), findsOneWidget);
    });
  });

  group('ArtistIdentityTagsScreen (Screen 13) Tests', () {
    testWidgets('Renders categories and tag chips', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ArtistIdentityTagsScreen(
            artistName: 'OddMaree',
            instagramHandle: '@OddMaree',
            minDeposit: 100,
          ),
        ),
      );

      expect(find.text('Tell them who\nyou are'), findsOneWidget);
      expect(find.text('STYLE'), findsOneWidget);
      expect(find.text('COMMUNITY & IDENTITY'), findsOneWidget);
      expect(find.text('THE SPACE'), findsOneWidget);
      expect(find.text('INCLUSIVITY'), findsOneWidget);
      expect(find.text('ACCESSIBILITY'), findsOneWidget);
      expect(find.byKey(const Key('tag_Vegan Inks')), findsOneWidget);
      expect(find.byKey(const Key('tag_Queer-Owned')), findsOneWidget);
      expect(find.byKey(const Key('done_identity_button')), findsOneWidget);
    });

    testWidgets('Tapping DONE navigates to ArtistChooseStyleScreen (Screen 14)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ArtistIdentityTagsScreen(
            artistName: 'OddMaree',
            instagramHandle: '@OddMaree',
            minDeposit: 100,
          ),
        ),
      );

      await tester.ensureVisible(find.byKey(const Key('done_identity_button')));
      await tester.tap(find.byKey(const Key('done_identity_button')));
      await tester.pumpAndSettle();

      expect(find.text('Choose your\nstyle'), findsOneWidget);
      expect(find.text('Pick the styles you specialize in so clients searching for your specific aesthetic can easily find your profile and flash'), findsOneWidget);
    });
  });

  group('ArtistChooseStyleScreen (Screen 14) Tests', () {
    testWidgets('Renders style chips, add a style trigger, and buttons', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ArtistChooseStyleScreen(
            artistName: 'OddMaree',
            instagramHandle: '@OddMaree',
            minDeposit: 100,
          ),
        ),
      );

      expect(find.text('Choose your\nstyle'), findsOneWidget);
      expect(find.byKey(const Key('style_Traditional')), findsOneWidget);
      expect(find.byKey(const Key('style_Fine-line')), findsOneWidget);
      expect(find.byKey(const Key('add_custom_style_trigger')), findsOneWidget);
      expect(find.byKey(const Key('done_styles_button')), findsOneWidget);
      expect(find.byKey(const Key('skip_styles_button')), findsOneWidget);
    });

    testWidgets('Tapping DONE navigates to ArtistShareLinkScreen (Screen 15)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ArtistChooseStyleScreen(
            artistName: 'OddMaree',
            instagramHandle: '@OddMaree',
            minDeposit: 100,
          ),
        ),
      );

      await tester.ensureVisible(find.byKey(const Key('done_styles_button')));
      await tester.tap(find.byKey(const Key('done_styles_button')));
      await tester.pumpAndSettle();

      expect(find.text('Tell em where to\nfind you'), findsOneWidget);
      expect(find.byKey(const Key('qr_ticket_card')), findsOneWidget);
    });
  });

  group('ArtistShareLinkScreen (Screen 15) Tests', () {
    testWidgets('Renders QR ticket card, handle, stickers button, and DONE button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ArtistShareLinkScreen(
            artistName: 'OddMaree',
            instagramHandle: '@OddMaree',
          ),
        ),
      );

      expect(find.text('Tell em where to\nfind you'), findsOneWidget);
      expect(find.byKey(const Key('qr_ticket_card')), findsOneWidget);
      expect(find.text('@OddMaree'), findsOneWidget);
      expect(find.text('Want to go beyond digital?'), findsOneWidget);
      expect(find.byKey(const Key('create_sticker_button')), findsOneWidget);
      expect(find.byKey(const Key('done_share_button')), findsOneWidget);
    });
  });
}
