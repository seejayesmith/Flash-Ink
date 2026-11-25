import '../../models/artist_dashboard/artist_books_schedule.dart';
import '../../models/artist_dashboard/book_drop.dart';
import '../../models/artist_dashboard/dashboard_appointment.dart';
import 'booking_slot_profile.dart';

/// Represents a candidate hourly start slot evaluated by [SlotAvailabilityEngine].
class AvailableSlot {
  final String time;
  final String period;
  final int startMinutes;
  final int durationMinutes;
  final int bufferMinutes;
  final int sessionEndMinutes;
  final int blockedEndMinutes;
  final bool isBookedConflict;
  final bool isHeldConflict;
  final bool isLeadTimeBlocked;
  final bool createsDeadGap;

  const AvailableSlot({
    required this.time,
    required this.period,
    required this.startMinutes,
    required this.durationMinutes,
    required this.bufferMinutes,
    required this.sessionEndMinutes,
    required this.blockedEndMinutes,
    this.isBookedConflict = false,
    this.isHeldConflict = false,
    this.isLeadTimeBlocked = false,
    this.createsDeadGap = false,
  });

  bool get isConflicted =>
      isBookedConflict || isHeldConflict || isLeadTimeBlocked;

  bool get isOptimal => !isConflicted && !createsDeadGap;
}

/// Core interval-based hourly scheduling engine with half-open overlap math
/// `[startMinutes, endMinutes)` and smart dead-gap protection.
class SlotAvailabilityEngine {
  const SlotAvailabilityEngine._();

  static const int hourlyGridStepMinutes = 60;

  /// Half-open interval overlap check: `[aStart, aEnd)` overlaps `[bStart, bEnd)`
  /// iff `aStart < bEnd && bStart < aEnd`.
  static bool intervalsOverlap(int aStart, int aEnd, int bStart, int bEnd) {
    return aStart < bEnd && bStart < aEnd;
  }

  /// Snaps [minutes] up to the next 60-minute boundary anchored at [gridOrigin]
  /// so fractional durations (e.g., 1.5-hr pieces) do not trigger false dead gaps.
  static int snapUpToHourlyGrid(int minutes, int gridOrigin) {
    if (minutes <= gridOrigin) return gridOrigin;
    final offset = minutes - gridOrigin;
    final remainder = offset % hourlyGridStepMinutes;
    return remainder == 0
        ? minutes
        : minutes + (hourlyGridStepMinutes - remainder);
  }

  /// Parses duration labels like `"1.5 hrs"`, `"3 hrs"`, `"90 mins"` into minutes.
  static int parseDurationMinutes(
    String? rawDuration, {
    required int fallbackMinutes,
  }) {
    final lower = (rawDuration ?? '').toLowerCase().trim();
    if (lower.isEmpty) return fallbackMinutes;
    final match = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(lower);
    if (match == null) return fallbackMinutes;
    final val = double.tryParse(match.group(1)!) ?? (fallbackMinutes / 60.0);
    if (lower.contains('min')) {
      return val.round().clamp(15, 720);
    }
    return (val * 60).round().clamp(15, 720);
  }

