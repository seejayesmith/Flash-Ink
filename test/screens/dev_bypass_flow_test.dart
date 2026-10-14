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
import 'package:flash_ink/widgets/skip_pill_button.dart';
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

  group('Onboarding Skip & Dev Bypass Removal Tests', () {
    testWidgets(
      'RoleSelectionScreen: Dev Skip button is never shown initially or upon role selection',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: RoleSelectionScreen(),
          ),
        );
        await tester.pump();

        // 1. Initial state
        expect(find.text("Let's get started."), findsOneWidget);
        expect(find.byKey(const Key('dev_skip_role_button')), findsNothing);
        expect(find.text('Skip (Dev)'), findsNothing);

        // 2. Select client role
        await tester.tap(find.text('I get tattoos'));
        await tester.pump();
        expect(find.byKey(const Key('dev_skip_role_button')), findsNothing);
        expect(find.text('Skip (Dev)'), findsNothing);

        // 3. Select artist role
        await tester.tap(find.text('I make tattoos'));
        await tester.pump();
        expect(find.byKey(const Key('dev_skip_role_button')), findsNothing);
        expect(find.text('Skip (Dev)'), findsNothing);
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
  });
}
