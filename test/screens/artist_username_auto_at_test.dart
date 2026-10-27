import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:flash_ink/screens/artist_onboarding/artist_info_screen.dart';
import 'package:flash_ink/screens/artist_onboarding/artist_profile_photo_screen.dart';
import 'package:flash_ink/screens/artist_dashboard/artist_edit_profile_screen.dart';
import 'package:flash_ink/services/auth_service.dart';
import 'package:flash_ink/theme/app_theme.dart';

class MockArtistUser extends Fake implements User {
  @override
  final String uid;
  @override
  final String? email;
  @override
  final String? displayName;
  @override
  final String? phoneNumber;

  MockArtistUser({
    this.uid = 'artist_test_uid',
    this.email = 'artist@flash.ink',
    this.displayName,
    this.phoneNumber,
  });

  @override
  Future<void> updateDisplayName(String? name) async {}
}

class FakeArtistAuthService extends AuthService {
  final MockArtistUser user;

  FakeArtistAuthService({MockArtistUser? testUser})
      : user = testUser ?? MockArtistUser();

  @override
  User? get currentUser => user;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
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

  group('ArtistInfoScreen Username Field Auto-@ Tests', () {
    testWidgets('shows placeholder @yourhandle when empty', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ArtistInfoScreen(
            authService: FakeArtistAuthService(testUser: MockArtistUser(displayName: null)),
            initialName: '',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('@yourhandle'), findsOneWidget);
      final textField = tester.widget<TextFormField>(
        find.byKey(const Key('artist_name_handle_field')),
      );
      expect(textField.controller?.text, isEmpty);
    });

    testWidgets('auto-populates @ when user taps the name/handle input field', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ArtistInfoScreen(
            authService: FakeArtistAuthService(testUser: MockArtistUser(displayName: null)),
            initialName: '',
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('artist_name_handle_field')));
      await tester.pump();

      final textField = tester.widget<TextFormField>(
        find.byKey(const Key('artist_name_handle_field')),
      );
      expect(textField.controller?.text, equals('@'));
      expect(textField.controller?.selection.baseOffset, equals(1));
    });

    testWidgets('prepends @ when user starts typing', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ArtistInfoScreen(
            authService: FakeArtistAuthService(testUser: MockArtistUser(displayName: null)),
            initialName: '',
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('artist_name_handle_field')), 'OddMaree');
      await tester.pump();

      final textField = tester.widget<TextFormField>(
        find.byKey(const Key('artist_name_handle_field')),
      );
      expect(textField.controller?.text, equals('@OddMaree'));
    });

    testWidgets('prevents double @ if user explicitly types @ in front', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ArtistInfoScreen(
            authService: FakeArtistAuthService(testUser: MockArtistUser(displayName: null)),
            initialName: '',
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('artist_name_handle_field')), '@OddMaree');
      await tester.pump();

      final textField = tester.widget<TextFormField>(
        find.byKey(const Key('artist_name_handle_field')),
      );
      expect(textField.controller?.text, equals('@OddMaree'));
    });

    testWidgets('clears @ on blur when user taps away without typing a username', (WidgetTester tester) async {
      final unfocusNode = FocusNode();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Expanded(
                  child: ArtistInfoScreen(
                    authService: FakeArtistAuthService(testUser: MockArtistUser(displayName: null)),
                    initialName: '',
                  ),
                ),
                TextField(focusNode: unfocusNode, key: const Key('outside_field')),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap name/handle field
      await tester.tap(find.byKey(const Key('artist_name_handle_field')));
      await tester.pump();

      final textField = tester.widget<TextFormField>(
        find.byKey(const Key('artist_name_handle_field')),
      );
      expect(textField.controller?.text, equals('@'));

      // Tap outside field to unfocus
      await tester.tap(find.byKey(const Key('outside_field')));
      await tester.pump();

      expect(textField.controller?.text, isEmpty);
      expect(find.text('@yourhandle'), findsOneWidget);
    });

    testWidgets('shows validation error if CONTINUE is tapped with only @', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ArtistInfoScreen(
            authService: FakeArtistAuthService(testUser: MockArtistUser(displayName: null)),
            initialName: '',
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('artist_name_handle_field')));
      await tester.pump();

      await tester.tap(find.byKey(const Key('continue_artist_info_button')));
      await tester.pump();

      expect(find.text('Please enter your name or artist handle'), findsOneWidget);
    });

    testWidgets('advances to photo step when valid username is entered with verified phone', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ArtistInfoScreen(
            authService: FakeArtistAuthService(
              testUser: MockArtistUser(
                displayName: null,
                phoneNumber: '+15551234567',
              ),
            ),
            initialName: '',
            initialPhone: '+15551234567',
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('artist_name_handle_field')), 'OddMaree');
      await tester.pump();
      expect(find.text('@OddMaree'), findsWidgets);

      // Check terms checkbox
      await tester.tap(find.byType(Checkbox));
      await tester.pump();

      // Tap CONTINUE
      await tester.tap(find.byKey(const Key('continue_artist_info_button')));
      await tester.pumpAndSettle();

      expect(find.byType(ArtistProfilePhotoScreen), findsOneWidget);
    });
  });

  group('ArtistEditProfileScreen Username Field Tests', () {
    testWidgets('renders @ prefix in front of username without space', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ArtistEditProfileScreen(
            initialDisplayName: 'OddMaree',
            initialUsername: 'oddmaree',
            initialBio: 'Bio text',
            initialLocation: 'Portland, OR',
          ),
        ),
      );
      await tester.pumpAndSettle();

      final textField = tester.widget<TextField>(
        find.byKey(const Key('edit_profile_username_field')),
      );

      expect(textField.decoration?.prefixText, equals('@'));
      expect(textField.decoration?.prefixStyle?.color, equals(AppTheme.gold));
      expect(textField.decoration?.hintText, equals('yourhandle'));
      expect(textField.controller?.text, equals('oddmaree'));
    });

    testWidgets('strips leading @ when user types or enters @ in the username field', (WidgetTester tester) async {
      String? savedUsername;
      await tester.pumpWidget(
        MaterialApp(
          home: ArtistEditProfileScreen(
            initialDisplayName: 'OddMaree',
            initialUsername: 'oddmaree',
            initialBio: 'Bio text',
            initialLocation: 'Portland, OR',
            onSave: (name, username, bio, location) async {
              savedUsername = username;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter username with leading @
      await tester.enterText(find.byKey(const Key('edit_profile_username_field')), '@newartist');
      await tester.pump();

      final textField = tester.widget<TextField>(
        find.byKey(const Key('edit_profile_username_field')),
      );
      expect(textField.controller?.text, equals('newartist'));

      // Save changes
      await tester.tap(find.byKey(const Key('save_profile_button')));
      await tester.pumpAndSettle();

      expect(savedUsername, equals('newartist'));
    });
  });
}
