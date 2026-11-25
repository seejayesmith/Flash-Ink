import '../../models/artist_dashboard/artist_books_schedule.dart';

/// Categorizes booking session types so slot generation applies the right
/// duration, cleanup buffer, and dead-gap filtering policy.
enum BookingSlotType {
  flash,
  custom,
  touchUp,
}

/// Resolved scheduling parameters for a specific [BookingSlotType].
class BookingSlotProfile {
  static const int touchUpSessionMinutes = 30;
  static const int touchUpBufferMinutes = 30;

  final BookingSlotType type;
  final int durationMinutes;
  final int bufferMinutes;
  final bool filterDeadGaps;
  final bool requireBufferBeforeClose;

  const BookingSlotProfile({
    required this.type,
    required this.durationMinutes,
    required this.bufferMinutes,
    required this.filterDeadGaps,
    this.requireBufferBeforeClose = false,
  });

  /// Maps [type] and optional [requestedDurationMinutes] onto [schedule]'s rules.
  factory BookingSlotProfile.forType(
    BookingSlotType type, {
    required ArtistBooksSchedule schedule,
    int? requestedDurationMinutes,
  }) {
    switch (type) {
      case BookingSlotType.flash:
        return BookingSlotProfile(
          type: BookingSlotType.flash,
          durationMinutes:
              (requestedDurationMinutes ?? schedule.slotDurationMinutes)
                  .clamp(15, 720),
          bufferMinutes: schedule.bufferDurationMinutes.clamp(0, 240),
          filterDeadGaps: schedule.preventDeadGaps,
          requireBufferBeforeClose: false,
        );
      case BookingSlotType.custom:
        return BookingSlotProfile(
          type: BookingSlotType.custom,
          durationMinutes:
              (requestedDurationMinutes ?? schedule.slotDurationMinutes)
                  .clamp(15, 720),
          bufferMinutes: schedule.bufferDurationMinutes.clamp(0, 240),
          filterDeadGaps: false,
          requireBufferBeforeClose: false,
        );
      case BookingSlotType.touchUp:
        return const BookingSlotProfile(
          type: BookingSlotType.touchUp,
          durationMinutes: touchUpSessionMinutes,
          bufferMinutes: touchUpBufferMinutes,
          filterDeadGaps: false,
          requireBufferBeforeClose: false,
        );
    }
  }
}
