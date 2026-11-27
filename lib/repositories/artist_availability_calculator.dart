import '../models/artist_dashboard/artist_books_schedule.dart';
import '../models/artist_dashboard/book_drop.dart';
import '../models/artist_dashboard/dashboard_appointment.dart';
import '../services/scheduling/booking_slot_profile.dart';
import '../services/scheduling/slot_availability_engine.dart';

/// Stateless availability, occupancy, weekly-cap, and capacity calculator for
/// an artist's booking schedule.
class ArtistAvailabilityCalculator {
  const ArtistAvailabilityCalculator._();

  /// Parses duration strings like "1 hr", "2.5 hrs", "3hrs", "90 mins" into minutes.
  static int parseDurationMinutes(
    String duration, {
    required int fallbackSlotDurationMinutes,
  }) {
    final lower = duration.toLowerCase().trim();
    final match = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(lower);
    if (match == null) return fallbackSlotDurationMinutes;
    final val = double.tryParse(match.group(1)!) ?? 2.0;
    if (lower.contains('min')) {
      return val.round().clamp(15, 720);
    }
    return (val * 60).round().clamp(15, 720);
  }

  static Iterable<DashboardAppointment> matchingAppointments({
    required ArtistBooksSchedule schedule,
    required ArtistBooksSchedule repoSchedule,
    required List<DashboardAppointment> calendarAppointments,
    String? artistId,
  }) {
    final includeLocalRepo = identical(schedule, repoSchedule);
    return calendarAppointments.where((apt) {
      if (includeLocalRepo) {
        return artistId == null || apt.artistId == null || apt.artistId == artistId;
      }
      return artistId != null && apt.artistId == artistId;
    });
  }

  static Iterable<CustomHold> activeLocalHolds({
    required ArtistBooksSchedule schedule,
    required ArtistBooksSchedule repoSchedule,
    required List<CustomHold> customHolds,
    required DateTime now,
  }) {
    if (!identical(schedule, repoSchedule)) return const [];
    return customHolds.where((h) => !now.isAfter(h.expiresAt));
  }

  /// Returns canonical `YYYY-MM-DD` date keys that have at least one confirmed
  /// appointment or unexpired 24h custom hold.
  static Set<String> getOccupiedDateKeys({
    required ArtistBooksSchedule schedule,
    required ArtistBooksSchedule repoSchedule,
    required List<DashboardAppointment> calendarAppointments,
    required List<CustomHold> customHolds,
    String? artistId,
    DateTime? now,
  }) {
    final effectiveNow = now ?? DateTime.now();
    final keys = <String>{};

    for (final apt in matchingAppointments(
      schedule: schedule,
      repoSchedule: repoSchedule,
      calendarAppointments: calendarAppointments,
      artistId: artistId,
    )) {
      if (apt.scheduledDate != null) {
        keys.add(ArtistBooksSchedule.dateKey(apt.scheduledDate!));
      }
    }
    for (final entry in schedule.bookedSlots) {
      if (entry.dateKey.isNotEmpty) keys.add(entry.dateKey);
    }
    for (final entry in schedule.heldSlots) {
      if (entry.dateKey.isNotEmpty && entry.isActiveAt(effectiveNow)) {
        keys.add(entry.dateKey);
      }
    }
    for (final hold in activeLocalHolds(
      schedule: schedule,
      repoSchedule: repoSchedule,
      customHolds: customHolds,
      now: effectiveNow,
    )) {
      keys.add(ArtistBooksSchedule.dateKey(hold.date));
    }
    return keys;
  }

  static bool isDateOccupied({
    required DateTime date,
    required ArtistBooksSchedule schedule,
    required ArtistBooksSchedule repoSchedule,
    required List<DashboardAppointment> calendarAppointments,
    required List<CustomHold> customHolds,
    String? artistId,
    DateTime? now,
  }) {
    return getOccupiedDateKeys(
      schedule: schedule,
      repoSchedule: repoSchedule,
      calendarAppointments: calendarAppointments,
      customHolds: customHolds,
      artistId: artistId,
      now: now,
    ).contains(ArtistBooksSchedule.dateKey(date));
  }

