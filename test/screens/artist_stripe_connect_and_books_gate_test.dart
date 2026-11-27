import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flash_ink/core/mock/mock_data_config.dart';
import 'package:flash_ink/repositories/artist_dashboard_repository.dart';
import 'package:flash_ink/screens/artist_dashboard/books_status_card.dart';
import 'package:flash_ink/screens/artist_dashboard/artist_dashboard_screen.dart';
import 'package:flash_ink/screens/artist_onboarding/artist_share_link_screen.dart';
import 'package:flash_ink/screens/artist_onboarding/artist_stripe_setup_screen.dart';
import 'package:flash_ink/services/auth_service.dart';
import 'package:flash_ink/services/stripe_service.dart';
import '../helpers/fake_recovery_functions.dart';

class _FakeConnectFunctions extends Fake implements FirebaseFunctions {
  final List<RecordedCallableInvocation> invocations = [];
  Map<String, dynamic> Function(String name, Map<String, dynamic> data)?
      handler;

  @override
  HttpsCallable httpsCallable(String name, {HttpsCallableOptions? options}) {
    return _FakeConnectCallable(name, this);
  }

  Map<String, dynamic> _dispatch(String name, Map<String, dynamic> data) {
    invocations.add(RecordedCallableInvocation(name, data));
    return handler != null ? handler!(name, data) : const {};
  }
}

class _FakeConnectCallable extends Fake implements HttpsCallable {
  final String name;
  final _FakeConnectFunctions backend;

  _FakeConnectCallable(this.name, this.backend);

  @override
  Future<HttpsCallableResult<T>> call<T>([dynamic parameters]) async {
    final data = <String, dynamic>{
      if (parameters is Map)
        for (final entry in parameters.entries)
          entry.key.toString(): entry.value,
    };
    final result = backend._dispatch(name, data);
    return _FakeConnectCallableResult<T>(result as T);
  }
}

class _FakeConnectCallableResult<T> extends Fake
    implements HttpsCallableResult<T> {
  @override
  final T data;

  _FakeConnectCallableResult(this.data);
}

class _FakeUser extends Fake implements User {
  @override
  String get uid => 'artist_stripe_test_uid';

  @override
  String? get email => 'ink@flash.ink';

  @override
  String? get displayName => 'OddMaree';

  @override
  String? get phoneNumber => '+15035550199';

  @override
  String? get photoURL => null;
}

class _FakeAuthService extends Fake implements AuthService {
  final User _user = _FakeUser();

