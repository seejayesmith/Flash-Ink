import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../core/mock/mock_data_config.dart';
import '../features/appointments/domain/models/appointment_item.dart';
import '../features/messages/domain/models/message_thread.dart';
import '../models/artist_dashboard_data.dart';
import '../models/waitlist_entry.dart';
import 'auth_service.dart';

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
    String? selectedDate,
    String? selectedTimeSlot,
    String? placement,
    String? clientName,
    String? clientEmail,
    String? clientPhone,
    String? clientNotes,
    bool isSilentAppointment = false,
    String status = 'pending',
  }) async {
    final nowIso = DateTime.now().toIso8601String();
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
      'selectedDate': ?selectedDate,
      'selectedTimeSlot': ?selectedTimeSlot,
      'placement': ?placement,
      'clientName': ?clientName,
      'clientEmail': ?clientEmail,
      'clientPhone': ?clientPhone,
      'clientNotes': ?clientNotes,
      'isSilentAppointment': isSilentAppointment,
      'createdAt': nowIso,
      'updatedAt': nowIso,
    };

    syncedPayloads.add({'collection': 'bookings', 'data': payload});

    if (!enableCloudWrites) return;
    try {
      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .set(payload, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[BookingSyncService] Offline/local fallback for booking $bookingId: $e');
    }
  }

  /// Persists or updates a [DashboardAppointment] in Cloud Firestore (`appointments` collection).
  static Future<void> syncAppointmentToCloud(
    DashboardAppointment appointment, {
    String? clientId,
    String? artistId,
    String status = 'confirmed',
  }) async {
    final effectiveClientId = (clientId != null && clientId.trim().isNotEmpty)
        ? clientId.trim()
        : (appointment.clientId != null && appointment.clientId!.trim().isNotEmpty
            ? appointment.clientId!.trim()
            : resolveCurrentUid());
    final effectiveArtistId = (artistId != null && artistId.trim().isNotEmpty)
        ? artistId.trim()
        : (appointment.artistId != null && appointment.artistId!.trim().isNotEmpty
            ? appointment.artistId!.trim()
            : resolveCurrentUid('artist_unknown'));

    final payload = {
      'id': appointment.id,
      'clientId': effectiveClientId,
      'artistId': effectiveArtistId,
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

  /// Persists the artist's [ArtistBooksSchedule] in Cloud Firestore (`artist_schedules`
  /// and public `artists` collections).
  static Future<void> syncBooksScheduleToCloud(
    ArtistBooksSchedule schedule, {
    required String artistId,
  }) async {
    final cleanArtistId = artistId.trim();
    if (cleanArtistId.isEmpty) return;

    final scheduleMap = schedule.toMap();
    final payload = {
      ...scheduleMap,
      'artistId': cleanArtistId,
      'updatedAt': DateTime.now().toIso8601String(),
    };

    syncedPayloads.add({'collection': 'artist_schedules', 'data': payload});

    if (!enableCloudWrites) return;
    try {
      await FirebaseFirestore.instance
          .collection('artist_schedules')
          .doc(cleanArtistId)
          .set(payload, SetOptions(merge: true));
      await FirebaseFirestore.instance
          .collection('artists')
          .doc(cleanArtistId)
          .set({
        'isBooksOpen': schedule.isBooksOpen,
        'booksSchedule': scheduleMap,
        'updatedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[BookingSyncService] Offline/local fallback for schedule $cleanArtistId: $e');
    }
  }

  /// Persists the artist's VIP [WaitlistEntry] roster in Cloud Firestore (`artist_schedules`
  /// and `artists` collections).
  static Future<void> syncWaitlistToCloud(
    List<WaitlistEntry> entries, {
    required String artistId,
  }) async {
    final cleanArtistId = artistId.trim();
    if (cleanArtistId.isEmpty) return;

    final serialized = entries.map((e) => e.toMap()).toList();
    final payload = {
      'artistId': cleanArtistId,
      'waitlistEntries': serialized,
      'updatedAt': DateTime.now().toIso8601String(),
    };

    syncedPayloads.add({'collection': 'artist_schedules', 'data': payload});

    if (!enableCloudWrites) return;
    try {
      await FirebaseFirestore.instance
          .collection('artist_schedules')
          .doc(cleanArtistId)
          .set(payload, SetOptions(merge: true));
      await FirebaseFirestore.instance
          .collection('artists')
          .doc(cleanArtistId)
          .set({
        'waitlistEntries': serialized,
        'updatedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[BookingSyncService] Offline/local fallback for waitlist $cleanArtistId: $e');
    }
  }

  /// Persists or updates a [MessageThread] and its messages in Cloud Firestore (`chats/{threadId}`).
  static Future<void> syncChatThreadToCloud(
    MessageThread thread, {
    String? clientId,
    required String artistId,
    String? clientName,
  }) async {
    final effectiveArtistId = artistId.trim().isNotEmpty
        ? artistId.trim()
        : (thread.artistId.trim().isNotEmpty ? thread.artistId.trim() : resolveCurrentUid('artist_unknown'));
    final effectiveClientId = (clientId != null && clientId.trim().isNotEmpty)
        ? clientId.trim()
        : (thread.clientId != null && thread.clientId!.trim().isNotEmpty
            ? thread.clientId!.trim()
            : resolveCurrentUid('client_unknown'));
    final participants = <String>[effectiveClientId, effectiveArtistId];

    final payload = {
      ...thread.toMap(),
      'clientId': effectiveClientId,
      'artistId': effectiveArtistId,
      if (clientName != null && clientName.isNotEmpty) 'clientName': clientName,
      'participants': participants,
      'createdAt': thread.lastMessageTime.toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    };

    syncedPayloads.add({'collection': 'chats', 'data': payload});

    if (!enableCloudWrites) return;
    try {
      final docRef = FirebaseFirestore.instance.collection('chats').doc(thread.id);
      await docRef.set(payload, SetOptions(merge: true));
      for (final msg in thread.messages) {
        await docRef
            .collection('messages')
            .doc(msg.id)
            .set(msg.toMap(), SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('[BookingSyncService] Offline/local fallback for chat thread ${thread.id}: $e');
    }
  }

  /// Appends a single [ChatMessage] to an active conversation in local memory and Cloud Firestore.
  static Future<void> appendAndSyncChatMessage({
    required String threadId,
    required ChatMessage message,
  }) async {
    final threads = MessageThread.activeThreads;
    final idx = threads.indexWhere((t) => t.id == threadId);
    if (idx != -1) {
      final existing = threads[idx];
      final updatedMessages = [...existing.messages, message];
      final updatedThread = existing.copyWith(
        lastMessage: message.text,
        lastMessageTime: message.timestamp,
        unreadCount: 0,
        messages: updatedMessages,
      );
      threads[idx] = updatedThread;
      ArtistDashboardRepository.notifyPendingRequestsChanged();
    }

    syncedPayloads.add({'collection': 'messages', 'data': message.toMap()});

    if (!enableCloudWrites) return;
    try {
      final docRef = FirebaseFirestore.instance.collection('chats').doc(threadId);
      await docRef.set({
        'lastMessage': message.text,
        'lastMessageTime': message.timestamp.toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
      await docRef
          .collection('messages')
          .doc(message.id)
          .set(message.toMap(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('[BookingSyncService] Offline/local fallback for chat message ${message.id}: $e');
    }
  }

  /// Hydrates live artist appointments, custom requests, book schedule, waitlist, and chat threads
  /// from Cloud Firestore when running in live mode (`!MockDataConfig.isEnabled`).
  static Future<void> hydrateArtistDataFromCloud(
    String artistId, {
    FirebaseFirestore? firestore,
  }) async {
    final cleanArtistId = artistId.trim();
    if (cleanArtistId.isEmpty || MockDataConfig.isEnabled) return;

    FirebaseFirestore? db = firestore;
    if (db == null) {
      try {
        db = FirebaseFirestore.instance;
      } catch (_) {
        return;
      }
    }

    bool changed = false;

    // 1. Hydrate artist_schedules (BooksSchedule + Waitlist)
    try {
      final schedDoc = await db.collection('artist_schedules').doc(cleanArtistId).get();
      if (schedDoc.exists && schedDoc.data() != null) {
        final data = schedDoc.data()!;
        ArtistDashboardRepository.booksSchedule = ArtistBooksSchedule.fromMap(data);
        if (data['waitlistEntries'] is List) {
          final parsedWaitlist = (data['waitlistEntries'] as List)
              .whereType<Map>()
              .map((m) => WaitlistEntry.fromMap(Map<String, dynamic>.from(m)))
              .toList();
          ArtistDashboardRepository.liveWaitlistEntries = parsedWaitlist;
        }
        changed = true;
      }
    } catch (_) {}

    // 2. Hydrate appointments for this artist
    try {
      final aptSnap = await db
          .collection('appointments')
          .where('artistId', isEqualTo: cleanArtistId)
          .get();
      final remoteApts = aptSnap.docs
          .where((doc) => doc.data()['status'] != 'cancelled')
          .map((doc) => DashboardAppointment.fromMap(doc.data(), doc.id))
          .toList();
      if (remoteApts.isNotEmpty) {
        final merged = <String, DashboardAppointment>{
          for (final a in ArtistDashboardRepository.liveCalendarAppointments) a.id: a,
          for (final a in remoteApts) a.id: a,
        };
        ArtistDashboardRepository.liveCalendarAppointments = merged.values.toList();
        changed = true;
      }
    } catch (_) {}

    // 3. Hydrate pending custom_requests for this artist
    try {
      final reqSnap = await db
          .collection('custom_requests')
          .where('artistId', isEqualTo: cleanArtistId)
          .get();
      final remoteReqs = reqSnap.docs
          .where((doc) {
            final st = (doc.data()['status'] ?? 'pending').toString();
            return st == 'pending' || st == 'pending_artist_approval';
          })
          .map((doc) => BookingRequest.fromMap(doc.data(), doc.id))
          .toList();
      if (remoteReqs.isNotEmpty) {
        final merged = <String, BookingRequest>{
          for (final r in ArtistDashboardRepository.livePendingRequests) r.id: r,
          for (final r in remoteReqs) r.id: r,
        };
        ArtistDashboardRepository.livePendingRequests = merged.values.toList();
        changed = true;
      }
    } catch (_) {}

    // 4. Hydrate chats where artist is a participant
    try {
      final chatSnap = await db
          .collection('chats')
          .where('participants', arrayContains: cleanArtistId)
          .get();
      if (chatSnap.docs.isNotEmpty) {
        final merged = <String, MessageThread>{
          for (final t in MessageThread.liveThreads) t.id: t,
        };
        for (final doc in chatSnap.docs) {
          final thread = MessageThread.fromMap(doc.data(), doc.id);
          merged[thread.id] = thread;
        }
        MessageThread.liveThreads
          ..clear()
          ..addAll(merged.values);
        changed = true;
      }
    } catch (_) {}

    if (changed) {
      ArtistDashboardRepository.notifyPendingRequestsChanged();
      MessageThread.unreadUpdateNotifier.value++;
    }
  }

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
    final effectiveRecipientId = (recipientId != null && recipientId.trim().isNotEmpty)
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
