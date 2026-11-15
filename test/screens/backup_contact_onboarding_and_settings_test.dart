import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flash_ink/models/artist.dart';
import 'package:flash_ink/providers/app_providers.dart';
import 'package:flash_ink/screens/aesthetics_selection_screen.dart';
import 'package:flash_ink/screens/artist_dashboard/artist_account_screen.dart';
import 'package:flash_ink/screens/artist_dashboard/artist_account_settings_screen.dart';
import 'package:flash_ink/screens/artist_onboarding/artist_info_screen.dart';
import 'package:flash_ink/screens/artist_onboarding/artist_phone_verification_screen.dart';
import 'package:flash_ink/screens/artist_onboarding/artist_profile_photo_screen.dart';
import 'package:flash_ink/screens/backup_email_verification_screen.dart';
import 'package:flash_ink/screens/client_account_screen.dart';
import 'package:flash_ink/screens/client_backup_contact_screen.dart';
import 'package:flash_ink/screens/profile_setup_screen.dart';
import 'package:flash_ink/services/auth_service.dart';
import 'package:flash_ink/widgets/inline_email_verification_tile.dart';
import 'package:flash_ink/widgets/reauthentication_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

class _FakeUserInfo extends Fake implements UserInfo {
  @override
  final String providerId;

  _FakeUserInfo(this.providerId);
}

class _FakeBackupUser extends Fake implements User {
  @override
  final String uid;

  @override
  String? email;

  @override
  bool emailVerified;

  @override
  String? phoneNumber;

  @override
  String? get displayName => null;

  @override
  String? get photoURL => null;

  @override
  bool get isAnonymous => false;

  final List<String> providers;

  _FakeBackupUser({
    required this.uid,
    this.email,
    this.emailVerified = false,
    this.phoneNumber,
    List<String>? providers,
  }) : providers = List<String>.from(providers ?? const []);

  @override
  List<UserInfo> get providerData =>
      providers.map((id) => _FakeUserInfo(id)).toList();

  @override
  Future<void> reload() async {}
}

class _FakeUserCredential extends Fake implements UserCredential {
  @override
  final User? user;

  _FakeUserCredential({this.user});
}

class _FakeBackupAuthService extends AuthService {
  final _FakeBackupUser testUser;
  String? pendingEmail;
  bool shouldMarkVerifiedOnCheck = true;
  int throwRequiresRecentLoginCount = 0;

  final List<String> sendBackupEmailCalls = [];
  int checkVerifiedCallCount = 0;
  final List<String> verifyPhoneCalls = [];
  final List<({String verificationId, String smsCode, String? phoneNumber})>
      linkWithPhoneCalls = [];
  int signInWithPhoneCallCount = 0;
  int updatePhoneStatusCallCount = 0;
  int reauthPasswordCallCount = 0;

  _FakeBackupAuthService({required this.testUser});

  @override
  User? get currentUser => testUser;

  @override
  List<String> get currentUserProviders => testUser.providers;

  @override
  Future<void> sendBackupEmailVerification(
    String email, {
    bool isArtist = false,
    FirebaseFirestore? firestore,
  }) async {
    sendBackupEmailCalls.add(email.trim());
    if (throwRequiresRecentLoginCount > 0) {
      throwRequiresRecentLoginCount--;
      throw const RequiresRecentLoginException();
    }
    pendingEmail = email.trim();
  }

  @override
  Future<bool> checkAndSyncBackupEmailVerified({
    String? expectedEmail,
    bool isArtist = false,
    FirebaseFirestore? firestore,
  }) async {
    checkVerifiedCallCount++;
    if (!shouldMarkVerifiedOnCheck) {
      return false;
    }
    final resolvedEmail = (expectedEmail?.trim().isNotEmpty == true)
        ? expectedEmail!.trim()
        : (pendingEmail ?? testUser.email ?? '');
    if (resolvedEmail.isEmpty) {
      return false;
    }
    testUser.email = resolvedEmail;
    testUser.emailVerified = true;
    pendingEmail = null;
    return true;
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
    verifyPhoneCalls.add(phoneNumber);
    onCodeSent('vid_backup_123', 42);
  }

