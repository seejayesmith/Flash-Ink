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
import 'package:flash_ink/features/explore/presentation/screens/explore_screen.dart';
import 'package:flash_ink/features/explore/presentation/screens/saved_bookmarks_screen.dart';
import 'package:flash_ink/services/auth_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flash_ink/screens/location_settings_screen.dart';

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
      'Tapping bookmark icon at top right of ExploreScreen navigates to SavedBookmarksScreen',
      (WidgetTester tester) async {
        final fakeAuth = FakeAccountAuthService();
        await tester.pumpWidget(
          MaterialApp(
            home: ExploreScreen(
              authService: fakeAuth,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify bookmark button is present in ExploreScreen actions
        final bookmarkButton = find.byKey(const Key('explore_bookmark_button'));
        expect(bookmarkButton, findsOneWidget);

        // Tap bookmark button
        await tester.tap(bookmarkButton);
        await tester.pumpAndSettle();

        // Verify navigation to SavedBookmarksScreen
        expect(find.byType(SavedBookmarksScreen), findsOneWidget);
        expect(find.text('Saved & Bookmarks'), findsOneWidget);
      },
    );

    testWidgets(
      'Home screen avatars display user photoURL when authenticated and fallback to person icon when null',
      (WidgetTester tester) async {
        final userWithPhoto = MockTestUser(
          photoURL: 'https://example.com/user_photo.jpg',
        );
        final authWithPhoto = FakeAccountAuthService(testUser: userWithPhoto);

        await tester.pumpWidget(
          MaterialApp(
            home: BrowseArtistsScreen(
              authService: authWithPhoto,
              showBottomNav: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify Image.network is rendered with user's photoURL
        final imageFinder = find.descendant(
          of: find.byKey(const Key('client_avatar_button')),
          matching: find.byType(Image),
        );
        expect(imageFinder, findsOneWidget);
        final imageWidget = tester.widget<Image>(imageFinder);
        expect((imageWidget.image as NetworkImage).url, 'https://example.com/user_photo.jpg');

        // Test fallback to generic person icon when photoURL is null
        final userWithoutPhoto = MockTestUser(photoURL: null);
        final authWithoutPhoto = FakeAccountAuthService(testUser: userWithoutPhoto);

        await tester.pumpWidget(
          MaterialApp(
            home: BrowseArtistsScreen(
              authService: authWithoutPhoto,
              showBottomNav: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final iconFinder = find.descendant(
          of: find.byKey(const Key('client_avatar_button')),
          matching: find.byIcon(Icons.person),
        );
        expect(iconFinder, findsOneWidget);
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

        // Check user identity (display name removed, username displayed)
        expect(find.text('Display Name'), findsNothing);
        expect(find.text('Alice Walker'), findsNothing);
        expect(find.text('@flashclient'), findsWidgets);
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
        expect(find.text('STUDIO & SAFETY POLICIES'), findsNothing);
        expect(find.text('Health & Safety Standards'), findsNothing);
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
      'Tapping Username opens edit profile bottom sheet and saves changes',
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

        // Verify top-right edit button is not present
        expect(find.byKey(const Key('account_edit_button')), findsNothing);

        // Tap Username tile to open edit profile bottom sheet
        await tester.tap(find.text('Username'));
        await tester.pumpAndSettle();

        // Verify bottom sheet appears
        expect(find.byKey(const Key('edit_profile_sheet_title')), findsOneWidget);
        expect(find.byKey(const Key('account_edit_username_input')), findsOneWidget);
        expect(find.byKey(const Key('account_edit_name_input')), findsNothing);

        // Enter new username
        await tester.enterText(find.byKey(const Key('account_edit_username_input')), 'elenavance');
        await tester.pump();

        // Tap save button
        await tester.tap(find.byKey(const Key('account_save_profile_button')));
        await tester.pumpAndSettle();

        // Verify sheet dismissed and username updated
        expect(find.byKey(const Key('edit_profile_sheet_title')), findsNothing);
        expect(find.text('@elenavance'), findsWidgets);
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

    testWidgets(
      'Tapping Location Permissions tile opens LocationSettingsScreen',
      (WidgetTester tester) async {
        final fakeAuth = FakeAccountAuthService();
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: ClientAccountScreen(
                authService: fakeAuth,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final locationTile = find.byKey(const Key('client_location_permissions_tile'));
        await tester.scrollUntilVisible(locationTile, 200);
        await tester.pumpAndSettle();

        expect(locationTile, findsOneWidget);
        expect(find.text('Location Permissions'), findsOneWidget);

        await tester.tap(locationTile);
        await tester.pumpAndSettle();

        expect(find.byType(LocationSettingsScreen), findsOneWidget);
        expect(find.byKey(const Key('location_settings_title')), findsOneWidget);
      },
    );
  });
}
