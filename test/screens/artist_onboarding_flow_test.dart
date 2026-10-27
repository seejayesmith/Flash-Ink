import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';

import 'package:flash_ink/widgets/artist_stepper_header.dart';
import 'package:flash_ink/features/onboarding/shared/onboarding_step_scaffold.dart';
import 'package:flash_ink/widgets/tattoo_background_wrapper.dart';
import 'package:flash_ink/widgets/adaptive_glass_container.dart';
import 'package:flash_ink/widgets/skip_pill_button.dart';
import 'package:flash_ink/screens/account_creation_screen.dart';
import 'package:flash_ink/screens/artist_onboarding/artist_info_screen.dart';
import 'package:flash_ink/screens/artist_onboarding/artist_phone_verification_screen.dart';
import 'package:flash_ink/screens/artist_onboarding/artist_profile_photo_screen.dart';
import 'package:flash_ink/screens/artist_onboarding/artist_studio_bio_screen.dart';
import 'package:flash_ink/screens/artist_onboarding/artist_policies_screen.dart';
import 'package:flash_ink/screens/artist_onboarding/artist_set_price_screen.dart';
import 'package:flash_ink/screens/artist_onboarding/artist_flash_upload_screen.dart';
import 'package:flash_ink/screens/artist_onboarding/artist_identity_tags_screen.dart';
import 'package:flash_ink/screens/artist_onboarding/artist_choose_style_screen.dart';
import 'package:flash_ink/screens/artist_onboarding/artist_share_link_screen.dart';
import 'package:flash_ink/screens/artist_dashboard/artist_dashboard_screen.dart';
import 'package:flash_ink/widgets/social_auth_buttons.dart';
import 'package:flash_ink/services/auth_service.dart';

class MockUser extends Fake implements User {
  @override
  final String uid;
  @override
  final String? email;
  @override
  final String? displayName;
  @override
  final String? phoneNumber;

  MockUser({required this.uid, this.email, this.displayName, this.phoneNumber});

  @override
  Future<void> updateDisplayName(String? name) async {}

  @override
  Future<void> updatePhotoURL(String? photoUri) async {}

  @override
  Future<String> getIdToken([bool forceRefresh = false]) async => 'mock_token';
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
  Future<UserCredential> signUpWithEmailAndPassword(String email, String password, {String? role}) async {
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

      expect(find.text('Account'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('Share'), findsOneWidget);
    });

