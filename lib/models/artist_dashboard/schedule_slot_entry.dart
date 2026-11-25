/// Compact anonymized interval slot entry stored on `artist_schedules/{artistId}`
/// so public booking clients can enforce half-open interval occupancy `[startMinutes, endMinutes)`
/// without reading private `/appointments` or `/bookings` PII.
class ScheduleSlotEntry {
  static const int defaultFallbackDurationMinutes = 120;
  static const int defaultFallbackBufferMinutes = 60;

  final String date;
  final String time;
  final int startMinutes;
  final int durationMinutes;
  final int bufferMinutes;
  final int endMinutes;
  final String? holdId;
  final DateTime? expiresAt;

  ScheduleSlotEntry({
    String? date,
    String? dateKey,
    String? time,
    String? timeSlot,
    int? startMinutes,
    int? durationMinutes,
    int? bufferMinutes,
    int? endMinutes,
    this.holdId,
    this.expiresAt,
  })  : date = (date ?? dateKey ?? '').trim(),
        time = _resolveTimeLabel(time ?? timeSlot ?? '', startMinutes),
        startMinutes = startMinutes ??
            parseTimeLabelToMinutes(time ?? timeSlot ?? '') ??
            0,
        durationMinutes = durationMinutes ?? defaultFallbackDurationMinutes,
        bufferMinutes = bufferMinutes ?? defaultFallbackBufferMinutes,
        endMinutes = endMinutes ??
            ((startMinutes ??
                    parseTimeLabelToMinutes(time ?? timeSlot ?? '') ??
                    0) +
                (durationMinutes ?? defaultFallbackDurationMinutes) +
                (bufferMinutes ?? defaultFallbackBufferMinutes));

  const ScheduleSlotEntry.raw({
    required this.date,
    required this.time,
    required this.startMinutes,
    required this.durationMinutes,
    required this.bufferMinutes,
    required this.endMinutes,
    this.holdId,
    this.expiresAt,
  });

  /// Legacy alias for [date] (`YYYY-MM-DD`).
  String get dateKey => date;

  /// Legacy alias for [time] (e.g., `"11:00 AM"`).
  String get timeSlot => time;

  bool isActiveAt(DateTime now) =>
      expiresAt == null || now.isBefore(expiresAt!);

  /// Half-open interval overlap check `[startMinutes, endMinutes)` vs `[candidateStart, candidateEnd)`.
  bool overlapsInterval(int candidateStart, int candidateEnd) {
    return candidateStart < endMinutes && startMinutes < candidateEnd;
  }

  static String _resolveTimeLabel(String rawTime, int? startMinutes) {
    final trimmed = rawTime.split('(').first.trim();
    if (trimmed.isNotEmpty) return trimmed;
    if (startMinutes != null && startMinutes >= 0) {
      return formatMinutesToTimeLabel(startMinutes);
    }
    return '';
  }

  /// Parses `"11:00 AM"`, `"1:30 PM (2.5 hrs)"`, or `"14:00"` into minutes from midnight.
  static int? parseTimeLabelToMinutes(String rawTime) {
    final cleaned = rawTime.split('(').first.trim().toUpperCase();
    if (cleaned.isEmpty) return null;

    final match12 =
        RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM)$').firstMatch(cleaned);
    if (match12 != null) {
      var hour = int.tryParse(match12.group(1)!) ?? 0;
      final minute = int.tryParse(match12.group(2)!) ?? 0;
      final meridiem = match12.group(3)!;
      if (meridiem == 'PM' && hour != 12) hour += 12;
      if (meridiem == 'AM' && hour == 12) hour = 0;
      return hour * 60 + minute;
    }

    final matchHourOnly = RegExp(r'^(\d{1,2})\s*(AM|PM)$').firstMatch(cleaned);
    if (matchHourOnly != null) {
      var hour = int.tryParse(matchHourOnly.group(1)!) ?? 0;
      final meridiem = matchHourOnly.group(2)!;
      if (meridiem == 'PM' && hour != 12) hour += 12;
      if (meridiem == 'AM' && hour == 12) hour = 0;
      return hour * 60;
    }

    final match24 = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(cleaned);
    if (match24 != null) {
      final hour = int.tryParse(match24.group(1)!) ?? 0;
      final minute = int.tryParse(match24.group(2)!) ?? 0;
      return hour * 60 + minute;
    }

    return null;
  }

  /// Formats minutes since midnight (e.g. `660`) into 12-hour display label (`"11:00 AM"`).
  static String formatMinutesToTimeLabel(int totalMinutes) {
    final normalized = totalMinutes.clamp(0, 24 * 60 - 1);
    final hour24 = normalized ~/ 60;
    final minute = normalized % 60;
    final suffix = hour24 >= 12 ? 'PM' : 'AM';
    final hour12 = hour24 == 0 ? 12 : (hour24 > 12 ? hour24 - 12 : hour24);
    final minStr = minute.toString().padLeft(2, '0');
    return '$hour12:$minStr $suffix';
  }

  Map<String, dynamic> toMap() => {
        'date': date,
        'time': time,
        'startMinutes': startMinutes,
        'durationMinutes': durationMinutes,
        'bufferMinutes': bufferMinutes,
        'endMinutes': endMinutes,
        if (holdId != null && holdId!.isNotEmpty) 'holdId': holdId,
        if (expiresAt != null) 'expiresAt': expiresAt!.toIso8601String(),
      };

  /// Gracefully parses both interval-enriched documents and legacy `{date, time}` entries.
  factory ScheduleSlotEntry.fromMap(
    Map<String, dynamic> map, {
    int fallbackDurationMinutes = defaultFallbackDurationMinutes,
    int fallbackBufferMinutes = defaultFallbackBufferMinutes,
  }) {
    final rawDate = (map['date'] ?? map['dateKey'] ?? '').toString().trim();
    final rawTime = (map['time'] ?? map['timeSlot'] ?? '').toString().trim();
    final parsedStart = (map['startMinutes'] as num?)?.toInt() ??
        parseTimeLabelToMinutes(rawTime) ??
        0;
    final parsedDuration =
        (map['durationMinutes'] as num?)?.toInt() ?? fallbackDurationMinutes;
    final parsedBuffer =
        (map['bufferMinutes'] as num?)?.toInt() ?? fallbackBufferMinutes;
    final parsedEnd = (map['endMinutes'] as num?)?.toInt() ??
        (parsedStart + parsedDuration + parsedBuffer);
    final resolvedTime = rawTime.isNotEmpty
        ? rawTime.split('(').first.trim()
        : formatMinutesToTimeLabel(parsedStart);

    return ScheduleSlotEntry.raw(
      date: rawDate,
      time: resolvedTime,
      startMinutes: parsedStart,
      durationMinutes: parsedDuration,
      bufferMinutes: parsedBuffer,
      endMinutes: parsedEnd,
      holdId: map['holdId']?.toString(),
      expiresAt: map['expiresAt'] != null
          ? DateTime.tryParse(map['expiresAt'].toString())
          : null,
    );
  }
}
