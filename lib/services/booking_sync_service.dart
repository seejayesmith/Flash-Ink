import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../features/appointments/domain/models/appointment_item.dart';
import '../features/messages/domain/models/message_thread.dart';
import '../models/artist_dashboard_data.dart';

/// Represents an in-app or push notification dispatched for booking lifecycle events.
class BookingNotification {
  final String id;
  final String recipientName;
  final String title;
  final String body;
  final String category; // 'booking_confirmed', 'custom_request', 'rescheduled', 'cancelled', 'reminder'
  final String? appointmentId;
  final DateTime createdAt;

  const BookingNotification({
    required this.id,
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
      'recipientName': recipientName,
      'title': title,
      'body': body,
      'category': category,
      'appointmentId': appointmentId,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

/// Multi-device Cloud Firestore synchronization and notification service for bookings.
///
/// Automatically persists appointments, custom requests, and artist book schedules
/// to Cloud Firestore when available, while gracefully falling back to local memory
/// when offline or during headless widget tests.
class BookingSyncService {
  static final List<BookingNotification> sentNotifications = [];
  static final List<Map<String, dynamic>> syncedPayloads = [];
  static final Set<String> claimedFlashPieceIds = <String>{};
  static bool enableCloudWrites = true;

  /// Clears in-memory notification and sync logs (used for sign-out & test isolation).
  static void resetSyncState() {
    sentNotifications.clear();
    syncedPayloads.clear();
    claimedFlashPieceIds.clear();
    ClientAppointment.clearSessionAppointments();
    MessageThread.clearSessionThreads();
  }

  /// Persists or updates a [DashboardAppointment] in Cloud Firestore (`appointments` collection).
  static Future<void> syncAppointmentToCloud(
    DashboardAppointment appointment, {
    String status = 'confirmed',
  }) async {
    final payload = {
      'id': appointment.id,
      'clientName': appointment.clientName,
      'serviceType': appointment.serviceType,
      'duration': appointment.duration,
      'time': appointment.time,
      'date': appointment.date,
      'scheduledDate': appointment.scheduledDate?.toIso8601String(),
      'placement': appointment.placement,
      'notes': appointment.notes,
      'depositPaid': appointment.depositPaid,
      'fullPrice': appointment.fullPrice,
      'balanceDue': appointment.balanceDue,
      'artworkImageUrl': appointment.artworkImageUrl,
      'isConsultation': appointment.isConsultation,
      'visitType': appointment.effectiveVisitType,
      'status': status,
      'updatedAt': DateTime.now().toIso8601String(),
    };

    syncedPayloads.add({'collection': 'appointments', 'data': payload});

    if (!enableCloudWrites) return;
    try {
      await FirebaseFirestore.instance
          .collection('appointments')
          .doc(appointment.id)
          .set(payload, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[BookingSyncService] Offline/local fallback for appointment ${appointment.id}: $e');
    }
  }

  /// Persists or updates a [BookingRequest] in Cloud Firestore (`custom_requests` collection).
  static Future<void> syncCustomRequestToCloud(
    BookingRequest request, {
    String status = 'pending',
  }) async {
    final payload = {
      'id': request.id,
      'clientName': request.clientName,
      'artistName': request.artistName,
      'conceptDescription': request.conceptDescription,
      'placement': request.placement,
      'category': request.category,
      'size': request.size,
      'sketchImageUrl': request.sketchImageUrl,
      'estimatedPrice': request.estimatedPrice,
      'deposit': request.deposit,
      'isSilentAppointment': request.isSilentAppointment,
      'preferredDate': request.preferredDate?.toIso8601String(),
      'preferredTimeSlot': request.preferredTimeSlot,
      'status': status,
      'updatedAt': DateTime.now().toIso8601String(),
    };

    syncedPayloads.add({'collection': 'custom_requests', 'data': payload});

    if (!enableCloudWrites) return;
    try {
      await FirebaseFirestore.instance
          .collection('custom_requests')
          .doc(request.id)
          .set(payload, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[BookingSyncService] Offline/local fallback for request ${request.id}: $e');
    }
  }

  /// Persists the artist's [ArtistBooksSchedule] in Cloud Firestore (`artist_schedules` collection).
  static Future<void> syncBooksScheduleToCloud(
    ArtistBooksSchedule schedule, {
    String artistId = 'artist_oddmaree',
  }) async {
    final payload = {
      ...schedule.toMap(),
      'artistId': artistId,
      'updatedAt': DateTime.now().toIso8601String(),
    };

    syncedPayloads.add({'collection': 'artist_schedules', 'data': payload});

    if (!enableCloudWrites) return;
    try {
      await FirebaseFirestore.instance
          .collection('artist_schedules')
          .doc(artistId)
          .set(payload, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[BookingSyncService] Offline/local fallback for schedule $artistId: $e');
    }
  }

  /// Dispatches a booking lifecycle or 24h reminder notification to a client or artist.
  static BookingNotification sendBookingNotification({
    required String recipientName,
    required String title,
    required String body,
    required String category,
    String? appointmentId,
  }) {
    final notification = BookingNotification(
      id: 'notif_${DateTime.now().microsecondsSinceEpoch}',
      recipientName: recipientName,
      title: title,
      body: body,
      category: category,
      appointmentId: appointmentId,
      createdAt: DateTime.now(),
    );

    sentNotifications.insert(0, notification);
    syncedPayloads.add({'collection': 'notifications', 'data': notification.toMap()});

    if (enableCloudWrites) {
      try {
        FirebaseFirestore.instance
            .collection('notifications')
            .doc(notification.id)
            .set(notification.toMap())
            .catchError((_) {});
      } catch (_) {}
    }

    return notification;
  }
}