  @override
  User? get currentUser => _user;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.physicalSize =
        const Size(1080, 2400);
    binding.platformDispatcher.views.first.devicePixelRatio = 1.0;
    MockDataConfig.debugOverride = false;
    ArtistDashboardRepository.resetMockData();
    ArtistDashboardRepository.stripePayoutsReady = false;
    ArtistDashboardRepository.closeBooks();
  });

  tearDown(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.resetPhysicalSize();
    binding.platformDispatcher.views.first.resetDevicePixelRatio();
    MockDataConfig.resetDebugOverride();
  });

  group('Live Stripe Connect Links & Status Sync', () {
    test(
      'launchStripeConnectOnboarding invokes createStripeConnectAccountLink and opens returned Stripe URL',
      () async {
        final fakeFunctions = _FakeConnectFunctions()
          ..handler = (name, data) {
            expect(name, 'createStripeConnectAccountLink');
            expect(data['email'], 'ink@flash.ink');
            expect(data['artistName'], 'OddMaree');
            return {
              'url': 'https://connect.stripe.com/setup/e/acct_live_123/secret',
              'hasAccount': true,
              'stripeAccountId': 'acct_live_123',
              'stripePayoutsReady': false,
              'payoutsEnabled': false,
              'chargesEnabled': false,
              'detailsSubmitted': false,
            };
          };

        Uri? launchedUri;
        final service = StripeService(
          functions: fakeFunctions,
          isProductionOverride: true,
          urlLauncher: (uri) async {
            launchedUri = uri;
            return true;
          },
        );

        final status = await service.launchStripeConnectOnboarding(
          email: 'ink@flash.ink',
          artistName: 'OddMaree',
        );

        expect(status.hasError, isFalse);
        expect(status.hasAccount, isTrue);
        expect(status.stripeAccountId, 'acct_live_123');
        expect(status.stripePayoutsReady, isFalse);
        expect(
          launchedUri?.toString(),
          'https://connect.stripe.com/setup/e/acct_live_123/secret',
        );
      },
    );

    test(
      'syncStripeConnectStatus updates ArtistDashboardRepository.stripePayoutsReady when verified',
      () async {
        final fakeFunctions = _FakeConnectFunctions()
          ..handler = (name, _) {
            expect(name, 'syncStripeConnectStatus');
            return {
              'hasAccount': true,
              'stripeAccountId': 'acct_live_123',
              'stripePayoutsReady': true,
              'payoutsEnabled': true,
              'chargesEnabled': true,
              'detailsSubmitted': true,
              'externalAccountLabel': 'Chase Bank •••• 4242',
            };
          };

        final service = StripeService(
          functions: fakeFunctions,
          isProductionOverride: true,
        );

        expect(ArtistDashboardRepository.stripePayoutsReady, isFalse);
        final synced = await service.syncStripeConnectStatus();

        expect(synced.stripePayoutsReady, isTrue);
        expect(synced.externalAccountLabel, 'Chase Bank •••• 4242');
        expect(ArtistDashboardRepository.stripePayoutsReady, isTrue);
      },
    );
  });

  group('ArtistStripeSetupScreen & Onboarding Books Persistence', () {
    testWidgets(
      'Skipping Stripe ("Do this later") persists isBooksOpen: false on Firestore when completing onboarding',
      (tester) async {
        final fakeDb = FakeFirebaseFirestore();
        final fakeAuth = _FakeAuthService();

        await tester.pumpWidget(
          MaterialApp(
            home: ArtistStripeSetupScreen(
              artistName: 'OddMaree',
              instagramHandle: '@OddMaree',
              minDeposit: 100,
              authService: fakeAuth,
              firestore: fakeDb,
            ),
          ),
        );

        await tester.ensureVisible(
          find.byKey(const Key('do_stripe_later_button')),
        );
        await tester.tap(find.byKey(const Key('do_stripe_later_button')));
        await tester.pumpAndSettle();

        expect(find.byType(ArtistShareLinkScreen), findsOneWidget);

        await tester.tap(find.byKey(const Key('done_share_button')));
        await tester.pumpAndSettle();

        expect(find.byType(ArtistDashboardScreen), findsOneWidget);
        final savedDoc = await fakeDb
            .collection('artists')
            .doc('artist_stripe_test_uid')
            .get();
        expect(savedDoc.exists, isTrue);
        expect(savedDoc.data()?['isBooksOpen'], isFalse);
        expect(ArtistDashboardRepository.booksSchedule.isBooksOpen, isFalse);
      },
    );

    testWidgets(
      'Connecting Stripe and refreshing status unlocks verified badge and saves isBooksOpen: true',
      (tester) async {
        final fakeDb = FakeFirebaseFirestore();
        final fakeAuth = _FakeAuthService();
        Uri? openedUrl;

        final fakeFunctions = _FakeConnectFunctions()
          ..handler = (name, _) {
            if (name == 'createStripeConnectAccountLink') {
              return {
                'url': 'https://connect.stripe.com/setup/e/acct_live_999/link',
                'hasAccount': true,
                'stripeAccountId': 'acct_live_999',
                'stripePayoutsReady': false,
                'payoutsEnabled': false,
                'chargesEnabled': false,
                'detailsSubmitted': false,
              };
            }
            return {
              'hasAccount': true,
              'stripeAccountId': 'acct_live_999',
              'stripePayoutsReady': true,
              'payoutsEnabled': true,
              'chargesEnabled': true,
              'detailsSubmitted': true,
              'externalAccountLabel': 'Bank Account •••• 8888',
            };
          };

        final stripeService = StripeService(
          functions: fakeFunctions,
          isProductionOverride: true,
          urlLauncher: (uri) async {
            openedUrl = uri;
            return true;
          },
        );

        await tester.pumpWidget(
          MaterialApp(
            home: ArtistStripeSetupScreen(
              artistName: 'OddMaree',
              instagramHandle: '@OddMaree',
              minDeposit: 100,
              authService: fakeAuth,
              firestore: fakeDb,
              stripeService: stripeService,
            ),
          ),
        );

        await tester.tap(
          find.byKey(const Key('connect_stripe_onboarding_button')),
        );
        await tester.pumpAndSettle();

        expect(
          openedUrl?.toString(),
          'https://connect.stripe.com/setup/e/acct_live_999/link',
        );
        expect(find.byKey(const Key('stripe_pending_card')), findsOneWidget);

        // Artist finishes in browser and taps Refresh
        await tester.tap(
          find.byKey(const Key('refresh_stripe_status_button')),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('stripe_connected_card')), findsOneWidget);
        expect(
          find.textContaining('Bank Account •••• 8888'),
          findsOneWidget,
        );

        // Allow the success SnackBar overlay to auto-dismiss before tapping Continue
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('continue_stripe_connected_button')),
        );
        await tester.pumpAndSettle();

        expect(find.byType(ArtistShareLinkScreen), findsOneWidget);
        await tester.tap(find.byKey(const Key('done_share_button')));
        await tester.pumpAndSettle();

        final savedDoc = await fakeDb
            .collection('artists')
            .doc('artist_stripe_test_uid')
            .get();
        expect(savedDoc.data()?['isBooksOpen'], isTrue);
      },
    );
  });

  group('Books Opening Gate Without Stripe', () {
    testWidgets(
      'BooksStatusCard prevents opening books when stripePayoutsReady is false, opens Stripe gate sheet, and opens books once verified',
      (tester) async {
        final fakeFunctions = _FakeConnectFunctions()
          ..handler = (name, _) {
            if (name == 'createStripeConnectAccountLink') {
              return {
                'url': 'https://connect.stripe.com/setup/e/acct_gate_1/link',
                'hasAccount': true,
                'stripeAccountId': 'acct_gate_1',
                'stripePayoutsReady': false,
                'payoutsEnabled': false,
                'chargesEnabled': false,
                'detailsSubmitted': false,
              };
            }
            return {
              'hasAccount': true,
              'stripeAccountId': 'acct_gate_1',
              'stripePayoutsReady': true,
              'payoutsEnabled': true,
              'chargesEnabled': true,
              'detailsSubmitted': true,
            };
          };

        final stripeService = StripeService(
          functions: fakeFunctions,
          isProductionOverride: true,
          urlLauncher: (_) async => true,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  return BooksStatusCard(
                    stripeService: stripeService,
                    onStatusChanged: () => setState(() {}),
                  );
                },
              ),
            ),
          ),
        );

        expect(find.text('PAYOUT SETUP REQUIRED'), findsOneWidget);
        expect(find.text('Connect Stripe to Open Books'), findsOneWidget);
        expect(ArtistDashboardRepository.booksSchedule.isBooksOpen, isFalse);

        // Attempt to flip switch ON -> opens gate sheet instead of opening books
        await tester.tap(find.byKey(const Key('books_status_switch')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('stripe_payout_gate_sheet')),
          findsOneWidget,
        );
        expect(ArtistDashboardRepository.booksSchedule.isBooksOpen, isFalse);

        // Tap "I finished — Check Status" inside gate sheet -> verifies & auto-opens books
        await tester.tap(find.byKey(const Key('gate_refresh_stripe_button')));
        await tester.pumpAndSettle();

        expect(ArtistDashboardRepository.stripePayoutsReady, isTrue);
        expect(ArtistDashboardRepository.booksSchedule.isBooksOpen, isTrue);
        expect(find.text('BOOKS OPEN'), findsOneWidget);
      },
    );
  });
}
