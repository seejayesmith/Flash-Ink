import '../../features/appointments/domain/models/appointment_item.dart';
import '../../models/artist_dashboard/artist_books_schedule.dart';

/// Outcome of evaluating whether a client may self-book a touch-up for a past tattoo.
enum TouchUpEligibilityStatus {
  eligible,
  notCompleted,
  artistDisabledTouchUps,
  tooEarlyToHeal,
  alreadyUsedForTattoo,
  hasActiveUpcomingTouchUp,
  windowExpired,
}

/// Structured result returned by [TouchUpEligibilityService.evaluate].
class TouchUpEligibilityResult {
  final TouchUpEligibilityStatus status;
  final String summary;
  final DateTime? availableAfter;
  final DateTime? windowEndsAt;
  final int feeDollars;
  final int durationMinutes;
  final int bufferMinutes;
  final int windowMonths;

  const TouchUpEligibilityResult({
    required this.status,
    required this.summary,
    this.availableAfter,
    this.windowEndsAt,
    this.feeDollars = 0,
    this.durationMinutes = 30,
    this.bufferMinutes = 30,
    this.windowMonths = 6,
  });

  bool get isEligible => status == TouchUpEligibilityStatus.eligible;
  bool get isFree => feeDollars <= 0;

  /// True when the client should be directed to message the artist in chat
  /// rather than self-booking (past window, already used 1 free/self-booked
  /// touch-up, or artist turned off self-booked touch-ups).
  bool get shouldDirectToChat =>
      status == TouchUpEligibilityStatus.windowExpired ||
      status == TouchUpEligibilityStatus.alreadyUsedForTattoo ||
      status == TouchUpEligibilityStatus.artistDisabledTouchUps;
}

/// Pure client-side mirror of the server's touch-up eligibility rules.
///
/// Mirrors `functions/src/touchups.ts` (`validateTouchUpEligibility`):
/// - Original tattoo must be completed and not itself a touch-up
/// - Artist must have `acceptTouchUps == true` (independent of `isBooksOpen`)
/// - Unlocks 7 days after original session date (minimum initial healing time)
/// - Must be within the artist's configured `touchUpWindowMonths` (default 6 months)
/// - Maximum 1 self-booked touch-up per original tattoo AND max 1 active upcoming touch-up
class TouchUpEligibilityService {
  const TouchUpEligibilityService._();

  static const int minHealingDays = 7;

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String formatShortDate(DateTime dt) =>
      '${_months[dt.month - 1]} ${dt.day}, ${dt.year}';

  static String formatDurationLabel(int minutes) {
    if (minutes < 60) return '$minutes min';
    final hrs = minutes / 60;
    if (hrs == hrs.roundToDouble()) {
      final whole = hrs.round();
      return '$whole ${whole == 1 ? 'hr' : 'hrs'}';
    }
    return '${hrs.toStringAsFixed(1)} hrs';
  }

  /// Adds calendar [months] to [base] while clamping overflow days (e.g., Aug 31 + 6m -> Feb 28).
  static DateTime addMonths(DateTime base, int months) {
    final totalMonths = (base.year * 12 + (base.month - 1)) + months;
    final targetYear = totalMonths ~/ 12;
    final targetMonth = (totalMonths % 12) + 1;
    final maxDay = DateTime(targetYear, targetMonth + 1, 0).day;
    return DateTime(
      targetYear,
      targetMonth,
      base.day > maxDay ? maxDay : base.day,
    );
  }

  static bool _matchesArtist(
    ClientAppointment appointment, {
    String? artistId,
    String? artistName,
  }) {
    final targetId = artistId?.trim() ?? '';
    final aptId = appointment.artistId?.trim() ?? '';
    if (targetId.isNotEmpty && aptId.isNotEmpty) {
      return targetId == aptId;
    }
    final targetName = artistName?.trim().toLowerCase() ?? '';
    final aptName = appointment.artistName.trim().toLowerCase();
    return targetName.isNotEmpty && aptName == targetName;
  }

