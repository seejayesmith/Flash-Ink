import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../features/appointments/domain/models/appointment_item.dart';
import '../features/messages/domain/models/message_thread.dart';
import '../models/artist_dashboard/artist_books_schedule.dart';
import '../models/artist_dashboard/booking_request.dart';
import '../models/artist_dashboard/dashboard_appointment.dart';
import '../models/booking_notification.dart';
import '../models/waitlist_entry.dart';
import '../repositories/artist_dashboard_repository.dart';
import 'auth_service.dart';
import 'booking/booking_cloud_hydrator.dart';
import 'booking/chat_cloud_sync.dart';
import 'booking/schedule_cloud_sync.dart';
import 'scheduling/slot_availability_engine.dart';

/// Multi-device Cloud Firestore synchronization and notification service for bookings.
///
/// Automatically persists bookings, appointments, custom requests, and artist book schedules
/// to Cloud Firestore when available, while gracefully falling back to local memory
/// when offline or during headless widget tests.
class BookingSyncService {
  static final List<BookingNotification> sentNotifications = [];
  static final List<Map<String, dynamic>> syncedPayloads = [];
  static final Set<String> claimedFlashPieceIds = <String>{};
  static bool enableCloudWrites = true;

  /// Resolves the currently authenticated user's UID from [FirebaseAuth] or dev mock state.
  static String resolveCurrentUid([String fallback = 'anonymous_client']) {
    try {
      final current = FirebaseAuth.instance.currentUser;
      if (current != null && current.uid.isNotEmpty) {
        return current.uid;
      }
    } catch (_) {}
    final devUid = AuthService.devMockUser?.uid;
    if (devUid != null && devUid.isNotEmpty) {
      return devUid;
    }
    return fallback;
  }

  /// Synchronously resolves the current user's profile photo URL from [FirebaseAuth]
  /// or dev mock state, ignoring empty or `local://` values.
  static String resolveCurrentUserPhotoUrlSync() {
    String? candidate;
    try {
      candidate = FirebaseAuth.instance.currentUser?.photoURL;
    } catch (_) {}
    if (candidate == null ||
        candidate.trim().isEmpty ||
        candidate.trim().startsWith('local://')) {
      candidate = AuthService.devMockUser?.photoURL;
    }
    if (candidate == null) return '';
    final trimmed = candidate.trim();
    return trimmed.startsWith('local://') ? '' : trimmed;
  }

  /// Synchronously resolves the current user's display name from [FirebaseAuth]
  /// or dev mock state.
  static String resolveCurrentUserDisplayNameSync([String fallback = 'Artist']) {
    String? candidate;
    try {
      candidate = FirebaseAuth.instance.currentUser?.displayName;
    } catch (_) {}
    if (candidate == null || candidate.trim().isEmpty) {
      candidate = AuthService.devMockUser?.displayName;
    }
    if (candidate == null || candidate.trim().isEmpty) return fallback;
    return candidate.trim();
  }

  /// Extracts a valid non-local photo URL from a Firestore user or artist map.
  static String extractPhotoUrl(Map<String, dynamic>? data) {
    if (data == null) return '';
    for (final key in const ['avatarUrl', 'photoUrl', 'photoURL']) {
      final raw = data[key];
      if (raw is String) {
        final trimmed = raw.trim();
        if (trimmed.isNotEmpty && !trimmed.startsWith('local://')) {
          return trimmed;
        }
      }
    }
    return '';
  }

  /// Resolves the current user's unified profile photo URL from `/users/{uid}`
  /// (and falls back to `/artists/{uid}` or Firebase Auth `photoURL`).
  static Future<String> resolveCurrentUserPhotoUrl({
    String? uid,
    FirebaseFirestore? firestore,
  }) async {
    final effectiveUid = (uid != null && uid.trim().isNotEmpty)
        ? uid.trim()
        : resolveCurrentUid('');
    final authPhoto = resolveCurrentUserPhotoUrlSync();
    if (effectiveUid.isEmpty) return authPhoto;

    FirebaseFirestore? db = firestore;
    if (db == null) {
      try {
        db = FirebaseFirestore.instance;
      } catch (_) {
        return authPhoto;
      }
    }

    try {
      final userDoc = await db
          .collection('users')
          .doc(effectiveUid)
          .get()
          .timeout(const Duration(seconds: 3));
      final userPhoto = extractPhotoUrl(userDoc.data());
      if (userPhoto.isNotEmpty) return userPhoto;
    } catch (_) {}

    if (authPhoto.isNotEmpty) return authPhoto;

    try {
      final artistDoc = await db
          .collection('artists')
          .doc(effectiveUid)
          .get()
          .timeout(const Duration(seconds: 3));
      final artistPhoto = extractPhotoUrl(artistDoc.data());
      if (artistPhoto.isNotEmpty) return artistPhoto;
    } catch (_) {}

    return '';
  }

