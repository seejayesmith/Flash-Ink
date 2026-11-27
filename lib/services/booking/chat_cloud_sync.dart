import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../features/messages/domain/models/message_thread.dart';
import '../../repositories/artist_dashboard_repository.dart';

/// Handles Cloud Firestore persistence for direct-message threads, per-role
/// unread counters/read watermarks, and canonical thread updates.
class ChatCloudSync {
  const ChatCloudSync._();

  static final Map<String, DateTime> _pendingLocalReads = <String, DateTime>{};
  static final Set<String> _migratingCanonicalIds = <String>{};

  static String _pendingReadKey(String threadId, bool isArtistView) =>
      '${threadId.trim()}:${isArtistView ? 'artist' : 'client'}';

  /// Clears transient in-flight read and migration guards (called on sign-out).
  static void clearTransientState() {
    _pendingLocalReads.clear();
    _migratingCanonicalIds.clear();
  }

  /// Tracks whether [canonicalId] currently has an active legacy backfill write.
  static bool tryBeginMigration(String canonicalId) =>
      _migratingCanonicalIds.add(canonicalId);

  static void endMigration(String canonicalId) {
    _migratingCanonicalIds.remove(canonicalId);
  }

  /// Protects optimistic local reads from being reverted by stale in-flight
  /// Firestore snapshots before the cloud write settles.
  static MessageThread applyPendingReadProtection(MessageThread thread) {
    var resolved = thread;

    final clientKey = _pendingReadKey(thread.id, false);
    final pendingClientRead = _pendingLocalReads[clientKey];
    if (pendingClientRead != null) {
      final remoteRead = resolved.clientLastReadAt;
      if (remoteRead != null && !remoteRead.isBefore(pendingClientRead)) {
        _pendingLocalReads.remove(clientKey);
      } else {
        final hasNewerArtistMsg = resolved.messages.any(
          (m) => m.isFromArtist && m.timestamp.isAfter(pendingClientRead),
        );
        if (!hasNewerArtistMsg) {
          resolved = resolved.copyWith(
            clientUnreadCount: 0,
            clientLastReadAt: pendingClientRead,
          );
        } else {
          _pendingLocalReads.remove(clientKey);
        }
      }
    }

    final artistKey = _pendingReadKey(thread.id, true);
    final pendingArtistRead = _pendingLocalReads[artistKey];
    if (pendingArtistRead != null) {
      final remoteRead = resolved.artistLastReadAt;
      if (remoteRead != null && !remoteRead.isBefore(pendingArtistRead)) {
        _pendingLocalReads.remove(artistKey);
      } else {
        final hasNewerClientMsg = resolved.messages.any(
          (m) => !m.isFromArtist && m.timestamp.isAfter(pendingArtistRead),
        );
        if (!hasNewerClientMsg) {
          resolved = resolved.copyWith(
            artistUnreadCount: 0,
            artistLastReadAt: pendingArtistRead,
          );
        } else {
          _pendingLocalReads.remove(artistKey);
        }
      }
    }

    return resolved;
  }

  static String _sanitizeAvatar(String? primary, String fallback) {
    if (primary != null &&
        primary.trim().isNotEmpty &&
        !primary.trim().startsWith('local://')) {
      return primary.trim();
    }
    if (fallback.trim().isNotEmpty && !fallback.trim().startsWith('local://')) {
      return fallback.trim();
    }
    return '';
  }

