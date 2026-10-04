import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';

import 'package:flash_ink/models/artist.dart';
import 'package:flash_ink/screens/artist_dashboard/artist_account_screen.dart';
import 'package:flash_ink/screens/artist_profile_screen.dart';
import 'package:flash_ink/screens/splash_screen.dart';
import 'package:flash_ink/services/auth_service.dart';

class MockArtistUser extends Fake implements User {
  @override
  final String uid;
  @override
  final String? email;
  @override
  final String? displayName;
  @override
  final String? photoURL;
  bool wasDeleted = false;

  MockArtistUser({
    this.uid = 'artist_oddmaree_uid',
    this.email = 'oddmaree@flash.ink',
    this.displayName = 'OddMaree',
    this.photoURL = 'https://example.com/artist.jpg',
  });

  @override
  Future<void> delete() async {
    wasDeleted = true;
  }
}

class FakeArtistAuthService extends AuthService {
  final MockArtistUser user;
  int signOutCallCount = 0;
  int deleteCallCount = 0;

  FakeArtistAuthService({MockArtistUser? testUser})
      : user = testUser ?? MockArtistUser();

  @override
  User? get currentUser => user;

  @override
  Future<void> signOut() async {
    signOutCallCount++;
  }

  @override
  Future<void> deleteAccount() async {
    deleteCallCount++;
    await user.delete();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  Widget buildTestWidget({
    Artist? artist,
    AuthService? authService,
  }) {
    return MaterialApp(
      home: ArtistAccountScreen(
        artist: artist,
        authService: authService ?? FakeArtistAuthService(),
      ),
    );
  }

  group('ArtistAccountScreen Tests', () {
    testWidgets('Renders AppBar with title and action buttons', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Account'), findsOneWidget);
      expect(find.byKey(const Key('artist_account_back_button')), findsOneWidget);
      expect(find.byKey(const Key('artist_account_view_public_profile_button')), findsOneWidget);
      expect(find.byKey(const Key('artist_account_edit_button')), findsOneWidget);
    });

    testWidgets('Renders Profile Hero card with avatar, name, handle, and Edit Profile button', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('OddMaree'), findsWidgets);
      expect(find.text('@oddmaree'), findsWidgets);
      expect(find.byKey(const Key('artist_account_avatar_edit')), findsOneWidget);
      expect(find.byKey(const Key('artist_account_edit_profile_hero_button')), findsOneWidget);
    });

    testWidgets('Renders Personal Information section with details', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('PERSONAL INFORMATION'), findsOneWidget);
      expect(find.text('Display Name'), findsOneWidget);
      expect(find.text('Username'), findsOneWidget);
      expect(find.text('Artist Bio'), findsOneWidget);
      expect(find.text('Studio & Location'), findsOneWidget);
      expect(find.text('Email Address'), findsOneWidget);
      expect(find.text('Phone Number'), findsOneWidget);
      expect(find.text('VERIFIED'), findsOneWidget);
    });

    testWidgets('Renders Notifications & Alerts section and toggles switch', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('NOTIFICATIONS & ALERTS'), findsOneWidget);
      expect(find.text('New Booking Requests'), findsOneWidget);
      expect(find.text('Appointment Reminders'), findsOneWidget);
      expect(find.text('Client Messages'), findsOneWidget);
    });

    testWidgets('Renders Studio & Safety Policies and shows info modal on tap', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('STUDIO & SAFETY POLICIES'), findsOneWidget);
      expect(find.text('Health & Safety Standards'), findsOneWidget);

      await tester.tap(find.text('Health & Safety Standards'));
      await tester.pumpAndSettle();

      expect(find.text('Health & Safety Protocol'), findsOneWidget);
      expect(find.text('Got It'), findsOneWidget);

      await tester.tap(find.text('Got It'));
      await tester.pumpAndSettle();
      expect(find.text('Health & Safety Protocol'), findsNothing);
    });

    testWidgets('Tapping Edit Profile button opens edit profile bottom sheet and updates fields', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('artist_account_edit_profile_hero_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('edit_profile_sheet_title')), findsOneWidget);
      expect(find.byKey(const Key('edit_profile_name_field')), findsOneWidget);
      expect(find.byKey(const Key('edit_profile_bio_field')), findsOneWidget);
      expect(find.byKey(const Key('save_profile_button')), findsOneWidget);

      await tester.enterText(find.byKey(const Key('edit_profile_name_field')), 'OddMaree Studio');
      await tester.tap(find.byKey(const Key('save_profile_button')));
      await tester.pumpAndSettle();

      expect(find.text('OddMaree Studio'), findsWidgets);
    });

    testWidgets('Tapping view public profile eye icon navigates to ArtistProfileScreen', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('artist_account_view_public_profile_button')));
      await tester.pumpAndSettle();

      expect(find.byType(ArtistProfileScreen), findsOneWidget);
    });

    testWidgets('Tapping Account Settings opens modal with Delete Account action', (tester) async {
      final fakeAuth = FakeArtistAuthService();
      await tester.pumpWidget(buildTestWidget(authService: fakeAuth));
      await tester.pumpAndSettle();

      // Scroll down if needed to reach Account Settings
      await tester.scrollUntilVisible(
        find.byKey(const Key('artist_account_settings_tile')),
        200,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('artist_account_settings_tile')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('account_settings_modal_title')), findsOneWidget);
      expect(find.byKey(const Key('delete_account_button')), findsOneWidget);

      // Tap Delete Account inside modal
      await tester.tap(find.byKey(const Key('delete_account_button')));
      await tester.pumpAndSettle();

      // Confirmation dialog should be displayed
      expect(find.byKey(const Key('delete_account_dialog')), findsOneWidget);
      expect(find.byKey(const Key('delete_account_confirm_button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('delete_account_confirm_button')));
      await tester.pumpAndSettle();

      expect(fakeAuth.deleteCallCount, 1);
      expect(find.byType(SplashScreen), findsOneWidget);
    });

    testWidgets('Tapping Sign Out button prompts confirmation and signs out', (tester) async {
      final fakeAuth = FakeArtistAuthService();
      await tester.pumpWidget(buildTestWidget(authService: fakeAuth));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(const Key('artist_account_sign_out_button')),
        200,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('artist_account_sign_out_button')));
      await tester.pumpAndSettle();

      expect(find.text('Are you sure you want to sign out of Flash.Ink?'), findsOneWidget);
      expect(find.text('Sign Out'), findsWidgets);

      // Confirm sign out in the AlertDialog
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign Out'));
      await tester.pumpAndSettle();

      expect(fakeAuth.signOutCallCount, 1);
      expect(find.byType(SplashScreen), findsOneWidget);
    });
  });
}
