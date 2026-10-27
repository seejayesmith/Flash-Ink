import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:flash_ink/screens/email_auth_screen.dart';
import 'package:flash_ink/screens/email_verification_screen.dart';
import 'package:flash_ink/screens/phone_verification_screen.dart';
import 'package:flash_ink/screens/phone_entry_screen.dart';
import 'package:flash_ink/screens/role_selection_screen.dart';
import 'package:flash_ink/screens/account_creation_screen.dart';
import 'package:flash_ink/screens/artist_onboarding/artist_phone_verification_screen.dart';
import 'package:flash_ink/screens/artist_onboarding/artist_info_screen.dart';
import 'package:flash_ink/screens/artist_onboarding/artist_profile_photo_screen.dart';
import 'package:flash_ink/screens/profile_setup_screen.dart';
import 'package:flash_ink/widgets/skip_pill_button.dart';
import 'package:flash_ink/services/auth_service.dart';

class TestMockAuthService extends AuthService {
  @override
  Future<void> updatePhoneVerificationStatus({
    required String uid,
    required String phoneNumber,
  }) async {}

  @override
  Future<void> signOut() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await Firebase.initializeApp();
  });

  setUp(() {
    AuthService.devMockUser = null;
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.physicalSize = const Size(1080, 2400);
    binding.platformDispatcher.views.first.devicePixelRatio = 1.0;
  });

  tearDown(() {
    AuthService.devMockUser = null;
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.resetPhysicalSize();
    binding.platformDispatcher.views.first.resetDevicePixelRatio();
  });

  group('Top-Right Skip Button on Email Sign-Up and Verification Screens', () {
    testWidgets('EmailAuthScreen (client): Has SkipPillButton and skips to ProfileSetupScreen', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: EmailAuthScreen(
            role: 'client',
            authService: TestMockAuthService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SkipPillButton), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);

      await tester.tap(find.byType(SkipPillButton));
      await tester.pumpAndSettle();

      expect(find.byType(EmailAuthScreen), findsNothing);
      expect(find.byType(ProfileSetupScreen), findsOneWidget);
    });

    testWidgets('EmailAuthScreen (artist): Has SkipPillButton and skips to ArtistInfoScreen', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: EmailAuthScreen(
            role: 'artist',
            authService: TestMockAuthService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SkipPillButton), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);

      await tester.tap(find.byType(SkipPillButton));
      await tester.pumpAndSettle();

      expect(find.byType(EmailAuthScreen), findsNothing);
      expect(find.byType(ArtistInfoScreen), findsOneWidget);
    });

    testWidgets('EmailVerificationScreen (client): Has SkipPillButton and skips to ProfileSetupScreen', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: EmailVerificationScreen(
            role: 'client',
            authService: TestMockAuthService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SkipPillButton), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);

      await tester.tap(find.byType(SkipPillButton));
      await tester.pumpAndSettle();

      expect(find.byType(EmailVerificationScreen), findsNothing);
      expect(find.byType(ProfileSetupScreen), findsOneWidget);
    });

    testWidgets('EmailVerificationScreen (artist): Has SkipPillButton and skips to ArtistInfoScreen', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: EmailVerificationScreen(
            role: 'artist',
            authService: TestMockAuthService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SkipPillButton), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);

      await tester.tap(find.byType(SkipPillButton));
      await tester.pumpAndSettle();

      expect(find.byType(EmailVerificationScreen), findsNothing);
      expect(find.byType(ArtistInfoScreen), findsOneWidget);
    });

    testWidgets('PhoneVerificationScreen (client): Has SkipPillButton and skips to ProfileSetupScreen', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PhoneVerificationScreen(
            phoneNumber: '+15551234567',
            verificationId: 'vid_test',
            authService: TestMockAuthService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SkipPillButton), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);

      await tester.tap(find.byType(SkipPillButton));
      await tester.pumpAndSettle();

      expect(find.byType(PhoneVerificationScreen), findsNothing);
      expect(find.byType(ProfileSetupScreen), findsOneWidget);
    });

    testWidgets('ArtistPhoneVerificationScreen (artist): Has SkipPillButton and skips to ArtistProfilePhotoScreen', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ArtistPhoneVerificationScreen(
            phoneNumber: '+15551234567',
            verificationId: 'vid_test',
            artistName: 'OddMaree',
            artistEmail: 'ink@studio.com',
            authService: TestMockAuthService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SkipPillButton), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);

      await tester.tap(find.byType(SkipPillButton));
      await tester.pumpAndSettle();

      expect(find.byType(ArtistPhoneVerificationScreen), findsNothing);
      expect(find.byType(ArtistProfilePhotoScreen), findsOneWidget);
    });

    testWidgets('PhoneEntryScreen: Has SkipPillButton for client and artist', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PhoneEntryScreen(
            role: 'client',
            authService: TestMockAuthService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SkipPillButton), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);

      await tester.tap(find.byType(SkipPillButton));
      await tester.pumpAndSettle();

      expect(find.byType(PhoneEntryScreen), findsNothing);
      expect(find.byType(ProfileSetupScreen), findsOneWidget);
    });

    testWidgets('RoleSelectionScreen: Does not have SkipPillButton and requires role selection', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RoleSelectionScreen(
            authService: TestMockAuthService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('skip_role_selection_button')), findsNothing);
      expect(find.byType(SkipPillButton), findsNothing);
      expect(find.text('Skip'), findsNothing);
    });

    testWidgets('AccountCreationScreen (client): Has SkipPillButton and skips to ProfileSetupScreen', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AccountCreationScreen(
            role: 'client',
            authService: TestMockAuthService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('skip_account_creation_button')), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);

      await tester.tap(find.byKey(const Key('skip_account_creation_button')));
      await tester.pumpAndSettle();

      expect(find.byType(AccountCreationScreen), findsNothing);
      expect(find.byType(ProfileSetupScreen), findsOneWidget);
    });

    testWidgets('AccountCreationScreen (artist): Has SkipPillButton and skips to ArtistInfoScreen', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AccountCreationScreen(
            role: 'artist',
            authService: TestMockAuthService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('skip_account_creation_button')), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);

      await tester.tap(find.byKey(const Key('skip_account_creation_button')));
      await tester.pumpAndSettle();

      expect(find.byType(AccountCreationScreen), findsNothing);
      expect(find.byType(ArtistInfoScreen), findsOneWidget);
    });

    testWidgets('ArtistInfoScreen: Has SkipPillButton and skips to ArtistProfilePhotoScreen', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ArtistInfoScreen(
            authService: TestMockAuthService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('skip_artist_info_button')), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);

      await tester.tap(find.byKey(const Key('skip_artist_info_button')));
      await tester.pumpAndSettle();

      expect(find.byType(ArtistInfoScreen), findsNothing);
      expect(find.byType(ArtistProfilePhotoScreen), findsOneWidget);
    });
  });
}
