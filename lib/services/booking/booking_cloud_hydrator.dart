import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../core/mock/mock_data_config.dart';
import '../../features/messages/domain/models/message_thread.dart';
import '../../models/artist_dashboard/artist_books_schedule.dart';
import '../../models/artist_dashboard/booking_request.dart';
import '../../models/artist_dashboard/dashboard_appointment.dart';
import '../../models/waitlist_entry.dart';
import '../../repositories/artist_dashboard_repository.dart';
import 'schedule_cloud_sync.dart';

/// Hydrates live artist and client booking/chat collections from Cloud Firestore.
class BookingCloudHydrator {
  const BookingCloudHydrator._();

  static List<BookingRequest> _parsePendingCustomRequests(
    QuerySnapshot<Map<String, dynamic>> snap,
  ) {
    return snap.docs
        .where((doc) {
          final st = (doc.data()['status'] ?? 'pending').toString();
          return st == 'pending' || st == 'pending_artist_approval';
        })
        .map((doc) => BookingRequest.fromMap(doc.data(), doc.id))
        .toList();
  }

  static Future<MessageThread> _mergeSubcollectionMessages(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    MessageThread thread,
  ) async {
    try {
      final msgSnap = await doc.reference.collection('messages').get();
      if (msgSnap.docs.isNotEmpty) {
        final byId = <String, ChatMessage>{
          for (final m in thread.messages) m.id: m,
          for (final mDoc in msgSnap.docs)
            mDoc.id: ChatMessage.fromMap(mDoc.data(), mDoc.id),
        };
        final mergedMsgs = byId.values.toList()
          ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
        return thread.copyWith(messages: mergedMsgs);
      }
    } catch (_) {}
    return thread;
  }

