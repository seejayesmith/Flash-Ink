import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:flash_ink/screens/artist_dashboard/artist_edit_profile_screen.dart';
import 'package:flash_ink/screens/artist_onboarding/artist_info_screen.dart';
import 'package:flash_ink/screens/client_edit_profile_screen.dart';
import 'package:flash_ink/screens/profile_setup_screen.dart';
import 'package:flash_ink/services/auth_service.dart';
import 'package:flash_ink/services/username_service.dart';

class _MockUser extends Fake implements User {
  @override
  final String uid;
  @override
  final String? email = 'user@flash.ink';
  @override
  final String? displayName = null;
  @override
  final String? phoneNumber = '+15551234567';
  @override
  final bool isAnonymous = false;
  @override
  final List<UserInfo> providerData = const [];

  _MockUser({required this.uid});

  @override
  Future<void> updateDisplayName(String? name) async {}
}

class _FakeAuthService extends AuthService {
  final _MockUser user;

  _FakeAuthService({required this.user});

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
    binding.platformDispatcher.views.first.physicalSize =
        const Size(1080, 2400);
    binding.platformDispatcher.views.first.devicePixelRatio = 1.0;
  });

  tearDown(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.resetPhysicalSize();
    binding.platformDispatcher.views.first.resetDevicePixelRatio();
  });

  group('UsernameService Format Validation (Industry Standard)', () {
    test('accepts valid handles with letters, numbers, underscores, and periods', () {
      expect(UsernameService.validateFormat('@oddmaree'), isNull);
      expect(UsernameService.validateFormat('OddMaree_99'), isNull);
      expect(UsernameService.validateFormat('elena.vance.ink'), isNull);
      expect(UsernameService.validateFormat('abc'), isNull);
    });

    test('rejects handles shorter than 3 or longer than 30 characters', () {
      expect(
        UsernameService.validateFormat('ab'),
        equals('Username must be at least 3 characters'),
      );
      expect(
        UsernameService.validateFormat('a' * 31),
        equals('Username must be 30 characters or less'),
      );
    });

    test('rejects handles with spaces or special characters', () {
      expect(
        UsernameService.validateFormat('odd maree'),
        equals('Only letters, numbers, underscores, and periods are allowed'),
      );
      expect(
        UsernameService.validateFormat('odd!maree#1'),
        equals('Only letters, numbers, underscores, and periods are allowed'),
      );
    });

    test('rejects leading, trailing, or consecutive periods', () {
      expect(
        UsernameService.validateFormat('.oddmaree'),
        equals('Username cannot start or end with a period'),
      );
      expect(
        UsernameService.validateFormat('oddmaree.'),
        equals('Username cannot start or end with a period'),
      );
      expect(
        UsernameService.validateFormat('odd..maree'),
        equals('Username cannot contain consecutive periods'),
      );
    });
  });

  group('UsernameService Global Shared Pool & Transaction Uniqueness', () {
    test('prevents duplicate handles case-insensitively across clients and artists', () async {
      final fakeDb = FakeFirebaseFirestore();
      final service = UsernameService(firestore: fakeDb);

      // Client A claims @OddMaree
      final claimed = await service.claimUsername(
        uid: 'client_a',
        rawUsername: '@OddMaree',
      );
      expect(claimed, equals('OddMaree'));

      // Verify /usernames/oddmaree is stored in lowercase
      final doc = await fakeDb.collection('usernames').doc('oddmaree').get();
      expect(doc.exists, isTrue);
      expect(doc.data()?['uid'], equals('client_a'));
      expect(doc.data()?['username'], equals('OddMaree'));

      // Client B or Artist B cannot claim @oddmaree or @ODDMAREE
      expect(
        await service.isUsernameAvailable('@oddmaree', currentUid: 'artist_b'),
        isFalse,
      );
      await expectLater(
        () => service.claimUsername(
          uid: 'artist_b',
          rawUsername: '@ODDMAREE',
        ),
        throwsA(isA<UsernameTakenException>()),
      );

      // Client A can re-claim or update casing on their own handle
      expect(
        await service.isUsernameAvailable('@oddmaree', currentUid: 'client_a'),
        isTrue,
      );
      final updated = await service.claimUsername(
        uid: 'client_a',
        rawUsername: '@oddmaree',
      );
      expect(updated, equals('oddmaree'));
    });

    test('releases old handle when a user renames their username', () async {
      final fakeDb = FakeFirebaseFirestore();
      final service = UsernameService(firestore: fakeDb);

      await service.claimUsername(
        uid: 'user_1',
        rawUsername: 'first_handle',
      );
      expect(
        (await fakeDb.collection('usernames').doc('first_handle').get()).exists,
        isTrue,
      );

      // User 1 renames to second_handle
      await service.claimUsername(
        uid: 'user_1',
        rawUsername: 'second_handle',
        previousUsername: 'first_handle',
      );

      // Old handle is freed, new handle is owned by user_1
      expect(
        (await fakeDb.collection('usernames').doc('first_handle').get()).exists,
        isFalse,
      );
      expect(
        (await fakeDb.collection('usernames').doc('second_handle').get())
            .data()?['uid'],
        equals('user_1'),
      );

      // Another user can now claim first_handle
      final claimedByOther = await service.claimUsername(
        uid: 'user_2',
        rawUsername: 'first_handle',
      );
      expect(claimedByOther, equals('first_handle'));
    });

    test('resolveUniqueAutoHandle appends suffix when base handle is already taken', () async {
      final fakeDb = FakeFirebaseFirestore();
      final service = UsernameService(firestore: fakeDb);

      await service.claimUsername(uid: 'user_1', rawUsername: 'alex');

      final generated = await service.resolveUniqueAutoHandle(
        baseHandle: 'alex',
        uid: 'user_2',
      );
      expect(generated, equals('alex_1'));
    });
  });

  group('UI Screens Duplicate Username Prevention', () {
    testWidgets('ProfileSetupScreen blocks taken username and shows error', (tester) async {
      final fakeDb = FakeFirebaseFirestore();
      await UsernameService(firestore: fakeDb).claimUsername(
        uid: 'existing_user',
        rawUsername: 'oddmaree',
      );

      final fakeAuth = _FakeAuthService(
        user: _MockUser(uid: 'new_client_uid'),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ProfileSetupScreen(
            authService: fakeAuth,
            firestore: fakeDb,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('username_input_field')),
        '@OddMaree',
      );
      await tester.pump();

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text(UsernameService.takenErrorMessage), findsOneWidget);
      expect(find.text('Add a profile photo'), findsNothing);
    });

    testWidgets('ArtistInfoScreen blocks taken handle and shows error', (tester) async {
      final fakeDb = FakeFirebaseFirestore();
      await UsernameService(firestore: fakeDb).claimUsername(
        uid: 'existing_client_uid',
        rawUsername: 'inkmaster',
      );

      final fakeAuth = _FakeAuthService(
        user: _MockUser(uid: 'new_artist_uid'),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ArtistInfoScreen(
            authService: fakeAuth,
            firestore: fakeDb,
            signInMethod: ArtistSignInMethod.oauth,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('artist_name_handle_field')),
        '@InkMaster',
      );
      await tester.tap(find.byType(Checkbox));
      await tester.pump();

      await tester.tap(find.byKey(const Key('continue_artist_info_button')));
      await tester.pumpAndSettle();

      expect(find.text(UsernameService.takenErrorMessage), findsWidgets);
    });

    testWidgets('ClientEditProfileScreen blocks saving a taken username', (tester) async {
      final fakeDb = FakeFirebaseFirestore();
      await UsernameService(firestore: fakeDb).claimUsername(
        uid: 'other_user',
        rawUsername: 'takenhandle',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ClientEditProfileScreen(
            initialUsername: 'myhandle',
            currentUid: 'my_uid',
            firestore: fakeDb,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('account_edit_username_input')),
        'takenhandle',
      );
      await tester.tap(find.byKey(const Key('account_save_profile_button')));
      await tester.pumpAndSettle();

      expect(find.text(UsernameService.takenErrorMessage), findsOneWidget);
      expect(find.byKey(const Key('edit_profile_sheet_title')), findsOneWidget);
    });

    testWidgets('ArtistEditProfileScreen blocks saving a taken or invalid username', (tester) async {
      final fakeDb = FakeFirebaseFirestore();
      await UsernameService(firestore: fakeDb).claimUsername(
        uid: 'other_user',
        rawUsername: 'taken_artist',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ArtistEditProfileScreen(
            initialDisplayName: 'OddMaree',
            initialUsername: 'oddmaree',
            initialBio: 'Bio',
            initialLocation: 'Portland, OR',
            currentUid: 'artist_uid_1',
            firestore: fakeDb,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('edit_profile_username_field')),
        'taken_artist',
      );
      await tester.tap(find.byKey(const Key('save_profile_button')));
      await tester.pumpAndSettle();

      expect(find.text(UsernameService.takenErrorMessage), findsOneWidget);
      expect(find.byKey(const Key('edit_profile_sheet_title')), findsOneWidget);
    });
  });
}
