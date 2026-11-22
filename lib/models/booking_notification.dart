/// Represents an in-app or push notification dispatched for booking lifecycle events.
class BookingNotification {
  final String id;
  final String senderId;
  final String recipientId;
  final String recipientName;
  final String title;
  final String body;
  final String category; // 'booking_confirmed', 'custom_request', 'rescheduled', 'cancelled', 'reminder'
  final String? appointmentId;
  final DateTime createdAt;

  const BookingNotification({
    required this.id,
    required this.senderId,
    required this.recipientId,
    required this.recipientName,
    required this.title,
    required this.body,
    required this.category,
    this.appointmentId,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'recipientId': recipientId,
      'recipientName': recipientName,
      'title': title,
      'body': body,
      'message': body,
      'category': category,
      'type': category,
      'appointmentId': appointmentId,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
