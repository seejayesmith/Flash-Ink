import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flash_ink/core/mock/mock_data_config.dart';
import 'package:flash_ink/models/artist_dashboard_data.dart';
import 'package:flash_ink/screens/artist_dashboard/booking_request_detail_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  group('Custom Request Review & Presets Tests', () {
    late BookingRequest testRequest;

    setUp(() {
      MockDataConfig.debugOverride = true;
      ArtistDashboardRepository.resetMockData();
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      binding.platformDispatcher.views.first.physicalSize = const Size(1080, 2400);
      binding.platformDispatcher.views.first.devicePixelRatio = 1.0;

      testRequest = const BookingRequest(
        id: 'req_test_custom_1',
        clientName: 'Jordan K.',
        conceptDescription: 'Neo-traditional serpent with peony flowers',
        placement: 'Right Forearm',
        category: 'Neo-traditional',
        estimatedPrice: 350,
        deposit: 75,
        timeAgo: '2h ago',
        sketchImageUrl: 'assets/images/flash_tiger_tattoo.jpg',
      );
    });

    tearDown(() {
      MockDataConfig.resetDebugOverride();
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      binding.platformDispatcher.views.first.resetPhysicalSize();
      binding.platformDispatcher.views.first.resetDevicePixelRatio();
    });

    testWidgets('Proposing time slot creates 24-hour hold in repository', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BookingRequestDetailScreen(request: testRequest),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Propose New Time
      final proposeBtn = find.byKey(const Key('propose_time_button'));
      expect(proposeBtn, findsOneWidget);
      await tester.ensureVisible(proposeBtn);
      await tester.tap(proposeBtn);
      await tester.pumpAndSettle();

      // Modal is open
      expect(find.text('Propose Session Time & Quote'), findsOneWidget);
      final sendProposalBtn = find.text('Send Proposal & Hold Slot (24h)');
      expect(sendProposalBtn, findsOneWidget);

      await tester.tap(sendProposalBtn);
      await tester.pumpAndSettle();

      // Verify a CustomHold was created
      final holds = ArtistDashboardRepository.customHolds;
      expect(holds.any((h) => h.requestId == testRequest.id), isTrue);
      final hold = holds.firstWhere((h) => h.requestId == testRequest.id);
      expect(hold.clientName, 'Jordan K.');
      expect(hold.isExpired, isFalse);
    });

    testWidgets('Tapping Ask Details opens multi-select presets sheet', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BookingRequestDetailScreen(request: testRequest),
        ),
      );
      await tester.pumpAndSettle();

      final askBtn = find.byKey(const Key('ask_info_button'));
      expect(askBtn, findsOneWidget);
      await tester.ensureVisible(askBtn);
      await tester.tap(askBtn);
      await tester.pumpAndSettle();

      // Verify preset sheet
      expect(find.text('Ask for More Details'), findsOneWidget);
      expect(find.text('Size in inches'), findsOneWidget);
      expect(find.text('Reference photos'), findsOneWidget);
      expect(find.text('Exact placement'), findsOneWidget);

      // Verify message preview contains Jordan's name
      expect(find.textContaining('Hey Jordan K.!'), findsOneWidget);

      // Tap Send Message
      final sendBtn = find.byKey(const Key('send_ask_info_message_button'));
      expect(sendBtn, findsOneWidget);
      await tester.tap(sendBtn);
      await tester.pumpAndSettle();

      expect(find.text('Ask for More Details'), findsNothing);
    });

    testWidgets('Tapping Pass with Presets opens gentle pass sheet with style redirection', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BookingRequestDetailScreen(request: testRequest),
        ),
      );
      await tester.pumpAndSettle();

      final passBtn = find.byKey(const Key('pass_request_button'));
      expect(passBtn, findsOneWidget);
      await tester.ensureVisible(passBtn);
      await tester.tap(passBtn);
      await tester.pumpAndSettle();

      // Verify pass sheet
      expect(find.text('Pass on this Request'), findsOneWidget);
      expect(find.text('Outside my style'), findsOneWidget);
      expect(find.text('Too big for current books'), findsOneWidget);
      expect(find.textContaining('Flash.Ink will guide client to: Recommend other Flash artists'), findsOneWidget);

      // Confirm pass
      final confirmBtn = find.byKey(const Key('confirm_pass_button'));
      expect(confirmBtn, findsOneWidget);
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // Request is removed from pending
      expect(ArtistDashboardRepository.pendingRequests.any((r) => r.id == testRequest.id), isFalse);
    });

    testWidgets('Modals render cleanly on compact iPhone SE viewport (375x667) without overflow', (tester) async {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      binding.platformDispatcher.views.first.physicalSize = const Size(375, 667);
      binding.platformDispatcher.views.first.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        MaterialApp(
          home: BookingRequestDetailScreen(request: testRequest),
        ),
      );
      await tester.pumpAndSettle();

      final proposeBtn = find.byKey(const Key('propose_time_button'));
      await tester.ensureVisible(proposeBtn);
      await tester.tap(proposeBtn);
      await tester.pumpAndSettle();
      expect(find.text('QUOTE & DEPOSIT'), findsOneWidget);
      expect(find.byKey(const Key('confirm_proposal_button')), findsOneWidget);

      // Dismiss and test Ask Details
      Navigator.of(tester.element(find.byKey(const Key('confirm_proposal_button')))).pop();
      await tester.pumpAndSettle();

      final askBtn = find.byKey(const Key('ask_info_button'));
      await tester.ensureVisible(askBtn);
      await tester.tap(askBtn);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('send_ask_info_message_button')), findsOneWidget);
    });
  });
}
