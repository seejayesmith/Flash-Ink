import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:flash_ink/screens/aesthetics_selection_screen.dart';
import 'package:flash_ink/screens/artist_dashboard/artist_account_screen.dart';
import 'package:flash_ink/screens/artist_dashboard/artist_dashboard_screen.dart';
import 'package:flash_ink/screens/artist_onboarding/artist_info_screen.dart';
import 'package:flash_ink/screens/auth_routing.dart';
import 'package:flash_ink/screens/client_account_screen.dart';
import 'package:flash_ink/screens/main_feed_screen.dart';
import 'package:flash_ink/screens/splash_screen.dart';
import 'package:flash_ink/services/auth_service.dart';

class DualRoleFakeUser extends Fake implements User {
  @override
  final String uid;
  @override
  final String? email;
  @override
  final String? displayName;
  @override
  final String? photoURL;
  @override
  final String? phoneNumber;
  @override
  final bool isAnonymous;
  @override
  final bool emailVerified;

  DualRoleFakeUser({
    this.uid = 'dual_user_uid_1',
    this.email = 'collector@flash.ink',
    this.displayName,
    this.photoURL,
    this.phoneNumber = '+15552223333',
    this.isAnonymous = false,
    this.emailVerified = true,
  });

  @override
  Future<void> reload() async {}
}

class _DualRoleFakeAuthService extends AuthService {
  final User? user;
  final String verifiedClaimRole;

  _DualRoleFakeAuthService({
    this.user,
    this.verifiedClaimRole = 'client',
  });

  @override
  User? get currentUser => user;

  @override
  Stream<User?> get authStateChanges => Stream.value(user);