  /// Clears in-memory notification and sync logs (used for sign-out & test isolation).
  static void resetSyncState() {
    sentNotifications.clear();
    syncedPayloads.clear();
    claimedFlashPieceIds.clear();
    ClientAppointment.clearSessionAppointments();
    MessageThread.clearSessionThreads();
  }

  /// Persists a flash booking document in Cloud Firestore (`bookings` collection)
  /// with status `'pending'` containing `flashId`, `artistId`, and `clientId`.
  static Future<void> syncBookingToCloud({
    required String bookingId,
    required String flashId,
    required String artistId,
    required String clientId,
    required int depositAmount,
    required int totalAmount,
    String? flashTitle,
    String? flashImageUrl,
    String? selectedDate,
    String? selectedTimeSlot,
    int? startMinutes,
    int? durationMinutes,
    int? bufferMinutes,
    String? placement,
    String? clientName,
    String? clientAvatar,
    String? clientEmail,
    String? clientPhone,
    String? clientNotes,
    bool isSilentAppointment = false,
    String status = 'pending',
    FirebaseFirestore? firestore,
  }) async {
    final nowIso = DateTime.now().toIso8601String();
    final safeClientAvatar = (clientAvatar != null &&
            clientAvatar.trim().isNotEmpty &&
            !clientAvatar.trim().startsWith('local://'))
        ? clientAvatar.trim()
        : null;
    final resolvedStart = startMinutes ??
        (selectedTimeSlot != null
            ? ScheduleSlotEntry.parseTimeLabelToMinutes(selectedTimeSlot)
            : null);
    final resolvedDuration =
        durationMinutes ?? ArtistDashboardRepository.booksSchedule.slotDurationMinutes;
    final resolvedBuffer =
        bufferMinutes ?? ArtistDashboardRepository.booksSchedule.bufferDurationMinutes;
    final resolvedEnd = resolvedStart != null
        ? resolvedStart + resolvedDuration + resolvedBuffer
        : null;

    final payload = <String, dynamic>{
      'id': bookingId,
      'bookingId': bookingId,
      'flashId': flashId,
      'artistId': artistId,
      'clientId': clientId,
      'status': status,
      'depositAmount': depositAmount,
      'totalAmount': totalAmount,
      'flashTitle': ?flashTitle,
      'flashImageUrl': ?flashImageUrl,
      'artworkImageUrl': ?flashImageUrl,
      'selectedDate': ?selectedDate,
      'selectedTimeSlot': ?selectedTimeSlot,
      'startMinutes': ?resolvedStart,
      'durationMinutes': resolvedDuration,
      'bufferMinutes': resolvedBuffer,
      'endMinutes': ?resolvedEnd,
      'placement': ?placement,
      'clientName': ?clientName,
      'clientAvatar': ?safeClientAvatar,
      'clientEmail': ?clientEmail,
      'clientPhone': ?clientPhone,
      'clientNotes': ?clientNotes,
      'isSilentAppointment': isSilentAppointment,
      'createdAt': nowIso,
      'updatedAt': nowIso,
    };

    syncedPayloads.add({'collection': 'bookings', 'data': payload});

    if (!enableCloudWrites && firestore == null) return;
    try {
      final db = firestore ?? FirebaseFirestore.instance;
      await db
          .collection('bookings')
          .doc(bookingId)
          .set(payload, SetOptions(merge: true));
    } catch (e) {
      debugPrint(
        '[BookingSyncService] Offline/local fallback for booking $bookingId: $e',
      );
    }
  }

