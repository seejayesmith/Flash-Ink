import 'package:flutter/material.dart';
import '../../core/mock/mock_data_config.dart';
import '../booking.dart';

enum DayCapacityStatus {
  open,
  filling,
  full,
  blocked,
  closed,
}

/// Compact anonymized slot entry stored on `artist_schedules` so clients
/// can enforce booked/held capacity without reading private `/appointments`.
class ScheduleSlotEntry {
  final String dateKey;
  final String timeSlot;
  final DateTime? expiresAt;

  const ScheduleSlotEntry({
    required this.dateKey,
    required this.timeSlot,
    this.expiresAt,
  });

  bool isActiveAt(DateTime now) =>
      expiresAt == null || now.isBefore(expiresAt!);

  Map<String, dynamic> toMap() => {
        'date': dateKey,
        'time': timeSlot,
        if (expiresAt != null) 'expiresAt': expiresAt!.toIso8601String(),
      };

  factory ScheduleSlotEntry.fromMap(Map<String, dynamic> map) {
    return ScheduleSlotEntry(
      dateKey: (map['date'] ?? '').toString(),
      timeSlot: (map['time'] ?? '').toString(),
      expiresAt: map['expiresAt'] != null
          ? DateTime.tryParse(map['expiresAt'].toString())
          : null,
    );
  }
}

/// Represents the configuration for an artist's booking schedule ("Books").
class ArtistBooksSchedule {
  final bool isBooksOpen;
  final bool isEarlyAccessOnly;
  final DateTime? earlyAccessEndsAt;
  final int earlyAccessHours;
  final DateTime bookingWindowStart;
  final DateTime bookingWindowEnd;
  final Set<int> workingDays; // 1 = Mon, 7 = Sun (DateTime weekday constants)
  final Set<String> blockedDates; // YYYY-MM-DD explicit day-off overrides
  final Set<String> openOverrideDates; // YYYY-MM-DD forced-open overrides
  final int minLeadTimeHours; // 0, 24, 48, 72, 168 (applies to empty days only)
  final int? maxWorkingDaysPerWeek; // Sun-Sat distinct occupied day cap
  final List<ScheduleSlotEntry> bookedSlots; // Server-maintained occupancy
  final List<ScheduleSlotEntry> heldSlots; // Unexpired 24h artist holds
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final int slotDurationMinutes; // e.g. 60, 120, 180
  final int bufferDurationMinutes; // e.g. 15, 30, 45, 60
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
    this.bufferDurationMinutes = 30,
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
    final cleaned = normalizeTimeLabel(timeSlot);
    final match12 = RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM)$').firstMatch(cleaned);
    if (match12 != null) {
      var hour = int.tryParse(match12.group(1)!) ?? 0;
      final minute = int.tryParse(match12.group(2)!) ?? 0;
      final meridiem = match12.group(3)!;
      if (meridiem == 'PM' && hour != 12) hour += 12;
      if (meridiem == 'AM' && hour == 12) hour = 0;
      return DateTime(date.year, date.month, date.day, hour, minute);
    }
    final match24 = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(cleaned);
    if (match24 != null) {
      final hour = int.tryParse(match24.group(1)!) ?? 0;
      final minute = int.tryParse(match24.group(2)!) ?? 0;
      return DateTime(date.year, date.month, date.day, hour, minute);
    }
    return null;
  }

  bool isDateBlocked(DateTime date) => blockedDates.contains(dateKey(date));

  bool isDateForceOpened(DateTime date) =>
      openOverrideDates.contains(dateKey(date));

  /// Returns true if [date] falls inside `[bookingWindowStart, bookingWindowEnd]` (inclusive).
  bool isWithinBookingWindow(DateTime date) {
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

  /// Generates available time slots from the artist's configured working hours,
  /// session duration, and buffer time.
  List<BookingTimeSlot> generateTimeSlots({bool forceDynamic = false}) {
    if (!isBooksOpen) return const [];
    final isDefaultConfig = !forceDynamic &&
        startTime.hour == 11 &&
        startTime.minute == 0 &&
        endTime.hour == 19 &&
        endTime.minute == 0 &&
        slotDurationMinutes == 120 &&
        bufferDurationMinutes == 30;
    if (isDefaultConfig) {
      return BookingTimeSlot.defaultSlots;
    }

    final startTotalMinutes = startTime.hour * 60 + startTime.minute;
    final endTotalMinutes = endTime.hour * 60 + endTime.minute;
    final step = (slotDurationMinutes + bufferDurationMinutes).clamp(15, 720);
    final List<BookingTimeSlot> slots = [];

    int currentMinutes = startTotalMinutes;
    while (currentMinutes + slotDurationMinutes <= endTotalMinutes) {
      final hour24 = currentMinutes ~/ 60;
      final minute = currentMinutes % 60;
      final periodLabel = hour24 < 12
          ? 'Morning'
          : (hour24 < 17 ? 'Afternoon' : 'Evening');
      final suffix = hour24 >= 12 ? 'PM' : 'AM';
      final hour12 = hour24 == 0 ? 12 : (hour24 > 12 ? hour24 - 12 : hour24);
      final minStr = minute.toString().padLeft(2, '0');
      slots.add(
        BookingTimeSlot(
          time: '$hour12:$minStr $suffix',
          period: periodLabel,
        ),
      );
      currentMinutes += step;
    }

    return slots.isEmpty ? BookingTimeSlot.defaultSlots : slots;
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
      'defaultDepositAmount': defaultDepositAmount,
      'acceptFlash': acceptFlash,
      'acceptCustom': acceptCustom,
      'acceptTouchUps': acceptTouchUps,
      'locationNote': locationNote,
    };
  }

  factory ArtistBooksSchedule.fromMap(Map<String, dynamic> map) {
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
              .map((e) => ScheduleSlotEntry.fromMap(Map<String, dynamic>.from(e)))
              .where((e) => e.dateKey.isNotEmpty && e.timeSlot.isNotEmpty)
              .toList() ??
          const [],
      heldSlots: (map['heldSlots'] as List?)
              ?.whereType<Map>()
              .map((e) => ScheduleSlotEntry.fromMap(Map<String, dynamic>.from(e)))
              .where((e) => e.dateKey.isNotEmpty && e.timeSlot.isNotEmpty)
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
      slotDurationMinutes: (map['slotDurationMinutes'] as num?)?.toInt() ?? 120,
      bufferDurationMinutes:
          (map['bufferDurationMinutes'] as num?)?.toInt() ?? 30,
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
