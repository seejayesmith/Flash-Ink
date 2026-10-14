import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';

import 'package:flash_ink/models/artist.dart';
import 'package:flash_ink/models/artist_dashboard_data.dart';
import 'package:flash_ink/screens/artist_dashboard/appointment_detail_screen.dart';
import 'package:flash_ink/screens/artist_dashboard/artist_account_screen.dart';
import 'package:flash_ink/screens/artist_dashboard/artist_earnings_screen.dart';
import 'package:flash_ink/services/auth_service.dart';

class MockEarningsUser extends Fake implements User {
  @override
  final String uid;
  @override
  final String? displayName;
  @override
  final String? email;
  @override
  final String? photoURL;

  MockEarningsUser({required this.uid, this.displayName, this.email, this.photoURL});
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

    testWidgets('Renders all core earnings sections matching visual mockup in Overview tab',
        (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // 1. Top action bar
      expect(find.byKey(const Key('earnings_tattoo_logo')), findsOneWidget);
      expect(find.byKey(const Key('earnings_avatar_button')), findsOneWidget);

      // 2. Segmented tab bar
      expect(find.byKey(const Key('earnings_segmented_tab_bar')), findsOneWidget);
      expect(find.byKey(const Key('earnings_tab_overview')), findsOneWidget);
      expect(find.byKey(const Key('earnings_tab_history')), findsOneWidget);
      expect(find.text('Overview'), findsOneWidget);
      expect(find.text('History'), findsOneWidget);

      // 3. Available Funds card
      expect(find.byKey(const Key('available_funds_card')), findsOneWidget);
      expect(find.text('Available Funds'), findsOneWidget);
      expect(find.text('\$1,256'), findsOneWidget);
      expect(find.text('.09'), findsOneWidget);
      expect(find.text('Transfer to Bank'), findsOneWidget);
      expect(find.byKey(const Key('instant_transfer_button')), findsOneWidget);

      // 4. Embedded YTD Earnings card inside Hero Container
      expect(find.byKey(const Key('hero_ytd_earnings')), findsOneWidget);
      expect(find.text('2026 YTD EARNINGS'), findsOneWidget);
      expect(find.text('\$16,987'), findsOneWidget);
      expect(find.textContaining('MTD: \$3,467'), findsOneWidget);

      // 5. Past Bookings section removed from Overview per design decision
      expect(find.text('Past Bookings'), findsNothing);

      // 6. Quick utility actions
      expect(find.byKey(const Key('action_tax_docs')), findsOneWidget);
      expect(find.byKey(const Key('action_bank_info')), findsOneWidget);
      expect(find.text('Tax Docs'), findsOneWidget);
      expect(find.text('Bank Info'), findsOneWidget);
    });

    testWidgets('Switching to History tab renders searchable day-grouped sessions',
        (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Tap on History tab
      await tester.tap(find.byKey(const Key('earnings_tab_history')));
      await tester.pumpAndSettle();

      // History view and search bar are visible
      expect(find.byKey(const Key('earnings_history_view')), findsOneWidget);
      expect(find.byKey(const Key('history_search_field')), findsOneWidget);

      // Day group date headers and session cards are visible
      expect(find.text('Sep 9, 2026'), findsOneWidget);
      expect(find.text('Marcus Cole'), findsWidgets);
      expect(find.text('Elena Rostova'), findsOneWidget);

      // Full price and badges are present
      expect(find.text('\$50'), findsWidgets);
      expect(find.text('CONSULTATION'), findsWidgets);
    });

    testWidgets('Search bar in History tab dynamically filters sessions',
        (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Tap on History tab
      await tester.tap(find.byKey(const Key('earnings_tab_history')));
      await tester.pumpAndSettle();

      // Enter search query
      await tester.enterText(find.byKey(const Key('history_search_field')), 'Marcus');
      await tester.pumpAndSettle();

      expect(find.text('Marcus Cole'), findsWidgets);
      expect(find.text('Elena Rostova'), findsNothing);

      // Clear search button resets
      expect(find.byKey(const Key('history_search_clear_button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('history_search_clear_button')));
      await tester.pumpAndSettle();

      expect(find.text('Elena Rostova'), findsOneWidget);
    });

    testWidgets('Tapping a session card in History tab navigates to AppointmentDetailScreen',
        (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Tap on History tab
      await tester.tap(find.byKey(const Key('earnings_tab_history')));
      await tester.pumpAndSettle();

      // Tap on Marcus Cole session item
      final marcusItem = find.byKey(const Key('history_appointment_item_cal_apt_marcus_1'));
      expect(marcusItem, findsOneWidget);
      await tester.tap(marcusItem);
      await tester.pumpAndSettle();

      // Verify AppointmentDetailScreen is opened
      expect(find.byType(AppointmentDetailScreen), findsOneWidget);
      expect(find.text('Appointment Details'), findsOneWidget);
      expect(find.text('Marcus Cole'), findsOneWidget);
    });

    testWidgets('Tapping Tax Docs opens tax documents modal', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -300));
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

      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -300));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('action_bank_info')));
      await tester.pumpAndSettle();

      expect(find.text('Bank & Payout Info'), findsOneWidget);
      expect(find.text('Chase Bank •••• 4821'), findsOneWidget);
      expect(find.text('Instant Payouts enabled to debit card.'),
          findsOneWidget);
      expect(find.text('Update Payout Method'), findsOneWidget);
    });

    testWidgets('Tapping avatar opens ArtistAccountScreen with profile and settings', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('earnings_avatar_button')));
      await tester.pumpAndSettle();

      expect(find.byType(ArtistAccountScreen), findsOneWidget);
      expect(find.byKey(const Key('artist_account_view_public_profile_button')), findsOneWidget);
      expect(find.byKey(const Key('artist_account_sign_out_button')), findsOneWidget);
    });

    testWidgets('Tapping Instant Transfer opens Stripe modal and initiates transfer',
        (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('instant_transfer_button')));
      await tester.pumpAndSettle();

      expect(find.text('Instant Stripe Transfer'), findsOneWidget);
      expect(find.text('Direct deposit via Stripe Connect'), findsOneWidget);
      expect(find.text('Destination: Chase Bank •••• 4821'), findsOneWidget);
      expect(find.byKey(const Key('confirm_instant_transfer_button')),
          findsOneWidget);

      await tester.tap(find.byKey(const Key('confirm_instant_transfer_button')));
      await tester.pumpAndSettle();

      expect(
          find.textContaining('Transfer of \$1237.25 initiated via Stripe Direct Deposit.'),
          findsOneWidget);
    });
  });
}
