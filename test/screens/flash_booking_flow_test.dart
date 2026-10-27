import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flash_ink/core/mock/mock_data_config.dart';
import 'package:flash_ink/models/artist.dart';
import 'package:flash_ink/models/artist_dashboard_data.dart';
import 'package:flash_ink/features/appointments/domain/models/appointment_item.dart';
import 'package:flash_ink/features/messages/domain/models/message_thread.dart';
import 'package:flash_ink/screens/artist_dashboard/appointment_detail_screen.dart';
import 'package:flash_ink/screens/artist_dashboard/booking_request_detail_screen.dart';
import 'package:flash_ink/screens/booking/flash_booking_screen.dart';
import 'package:flash_ink/screens/flash_details_screen.dart';
import 'package:flash_ink/services/booking_sync_service.dart';
import 'package:flash_ink/widgets/flash_switch.dart';

void main() {
  group('Flash Booking Flow Tests', () {
    setUp(() {
      MockDataConfig.debugOverride = true;
      ArtistDashboardRepository.resetMockData();
    });

    tearDown(() {
      ArtistDashboardRepository.resetMockData();
      MockDataConfig.resetDebugOverride();
    });

    const testFlash = FlashArtwork(
      id: 'flash_test_101',
      artistId: 'artist_1',
      artistName: 'Maree Raven',
      title: 'Obsidian Serpent & Peony',
      imageUrl: 'https://images.unsplash.com/photo-1598371839696-5c5bb00bdc28',
      price: 250,
      deposit: 75,
      dimensions: '6" x 9"',
      estimatedTime: '3.0 hrs',
      location: 'Forearm / Calf',
      status: FlashStatus.available,
    );

    const testArtist = Artist(
      id: 'artist_1',
      name: 'Maree Raven',
      avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb',
      location: 'Downtown Arts District, LA',
      studioType: 'Private Studio',
      rating: 4.9,
      minDeposit: 75,
      availablePieces: 8,
      images: [],
    );

    testWidgets('Renders FlashBookingScreen Step 1 (Schedule) with calendar, time slots, and artwork recap',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: FlashBookingScreen(
            flash: testFlash,
            artist: testArtist,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Top Header & Stepper
      expect(find.text('Claim & Book Flash'), findsOneWidget);
      expect(find.text('Date & Time'), findsOneWidget);
      expect(find.text('Details'), findsOneWidget);
      expect(find.text('Payment'), findsOneWidget);
      expect(find.text('Confirmed'), findsOneWidget);

      // Artwork recap
      expect(find.text('Obsidian Serpent & Peony'), findsOneWidget);
      expect(find.text('by Maree Raven'), findsOneWidget);
      expect(find.text('Deposit: \$75 • Full: \$250'), findsOneWidget);

      // Calendar & Time slots
      expect(find.text('SELECT DATE'), findsOneWidget);
      expect(find.text('SELECT TIME SLOT'), findsOneWidget);
      expect(find.text('Session Est. 3.0 hrs'), findsOneWidget);
      expect(find.text('1:30 PM'), findsOneWidget);
      expect(find.text('3:00 PM'), findsOneWidget);

      // Placement & Silent appointment toggle
      expect(find.text('BODY PLACEMENT'), findsOneWidget);
      expect(find.text('Silent Appointment'), findsOneWidget);
      expect(find.text('CONTINUE TO DETAILS'), findsOneWidget);
    });

    testWidgets('Selecting time slot, toggling silent appointment, and proceeding to Step 2 (Details)',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: FlashBookingScreen(
            flash: testFlash,
            artist: testArtist,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap different time slot
      await tester.tap(find.text('3:00 PM'));
      await tester.pumpAndSettle();

      // Toggle silent appointment switch
      await tester.tap(find.byType(FlashSwitch));
      await tester.pumpAndSettle();

      // Tap CONTINUE TO DETAILS
      await tester.tap(find.text('CONTINUE TO DETAILS'));
      await tester.pumpAndSettle();

      // Verify Step 2 rendered
      expect(find.text('CLIENT INFORMATION'), findsOneWidget);
      expect(find.text('STUDIO POLICIES & TERMS'), findsOneWidget);
      expect(find.text('CONTINUE TO PAYMENT'), findsOneWidget);
      expect(find.text('Alex Rivers'), findsOneWidget);
    });

    testWidgets('Step 2: Policy checkbox controls proceed button to Step 3 (Payment)',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: FlashBookingScreen(
            flash: testFlash,
            artist: testArtist,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Go to Step 2
      await tester.tap(find.text('CONTINUE TO DETAILS'));
      await tester.pumpAndSettle();

      // Uncheck policies
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      // Attempt tapping Continue To Payment when disabled
      await tester.tap(find.text('CONTINUE TO PAYMENT'));
      await tester.pumpAndSettle();

      // Still on step 2
      expect(find.text('CLIENT INFORMATION'), findsOneWidget);

      // Check policies back on
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      // Tap Continue to payment
      await tester.tap(find.text('CONTINUE TO PAYMENT'));
      await tester.pumpAndSettle();

      // Verify Step 3 Payment Breakdown
      expect(find.text('PAYMENT BREAKDOWN'), findsOneWidget);
      expect(find.text('Total Flash Price'), findsOneWidget);
      expect(find.text('\$250'), findsOneWidget);
      expect(find.text('Deposit Due Today'), findsOneWidget);
      expect(find.text('\$75'), findsOneWidget);
      expect(find.text('Balance Due at Studio'), findsOneWidget);
      expect(find.text('\$175'), findsOneWidget);
      expect(find.text('PAY \$75 DEPOSIT & CONFIRM'), findsOneWidget);
    });

    testWidgets('Step 3: Processing payment transitions to Step 4 (Confirmation screen)',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: FlashBookingScreen(
            flash: testFlash,
            artist: testArtist,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Step 1 -> Step 2
      await tester.tap(find.text('CONTINUE TO DETAILS'));
      await tester.pumpAndSettle();

      // Step 2 -> Step 3
      await tester.tap(find.text('CONTINUE TO PAYMENT'));
      await tester.pumpAndSettle();

      // Select Credit Card
      await tester.tap(find.text('Credit Card (•••• 4242)'));
      await tester.pumpAndSettle();

      // Tap PAY DEPOSIT & CONFIRM
      await tester.tap(find.text('PAY \$75 DEPOSIT & CONFIRM'));
      await tester.pump(); // Starts loading

      // Wait for simulated payment processing
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pumpAndSettle();

      // Verify Step 4 Confirmation
      expect(find.text('Flash Claimed & Booked!'), findsOneWidget);
      expect(find.textContaining('Ref: INK-'), findsOneWidget);
      expect(find.text('ADD TO CALENDAR'), findsOneWidget);
      expect(find.text('SESSION PREPARATION TIPS'), findsOneWidget);
      expect(find.text('DONE'), findsOneWidget);

      // Verify End-to-End Persistence to Artist Calendar and Client Appointments
      final artistApt = ArtistDashboardRepository.calendarAppointments.firstWhere(
        (apt) => apt.serviceType.contains('Obsidian Serpent & Peony'),
      );
      expect(artistApt.clientName, 'Alex Rivers');
      expect(artistApt.depositPaid, 75);
      expect(artistApt.fullPrice, 250);

      final clientApt = ClientAppointment.mockUpcoming.firstWhere(
        (apt) => apt.flashTitle == 'Obsidian Serpent & Peony',
      );
      expect(clientApt.status, AppointmentStatus.confirmed);
      expect(clientApt.depositAmount, 75);
      expect(clientApt.totalPrice, 250);
    });

    testWidgets('End-to-End: Tapping CLAIM & BOOK FLASH in FlashDetailsScreen opens booking flow and marks artwork as claimed',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: FlashDetailsScreen(
            flash: testFlash,
            artist: testArtist,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify initial state
      expect(find.text('CLAIM & BOOK FLASH'), findsOneWidget);
      expect(find.text('EXCLUSIVE'), findsOneWidget);

      // Tap CLAIM & BOOK FLASH to launch flow
      await tester.tap(find.text('CLAIM & BOOK FLASH'));
      await tester.pumpAndSettle();

      // We are in FlashBookingScreen Step 1
      expect(find.text('SELECT DATE'), findsOneWidget);

      // Progress through flow: Step 1 -> Step 2
      await tester.tap(find.text('CONTINUE TO DETAILS'));
      await tester.pumpAndSettle();

      // Step 2 -> Step 3
      await tester.tap(find.text('CONTINUE TO PAYMENT'));
      await tester.pumpAndSettle();

      // Step 3 -> Pay
      await tester.tap(find.text('PAY \$75 DEPOSIT & CONFIRM'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pumpAndSettle();

      // We are on Confirmation screen
      expect(find.text('Flash Claimed & Booked!'), findsOneWidget);

      // Tap DONE to return
      await tester.ensureVisible(find.text('DONE'));
      await tester.tap(find.text('DONE'));
      await tester.pumpAndSettle();

      // Back on FlashDetailsScreen: verify artwork is now claimed!
      expect(find.text('PIECE ALREADY CLAIMED'), findsOneWidget);
      expect(find.text('CLAIMED'), findsOneWidget);
      expect(find.textContaining('Deposit \$75 confirmed'), findsOneWidget);
    });

    testWidgets('FlashDetailsScreen renders title and price with AppSpacing.spaceXl gap and maxLines: 2',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: FlashDetailsScreen(
            flash: testFlash,
            artist: testArtist,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final titleFinder = find.text(testFlash.title);
      expect(titleFinder, findsOneWidget);

      final Text titleWidget = tester.widget<Text>(titleFinder);
      expect(titleWidget.maxLines, 2);
      expect(titleWidget.overflow, TextOverflow.ellipsis);

      // Verify price is rendered
      expect(find.text('\$${testFlash.fullPrice}'), findsOneWidget);

      // Verify the 32px (AppSpacing.spaceXl) spacing SizedBox exists
      final sizedBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
      final has32pxGap = sizedBoxes.any((box) => box.width == 32.0);
      expect(has32pxGap, isTrue);
    });

    testWidgets('Placement selector opens glassmorphic bottom sheet, selects preset or custom placement',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: FlashBookingScreen(
            flash: testFlash,
            artist: testArtist,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Trigger is initially 'Forearm'
      expect(find.byKey(const Key('placement_selector_trigger')), findsOneWidget);
      expect(find.text('Forearm'), findsOneWidget);

      // Tap trigger to open bottom sheet
      await tester.tap(find.byKey(const Key('placement_selector_trigger')));
      await tester.pumpAndSettle();

      // Bottom sheet is displayed
      expect(find.text('Select Body Placement'), findsOneWidget);
      expect(find.text('Choose where you want this flash piece tattooed'), findsOneWidget);
      expect(find.byKey(const Key('placement_option_Thigh')), findsOneWidget);

      // Select 'Thigh'
      await tester.tap(find.byKey(const Key('placement_option_Thigh')));
      await tester.pumpAndSettle();

      // Bottom sheet dismissed, trigger updated
      expect(find.text('Select Body Placement'), findsNothing);
      expect(find.text('Thigh'), findsOneWidget);

      // Reopen sheet to select 'Other' with custom input
      await tester.tap(find.byKey(const Key('placement_selector_trigger')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('placement_option_Other')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('custom_placement_field')), findsOneWidget);
      await tester.enterText(find.byKey(const Key('custom_placement_field')), 'Collarbone');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('confirm_custom_placement_btn')));
      await tester.pumpAndSettle();

      // Sheet dismissed, trigger displays custom placement
      expect(find.text('Select Body Placement'), findsNothing);
      expect(find.text('Collarbone'), findsOneWidget);
    });

    testWidgets('ArtistBooksSchedule dynamically generates time slots when working hours or durations are customized',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Customize artist working hours: 10:00 AM to 3:30 PM, 60 min slot + 30 min buffer (90 min step)
      ArtistDashboardRepository.updateBooksSchedule(
        ArtistDashboardRepository.booksSchedule.copyWith(
          startTime: const TimeOfDay(hour: 10, minute: 0),
          endTime: const TimeOfDay(hour: 15, minute: 30),
          slotDurationMinutes: 60,
          bufferDurationMinutes: 30,
        ),
      );

      final generated = ArtistDashboardRepository.booksSchedule.generateTimeSlots();
      expect(generated.map((s) => s.time).toList(), ['10:00 AM', '11:30 AM', '1:00 PM', '2:30 PM']);

      await tester.pumpWidget(
        const MaterialApp(
          home: FlashBookingScreen(
            flash: testFlash,
            artist: testArtist,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('10:00 AM'), findsOneWidget);
      expect(find.text('1:00 PM'), findsOneWidget);
      expect(find.text('2:30 PM'), findsOneWidget);
    });

    testWidgets('End-to-End Custom Request Flow: submitting brief, proposing time, and artist acceptance syncs calendar, client appointments, and chat receipt',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const customReq = BookingRequest(
        id: 'req_custom_e2e_99',
        clientName: 'Jordan Blake',
        timeAgo: 'Just now',
        conceptDescription: 'Custom geometric raven across shoulder blade.',
        placement: 'Shoulder / Back',
        category: 'Blackwork',
        sketchImageUrl: 'assets/images/flash_traditional_panther.jpg',
        estimatedPrice: 550,
        deposit: 120,
        artistName: 'OddMaree',
      );

      ArtistDashboardRepository.addPendingRequest(customReq);
      expect(
        ArtistDashboardRepository.pendingRequests.any((r) => r.id == 'req_custom_e2e_99'),
        isTrue,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: BookingRequestDetailScreen(request: customReq),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Jordan Blake'), findsOneWidget);
      expect(find.text('\$550'), findsOneWidget);
      expect(find.text('\$120'), findsOneWidget);

      // Open Propose New Time modal and apply a proposed slot
      await tester.tap(find.byKey(const Key('propose_time_button')));
      await tester.pumpAndSettle();
      expect(find.text('Propose Session Time & Quote'), findsOneWidget);

      await tester.tap(find.byKey(const Key('confirm_proposal_button')));
      await tester.pumpAndSettle();

      // Accept the custom request
      await tester.tap(find.byKey(const Key('accept_request_button')));
      await tester.pumpAndSettle();

      // Verify request was removed from pendingRequests
      expect(
        ArtistDashboardRepository.pendingRequests.any((r) => r.id == 'req_custom_e2e_99'),
        isFalse,
      );

      // Verify appointment added to Artist Calendar
      final calApt = ArtistDashboardRepository.calendarAppointments.firstWhere(
        (a) => a.id == 'cal_custom_req_custom_e2e_99',
      );
      expect(calApt.clientName, 'Jordan Blake');
      expect(calApt.fullPrice, 550);
      expect(calApt.depositPaid, 120);

      // Verify appointment added to Client Upcoming Appointments
      final clientApt = ClientAppointment.mockUpcoming.firstWhere(
        (a) => a.notes == 'Custom geometric raven across shoulder blade.',
      );
      expect(clientApt.status, AppointmentStatus.confirmed);
      expect(clientApt.totalPrice, 550);

      // Verify receipt message posted in MessageThread
      final thread = MessageThread.mockThreads.firstWhere(
        (t) => t.id == 'thread_custom_req_custom_e2e_99',
      );
      expect(
        thread.messages.any((m) => m.type == ChatMessageType.receipt && m.receiptAmount == 120.0),
        isTrue,
      );

      // Verify BookingSyncService recorded custom_request and booking_confirmed notifications
      expect(
        BookingSyncService.sentNotifications.any((n) => n.category == 'custom_request'),
        isTrue,
      );
      expect(
        BookingSyncService.sentNotifications.any((n) => n.category == 'booking_confirmed'),
        isTrue,
      );
    });

    testWidgets('End-to-End Reschedule & Cancellation Flow: AppointmentDetailScreen reschedules and cancels appointments across calendar, client list, chat, and BookingSyncService',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final testApt = DashboardAppointment(
        id: 'cal_resched_test_1',
        clientName: 'Taylor Swift',
        serviceType: 'Flash: Lunar Moth',
        duration: '2.5 hrs',
        time: '11:00 AM',
        scheduledDate: DateTime(2026, 10, 15),
        date: 'Oct 15, 2026',
        placement: 'Upper Arm / Bicep',
        notes: 'Fine line lunar moth.',
        depositPaid: 80,
        fullPrice: 280,
        artworkImageUrl: 'assets/images/flash_fineline_flora.jpg',
        visitType: 'Flash Tattoo',
      );
      ArtistDashboardRepository.addCalendarAppointment(testApt);

      await tester.pumpWidget(
        MaterialApp(
          home: AppointmentDetailScreen(appointment: testApt),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Open Reschedule sheet
      await tester.ensureVisible(find.byKey(const Key('reschedule_appointment_button')));
      await tester.tap(find.byKey(const Key('reschedule_appointment_button')));
      await tester.pumpAndSettle();

      expect(find.text('SELECT WORKING DAY'), findsOneWidget);
      expect(find.text('SELECT TIME SLOT'), findsOneWidget);

      // Select '3:00 PM' slot and confirm reschedule
      await tester.tap(find.text('3:00 PM'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm_reschedule_button')));
      await tester.pumpAndSettle();

      // Verify AppointmentDetailScreen header updated to 3:00 PM
      expect(find.text('3:00 PM'), findsOneWidget);

      // Verify ArtistDashboardRepository.calendarAppointments updated
      final updatedCalApt = ArtistDashboardRepository.calendarAppointments.firstWhere(
        (a) => a.id == 'cal_resched_test_1',
      );
      expect(updatedCalApt.time, '3:00 PM');

      // Verify BookingSyncService dispatched a 'rescheduled' notification
      expect(
        BookingSyncService.sentNotifications.any(
          (n) => n.appointmentId == 'cal_resched_test_1' && n.category == 'rescheduled',
        ),
        isTrue,
      );

      // 2. Open Cancel Confirmation sheet and cancel the appointment
      await tester.ensureVisible(find.byKey(const Key('cancel_appointment_button')));
      await tester.tap(find.byKey(const Key('cancel_appointment_button')));
      await tester.pumpAndSettle();

      expect(find.text('Cancel Appointment?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('confirm_cancel_appointment_button')));
      await tester.pumpAndSettle();

      // Verify appointment was removed from calendarAppointments
      expect(
        ArtistDashboardRepository.calendarAppointments.any((a) => a.id == 'cal_resched_test_1'),
        isFalse,
      );

      // Verify BookingSyncService dispatched a 'cancelled' notification
      expect(
        BookingSyncService.sentNotifications.any(
          (n) => n.appointmentId == 'cal_resched_test_1' && n.category == 'cancelled',
        ),
        isTrue,
      );
    });

    testWidgets('Step 3: Selecting Credit Card displays auto-filled card details and Auto-fill Test Card button',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: FlashBookingScreen(
            flash: testFlash,
            artist: testArtist,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to Step 2
      await tester.tap(find.text('CONTINUE TO DETAILS'));
      await tester.pumpAndSettle();

      // Navigate to Step 3
      await tester.tap(find.text('CONTINUE TO PAYMENT'));
      await tester.pumpAndSettle();

      // Tap Auto-fill Test Card button
      expect(find.text('Auto-fill Test Card'), findsOneWidget);
      await tester.tap(find.text('Auto-fill Test Card'));
      await tester.pumpAndSettle();

      // Verify Credit Card is selected and card fields are populated
      expect(find.text('CARD DETAILS'), findsOneWidget);
      expect(find.text('Test Card Ready'), findsOneWidget);
      expect(find.text('4242 4242 4242 4242'), findsOneWidget);
      expect(find.text('12/28'), findsOneWidget);
      expect(find.text('123'), findsOneWidget);
      expect(find.text('90210'), findsOneWidget);
      expect(
        find.text('Stripe mock test card auto-filled. You can proceed without actual charges.'),
        findsOneWidget,
      );

      // Verify payment button is enabled and can process purchase
      expect(find.text('PAY \$75 DEPOSIT & CONFIRM'), findsOneWidget);
      await tester.tap(find.text('PAY \$75 DEPOSIT & CONFIRM'));
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pumpAndSettle();

      // Successfully reaches Step 4 Confirmation
      expect(find.text('Flash Claimed & Booked!'), findsOneWidget);
    });
  });
}

