import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';

import 'package:flash_ink/screens/artist_onboarding/artist_info_screen.dart';
import 'package:flash_ink/screens/artist_onboarding/artist_phone_verification_screen.dart';
import 'package:flash_ink/screens/artist_onboarding/artist_profile_photo_screen.dart';
import 'package:flash_ink/screens/artist_onboarding/artist_set_price_screen.dart';
import 'package:flash_ink/screens/artist_onboarding/artist_flash_upload_screen.dart';
import 'package:flash_ink/screens/artist_onboarding/artist_identity_tags_screen.dart';
import 'package:flash_ink/screens/artist_onboarding/artist_choose_style_screen.dart';
import 'package:flash_ink/screens/artist_onboarding/artist_share_link_screen.dart';
import 'package:flash_ink/screens/client_aesthetics_screen.dart';
import 'package:flash_ink/screens/client_edit_profile_screen.dart';
import 'package:flash_ink/screens/app_info_screen.dart';
import 'package:flash_ink/screens/artist_dashboard/artist_account_settings_screen.dart';
import 'package:flash_ink/screens/artist_dashboard/artist_edit_profile_screen.dart';
import 'package:flash_ink/screens/profile_setup_screen.dart';
import 'package:flash_ink/screens/phone_entry_screen.dart';
import 'package:flash_ink/widgets/flash_glass_app_bar.dart';
import 'package:flash_ink/services/auth_service.dart';

class MockArtistUser extends Fake implements User {
  @override
  final String uid = 'test_artist_uid';
  @override
  final String? email = 'artist@test.com';
  @override
  final String? displayName = 'OddMaree';
}

class FakeAuthService extends AuthService {
  final MockArtistUser _user = MockArtistUser();

  @override
  User? get currentUser => _user;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  group('Transparent Top Bar & AppBar Tests', () {
    testWidgets('ArtistInfoScreen has extendBodyBehindAppBar true and transparent AppBar', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ArtistInfoScreen(authService: FakeAuthService()),
        ),
      );
      await tester.pumpAndSettle();

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.extendBodyBehindAppBar, isTrue);

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.backgroundColor, equals(Colors.transparent));
      expect(appBar.elevation, equals(0));
    });

    testWidgets('ArtistPhoneVerificationScreen has extendBodyBehindAppBar true and transparent AppBar', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ArtistPhoneVerificationScreen(
            phoneNumber: '+15550000000',
            verificationId: 'test_vid',
            artistName: 'OddMaree',
            artistEmail: 'artist@test.com',
            authService: FakeAuthService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.extendBodyBehindAppBar, isTrue);

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.backgroundColor, equals(Colors.transparent));
    });

    testWidgets('ArtistProfilePhotoScreen has extendBodyBehindAppBar true and transparent AppBar', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ArtistProfilePhotoScreen(
            artistName: 'OddMaree',
            authService: FakeAuthService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.extendBodyBehindAppBar, isTrue);

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.backgroundColor, equals(Colors.transparent));
    });

    testWidgets('ArtistSetPriceScreen has extendBodyBehindAppBar true and transparent AppBar', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ArtistSetPriceScreen(
            artistName: 'OddMaree',
            instagramHandle: 'oddmaree',
            authService: FakeAuthService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.extendBodyBehindAppBar, isTrue);

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.backgroundColor, equals(Colors.transparent));
    });

    testWidgets('ArtistFlashUploadScreen has extendBodyBehindAppBar true and transparent AppBar', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ArtistFlashUploadScreen(
            artistName: 'OddMaree',
            instagramHandle: 'oddmaree',
            minDeposit: 100,
            authService: FakeAuthService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.extendBodyBehindAppBar, isTrue);

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.backgroundColor, equals(Colors.transparent));
    });

    testWidgets('ArtistIdentityTagsScreen has extendBodyBehindAppBar true and transparent AppBar', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ArtistIdentityTagsScreen(
            artistName: 'OddMaree',
            instagramHandle: 'oddmaree',
            minDeposit: 100,
            authService: FakeAuthService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.extendBodyBehindAppBar, isTrue);

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.backgroundColor, equals(Colors.transparent));
    });

    testWidgets('ArtistChooseStyleScreen has extendBodyBehindAppBar true and transparent AppBar', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ArtistChooseStyleScreen(
            artistName: 'OddMaree',
            instagramHandle: 'oddmaree',
            minDeposit: 100,
            authService: FakeAuthService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.extendBodyBehindAppBar, isTrue);

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.backgroundColor, equals(Colors.transparent));
    });

    testWidgets('ArtistShareLinkScreen has extendBodyBehindAppBar true and transparent AppBar', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ArtistShareLinkScreen(
            artistName: 'OddMaree',
            authService: FakeAuthService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.extendBodyBehindAppBar, isTrue);

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.backgroundColor, equals(Colors.transparent));
    });

    testWidgets('Secondary screens have transparent AppBar', (tester) async {
      // ClientAestheticsScreen
      await tester.pumpWidget(
        const MaterialApp(home: ClientAestheticsScreen(initialAesthetics: [])),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<AppBar>(find.byType(AppBar)).backgroundColor, equals(Colors.transparent));

      // ClientEditProfileScreen
      await tester.pumpWidget(
        const MaterialApp(home: ClientEditProfileScreen(initialDisplayName: 'OddMaree', initialUsername: 'oddmaree')),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<AppBar>(find.byType(AppBar)).backgroundColor, equals(Colors.transparent));

      // AppInfoScreen
      await tester.pumpWidget(
        const MaterialApp(home: AppInfoScreen(title: 'Test', content: 'Test info')),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<AppBar>(find.byType(AppBar)).backgroundColor, equals(Colors.transparent));

      // ArtistAccountSettingsScreen
      await tester.pumpWidget(
        const MaterialApp(home: ArtistAccountSettingsScreen(email: 'artist@test.com')),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<AppBar>(find.byType(AppBar)).backgroundColor, equals(Colors.transparent));

      // ArtistEditProfileScreen
      await tester.pumpWidget(
        const MaterialApp(
          home: ArtistEditProfileScreen(
            initialDisplayName: 'OddMaree',
            initialUsername: 'oddmaree',
            initialBio: 'Tattoo Artist',
            initialLocation: 'Brooklyn, NY',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<AppBar>(find.byType(AppBar)).backgroundColor, equals(Colors.transparent));
    });

    testWidgets('ProfileSetupScreen has extendBodyBehindAppBar true and FlashGlassAppBar', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ProfileSetupScreen(authService: FakeAuthService()),
        ),
      );
      await tester.pumpAndSettle();

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.extendBodyBehindAppBar, isTrue);

      expect(find.byType(FlashGlassAppBar), findsOneWidget);
      expect(tester.widget<AppBar>(find.byType(AppBar)).backgroundColor, equals(Colors.transparent));
    });

    testWidgets('PhoneEntryScreen has extendBodyBehindAppBar true, transparent AppBar, and edge-to-edge background', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PhoneEntryScreen(
            role: 'client',
            authService: FakeAuthService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.extendBodyBehindAppBar, isTrue);
      expect(scaffold.resizeToAvoidBottomInset, isFalse);

      expect(find.byType(FlashGlassAppBar), findsOneWidget);
      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.backgroundColor, equals(Colors.transparent));

      // Verify the background texture image is loaded edge-to-edge
      expect(find.byType(Image), findsOneWidget);
      expect(find.byType(TextFormField), findsOneWidget);
    });
  });
}