  static StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      listenToArtistCustomRequests(
    String artistId, {
    FirebaseFirestore? firestore,
  }) {
    final cleanArtistId = artistId.trim();
    if (cleanArtistId.isEmpty || MockDataConfig.isEnabled) return null;

    FirebaseFirestore? db = firestore;
    if (db == null) {
      try {
        db = FirebaseFirestore.instance;
      } catch (_) {
        return null;
      }
    }

    try {
      return db
          .collection('custom_requests')
          .where('artistId', isEqualTo: cleanArtistId)
          .snapshots()
          .listen(
        (snap) {
          ArtistDashboardRepository.pendingRequests =
              _parsePendingCustomRequests(snap);
        },
        onError: (Object error) {
          debugPrint(
            '[BookingSyncService] Custom requests stream error for $cleanArtistId: $error',
          );
        },
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> hydrateArtistDataFromCloud(
    String artistId, {
    required String Function() resolveCurrentUserPhotoUrlSync,
    required String Function(Map<String, dynamic>? data) extractPhotoUrl,
    required bool enableCloudWrites,
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
      final schedDoc =
          await db.collection('artist_schedules').doc(cleanArtistId).get();
      if (schedDoc.exists && schedDoc.data() != null) {
        final data = schedDoc.data()!;
        ArtistDashboardRepository.booksSchedule =
            ArtistBooksSchedule.fromMap(data);
        if (data['waitlistEntries'] is List) {
          final parsedWaitlist = (data['waitlistEntries'] as List)
              .whereType<Map>()
              .map((m) => WaitlistEntry.fromMap(Map<String, dynamic>.from(m)))
              .toList();
          ArtistDashboardRepository.liveWaitlistEntries = parsedWaitlist;
        }
        changed = true;
      } else {
        final fallbackSchedule =
            await ScheduleCloudSync.fetchArtistScheduleFromCloud(
          cleanArtistId,
          firestore: db,
        );
        if (fallbackSchedule != null) {
          ArtistDashboardRepository.booksSchedule = fallbackSchedule;
          changed = true;
        }
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
          for (final a in ArtistDashboardRepository.liveCalendarAppointments)
            a.id: a,
          for (final a in remoteApts) a.id: a,
        };
        ArtistDashboardRepository.liveCalendarAppointments =
            merged.values.toList();
        changed = true;
      }
    } catch (_) {}

    // 3. Hydrate pending custom_requests for this artist
    try {
      final reqSnap = await db
          .collection('custom_requests')
          .where('artistId', isEqualTo: cleanArtistId)
          .get();
      final remoteReqs = _parsePendingCustomRequests(reqSnap);
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
      final clientAvatarsByClientId = <String, String>{};
      for (final apt in ArtistDashboardRepository.liveCalendarAppointments) {
        final cid = apt.clientId?.trim() ?? '';
        final avatar = apt.clientAvatar?.trim() ?? '';
        if (cid.isNotEmpty &&
            avatar.isNotEmpty &&
            !avatar.startsWith('local://')) {
          clientAvatarsByClientId[cid] = avatar;
        }
      }
      for (final req in ArtistDashboardRepository.livePendingRequests) {
        final cid = req.clientId?.trim() ?? '';
        final avatar = req.clientAvatar?.trim() ?? '';
        if (cid.isNotEmpty &&
            avatar.isNotEmpty &&
            !avatar.startsWith('local://')) {
          clientAvatarsByClientId.putIfAbsent(cid, () => avatar);
        }
      }

      String selfArtistAvatar = resolveCurrentUserPhotoUrlSync();
      if (selfArtistAvatar.isEmpty) {
        try {
          final selfArtistDoc =
              await db.collection('artists').doc(cleanArtistId).get();
          selfArtistAvatar = extractPhotoUrl(selfArtistDoc.data());
        } catch (_) {}
      }

      final chatSnap = await db
          .collection('chats')
          .where('participants', arrayContains: cleanArtistId)
          .get();
      if (chatSnap.docs.isNotEmpty) {
        final merged = <String, MessageThread>{
          for (final t in MessageThread.liveThreads) t.id: t,
        };
        for (final doc in chatSnap.docs) {
          var thread = await _mergeSubcollectionMessages(
            doc,
            MessageThread.fromMap(doc.data(), doc.id),
          );

          final updates = <String, dynamic>{};
          final threadClientId = thread.clientId?.trim() ?? '';
          if ((thread.clientAvatar.trim().isEmpty ||
                  thread.clientAvatar.trim().startsWith('local://')) &&
              threadClientId.isNotEmpty) {
            var resolvedClientAvatar =
                clientAvatarsByClientId[threadClientId] ?? '';
            if (resolvedClientAvatar.isEmpty) {
              try {
                final clientArtistDoc =
                    await db.collection('artists').doc(threadClientId).get();
                resolvedClientAvatar = extractPhotoUrl(clientArtistDoc.data());
              } catch (_) {}
            }
            if (resolvedClientAvatar.isEmpty &&
                threadClientId == cleanArtistId) {
              resolvedClientAvatar = selfArtistAvatar;
            }
            if (resolvedClientAvatar.isNotEmpty) {
              thread = thread.copyWith(clientAvatar: resolvedClientAvatar);
              updates['clientAvatar'] = resolvedClientAvatar;
            }
          }

          if ((thread.artistAvatar.trim().isEmpty ||
                  thread.artistAvatar.trim().startsWith('local://')) &&
              thread.artistId == cleanArtistId &&
              selfArtistAvatar.isNotEmpty) {
            thread = thread.copyWith(artistAvatar: selfArtistAvatar);
            updates['artistAvatar'] = selfArtistAvatar;
          }

          if (updates.isNotEmpty && enableCloudWrites) {
            try {
              await doc.reference.set(updates, SetOptions(merge: true));
            } catch (_) {}
          }

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

  static Future<void> hydrateClientDataFromCloud(
    String clientId, {
    required Future<String> Function({String? uid, FirebaseFirestore? firestore})
        resolveCurrentUserPhotoUrl,
    required String Function(Map<String, dynamic>? data) extractPhotoUrl,
    required bool enableCloudWrites,
    FirebaseFirestore? firestore,
  }) async {
    final cleanClientId = clientId.trim();
    if (cleanClientId.isEmpty || MockDataConfig.isEnabled) return;

    FirebaseFirestore? db = firestore;
    if (db == null) {
      try {
        db = FirebaseFirestore.instance;
      } catch (_) {
        return;
      }
    }

    bool changed = false;
    final selfPhotoUrl = await resolveCurrentUserPhotoUrl(
      uid: cleanClientId,
      firestore: db,
    );

    try {
      final chatSnap = await db
          .collection('chats')
          .where('participants', arrayContains: cleanClientId)
          .get();
      if (chatSnap.docs.isNotEmpty) {
        final merged = <String, MessageThread>{
          for (final t in MessageThread.liveThreads) t.id: t,
        };
        final artistAvatarCache = <String, String>{};

        for (final doc in chatSnap.docs) {
          var thread = await _mergeSubcollectionMessages(
            doc,
            MessageThread.fromMap(doc.data(), doc.id),
          );

          final updates = <String, dynamic>{};
          if (selfPhotoUrl.isNotEmpty &&
              (thread.clientAvatar.trim().isEmpty ||
                  thread.clientAvatar.trim().startsWith('local://') ||
                  thread.clientAvatar.trim() != selfPhotoUrl) &&
              (thread.clientId == null ||
                  thread.clientId!.trim().isEmpty ||
                  thread.clientId!.trim() == cleanClientId)) {
            thread = thread.copyWith(clientAvatar: selfPhotoUrl);
            updates['clientAvatar'] = selfPhotoUrl;
          }

          final targetArtistId = thread.artistId.trim();
          if ((thread.artistAvatar.trim().isEmpty ||
                  thread.artistAvatar.trim().startsWith('local://')) &&
              targetArtistId.isNotEmpty) {
            var resolvedArtistAvatar = artistAvatarCache[targetArtistId];
            if (resolvedArtistAvatar == null) {
              try {
                final artistDoc =
                    await db.collection('artists').doc(targetArtistId).get();
                resolvedArtistAvatar = extractPhotoUrl(artistDoc.data());
              } catch (_) {
                resolvedArtistAvatar = '';
              }
              artistAvatarCache[targetArtistId] = resolvedArtistAvatar;
            }
            if (resolvedArtistAvatar.isNotEmpty) {
              thread = thread.copyWith(artistAvatar: resolvedArtistAvatar);
              updates['artistAvatar'] = resolvedArtistAvatar;
            }
          }

          if (updates.isNotEmpty && enableCloudWrites) {
            try {
              await doc.reference.set(updates, SetOptions(merge: true));
            } catch (_) {}
          }

          merged[thread.id] = thread;
        }

        MessageThread.liveThreads
          ..clear()
          ..addAll(merged.values);
        changed = true;
      }
    } catch (_) {}

    if (changed) {
      MessageThread.unreadUpdateNotifier.value++;
    }
  }
}