  static FirebaseFirestore? _resolveDb(FirebaseFirestore? firestore) {
    if (firestore != null) return firestore;
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  /// Marks [threadId] as read for either Artist Mode or Client Mode both locally
  /// and in Cloud Firestore so the read state persists across account switches.
  static Future<void> markThreadAsRead({
    required String threadId,
    required bool isArtistView,
    required List<Map<String, dynamic>> syncedPayloads,
    required bool enableCloudWrites,
    List<String> legacyThreadIds = const [],
    DateTime? readAt,
    FirebaseFirestore? firestore,
  }) async {
    final cleanId = threadId.trim();
    if (cleanId.isEmpty) return;

    final now = readAt ?? DateTime.now();
    final nowIso = now.toIso8601String();

    final existing = MessageThread.findExistingThread(threadId: cleanId);
    final resolvedCanonicalId = existing?.id ?? cleanId;
    final allLegacyIds = <String>{
      ...legacyThreadIds
          .map((id) => id.trim())
          .where((id) => id.isNotEmpty && id != resolvedCanonicalId),
      if (existing != null)
        ...existing.mergedLegacyIds
            .map((id) => id.trim())
            .where((id) => id.isNotEmpty && id != resolvedCanonicalId),
      if (cleanId != resolvedCanonicalId) cleanId,
    };

    _pendingLocalReads[_pendingReadKey(resolvedCanonicalId, isArtistView)] = now;
    if (cleanId != resolvedCanonicalId) {
      _pendingLocalReads[_pendingReadKey(cleanId, isArtistView)] = now;
    }

    MessageThread.markThreadAsRead(
      resolvedCanonicalId,
      isArtistView: isArtistView,
      readAt: now,
    );

    // Strictly mutable keys so Firestore rules `areImmutableFieldsUnchanged` always passes.
    final updatePayload = <String, dynamic>{
      if (isArtistView) ...{
        'artistUnreadCount': 0,
        'artistLastReadAt': nowIso,
      } else ...{
        'clientUnreadCount': 0,
        'clientLastReadAt': nowIso,
        'unreadCount': 0,
      },
      'updatedAt': nowIso,
    };

    syncedPayloads.add({
      'collection': 'chats',
      'threadId': resolvedCanonicalId,
      'action': 'mark_read',
      'data': updatePayload,
    });

    if (!enableCloudWrites && firestore == null) return;
    final db = _resolveDb(firestore);
    if (db == null) return;

    try {
      final docRef = db.collection('chats').doc(resolvedCanonicalId);
      final snap = await docRef.get();
      if (snap.exists) {
        await docRef.update(updatePayload);
      }

      for (final legacyId in allLegacyIds) {
        try {
          final legacyRef = db.collection('chats').doc(legacyId);
          final legacySnap = await legacyRef.get();
          if (legacySnap.exists) {
            await legacyRef.update({
              'clientUnreadCount': 0,
              'artistUnreadCount': 0,
              'unreadCount': 0,
              if (isArtistView)
                'artistLastReadAt': nowIso
              else
                'clientLastReadAt': nowIso,
              'updatedAt': nowIso,
            });
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint(
        '[BookingSyncService] Offline/local fallback for markThreadAsRead $resolvedCanonicalId: $e',
      );
    }
  }

  /// Persists a thread to Cloud Firestore safely, creating it with immutable
  /// fields on first write and updating only mutable fields on subsequent writes.
  static Future<void> syncChatThreadToCloud(
    MessageThread thread, {
    required String artistId,
    required String Function([String fallback]) resolveCurrentUid,
    required List<Map<String, dynamic>> syncedPayloads,
    required bool enableCloudWrites,
    String? clientId,
    String? clientName,
    String? clientAvatar,
    String? artistAvatar,
    bool syncSubcollectionMessages = true,
    List<ChatMessage>? newMessagesForSubcollection,
    bool? incrementRecipientFromArtist,
    FirebaseFirestore? firestore,
  }) async {
    final effectiveArtistId = artistId.trim().isNotEmpty
        ? artistId.trim()
        : (thread.artistId.trim().isNotEmpty
            ? thread.artistId.trim()
            : resolveCurrentUid('artist_unknown'));
    final effectiveClientId = (clientId != null && clientId.trim().isNotEmpty)
        ? clientId.trim()
        : (thread.clientId != null && thread.clientId!.trim().isNotEmpty
            ? thread.clientId!.trim()
            : resolveCurrentUid('client_unknown'));
    final participants = <String>[effectiveClientId, effectiveArtistId];

    final resolvedClientAvatar =
        _sanitizeAvatar(clientAvatar, thread.clientAvatar);
    final resolvedArtistAvatar =
        _sanitizeAvatar(artistAvatar, thread.artistAvatar);

    final nowIso = DateTime.now().toIso8601String();
    final earliestMsgTime = thread.messages.isNotEmpty
        ? thread.messages
            .map((m) => m.timestamp)
            .reduce((a, b) => a.isBefore(b) ? a : b)
        : thread.lastMessageTime;

    final threadMap = thread.toMap();
    if (resolvedClientAvatar.isEmpty) {
      threadMap.remove('clientAvatar');
    } else {
      threadMap['clientAvatar'] = resolvedClientAvatar;
    }
    if (resolvedArtistAvatar.isEmpty) {
      threadMap.remove('artistAvatar');
    } else {
      threadMap['artistAvatar'] = resolvedArtistAvatar;
    }
    if (clientName != null && clientName.isNotEmpty) {
      threadMap['clientName'] = clientName;
    }

    // Mutable-only payload (omits immutable keys: participants, clientId, artistId, bookingId, createdAt).
    final mutablePayload = Map<String, dynamic>.from(threadMap)
      ..remove('participants')
      ..remove('clientId')
      ..remove('artistId')
      ..remove('bookingId')
      ..remove('createdAt');
    mutablePayload['updatedAt'] = nowIso;

    final createPayload = <String, dynamic>{
      ...mutablePayload,
      'clientId': effectiveClientId,
      'artistId': effectiveArtistId,
      'participants': participants,
      'createdAt': earliestMsgTime.toIso8601String(),
      'updatedAt': nowIso,
    };

    syncedPayloads.add({'collection': 'chats', 'data': createPayload});

    if (!enableCloudWrites && firestore == null) return;
    final db = _resolveDb(firestore);
    if (db == null) return;

    try {
      final docRef = db.collection('chats').doc(thread.id);
      final existingSnap = await docRef.get();
      if (!existingSnap.exists) {
        await docRef.set(createPayload);
      } else {
        final existingData = existingSnap.data() ?? const <String, dynamic>{};
        final existingParsed = MessageThread.fromMap(existingData, thread.id);
        final mergedMessages = MessageThread.mergeMessages(
          existingParsed.messages,
          thread.messages,
        );
        final latestMessage =
            mergedMessages.isNotEmpty ? mergedMessages.last : null;
        final latestTime = latestMessage != null &&
                latestMessage.timestamp.isAfter(thread.lastMessageTime)
            ? latestMessage.timestamp
            : (existingParsed.lastMessageTime.isAfter(thread.lastMessageTime)
                ? existingParsed.lastMessageTime
                : thread.lastMessageTime);
        final latestPreview = latestMessage != null &&
                latestMessage.timestamp.isAfter(thread.lastMessageTime)
            ? latestMessage.previewText
            : (existingParsed.lastMessageTime.isAfter(thread.lastMessageTime)
                ? existingParsed.lastMessage
                : thread.lastMessage);

        final updatePayload = Map<String, dynamic>.from(mutablePayload)
          ..['messages'] = mergedMessages.map((m) => m.toMap()).toList()
          ..['lastMessage'] = latestPreview
          ..['lastMessageTime'] = latestTime.toIso8601String()
          ..['updatedAt'] = nowIso;

        if (incrementRecipientFromArtist == true) {
          updatePayload['artistUnreadCount'] = 0;
          updatePayload['artistLastReadAt'] = nowIso;
          updatePayload['clientUnreadCount'] = FieldValue.increment(1);
          updatePayload['unreadCount'] = FieldValue.increment(1);
        } else if (incrementRecipientFromArtist == false) {
          updatePayload['clientUnreadCount'] = 0;
          updatePayload['clientLastReadAt'] = nowIso;
          updatePayload['unreadCount'] = 0;
          updatePayload['artistUnreadCount'] = FieldValue.increment(1);
        } else {
          // Metadata/avatar-only update: never clobber unread counts in Firestore.
          updatePayload.remove('clientUnreadCount');
          updatePayload.remove('artistUnreadCount');
          updatePayload.remove('unreadCount');
        }

        // Keep any existing read watermarks if incoming thread doesn't have newer ones.
        if (incrementRecipientFromArtist != false &&
            existingParsed.clientLastReadAt != null &&
            (thread.clientLastReadAt == null ||
                existingParsed.clientLastReadAt!
                    .isAfter(thread.clientLastReadAt!))) {
          updatePayload['clientLastReadAt'] =
              existingParsed.clientLastReadAt!.toIso8601String();
        }
        if (incrementRecipientFromArtist != true &&
            existingParsed.artistLastReadAt != null &&
            (thread.artistLastReadAt == null ||
                existingParsed.artistLastReadAt!
                    .isAfter(thread.artistLastReadAt!))) {
          updatePayload['artistLastReadAt'] =
              existingParsed.artistLastReadAt!.toIso8601String();
        }

        await docRef.update(updatePayload);
      }

      if (syncSubcollectionMessages) {
        final currentUid = resolveCurrentUid('');
        final toWrite = newMessagesForSubcollection ?? thread.messages;
        for (final msg in toWrite) {
          // Firestore rules require senderId == request.auth.uid on message create
          // and disallow updates on existing message docs.
          if (currentUid.isNotEmpty && msg.senderId != currentUid) {
            continue;
          }
          try {
            final msgRef = docRef.collection('messages').doc(msg.id);
            final msgSnap = await msgRef.get();
            if (!msgSnap.exists) {
              await msgRef.set(msg.toMap());
            }
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint(
        '[BookingSyncService] Offline/local fallback for chat thread ${thread.id}: $e',
      );
    }
  }

  /// Appends [message] to an existing thread (or creates the canonical thread),
  /// clears ONLY the sender's unread count, and increments ONLY the recipient's
  /// unread count in both local memory and Cloud Firestore.
  static Future<void> appendAndSyncChatMessage({
    required String threadId,
    required ChatMessage message,
    required List<Map<String, dynamic>> syncedPayloads,
    required bool enableCloudWrites,
    String Function([String fallback])? resolveCurrentUid,
    FirebaseFirestore? firestore,
  }) async {
    final now = DateTime.now();
    final nowIso = now.toIso8601String();
    final senderIsArtist = message.isFromArtist;

    final threads = MessageThread.activeThreads;
    var idx = threads.indexWhere(
      (t) => t.id == threadId || t.mergedLegacyIds.contains(threadId),
    );

    MessageThread? updatedLocalThread;
    var effectiveThreadId = threadId;

    if (idx != -1) {
      final existing = threads[idx];
      effectiveThreadId = existing.id;
      final updatedMessages = MessageThread.mergeMessages(
        existing.messages,
        [message],
      );
      updatedLocalThread = existing.copyWith(
        lastMessage: message.previewText,
        lastMessageTime: message.timestamp,
        clientUnreadCount: senderIsArtist ? existing.clientUnreadCount + 1 : 0,
        artistUnreadCount: senderIsArtist ? 0 : existing.artistUnreadCount + 1,
        clientLastReadAt: senderIsArtist ? existing.clientLastReadAt : now,
        artistLastReadAt: senderIsArtist ? now : existing.artistLastReadAt,
        messages: updatedMessages,
      );
      threads.removeAt(idx);
      threads.insert(0, updatedLocalThread);

      _pendingLocalReads[_pendingReadKey(effectiveThreadId, senderIsArtist)] =
          now;
      MessageThread.unreadUpdateNotifier.value++;
      ArtistDashboardRepository.notifyPendingRequestsChanged();
    }

    syncedPayloads.add({'collection': 'messages', 'data': message.toMap()});

    if (!enableCloudWrites && firestore == null) return;
    final db = _resolveDb(firestore);
    if (db == null) return;

    try {
      final docRef = db.collection('chats').doc(effectiveThreadId);
      final existingSnap = await docRef.get();

      if (existingSnap.exists) {
        final updatePayload = <String, dynamic>{
          'lastMessage': message.previewText,
          'lastMessageTime': message.timestamp.toIso8601String(),
          'updatedAt': nowIso,
          'messages': FieldValue.arrayUnion([message.toMap()]),
          if (senderIsArtist) ...{
            'artistUnreadCount': 0,
            'artistLastReadAt': nowIso,
            'clientUnreadCount': FieldValue.increment(1),
            'unreadCount': FieldValue.increment(1),
          } else ...{
            'clientUnreadCount': 0,
            'clientLastReadAt': nowIso,
            'unreadCount': 0,
            'artistUnreadCount': FieldValue.increment(1),
          },
        };
        await docRef.update(updatePayload);
      } else if (updatedLocalThread != null) {
        await syncChatThreadToCloud(
          updatedLocalThread,
          artistId: updatedLocalThread.artistId,
          clientId: updatedLocalThread.clientId,
          clientName: updatedLocalThread.clientName,
          clientAvatar: updatedLocalThread.clientAvatar,
          artistAvatar: updatedLocalThread.artistAvatar,
          resolveCurrentUid: resolveCurrentUid ?? ([fallback = '']) => fallback,
          syncedPayloads: syncedPayloads,
          enableCloudWrites: true,
          syncSubcollectionMessages: false,
          firestore: db,
        );
      }

      final currentUid = resolveCurrentUid?.call('') ?? '';
      if (currentUid.isEmpty || message.senderId == currentUid) {
        try {
          final msgRef = docRef.collection('messages').doc(message.id);
          final msgSnap = await msgRef.get();
          if (!msgSnap.exists) {
            await msgRef.set(message.toMap());
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint(
        '[BookingSyncService] Offline/local fallback for chat message ${message.id}: $e',
      );
    }
  }
}