  /// Counts distinct occupied dates in the Sunday–Saturday week containing [date].
  static int countBookedDaysInWeek({
    required DateTime date,
    required ArtistBooksSchedule schedule,
    required ArtistBooksSchedule repoSchedule,
    required List<DashboardAppointment> calendarAppointments,
    required List<CustomHold> customHolds,
    String? artistId,
    DateTime? now,
  }) {
    final occupied = getOccupiedDateKeys(
      schedule: schedule,
      repoSchedule: repoSchedule,
      calendarAppointments: calendarAppointments,
      customHolds: customHolds,
      artistId: artistId,
      now: now,
    );
    if (occupied.isEmpty) return 0;

    final sun = ArtistBooksSchedule.weekStartSunday(date);
    int count = 0;
    for (int i = 0; i < 7; i++) {
      final day = DateTime(sun.year, sun.month, sun.day + i);
      if (occupied.contains(ArtistBooksSchedule.dateKey(day))) {
        count++;
      }
    }
    return count;
  }

  /// Returns true when [date] is an unbooked working day closed because the
  /// artist reached their configured Sun–Sat [maxWorkingDaysPerWeek] cap.
  static bool isClosedByWeeklyCap({
    required DateTime date,
    required ArtistBooksSchedule schedule,
    required ArtistBooksSchedule repoSchedule,
    required List<DashboardAppointment> calendarAppointments,
    required List<CustomHold> customHolds,
    required BookingMode mode,
    required bool isPaused,
    String? artistId,
    DateTime? now,
  }) {
    if (mode != BookingMode.alwaysOpen || isPaused) {
      return false;
    }
    final cap = schedule.maxWorkingDaysPerWeek;
    if (cap == null || cap <= 0 || !schedule.isWorkingDay(date)) return false;

    final effectiveNow = now ?? DateTime.now();
    final occupied = getOccupiedDateKeys(
      schedule: schedule,
      repoSchedule: repoSchedule,
      calendarAppointments: calendarAppointments,
      customHolds: customHolds,
      artistId: artistId,
      now: effectiveNow,
    );
    final key = ArtistBooksSchedule.dateKey(date);
    if (occupied.contains(key)) return false;

    final sun = ArtistBooksSchedule.weekStartSunday(date);
    int weekCount = 0;
    for (int i = 0; i < 7; i++) {
      final day = DateTime(sun.year, sun.month, sun.day + i);
      if (occupied.contains(ArtistBooksSchedule.dateKey(day))) {
        weekCount++;
      }
    }
    return weekCount >= cap;
  }

  static bool isTimeSlotBooked({
    required DateTime date,
    required String timeSlot,
    required ArtistBooksSchedule schedule,
    required ArtistBooksSchedule repoSchedule,
    required List<DashboardAppointment> calendarAppointments,
    String? artistId,
    int? startMinutes,
    int? durationMinutes,
    int? bufferMinutes,
  }) {
    final resolvedStart =
        startMinutes ?? ScheduleSlotEntry.parseTimeLabelToMinutes(timeSlot);
    if (resolvedStart != null) {
      final resolvedDuration = durationMinutes ?? schedule.slotDurationMinutes;
      final resolvedBuffer = bufferMinutes ?? schedule.bufferDurationMinutes;
      final candidateEnd = resolvedStart + resolvedDuration + resolvedBuffer;
      final occupied = SlotAvailabilityEngine.collectOccupiedForDate(
        date: date,
        schedule: schedule,
        localAppointments: matchingAppointments(
          schedule: schedule,
          repoSchedule: repoSchedule,
          calendarAppointments: calendarAppointments,
          artistId: artistId,
        ),
      );
      return occupied.booked.any(
        (b) => SlotAvailabilityEngine.intervalsOverlap(
          resolvedStart,
          candidateEnd,
          b.startMinutes,
          b.endMinutes,
        ),
      );
    }

    final key = ArtistBooksSchedule.dateKey(date);
    final targetTime = ArtistBooksSchedule.normalizeTimeLabel(timeSlot);

    if (schedule.bookedSlots.any((entry) =>
        entry.dateKey == key &&
        ArtistBooksSchedule.normalizeTimeLabel(entry.timeSlot) == targetTime)) {
      return true;
    }

    return matchingAppointments(
      schedule: schedule,
      repoSchedule: repoSchedule,
      calendarAppointments: calendarAppointments,
      artistId: artistId,
    ).any((apt) {
      if (apt.scheduledDate == null) return false;
      if (ArtistBooksSchedule.dateKey(apt.scheduledDate!) != key) return false;
      return ArtistBooksSchedule.normalizeTimeLabel(apt.time) == targetTime;
    });
  }

