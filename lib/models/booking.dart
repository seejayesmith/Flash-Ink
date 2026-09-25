import 'artist.dart';

/// Available booking time slot option.
class BookingTimeSlot {
  final String time;
  final String period; // 'Morning', 'Afternoon', 'Evening'
  final bool isAvailable;

  const BookingTimeSlot({
    required this.time,
    required this.period,
    this.isAvailable = true,
  });

  static const List<BookingTimeSlot> defaultSlots = [
    BookingTimeSlot(time: '10:00 AM', period: 'Morning'),
    BookingTimeSlot(time: '11:30 AM', period: 'Morning'),
    BookingTimeSlot(time: '1:30 PM', period: 'Afternoon'),
    BookingTimeSlot(time: '3:00 PM', period: 'Afternoon'),
    BookingTimeSlot(time: '4:30 PM', period: 'Afternoon'),
    BookingTimeSlot(time: '6:00 PM', period: 'Evening'),
    BookingTimeSlot(time: '7:30 PM', period: 'Evening'),
  ];
}

/// Represents a confirmed or in-progress flash tattoo booking.
class FlashBooking {
  final String id;
  final FlashArtwork flash;
  final Artist? artist;
  final DateTime selectedDate;
  final String selectedTimeSlot;
  final String clientName;
  final String clientPhone;
  final String clientEmail;
  final String placement;
  final String? clientNotes;
  final bool isSilentAppointment;
  final int depositAmount;
  final int totalAmount;
  final String paymentMethod;
  final DateTime createdAt;

  int get balanceDue => totalAmount - depositAmount;

  const FlashBooking({
    required this.id,
    required this.flash,
    this.artist,
    required this.selectedDate,
    required this.selectedTimeSlot,
    required this.clientName,
    required this.clientPhone,
    required this.clientEmail,
    required this.placement,
    this.clientNotes,
    this.isSilentAppointment = false,
    required this.depositAmount,
    required this.totalAmount,
    required this.paymentMethod,
    required this.createdAt,
  });
}
