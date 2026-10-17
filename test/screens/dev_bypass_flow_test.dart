import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:flash_ink/screens/role_selection_screen.dart';
import 'package:flash_ink/screens/account_creation_screen.dart';
import 'package:flash_ink/screens/profile_setup_screen.dart';
import 'package:flash_ink/screens/aesthetics_selection_screen.dart';
import 'package:flash_ink/screens/main_feed_screen.dart';
import 'package:flash_ink/screens/artist_onboarding/artist_info_screen.dart';
import 'package:flash_ink/widgets/skip_pill_button.dart';
import 'package:flash_ink/services/auth_service.dart';
import 'package:flash_ink/services/stripe_service.dart';

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

  group('Onboarding Skip & Dev Bypass Removal Tests', () {
    testWidgets(
      'RoleSelectionScreen: Skip button is completely removed and role must be selected',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: RoleSelectionScreen(),
          ),
        );
        await tester.pump();

        // 1. Initial state: No Skip button of any kind
        expect(find.text("Let's get started."), findsOneWidget);
        expect(find.byKey(const Key('dev_skip_role_button')), findsNothing);
        expect(find.byKey(const Key('skip_role_selection_button')), findsNothing);
        expect(find.byType(SkipPillButton), findsNothing);
        expect(find.text('Skip'), findsNothing);

        // 2. Select client role
        await tester.tap(find.text('I get tattoos'));
        await tester.pump();
        expect(find.byKey(const Key('skip_role_selection_button')), findsNothing);
        expect(find.byType(SkipPillButton), findsNothing);
        expect(find.text('Skip'), findsNothing);

        // 3. Select artist role
        await tester.tap(find.text('I make tattoos'));
        await tester.pump();
        expect(find.byKey(const Key('skip_role_selection_button')), findsNothing);
        expect(find.byType(SkipPillButton), findsNothing);
        expect(find.text('Skip'), findsNothing);
      },
    );

    testWidgets(
      'AccountCreationScreen: Dev Skip button and dev banner are completely removed',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: AccountCreationScreen(role: 'client'),
          ),
        );
        await tester.pump();

        expect(find.byKey(const Key('dev_skip_account_creation_button')), findsNothing);
        expect(find.byKey(const Key('dev_skip_banner_button')), findsNothing);
        expect(find.text('Skip (Dev)'), findsNothing);
        expect(find.text('Dev Mode: Bypass account creation'), findsNothing);
      },
    );

    testWidgets(
      'ProfileSetupScreen: Minimal Skip button in top right advances from username step to photo step',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: ProfileSetupScreen(),
          ),
        );
        await tester.pumpAndSettle();

        // Verify username step has top-right Skip button
        expect(find.text('Add a username'), findsOneWidget);
        final skipFinder = find.byType(SkipPillButton);
        expect(skipFinder, findsOneWidget);
        expect(find.text('Skip'), findsOneWidget);

        // Tap Skip on username step
        await tester.tap(skipFinder);
        await tester.pumpAndSettle();

        // Verify advance to photo upload step
        expect(find.text('Upload a profile photo'), findsOneWidget);
        expect(find.byType(SkipPillButton), findsOneWidget);
      },
    );

    testWidgets(
      'ProfileSetupScreen: Tapping Skip on photo step navigates to AestheticsSelectionScreen',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: ProfileSetupScreen(),
          ),
        );
        await tester.pumpAndSettle();

        // Skip username step
        await tester.tap(find.byType(SkipPillButton));
        await tester.pumpAndSettle();

        expect(find.text('Upload a profile photo'), findsOneWidget);

        // Skip photo step
        await tester.tap(find.byType(SkipPillButton));
        await tester.pumpAndSettle();

        // Should route to AestheticsSelectionScreen
        expect(find.byType(ProfileSetupScreen), findsNothing);
        expect(find.byType(AestheticsSelectionScreen), findsOneWidget);
      },
    );

    testWidgets(
      'AestheticsSelectionScreen: Top-right Skip button navigates directly to MainFeedScreen',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: AestheticsSelectionScreen(isGuest: false),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Choose your aesthetics'), findsOneWidget);
        final skipFinder = find.byType(SkipPillButton);
        expect(skipFinder, findsOneWidget);
        expect(find.text('Skip'), findsOneWidget);

        // Tap Skip button
        await tester.tap(skipFinder);
        await tester.pumpAndSettle();

        // Should route to MainFeedScreen
        expect(find.byType(AestheticsSelectionScreen), findsNothing);
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

    testWidgets(
      'AccountCreationScreen (client): Tapping Skip creates mock client account and routes to ProfileSetupScreen with isGuest == false',
      (WidgetTester tester) async {
        AuthService.clearDevMockUser();
        await tester.pumpWidget(
          const MaterialApp(
            home: AccountCreationScreen(role: 'client'),
          ),
        );
        await tester.pumpAndSettle();

        final skipFinder = find.byKey(const Key('skip_account_creation_button'));
        expect(skipFinder, findsOneWidget);

        await tester.tap(skipFinder);
        await tester.pumpAndSettle();

        expect(find.byType(AccountCreationScreen), findsNothing);
        expect(find.byType(ProfileSetupScreen), findsOneWidget);

        // Verify devMockUser is initialized as client
        final user = AuthService().currentUser;
        expect(user, isNotNull);
        expect(user!.uid, 'dev_client_uid');
        expect(user.displayName, 'Alex Rivers');
        expect(user.email, 'alex.rivers@example.com');
        expect(AuthService().isGuest, isFalse);
      },
    );

    testWidgets(
      'AccountCreationScreen (artist): Tapping Skip creates mock artist account and routes to ArtistInfoScreen with isGuest == false',
      (WidgetTester tester) async {
        AuthService.clearDevMockUser();
        await tester.pumpWidget(
          const MaterialApp(
            home: AccountCreationScreen(role: 'artist'),
          ),
        );
        await tester.pumpAndSettle();

        final skipFinder = find.byKey(const Key('skip_account_creation_button'));
        expect(skipFinder, findsOneWidget);

        await tester.tap(skipFinder);
        await tester.pumpAndSettle();

        expect(find.byType(AccountCreationScreen), findsNothing);
        expect(find.byType(ArtistInfoScreen), findsOneWidget);

        // Verify devMockUser is initialized as artist
        final user = AuthService().currentUser;
        expect(user, isNotNull);
        expect(user!.uid, 'dev_artist_uid');
        expect(user.displayName, 'OddMaree');
        expect(user.email, 'oddmaree@flash.ink');
        expect(AuthService().isGuest, isFalse);
      },
    );

    test(
      'AuthService devMockUser lifecycle: creation, isGuest, and clear / signOut',
      () async {
        AuthService.clearDevMockUser();
        expect(AuthService().currentUser, isNull);
        expect(AuthService().isGuest, isTrue);

        final client = AuthService.createDevMockClient();
        expect(client.uid, 'dev_client_uid');
        expect(AuthService().currentUser?.displayName, 'Alex Rivers');
        expect(AuthService().isGuest, isFalse);

        await AuthService().signOut();
        expect(AuthService().currentUser, isNull);
        expect(AuthService().isGuest, isTrue);

        final artist = AuthService.createDevMockArtist();
        expect(artist.uid, 'dev_artist_uid');
        expect(AuthService().currentUser?.displayName, 'OddMaree');
        expect(AuthService().isGuest, isFalse);

        await AuthService().deleteAccount();
        expect(AuthService().currentUser, isNull);
        expect(AuthService().isGuest, isTrue);
      },
    );

    test(
      'StripeService: presentDepositPaymentSheet simulates gracefully in tests and handles non-acct destination IDs',
      () async {
        final stripe = StripeService();
        final response = await stripe.presentDepositPaymentSheet(
          amountInDollars: 60,
          flashTitle: 'Sacred Dagger & Serpent',
          customerEmail: 'alex.rivers@example.com',
          customerName: 'Alex Rivers',
          artistStripeAccountId: 'artist_1',
        );

        expect(response.isSuccess, isTrue);
      },
    );
  });
}