  @override
  Future<UserCredential?> linkWithPhoneCredential({
    required String verificationId,
    required String smsCode,
    String? phoneNumber,
  }) async {
    linkWithPhoneCalls.add((
      verificationId: verificationId,
      smsCode: smsCode,
      phoneNumber: phoneNumber,
    ));
    if (phoneNumber != null && phoneNumber.isNotEmpty) {
      testUser.phoneNumber = phoneNumber;
    }
    if (!testUser.providers.contains('phone')) {
      testUser.providers.add('phone');
    }
    return _FakeUserCredential(user: testUser);
  }

  @override
  Future<UserCredential> signInWithPhoneCredential({
    required String verificationId,
    required String smsCode,
  }) async {
    signInWithPhoneCallCount++;
    return _FakeUserCredential(user: testUser);
  }

  @override
  Future<void> updatePhoneVerificationStatus({
    required String uid,
    required String phoneNumber,
  }) async {
    updatePhoneStatusCallCount++;
  }

  @override
  Future<UserCredential?> reauthenticateWithPassword(String password) async {
    reauthPasswordCallCount++;
    return null;
  }
}

Widget _wrapApp(Widget home, {FirebaseFirestore? firestore}) {
  return ProviderScope(
    overrides: [
      if (firestore != null)
        firebaseFirestoreProvider.overrideWithValue(firestore),
    ],
    child: MaterialApp(
      home: home,
    ),
  );
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
    binding.platformDispatcher.views.first.physicalSize =
        const Size(1080, 2400);
    binding.platformDispatcher.views.first.devicePixelRatio = 1.0;
  });

  group('Client Onboarding Backup Contact Flows', () {
    testWidgets(
      'ProfileSetupScreen routes Phone-OTP client without email to ClientBackupContactScreen(email)',
      (WidgetTester tester) async {
        final fakeAuth = _FakeBackupAuthService(
          testUser: _FakeBackupUser(
            uid: 'client_phone_1',
            phoneNumber: '+15551112222',
            providers: ['phone'],
          ),
        );

        final fakeFirestore = FakeFirebaseFirestore();
        await tester.pumpWidget(
          _wrapApp(
            ProfileSetupScreen(authService: fakeAuth),
            firestore: fakeFirestore,
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField).first, '@collector');
        await tester.pump();
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        expect(find.text('Add a profile photo'), findsOneWidget);
        await tester.tap(find.text('Skip for Now'));
        await tester.pumpAndSettle();

        expect(find.byType(ClientBackupContactScreen), findsOneWidget);
        expect(find.byKey(const Key('client_backup_email_input')), findsOneWidget);
      },
    );

    testWidgets(
      'ProfileSetupScreen routes Email/Password client without phone to ClientBackupContactScreen(phone)',
      (WidgetTester tester) async {
        final fakeAuth = _FakeBackupAuthService(
          testUser: _FakeBackupUser(
            uid: 'client_email_1',
            email: 'collector@flash.ink',
            emailVerified: true,
            providers: ['password'],
          ),
        );

        final fakeFirestore = FakeFirebaseFirestore();
        await tester.pumpWidget(
          _wrapApp(
            ProfileSetupScreen(authService: fakeAuth),
            firestore: fakeFirestore,
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField).first, '@collector');
        await tester.pump();
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        expect(find.text('Add a profile photo'), findsOneWidget);
        await tester.tap(find.text('Skip for Now'));
        await tester.pumpAndSettle();

        expect(find.byType(ClientBackupContactScreen), findsOneWidget);
        expect(find.byKey(const Key('client_backup_phone_input')), findsOneWidget);
      },
    );

    testWidgets(
      'Client Phone-OTP -> Backup Email -> BackupEmailVerificationScreen -> AestheticsSelectionScreen',
      (WidgetTester tester) async {
        final fakeAuth = _FakeBackupAuthService(
          testUser: _FakeBackupUser(
            uid: 'client_phone_2',
            phoneNumber: '+15551112222',
            providers: ['phone'],
          ),
        );

        await tester.pumpWidget(
          _wrapApp(
            ClientBackupContactScreen(
              mode: ClientBackupContactMode.email,
              authService: fakeAuth,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('client_backup_email_input')),
          'backup.client@flash.ink',
        );
        await tester.tap(
          find.byKey(const Key('client_backup_email_submit_button')),
        );
        await tester.pumpAndSettle();

        expect(fakeAuth.sendBackupEmailCalls, ['backup.client@flash.ink']);
        expect(find.byType(BackupEmailVerificationScreen), findsOneWidget);
        expect(find.textContaining('backup.client@flash.ink'), findsOneWidget);

        await tester.tap(find.byKey(const Key('backup_email_verified_cta')));
        await tester.pumpAndSettle();

        expect(fakeAuth.checkVerifiedCallCount, 1);
        expect(find.byType(AestheticsSelectionScreen), findsOneWidget);
      },
    );

    testWidgets(
      'Client Phone-OTP skips backup email directly to AestheticsSelectionScreen',
      (WidgetTester tester) async {
        final fakeAuth = _FakeBackupAuthService(
          testUser: _FakeBackupUser(
            uid: 'client_phone_skip',
            phoneNumber: '+15551112222',
            providers: ['phone'],
          ),
        );

        await tester.pumpWidget(
          _wrapApp(
            ClientBackupContactScreen(
              mode: ClientBackupContactMode.email,
              authService: fakeAuth,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('client_backup_skip_button')));
        await tester.pumpAndSettle();

        expect(fakeAuth.sendBackupEmailCalls, isEmpty);
        expect(find.byType(AestheticsSelectionScreen), findsOneWidget);
      },
    );

    testWidgets(
      'Client Email/Password -> Backup Phone OTP -> linkWithPhoneCredential -> AestheticsSelectionScreen',
      (WidgetTester tester) async {
        final fakeAuth = _FakeBackupAuthService(
          testUser: _FakeBackupUser(
            uid: 'client_email_2',
            email: 'collector@flash.ink',
            emailVerified: true,
            providers: ['password'],
          ),
        );

        await tester.pumpWidget(
          _wrapApp(
            ClientBackupContactScreen(
              mode: ClientBackupContactMode.phone,
              authService: fakeAuth,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('client_backup_phone_input')),
          '5552223344',
        );
        await tester.tap(
          find.byKey(const Key('client_backup_phone_submit_button')),
        );
        await tester.pumpAndSettle();

        expect(fakeAuth.verifyPhoneCalls, ['+15552223344']);
        expect(find.byKey(const Key('client_backup_otp_input')), findsOneWidget);

        await tester.enterText(
          find.byKey(const Key('client_backup_otp_input')),
          '123456',
        );
        await tester.tap(
          find.byKey(const Key('client_backup_otp_verify_button')),
        );
        await tester.pumpAndSettle();

        expect(fakeAuth.linkWithPhoneCalls.length, 1);
        expect(
          fakeAuth.linkWithPhoneCalls.first.verificationId,
          'vid_backup_123',
        );
        expect(fakeAuth.linkWithPhoneCalls.first.smsCode, '123456');
        expect(fakeAuth.linkWithPhoneCalls.first.phoneNumber, '+15552223344');
        expect(fakeAuth.signInWithPhoneCallCount, 0);
        expect(find.byType(AestheticsSelectionScreen), findsOneWidget);
      },
    );

    testWidgets(
      'Client Email/Password skips backup phone directly to AestheticsSelectionScreen',
      (WidgetTester tester) async {
        final fakeAuth = _FakeBackupAuthService(
          testUser: _FakeBackupUser(
            uid: 'client_email_skip',
            email: 'collector@flash.ink',
            emailVerified: true,
            providers: ['password'],
          ),
        );

        await tester.pumpWidget(
          _wrapApp(
            ClientBackupContactScreen(
              mode: ClientBackupContactMode.phone,
              authService: fakeAuth,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('client_backup_skip_button')));
        await tester.pumpAndSettle();

        expect(fakeAuth.verifyPhoneCalls, isEmpty);
        expect(fakeAuth.linkWithPhoneCalls, isEmpty);
        expect(find.byType(AestheticsSelectionScreen), findsOneWidget);
      },
    );
  });

  group('Artist Onboarding Backup Email & Phone Linking', () {
    testWidgets(
      'Phone-OTP artist leaving optional Backup Email blank skips straight to ArtistProfilePhotoScreen',
      (WidgetTester tester) async {
        final fakeAuth = _FakeBackupAuthService(
          testUser: _FakeBackupUser(
            uid: 'artist_phone_1',
            phoneNumber: '+15559876543',
            providers: ['phone'],
          ),
        );

        await tester.pumpWidget(
          _wrapApp(
            ArtistInfoScreen(
              authService: fakeAuth,
              initialPhone: '+15559876543',
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('artist_backup_email_field')),
          findsOneWidget,
        );

        await tester.enterText(
          find.byKey(const Key('artist_name_handle_field')),
          '@inkmaster',
        );
        await tester.ensureVisible(find.byType(Checkbox));
        await tester.tap(find.byType(Checkbox));
        await tester.pump();

        await tester.tap(find.text('Continue').first);
        await tester.pumpAndSettle();

        expect(fakeAuth.sendBackupEmailCalls, isEmpty);
        expect(find.byType(ArtistProfilePhotoScreen), findsOneWidget);
      },
    );

    testWidgets(
      'Phone-OTP artist entering optional Backup Email routes through BackupEmailVerificationScreen -> ArtistProfilePhotoScreen',
      (WidgetTester tester) async {
        final fakeAuth = _FakeBackupAuthService(
          testUser: _FakeBackupUser(
            uid: 'artist_phone_2',
            phoneNumber: '+15559876543',
            providers: ['phone'],
          ),
        );

        await tester.pumpWidget(
          _wrapApp(
            ArtistInfoScreen(
              authService: fakeAuth,
              initialPhone: '+15559876543',
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('artist_name_handle_field')),
          '@inkmaster',
        );
        await tester.enterText(
          find.byKey(const Key('artist_backup_email_field')),
          'backup.artist@studio.com',
        );
        await tester.ensureVisible(find.byType(Checkbox));
        await tester.tap(find.byType(Checkbox));
        await tester.pump();

        await tester.tap(find.text('Continue').first);
        await tester.pumpAndSettle();

        expect(fakeAuth.sendBackupEmailCalls, ['backup.artist@studio.com']);
        expect(find.byType(BackupEmailVerificationScreen), findsOneWidget);

        await tester.tap(find.byKey(const Key('backup_email_verified_cta')));
        await tester.pumpAndSettle();

        expect(fakeAuth.checkVerifiedCallCount, 1);
        expect(find.byType(ArtistProfilePhotoScreen), findsOneWidget);
      },
    );

    testWidgets(
      'Email/Password artist on ArtistPhoneVerificationScreen calls linkWithPhoneCredential (not signInWithPhoneCredential)',
      (WidgetTester tester) async {
        final fakeAuth = _FakeBackupAuthService(
          testUser: _FakeBackupUser(
            uid: 'artist_email_1',
            email: 'artist@studio.com',
            emailVerified: true,
            providers: ['password'],
          ),
        );

        await tester.pumpWidget(
          _wrapApp(
            ArtistPhoneVerificationScreen(
              phoneNumber: '(555) 333-4444',
              verificationId: 'vid_artist_1',
              artistName: '@inkmaster',
              artistEmail: 'artist@studio.com',
              authService: fakeAuth,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final otpFields = find.byType(TextField);
        expect(otpFields, findsNWidgets(6));
        const code = '654321';
        for (int i = 0; i < 6; i++) {
          await tester.enterText(otpFields.at(i), code[i]);
          await tester.pump();
        }
        await tester.pumpAndSettle();

        expect(fakeAuth.linkWithPhoneCalls.length, 1);
        expect(
          fakeAuth.linkWithPhoneCalls.first.verificationId,
          'vid_artist_1',
        );
        expect(fakeAuth.linkWithPhoneCalls.first.smsCode, '654321');
        expect(fakeAuth.signInWithPhoneCallCount, 0);
        expect(find.byType(ArtistProfilePhotoScreen), findsOneWidget);
      },
    );
  });

  group('Post-Onboarding Account Settings (InlineEmailVerificationTile)', () {
    testWidgets(
      'ClientAccountScreen: phone user adds and confirms backup email inline',
      (WidgetTester tester) async {
        final fakeFirestore = FakeFirebaseFirestore();
        const uid = 'client_settings_phone_1';
        await fakeFirestore.collection('users').doc(uid).set({
          'username': 'phoneclient',
          'phone': '(555) 111-2222',
          'phoneVerified': true,
        });

        final fakeAuth = _FakeBackupAuthService(
          testUser: _FakeBackupUser(
            uid: uid,
            phoneNumber: '+15551112222',
            providers: ['phone'],
          ),
        );

        await tester.pumpWidget(
          _wrapApp(
            ClientAccountScreen(
              authService: fakeAuth,
              firestore: fakeFirestore,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final addButton = find.byKey(const Key('add_email_button'));
        await tester.ensureVisible(addButton);
        expect(find.text('Not added'), findsOneWidget);
        await tester.tap(addButton);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('inline_email_expansion_container')),
          findsOneWidget,
        );
        await tester.enterText(
          find.byKey(const Key('inline_email_input_field')),
          'saved.client@flash.ink',
        );
        await tester.tap(
          find.byKey(const Key('inline_email_send_link_button')),
        );
        await tester.pumpAndSettle();

        expect(fakeAuth.sendBackupEmailCalls, ['saved.client@flash.ink']);
        expect(find.byKey(const Key('email_pending_badge')), findsOneWidget);
        expect(
          find.byKey(const Key('inline_email_check_verified_button')),
          findsOneWidget,
        );

        await tester.tap(
          find.byKey(const Key('inline_email_check_verified_button')),
        );
        await tester.pumpAndSettle();

        expect(fakeAuth.checkVerifiedCallCount, 1);
        expect(find.byKey(const Key('email_verified_badge')), findsOneWidget);
        expect(find.text('saved.client@flash.ink'), findsWidgets);
        expect(
          find.descendant(
            of: find.byKey(const Key('account_email_tile')),
            matching: find.text('saved.client@flash.ink'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'ArtistAccountScreen: phone artist adds and confirms backup email inline',
      (WidgetTester tester) async {
        final fakeFirestore = FakeFirebaseFirestore();
        const uid = 'artist_settings_phone_1';
        await fakeFirestore.collection('users').doc(uid).set({
          'phoneVerified': true,
          'phoneNumber': '+1 (555) 444-5555',
        });
        await fakeFirestore
            .collection('artists')
            .doc(uid)
            .collection('private')
            .doc('settings')
            .set({
          'phoneNumber': '+1 (555) 444-5555',
        });

        final fakeAuth = _FakeBackupAuthService(
          testUser: _FakeBackupUser(
            uid: uid,
            phoneNumber: '+15554445555',
            providers: ['phone'],
          ),
        );

        const artist = Artist(
          id: uid,
          name: 'Studio Artist',
          bio: 'Blackwork specialist',
          location: 'Austin, TX',
          avatarUrl: '',
          studioType: 'Private Studio',
          rating: 5.0,
          availablePieces: 4,
          minDeposit: 100,
          isBooksOpen: true,
        );

        await tester.pumpWidget(
          _wrapApp(
            ArtistAccountScreen(
              artist: artist,
              authService: fakeAuth,
              firestore: fakeFirestore,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final addButton = find.byKey(const Key('add_email_button'));
        await tester.ensureVisible(addButton);
        expect(find.text('Not added'), findsOneWidget);
        await tester.tap(addButton);
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('inline_email_input_field')),
          'saved.artist@flash.ink',
        );
        await tester.tap(
          find.byKey(const Key('inline_email_send_link_button')),
        );
        await tester.pumpAndSettle();

        expect(fakeAuth.sendBackupEmailCalls, ['saved.artist@flash.ink']);
        expect(find.byKey(const Key('email_pending_badge')), findsOneWidget);

        await tester.tap(
          find.byKey(const Key('inline_email_check_verified_button')),
        );
        await tester.pumpAndSettle();

        expect(fakeAuth.checkVerifiedCallCount, 1);
        expect(find.byKey(const Key('email_verified_badge')), findsOneWidget);
        expect(find.text('saved.artist@flash.ink'), findsWidgets);
        expect(
          find.descendant(
            of: find.byKey(const Key('account_email_tile')),
            matching: find.text('saved.artist@flash.ink'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'ArtistAccountSettingsScreen updates Primary Account Email and handles requires-recent-login via ReauthenticationBottomSheet',
      (WidgetTester tester) async {
        final fakeAuth = _FakeBackupAuthService(
          testUser: _FakeBackupUser(
            uid: 'artist_settings_reauth_1',
            email: 'old@flash.ink',
            emailVerified: false,
            providers: ['password'],
          ),
        )..throwRequiresRecentLoginCount = 1;

        await tester.pumpWidget(
          _wrapApp(
            ArtistAccountSettingsScreen(
              email: 'old@flash.ink',
              authService: fakeAuth,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(InlineEmailVerificationTile), findsOneWidget);
        expect(find.text('Primary Account Email'), findsOneWidget);
        expect(find.text('old@flash.ink'), findsOneWidget);

        await tester.tap(find.byKey(const Key('change_email_button')));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('inline_email_input_field')),
          'new.verified@flash.ink',
        );
        await tester.tap(
          find.byKey(const Key('inline_email_send_link_button')),
        );
        await tester.pumpAndSettle();

        // First attempt throws RequiresRecentLoginException -> opens ReauthenticationBottomSheet
        expect(fakeAuth.sendBackupEmailCalls, ['new.verified@flash.ink']);
        expect(find.byKey(const Key('reauth_modal_title')), findsOneWidget);
        expect(find.text('Security Verification'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(ReauthenticationBottomSheet),
            matching: find.textContaining('Delete'),
          ),
          findsNothing,
        );

        await tester.enterText(
          find.byKey(const Key('reauth_password_field')),
          'secret123',
        );
        await tester.tap(find.byKey(const Key('reauth_confirm_button')));
        await tester.pumpAndSettle();

        // Reauthentication succeeds and retries sendBackupEmailVerification
        expect(fakeAuth.reauthPasswordCallCount, 1);
        expect(
          fakeAuth.sendBackupEmailCalls,
          ['new.verified@flash.ink', 'new.verified@flash.ink'],
        );
        expect(find.byKey(const Key('email_pending_badge')), findsOneWidget);

        await tester.tap(
          find.byKey(const Key('inline_email_check_verified_button')),
        );
        await tester.pumpAndSettle();

        expect(fakeAuth.checkVerifiedCallCount, 1);
        expect(find.text('new.verified@flash.ink'), findsOneWidget);
        expect(find.byKey(const Key('email_verified_badge')), findsOneWidget);
      },
    );
  });
}
