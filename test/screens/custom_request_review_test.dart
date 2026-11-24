import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flash_ink/core/mock/mock_data_config.dart';
import 'package:flash_ink/features/messages/domain/models/message_thread.dart';
import 'package:flash_ink/features/messages/presentation/widgets/proposal_options_message_tile.dart';
import 'package:flash_ink/models/artist_dashboard/artist_books_schedule.dart';
import 'package:flash_ink/models/artist_dashboard/booking_request.dart';
import 'package:flash_ink/repositories/artist_dashboard_repository.dart';
import 'package:flash_ink/screens/artist_dashboard/booking_request_detail_screen.dart';
import 'package:flash_ink/widgets/adaptive_glass_container.dart';

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

    testWidgets('Artist can propose up to 3 dates/times with custom duration and posts proposal card to chat', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      ArtistDashboardRepository.booksSchedule =
          ArtistDashboardRepository.booksSchedule.copyWith(
        workingDays: const {1, 2, 3, 4, 5, 6, 7},
      );

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

      // Modal is open with frosted glass overlay and 1 default option pre-selected
      expect(find.text('Propose Session Time & Quote'), findsOneWidget);
      final sheetGlass = tester.widget<AdaptiveGlassContainer>(
        find.byType(AdaptiveGlassContainer).first,
      );
      expect(sheetGlass.glassEnabled, isTrue);
      expect(find.byType(BackdropFilter), findsWidgets);
      expect(find.text('PROPOSED OPTIONS (1/3)'), findsOneWidget);

      // Select 2 more open time slots to reach 3/3
      final slot300 = find.byKey(const Key('proposal_slot_3:00 PM'));
      final slot430 = find.byKey(const Key('proposal_slot_4:30 PM'));
      await tester.ensureVisible(slot300);
      await tester.tap(slot300);
      await tester.pumpAndSettle();
      await tester.ensureVisible(slot430);
      await tester.tap(slot430);
      await tester.pumpAndSettle();
      expect(find.text('PROPOSED OPTIONS (3/3)'), findsOneWidget);

      // Attempting a 4th slot shows max-3 hint instead of exceeding 3
      final slot600 = find.byKey(const Key('proposal_slot_6:00 PM'));
      await tester.ensureVisible(slot600);
      await tester.tap(slot600);
      await tester.pumpAndSettle();
      expect(find.text('PROPOSED OPTIONS (3/3)'), findsOneWidget);
      expect(
        find.text('You can propose up to 3 times. Remove one to pick another.'),
        findsOneWidget,
      );

      // Select 4 hrs duration
      final dur240 = find.byKey(const Key('proposal_duration_240'));
      await tester.ensureVisible(dur240);
      await tester.tap(dur240);
      await tester.pumpAndSettle();

      final sendProposalBtn = find.byKey(const Key('confirm_proposal_button'));
      expect(find.text('Send 3 Proposed Times'), findsOneWidget);
      await tester.ensureVisible(sendProposalBtn);
      await tester.tap(sendProposalBtn);
      await tester.pumpAndSettle();

      // Verify proposal message was posted in the custom chat thread with 3 options and 240 min duration
      final thread = MessageThread.activeThreads.firstWhere(
        (t) => t.id == 'thread_custom_${testRequest.id}',
      );
      final proposalMsg = thread.messages.last;
      expect(proposalMsg.type, ChatMessageType.proposal);
      expect(proposalMsg.proposedSlots.length, 3);
      expect(proposalMsg.appointmentDurationMinutes, 240);
      expect(proposalMsg.estimatedTotalPrice, 350);
      expect(proposalMsg.receiptAmount, 75.0);
    });

    testWidgets('Client selecting a proposed time taken 15h later is blocked from double-booking and can pick another open option', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final fakeDb = FakeFirebaseFirestore();
      final now = DateTime.now();
      final dayA = DateTime(now.year, now.month, now.day + 4);
      final dayB = DateTime(now.year, now.month, now.day + 5);
      final keyA = ArtistBooksSchedule.dateKey(dayA);

      await fakeDb.collection('artist_schedules').doc('artist_prop_1').set({
        'isBooksOpen': true,
        'bookingWindowStart': DateTime(now.year, now.month, 1).toIso8601String(),
        'bookingWindowEnd': DateTime(now.year, now.month + 3, 1).toIso8601String(),
        'workingDays': [1, 2, 3, 4, 5, 6, 7],
        'bookedSlots': [],
      });

      final proposalMsg = ChatMessage(
        id: 'proposal_race_1',
        senderId: 'artist_prop_1',
        senderName: 'OddMaree',
        text: 'OddMaree proposed 3 session times.',
        timestamp: now,
        isFromArtist: true,
        type: ChatMessageType.proposal,
        receiptAmount: 100.0,
        estimatedTotalPrice: 450,
        appointmentDurationMinutes: 180,
        artistName: 'OddMaree',
        studioLocation: 'OddMaree Studio',
        flashTitle: 'Custom: Fine Line',
        placement: 'Forearm',
        requestId: testRequest.id,
        proposedSlots: [
          ProposedTimeOption(date: dayA, timeSlot: '3:00 PM'),
          ProposedTimeOption(date: dayA, timeSlot: '4:30 PM'),
          ProposedTimeOption(date: dayB, timeSlot: '1:30 PM'),
        ],
      );
      final thread = MessageThread(
        id: 'thread_custom_${testRequest.id}',
        artistId: 'artist_prop_1',
        clientId: 'client_1',
        clientName: 'Jordan K.',
        artistName: 'OddMaree',
        artistAvatar: '',
        studioName: 'OddMaree Studio',
        lastMessage: proposalMsg.text,
        lastMessageTime: now,
        unreadCount: 1,
        messages: [proposalMsg],
      );
      MessageThread.addThread(thread);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ProposalOptionsMessageTile(
                message: proposalMsg,
                thread: thread,
                isArtistView: false,
                firestore: fakeDb,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Client selects option 0 (dayA at 3:00 PM)
      await tester.tap(find.byKey(const Key('proposal_option_0')));
      await tester.pumpAndSettle();

      // Before client taps Confirm, another client takes dayA at 3:00 PM!
      await fakeDb.collection('artist_schedules').doc('artist_prop_1').set({
        'bookedSlots': [
          {'date': keyA, 'time': '3:00 PM'},
        ],
      }, SetOptions(merge: true));

      await tester.tap(find.byKey(const Key('confirm_proposed_slot_button')));
      await tester.pumpAndSettle();

      // Double-booking is blocked, option 0 is marked Taken, and error banner appears
      expect(find.text('Taken'), findsOneWidget);
      expect(find.text('SESSION TIME CONFIRMED'), findsNothing);
      expect(
        find.textContaining('That time slot is no longer available'),
        findsOneWidget,
      );

      // Client instead selects option 2 (dayB at 1:30 PM), which is still open
      await tester.tap(find.byKey(const Key('proposal_option_2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm_proposed_slot_button')));
      await tester.pumpAndSettle();

      // Confirmed cleanly!
      expect(find.text('SESSION TIME CONFIRMED'), findsOneWidget);
      expect(find.text('Confirmed'), findsOneWidget);
      expect(
        ArtistDashboardRepository.calendarAppointments.any(
          (a) => a.time == '1:30 PM' && a.clientName == 'Jordan K.',
        ),
        isTrue,
      );
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
