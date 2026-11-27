import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flash_ink/core/mock/mock_data_config.dart';
import 'package:flash_ink/features/appointments/domain/models/appointment_item.dart';
import 'package:flash_ink/features/appointments/presentation/widgets/appointment_detail_modal.dart';
import 'package:flash_ink/features/messages/domain/models/message_thread.dart';
import 'package:flash_ink/features/messages/presentation/screens/chat_conversation_screen.dart';
import 'package:flash_ink/models/artist_dashboard/artist_books_schedule.dart';
import 'package:flash_ink/repositories/artist_dashboard_repository.dart';
import 'package:flash_ink/screens/booking/touch_up_booking_screen.dart';
import 'package:flash_ink/services/booking_sync_service.dart';
import 'package:flash_ink/services/scheduling/booking_slot_profile.dart';
import 'package:flash_ink/services/scheduling/slot_availability_engine.dart';
import 'package:flash_ink/services/scheduling/touch_up_eligibility.dart';
import 'package:flash_ink/services/touch_up_service.dart';

ArtistBooksSchedule _buildSchedule({
  bool isBooksOpen = true,
  bool acceptTouchUps = true,
  int touchUpDurationMinutes = 30,
  int touchUpBufferMinutes = 30,
  int touchUpWindowMonths = 6,
  int touchUpFeeDollars = 0,
  List<ScheduleSlotEntry> bookedSlots = const [],
}) {
  return ArtistBooksSchedule(
    isBooksOpen: isBooksOpen,
    bookingWindowStart: DateTime(2026, 1, 1),
    bookingWindowEnd: DateTime(2026, 12, 31),
    hasBookingWindow: false,
    workingDays: const {1, 2, 3, 4, 5, 6, 7},
    startTime: const TimeOfDay(hour: 10, minute: 0),
    endTime: const TimeOfDay(hour: 17, minute: 0),
    slotDurationMinutes: 120,
    bufferDurationMinutes: 60,
    preventDeadGaps: true,
    minBookableSessionMinutes: 60,
    bookedSlots: bookedSlots,
    acceptTouchUps: acceptTouchUps,
    touchUpDurationMinutes: touchUpDurationMinutes,
    touchUpBufferMinutes: touchUpBufferMinutes,
    touchUpWindowMonths: touchUpWindowMonths,
    touchUpFeeDollars: touchUpFeeDollars,
    locationNote: 'Velvet Needle Parlor • Venice, CA',
  );
}

ClientAppointment _buildCompletedTattoo({
  String id = 'APT-ORIG-1',
  String artistId = 'artist_kora',
  String artistName = 'Kora Sol',
  String title = 'Chrysanthemum Silhouette',
  required DateTime dateTime,
  AppointmentStatus status = AppointmentStatus.completed,
  bool isTouchUp = false,
  String? parentAppointmentId,
}) {
  return ClientAppointment(
    id: id,
    artistId: artistId,
    artistName: artistName,
    artistAvatar: '',
    studioName: 'Velvet Needle Parlor',
    studioAddress: '310 Sunset Blvd, Venice, CA',
    flashTitle: title,
    flashImageUrl: '',
    dateTime: dateTime,
    timeSlot: '2:00 PM (2.0 hrs)',
    placement: 'Left Thigh',
    depositAmount: 80,
    totalPrice: 320,
    status: status,
    isTouchUp: isTouchUp,
    parentAppointmentId: parentAppointmentId,
  );
}