  /// Evaluates touch-up self-booking eligibility for [originalAppointment].
  static TouchUpEligibilityResult evaluate({
    required ClientAppointment originalAppointment,
    required ArtistBooksSchedule schedule,
    List<ClientAppointment>? allClientAppointments,
    DateTime? now,
  }) {
    final durationMinutes = schedule.touchUpDurationMinutes.clamp(15, 720);
    final bufferMinutes = schedule.touchUpBufferMinutes.clamp(0, 240);
    final windowMonths = schedule.touchUpWindowMonths.clamp(1, 36);
    final feeDollars = schedule.touchUpFeeDollars.clamp(0, 10000);

    if (originalAppointment.isTouchUp ||
        originalAppointment.status != AppointmentStatus.completed) {
      return TouchUpEligibilityResult(
        status: TouchUpEligibilityStatus.notCompleted,
        summary: 'Touch-ups can only be booked for completed tattoo sessions.',
        feeDollars: feeDollars,
        durationMinutes: durationMinutes,
        bufferMinutes: bufferMinutes,
        windowMonths: windowMonths,
      );
    }

    if (!schedule.acceptTouchUps) {
      return TouchUpEligibilityResult(
        status: TouchUpEligibilityStatus.artistDisabledTouchUps,
        summary:
            '${originalAppointment.artistName} is not currently accepting self-booked touch-ups. Message them in chat to arrange a follow-up.',
        feeDollars: feeDollars,
        durationMinutes: durationMinutes,
        bufferMinutes: bufferMinutes,
        windowMonths: windowMonths,
      );
    }

    final effectiveNow = now ?? DateTime.now();
    final today =
        DateTime(effectiveNow.year, effectiveNow.month, effectiveNow.day);
    final origDay = DateTime(
      originalAppointment.dateTime.year,
      originalAppointment.dateTime.month,
      originalAppointment.dateTime.day,
    );

    final unlockDate = origDay.add(const Duration(days: minHealingDays));
    final windowEndsAt = addMonths(origDay, windowMonths);

    if (today.isBefore(unlockDate)) {
      return TouchUpEligibilityResult(
        status: TouchUpEligibilityStatus.tooEarlyToHeal,
        summary:
            'Touch-up booking unlocks on ${formatShortDate(unlockDate)} (7 days after your session so initial healing can begin).',
        availableAfter: unlockDate,
        windowEndsAt: windowEndsAt,
        feeDollars: feeDollars,
        durationMinutes: durationMinutes,
        bufferMinutes: bufferMinutes,
        windowMonths: windowMonths,
      );
    }

    final appointments = allClientAppointments ?? ClientAppointment.allActive;

    // 1. Check 1-touch-up-per-tattoo limit (upcoming or completed, non-cancelled).
    final alreadyTouchedUp = appointments.any((apt) {
      if (apt.status == AppointmentStatus.cancelled) return false;
      if (!apt.isTouchUp) return false;
      final parentId = apt.parentAppointmentId?.trim() ?? '';
      return parentId.isNotEmpty && parentId == originalAppointment.id;
    });
    if (alreadyTouchedUp) {
      return TouchUpEligibilityResult(
        status: TouchUpEligibilityStatus.alreadyUsedForTattoo,
        summary:
            'You have already booked a touch-up for this piece. Message ${originalAppointment.artistName} in chat if you need another follow-up.',
        windowEndsAt: windowEndsAt,
        feeDollars: feeDollars,
        durationMinutes: durationMinutes,
        bufferMinutes: bufferMinutes,
        windowMonths: windowMonths,
      );
    }

    // 2. Check window expiration (original date + configured touchUpWindowMonths).
    if (today.isAfter(windowEndsAt)) {
      return TouchUpEligibilityResult(
        status: TouchUpEligibilityStatus.windowExpired,
        summary:
            'Your $windowMonths-month self-booking touch-up window ended on ${formatShortDate(windowEndsAt)}. Message ${originalAppointment.artistName} in chat to arrange a touch-up.',
        windowEndsAt: windowEndsAt,
        feeDollars: feeDollars,
        durationMinutes: durationMinutes,
        bufferMinutes: bufferMinutes,
        windowMonths: windowMonths,
      );
    }

    // 3. Check 1 active upcoming touch-up at a time with this artist.
    final hasActiveUpcoming = appointments.any((apt) {
      if (!apt.isTouchUp) return false;
      if (apt.status == AppointmentStatus.cancelled ||
          apt.status == AppointmentStatus.completed) {
        return false;
      }
      final aptDay = DateTime(
        apt.dateTime.year,
        apt.dateTime.month,
        apt.dateTime.day,
      );
      if (aptDay.isBefore(today)) return false;
      return _matchesArtist(
        apt,
        artistId: originalAppointment.artistId,
        artistName: originalAppointment.artistName,
      );
    });
    if (hasActiveUpcoming) {
      return TouchUpEligibilityResult(
        status: TouchUpEligibilityStatus.hasActiveUpcomingTouchUp,
        summary:
            'You already have an upcoming touch-up scheduled with ${originalAppointment.artistName}.',
        windowEndsAt: windowEndsAt,
        feeDollars: feeDollars,
        durationMinutes: durationMinutes,
        bufferMinutes: bufferMinutes,
        windowMonths: windowMonths,
      );
    }

    final priceLabel =
        feeDollars <= 0 ? 'Free (\$0)' : '\$$feeDollars setup fee';
    return TouchUpEligibilityResult(
      status: TouchUpEligibilityStatus.eligible,
      summary:
          '$priceLabel • ${formatDurationLabel(durationMinutes)} • Eligible through ${formatShortDate(windowEndsAt)}',
      availableAfter: unlockDate,
      windowEndsAt: windowEndsAt,
      feeDollars: feeDollars,
      durationMinutes: durationMinutes,
      bufferMinutes: bufferMinutes,
      windowMonths: windowMonths,
    );
  }

  /// Finds all completed original (non-touch-up) tattoos for a specific artist,
  /// sorted most-recent first (used by Chat entry point).
  static List<ClientAppointment> findCompletedTattoosForArtist({
    required String artistId,
    String? artistName,
    List<ClientAppointment>? appointments,
  }) {
    final source = appointments ?? ClientAppointment.allActive;
    final matches = source.where((apt) {
      if (apt.status != AppointmentStatus.completed) return false;
      if (apt.isTouchUp) return false;
      return _matchesArtist(
        apt,
        artistId: artistId,
        artistName: artistName,
      );
    }).toList()
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
    return matches;
  }
}