    testWidgets('Current step 1 shows step 1 active and steps 2 & 3 inactive', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ArtistStepperHeader(currentStep: 1),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final size1 = tester.getSize(find.byKey(const Key('artist_step_indicator_1')));
      final size2 = tester.getSize(find.byKey(const Key('artist_step_indicator_2')));
      final size3 = tester.getSize(find.byKey(const Key('artist_step_indicator_3')));

      expect(size1.width, 24.0);
      expect(size2.width, 12.0);
      expect(size3.width, 12.0);

      final c1 = tester.widget<AnimatedContainer>(find.byKey(const Key('artist_step_indicator_1')));
      final c2 = tester.widget<AnimatedContainer>(find.byKey(const Key('artist_step_indicator_2')));
      final c3 = tester.widget<AnimatedContainer>(find.byKey(const Key('artist_step_indicator_3')));

      expect((c1.decoration as BoxDecoration).color, const Color(0xFFEEC200));
      expect((c2.decoration as BoxDecoration).color, const Color(0xFF333737));
      expect((c3.decoration as BoxDecoration).color, const Color(0xFF333737));
    });

    testWidgets('Current step 2 shows step 1 completed and step 2 active', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ArtistStepperHeader(currentStep: 2),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final size1 = tester.getSize(find.byKey(const Key('artist_step_indicator_1')));
      final size2 = tester.getSize(find.byKey(const Key('artist_step_indicator_2')));
      final size3 = tester.getSize(find.byKey(const Key('artist_step_indicator_3')));

      expect(size1.width, 12.0);
      expect(size2.width, 24.0);
      expect(size3.width, 12.0);

      final c1 = tester.widget<AnimatedContainer>(find.byKey(const Key('artist_step_indicator_1')));
      final c2 = tester.widget<AnimatedContainer>(find.byKey(const Key('artist_step_indicator_2')));
      final c3 = tester.widget<AnimatedContainer>(find.byKey(const Key('artist_step_indicator_3')));

      expect((c1.decoration as BoxDecoration).color, const Color(0xFFEEC200));
      expect((c2.decoration as BoxDecoration).color, const Color(0xFFEEC200));
      expect((c3.decoration as BoxDecoration).color, const Color(0xFF333737));
    });

    testWidgets('Current step 3 shows steps 1 and 2 completed and step 3 active', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ArtistStepperHeader(currentStep: 3),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final size1 = tester.getSize(find.byKey(const Key('artist_step_indicator_1')));
      final size2 = tester.getSize(find.byKey(const Key('artist_step_indicator_2')));
      final size3 = tester.getSize(find.byKey(const Key('artist_step_indicator_3')));

      expect(size1.width, 12.0);
      expect(size2.width, 12.0);
      expect(size3.width, 24.0);

      final c1 = tester.widget<AnimatedContainer>(find.byKey(const Key('artist_step_indicator_1')));
      final c2 = tester.widget<AnimatedContainer>(find.byKey(const Key('artist_step_indicator_2')));
      final c3 = tester.widget<AnimatedContainer>(find.byKey(const Key('artist_step_indicator_3')));

      expect((c1.decoration as BoxDecoration).color, const Color(0xFFEEC200));
      expect((c2.decoration as BoxDecoration).color, const Color(0xFFEEC200));
      expect((c3.decoration as BoxDecoration).color, const Color(0xFFEEC200));
    });
  });

  group('Artist Auth & Information Screen Tests', () {
    testWidgets('AccountCreationScreen for artist mirrors client UI and hides guest option', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AccountCreationScreen(
            role: 'artist',
            authService: FakeArtistAuthService(),
          ),
        ),
      );

      // Verify unified input, primary CTA, and social auth buttons are present
      expect(find.byKey(const Key('unified_auth_input_field')), findsOneWidget);
      expect(find.byKey(const Key('unified_auth_continue_button')), findsOneWidget);
      expect(find.byType(CircularGoogleSignInButton), findsOneWidget);
      expect(find.byType(CircularAppleSignInButton), findsOneWidget);
      expect(find.byKey(const Key('google_sign_in_button')), findsOneWidget);
      expect(find.byKey(const Key('apple_sign_in_button')), findsOneWidget);

      // Verify artist-specific copy
      expect(find.text('Create an account to showcase your flash designs, manage bookings, and grow your studio.'), findsOneWidget);

      // Verify Guest Mode is NOT present for artist
      expect(find.text('Continue as Guest'), findsNothing);
    });

    testWidgets('ArtistInfoScreen renders progress bar, fields, and dev skip banner', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ArtistInfoScreen(authService: FakeArtistAuthService()),
        ),
      );

      expect(find.byType(SegmentedProgressPills), findsOneWidget);
      expect(find.byType(ArtistStepperHeader), findsNothing);
      expect(find.text('Artist Profile'), findsOneWidget);
      expect(find.text('Enter your artist name and contact number to get set up.'), findsOneWidget);
      expect(find.text('Name or Artist Handle'), findsOneWidget);
      expect(find.text('Phone Number'), findsOneWidget);
      expect(find.text('I agree to the Terms of Service and Privacy Policy.'), findsOneWidget);
      expect(find.text('CONTINUE'), findsOneWidget);
      expect(find.byType(TattooBackgroundWrapper), findsOneWidget);
      expect(find.byType(AdaptiveGlassContainer), findsWidgets);
    });

    testWidgets('ArtistInfoScreen displays placeholder copy @yourhandle', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ArtistInfoScreen(
            authService: FakeArtistAuthService(),
            initialName: '',
          ),
        ),
      );

      final textField = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const Key('artist_name_handle_field')),
          matching: find.byType(TextField),
        ),
      );
      expect(textField.decoration?.hintText, '@yourhandle');
      expect(find.text('@yourhandle'), findsOneWidget);
    });

    testWidgets('ArtistInfoScreen form validation blocks submit when empty', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ArtistInfoScreen(
            authService: FakeArtistAuthService(),
            initialName: '',
          ),
        ),
      );

      // Clear the text field to ensure it is empty
      await tester.enterText(find.byType(TextFormField).first, '');
      await tester.pump();

      // Tap CONTINUE without filling fields
      await tester.tap(find.text('CONTINUE'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter your name or artist handle'), findsOneWidget);
      expect(find.text('Please enter your phone number for SMS verification'), findsOneWidget);
    });

    testWidgets('ArtistInfoScreen renders top-right Skip button and navigates to ArtistProfilePhotoScreen', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ArtistInfoScreen(authService: FakeArtistAuthService()),
        ),
      );

      expect(find.byType(SkipPillButton), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);

      await tester.tap(find.byType(SkipPillButton));
      await tester.pumpAndSettle();

      expect(find.byType(ArtistProfilePhotoScreen), findsOneWidget);
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
      expect(find.text('Skip'), findsOneWidget);
    });

    testWidgets('Tapping Skip bypasses verification and navigates to photo screen', (tester) async {
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

      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(find.text('Add a profile photo'), findsOneWidget);
    });
  });

  group('ArtistProfilePhotoScreen Tests', () {
    testWidgets('Renders Upload Photo state with wireframe buttons and copy', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ArtistProfilePhotoScreen(
            artistName: 'OddMaree',
            authService: FakeArtistAuthService(),
          ),
        ),
      );

      expect(find.text('Add a profile photo'), findsOneWidget);
      expect(find.text('Show the community who you are!\nYou can always change this later.'), findsOneWidget);
      expect(find.text('Upload a Photo'), findsNothing);
      expect(find.text('Take a Picture'), findsNothing);
      expect(find.text('Skip for now'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
    });

    testWidgets('Renders preview state with active Continue button when photo is present', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ArtistProfilePhotoScreen(
            artistName: 'OddMaree',
            initialImageBytes: samplePngBytes,
            authService: FakeArtistAuthService(),
          ),
        ),
      );

      expect(find.text('Add a profile photo'), findsOneWidget);
      expect(find.text('Upload a Photo'), findsNothing);
      expect(find.text('Change Photo'), findsNothing);
      expect(find.text('Take a Picture'), findsNothing);
      expect(find.text('Skip for now'), findsNothing);
      expect(find.text('Continue'), findsOneWidget);
    });

    testWidgets('Tapping CONTINUE navigates to ArtistStudioBioScreen', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ArtistProfilePhotoScreen(
            artistName: 'OddMaree',
            initialImageBytes: samplePngBytes,
            authService: FakeArtistAuthService(),
          ),
        ),
      );

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Where do you tattoo?'), findsOneWidget);
    });

    testWidgets('Tapping Skip bypasses photo upload and navigates to ArtistStudioBioScreen', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ArtistProfilePhotoScreen(
            artistName: 'OddMaree',
            authService: FakeArtistAuthService(),
          ),
        ),
      );

      expect(find.text('Skip'), findsOneWidget);
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(find.text('Where do you tattoo?'), findsOneWidget);
    });
  });

  group('ArtistSetPriceScreen (Screens 7 & 8) Tests', () {
    testWidgets('Renders price card, faded placeholder, and skip/continue buttons', (tester) async {
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
      expect(find.byKey(const Key('price_text_field')), findsOneWidget);
      expect(find.text('100'), findsOneWidget);
      expect(find.text('CONTINUE'), findsOneWidget);
      expect(find.byKey(const Key('skip_price_button')), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
    });

    testWidgets('Tapping Skip navigates to ArtistFlashUploadScreen (Screens 9-12)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ArtistSetPriceScreen(
            artistName: 'OddMaree',
            instagramHandle: '@OddMaree',
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('skip_price_button')));
      await tester.pumpAndSettle();

      expect(find.text('Showcase your\nwork'), findsOneWidget);
    });

    testWidgets('Tapping price card requests focus, text entry updates price and clearing restores placeholder', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ArtistSetPriceScreen(
            artistName: 'OddMaree',
            instagramHandle: '@OddMaree',
          ),
        ),
      );

      // Initially field is not focused and shows placeholder '100'
      final textFieldFinder = find.byKey(const Key('price_text_field'));
      final textField = tester.widget<TextField>(textFieldFinder);
      expect(textField.focusNode?.hasFocus ?? false, isFalse);
      expect(find.text('100'), findsOneWidget);

      // Tap card to request focus
      await tester.tap(find.byKey(const Key('price_display_card')));
      await tester.pump();
      expect(textField.focusNode?.hasFocus ?? false, isTrue);

      // Enter amount
      await tester.enterText(textFieldFinder, '150');
      await tester.pump();

      expect(find.byWidgetPredicate((w) => w is Text && w.data == '150'), findsOneWidget);

      // Clear amount to restore placeholder
      await tester.enterText(textFieldFinder, '');
      await tester.pump();

      expect(find.text('100'), findsOneWidget);
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

    testWidgets('Does not require four pieces of flash artwork', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ArtistFlashUploadScreen(
            artistName: 'OddMaree',
            instagramHandle: '@OddMaree',
            minDeposit: 100,
          ),
        ),
      );

      expect(find.byKey(const Key('four_pieces_notice')), findsNothing);
      expect(find.text('4 Pieces Required'), findsNothing);
    });

    testWidgets('Uploading flash artwork proceeds on DONE without requiring 4 items', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ArtistFlashUploadScreen(
            artistName: 'OddMaree',
            instagramHandle: '@OddMaree',
            minDeposit: 100,
          ),
        ),
      );

      // Open upload bottom sheet
      await tester.tap(find.byKey(const Key('upload_flash_trigger')));
      await tester.pumpAndSettle();

      // Tap sample flash
      await tester.tap(find.text('Use Sample Flash: Traditional Panther'));
      await tester.pumpAndSettle();

      // Details editor is now open
      expect(find.text('Upload Flash: Item Details'), findsOneWidget);
      expect(find.byKey(const Key('four_pieces_notice')), findsNothing);

      // Save item
      await tester.tap(find.byKey(const Key('done_details_button')));
      await tester.pumpAndSettle();

      // Back to main view: 1 item uploaded
      expect(find.text('UPLOADED FLASH (1)'), findsOneWidget);
      expect(find.byKey(const Key('done_flash_button')), findsOneWidget);

      // Tapping DONE with 1 piece proceeds directly without requiring 4 items
      await tester.tap(find.byKey(const Key('done_flash_button')));
      await tester.pumpAndSettle();

      expect(find.text('Tell them who\nyou are'), findsOneWidget);
      expect(
        find.text('Notice: You must include four pieces of flash artwork to complete your showcase (1 of 4 added).'),
        findsNothing,
      );
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
      expect(find.byKey(const Key('skip_share_link_button')), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
    });

    testWidgets('Tapping Skip on ArtistShareLinkScreen navigates to ArtistDashboardScreen', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ArtistShareLinkScreen(
            artistName: 'OddMaree',
            instagramHandle: '@OddMaree',
            authService: FakeArtistAuthService(),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('skip_share_link_button')));
      await tester.pump(const Duration(seconds: 9));
      await tester.pumpAndSettle();

      expect(find.byType(ArtistDashboardScreen), findsOneWidget);
    });
  });

  group('Artist Onboarding Progress Bar Matching Client Side Suite', () {
    testWidgets('All artist onboarding screens render top SegmentedProgressPills and no ArtistStepperHeader', (tester) async {
      final fakeAuth = FakeArtistAuthService();

      // Step 1: Info Screen
      await tester.pumpWidget(MaterialApp(home: ArtistInfoScreen(authService: fakeAuth)));
      await tester.pumpAndSettle();
      expect(find.byType(SegmentedProgressPills), findsOneWidget);
      expect(find.byType(ArtistStepperHeader), findsNothing);
      var pills = tester.widget<SegmentedProgressPills>(find.byType(SegmentedProgressPills));
      expect(pills.currentStep, equals(1));
      expect(pills.totalSteps, equals(9));

      // Step 1 (phone sub-step): Phone Verification Screen
      await tester.pumpWidget(MaterialApp(
        home: ArtistPhoneVerificationScreen(
          phoneNumber: '+15551234567',
          verificationId: 'vid',
          artistName: 'OddMaree',
          artistEmail: 'test@flash.ink',
          authService: fakeAuth,
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(SegmentedProgressPills), findsOneWidget);
      expect(find.byType(ArtistStepperHeader), findsNothing);
      pills = tester.widget<SegmentedProgressPills>(find.byType(SegmentedProgressPills));
      expect(pills.currentStep, equals(1));
      expect(pills.totalSteps, equals(9));

      // Step 2: Profile Photo Screen
      await tester.pumpWidget(MaterialApp(
        home: ArtistProfilePhotoScreen(
          artistName: 'OddMaree',
          authService: fakeAuth,
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(SegmentedProgressPills), findsOneWidget);
      expect(find.byType(ArtistStepperHeader), findsNothing);
      pills = tester.widget<SegmentedProgressPills>(find.byType(SegmentedProgressPills));
      expect(pills.currentStep, equals(2));
      expect(pills.totalSteps, equals(9));

      // Step 3: Studio & Bio Screen
      await tester.pumpWidget(MaterialApp(
        home: ArtistStudioBioScreen(
          artistName: 'OddMaree',
          authService: fakeAuth,
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(SegmentedProgressPills), findsOneWidget);
      expect(find.byType(ArtistStepperHeader), findsNothing);
      pills = tester.widget<SegmentedProgressPills>(find.byType(SegmentedProgressPills));
      expect(pills.currentStep, equals(3));
      expect(pills.totalSteps, equals(9));

      // Step 4: Policies Screen
      await tester.pumpWidget(MaterialApp(
        home: ArtistPoliciesScreen(
          artistName: 'OddMaree',
          authService: fakeAuth,
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(SegmentedProgressPills), findsOneWidget);
      expect(find.byType(ArtistStepperHeader), findsNothing);
      pills = tester.widget<SegmentedProgressPills>(find.byType(SegmentedProgressPills));
      expect(pills.currentStep, equals(4));
      expect(pills.totalSteps, equals(9));

      // Step 5: Set Price Screen
      await tester.pumpWidget(MaterialApp(
        home: ArtistSetPriceScreen(
          artistName: 'OddMaree',
          authService: fakeAuth,
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(SegmentedProgressPills), findsOneWidget);
      expect(find.byType(ArtistStepperHeader), findsNothing);
      pills = tester.widget<SegmentedProgressPills>(find.byType(SegmentedProgressPills));
      expect(pills.currentStep, equals(5));
      expect(pills.totalSteps, equals(9));

      // Step 6: Flash Upload Screen
      await tester.pumpWidget(MaterialApp(
        home: ArtistFlashUploadScreen(
          artistName: 'OddMaree',
          instagramHandle: '@OddMaree',
          minDeposit: 100,
          authService: fakeAuth,
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(SegmentedProgressPills), findsOneWidget);
      expect(find.byType(ArtistStepperHeader), findsNothing);
      pills = tester.widget<SegmentedProgressPills>(find.byType(SegmentedProgressPills));
      expect(pills.currentStep, equals(6));
      expect(pills.totalSteps, equals(9));

      // Step 7: Identity Tags Screen
      await tester.pumpWidget(MaterialApp(
        home: ArtistIdentityTagsScreen(
          artistName: 'OddMaree',
          instagramHandle: '@OddMaree',
          minDeposit: 100,
          authService: fakeAuth,
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(SegmentedProgressPills), findsOneWidget);
      expect(find.byType(ArtistStepperHeader), findsNothing);
      pills = tester.widget<SegmentedProgressPills>(find.byType(SegmentedProgressPills));
      expect(pills.currentStep, equals(7));
      expect(pills.totalSteps, equals(9));

      // Step 8: Choose Style Screen
      await tester.pumpWidget(MaterialApp(
        home: ArtistChooseStyleScreen(
          artistName: 'OddMaree',
          instagramHandle: '@OddMaree',
          minDeposit: 100,
          authService: fakeAuth,
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(SegmentedProgressPills), findsOneWidget);
      expect(find.byType(ArtistStepperHeader), findsNothing);
      pills = tester.widget<SegmentedProgressPills>(find.byType(SegmentedProgressPills));
      expect(pills.currentStep, equals(8));
      expect(pills.totalSteps, equals(9));

      // Step 9: Share Link Screen
      await tester.pumpWidget(MaterialApp(
        home: ArtistShareLinkScreen(
          artistName: 'OddMaree',
          authService: fakeAuth,
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(SegmentedProgressPills), findsOneWidget);
      expect(find.byType(ArtistStepperHeader), findsNothing);
      pills = tester.widget<SegmentedProgressPills>(find.byType(SegmentedProgressPills));
      expect(pills.currentStep, equals(9));
      expect(pills.totalSteps, equals(9));
    });
  });
}
