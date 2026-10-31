import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';

import 'package:flash_ink/screens/artist_dashboard/artist_account_settings_screen.dart';
import 'package:flash_ink/screens/splash_screen.dart';
import 'package:flash_ink/services/auth_service.dart';

class MockSettingsUser extends Fake implements User {
  @override
  final String uid;
  @override
  final String? email;
  bool wasDeleted = false;

  MockSettingsUser({
    this.uid = 'artist_test_uid',
    this.email = 'artist@flash.ink',
  });

  @override
  Future<void> delete() async {
    wasDeleted = true;
  }
}

class FakeSettingsAuthService extends AuthService {
  final MockSettingsUser user;
  int deleteCallCount = 0;
  Exception? errorToThrowOnDelete;

  FakeSettingsAuthService({MockSettingsUser? testUser})
      : user = testUser ?? MockSettingsUser();

  @override
  User? get currentUser => user;

  @override
  Future<void> deleteAccount() async {
    if (errorToThrowOnDelete != null) {
      throw errorToThrowOnDelete!;
    }
    deleteCallCount++;
    await user.delete();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  Widget buildTestWidget({
    String email = 'artist@flash.ink',
    AuthService? authService,
    Future<void> Function()? onDeleteAccount,
  }) {
    return MaterialApp(
      home: ArtistAccountSettingsScreen(
        email: email,
        authService: authService ?? FakeSettingsAuthService(),
        onDeleteAccount: onDeleteAccount,
      ),
    );
  }

  group('ArtistAccountSettingsScreen Tests', () {
    testWidgets('Renders AppBar, Email, Verification, and Danger Zone Delete Account', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('account_settings_modal_title')), findsOneWidget);
      expect(find.text('Primary Account Email'), findsOneWidget);
      expect(find.text('artist@flash.ink'), findsOneWidget);
      expect(find.text('Artist Verification Status'), findsOneWidget);
      expect(find.text('Verified Resident Tattooer'), findsOneWidget);
      expect(find.text('DANGER ZONE'), findsOneWidget);
      expect(find.byKey(const Key('delete_account_button')), findsOneWidget);
    });

    testWidgets('Tapping Delete Account shows confirmation dialog and Cancel retains screen', (tester) async {
      final fakeAuth = FakeSettingsAuthService();
      await tester.pumpWidget(buildTestWidget(authService: fakeAuth));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('delete_account_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('delete_account_dialog')), findsOneWidget);
      expect(find.byKey(const Key('delete_account_cancel_button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('delete_account_cancel_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('delete_account_dialog')), findsNothing);
      expect(find.byKey(const Key('account_settings_modal_title')), findsOneWidget);
      expect(fakeAuth.deleteCallCount, 0);
    });

    testWidgets('Confirming Delete Account shows loading dialog, deletes account and navigates to SplashScreen', (tester) async {
      final fakeAuth = FakeSettingsAuthService();
      await tester.pumpWidget(buildTestWidget(authService: fakeAuth));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('delete_account_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('delete_account_confirm_button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('delete_account_confirm_button')));
      await tester.pump();
      await tester.pump();

      expect(fakeAuth.deleteCallCount, 1);
      expect(fakeAuth.user.wasDeleted, isTrue);
      expect(find.byType(SplashScreen), findsOneWidget);
    });

    testWidgets('Error during delete dismisses loading dialog and shows FlashSnackBar', (tester) async {
      final fakeAuth = FakeSettingsAuthService();
      fakeAuth.errorToThrowOnDelete = Exception('Network error');

      await tester.pumpWidget(buildTestWidget(authService: fakeAuth));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('delete_account_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('delete_account_confirm_button')));
      await tester.pump();
      await tester.pump();

      expect(find.text('Network error'), findsOneWidget);
      expect(find.byKey(const Key('account_settings_modal_title')), findsOneWidget);
    });
  });
}