  /// Checks whether a time slot interval overlaps an active (non-expired) 24h custom hold.
  static bool hasActiveHoldForSlot({
    required DateTime date,
    required String timeSlot,
    required ArtistBooksSchedule schedule,
    required ArtistBooksSchedule repoSchedule,
    required List<CustomHold> customHolds,
    DateTime? now,
    int? startMinutes,
    int? durationMinutes,
    int? bufferMinutes,
    String? ignoreHoldId,
  }) {
    final effectiveNow = now ?? DateTime.now();
    final resolvedStart =
        startMinutes ?? ScheduleSlotEntry.parseTimeLabelToMinutes(timeSlot);
    if (resolvedStart != null) {
      final resolvedDuration = durationMinutes ?? schedule.slotDurationMinutes;
      final resolvedBuffer = bufferMinutes ?? schedule.bufferDurationMinutes;
      final candidateEnd = resolvedStart + resolvedDuration + resolvedBuffer;
      final occupied = SlotAvailabilityEngine.collectOccupiedForDate(
        date: date,
        schedule: schedule,
        localHolds: activeLocalHolds(
          schedule: schedule,
          repoSchedule: repoSchedule,
          customHolds: customHolds,
          now: effectiveNow,
        ),
        now: effectiveNow,
        ignoreHoldId: ignoreHoldId,
      );
      return occupied.held.any(
        (h) => SlotAvailabilityEngine.intervalsOverlap(
          resolvedStart,
          candidateEnd,
          h.startMinutes,
          h.endMinutes,
        ),
      );
    }

    final key = ArtistBooksSchedule.dateKey(date);
    final targetTime = ArtistBooksSchedule.normalizeTimeLabel(timeSlot);

    if (schedule.heldSlots.any((entry) =>
        entry.dateKey == key &&
        entry.isActiveAt(effectiveNow) &&
        (ignoreHoldId == null || entry.holdId != ignoreHoldId) &&
        ArtistBooksSchedule.normalizeTimeLabel(entry.timeSlot) == targetTime)) {
      return true;
    }

    return activeLocalHolds(
      schedule: schedule,
      repoSchedule: repoSchedule,
      customHolds: customHolds,
      now: effectiveNow,
    ).any((hold) {
      if (ignoreHoldId != null && hold.id == ignoreHoldId) return false;
      return ArtistBooksSchedule.dateKey(hold.date) == key &&
          ArtistBooksSchedule.normalizeTimeLabel(hold.timeSlot) == targetTime;
    });
  }

  static bool _isDayOpenForClientBooking({
    required DateTime dayOnly,
    required DateTime today,
    required ArtistBooksSchedule schedule,
    required ArtistBooksSchedule repoSchedule,
    required List<DashboardAppointment> calendarAppointments,
    required List<CustomHold> customHolds,
    required BookingMode mode,
    required bool isPaused,
    required String? artistId,
    required DateTime now,
    BookingSlotType slotType = BookingSlotType.flash,
  }) {
    if (dayOnly.isBefore(today)) return false;

    if (slotType == BookingSlotType.touchUp) {
      if (!schedule.isTouchUpWorkingDay(dayOnly)) return false;
      if (mode == BookingMode.alwaysOpen &&
          isClosedByWeeklyCap(
            date: dayOnly,
            schedule: schedule,
            repoSchedule: repoSchedule,
            calendarAppointments: calendarAppointments,
            customHolds: customHolds,
            mode: mode,
            isPaused: isPaused,
            artistId: artistId,
            now: now,
          )) {
        return false;
      }
      return true;
    }

    if (!schedule.isBooksOpen) return false;

    if (mode == BookingMode.alwaysOpen) {
      if (!schedule.isWorkingDay(dayOnly)) return false;
      if (!schedule.isDateForceOpened(dayOnly) &&
          !schedule.isWithinBookingWindow(dayOnly)) {
        return false;
      }
      if (isClosedByWeeklyCap(
        date: dayOnly,
        schedule: schedule,
        repoSchedule: repoSchedule,
        calendarAppointments: calendarAppointments,
        customHolds: customHolds,
        mode: mode,
        isPaused: isPaused,
        artistId: artistId,
        now: now,
      )) {
        return false;
      }
    } else {
      if (!schedule.workingDays.contains(dayOnly.weekday)) return false;
    }
    return true;
  }

