import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:flash_ink/screens/browse_artists_screen.dart';
import 'package:flash_ink/screens/client_account_screen.dart';
import 'package:flash_ink/screens/splash_screen.dart';
import 'package:flash_ink/features/discover/presentation/screens/discover_screen.dart';
import 'package:flash_ink/services/auth_service.dart';

class MockTestUser extends Fake implements User {
  @override
  final String uid;
  @override
  final String? email;
  @override
  final String? displayName;
  @override
  final String? photoURL;
  bool wasDeleted = false;

  MockTestUser({
    this.uid = 'client_user_123',
    this.email = 'collector@flash.ink',
    this.displayName = 'Alice Walker',
    this.photoURL = 'https://example.com/avatar.jpg',
  });

  @override
  Future<void> delete() async {
    wasDeleted = true;
  }
}

class FakeAccountAuthService extends AuthService {
  final MockTestUser user;
  int signOutCallCount = 0;
  int deleteCallCount = 0;
  bool throwErrorOnDelete = false;

  FakeAccountAuthService({MockTestUser? testUser})
      : user = testUser ?? MockTestUser();

  @override
  User? get currentUser => user;

  @override
  Future<void> signOut() async {
    signOutCallCount++;
  }

  @override
  Future<void> deleteAccount() async {
    deleteCallCount++;
    if (throwErrorOnDelete) {
      throw Exception('Failed to delete account');
    }
    await user.delete();
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
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.physicalSize = const Size(1080, 2400);
    binding.platformDispatcher.views.first.devicePixelRatio = 1.0;
  });

  tearDown(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.resetPhysicalSize();
    binding.platformDispatcher.views.first.resetDevicePixelRatio();
  });

  group('Client Account Screen & Avatar Navigation Tests', () {
    testWidgets(
      'Tapping avatar icon at top right of BrowseArtistsScreen navigates to ClientAccountScreen',
      (WidgetTester tester) async {
        final fakeAuth = FakeAccountAuthService();
        await tester.pumpWidget(
          MaterialApp(
            home: BrowseArtistsScreen(
              authService: fakeAuth,
              showBottomNav: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify avatar button is present in the sticky header
        final avatarButton = find.byKey(const Key('client_avatar_button'));
        expect(avatarButton, findsOneWidget);

        // Tap avatar button
        await tester.tap(avatarButton);
        await tester.pumpAndSettle();

        // Verify navigation to ClientAccountScreen
        expect(find.byType(ClientAccountScreen), findsOneWidget);
        expect(find.text('Account'), findsOneWidget);
        expect(find.byKey(const Key('account_back_button')), findsOneWidget);
      },
    );

    testWidgets(
      'Tapping avatar icon at top right of DiscoverScreen navigates to ClientAccountScreen',
      (WidgetTester tester) async {
        final fakeAuth = FakeAccountAuthService();
        await tester.pumpWidget(
          MaterialApp(
            home: DiscoverScreen(
              authService: fakeAuth,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify avatar button is present in DiscoverScreen actions
        final avatarButton = find.byKey(const Key('discover_avatar_button'));
        expect(avatarButton, findsOneWidget);

        // Tap avatar button
        await tester.tap(avatarButton);
        await tester.pumpAndSettle();

        // Verify navigation to ClientAccountScreen
        expect(find.byType(ClientAccountScreen), findsOneWidget);
        expect(find.text('Account'), findsOneWidget);
      },
    );

    testWidgets(
      'ClientAccountScreen renders profile info, aesthetics, switches, and actions',
      (WidgetTester tester) async {
        final fakeAuth = FakeAccountAuthService();
        await tester.pumpWidget(
          MaterialApp(
            home: ClientAccountScreen(
              authService: fakeAuth,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Check user identity
        expect(find.text('Alice Walker'), findsWidgets);
        expect(find.text('collector@flash.ink'), findsWidgets);
        expect(find.text('COLLECTOR • VERIFIED'), findsOneWidget);

        // Check stats
        expect(find.text('Upcoming Bookings'), findsOneWidget);
        expect(find.text('Saved Pieces'), findsOneWidget);

        // Check aesthetics section
        expect(find.text('MY AESTHETICS'), findsOneWidget);
        expect(find.text('TRADITIONAL'), findsOneWidget);
        expect(find.text('FINE LINE'), findsOneWidget);
        expect(find.text('BLACKWORK'), findsOneWidget);

        // Check settings sections
        expect(find.text('PERSONAL INFORMATION'), findsOneWidget);
        expect(find.text('NOTIFICATIONS & ALERTS'), findsOneWidget);
        expect(find.text('STUDIO & SAFETY POLICIES'), findsOneWidget);
        expect(find.text('SUPPORT & LEGAL'), findsOneWidget);

        // Check action buttons
        expect(find.byKey(const Key('account_sign_out_button')), findsOneWidget);
        expect(find.byKey(const Key('account_delete_account_button')), findsOneWidget);
      },
    );

    testWidgets(
      'Tapping back button on ClientAccountScreen pops and returns to previous screen',
      (WidgetTester tester) async {
        final fakeAuth = FakeAccountAuthService();
        await tester.pumpWidget(
          MaterialApp(
            home: BrowseArtistsScreen(
              authService: fakeAuth,
              showBottomNav: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap avatar to go to account
        await tester.tap(find.byKey(const Key('client_avatar_button')));
        await tester.pumpAndSettle();
        expect(find.byType(ClientAccountScreen), findsOneWidget);

        // Tap back button
        await tester.tap(find.byKey(const Key('account_back_button')));
        await tester.pumpAndSettle();

        // Verify popped back to BrowseArtistsScreen
        expect(find.byType(ClientAccountScreen), findsNothing);
        expect(find.byType(BrowseArtistsScreen), findsOneWidget);
      },
    );

    testWidgets(
      'Tapping edit button opens edit profile bottom sheet and saves changes',
      (WidgetTester tester) async {
        final fakeAuth = FakeAccountAuthService();
        await tester.pumpWidget(
          MaterialApp(
            home: ClientAccountScreen(
              authService: fakeAuth,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap edit profile button in AppBar
        await tester.tap(find.byKey(const Key('account_edit_button')));
        await tester.pumpAndSettle();

        // Verify bottom sheet appears
        expect(find.byKey(const Key('edit_profile_sheet_title')), findsOneWidget);
        expect(find.byKey(const Key('account_edit_name_input')), findsOneWidget);

        // Enter new display name
        await tester.enterText(find.byKey(const Key('account_edit_name_input')), 'Elena Vance');
        await tester.pump();

        // Tap save button
        await tester.tap(find.byKey(const Key('account_save_profile_button')));
        await tester.pumpAndSettle();

        // Verify sheet dismissed and name updated
        expect(find.byKey(const Key('edit_profile_sheet_title')), findsNothing);
        expect(find.text('Elena Vance'), findsWidgets);
      },
    );

    testWidgets(
      'Tapping Sign Out button triggers confirmation and invokes authService.signOut()',
      (WidgetTester tester) async {
        final fakeAuth = FakeAccountAuthService();
        await tester.pumpWidget(
          MaterialApp(
            home: ClientAccountScreen(
              authService: fakeAuth,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Scroll to sign out button
        final signOutBtn = find.byKey(const Key('account_sign_out_button'));
        await tester.ensureVisible(signOutBtn);
        await tester.tap(signOutBtn);
        await tester.pumpAndSettle();

        // Verify dialog
        expect(find.text('Are you sure you want to sign out of Flash.Ink?'), findsOneWidget);

        // Tap Sign Out in dialog
        final confirmSignOut = find.widgetWithText(ElevatedButton, 'Sign Out');
        await tester.tap(confirmSignOut);
        await tester.pump(); // dismiss dialog
        await tester.pump(); // complete async sign out and push SplashScreen

        // Verify signOut was called and routed to SplashScreen
        expect(fakeAuth.signOutCallCount, 1);
        expect(find.byType(SplashScreen), findsOneWidget);
      },
    );

    testWidgets(
      'Tapping Delete Account button opens confirmation modal, confirm invokes deleteAccount and routes to SplashScreen',
      (WidgetTester tester) async {
        final fakeAuth = FakeAccountAuthService();
        await tester.pumpWidget(
          MaterialApp(
            home: ClientAccountScreen(
              authService: fakeAuth,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Scroll to delete account button
        final deleteBtn = find.byKey(const Key('account_delete_account_button'));
        await tester.ensureVisible(deleteBtn);
        await tester.tap(deleteBtn);
        await tester.pumpAndSettle();

        // Verify standard deletion modal
        expect(find.byKey(const Key('delete_account_modal_title')), findsOneWidget);
        expect(find.byKey(const Key('delete_account_cancel_button')), findsOneWidget);
        expect(find.byKey(const Key('delete_account_confirm_button')), findsOneWidget);

        // Confirm deletion
        await tester.tap(find.byKey(const Key('delete_account_confirm_button')));
        await tester.pump();
        await tester.pump();

        // Verify delete was called and routed to SplashScreen
        expect(fakeAuth.deleteCallCount, 1);
        expect(fakeAuth.user.wasDeleted, isTrue);
        expect(find.text('Account deleted. A confirmation email has been sent.'), findsOneWidget);
        expect(find.byType(SplashScreen), findsOneWidget);
      },
    );
  });
}
