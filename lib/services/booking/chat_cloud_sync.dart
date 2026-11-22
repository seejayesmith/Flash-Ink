import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../features/messages/domain/models/message_thread.dart';
import '../../repositories/artist_dashboard_repository.dart';

/// Handles Cloud Firestore persistence for direct-message threads and messages.
class ChatCloudSync {
  const ChatCloudSync._();

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

    final payload = {
      ...threadMap,
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
      debugPrint(
        '[BookingSyncService] Offline/local fallback for chat thread ${thread.id}: $e',
      );
    }
  }

  static Future<void> appendAndSyncChatMessage({
    required String threadId,
    required ChatMessage message,
    required List<Map<String, dynamic>> syncedPayloads,
    required bool enableCloudWrites,
  }) async {
    final threads = MessageThread.activeThreads;
    final idx = threads.indexWhere((t) => t.id == threadId);
    if (idx != -1) {
      final existing = threads[idx];
      final updatedMessages = [...existing.messages, message];
      final updatedThread = existing.copyWith(
        lastMessage: message.previewText,
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
        'lastMessage': message.previewText,
        'lastMessageTime': message.timestamp.toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
        'messages': FieldValue.arrayUnion([message.toMap()]),
      }, SetOptions(merge: true));
      await docRef
          .collection('messages')
          .doc(message.id)
          .set(message.toMap(), SetOptions(merge: true));
    } catch (e) {
      debugPrint(
        '[BookingSyncService] Offline/local fallback for chat message ${message.id}: $e',
      );
    }
  }
}