  static bool _isSlotBookableOnPrevalidatedDay({
    required DateTime dayOnly,
    required String timeSlot,
    required ArtistBooksSchedule schedule,
    required ArtistBooksSchedule repoSchedule,
    required List<DashboardAppointment> calendarAppointments,
    required List<CustomHold> customHolds,
    required String? artistId,
    required BookingMode mode,
    required DateTime now,
    required bool hasBookingOrHoldOnDay,
    int? startMinutes,
    int? durationMinutes,
    int? bufferMinutes,
    String? ignoreHoldId,
    BookingSlotType slotType = BookingSlotType.flash,
  }) {
    final resolvedStart =
        startMinutes ?? ScheduleSlotEntry.parseTimeLabelToMinutes(timeSlot);
    if (resolvedStart != null) {
      final isTouchUp = slotType == BookingSlotType.touchUp;
      final defaultDuration = isTouchUp
          ? schedule.touchUpDurationMinutes
          : schedule.slotDurationMinutes;
      final defaultBuffer = isTouchUp
          ? schedule.touchUpBufferMinutes
          : schedule.bufferDurationMinutes;
      return SlotAvailabilityEngine.isIntervalAvailable(
        date: dayOnly,
        startMinutes: resolvedStart,
        durationMinutes: durationMinutes ?? defaultDuration,
        bufferMinutes: bufferMinutes ?? defaultBuffer,
        schedule: schedule,
        localAppointments: matchingAppointments(
          schedule: schedule,
          repoSchedule: repoSchedule,
          calendarAppointments: calendarAppointments,
          artistId: artistId,
        ),
        localHolds: activeLocalHolds(
          schedule: schedule,
          repoSchedule: repoSchedule,
          customHolds: customHolds,
          now: now,
        ),
        now: now,
        enforceLeadTime: mode == BookingMode.alwaysOpen,
        hasBookingOrHoldOnDay: hasBookingOrHoldOnDay,
        requireBufferBeforeClose: false,
        isTouchUp: isTouchUp,
        ignoreHoldId: ignoreHoldId,
      );
    }

    if (isTimeSlotBooked(
      date: dayOnly,
      timeSlot: timeSlot,
      schedule: schedule,
      repoSchedule: repoSchedule,
      calendarAppointments: calendarAppointments,
      artistId: artistId,
    )) {
      return false;
    }
    if (hasActiveHoldForSlot(
      date: dayOnly,
      timeSlot: timeSlot,
      schedule: schedule,
      repoSchedule: repoSchedule,
      customHolds: customHolds,
      now: now,
      ignoreHoldId: ignoreHoldId,
    )) {
      return false;
    }

    final slotDt = ArtistBooksSchedule.parseSlotDateTime(dayOnly, timeSlot);
    if (slotDt != null) {
      if (!slotDt.isAfter(now)) return false;
      if (mode == BookingMode.alwaysOpen &&
          schedule.minLeadTimeHours > 0 &&
          !hasBookingOrHoldOnDay) {
        final cutoff = now.add(Duration(hours: schedule.minLeadTimeHours));
        if (slotDt.isBefore(cutoff)) return false;
      }
    }
    return true;
  }