void main() {
  setUp(() {
    MockDataConfig.debugOverride = true;
    BookingSyncService.enableCloudWrites = false;
    ClientAppointment.mockUpcoming = [];
    ClientAppointment.mockPast = [];
    ArtistDashboardRepository.calendarAppointments.clear();
  });

  tearDown(() {
    MockDataConfig.resetDebugOverride();
    BookingSyncService.enableCloudWrites = true;
  });

  group('Touch-Up Scheduling Engine & Configurable Profile', () {
    test('Uses artist-configured touch-up duration and buffer (not hardcoded)', () {
      final schedule = _buildSchedule(
        touchUpDurationMinutes: 45,
        touchUpBufferMinutes: 15,
      );

      final profile = BookingSlotProfile.forType(
        BookingSlotType.touchUp,
        schedule: schedule,
      );

      expect(profile.type, BookingSlotType.touchUp);
      expect(profile.durationMinutes, 45);
      expect(profile.bufferMinutes, 15);
      expect(profile.filterDeadGaps, isFalse);
    });

    test(
      'Touch-up slots stay bookable when public books are closed (acceptTouchUps only) and hide when acceptTouchUps is false',
      () {
        final date = DateTime(2026, 12, 10);
        final closedBooksTouchUpsOn = _buildSchedule(
          isBooksOpen: false,
          acceptTouchUps: true,
        );
        final openBooksTouchUpsOff = _buildSchedule(
          isBooksOpen: true,
          acceptTouchUps: false,
        );

        final flashSlotsWhenClosed = SlotAvailabilityEngine.generateAvailableSlots(
          date: date,
          schedule: closedBooksTouchUpsOn,
          slotType: BookingSlotType.flash,
        );
        final touchUpSlotsWhenClosed =
            SlotAvailabilityEngine.generateAvailableSlots(
          date: date,
          schedule: closedBooksTouchUpsOn,
          slotType: BookingSlotType.touchUp,
        );
        final touchUpSlotsWhenDisabled =
            SlotAvailabilityEngine.generateAvailableSlots(
          date: date,
          schedule: openBooksTouchUpsOff,
          slotType: BookingSlotType.touchUp,
        );

        expect(flashSlotsWhenClosed, isEmpty);
        expect(touchUpSlotsWhenClosed, isNotEmpty);
        expect(touchUpSlotsWhenDisabled, isEmpty);
      },
    );

    test('Touch-ups continue to bypass dead-gap protection into 1-hour gaps', () {
      final date = DateTime(2026, 12, 10);
      final schedule = _buildSchedule(
        isBooksOpen: false,
        acceptTouchUps: true,
        touchUpDurationMinutes: 30,
        touchUpBufferMinutes: 30,
        bookedSlots: [
          ScheduleSlotEntry(
            dateKey: '2026-12-10',
            timeSlot: '11:00 AM',
            startMinutes: 660,
            durationMinutes: 120,
            bufferMinutes: 60,
          ),
        ],
      );

      final slots = SlotAvailabilityEngine.generateAvailableSlots(
        date: date,
        schedule: schedule,
        slotType: BookingSlotType.touchUp,
      );
      expect(slots.map((s) => s.time), contains('10:00 AM'));
    });
  });

  group('TouchUpEligibilityService Rules', () {
    final now = DateTime(2026, 11, 24);

    test('Blocks booking before 7-day healing wait and unlocks on day 7', () {
      final schedule = _buildSchedule();
      final day6Tattoo = _buildCompletedTattoo(
        dateTime: now.subtract(const Duration(days: 6)),
      );
      final day7Tattoo = _buildCompletedTattoo(
        id: 'APT-ORIG-2',
        dateTime: now.subtract(const Duration(days: 7)),
      );

      final tooEarly = TouchUpEligibilityService.evaluate(
        originalAppointment: day6Tattoo,
        schedule: schedule,
        allClientAppointments: const [],
        now: now,
      );
      final unlocked = TouchUpEligibilityService.evaluate(
        originalAppointment: day7Tattoo,
        schedule: schedule,
        allClientAppointments: const [],
        now: now,
      );

      expect(tooEarly.status, TouchUpEligibilityStatus.tooEarlyToHeal);
      expect(tooEarly.availableAfter, DateTime(2026, 11, 25));
      expect(unlocked.isEligible, isTrue);
      expect(unlocked.isFree, isTrue);
    });

    test('Disables self-booking and directs to chat once window expires', () {
      final schedule = _buildSchedule(touchUpWindowMonths: 6);
      final expiredTattoo = _buildCompletedTattoo(
        dateTime: DateTime(2026, 4, 1),
      );

      final result = TouchUpEligibilityService.evaluate(
        originalAppointment: expiredTattoo,
        schedule: schedule,
        allClientAppointments: const [],
        now: now,
      );

      expect(result.status, TouchUpEligibilityStatus.windowExpired);
      expect(result.shouldDirectToChat, isTrue);
    });

    test('Enforces 1 touch-up per original tattoo and directs repeat requests to chat', () {
      final schedule = _buildSchedule();
      final original = _buildCompletedTattoo(
        id: 'APT-ORIG-1',
        dateTime: now.subtract(const Duration(days: 30)),
      );
      final priorTouchUp = _buildCompletedTattoo(
        id: 'TU-PRIOR',
        dateTime: now.subtract(const Duration(days: 5)),
        status: AppointmentStatus.completed,
        isTouchUp: true,
        parentAppointmentId: 'APT-ORIG-1',
      );

      final result = TouchUpEligibilityService.evaluate(
        originalAppointment: original,
        schedule: schedule,
        allClientAppointments: [original, priorTouchUp],
        now: now,
      );

      expect(result.status, TouchUpEligibilityStatus.alreadyUsedForTattoo);
      expect(result.shouldDirectToChat, isTrue);
    });

    test('Enforces max 1 active upcoming touch-up at a time with an artist', () {
      final schedule = _buildSchedule();
      final secondOriginal = _buildCompletedTattoo(
        id: 'APT-ORIG-2',
        dateTime: now.subtract(const Duration(days: 40)),
      );
      final activeUpcomingTouchUp = _buildCompletedTattoo(
        id: 'TU-UPCOMING',
        dateTime: now.add(const Duration(days: 4)),
        status: AppointmentStatus.confirmed,
        isTouchUp: true,
        parentAppointmentId: 'APT-ORIG-1',
      );

      final result = TouchUpEligibilityService.evaluate(
        originalAppointment: secondOriginal,
        schedule: schedule,
        allClientAppointments: [secondOriginal, activeUpcomingTouchUp],
        now: now,
      );

      expect(result.status, TouchUpEligibilityStatus.hasActiveUpcomingTouchUp);
    });

    test('Returns artistDisabledTouchUps when acceptTouchUps is false', () {
      final schedule = _buildSchedule(acceptTouchUps: false);
      final original = _buildCompletedTattoo(
        dateTime: now.subtract(const Duration(days: 20)),
      );

      final result = TouchUpEligibilityService.evaluate(
        originalAppointment: original,
        schedule: schedule,
        allClientAppointments: const [],
        now: now,
      );

      expect(result.status, TouchUpEligibilityStatus.artistDisabledTouchUps);
      expect(result.shouldDirectToChat, isTrue);
    });
  });

  group('Touch-Up Entry Points & Self-Booking Widget Tests', () {
    testWidgets(
      'Entry Point #1 (AppointmentDetailModal): renders eligible Book CTA, 7-day wait banner, and expired chat-only CTA',
      (tester) async {
        final now = DateTime(2026, 11, 24);
        final schedule = _buildSchedule(
          isBooksOpen: false,
          acceptTouchUps: true,
          touchUpFeeDollars: 0,
        );

        // 1. Eligible completed tattoo
        final eligibleApt = _buildCompletedTattoo(
          dateTime: now.subtract(const Duration(days: 20)),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AppointmentDetailModal(
                appointment: eligibleApt,
                artistScheduleOverride: schedule,
                allAppointmentsOverride: [eligibleApt],
                nowOverride: now,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('book_touch_up_button')), findsOneWidget);
        expect(find.text('Book Free Touch-up'), findsOneWidget);

        // 2. Too early (< 7 days)
        final recentApt = _buildCompletedTattoo(
          id: 'APT-RECENT',
          dateTime: now.subtract(const Duration(days: 3)),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AppointmentDetailModal(
                appointment: recentApt,
                artistScheduleOverride: schedule,
                allAppointmentsOverride: [recentApt],
                nowOverride: now,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('touch_up_too_early_banner')), findsOneWidget);
        expect(find.byKey(const Key('book_touch_up_button')), findsNothing);

        // 3. Past free window -> self-booking disabled, directs to chat
        final expiredApt = _buildCompletedTattoo(
          id: 'APT-OLD',
          dateTime: DateTime(2026, 1, 10),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AppointmentDetailModal(
                appointment: expiredApt,
                artistScheduleOverride: schedule,
                allAppointmentsOverride: [expiredApt],
                nowOverride: now,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('touch_up_chat_only_banner')), findsOneWidget);
        expect(
          find.byKey(const Key('touch_up_message_artist_button')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('book_touch_up_button')), findsNothing);
      },
    );

    testWidgets(
      'TouchUpBookingScreen completes \$0 self-booking without requiring a photo even when public books are closed',
      (tester) async {
        final orig = _buildCompletedTattoo(
          id: 'APT-ORIG-99',
          dateTime: DateTime.now().subtract(const Duration(days: 30)),
        );
        final schedule = _buildSchedule(
          isBooksOpen: false,
          acceptTouchUps: true,
          touchUpFeeDollars: 0,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: TouchUpBookingScreen(
              originalAppointment: orig,
              initialSchedule: schedule,
              touchUpService: TouchUpService(isProductionOverride: false),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('FREE TOUCH-UP'), findsOneWidget);
        expect(find.text('HEALED TATTOO PHOTO (OPTIONAL)'), findsOneWidget);

        final confirmBtn = find.byKey(const Key('confirm_touch_up_booking_button'));
        expect(confirmBtn, findsOneWidget);
        await tester.tap(confirmBtn);
        await tester.pumpAndSettle();

        expect(find.text('Touch-up Confirmed!'), findsOneWidget);
        expect(ClientAppointment.mockUpcoming.length, 1);
        final booked = ClientAppointment.mockUpcoming.first;
        expect(booked.isTouchUp, isTrue);
        expect(booked.parentAppointmentId, 'APT-ORIG-99');
        expect(booked.totalPrice, 0);
      },
    );

    testWidgets(
      'Entry Point #2 (ChatConversationScreen): shows Touch-up action for clients only and opens picker when 2+ tattoos exist',
      (tester) async {
        final now = DateTime(2026, 11, 24);
        final schedule = _buildSchedule();
        final tattoo1 = _buildCompletedTattoo(
          id: 'APT-1',
          artistId: 'artist_kora',
          artistName: 'Kora Sol',
          title: 'Chrysanthemum Silhouette',
          dateTime: now.subtract(const Duration(days: 20)),
        );
        final tattoo2 = _buildCompletedTattoo(
          id: 'APT-2',
          artistId: 'artist_kora',
          artistName: 'Kora Sol',
          title: 'Lunar Moth',
          dateTime: now.subtract(const Duration(days: 60)),
        );
        final thread = MessageThread(
          id: 'thread_kora',
          artistId: 'artist_kora',
          artistName: 'Kora Sol',
          artistAvatar: '',
          studioName: 'Velvet Needle Parlor',
          lastMessage: 'How is it healing?',
          lastMessageTime: now,
          unreadCount: 0,
          messages: const [],
        );

        // Artist view must NOT show client-initiated Touch-up button
        await tester.pumpWidget(
          MaterialApp(
            home: ChatConversationScreen(
              thread: thread,
              isArtistView: true,
              artistScheduleOverride: schedule,
              allAppointmentsOverride: [tattoo1, tattoo2],
              nowOverride: now,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('chat_book_touch_up_button')), findsNothing);

        // Client view shows Touch-up button and opens 2-tattoo picker
        await tester.pumpWidget(
          MaterialApp(
            home: ChatConversationScreen(
              thread: thread,
              isArtistView: false,
              artistScheduleOverride: schedule,
              allAppointmentsOverride: [tattoo1, tattoo2],
              nowOverride: now,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final btn = find.byKey(const Key('chat_book_touch_up_button'));
        expect(btn, findsOneWidget);

        await tester.tap(btn);
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('chat_touch_up_tattoo_picker')), findsOneWidget);
        expect(find.byKey(const Key('touch_up_picker_item_APT-1')), findsOneWidget);
        expect(find.byKey(const Key('touch_up_picker_item_APT-2')), findsOneWidget);
      },
    );
  });
}