  /// Collects booked and active held [ScheduleSlotEntry] intervals on [date]
  /// from both [schedule] and optional local repository appointments/holds.
  static ({
    List<ScheduleSlotEntry> booked,
    List<ScheduleSlotEntry> held,
  }) collectOccupiedForDate({
    required DateTime date,
    required ArtistBooksSchedule schedule,
    Iterable<DashboardAppointment> localAppointments = const [],
    Iterable<CustomHold> localHolds = const [],
    DateTime? now,
    String? ignoreHoldId,
  }) {
    final effectiveNow = now ?? DateTime.now();
    final key = ArtistBooksSchedule.dateKey(date);

    final bookedByRange = <String, ScheduleSlotEntry>{};
    for (final entry in schedule.bookedSlots) {
      if (entry.date == key) {
        bookedByRange['${entry.startMinutes}_${entry.endMinutes}'] = entry;
      }
    }
    for (final apt in localAppointments) {
      if (apt.scheduledDate == null) continue;
      if (ArtistBooksSchedule.dateKey(apt.scheduledDate!) != key) continue;
      final start = ScheduleSlotEntry.parseTimeLabelToMinutes(apt.time);
      if (start == null) continue;
      final dur = parseDurationMinutes(
        apt.duration,
        fallbackMinutes: schedule.slotDurationMinutes,
      );
      final buf = schedule.bufferDurationMinutes;
      final entry = ScheduleSlotEntry.raw(
        date: key,
        time: ScheduleSlotEntry.formatMinutesToTimeLabel(start),
        startMinutes: start,
        durationMinutes: dur,
        bufferMinutes: buf,
        endMinutes: start + dur + buf,
      );
      bookedByRange.putIfAbsent(
        '${entry.startMinutes}_${entry.endMinutes}',
        () => entry,
      );
    }

    final heldByRange = <String, ScheduleSlotEntry>{};
    for (final entry in schedule.heldSlots) {
      if (entry.date != key) continue;
      if (!entry.isActiveAt(effectiveNow)) continue;
      if (ignoreHoldId != null &&
          ignoreHoldId.isNotEmpty &&
          entry.holdId == ignoreHoldId) {
        continue;
      }
      heldByRange['${entry.startMinutes}_${entry.endMinutes}'] = entry;
    }
    for (final hold in localHolds) {
      if (ArtistBooksSchedule.dateKey(hold.date) != key) continue;
      if (effectiveNow.isAfter(hold.expiresAt)) continue;
      if (ignoreHoldId != null &&
          ignoreHoldId.isNotEmpty &&
          hold.id == ignoreHoldId) {
        continue;
      }
      final start = ScheduleSlotEntry.parseTimeLabelToMinutes(hold.timeSlot);
      if (start == null) continue;
      final dur = hold.durationMinutes;
      final buf = schedule.bufferDurationMinutes;
      final entry = ScheduleSlotEntry.raw(
        date: key,
        time: ScheduleSlotEntry.formatMinutesToTimeLabel(start),
        startMinutes: start,
        durationMinutes: dur,
        bufferMinutes: buf,
        endMinutes: start + dur + buf,
        holdId: hold.id,
        expiresAt: hold.expiresAt,
      );
      heldByRange.putIfAbsent(
        '${entry.startMinutes}_${entry.endMinutes}',
        () => entry,
      );
    }

    return (
      booked: bookedByRange.values.toList(),
      held: heldByRange.values.toList(),
    );
  }