  static bool isSlotBookable({
    required DateTime date,
    required String timeSlot,
    required ArtistBooksSchedule schedule,
    required ArtistBooksSchedule repoSchedule,
    required List<DashboardAppointment> calendarAppointments,
    required List<CustomHold> customHolds,
    required BookingMode mode,
    required bool isPaused,
    String? artistId,
    DateTime? now,
    int? startMinutes,
    int? durationMinutes,
    int? bufferMinutes,
    String? ignoreHoldId,
    BookingSlotType slotType = BookingSlotType.flash,
  }) {
    final effectiveNow = now ?? DateTime.now();
    final dayOnly = DateTime(date.year, date.month, date.day);
    final today =
        DateTime(effectiveNow.year, effectiveNow.month, effectiveNow.day);

    if (!_isDayOpenForClientBooking(
      dayOnly: dayOnly,
      today: today,
      schedule: schedule,
      repoSchedule: repoSchedule,
      calendarAppointments: calendarAppointments,
      customHolds: customHolds,
      mode: mode,
      isPaused: isPaused,
      artistId: artistId,
      now: effectiveNow,
      slotType: slotType,
    )) {
      return false;
    }

    final hasBookingOrHoldOnDay = isDateOccupied(
      date: dayOnly,
      schedule: schedule,
      repoSchedule: repoSchedule,
      calendarAppointments: calendarAppointments,
      customHolds: customHolds,
      artistId: artistId,
      now: effectiveNow,
    );
    return _isSlotBookableOnPrevalidatedDay(
      dayOnly: dayOnly,
      timeSlot: timeSlot,
      schedule: schedule,
      repoSchedule: repoSchedule,
      calendarAppointments: calendarAppointments,
      customHolds: customHolds,
      artistId: artistId,
      mode: mode,
      now: effectiveNow,
      hasBookingOrHoldOnDay: hasBookingOrHoldOnDay,
      startMinutes: startMinutes,
      durationMinutes: durationMinutes,
      bufferMinutes: bufferMinutes,
      ignoreHoldId: ignoreHoldId,
      slotType: slotType,
    );
  }

  static bool isDateBookable({
    required DateTime date,
    required ArtistBooksSchedule schedule,
    required ArtistBooksSchedule repoSchedule,
    required List<DashboardAppointment> calendarAppointments,
    required List<CustomHold> customHolds,
    required BookingMode mode,
    required bool isPaused,
    String? artistId,
    DateTime? now,
    int? durationMinutes,
    BookingSlotType slotType = BookingSlotType.flash,
  }) {
    final effectiveNow = now ?? DateTime.now();
    final dayOnly = DateTime(date.year, date.month, date.day);
    final today =
        DateTime(effectiveNow.year, effectiveNow.month, effectiveNow.day);

    if (!_isDayOpenForClientBooking(
      dayOnly: dayOnly,
      today: today,
      schedule: schedule,
      repoSchedule: repoSchedule,
      calendarAppointments: calendarAppointments,
      customHolds: customHolds,
      mode: mode,
      isPaused: isPaused,
      artistId: artistId,
      now: effectiveNow,
      slotType: slotType,
    )) {
      return false;
    }

    final hasBookingOrHoldOnDay = isDateOccupied(
      date: dayOnly,
      schedule: schedule,
      repoSchedule: repoSchedule,
      calendarAppointments: calendarAppointments,
      customHolds: customHolds,
      artistId: artistId,
      now: effectiveNow,
    );

    final availableSlots = SlotAvailabilityEngine.generateAvailableSlots(
      date: dayOnly,
      schedule: schedule,
      slotType: slotType,
      requestedDurationMinutes: durationMinutes,
      localAppointments: matchingAppointments(
        schedule: schedule,
        repoSchedule: repoSchedule,
        calendarAppointments: calendarAppointments,
        artistId: artistId,
      ),
      localHolds: activeLocalHolds(
        schedule: schedule,
        repoSchedule: repoSchedule,
        customHolds: customHolds,
        now: effectiveNow,
      ),
      now: effectiveNow,
      enforceLeadTime: mode == BookingMode.alwaysOpen,
      hasBookingOrHoldOnDay: hasBookingOrHoldOnDay,
    );

    return availableSlots.isNotEmpty;
  }

  static bool _isDateInActiveDrop(DateTime date, BookDrop? drop) {
    if (drop == null || drop.status == BookDropStatus.closed) return false;
    final dateOnly = DateTime(date.year, date.month, date.day);
    final startOnly =
        DateTime(drop.startDate.year, drop.startDate.month, drop.startDate.day);
    final endOnly =
        DateTime(drop.endDate.year, drop.endDate.month, drop.endDate.day);
    if (dateOnly.isBefore(startOnly) || dateOnly.isAfter(endOnly)) return false;
    return drop.selectedDays.contains(date.day);
  }

