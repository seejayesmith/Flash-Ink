import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../core/mock/mock_data_config.dart';
import '../../features/appointments/domain/models/appointment_item.dart';
import '../../features/messages/domain/models/message_thread.dart';
import '../../models/artist_dashboard/artist_books_schedule.dart';
import '../../models/artist_dashboard/booking_request.dart';
import '../../models/artist_dashboard/dashboard_appointment.dart';
import '../../models/waitlist_entry.dart';
import '../../repositories/artist_dashboard_repository.dart';
import 'chat_cloud_sync.dart';
import 'schedule_cloud_sync.dart';

class _ParsedChatDoc {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final MessageThread thread;

  const _ParsedChatDoc({
    required this.doc,
    required this.thread,
  });
}

/// Hydrates and live-syncs artist and client booking/chat collections from Cloud Firestore.
class BookingCloudHydrator {
  const BookingCloudHydrator._();

  static StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _activeChatsSub;
  static String? _activeChatsUid;
  static FirebaseFirestore? _activeChatsFirestore;
  static int _chatsSnapshotEpoch = 0;

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
        final subMsgs = msgSnap.docs
            .map((mDoc) => ChatMessage.fromMap(mDoc.data(), mDoc.id))
            .toList();
        final mergedMsgs = MessageThread.mergeMessages(thread.messages, subMsgs);
        if (mergedMsgs.isNotEmpty) {
          final latest = mergedMsgs.last;
          final shouldRefreshPreview =
              latest.timestamp.isAfter(thread.lastMessageTime) ||
                  thread.lastMessage.trim().isEmpty;
          return thread.copyWith(
            messages: mergedMsgs,
            lastMessage: shouldRefreshPreview
                ? latest.previewText
                : thread.lastMessage,
            lastMessageTime: shouldRefreshPreview
                ? latest.timestamp
                : thread.lastMessageTime,
          );
        }
        return thread.copyWith(messages: mergedMsgs);
      }
    } catch (_) {}
    return thread;
  }

  static DateTime? _latestDateTime(Iterable<DateTime?> dates) {
    DateTime? best;
    for (final d in dates) {
      if (d == null) continue;
      if (best == null || d.isAfter(best)) best = d;
    }
    return best;
  }

  static bool _isValidAvatar(String raw) {
    final trimmed = raw.trim();
    return trimmed.isNotEmpty && !trimmed.startsWith('local://');
  }

  /// Consolidates raw Firestore chat docs for [activeUid] into one canonical
  /// `dm_<clientId>_<artistId>` thread per pair, backfills legacy duplicates
  /// into the canonical doc, resolves missing avatars, and reconciles per-role
  /// unread state.
  static Future<List<MessageThread>> _consolidateChatSnapshot({
    required QuerySnapshot<Map<String, dynamic>> chatSnap,
    required String activeUid,
    required FirebaseFirestore db,
    required String Function(Map<String, dynamic>? data) extractPhotoUrl,
    required bool enableCloudWrites,
    required List<Map<String, dynamic>> syncedPayloads,
    String selfPhotoUrl = '',
    Map<String, String> clientAvatarsByClientId = const {},
  }) async {
    if (chatSnap.docs.isEmpty) return const [];

    final parsedItems = <_ParsedChatDoc>[];
    for (final doc in chatSnap.docs) {
      final base = MessageThread.fromMap(doc.data(), doc.id);
      final withSub = await _mergeSubcollectionMessages(doc, base);
      parsedItems.add(_ParsedChatDoc(doc: doc, thread: withSub));
    }

    // Group documents by their canonical (clientId, artistId) thread ID.
    final grouped = <String, List<_ParsedChatDoc>>{};
    for (final item in parsedItems) {
      final t = item.thread;
      final canonicalId = MessageThread.hasCanonicalParticipants(
        clientId: t.clientId,
        artistId: t.artistId,
      )
          ? MessageThread.canonicalThreadId(
              clientId: t.clientId!,
              artistId: t.artistId,
            )
          : t.id;
      grouped.putIfAbsent(canonicalId, () => []).add(item);
    }

    final artistAvatarCache = <String, String>{};
    final consolidated = <MessageThread>[];
    final nowIso = DateTime.now().toIso8601String();

    for (final entry in grouped.entries) {
      final canonicalId = entry.key;
      final items = entry.value;

      _ParsedChatDoc? canonicalItem;
      final legacyItems = <_ParsedChatDoc>[];
      for (final item in items) {
        if (item.doc.id == canonicalId) {
          canonicalItem = item;
        } else {
          legacyItems.add(item);
        }
      }

      final unmergedLegacyItems = legacyItems
          .where((i) => i.thread.mergedInto == null)
          .toList(growable: false);
      final activeItems = items
          .where((i) => i.thread.mergedInto == null)
          .toList(growable: false);
      final metadataSource = (activeItems.isNotEmpty ? activeItems : items)
        ..sort((a, b) =>
            b.thread.lastMessageTime.compareTo(a.thread.lastMessageTime));

      // Combine all messages chronologically across canonical + legacy docs.
      var mergedMessages = <ChatMessage>[];
      for (final item in items) {
        mergedMessages = MessageThread.mergeMessages(
          mergedMessages,
          item.thread.messages,
        );
      }

      String pickString(String Function(MessageThread t) selector,
          {bool requireValidAvatar = false}) {
        for (final item in metadataSource) {
          final v = selector(item.thread).trim();
          if (v.isEmpty) continue;
          if (requireValidAvatar && !_isValidAvatar(v)) continue;
          return v;
        }
        for (final item in items) {
          final v = selector(item.thread).trim();
          if (v.isEmpty) continue;
          if (requireValidAvatar && !_isValidAvatar(v)) continue;
          return v;
        }
        return '';
      }

      final primary = metadataSource.first.thread;
      final resolvedArtistId = pickString((t) => t.artistId);
      final resolvedClientId = pickString((t) => t.clientId ?? '');
      final resolvedClientName = pickString((t) => t.clientName ?? '');
      final resolvedArtistName = pickString((t) => t.artistName);
      final resolvedStudioName = pickString((t) => t.studioName);
      final resolvedFlashTitle = pickString((t) => t.flashTitleContext ?? '');
      var resolvedClientAvatar = pickString(
        (t) => t.clientAvatar,
        requireValidAvatar: true,
      );
      var resolvedArtistAvatar = pickString(
        (t) => t.artistAvatar,
        requireValidAvatar: true,
      );

      final avatarUpdates = <String, dynamic>{};

      // Resolve missing or stale clientAvatar.
      if (selfPhotoUrl.isNotEmpty &&
          resolvedClientId == activeUid &&
          (!_isValidAvatar(resolvedClientAvatar) ||
              resolvedClientAvatar != selfPhotoUrl)) {
        resolvedClientAvatar = selfPhotoUrl;
        avatarUpdates['clientAvatar'] = selfPhotoUrl;
      } else if (!_isValidAvatar(resolvedClientAvatar) &&
          resolvedClientId.isNotEmpty) {
        var candidate = clientAvatarsByClientId[resolvedClientId] ?? '';
        if (candidate.isEmpty) {
          try {
            final clientArtistDoc =
                await db.collection('artists').doc(resolvedClientId).get();
            candidate = extractPhotoUrl(clientArtistDoc.data());
          } catch (_) {}
        }
        if (candidate.isEmpty &&
            resolvedClientId == activeUid &&
            selfPhotoUrl.isNotEmpty) {
          candidate = selfPhotoUrl;
        }
        if (_isValidAvatar(candidate)) {
          resolvedClientAvatar = candidate;
          avatarUpdates['clientAvatar'] = candidate;
        }
      }

      // Resolve missing artistAvatar.
      if (!_isValidAvatar(resolvedArtistAvatar) &&
          resolvedArtistId.isNotEmpty) {
        String candidate = '';
        if (resolvedArtistId == activeUid && selfPhotoUrl.isNotEmpty) {
          candidate = selfPhotoUrl;
        } else {
          final cached = artistAvatarCache[resolvedArtistId];
          if (cached != null) {
            candidate = cached;
          } else {
            try {
              final artistDoc =
                  await db.collection('artists').doc(resolvedArtistId).get();
              candidate = extractPhotoUrl(artistDoc.data());
            } catch (_) {
              candidate = '';
            }
            artistAvatarCache[resolvedArtistId] = candidate;
          }
        }
        if (_isValidAvatar(candidate)) {
          resolvedArtistAvatar = candidate;
          avatarUpdates['artistAvatar'] = candidate;
        }
      }

      final clientLastReadAt =
          _latestDateTime(items.map((i) => i.thread.clientLastReadAt));
      final artistLastReadAt =
          _latestDateTime(items.map((i) => i.thread.artistLastReadAt));

      final needsMigration = unmergedLegacyItems.isNotEmpty ||
          (canonicalItem == null && legacyItems.isNotEmpty);

      int clientUnreadCount;
      int artistUnreadCount;

      if (!needsMigration && canonicalItem != null) {
        clientUnreadCount = canonicalItem.thread.clientUnreadCount;
        artistUnreadCount = canonicalItem.thread.artistUnreadCount;
      } else {
        if (clientLastReadAt != null) {
          if (mergedMessages.isNotEmpty) {
            clientUnreadCount = mergedMessages
                .where(
                  (m) =>
                      m.isFromArtist && m.timestamp.isAfter(clientLastReadAt),
                )
                .length;
          } else {
            clientUnreadCount = canonicalItem?.thread.clientUnreadCount ?? 0;
          }
        } else {
          clientUnreadCount = activeItems.fold<int>(
            0,
            (sum, i) => sum + i.thread.clientUnreadCount,
          );
        }

        if (artistLastReadAt != null) {
          if (mergedMessages.isNotEmpty) {
            artistUnreadCount = mergedMessages
                .where(
                  (m) =>
                      !m.isFromArtist && m.timestamp.isAfter(artistLastReadAt),
                )
                .length;
          } else {
            artistUnreadCount = canonicalItem?.thread.artistUnreadCount ?? 0;
          }
        } else {
          artistUnreadCount = activeItems.fold<int>(
            0,
            (sum, i) => sum + i.thread.artistUnreadCount,
          );
        }
      }

      final latestMsg =
          mergedMessages.isNotEmpty ? mergedMessages.last : null;
      final resolvedLastMessageTime = latestMsg != null &&
              latestMsg.timestamp.isAfter(primary.lastMessageTime)
          ? latestMsg.timestamp
          : primary.lastMessageTime;
      final resolvedLastMessage = latestMsg != null &&
              (latestMsg.timestamp.isAfter(primary.lastMessageTime) ||
                  primary.lastMessage.trim().isEmpty)
          ? latestMsg.previewText
          : primary.lastMessage;

      final legacyIdList =
          legacyItems.map((i) => i.doc.id).toList(growable: false);

      var thread = MessageThread(
        id: canonicalId,
        artistId: resolvedArtistId,
        clientId: resolvedClientId.isNotEmpty ? resolvedClientId : null,
        clientName: resolvedClientName.isNotEmpty ? resolvedClientName : null,
        clientAvatar: resolvedClientAvatar,
        artistName:
            resolvedArtistName.isNotEmpty ? resolvedArtistName : 'Artist',
        artistAvatar: resolvedArtistAvatar,
        studioName: resolvedStudioName,
        lastMessage: resolvedLastMessage,
        lastMessageTime: resolvedLastMessageTime,
        clientUnreadCount: clientUnreadCount,
        artistUnreadCount: artistUnreadCount,
        clientLastReadAt: clientLastReadAt,
        artistLastReadAt: artistLastReadAt,
        mergedLegacyIds: legacyIdList,
        isOnline: items.any((i) => i.thread.isOnline),
        flashTitleContext:
            resolvedFlashTitle.isNotEmpty ? resolvedFlashTitle : null,
        messages: mergedMessages,
      );

      thread = ChatCloudSync.applyPendingReadProtection(thread);

      // If the user currently has this conversation open, immediately keep it read.
      final openId = MessageThread.activeOpenThreadId;
      if (openId != null &&
          (openId == thread.id || thread.mergedLegacyIds.contains(openId))) {
        final openIsArtist = MessageThread.activeOpenThreadIsArtistView;
        if (thread.unreadCountFor(isArtistView: openIsArtist) > 0) {
          final readNow = DateTime.now();
          thread = openIsArtist
              ? thread.copyWith(artistUnreadCount: 0, artistLastReadAt: readNow)
              : thread.copyWith(clientUnreadCount: 0, clientLastReadAt: readNow);
          unawaited(
            ChatCloudSync.markThreadAsRead(
              threadId: thread.id,
              isArtistView: openIsArtist,
              legacyThreadIds: thread.mergedLegacyIds,
              readAt: readNow,
              syncedPayloads: syncedPayloads,
              enableCloudWrites: enableCloudWrites,
              firestore: db,
            ),
          );
        }
      }

      // Persist canonical backfill & mark legacy docs merged (or avatar backfill).
      if (enableCloudWrites) {
        if (needsMigration && ChatCloudSync.tryBeginMigration(canonicalId)) {
          try {
            final earliestTime = mergedMessages.isNotEmpty
                ? mergedMessages.first.timestamp
                : thread.lastMessageTime;
            final canonicalRef = db.collection('chats').doc(canonicalId);
            final mutableMap = Map<String, dynamic>.from(thread.toMap())
              ..remove('participants')
              ..remove('clientId')
              ..remove('artistId')
              ..remove('bookingId')
              ..remove('createdAt')
              ..remove('mergedInto')
              ..['updatedAt'] = nowIso;

            if (canonicalItem == null) {
              final existingCanonicalSnap = await canonicalRef.get();
              if (!existingCanonicalSnap.exists) {
                await canonicalRef.set({
                  ...mutableMap,
                  'clientId': resolvedClientId,
                  'artistId': resolvedArtistId,
                  'participants': [resolvedClientId, resolvedArtistId],
                  'createdAt': earliestTime.toIso8601String(),
                });
              } else {
                await canonicalRef.update(mutableMap);
              }
            } else {
              await canonicalRef.update(mutableMap);
            }

            for (final legacy in unmergedLegacyItems) {
              try {
                await legacy.doc.reference.update({
                  'mergedInto': canonicalId,
                  'clientUnreadCount': 0,
                  'artistUnreadCount': 0,
                  'unreadCount': 0,
                  'updatedAt': nowIso,
                  ...avatarUpdates,
                });
              } catch (_) {}
            }
          } catch (e) {
            debugPrint(
              '[BookingSyncService] Canonical chat backfill skipped for $canonicalId: $e',
            );
          } finally {
            ChatCloudSync.endMigration(canonicalId);
          }
        } else if (avatarUpdates.isNotEmpty && canonicalItem != null) {
          try {
            await canonicalItem.doc.reference.update({
              ...avatarUpdates,
              'updatedAt': nowIso,
            });
          } catch (_) {}
        }
      }

      consolidated.add(thread);
    }

    consolidated.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
    return consolidated;
  }

  /// Replaces `MessageThread.liveThreads` with consolidated Firestore threads
  /// for [activeUid], removing superseded legacy duplicate IDs cleanly.
  static void _applyConsolidatedLiveThreads(
    List<MessageThread> remoteThreads,
    String activeUid,
  ) {
    final supersededLegacyIds = <String>{};
    for (final t in remoteThreads) {
      supersededLegacyIds.addAll(t.mergedLegacyIds);
    }

    final mergedById = <String, MessageThread>{
      for (final t in remoteThreads) t.id: t,
    };

    // Preserve any locally created optimistic thread for the same user that
    // hasn't arrived in Firestore yet, without resurrecting merged duplicates.
    for (final local in MessageThread.liveThreads) {
      if (supersededLegacyIds.contains(local.id)) continue;
      if (mergedById.containsKey(local.id)) continue;
      final belongsToActiveUser = local.artistId.trim() == activeUid ||
          (local.clientId ?? '').trim() == activeUid;
      if (!belongsToActiveUser) continue;

      final canonicalKey = MessageThread.hasCanonicalParticipants(
        clientId: local.clientId,
        artistId: local.artistId,
      )
          ? MessageThread.canonicalThreadId(
              clientId: local.clientId!,
              artistId: local.artistId,
            )
          : local.id;
      if (mergedById.containsKey(canonicalKey)) continue;
      mergedById[local.id] = local;
    }

    final sorted = mergedById.values.toList()
      ..sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));

    MessageThread.liveThreads
      ..clear()
      ..addAll(sorted);
  }

  static Map<String, String> _collectKnownClientAvatars() {
    final avatars = <String, String>{};
    for (final apt in ArtistDashboardRepository.liveCalendarAppointments) {
      final cid = apt.clientId?.trim() ?? '';
      final avatar = apt.clientAvatar?.trim() ?? '';
      if (cid.isNotEmpty && _isValidAvatar(avatar)) {
        avatars[cid] = avatar;
      }
    }
    for (final req in ArtistDashboardRepository.livePendingRequests) {
      final cid = req.clientId?.trim() ?? '';
      final avatar = req.clientAvatar?.trim() ?? '';
      if (cid.isNotEmpty && _isValidAvatar(avatar)) {
        avatars.putIfAbsent(cid, () => avatar);
      }
    }
    return avatars;
  }

  /// Starts (or reuses) a single real-time Firestore listener for all chat threads
  /// involving [userId]. Automatically cancels the previous listener if the
  /// authenticated user changes.
  static StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      ensureUserChatsListener(
    String userId, {
    required String Function() resolveCurrentUserPhotoUrlSync,
    required String Function(Map<String, dynamic>? data) extractPhotoUrl,
    required bool enableCloudWrites,
    required List<Map<String, dynamic>> syncedPayloads,
    FirebaseFirestore? firestore,
  }) {
    final cleanUid = userId.trim();
    if (cleanUid.isEmpty || MockDataConfig.isEnabled) return null;

    FirebaseFirestore? db = firestore;
    if (db == null) {
      try {
        db = FirebaseFirestore.instance;
      } catch (_) {
        return null;
      }
    }

    if (_activeChatsSub != null &&
        _activeChatsUid == cleanUid &&
        identical(_activeChatsFirestore, db)) {
      return _activeChatsSub;
    }

    final previousUid = _activeChatsUid;
    stopUserChatsListener();
    if (previousUid != null && previousUid != cleanUid) {
      MessageThread.clearSessionThreads();
      ChatCloudSync.clearTransientState();
    }

    _activeChatsUid = cleanUid;
    _activeChatsFirestore = db;
    final resolvedDb = db;

    try {
      _activeChatsSub = resolvedDb
          .collection('chats')
          .where('participants', arrayContains: cleanUid)
          .snapshots()
          .listen(
        (chatSnap) async {
          final snapshotEpoch = ++_chatsSnapshotEpoch;
          try {
            final consolidated = await _consolidateChatSnapshot(
              chatSnap: chatSnap,
              activeUid: cleanUid,
              db: resolvedDb,
              extractPhotoUrl: extractPhotoUrl,
              enableCloudWrites: enableCloudWrites,
              syncedPayloads: syncedPayloads,
              selfPhotoUrl: resolveCurrentUserPhotoUrlSync(),
              clientAvatarsByClientId: _collectKnownClientAvatars(),
            );
            if (snapshotEpoch != _chatsSnapshotEpoch ||
                _activeChatsUid != cleanUid) {
              return;
            }
            _applyConsolidatedLiveThreads(consolidated, cleanUid);
            MessageThread.unreadUpdateNotifier.value++;
            ArtistDashboardRepository.notifyPendingRequestsChanged();
          } catch (e) {
            debugPrint(
              '[BookingSyncService] Chat snapshot processing error for $cleanUid: $e',
            );
          }
        },
        onError: (Object error) {
          debugPrint(
            '[BookingSyncService] User chats stream error for $cleanUid: $error',
          );
        },
      );
      return _activeChatsSub;
    } catch (_) {
      return null;
    }
  }

  /// Stops any active real-time user chats subscription (called on sign-out).
  static void stopUserChatsListener() {
    _chatsSnapshotEpoch++;
    _activeChatsSub?.cancel();
    _activeChatsSub = null;
    _activeChatsUid = null;
    _activeChatsFirestore = null;
  }

  /// Listens in real time to the `messages` subcollection of [threadId] so
  /// messages written directly by Cloud Functions appear immediately while the
  /// conversation screen is open.
  static StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      listenToThreadMessages(
    String threadId, {
    required void Function(List<ChatMessage> messages) onMessages,
    FirebaseFirestore? firestore,
  }) {
    final cleanId = threadId.trim();
    if (cleanId.isEmpty || MockDataConfig.isEnabled) return null;

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
          .collection('chats')
          .doc(cleanId)
          .collection('messages')
          .snapshots()
          .listen(
        (snap) {
          if (snap.docs.isEmpty) return;
          final msgs = snap.docs
              .map((doc) => ChatMessage.fromMap(doc.data(), doc.id))
              .toList()
            ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
          onMessages(msgs);
        },
        onError: (_) {},
      );
    } catch (_) {
      return null;
    }
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
    required List<Map<String, dynamic>> syncedPayloads,
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

    // 0. Hydrate artist Stripe Connect payout readiness from `/artists/{artistId}`
    Map<String, dynamic>? cachedArtistDocData;
    try {
      final selfArtistDoc =
          await db.collection('artists').doc(cleanArtistId).get();
      if (selfArtistDoc.exists && selfArtistDoc.data() != null) {
        cachedArtistDocData = selfArtistDoc.data()!;
        final payoutsReady = cachedArtistDocData['stripePayoutsReady'] == true;
        ArtistDashboardRepository.stripePayoutsReady = payoutsReady;
        changed = true;
      }
    } catch (_) {}

    // 1. Hydrate artist_schedules (BooksSchedule + Waitlist)
    try {
      final schedDoc =
          await db.collection('artist_schedules').doc(cleanArtistId).get();
      if (schedDoc.exists && schedDoc.data() != null) {
        final data = schedDoc.data()!;
        var loadedSchedule = ArtistBooksSchedule.fromMap(data);
        if (!ArtistDashboardRepository.stripePayoutsReady &&
            loadedSchedule.isBooksOpen) {
          loadedSchedule = loadedSchedule.copyWith(
            isBooksOpen: false,
            isEarlyAccessOnly: false,
          );
        }
        ArtistDashboardRepository.booksSchedule = loadedSchedule;
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

    // 4. Hydrate & consolidate chats where artist is a participant
    try {
      String selfArtistAvatar = resolveCurrentUserPhotoUrlSync();
      if (selfArtistAvatar.isEmpty) {
        selfArtistAvatar = extractPhotoUrl(cachedArtistDocData);
      }
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
        final consolidated = await _consolidateChatSnapshot(
          chatSnap: chatSnap,
          activeUid: cleanArtistId,
          db: db,
          extractPhotoUrl: extractPhotoUrl,
          enableCloudWrites: enableCloudWrites,
          syncedPayloads: syncedPayloads,
          selfPhotoUrl: selfArtistAvatar,
          clientAvatarsByClientId: _collectKnownClientAvatars(),
        );
        _applyConsolidatedLiveThreads(consolidated, cleanArtistId);
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
    required List<Map<String, dynamic>> syncedPayloads,
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
      final aptSnap = await db
          .collection('appointments')
          .where('clientId', isEqualTo: cleanClientId)
          .get();
      if (aptSnap.docs.isNotEmpty) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final upcomingById = <String, ClientAppointment>{
          for (final a in ClientAppointment.liveUpcoming) a.id: a,
        };
        final pastById = <String, ClientAppointment>{
          for (final a in ClientAppointment.livePast) a.id: a,
        };

        for (final doc in aptSnap.docs) {
          final parsed = ClientAppointment.fromMap(doc.data(), doc.id);
          if (parsed.status == AppointmentStatus.cancelled) {
            upcomingById.remove(parsed.id);
            pastById.remove(parsed.id);
            continue;
          }
          final aptDay = DateTime(
            parsed.dateTime.year,
            parsed.dateTime.month,
            parsed.dateTime.day,
          );
          final isPast = parsed.status == AppointmentStatus.completed ||
              aptDay.isBefore(today);
          if (isPast) {
            final normalizedPast = parsed.status == AppointmentStatus.completed
                ? parsed
                : parsed.copyWith(status: AppointmentStatus.completed);
            pastById[normalizedPast.id] = normalizedPast;
            upcomingById.remove(normalizedPast.id);
          } else {
            upcomingById[parsed.id] = parsed;
            pastById.remove(parsed.id);
          }
        }

        ClientAppointment.liveUpcoming
          ..clear()
          ..addAll(
            upcomingById.values.toList()
              ..sort((a, b) => a.dateTime.compareTo(b.dateTime)),
          );
        ClientAppointment.livePast
          ..clear()
          ..addAll(
            pastById.values.toList()
              ..sort((a, b) => b.dateTime.compareTo(a.dateTime)),
          );
        ClientAppointment.appointmentsUpdateNotifier.value++;
        changed = true;
      }
    } catch (_) {}

    try {
      final chatSnap = await db
          .collection('chats')
          .where('participants', arrayContains: cleanClientId)
          .get();
      if (chatSnap.docs.isNotEmpty) {
        final consolidated = await _consolidateChatSnapshot(
          chatSnap: chatSnap,
          activeUid: cleanClientId,
          db: db,
          extractPhotoUrl: extractPhotoUrl,
          enableCloudWrites: enableCloudWrites,
          syncedPayloads: syncedPayloads,
          selfPhotoUrl: selfPhotoUrl,
        );
        _applyConsolidatedLiveThreads(consolidated, cleanClientId);
        changed = true;
      }
    } catch (_) {}

    if (changed) {
      MessageThread.unreadUpdateNotifier.value++;
    }
  }
}
