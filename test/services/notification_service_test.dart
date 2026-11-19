import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:flash_ink/core/widgets/flash_bottom_nav_bar.dart';
import 'package:flash_ink/screens/artist_dashboard/artist_account_screen.dart';
import 'package:flash_ink/screens/client_account_screen.dart';
import 'package:flash_ink/screens/main_feed_screen.dart';
import 'package:flash_ink/services/auth_service.dart';
import 'package:flash_ink/services/notification_service.dart';
import 'package:flash_ink/widgets/flash_switch.dart';

class _TestUser extends Fake implements User {
  @override
  final String uid;
  @override
  final String? email = 'user@flash.ink';
  @override
  final String? displayName;
  @override
  final String? photoURL = null;
  @override
  final String? phoneNumber = null;
  @override
  final bool isAnonymous;

  _TestUser({
    required this.uid,
    this.displayName = 'Test User',
    this.isAnonymous = false,
  });
}

class _TestAuthService extends AuthService {
  final _TestUser _user;

  _TestAuthService(this._user);

  @override
  User? get currentUser => _user;
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
    NotificationService.lastTappedPayload.value = null;
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.resetPhysicalSize();
    binding.platformDispatcher.views.first.resetDevicePixelRatio();
  });

  group('NotificationService unit tests', () {
    test('syncFcmTokenForUser and removeFcmTokenForUser update fcmTokens',
        () async {
      final fakeDb = FakeFirebaseFirestore();

      final synced1 = await NotificationService.syncFcmTokenForUser(
        'user_123',
        firestore: fakeDb,
        tokenOverride: 'token_abc',
      );
      expect(synced1, 'token_abc');

      await NotificationService.syncFcmTokenForUser(
        'user_123',
        firestore: fakeDb,
        tokenOverride: 'token_xyz',
      );

      var snap = await fakeDb.collection('users').doc('user_123').get();
      expect(
        List<String>.from(snap.data()?['fcmTokens'] as List),
        containsAll(['token_abc', 'token_xyz']),
      );

      await NotificationService.removeFcmTokenForUser(
        'user_123',
        firestore: fakeDb,
        tokenOverride: 'token_abc',
      );

      snap = await fakeDb.collection('users').doc('user_123').get();
      expect(
        List<String>.from(snap.data()?['fcmTokens'] as List),
        ['token_xyz'],
      );
    });

    test(
        'syncFcmTokenForCurrentUser syncs for signed-in user and skips null/anonymous users',
        () async {
      final fakeDb = FakeFirebaseFirestore();

      final signedInToken = await NotificationService.syncFcmTokenForCurrentUser(
        user: _TestUser(uid: 'signed_in_uid'),
        firestore: fakeDb,
        tokenOverride: 'cold_start_token',
      );
      expect(signedInToken, 'cold_start_token');

      final signedInSnap =
          await fakeDb.collection('users').doc('signed_in_uid').get();
      expect(
        List<String>.from(signedInSnap.data()?['fcmTokens'] as List),
        ['cold_start_token'],
      );

      final anonToken = await NotificationService.syncFcmTokenForCurrentUser(
        user: _TestUser(uid: 'anon_uid', isAnonymous: true),
        firestore: fakeDb,
        tokenOverride: 'anon_token',
      );
      expect(anonToken, isNull);
      final anonSnap = await fakeDb.collection('users').doc('anon_uid').get();
      expect(anonSnap.exists, isFalse);

      final nullToken = await NotificationService.syncFcmTokenForCurrentUser(
        user: null,
        firestore: fakeDb,
        tokenOverride: 'null_token',
      );
      expect(nullToken, isNull);
    });

    test('updatePreference and loadPreferences persist and restore values',
        () async {
      final fakeDb = FakeFirebaseFirestore();

      final initial = await NotificationService.loadPreferences(
        'user_456',
        firestore: fakeDb,
      );
      expect(initial.flashDropAlerts, isTrue);
      expect(initial.bookingAlerts, isTrue);

      await NotificationService.updatePreference(
        'user_456',
        key: 'flashDropAlerts',
        value: false,
        firestore: fakeDb,
      );
      await NotificationService.updatePreference(
        'user_456',
        key: 'reminderAlerts',
        value: false,
        firestore: fakeDb,
      );

      final loaded = await NotificationService.loadPreferences(
        'user_456',
        firestore: fakeDb,
      );
      expect(loaded.flashDropAlerts, isFalse);
      expect(loaded.bookingReminders, isTrue);
      expect(loaded.artistMessages, isTrue);
      expect(loaded.bookingAlerts, isTrue);
      expect(loaded.reminderAlerts, isFalse);
      expect(loaded.clientMessages, isTrue);
    });

    test('syncFollowedArtist adds and removes artist IDs in followedArtistIds',
        () async {
      final fakeDb = FakeFirebaseFirestore();

      await NotificationService.syncFollowedArtist(
        'user_follow_1',
        artistId: 'artist_1',
        isFollowed: true,
        firestore: fakeDb,
      );
      await NotificationService.syncFollowedArtist(
        'user_follow_1',
        artistId: 'artist_2',
        isFollowed: true,
        firestore: fakeDb,
      );

      var snap = await fakeDb.collection('users').doc('user_follow_1').get();
      expect(
        List<String>.from(snap.data()?['followedArtistIds'] as List),
        containsAll(['artist_1', 'artist_2']),
      );

      await NotificationService.syncFollowedArtist(
        'user_follow_1',
        artistId: 'artist_1',
        isFollowed: false,
        firestore: fakeDb,
      );

      snap = await fakeDb.collection('users').doc('user_follow_1').get();
      expect(
        List<String>.from(snap.data()?['followedArtistIds'] as List),
        ['artist_2'],
      );
    });
  });

  group('Account screen notification preference persistence', () {
    testWidgets(
      'ClientAccountScreen persists Flash Drop Alerts toggle and restores on reload',
      (WidgetTester tester) async {
        final fakeDb = FakeFirebaseFirestore();
        const uid = 'client_pref_uid';
        await fakeDb.collection('users').doc(uid).set({
          'uid': uid,
          'username': 'collector_one',
          'email': 'collector@flash.ink',
        });
        final fakeAuth = _TestAuthService(_TestUser(uid: uid));

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: ClientAccountScreen(
                authService: fakeAuth,
                firestore: fakeDb,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final flashDropTile = find.ancestor(
          of: find.text('Flash Drop Alerts'),
          matching: find.byType(ListTile),
        );
        final flashDropSwitchFinder = find.descendant(
          of: flashDropTile,
          matching: find.byType(FlashSwitch),
        );

        await tester.ensureVisible(flashDropSwitchFinder);
        await tester.pumpAndSettle();

        expect(
          tester.widget<FlashSwitch>(flashDropSwitchFinder).value,
          isTrue,
        );

        await tester.tap(flashDropSwitchFinder);
        await tester.pumpAndSettle();

        final docSnap = await fakeDb.collection('users').doc(uid).get();
        final prefs = Map<String, dynamic>.from(
          docSnap.data()?['notificationPreferences'] as Map,
        );
        expect(prefs['flashDropAlerts'], isFalse);

        // Unmount and reload the screen to verify restored state
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: ClientAccountScreen(
                authService: fakeAuth,
                firestore: fakeDb,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final reloadedSwitchFinder = find.descendant(
          of: find.ancestor(
            of: find.text('Flash Drop Alerts'),
            matching: find.byType(ListTile),
          ),
          matching: find.byType(FlashSwitch),
        );
        expect(
          tester.widget<FlashSwitch>(reloadedSwitchFinder).value,
          isFalse,
        );
      },
    );

    testWidgets(
      'ArtistAccountScreen persists New Booking Requests toggle and restores on reload',
      (WidgetTester tester) async {
        final fakeDb = FakeFirebaseFirestore();
        const uid = 'artist_pref_uid';
        await fakeDb.collection('users').doc(uid).set({
          'uid': uid,
          'email': 'artist@flash.ink',
          'role': 'artist',
        });
        await fakeDb.collection('artists').doc(uid).set({
          'id': uid,
          'name': 'OddMaree',
          'username': 'oddmaree',
          'bio': 'Illustrative blackwork',
          'location': 'Portland, OR',
        });
        final fakeAuth = _TestAuthService(
          _TestUser(uid: uid, displayName: 'OddMaree'),
        );

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: ArtistAccountScreen(
                authService: fakeAuth,
                firestore: fakeDb,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final bookingAlertsTile = find.ancestor(
          of: find.text('New Booking Requests'),
          matching: find.byType(ListTile),
        );
        final bookingAlertsSwitchFinder = find.descendant(
          of: bookingAlertsTile,
          matching: find.byType(FlashSwitch),
        );

        await tester.ensureVisible(bookingAlertsSwitchFinder);
        await tester.pumpAndSettle();

        expect(
          tester.widget<FlashSwitch>(bookingAlertsSwitchFinder).value,
          isTrue,
        );

        await tester.tap(bookingAlertsSwitchFinder);
        await tester.pumpAndSettle();

        final docSnap = await fakeDb.collection('users').doc(uid).get();
        final prefs = Map<String, dynamic>.from(
          docSnap.data()?['notificationPreferences'] as Map,
        );
        expect(prefs['bookingAlerts'], isFalse);

        // Unmount and reload the screen to verify restored state
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: ArtistAccountScreen(
                authService: fakeAuth,
                firestore: fakeDb,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final reloadedSwitchFinder = find.descendant(
          of: find.ancestor(
            of: find.text('New Booking Requests'),
            matching: find.byType(ListTile),
          ),
          matching: find.byType(FlashSwitch),
        );
        expect(
          tester.widget<FlashSwitch>(reloadedSwitchFinder).value,
          isFalse,
        );
      },
    );
  });

  group('Notification tap deep-linking', () {
    testWidgets(
      'MainFeedScreen switches tabs when NotificationService.lastTappedPayload changes and clears payload',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: MainFeedScreen(),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          tester.widget<FlashBottomNavBar>(find.byType(FlashBottomNavBar)).currentIndex,
          0,
        );

        NotificationService.lastTappedPayload.value = const {
          'category': 'artist_message',
          'threadId': 'thread_123',
        };
        await tester.pumpAndSettle();
        expect(
          tester.widget<FlashBottomNavBar>(find.byType(FlashBottomNavBar)).currentIndex,
          3,
        );
        expect(NotificationService.lastTappedPayload.value, isNull);

        NotificationService.lastTappedPayload.value = const {
          'category': 'flash_drop',
          'artistId': 'artist_abc',
        };
        await tester.pumpAndSettle();
        expect(
          tester.widget<FlashBottomNavBar>(find.byType(FlashBottomNavBar)).currentIndex,
          1,
        );
        expect(NotificationService.lastTappedPayload.value, isNull);

        NotificationService.lastTappedPayload.value = const {
          'category': 'booking_confirmed',
          'appointmentId': 'apt_789',
        };
        await tester.pumpAndSettle();
        expect(
          tester.widget<FlashBottomNavBar>(find.byType(FlashBottomNavBar)).currentIndex,
          2,
        );
        expect(NotificationService.lastTappedPayload.value, isNull);
      },
    );
  });
}