  /// Persists or updates a [DashboardAppointment] in Cloud Firestore (`appointments` collection).
  static Future<void> syncAppointmentToCloud(
    DashboardAppointment appointment, {
    String? clientId,
    String? artistId,
    String status = 'confirmed',
    FirebaseFirestore? firestore,
  }) async {
    final effectiveClientId = (clientId != null && clientId.trim().isNotEmpty)
        ? clientId.trim()
        : (appointment.clientId != null &&
                appointment.clientId!.trim().isNotEmpty
            ? appointment.clientId!.trim()
            : resolveCurrentUid());
    final effectiveArtistId = (artistId != null && artistId.trim().isNotEmpty)
        ? artistId.trim()
        : (appointment.artistId != null &&
                appointment.artistId!.trim().isNotEmpty
            ? appointment.artistId!.trim()
            : resolveCurrentUid('artist_unknown'));

    final schedule = ArtistDashboardRepository.booksSchedule;
    final cleanTime = appointment.time.split('(').first.trim();
    final parsedStart = ScheduleSlotEntry.parseTimeLabelToMinutes(cleanTime);
    final parsedDuration = SlotAvailabilityEngine.parseDurationMinutes(
      appointment.duration,
      fallbackMinutes: schedule.slotDurationMinutes,
    );
    final bufferMins = schedule.bufferDurationMinutes;

    final payload = {
      'id': appointment.id,
      'clientId': effectiveClientId,
      'artistId': effectiveArtistId,
      'clientName': appointment.clientName,
      if (appointment.clientAvatar != null &&
          appointment.clientAvatar!.trim().isNotEmpty &&
          !appointment.clientAvatar!.trim().startsWith('local://'))
        'clientAvatar': appointment.clientAvatar!.trim(),
      'serviceType': appointment.serviceType,
      'duration': appointment.duration,
      'durationMinutes': parsedDuration,
      'bufferMinutes': bufferMins,
      'startMinutes': ?parsedStart,
      if (parsedStart != null)
        'endMinutes': parsedStart + parsedDuration + bufferMins,
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

    if (!enableCloudWrites && firestore == null) return;
    try {
      final db = firestore ?? FirebaseFirestore.instance;
      await db
          .collection('appointments')
          .doc(appointment.id)
          .set(payload, SetOptions(merge: true));

      final isActiveBooking = status == 'confirmed' || status == 'rescheduled';
      final canWriteSchedule =
          firestore != null || resolveCurrentUid('') == effectiveArtistId;
      if (isActiveBooking &&
          canWriteSchedule &&
          appointment.scheduledDate != null &&
          cleanTime.isNotEmpty &&
          effectiveArtistId.isNotEmpty) {
        final slotEntry = ScheduleSlotEntry(
          dateKey: ArtistBooksSchedule.dateKey(appointment.scheduledDate!),
          timeSlot: cleanTime,
          startMinutes: parsedStart,
          durationMinutes: parsedDuration,
          bufferMinutes: bufferMins,
        );
        try {
          await db.collection('artist_schedules').doc(effectiveArtistId).set({
            'artistId': effectiveArtistId,
            'bookedSlots': FieldValue.arrayUnion([slotEntry.toMap()]),
            'updatedAt': DateTime.now().toIso8601String(),
          }, SetOptions(merge: true));
        } catch (_) {}
      }
    } catch (e) {
      debugPrint(
        '[BookingSyncService] Offline/local fallback for appointment ${appointment.id}: $e',
      );
    }
  }

  /// Persists or updates a [BookingRequest] in Cloud Firestore (`custom_requests` collection).
  static Future<void> syncCustomRequestToCloud(
    BookingRequest request, {
    String? clientId,
    String? artistId,
    String status = 'pending',
  }) async {
    final effectiveClientId = (clientId != null && clientId.trim().isNotEmpty)
        ? clientId.trim()
        : (request.clientId != null && request.clientId!.trim().isNotEmpty
            ? request.clientId!.trim()
            : resolveCurrentUid());
    final effectiveArtistId = (artistId != null && artistId.trim().isNotEmpty)
        ? artistId.trim()
        : (request.artistId != null && request.artistId!.trim().isNotEmpty
            ? request.artistId!.trim()
            : 'artist_unknown');

    final payload = {
      'id': request.id,
      'clientId': effectiveClientId,
      'artistId': effectiveArtistId,
      'clientName': request.clientName,
      if (request.clientAvatar != null &&
          request.clientAvatar!.trim().isNotEmpty &&
          !request.clientAvatar!.trim().startsWith('local://'))
        'clientAvatar': request.clientAvatar!.trim(),
      'artistName': request.artistName,
      'conceptDescription': request.conceptDescription,
      'placement': request.placement,
      'category': request.category,
      'size': request.size,
      'sketchImageUrl': request.sketchImageUrl,
      'referenceImageUrls': request.referenceImageUrls,
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
      debugPrint(
        '[BookingSyncService] Offline/local fallback for request ${request.id}: $e',
      );
    }
  }

  static Future<void> syncBooksScheduleToCloud(
    ArtistBooksSchedule schedule, {
    required String artistId,
    FirebaseFirestore? firestore,
  }) =>
      ScheduleCloudSync.syncBooksScheduleToCloud(
        schedule,
        artistId: artistId,
        syncedPayloads: syncedPayloads,
        enableCloudWrites: enableCloudWrites,
        firestore: firestore,
      );

  static Future<void> syncHeldSlotsToCloud(
    List<ScheduleSlotEntry> heldSlots, {
    required String artistId,
    FirebaseFirestore? firestore,
  }) =>
      ScheduleCloudSync.syncHeldSlotsToCloud(
        heldSlots,
        artistId: artistId,
        syncedPayloads: syncedPayloads,
        enableCloudWrites: enableCloudWrites,
        firestore: firestore,
      );

  static Future<ArtistBooksSchedule?> fetchArtistScheduleFromCloud(
    String artistId, {
    FirebaseFirestore? firestore,
  }) =>
      ScheduleCloudSync.fetchArtistScheduleFromCloud(
        artistId,
        firestore: firestore,
      );

  static Future<({bool available, ArtistBooksSchedule? schedule})>
      verifySlotAvailableInCloud({
    required String artistId,
    required DateTime date,
    required String timeSlot,
    int? startMinutes,
    int? durationMinutes,
    int? bufferMinutes,
    String? ignoreHoldId,
    FirebaseFirestore? firestore,
  }) =>
      ScheduleCloudSync.verifySlotAvailableInCloud(
        artistId: artistId,
        date: date,
        timeSlot: timeSlot,
        startMinutes: startMinutes,
        durationMinutes: durationMinutes,
        bufferMinutes: bufferMinutes,
        ignoreHoldId: ignoreHoldId,
        firestore: firestore,
      );

  static Future<void> syncWaitlistToCloud(
    List<WaitlistEntry> entries, {
    required String artistId,
  }) =>
      ScheduleCloudSync.syncWaitlistToCloud(
        entries,
        artistId: artistId,
        syncedPayloads: syncedPayloads,
        enableCloudWrites: enableCloudWrites,
      );

  static Future<void> syncChatThreadToCloud(
    MessageThread thread, {
    String? clientId,
    required String artistId,
    String? clientName,
    String? clientAvatar,
    String? artistAvatar,
  }) =>
      ChatCloudSync.syncChatThreadToCloud(
        thread,
        artistId: artistId,
        resolveCurrentUid: resolveCurrentUid,
        syncedPayloads: syncedPayloads,
        enableCloudWrites: enableCloudWrites,
        clientId: clientId,
        clientName: clientName,
        clientAvatar: clientAvatar,
        artistAvatar: artistAvatar,
      );

  static Future<void> appendAndSyncChatMessage({
    required String threadId,
    required ChatMessage message,
  }) =>
      ChatCloudSync.appendAndSyncChatMessage(
        threadId: threadId,
        message: message,
        syncedPayloads: syncedPayloads,
        enableCloudWrites: enableCloudWrites,
      );

  static StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      listenToArtistCustomRequests(
    String artistId, {
    FirebaseFirestore? firestore,
  }) =>
      BookingCloudHydrator.listenToArtistCustomRequests(
        artistId,
        firestore: firestore,
      );

  static Future<void> hydrateArtistDataFromCloud(
    String artistId, {
    FirebaseFirestore? firestore,
  }) =>
      BookingCloudHydrator.hydrateArtistDataFromCloud(
        artistId,
        resolveCurrentUserPhotoUrlSync: resolveCurrentUserPhotoUrlSync,
        extractPhotoUrl: extractPhotoUrl,
        enableCloudWrites: enableCloudWrites,
        firestore: firestore,
      );

  static Future<void> hydrateClientDataFromCloud(
    String clientId, {
    FirebaseFirestore? firestore,
  }) =>
      BookingCloudHydrator.hydrateClientDataFromCloud(
        clientId,
        resolveCurrentUserPhotoUrl: resolveCurrentUserPhotoUrl,
        extractPhotoUrl: extractPhotoUrl,
        enableCloudWrites: enableCloudWrites,
        firestore: firestore,
      );

  /// Dispatches a booking lifecycle or 24h reminder notification to a client or artist.
  static BookingNotification sendBookingNotification({
    required String recipientName,
    required String title,
    required String body,
    required String category,
    String? senderId,
    String? recipientId,
    String? appointmentId,
  }) {
    final effectiveSenderId = (senderId != null && senderId.trim().isNotEmpty)
        ? senderId.trim()
        : resolveCurrentUid();
    final effectiveRecipientId =
        (recipientId != null && recipientId.trim().isNotEmpty)
            ? recipientId.trim()
            : resolveCurrentUid('recipient_unknown');

    final notification = BookingNotification(
      id: 'notif_${DateTime.now().microsecondsSinceEpoch}',
      senderId: effectiveSenderId,
      recipientId: effectiveRecipientId,
      recipientName: recipientName,
      title: title,
      body: body,
      category: category,
      appointmentId: appointmentId,
      createdAt: DateTime.now(),
    );

    sentNotifications.insert(0, notification);
    syncedPayloads
        .add({'collection': 'notifications', 'data': notification.toMap()});

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