  /// Computes remaining factual open minutes on [date], accounting for
  /// scheduled appointments, active 24h holds, and session buffers.
  static int getRemainingOpenMinutes({
    required DateTime date,
    required ArtistBooksSchedule schedule,
    required List<DashboardAppointment> calendarAppointments,
    required List<DashboardAppointment> appointmentsForDate,
    required List<CustomHold> customHolds,
    required BookingMode bookingMode,
    required BookDrop? currentBookDrop,
    required bool isPaused,
  }) {
    if (isPaused) return 0;

    if (bookingMode == BookingMode.drops) {
      if (!_isDateInActiveDrop(date, currentBookDrop)) return 0;
    } else {
      if (!schedule.isWorkingDay(date) ||
          isClosedByWeeklyCap(
            date: date,
            schedule: schedule,
            repoSchedule: schedule,
            calendarAppointments: calendarAppointments,
            customHolds: customHolds,
            mode: bookingMode,
            isPaused: isPaused,
          )) {
        return 0;
      }
    }

    final holds = customHolds.where((h) =>
        !h.isExpired &&
        h.date.year == date.year &&
        h.date.month == date.month &&
        h.date.day == date.day);

    int busyMinutes = 0;
    for (final apt in appointmentsForDate) {
      busyMinutes += parseDurationMinutes(
            apt.duration,
            fallbackSlotDurationMinutes: schedule.slotDurationMinutes,
          ) +
          schedule.bufferDurationMinutes;
    }
    for (final hold in holds) {
      busyMinutes += hold.durationMinutes + schedule.bufferDurationMinutes;
    }

    final totalDayMinutes =
        (schedule.endTime.hour * 60 + schedule.endTime.minute) -
            (schedule.startTime.hour * 60 + schedule.startTime.minute);
    return (totalDayMinutes - busyMinutes).clamp(0, totalDayMinutes);
  }

  /// Calculates the visual capacity status for a given calendar date.
  static DayCapacityStatus getDayCapacityStatus({
    required DateTime date,
    required ArtistBooksSchedule schedule,
    required List<DashboardAppointment> calendarAppointments,
    required List<DashboardAppointment> appointmentsForDate,
    required List<CustomHold> customHolds,
    required BookingMode bookingMode,
    required BookDrop? currentBookDrop,
    required bool isPaused,
  }) {
    if (bookingMode == BookingMode.drops) {
      if (isPaused || !_isDateInActiveDrop(date, currentBookDrop)) {
        return DayCapacityStatus.closed;
      }
    } else {
      if (schedule.isDateBlocked(date)) {
        return DayCapacityStatus.blocked;
      }
      if (isPaused ||
          !schedule.isWorkingDay(date) ||
          isClosedByWeeklyCap(
            date: date,
            schedule: schedule,
            repoSchedule: schedule,
            calendarAppointments: calendarAppointments,
            customHolds: customHolds,
            mode: bookingMode,
            isPaused: isPaused,
          )) {
        return DayCapacityStatus.closed;
      }
    }

    final remainingMinutes = getRemainingOpenMinutes(
      date: date,
      schedule: schedule,
      calendarAppointments: calendarAppointments,
      appointmentsForDate: appointmentsForDate,
      customHolds: customHolds,
      bookingMode: bookingMode,
      currentBookDrop: currentBookDrop,
      isPaused: isPaused,
    );
    final totalDayMinutes =
        (schedule.endTime.hour * 60 + schedule.endTime.minute) -
            (schedule.startTime.hour * 60 + schedule.startTime.minute);
    if (totalDayMinutes <= 0) return DayCapacityStatus.closed;

    final busyMinutes = totalDayMinutes - remainingMinutes;
    if (remainingMinutes <= 30) {
      return DayCapacityStatus.full;
    }
    if (busyMinutes >= (totalDayMinutes * 0.4).toInt()) {
      return DayCapacityStatus.filling;
    }
    return DayCapacityStatus.open;
  }
}
