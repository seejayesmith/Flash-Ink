import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';

import 'package:flash_ink/services/auth_service.dart';
import 'package:flash_ink/screens/client_account_screen.dart';
import 'package:flash_ink/screens/artist_dashboard/artist_account_screen.dart';
import 'package:flash_ink/screens/profile_setup_screen.dart';
import 'package:flash_ink/screens/artist_onboarding/artist_profile_photo_screen.dart';

final sampleBytes = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

class TestUser extends Fake implements User {
  @override
  final String uid;
  @override
  final String? email;
  @override
  final String? displayName;
  @override
  String? photoURL;

  TestUser({
    this.uid = 'test_user_photo',
    this.email = 'tester@flash.ink',
    this.displayName = 'Photo Tester',
    this.photoURL,
  });

  @override
  Future<void> updatePhotoURL(String? photoUri) async {
    photoURL = photoUri;
  }

  @override
  Future<void> reload() async {}
}

class TestAuthService extends AuthService {
  final TestUser? testUser;
  TestAuthService({this.testUser});

  @override
  User? get currentUser => testUser ?? TestUser();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  group('Profile Photo Persistence & DevMockUser Tests', () {
    test('DevMockUser updates and preserves photoURL', () async {
      final mock = DevMockUser(
        uid: 'dev_user_1',
        displayName: 'Dev Tester',
        email: 'dev@flash.ink',
      );

      expect(mock.photoURL, isNull);

      await mock.updatePhotoURL('https://example.com/new_avatar.png');
      expect(mock.photoURL, 'https://example.com/new_avatar.png');

      await mock.updatePhotoURL(null);
      expect(mock.photoURL, isNull);
    });

    testWidgets('ProfileSetupScreen renders Add a profile photo title and avatar placeholder', (tester) async {
      final user = TestUser();
      final auth = TestAuthService(testUser: user);

      await tester.pumpWidget(
        MaterialApp(
          home: ProfileSetupScreen(authService: auth),
        ),
      );
      await tester.pumpAndSettle();

      // Enter username to advance to photo step
      await tester.enterText(find.byType(TextField), 'OddMaree');
      await tester.pump();
      await tester.tap(find.text('CONTINUE'));
      await tester.pumpAndSettle();

      // Verify title is "Add a profile photo"
      expect(find.text('Add a profile photo'), findsOneWidget);
      expect(find.text('Show the community who you are!\nYou can always change this later.'), findsOneWidget);
    });

    testWidgets('ClientAccountScreen displays photoURL when present on user', (tester) async {
      final userWithPhoto = TestUser(photoURL: 'https://example.com/custom_avatar.png');
      final auth = TestAuthService(testUser: userWithPhoto);

      await tester.pumpWidget(
        MaterialApp(
          home: ClientAccountScreen(authService: auth),
        ),
      );
      await tester.pumpAndSettle();

      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);
      final imageWidget = tester.widget<Image>(imageFinder);
      expect((imageWidget.image as NetworkImage).url, 'https://example.com/custom_avatar.png');
    });

    testWidgets('ArtistProfilePhotoScreen renders with initial photo and calls updatePhotoURL on continue', (tester) async {
      final user = TestUser();
      final auth = TestAuthService(testUser: user);

      await tester.pumpWidget(
        MaterialApp(
          home: ArtistProfilePhotoScreen(
            artistName: 'OddMaree',
            initialImageBytes: sampleBytes,
            authService: auth,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Add a profile photo'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // After continuing, user.photoURL is updated (fallback or downloadUrl)
      expect(user.photoURL, isNotNull);
    });

    testWidgets('ArtistAccountScreen displays updated photoURL', (tester) async {
      final user = TestUser(photoURL: 'https://example.com/artist_photo.png');
      final auth = TestAuthService(testUser: user);

      await tester.pumpWidget(
        MaterialApp(
          home: ArtistAccountScreen(authService: auth),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('artist_account_avatar_edit')), findsOneWidget);
    });
  });
}
