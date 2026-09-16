import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:flash_ink/screens/role_selection_screen.dart';
import 'package:flash_ink/screens/account_creation_screen.dart';
import 'package:flash_ink/screens/main_feed_screen.dart';
import 'package:flash_ink/screens/artist_dashboard/artist_dashboard_screen.dart';
import 'package:flash_ink/services/auth_service.dart';

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

  group('Onboarding Dev Bypass Flow Tests', () {
    testWidgets(
      'Dev Skip button is hidden initially when no role has been selected',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: RoleSelectionScreen(),
          ),
        );
        await tester.pump();

        // Verify title rendered
        expect(find.text("Let's get started."), findsOneWidget);

        // Verify Dev Skip button is NOT visible initially
        expect(find.byKey(const Key('dev_skip_role_button')), findsNothing);
        expect(find.text('Skip (Dev)'), findsNothing);

        // Verify CONTINUE button is present
        expect(find.text('CONTINUE'), findsOneWidget);
      },
    );

    testWidgets(
      'Selecting "I get tattoos" reveals Dev Skip button, tapping it navigates to MainFeedScreen with client mock user, and Back returns cleanly',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: RoleSelectionScreen(),
          ),
        );
        await tester.pump();

        // Dev skip button should not be present yet
        expect(find.byKey(const Key('dev_skip_role_button')), findsNothing);

        // Tap client role card ("I get tattoos")
        await tester.tap(find.text('I get tattoos'));
        await tester.pump();

        // Dev skip button is now visible
        expect(find.byKey(const Key('dev_skip_role_button')), findsOneWidget);
        expect(find.text('Skip (Dev)'), findsOneWidget);

        // Tap the Dev Skip button
        await tester.tap(find.byKey(const Key('dev_skip_role_button')));
        await tester.pumpAndSettle();

        // Verify navigation to MainFeedScreen
        expect(find.byType(MainFeedScreen), findsOneWidget);

        // Verify injected AuthService has mock client user context
        final mainFeed = tester.widget<MainFeedScreen>(find.byType(MainFeedScreen));
        expect(mainFeed.authService, isNotNull);
        expect(mainFeed.authService!.currentUser, isNotNull);
        expect(mainFeed.authService!.currentUser!.uid, 'dev_tester_client');
        expect(mainFeed.authService!.currentUser!.displayName, 'Dev Tester');
        expect(mainFeed.authService!.currentUser!.email, 'dev_client@flash.ink');

        // Test Back navigation pops back to RoleSelectionScreen
        final NavigatorState navigator = tester.state(find.byType(Navigator));
        navigator.pop();
        await tester.pumpAndSettle();

        expect(find.byType(RoleSelectionScreen), findsOneWidget);
        expect(find.byType(MainFeedScreen), findsNothing);
      },
    );

    testWidgets(
      'Selecting "I make tattoos" reveals Dev Skip button, tapping it navigates to ArtistDashboardScreen with artist mock user, and Back returns cleanly',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: RoleSelectionScreen(),
          ),
        );
        await tester.pump();

        // Tap artist role card ("I make tattoos")
        await tester.tap(find.text('I make tattoos'));
        await tester.pump();

        // Dev skip button is now visible
        expect(find.byKey(const Key('dev_skip_role_button')), findsOneWidget);

        // Tap Dev Skip
        await tester.tap(find.byKey(const Key('dev_skip_role_button')));
        await tester.pumpAndSettle();

        // Verify navigation to ArtistDashboardScreen
        expect(find.byType(ArtistDashboardScreen), findsOneWidget);

        // Verify injected AuthService has mock artist user context
        final artistDashboard = tester.widget<ArtistDashboardScreen>(find.byType(ArtistDashboardScreen));
        expect(artistDashboard.authService, isNotNull);
        expect(artistDashboard.authService!.currentUser, isNotNull);
        expect(artistDashboard.authService!.currentUser!.uid, 'dev_tester_artist');
        expect(artistDashboard.authService!.currentUser!.displayName, 'Dev Tester');
        expect(artistDashboard.authService!.currentUser!.email, 'dev_artist@flash.ink');

        // Verify that the artist dashboard displays "Dev Tester" as artist display name
        expect(find.text('Dev Tester'), findsOneWidget);

        // Test Back navigation pops back to RoleSelectionScreen
        final NavigatorState navigator = tester.state(find.byType(Navigator));
        navigator.pop();
        await tester.pumpAndSettle();

        expect(find.byType(RoleSelectionScreen), findsOneWidget);
        expect(find.byType(ArtistDashboardScreen), findsNothing);
      },
    );

    testWidgets(
      'Tapping Skip on AccountCreationScreen bypasses entire account creation and navigates to MainFeedScreen with client mock user',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: AccountCreationScreen(role: 'client'),
          ),
        );
        await tester.pump();

        // Verify Dev Skip button in AppBar is present
        expect(find.byKey(const Key('dev_skip_account_creation_button')), findsOneWidget);

        // Tap the AppBar skip button
        await tester.tap(find.byKey(const Key('dev_skip_account_creation_button')));
        await tester.pumpAndSettle();

        // Verify direct navigation to MainFeedScreen (bypassing ProfileSetupScreen)
        expect(find.byType(MainFeedScreen), findsOneWidget);

        final mainFeed = tester.widget<MainFeedScreen>(find.byType(MainFeedScreen));
        expect(mainFeed.authService?.currentUser?.uid, 'dev_tester_client');
        expect(mainFeed.authService?.currentUser?.displayName, 'Dev Tester');
      },
    );

    testWidgets(
      'Tapping banner Skip button on AccountCreationScreen bypasses entire account creation to MainFeedScreen',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: AccountCreationScreen(role: 'client'),
          ),
        );
        await tester.pump();

        // Verify Dev banner skip button is present
        expect(find.byKey(const Key('dev_skip_banner_button')), findsOneWidget);

        // Tap the banner skip button
        await tester.tap(find.byKey(const Key('dev_skip_banner_button')));
        await tester.pumpAndSettle();

        // Verify direct navigation to MainFeedScreen
        expect(find.byType(MainFeedScreen), findsOneWidget);
      },
    );

    test(
      'DevMockUser safely handles unimplemented members via noSuchMethod and AuthService handles mock deleteAccount',
      () async {
        final mockUser = DevMockUser(
          uid: 'test_uid_456',
          displayName: 'Dev Tester',
          email: 'test@flash.ink',
          isAnonymous: false,
        );

        expect(mockUser.uid, 'test_uid_456');
        expect(mockUser.displayName, 'Dev Tester');
        expect(mockUser.email, 'test@flash.ink');
        expect(mockUser.isAnonymous, false);

        // Test safe fallback for unimplemented members via noSuchMethod
        expect(mockUser.phoneNumber, isNull);
        expect(mockUser.photoURL, isNull);

        // Test AuthService with mock user
        final authService = AuthService(mockUser: mockUser);
        expect(authService.currentUser, equals(mockUser));

        // Test deleteAccount no-op for mock sessions
        await expectLater(authService.deleteAccount(), completes);
      },
    );
  });
}
