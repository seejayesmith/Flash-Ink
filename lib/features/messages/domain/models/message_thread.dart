import 'package:flutter/foundation.dart';
import '../../../../core/mock/mock_data_config.dart';
import '../../../../core/mock/mock_fixtures.dart';

enum ChatMessageType { text, receipt }

/// Individual chat message item.
class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime timestamp;
  final bool isFromArtist;
  
  final ChatMessageType type;
  final double? receiptAmount;
  final DateTime? appointmentDate;
  final String? flashImageUrl;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.timestamp,
    required this.isFromArtist,
    this.type = ChatMessageType.text,
    this.receiptAmount,
    this.appointmentDate,
    this.flashImageUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      'timestamp': timestamp.toIso8601String(),
      'isFromArtist': isFromArtist,
      'type': type.name,
      if (receiptAmount != null) 'receiptAmount': receiptAmount,
      if (appointmentDate != null) 'appointmentDate': appointmentDate!.toIso8601String(),
      if (flashImageUrl != null) 'flashImageUrl': flashImageUrl,
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map, [String? docId]) {
    final rawType = map['type']?.toString() ?? 'text';
    final parsedType = rawType == 'receipt' ? ChatMessageType.receipt : ChatMessageType.text;
    return ChatMessage(
      id: (docId != null && docId.isNotEmpty)
          ? docId
          : (map['id']?.toString() ?? 'msg_${DateTime.now().millisecondsSinceEpoch}'),
      senderId: map['senderId']?.toString() ?? '',
      senderName: map['senderName']?.toString() ?? '',
      text: map['text']?.toString() ?? '',
      timestamp: map['timestamp'] is String
          ? DateTime.tryParse(map['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
      isFromArtist: map['isFromArtist'] == true,
      type: parsedType,
      receiptAmount: (map['receiptAmount'] as num?)?.toDouble(),
      appointmentDate: map['appointmentDate'] is String
          ? DateTime.tryParse(map['appointmentDate'] as String)
          : null,
      flashImageUrl: map['flashImageUrl']?.toString(),
    );
  }
}

/// Message thread representation for the Messages inbox.
class MessageThread {
  final String id;
  final String artistId;
  final String? clientId;
  final String? clientName;
  final String artistName;
  final String artistAvatar;
  final String studioName;
  final String lastMessage;
  final DateTime lastMessageTime;
  final int unreadCount;
  final bool isOnline;
  final String? flashTitleContext;
  final List<ChatMessage> messages;

  bool get hasUnread => unreadCount > 0;

  const MessageThread({
    required this.id,
    required this.artistId,
    this.clientId,
    this.clientName,
    required this.artistName,
    required this.artistAvatar,
    required this.studioName,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.unreadCount,
    this.isOnline = false,
    this.flashTitleContext,
    this.messages = const [],
  });

  MessageThread copyWith({
    String? id,
    String? artistId,
    String? clientId,
    String? clientName,
    String? artistName,
    String? artistAvatar,
    String? studioName,
    String? lastMessage,
    DateTime? lastMessageTime,
    int? unreadCount,
    bool? isOnline,
    String? flashTitleContext,
    List<ChatMessage>? messages,
  }) {
    return MessageThread(
      id: id ?? this.id,
      artistId: artistId ?? this.artistId,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      artistName: artistName ?? this.artistName,
      artistAvatar: artistAvatar ?? this.artistAvatar,
      studioName: studioName ?? this.studioName,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      unreadCount: unreadCount ?? this.unreadCount,
      isOnline: isOnline ?? this.isOnline,
      flashTitleContext: flashTitleContext ?? this.flashTitleContext,
      messages: messages ?? this.messages,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'artistId': artistId,
      if (clientId != null) 'clientId': clientId,
      if (clientName != null) 'clientName': clientName,
      'artistName': artistName,
      'artistAvatar': artistAvatar,
      'studioName': studioName,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime.toIso8601String(),
      'unreadCount': unreadCount,
      'isOnline': isOnline,
      if (flashTitleContext != null) 'flashTitleContext': flashTitleContext,
      'messages': messages.map((m) => m.toMap()).toList(),
    };
  }

  factory MessageThread.fromMap(Map<String, dynamic> map, [String? docId]) {
    final rawMsgs = map['messages'];
    final parsedMsgs = rawMsgs is List
        ? rawMsgs
            .whereType<Map>()
            .map((m) => ChatMessage.fromMap(Map<String, dynamic>.from(m)))
            .toList()
        : <ChatMessage>[];
    return MessageThread(
      id: (docId != null && docId.isNotEmpty)
          ? docId
          : (map['id']?.toString() ?? 'thread_${DateTime.now().millisecondsSinceEpoch}'),
      artistId: map['artistId']?.toString() ?? '',
      clientId: map['clientId']?.toString(),
      clientName: map['clientName']?.toString(),
      artistName: map['artistName']?.toString() ?? 'Artist',
      artistAvatar: map['artistAvatar']?.toString() ?? '',
      studioName: map['studioName']?.toString() ?? '',
      lastMessage: map['lastMessage']?.toString() ?? '',
      lastMessageTime: map['lastMessageTime'] is String
          ? DateTime.tryParse(map['lastMessageTime'] as String) ?? DateTime.now()
          : DateTime.now(),
      unreadCount: (map['unreadCount'] as num?)?.toInt() ?? 0,
      isOnline: map['isOnline'] == true,
      flashTitleContext: map['flashTitleContext']?.toString(),
      messages: parsedMsgs,
    );
  }

  /// Notifier triggered whenever thread read states or unread counts change.
  static final ValueNotifier<int> unreadUpdateNotifier = ValueNotifier<int>(0);

  /// Quarantined mock threads preserved in [MockFixtures].
  static List<MessageThread> mockThreads = MockFixtures.createMessageThreads();

  /// Live session threads populated during an active authenticated session.
  static final List<MessageThread> liveThreads = [];

  /// Active message threads for the current runtime mode.
  static List<MessageThread> get activeThreads =>
      MockDataConfig.isEnabled ? mockThreads : liveThreads;

  /// Total unread messages across active threads (optionally filtered by artist ID).
  static int totalUnreadCount([String? artistId]) {
    final threads = activeThreads;
    final relevant = (artistId != null && artistId.isNotEmpty)
        ? threads.where((t) => t.artistId == artistId)
        : threads;
    return relevant.fold<int>(0, (sum, t) => sum + t.unreadCount);
  }

  /// Marks a specific conversation thread as read across active session lists.
  static void markThreadAsRead(String threadId) {
    bool updated = false;
    final mockIndex = mockThreads.indexWhere((t) => t.id == threadId);
    if (mockIndex != -1 && mockThreads[mockIndex].unreadCount > 0) {
      mockThreads[mockIndex] = mockThreads[mockIndex].copyWith(unreadCount: 0);
      updated = true;
    }

    final liveIndex = liveThreads.indexWhere((t) => t.id == threadId);
    if (liveIndex != -1 && liveThreads[liveIndex].unreadCount > 0) {
      liveThreads[liveIndex] = liveThreads[liveIndex].copyWith(unreadCount: 0);
      updated = true;
    }

    if (updated) {
      unreadUpdateNotifier.value++;
    }
  }

  /// Prepends a thread to the active session list (or mock list when sandboxed).
  static void addThread(MessageThread thread) {
    if (MockDataConfig.isEnabled) {
      mockThreads.insert(0, thread);
    } else {
      liveThreads.insert(0, thread);
    }
    unreadUpdateNotifier.value++;
  }

  /// Clears session-scoped message threads upon sign-out.
  static void clearSessionThreads() {
    liveThreads.clear();
    unreadUpdateNotifier.value++;
  }

  /// Resets mock threads to initial fixture data (useful for test isolation).
  static void resetMockThreads() {
    mockThreads = MockFixtures.createMessageThreads();
    unreadUpdateNotifier.value++;
  }
}
