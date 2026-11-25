import 'package:flutter/material.dart';
import '../../core/mock/mock_data_config.dart';
import '../booking.dart';
import 'schedule_slot_entry.dart';

export 'schedule_slot_entry.dart';

enum DayCapacityStatus {
  open,
  filling,
  full,
  blocked,
  closed,
}

/// Represents the configuration for an artist's booking schedule ("Books").
class ArtistBooksSchedule {
  final bool isBooksOpen;
  final bool isEarlyAccessOnly;
  final DateTime? earlyAccessEndsAt;
  final int earlyAccessHours;
  final DateTime bookingWindowStart;
  final DateTime bookingWindowEnd;
  final bool hasBookingWindow; // false = Always Open (no date limit)
  final Set<int> workingDays; // 1 = Mon, 7 = Sun (DateTime weekday constants)
  final Set<String> blockedDates; // YYYY-MM-DD explicit day-off overrides
  final Set<String> openOverrideDates; // YYYY-MM-DD forced-open overrides
  final int minLeadTimeHours; // 0, 24, 48, 72, 168 (applies to empty days only)
  final int? maxWorkingDaysPerWeek; // Sun-Sat distinct occupied day cap
  final List<ScheduleSlotEntry> bookedSlots; // Server-maintained occupancy
  final List<ScheduleSlotEntry> heldSlots; // Unexpired 24h artist holds
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final int slotDurationMinutes; // e.g. 60, 120, 180, 240
  final int bufferDurationMinutes; // default 60 min cleanup between bookings
  final bool preventDeadGaps; // default true
  final int minBookableSessionMinutes; // default 60 (60, 90, or 120)
  final int defaultDepositAmount; // e.g. 50, 80, 100
  final bool acceptFlash;
  final bool acceptCustom;
  final bool acceptTouchUps;
  final String locationNote;

  const ArtistBooksSchedule({
    this.isBooksOpen = true,
    this.isEarlyAccessOnly = false,
    this.earlyAccessEndsAt,
    this.earlyAccessHours = 24,
    required this.bookingWindowStart,
    required this.bookingWindowEnd,
    this.hasBookingWindow = true,
    this.workingDays = const {2, 3, 4, 5, 6}, // Tue - Sat
    this.blockedDates = const {},
    this.openOverrideDates = const {},
    this.minLeadTimeHours = 0,
    this.maxWorkingDaysPerWeek,
    this.bookedSlots = const [],
    this.heldSlots = const [],
    this.startTime = const TimeOfDay(hour: 11, minute: 0),
    this.endTime = const TimeOfDay(hour: 19, minute: 0),
    this.slotDurationMinutes = 120,
    this.bufferDurationMinutes = 60,
    this.preventDeadGaps = true,
    this.minBookableSessionMinutes = 60,
    this.defaultDepositAmount = 80,
    this.acceptFlash = true,
    this.acceptCustom = true,
    this.acceptTouchUps = true,
    this.locationNote = 'OddMaree Studio • Portland, OR',
  });

  /// Formats [dt] into a canonical `YYYY-MM-DD` local calendar date key.
  static String dateKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  /// Normalizes display slot labels such as `"1:30 PM (3.0 hrs)"` to `"1:30 PM"`.
  static String normalizeTimeLabel(String timeSlot) =>
      timeSlot.split('(').first.trim().toUpperCase();

  /// Returns local midnight of the Sunday starting the Sun–Sat week containing [date].
  static DateTime weekStartSunday(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return DateTime(
      normalized.year,
      normalized.month,
      normalized.day - (normalized.weekday % 7),
    );
  }

  /// Parses [timeSlot] on [date] into a local [DateTime], or `null` if invalid.
  static DateTime? parseSlotDateTime(DateTime date, String timeSlot) {
    final mins = ScheduleSlotEntry.parseTimeLabelToMinutes(timeSlot);
    if (mins == null) return null;
    return DateTime(date.year, date.month, date.day, mins ~/ 60, mins % 60);
  }

  bool isDateBlocked(DateTime date) => blockedDates.contains(dateKey(date));

  bool isDateForceOpened(DateTime date) =>
      openOverrideDates.contains(dateKey(date));