  /// Generates hourly candidate slots anchored to [schedule.startTime], applying
  /// half-open interval overlap checks and smart dead-gap detection.
  ///
  /// When [includeConflicted] is `false` (default), only bookable non-overlapping
  /// slots are returned (and dead-gap slots are omitted when `profile.filterDeadGaps`
  /// is `true`). Set [includeConflicted] to `true` when UI screens want to render
  /// disabled `(Booked)` / `(Held)` chips alongside open slots.
  static List<AvailableSlot> generateAvailableSlots({
    required DateTime date,
    required ArtistBooksSchedule schedule,
    BookingSlotProfile? profile,
    BookingSlotType slotType = BookingSlotType.flash,
    int? requestedDurationMinutes,
    Iterable<DashboardAppointment> localAppointments = const [],
    Iterable<CustomHold> localHolds = const [],
    DateTime? now,
    bool enforceLeadTime = false,
    bool hasBookingOrHoldOnDay = false,
    String? ignoreHoldId,
    bool includeConflicted = false,
  }) {
    if (!schedule.isBooksOpen) return const [];

    final resolvedProfile = profile ??
        BookingSlotProfile.forType(
          slotType,
          schedule: schedule,
          requestedDurationMinutes: requestedDurationMinutes,
        );

    final dayStart = schedule.startTime.hour * 60 + schedule.startTime.minute;
    final dayEnd = schedule.endTime.hour * 60 + schedule.endTime.minute;
    if (dayEnd <= dayStart) return const [];

    final occupied = collectOccupiedForDate(
      date: date,
      schedule: schedule,
      localAppointments: localAppointments,
      localHolds: localHolds,
      now: now,
      ignoreHoldId: ignoreHoldId,
    );
    final allOccupied = <ScheduleSlotEntry>[
      ...occupied.booked,
      ...occupied.held,
    ]..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));

    final dayHasOccupancy = hasBookingOrHoldOnDay || allOccupied.isNotEmpty;
    final minUsableBeforeBooking =
        schedule.minBookableSessionMinutes + schedule.bufferDurationMinutes;
    final minUsableBeforeClose = schedule.minBookableSessionMinutes;

    final results = <AvailableSlot>[];
    int candidateStart = dayStart;

    while (true) {
      final sessionEnd = candidateStart + resolvedProfile.durationMinutes;
      final blockedEnd = sessionEnd + resolvedProfile.bufferMinutes;
      final requiredDayEnd =
          resolvedProfile.requireBufferBeforeClose ? blockedEnd : sessionEnd;
      if (requiredDayEnd > dayEnd) break;

      final isBookedConflict = occupied.booked.any(
        (b) => intervalsOverlap(
          candidateStart,
          blockedEnd,
          b.startMinutes,
          b.endMinutes,
        ),
      );
      final isHeldConflict = !isBookedConflict &&
          occupied.held.any(
            (h) => intervalsOverlap(
              candidateStart,
              blockedEnd,
              h.startMinutes,
              h.endMinutes,
            ),
          );

      bool isLeadTimeBlocked = false;
      if (enforceLeadTime && now != null) {
        final slotDt = DateTime(
          date.year,
          date.month,
          date.day,
          candidateStart ~/ 60,
          candidateStart % 60,
        );
        if (!slotDt.isAfter(now)) {
          isLeadTimeBlocked = true;
        } else if (schedule.minLeadTimeHours > 0 && !dayHasOccupancy) {
          final cutoff = now.add(Duration(hours: schedule.minLeadTimeHours));
          if (slotDt.isBefore(cutoff)) {
            isLeadTimeBlocked = true;
          }
        }
      }

      final hasConflict =
          isBookedConflict || isHeldConflict || isLeadTimeBlocked;

      bool createsDeadGap = false;
      if (!hasConflict &&
          resolvedProfile.type != BookingSlotType.touchUp &&
          schedule.preventDeadGaps) {
        // 1. Gap BEFORE candidateStart
        int? latestPrevEnd;
        for (final occ in allOccupied) {
          if (occ.endMinutes <= candidateStart) {
            if (latestPrevEnd == null || occ.endMinutes > latestPrevEnd) {
              latestPrevEnd = occ.endMinutes;
            }
          }
        }
        final prevBoundary = latestPrevEnd != null
            ? snapUpToHourlyGrid(latestPrevEnd, dayStart)
            : dayStart;
        final gapBefore = candidateStart - prevBoundary;
        final beforeIsDead =
            gapBefore > 0 && gapBefore < minUsableBeforeBooking;

        // 2. Gap AFTER candidate blockedEnd
        int? earliestNextStart;
        for (final occ in allOccupied) {
          if (occ.startMinutes >= blockedEnd) {
            if (earliestNextStart == null ||
                occ.startMinutes < earliestNextStart) {
              earliestNextStart = occ.startMinutes;
            }
          }
        }
        final snappedBlockedEnd = snapUpToHourlyGrid(blockedEnd, dayStart);
        final bool afterIsDead;
        if (earliestNextStart != null) {
          final gapAfter = earliestNextStart - snappedBlockedEnd;
          afterIsDead = gapAfter > 0 && gapAfter < minUsableBeforeBooking;
        } else {
          final gapAfterClose = dayEnd - snappedBlockedEnd;
          afterIsDead =
              gapAfterClose > 0 && gapAfterClose < minUsableBeforeClose;
        }

        createsDeadGap = beforeIsDead || afterIsDead;
      }

      final hour24 = candidateStart ~/ 60;
      final periodLabel = hour24 < 12
          ? 'Morning'
          : (hour24 < 17 ? 'Afternoon' : 'Evening');
      final slot = AvailableSlot(
        time: ScheduleSlotEntry.formatMinutesToTimeLabel(candidateStart),
        period: periodLabel,
        startMinutes: candidateStart,
        durationMinutes: resolvedProfile.durationMinutes,
        bufferMinutes: resolvedProfile.bufferMinutes,
        sessionEndMinutes: sessionEnd,
        blockedEndMinutes: blockedEnd,
        isBookedConflict: isBookedConflict,
        isHeldConflict: isHeldConflict,
        isLeadTimeBlocked: isLeadTimeBlocked,
        createsDeadGap: createsDeadGap,
      );

      if (hasConflict) {
        if (includeConflicted && !isLeadTimeBlocked) {
          results.add(slot);
        }
      } else if (!(resolvedProfile.filterDeadGaps && createsDeadGap)) {
        results.add(slot);
      }

      candidateStart += hourlyGridStepMinutes;
    }

    return results;
  }

  /// Validates whether a specific interval `[startMinutes, startMinutes + durationMinutes + bufferMinutes)`
  /// is free of overlaps and fits within [schedule]'s working hours on [date].
  static bool isIntervalAvailable({
    required DateTime date,
    required int startMinutes,
    required int durationMinutes,
    required int bufferMinutes,
    required ArtistBooksSchedule schedule,
    Iterable<DashboardAppointment> localAppointments = const [],
    Iterable<CustomHold> localHolds = const [],
    DateTime? now,
    bool enforceLeadTime = false,
    bool hasBookingOrHoldOnDay = false,
    bool requireBufferBeforeClose = false,
    String? ignoreHoldId,
  }) {
    if (!schedule.isBooksOpen) return false;
    final dayStart = schedule.startTime.hour * 60 + schedule.startTime.minute;
    final dayEnd = schedule.endTime.hour * 60 + schedule.endTime.minute;
    final sessionEnd = startMinutes + durationMinutes;
    final blockedEnd = sessionEnd + bufferMinutes;
    final requiredEnd = requireBufferBeforeClose ? blockedEnd : sessionEnd;

    if (startMinutes < dayStart || requiredEnd > dayEnd) {
      return false;
    }

    final occupied = collectOccupiedForDate(
      date: date,
      schedule: schedule,
      localAppointments: localAppointments,
      localHolds: localHolds,
      now: now,
      ignoreHoldId: ignoreHoldId,
    );

    for (final b in occupied.booked) {
      if (intervalsOverlap(
        startMinutes,
        blockedEnd,
        b.startMinutes,
        b.endMinutes,
      )) {
        return false;
      }
    }
    for (final h in occupied.held) {
      if (intervalsOverlap(
        startMinutes,
        blockedEnd,
        h.startMinutes,
        h.endMinutes,
      )) {
        return false;
      }
    }

    if (enforceLeadTime && now != null) {
      final slotDt = DateTime(
        date.year,
        date.month,
        date.day,
        startMinutes ~/ 60,
        startMinutes % 60,
      );
      if (!slotDt.isAfter(now)) return false;
      final dayOccupied = hasBookingOrHoldOnDay ||
          occupied.booked.isNotEmpty ||
          occupied.held.isNotEmpty;
      if (schedule.minLeadTimeHours > 0 && !dayOccupied) {
        final cutoff = now.add(Duration(hours: schedule.minLeadTimeHours));
        if (slotDt.isBefore(cutoff)) return false;
      }
    }

    return true;
  }
}
