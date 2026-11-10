import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';

import 'package:flash_ink/core/mock/mock_data_config.dart';
import 'package:flash_ink/models/artist.dart';
import 'package:flash_ink/screens/artist_onboarding/artist_info_screen.dart';
import 'package:flash_ink/screens/artist_onboarding/artist_profile_photo_screen.dart';
import 'package:flash_ink/screens/client_account_screen.dart';
import 'package:flash_ink/screens/booking/flash_booking_screen.dart';
import 'package:flash_ink/services/auth_service.dart';

class MockGoogleUserInfo extends Fake implements UserInfo {
  @override
  final String providerId = 'google.com';
  @override
  final String? email;
  MockGoogleUserInfo({this.email = 'alex.rivers@gmail.com'});
}

class MockGoogleAuthUser extends Fake implements User {
  @override
  final String uid;
  @override
  final String? email;
  @override
  final String? displayName;
  @override
  final String? phoneNumber;
  @override
  final String? photoURL;
  @override
  final bool isAnonymous;
  @override
  final List<UserInfo> providerData;

  MockGoogleAuthUser({
    required this.uid,
    this.email = 'artist.google@gmail.com',
    this.displayName = 'GoogleArtist',
    this.phoneNumber,
    this.photoURL,
    this.isAnonymous = false,
    List<UserInfo>? providers,
  }) : providerData = providers ?? [MockGoogleUserInfo(email: email)];

  @override
  Future<void> updateDisplayName(String? name) async {}
  @override
  Future<void> updatePhotoURL(String? photoUri) async {}
  @override
  Future<String> getIdToken([bool forceRefresh = false]) async => 'mock_token';
}

class FakeGoogleTestAuthService extends AuthService {
  final MockGoogleAuthUser user;
  int verifyPhoneNumberCallCount = 0;

  FakeGoogleTestAuthService({required this.user});

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
    onCodeSent('vid_123', 1);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  setUp(() {
    MockDataConfig.debugOverride = false;
  });

  tearDown(() {
    MockDataConfig.resetDebugOverride();
  });

  group('Google Sign-In Phone Exclusion Tests', () {
    testWidgets('ArtistInfoScreen completely hides phone field for Google users and bypasses SMS verification', (tester) async {
      final googleUser = MockGoogleAuthUser(
        uid: 'google_artist_uid',
        email: 'ink.master@gmail.com',
        displayName: 'InkMaster',
      );
      final fakeAuth = FakeGoogleTestAuthService(user: googleUser);

      await tester.pumpWidget(
        MaterialApp(
          home: ArtistInfoScreen(
            authService: fakeAuth,
            initialEmail: googleUser.email,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Artist handle field is visible
      expect(find.byKey(const Key('artist_name_handle_field')), findsOneWidget);

      // Phone Number field is NOT rendered for Google users
      expect(find.text('Phone Number'), findsNothing);
      expect(find.text('(555) 000-0000'), findsNothing);

      // Agree to terms checkbox
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      // Tap CONTINUE
      await tester.tap(find.byKey(const Key('continue_artist_info_button')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // Verify SMS OTP verification was NOT invoked
      expect(fakeAuth.verifyPhoneNumberCallCount, 0);

      // Successfully navigated directly to ArtistProfilePhotoScreen
      expect(find.byType(ArtistProfilePhotoScreen), findsOneWidget);
    });

    testWidgets('ClientAccountScreen does not auto-populate a default phone for Google users', (tester) async {
      final googleUser = MockGoogleAuthUser(
        uid: 'google_client_uid',
        email: 'collector.gmail@gmail.com',
        displayName: 'Collector',
      );
      final fakeAuth = FakeGoogleTestAuthService(user: googleUser);

      await tester.pumpWidget(
        MaterialApp(
          home: ClientAccountScreen(authService: fakeAuth),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Phone Number displays "Not added" and "+ Add" button, NOT (555) 234-5678
      expect(find.text('(555) 234-5678'), findsNothing);
      expect(find.text('Not added'), findsOneWidget);
      expect(find.byKey(const Key('add_phone_button')), findsOneWidget);
      expect(find.byKey(const Key('phone_verified_badge')), findsNothing);
    });

    testWidgets('FlashBookingScreen prompts with modal bottom sheet if user lacks verified phone', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const testFlash = FlashArtwork(
        id: 'flash_google_test',
        artistId: 'artist_1',
        artistName: 'Maree Raven',
        title: 'Obsidian Serpent',
        imageUrl: 'https://images.unsplash.com/photo-1598371839696-5c5bb00bdc28',
        price: 250,
        deposit: 75,
        dimensions: '6" x 9"',
        estimatedTime: '3.0 hrs',
        location: 'Forearm',
        status: FlashStatus.available,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: FlashBookingScreen(flash: testFlash),
        ),
      );
      await tester.pumpAndSettle();

      // Advance from Step 0 (Schedule) to Step 1 (Details)
      await tester.tap(find.text('CONTINUE TO DETAILS'));
      await tester.pumpAndSettle();

      // Enter required fields (Full Legal Name and Email)
      await tester.enterText(find.byType(TextField).at(0), 'Jane Doe');
      await tester.enterText(find.byType(TextField).at(2), 'jane@example.com');
      await tester.pumpAndSettle();

      // Tap CONTINUE TO PAYMENT
      await tester.tap(find.text('CONTINUE TO PAYMENT'));
      await tester.pumpAndSettle();

      // Verified Phone Required modal bottom sheet is shown
      expect(find.byKey(const Key('phone_required_sheet_title')), findsOneWidget);
      expect(find.text('Verified Phone Required'), findsOneWidget);
      expect(find.byKey(const Key('go_to_account_settings_button')), findsOneWidget);

      // Dismiss modal
      await tester.tap(find.byKey(const Key('dismiss_phone_required_sheet_button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('phone_required_sheet_title')), findsNothing);
    });
  });
}