  /// Returns true if [date] falls inside `[bookingWindowStart, bookingWindowEnd]` (inclusive),
  /// or `true` for all dates when [hasBookingWindow] is `false` (Always Open).
  bool isWithinBookingWindow(DateTime date) {
    if (!hasBookingWindow) return true;
    final dayOnly = DateTime(date.year, date.month, date.day);
    final startOnly = DateTime(
      bookingWindowStart.year,
      bookingWindowStart.month,
      bookingWindowStart.day,
    );
    final endOnly = DateTime(
      bookingWindowEnd.year,
      bookingWindowEnd.month,
      bookingWindowEnd.day,
    );
    if (endOnly.isBefore(startOnly)) return true;
    return !dayOnly.isBefore(startOnly) && !dayOnly.isAfter(endOnly);
  }

  /// Returns true if books are open and [date] is either force-opened or an
  /// unblocked configured working weekday.
  bool isWorkingDay(DateTime date) {
    if (!isBooksOpen) return false;
    final key = dateKey(date);
    if (blockedDates.contains(key)) return false;
    if (openOverrideDates.contains(key)) return true;
    return workingDays.contains(date.weekday);
  }

  /// Generates candidate hourly time slots anchored to [startTime] where a session
  /// of [durationMinutes] (default [slotDurationMinutes]) finishes on or before [endTime].
  ///
  /// Cleanup buffer is required *between* bookings (`requireBufferBeforeClose = false`),
  /// so the final session of the day may run right up to [endTime].
  List<BookingTimeSlot> generateTimeSlots({
    bool forceDynamic = false,
    int? durationMinutes,
  }) {
    if (!isBooksOpen) return const [];
    final startTotalMinutes = startTime.hour * 60 + startTime.minute;
    final endTotalMinutes = endTime.hour * 60 + endTime.minute;
    final effectiveDuration =
        (durationMinutes ?? slotDurationMinutes).clamp(15, 720);
    const int hourlyStep = 60;
    final List<BookingTimeSlot> slots = [];

    int currentMinutes = startTotalMinutes;
    while (currentMinutes + effectiveDuration <= endTotalMinutes) {
      final hour24 = currentMinutes ~/ 60;
      final periodLabel = hour24 < 12
          ? 'Morning'
          : (hour24 < 17 ? 'Afternoon' : 'Evening');
      slots.add(
        BookingTimeSlot(
          time: ScheduleSlotEntry.formatMinutesToTimeLabel(currentMinutes),
          period: periodLabel,
        ),
      );
      currentMinutes += hourlyStep;
    }

    return slots;
  }

  bool get isEffectiveBooksOpen {
    if (!isBooksOpen) return false;
    if (isEarlyAccessOnly) {
      if (earlyAccessEndsAt != null &&
          DateTime.now().isAfter(earlyAccessEndsAt!)) {
        return true; // Auto-transitioned to public open!
      }
      return false; // Still exclusive early access
    }
    return true;
  }

  bool get isEarlyAccessActive {
    if (!isBooksOpen || !isEarlyAccessOnly) return false;
    if (earlyAccessEndsAt != null &&
        DateTime.now().isAfter(earlyAccessEndsAt!)) {
      return false; // Expired
    }
    return true;
  }

