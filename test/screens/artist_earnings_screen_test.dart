import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';

import 'package:flash_ink/models/artist.dart';
import 'package:flash_ink/models/artist_dashboard_data.dart';
import 'package:flash_ink/screens/artist_dashboard/artist_earnings_screen.dart';
import 'package:flash_ink/services/auth_service.dart';

class MockEarningsUser extends Fake implements User {
  @override
  final String uid;
  @override
  final String? displayName;

  MockEarningsUser({required this.uid, this.displayName});
}

class FakeEarningsAuthService extends AuthService {
  final MockEarningsUser user =
      MockEarningsUser(uid: 'artist_oddmaree', displayName: 'OddMaree');
  bool signedOut = false;

  @override
  User? get currentUser => user;

  @override
  Future<void> signOut() async {
    signedOut = true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  group('ArtistEarningsScreen Widget Tests', () {
    late FakeEarningsAuthService fakeAuth;

    setUp(() {
      fakeAuth = FakeEarningsAuthService();
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

    Widget buildTestWidget({
      Artist? artist,
      bool isEmbeddedInTab = true,
      VoidCallback? onBack,
      ArtistEarningsData? data,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: ArtistEarningsScreen(
            artist: artist,
            authService: fakeAuth,
            isEmbeddedInTab: isEmbeddedInTab,
            onBack: onBack,
            earningsData: data,
          ),
        ),
      );
    }

    testWidgets('Renders all core earnings sections matching visual mockup',
        (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // 1. Top action bar
      expect(find.byKey(const Key('earnings_tattoo_logo')), findsOneWidget);
      expect(find.byKey(const Key('earnings_avatar_button')), findsOneWidget);

      // 2. Next Payout card
      expect(find.byKey(const Key('next_payout_card')), findsOneWidget);
      expect(find.text('Next Payout'), findsOneWidget);
      expect(find.text('\$1,256'), findsOneWidget);
      expect(find.text('.09'), findsOneWidget);
      expect(find.text('Friday August 14th'), findsOneWidget);

      // 3. Earnings section header
      expect(find.text('Earnings'), findsOneWidget);

      // 4. MTD and YTD metric cards
      expect(find.byKey(const Key('metric_card_mtd')), findsOneWidget);
      expect(find.byKey(const Key('metric_card_ytd')), findsOneWidget);
      expect(find.text('MTD'), findsOneWidget);
      expect(find.text('AUGUST'), findsOneWidget);
      expect(find.text('\$3,467'), findsOneWidget);
      expect(find.text('YTD'), findsOneWidget);
      expect(find.text('2026'), findsOneWidget);
      expect(find.text('\$16,987'), findsOneWidget);

      // 5. Past Bookings section
      expect(find.text('Past Bookings'), findsOneWidget);
      expect(find.byKey(const Key('past_bookings_view_all_button')),
          findsOneWidget);
      expect(find.text('Full Sleeve Session - Alex M.'), findsOneWidget);
      expect(find.text('Completed • Oct 24, 2023'), findsOneWidget);
      expect(find.text('\$800.00'), findsOneWidget);
      expect(find.text('Custom Flash - Sarah T.'), findsOneWidget);
      expect(find.text('Completed • Oct 22, 2023'), findsOneWidget);
      expect(find.text('\$250.00'), findsOneWidget);

      // 6. Quick utility actions
      expect(find.byKey(const Key('action_tax_docs')), findsOneWidget);
      expect(find.byKey(const Key('action_bank_info')), findsOneWidget);
      expect(find.text('Tax Docs'), findsOneWidget);
      expect(find.text('Bank Info'), findsOneWidget);
    });

    testWidgets('Tapping a past booking opens the Booking Receipt modal',
        (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Full Sleeve Session - Alex M.'));
      await tester.pumpAndSettle();

      expect(find.text('Booking Receipt'), findsOneWidget);
      expect(find.text('Session Subtotal'), findsOneWidget);
      expect(find.text('Net Deposit'), findsOneWidget);
      expect(find.text('Download PDF'), findsOneWidget);

      await tester.tap(find.text('Download PDF'));
      await tester.pumpAndSettle();

      expect(find.text('Receipt #REC-2023-9041 downloaded.'), findsOneWidget);
    });

    testWidgets('Tapping View All opens complete past bookings list',
        (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('past_bookings_view_all_button')));
      await tester.pumpAndSettle();

      expect(find.text('Past Bookings & Payouts'), findsOneWidget);
      expect(find.text('Fine Line Floral - Marcus K.'), findsOneWidget);
      expect(find.text('Micro Realism Eye - Elena R.'), findsOneWidget);
    });

    testWidgets('Tapping Tax Docs opens tax documents modal', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('action_tax_docs')));
      await tester.pumpAndSettle();

      expect(find.text('Tax Documents'), findsOneWidget);
      expect(find.text('2025 Form 1099-K'), findsOneWidget);
      expect(find.text('W-9 Form & Tax ID'), findsOneWidget);
      expect(find.text('Verified'), findsOneWidget);
    });

    testWidgets('Tapping Bank Info opens banking and payout details modal',
        (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('action_bank_info')));
      await tester.pumpAndSettle();

      expect(find.text('Bank & Payout Info'), findsOneWidget);
      expect(find.text('Chase Bank •••• 4821'), findsOneWidget);
      expect(find.text('Instant Payouts enabled to debit card.'),
          findsOneWidget);
      expect(find.text('Update Payout Method'), findsOneWidget);
    });

    testWidgets('Tapping avatar opens profile options modal', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('earnings_avatar_button')));
      await tester.pumpAndSettle();

      expect(find.text('View Public Profile'), findsOneWidget);
      expect(find.byKey(const Key('modal_sign_out')), findsOneWidget);
    });
  });
}