  @override
  Future<String> getVerifiedRole({
    User? user,
    bool forceRefresh = false,
  }) async {
    return verifiedClaimRole;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await Firebase.initializeApp();
  });

  setUp(() {
    AuthService.invalidateSessionState();
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.physicalSize =
        const Size(1080, 2400);
    binding.platformDispatcher.views.first.devicePixelRatio = 1.0;
  });

  tearDown(() {
    AuthService.invalidateSessionState();
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.resetPhysicalSize();
    binding.platformDispatcher.views.first.resetDevicePixelRatio();
  });

  group('Dual-Role Persona Routing & Switching Tests', () {
    testWidgets(
      'Existing Client signing in with defaultRole: artist routes to ArtistInfoScreen with pre-filled details',
      (WidgetTester tester) async {
        final fakeDb = FakeFirebaseFirestore();
        final mockUser = DualRoleFakeUser(uid: 'existing_client_1');

        // Seed existing completed client document in Firestore
        await fakeDb.collection('users').doc(mockUser.uid).set({
          'uid': mockUser.uid,
          'username': 'inkcollector',
          'email': 'collector@flash.ink',
          'phoneNumber': '+15552223333',
          'phoneVerified': true,
          'role': 'client',
          'profileCompleted': true,
          'aesthetics': ['traditional', 'blackwork'],
        });

        final fakeAuth = _DualRoleFakeAuthService(user: mockUser);

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  AuthRouting.routeUserAfterAuth(
                    context,
                    mockUser,
                    defaultRole: 'artist',
                    authService: fakeAuth,
                    firestore: fakeDb,
                  );
                },
                child: const Text('Route As Artist'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Route As Artist'));
        await tester.pumpAndSettle();

        expect(find.byType(ArtistInfoScreen), findsOneWidget);
        expect(find.text('@inkcollector'), findsOneWidget);
        expect(find.text('(555) 222-3333'), findsOneWidget);
        expect(AuthService.activeAppMode, equals('artist'));
      },
    );

    testWidgets(
      'Existing Artist signing in with defaultRole: client routes to AestheticsSelectionScreen or MainFeedScreen',
      (WidgetTester tester) async {
        final fakeDb = FakeFirebaseFirestore();
        final mockUser = DualRoleFakeUser(uid: 'existing_artist_1');

        // Seed existing completed artist document & user document
        await fakeDb.collection('users').doc(mockUser.uid).set({
          'uid': mockUser.uid,
          'username': 'oddmaree',
          'displayName': 'OddMaree',
          'role': 'client',
          'isArtist': true,
          'profileCompleted': true,
          'aesthetics': ['fineline'],
        });
        await fakeDb.collection('artists').doc(mockUser.uid).set({
          'id': mockUser.uid,
          'name': 'OddMaree',
          'profileCompleted': true,
        });

        final fakeAuth = _DualRoleFakeAuthService(
          user: mockUser,
          verifiedClaimRole: 'artist',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  AuthRouting.routeUserAfterAuth(
                    context,
                    mockUser,
                    defaultRole: 'client',
                    authService: fakeAuth,
                    firestore: fakeDb,
                  );
                },
                child: const Text('Route As Client'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Route As Client'));
        await tester.pumpAndSettle();

        expect(find.byType(MainFeedScreen), findsOneWidget);
        expect(AuthService.activeAppMode, equals('client'));

        final updatedUserDoc =
            await fakeDb.collection('users').doc(mockUser.uid).get();
        expect(updatedUserDoc.data()?['activeMode'], equals('client'));
      },
    );

    testWidgets(
      'Existing Artist without client aesthetics signing in with defaultRole: client routes to AestheticsSelectionScreen',
      (WidgetTester tester) async {
        final fakeDb = FakeFirebaseFirestore();
        final mockUser = DualRoleFakeUser(uid: 'existing_artist_no_aesthetics');

        await fakeDb.collection('users').doc(mockUser.uid).set({
          'uid': mockUser.uid,
          'username': 'oddmaree',
          'displayName': 'OddMaree',
          'role': 'client',
          'isArtist': true,
          'profileCompleted': true,
        });
        await fakeDb.collection('artists').doc(mockUser.uid).set({
          'id': mockUser.uid,
          'name': 'OddMaree',
          'profileCompleted': true,
        });

        final fakeAuth = _DualRoleFakeAuthService(
          user: mockUser,
          verifiedClaimRole: 'artist',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  AuthRouting.routeUserAfterAuth(
                    context,
                    mockUser,
                    defaultRole: 'client',
                    authService: fakeAuth,
                    firestore: fakeDb,
                  );
                },
                child: const Text('Route As Client'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Route As Client'));
        await tester.pumpAndSettle();

        expect(find.byType(AestheticsSelectionScreen), findsOneWidget);
        expect(AuthService.activeAppMode, equals('client'));
      },
    );

    testWidgets(
      'ClientAccountScreen shows Switch to Artist Mode when artist profile exists and navigates to ArtistDashboardScreen',
      (WidgetTester tester) async {
        final fakeDb = FakeFirebaseFirestore();
        final mockUser = DualRoleFakeUser(uid: 'dual_user_switch_1');

        await fakeDb.collection('users').doc(mockUser.uid).set({
          'uid': mockUser.uid,
          'username': 'dualcollector',
          'isArtist': true,
          'profileCompleted': true,
        });
        await fakeDb.collection('artists').doc(mockUser.uid).set({
          'id': mockUser.uid,
          'name': 'Dual Artist',
          'profileCompleted': true,
        });

        final fakeAuth = _DualRoleFakeAuthService(
          user: mockUser,
          verifiedClaimRole: 'artist',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: ClientAccountScreen(
              authService: fakeAuth,
              firestore: fakeDb,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final switchTile = find.byKey(const Key('switch_to_artist_mode_button'));
        expect(switchTile, findsOneWidget);

        await tester.ensureVisible(switchTile);
        await tester.tap(switchTile);
        await tester.pumpAndSettle();

        expect(find.byType(ArtistDashboardScreen), findsOneWidget);
        expect(AuthService.activeAppMode, equals('artist'));
      },
    );

    testWidgets(
      'ArtistAccountScreen shows Switch to Client Mode and navigates to MainFeedScreen',
      (WidgetTester tester) async {
        final fakeDb = FakeFirebaseFirestore();
        final mockUser = DualRoleFakeUser(uid: 'dual_user_switch_2');

        await fakeDb.collection('users').doc(mockUser.uid).set({
          'uid': mockUser.uid,
          'username': 'dualartist',
          'isArtist': true,
          'profileCompleted': true,
        });

        final fakeAuth = _DualRoleFakeAuthService(
          user: mockUser,
          verifiedClaimRole: 'artist',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: ArtistAccountScreen(
              authService: fakeAuth,
              firestore: fakeDb,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final switchTile = find.byKey(const Key('switch_to_client_mode_button'));
        expect(switchTile, findsOneWidget);

        await tester.ensureVisible(switchTile);
        await tester.tap(switchTile);
        await tester.pumpAndSettle();

        expect(find.byType(MainFeedScreen), findsOneWidget);
        expect(AuthService.activeAppMode, equals('client'));
      },
    );

    testWidgets(
      'SplashScreen respects persisted activeMode == client for a dual-role user',
      (WidgetTester tester) async {
        final fakeDb = FakeFirebaseFirestore();
        final mockUser = DualRoleFakeUser(uid: 'splash_dual_user');

        await fakeDb.collection('users').doc(mockUser.uid).set({
          'uid': mockUser.uid,
          'username': 'dualuser',
          'isArtist': true,
          'activeMode': 'client',
          'profileCompleted': true,
          'aesthetics': ['traditional'],
        });
        await fakeDb.collection('artists').doc(mockUser.uid).set({
          'id': mockUser.uid,
          'name': 'Dual Artist',
          'profileCompleted': true,
        });

        final fakeAuth = _DualRoleFakeAuthService(
          user: mockUser,
          verifiedClaimRole: 'artist',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: SplashScreen(
              delay: Duration.zero,
              authService: fakeAuth,
              firestore: fakeDb,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(MainFeedScreen), findsOneWidget);
        expect(AuthService.activeAppMode, equals('client'));
      },
    );

    testWidgets(
      'SplashScreen routes mid-onboarding artist draft back to ArtistInfoScreen instead of ArtistDashboardScreen',
      (WidgetTester tester) async {
        final fakeDb = FakeFirebaseFirestore();
        final mockUser = DualRoleFakeUser(uid: 'draft_artist_user');

        await fakeDb.collection('users').doc(mockUser.uid).set({
          'uid': mockUser.uid,
          'username': 'draftartist',
          'onboardingRole': 'artist',
          'activeMode': 'artist',
          'profileCompleted': true,
        });
        await fakeDb.collection('artists').doc(mockUser.uid).set({
          'id': mockUser.uid,
          'name': 'Draft Artist',
          'profileCompleted': false,
        });

        final fakeAuth = _DualRoleFakeAuthService(
          user: mockUser,
          verifiedClaimRole: 'client',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: SplashScreen(
              delay: Duration.zero,
              authService: fakeAuth,
              firestore: fakeDb,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(ArtistInfoScreen), findsOneWidget);
      },
    );
  });
}