  Duration? get earlyAccessTimeRemaining {
    if (!isEarlyAccessActive || earlyAccessEndsAt == null) return null;
    final diff = earlyAccessEndsAt!.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  ArtistBooksSchedule copyWith({
    bool? isBooksOpen,
    bool? isEarlyAccessOnly,
    DateTime? earlyAccessEndsAt,
    bool clearEarlyAccessEndsAt = false,
    int? earlyAccessHours,
    DateTime? bookingWindowStart,
    DateTime? bookingWindowEnd,
    bool? hasBookingWindow,
    Set<int>? workingDays,
    Set<String>? blockedDates,
    Set<String>? openOverrideDates,
    int? minLeadTimeHours,
    int? maxWorkingDaysPerWeek,
    bool clearMaxWorkingDaysPerWeek = false,
    List<ScheduleSlotEntry>? bookedSlots,
    List<ScheduleSlotEntry>? heldSlots,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    int? slotDurationMinutes,
    int? bufferDurationMinutes,
    bool? preventDeadGaps,
    int? minBookableSessionMinutes,
    int? defaultDepositAmount,
    bool? acceptFlash,
    bool? acceptCustom,
    bool? acceptTouchUps,
    String? locationNote,
  }) {
    return ArtistBooksSchedule(
      isBooksOpen: isBooksOpen ?? this.isBooksOpen,
      isEarlyAccessOnly: isEarlyAccessOnly ?? this.isEarlyAccessOnly,
      earlyAccessEndsAt: clearEarlyAccessEndsAt
          ? null
          : (earlyAccessEndsAt ?? this.earlyAccessEndsAt),
      earlyAccessHours: earlyAccessHours ?? this.earlyAccessHours,
      bookingWindowStart: bookingWindowStart ?? this.bookingWindowStart,
      bookingWindowEnd: bookingWindowEnd ?? this.bookingWindowEnd,
      hasBookingWindow: hasBookingWindow ?? this.hasBookingWindow,
      workingDays: workingDays ?? this.workingDays,
      blockedDates: blockedDates ?? this.blockedDates,
      openOverrideDates: openOverrideDates ?? this.openOverrideDates,
      minLeadTimeHours: minLeadTimeHours ?? this.minLeadTimeHours,
      maxWorkingDaysPerWeek: clearMaxWorkingDaysPerWeek
          ? null
          : (maxWorkingDaysPerWeek ?? this.maxWorkingDaysPerWeek),
      bookedSlots: bookedSlots ?? this.bookedSlots,
      heldSlots: heldSlots ?? this.heldSlots,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      slotDurationMinutes: slotDurationMinutes ?? this.slotDurationMinutes,
      bufferDurationMinutes:
          bufferDurationMinutes ?? this.bufferDurationMinutes,
      preventDeadGaps: preventDeadGaps ?? this.preventDeadGaps,
      minBookableSessionMinutes:
          minBookableSessionMinutes ?? this.minBookableSessionMinutes,
      defaultDepositAmount: defaultDepositAmount ?? this.defaultDepositAmount,
      acceptFlash: acceptFlash ?? this.acceptFlash,
      acceptCustom: acceptCustom ?? this.acceptCustom,
      acceptTouchUps: acceptTouchUps ?? this.acceptTouchUps,
      locationNote: locationNote ?? this.locationNote,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'isBooksOpen': isBooksOpen,
      'isEarlyAccessOnly': isEarlyAccessOnly,
      'earlyAccessEndsAt': earlyAccessEndsAt?.toIso8601String(),
      'earlyAccessHours': earlyAccessHours,
      'bookingWindowStart': bookingWindowStart.toIso8601String(),
      'bookingWindowEnd': bookingWindowEnd.toIso8601String(),
      'hasBookingWindow': hasBookingWindow,
      'workingDays': workingDays.toList()..sort(),
      'blockedDates': blockedDates.toList()..sort(),
      'openOverrideDates': openOverrideDates.toList()..sort(),
      'minLeadTimeHours': minLeadTimeHours,
      'maxWorkingDaysPerWeek': maxWorkingDaysPerWeek,
      'heldSlots': heldSlots.map((e) => e.toMap()).toList(),
      // Omit bookedSlots so client writes preserve server-maintained Cloud Function data.
      'startHour': startTime.hour,
      'startMinute': startTime.minute,
      'endHour': endTime.hour,
      'endMinute': endTime.minute,
      'slotDurationMinutes': slotDurationMinutes,
      'bufferDurationMinutes': bufferDurationMinutes,
      'preventDeadGaps': preventDeadGaps,
      'minBookableSessionMinutes': minBookableSessionMinutes,
      'defaultDepositAmount': defaultDepositAmount,
      'acceptFlash': acceptFlash,
      'acceptCustom': acceptCustom,
      'acceptTouchUps': acceptTouchUps,
      'locationNote': locationNote,
    };
  }

  factory ArtistBooksSchedule.fromMap(Map<String, dynamic> map) {
    final parsedSlotDuration =
        (map['slotDurationMinutes'] as num?)?.toInt() ?? 120;
    final parsedBuffer = (map['bufferDurationMinutes'] as num?)?.toInt() ?? 60;
    return ArtistBooksSchedule(
      isBooksOpen: map['isBooksOpen'] as bool? ?? true,
      isEarlyAccessOnly: map['isEarlyAccessOnly'] as bool? ?? false,
      earlyAccessEndsAt: map['earlyAccessEndsAt'] != null
          ? DateTime.tryParse(map['earlyAccessEndsAt'] as String)
          : null,
      earlyAccessHours: (map['earlyAccessHours'] as num?)?.toInt() ?? 24,
      bookingWindowStart: map['bookingWindowStart'] != null
          ? DateTime.tryParse(map['bookingWindowStart'] as String) ??
              DateTime(2026, 10, 1)
          : DateTime(2026, 10, 1),
      bookingWindowEnd: map['bookingWindowEnd'] != null
          ? DateTime.tryParse(map['bookingWindowEnd'] as String) ??
              DateTime(2026, 12, 31)
          : DateTime(2026, 12, 31),
      hasBookingWindow: map.containsKey('hasBookingWindow')
          ? (map['hasBookingWindow'] as bool? ?? false)
          : (map['bookingWindowStart'] != null &&
              map['bookingWindowEnd'] != null),
      workingDays: map['workingDays'] != null
          ? (map['workingDays'] as List).map((e) => (e as num).toInt()).toSet()
          : const {2, 3, 4, 5, 6},
      blockedDates: (map['blockedDates'] as List?)
              ?.map((e) => e.toString())
              .where((s) => s.isNotEmpty)
              .toSet() ??
          const {},
      openOverrideDates: (map['openOverrideDates'] as List?)
              ?.map((e) => e.toString())
              .where((s) => s.isNotEmpty)
              .toSet() ??
          const {},
      minLeadTimeHours: (map['minLeadTimeHours'] as num?)?.toInt() ?? 0,
      maxWorkingDaysPerWeek: (map['maxWorkingDaysPerWeek'] as num?)?.toInt(),
      bookedSlots: (map['bookedSlots'] as List?)
              ?.whereType<Map>()
              .map(
                (e) => ScheduleSlotEntry.fromMap(
                  Map<String, dynamic>.from(e),
                  fallbackDurationMinutes:
                      ScheduleSlotEntry.defaultFallbackDurationMinutes,
                  fallbackBufferMinutes:
                      ScheduleSlotEntry.defaultFallbackBufferMinutes,
                ),
              )
              .where((e) => e.date.isNotEmpty && e.time.isNotEmpty)
              .toList() ??
          const [],
      heldSlots: (map['heldSlots'] as List?)
              ?.whereType<Map>()
              .map(
                (e) => ScheduleSlotEntry.fromMap(
                  Map<String, dynamic>.from(e),
                  fallbackDurationMinutes:
                      ScheduleSlotEntry.defaultFallbackDurationMinutes,
                  fallbackBufferMinutes:
                      ScheduleSlotEntry.defaultFallbackBufferMinutes,
                ),
              )
              .where((e) => e.date.isNotEmpty && e.time.isNotEmpty)
              .toList() ??
          const [],
      startTime: TimeOfDay(
        hour: (map['startHour'] as num?)?.toInt() ?? 11,
        minute: (map['startMinute'] as num?)?.toInt() ?? 0,
      ),
      endTime: TimeOfDay(
        hour: (map['endHour'] as num?)?.toInt() ?? 19,
        minute: (map['endMinute'] as num?)?.toInt() ?? 0,
      ),
      slotDurationMinutes: parsedSlotDuration,
      bufferDurationMinutes: parsedBuffer,
      preventDeadGaps: map['preventDeadGaps'] as bool? ?? true,
      minBookableSessionMinutes:
          (map['minBookableSessionMinutes'] as num?)?.toInt() ?? 60,
      defaultDepositAmount:
          (map['defaultDepositAmount'] as num?)?.toInt() ?? 80,
      acceptFlash: map['acceptFlash'] as bool? ?? true,
      acceptCustom: map['acceptCustom'] as bool? ?? true,
      acceptTouchUps: map['acceptTouchUps'] as bool? ?? true,
      locationNote: map['locationNote'] as String? ??
          (MockDataConfig.isEnabled ? 'OddMaree Studio • Portland, OR' : ''),
    );
  }
}
