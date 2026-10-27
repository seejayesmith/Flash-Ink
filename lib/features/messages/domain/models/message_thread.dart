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
}

/// Message thread representation for the Messages inbox.
class MessageThread {
  final String id;
  final String artistId;
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

  /// Quarantined mock threads preserved in [MockFixtures].
  static List<MessageThread> mockThreads = MockFixtures.createMessageThreads();

  /// Live session threads populated during an active authenticated session.
  static final List<MessageThread> liveThreads = [];

  /// Active message threads for the current runtime mode.
  static List<MessageThread> get activeThreads =>
      MockDataConfig.isEnabled ? mockThreads : liveThreads;

  /// Prepends a thread to the active session list (or mock list when sandboxed).
  static void addThread(MessageThread thread) {
    if (MockDataConfig.isEnabled) {
      mockThreads.insert(0, thread);
    } else {
      liveThreads.insert(0, thread);
    }
  }

  /// Clears session-scoped message threads upon sign-out.
  static void clearSessionThreads() {
    liveThreads.clear();
  }
}
