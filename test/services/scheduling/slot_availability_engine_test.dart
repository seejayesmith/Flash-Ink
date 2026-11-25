import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flash_ink/core/mock/mock_data_config.dart';
import 'package:flash_ink/features/messages/domain/models/message_thread.dart';
import 'package:flash_ink/models/artist_dashboard/artist_books_schedule.dart';
import 'package:flash_ink/repositories/artist_dashboard_repository.dart';
import 'package:flash_ink/services/scheduling/booking_slot_profile.dart';
import 'package:flash_ink/services/scheduling/slot_availability_engine.dart';

void main() {
  final targetDate = DateTime(2026, 12, 15); // Tuesday
  final targetDateKey = ArtistBooksSchedule.dateKey(targetDate);

  ArtistBooksSchedule buildSchedule({
    DateTime? bookingWindowStart,
    DateTime? bookingWindowEnd,
    TimeOfDay startTime = const TimeOfDay(hour: 10, minute: 0),
    TimeOfDay endTime = const TimeOfDay(hour: 19, minute: 0),
    int slotDurationMinutes = 120,
    int bufferDurationMinutes = 60,
    bool preventDeadGaps = true,
    int minBookableSessionMinutes = 60,
    List<ScheduleSlotEntry> bookedSlots = const [],
    List<ScheduleSlotEntry> heldSlots = const [],
  }) {
    return ArtistBooksSchedule(
      isBooksOpen: true,
      bookingWindowStart: bookingWindowStart ?? DateTime(2026, 12, 1),
      bookingWindowEnd: bookingWindowEnd ?? DateTime(2027, 2, 1),
      workingDays: const {1, 2, 3, 4, 5, 6, 7},
      startTime: startTime,
      endTime: endTime,
      slotDurationMinutes: slotDurationMinutes,
      bufferDurationMinutes: bufferDurationMinutes,
      preventDeadGaps: preventDeadGaps,
      minBookableSessionMinutes: minBookableSessionMinutes,
      bookedSlots: bookedSlots,
      heldSlots: heldSlots,
    );
  }

  group('SlotAvailabilityEngine — Hourly Grid, Buffers & Smart Dead-Gap Rules', () {
    test(
      '1. Empty 10:00 AM – 7:00 PM day with a 3-hr piece hides 11:00 AM and allows 4:00 PM closing fit',
      () {
        final schedule = buildSchedule();
        final slots = SlotAvailabilityEngine.generateAvailableSlots(
          date: targetDate,
          schedule: schedule,
          slotType: BookingSlotType.flash,
          requestedDurationMinutes: 180, // 3-hr tattoo
        );

        final times = slots.map((s) => s.time).toList();

        // Hourly grid only (no :30 slots).
        expect(times.every((t) => t.contains(':00 ')), isTrue);

        // 11:00 AM strands 10:00 AM – 11:00 AM (60 min < 120 min usable gap) -> hidden!
        expect(times, isNot(contains('11:00 AM')));

        // 4:00 PM runs 4:00 PM – 7:00 PM right up to closing (requireBufferBeforeClose = false).
        expect(
          times,
          equals([
            '10:00 AM',
            '12:00 PM',
            '1:00 PM',
            '2:00 PM',
            '3:00 PM',
            '4:00 PM',
          ]),
        );
      },
    );

    test(
      '2. Existing 11:00 AM – 1:00 PM (+ 1-hr cleanup to 2:00 PM) blocks 10:00 AM for regular tattoos, allows 10:00 AM for touch-up, allows 2:00 PM, and hides 3:00 PM for Flash',
      () {
        // 11:00 AM (660) + 120m session + 60m buffer = [660, 840) (11:00 AM – 2:00 PM)
        final existingBooking = ScheduleSlotEntry(
          dateKey: targetDateKey,
          timeSlot: '11:00 AM',
          startMinutes: 660,
          durationMinutes: 120,
          bufferMinutes: 60,
        );
        final schedule = buildSchedule(bookedSlots: [existingBooking]);

        // Regular 2-hr Flash booking
        final flashSlots = SlotAvailabilityEngine.generateAvailableSlots(
          date: targetDate,
          schedule: schedule,
          slotType: BookingSlotType.flash,
          requestedDurationMinutes: 120,
        );
        final flashTimes = flashSlots.map((s) => s.time).toList();

        // 10:00 AM (600 + 120 + 60 = 780) overlaps [660, 840) -> blocked.
        expect(flashTimes, isNot(contains('10:00 AM')));
        // 2:00 PM (840) starts right after cleanup finishes -> allowed!
        expect(flashTimes, contains('2:00 PM'));
        // 3:00 PM strands 2:00 PM – 3:00 PM (60m < 120m) -> hidden for Flash!
        expect(flashTimes, isNot(contains('3:00 PM')));
        // 4:00 PM leaves 2:00 PM – 4:00 PM (120m usable) and 5:00 PM runs to 7:00 PM close -> allowed!
        expect(flashTimes, equals(['2:00 PM', '4:00 PM', '5:00 PM']));

        // Touch-up (30m session + 30m buffer = 60m total: [600, 660)) fits cleanly into 10:00 AM – 11:00 AM!
        final touchUpSlots = SlotAvailabilityEngine.generateAvailableSlots(
          date: targetDate,
          schedule: schedule,
          slotType: BookingSlotType.touchUp,
        );
        final touchUpTimes = touchUpSlots.map((s) => s.time).toList();
        expect(touchUpTimes, contains('10:00 AM'));
        expect(touchUpTimes, isNot(contains('11:00 AM')));
        expect(touchUpTimes, isNot(contains('12:00 PM')));
        expect(touchUpTimes, isNot(contains('1:00 PM')));
        expect(touchUpTimes, contains('2:00 PM'));
      },
    );

    test(
      '3. Custom proposal mode flags createsDeadGap: true without hiding non-overlapping slots',
      () {
        final existingBooking = ScheduleSlotEntry(
          dateKey: targetDateKey,
          timeSlot: '11:00 AM',
          startMinutes: 660,
          durationMinutes: 120,
          bufferMinutes: 60,
        );
        final schedule = buildSchedule(bookedSlots: [existingBooking]);

        final customSlots = SlotAvailabilityEngine.generateAvailableSlots(
          date: targetDate,
          schedule: schedule,
          slotType: BookingSlotType.custom,
          requestedDurationMinutes: 120,
        );

        final byTime = {for (final s in customSlots) s.time: s};

        // 3:00 PM is NOT hidden in custom mode, and exposes createsDeadGap == true.
        expect(byTime.containsKey('3:00 PM'), isTrue);
        expect(byTime['3:00 PM']!.createsDeadGap, isTrue);
        expect(byTime['3:00 PM']!.isOptimal, isFalse);

        // 2:00 PM, 4:00 PM, and 5:00 PM are optimal (createsDeadGap == false).
        expect(byTime['2:00 PM']!.createsDeadGap, isFalse);
        expect(byTime['2:00 PM']!.isOptimal, isTrue);
        expect(byTime['4:00 PM']!.createsDeadGap, isFalse);
        expect(byTime['5:00 PM']!.createsDeadGap, isFalse);
      },
    );

    test(
      '3b. Snaps non-hour 1.5-hr Flash durations to next hourly grid boundary without false dead-gap flags',
      () {
        final schedule = buildSchedule();
        final slots = SlotAvailabilityEngine.generateAvailableSlots(
          date: targetDate,
          schedule: schedule,
          slotType: BookingSlotType.flash,
          requestedDurationMinutes: 90, // 1.5 hrs + 60m buffer = 150m
        );
        final times = slots.map((s) => s.time).toList();

        // 10:00 AM -> blockedEnd 12:30 PM, snapped to 1:00 PM -> 6h remaining -> valid!
        expect(times, contains('10:00 AM'));
        // 4:00 PM -> blockedEnd 6:30 PM, snapped to 7:00 PM -> gapAfterClose = 0 -> valid!
        expect(times, contains('4:00 PM'));
      },
    );

    test(
      '4. Legacy {date, time} fallback parsing in ScheduleSlotEntry.fromMap uses 120m duration + 60m buffer and stays PII-free',
      () {
        final legacyEntry = ScheduleSlotEntry.fromMap({
          'date': '2026-12-15',
          'time': '1:30 PM',
        });

        expect(legacyEntry.date, '2026-12-15');
        expect(legacyEntry.time, '1:30 PM');
        expect(legacyEntry.startMinutes, 13 * 60 + 30); // 810
        expect(legacyEntry.durationMinutes, 120);
        expect(legacyEntry.bufferMinutes, 60);
        expect(legacyEntry.endMinutes, 810 + 120 + 60); // 990 (4:30 PM)

        // Overlaps 12:00 PM 2-hr + 1-hr buffer [720, 900) and 4:00 PM [960, 1140),
        // but does NOT overlap 10:00 AM [600, 780) or 5:00 PM [1020, 1200).
        expect(legacyEntry.overlapsInterval(720, 900), isTrue);
        expect(legacyEntry.overlapsInterval(960, 1140), isTrue);
        expect(legacyEntry.overlapsInterval(600, 780), isFalse);
        expect(legacyEntry.overlapsInterval(1020, 1200), isFalse);

        final serialized = legacyEntry.toMap();
        expect(serialized.keys, unorderedEquals([
          'date',
          'time',
          'startMinutes',
          'durationMinutes',
          'bufferMinutes',
          'endMinutes',
        ]));
        expect(serialized.containsKey('clientName'), isFalse);
        expect(serialized.containsKey('clientId'), isFalse);
      },
    );

    test(
      '5. confirmProposedTimeSlot rejects proposed option when an overlapping (different start time) booking claims part of the interval',
      () async {
        MockDataConfig.debugOverride = true;
        addTearDown(MockDataConfig.resetDebugOverride);
        ArtistDashboardRepository.resetMockData();

        final proposalDay = DateTime.now().add(const Duration(days: 5));
        final dayOnly =
            DateTime(proposalDay.year, proposalDay.month, proposalDay.day);
        ArtistDashboardRepository.booksSchedule = buildSchedule(
          bookingWindowStart: DateTime.now().subtract(const Duration(days: 1)),
          bookingWindowEnd: DateTime.now().add(const Duration(days: 60)),
          bookedSlots: [
            // Another client booked 1:00 PM (2h + 1h cleanup -> blocks [1:00 PM, 4:00 PM))
            ScheduleSlotEntry(
              dateKey: ArtistBooksSchedule.dateKey(dayOnly),
              timeSlot: '1:00 PM',
              startMinutes: 13 * 60,
              durationMinutes: 120,
              bufferMinutes: 60,
            ),
          ],
        );

        final proposalMsg = ChatMessage(
          id: 'prop_interval_1',
          senderId: 'artist_1',
          senderName: 'OddMaree',
          text: 'Pick a time',
          timestamp: DateTime.now(),
          isFromArtist: true,
          type: ChatMessageType.proposal,
          appointmentDurationMinutes: 120,
          proposedSlots: [
            // 2:00 PM starts at a different label than 1:00 PM, but overlaps [1:00 PM, 4:00 PM)!
            ProposedTimeOption(
              date: dayOnly,
              timeSlot: '2:00 PM',
              startMinutes: 14 * 60,
              durationMinutes: 120,
            ),
            // 4:00 PM starts right after cleanup ends at 4:00 PM -> available!
            ProposedTimeOption(
              date: dayOnly,
              timeSlot: '4:00 PM',
              startMinutes: 16 * 60,
              durationMinutes: 120,
            ),
          ],
        );

        final conflictRes =
            await ArtistDashboardRepository.confirmProposedTimeSlot(
          proposalMessage: proposalMsg,
          optionIndex: 0,
          artistId: 'artist_1',
        );
        expect(conflictRes.confirmed, isFalse);

        final validRes =
            await ArtistDashboardRepository.confirmProposedTimeSlot(
          proposalMessage: proposalMsg,
          optionIndex: 1,
          artistId: 'artist_1',
        );
        expect(validRes.confirmed, isTrue);
      },
    );
  });
}
