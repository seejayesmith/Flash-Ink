/// Individual chat message item.
class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime timestamp;
  final bool isFromArtist;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.timestamp,
    required this.isFromArtist,
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

  static List<MessageThread> mockThreads = [
    MessageThread(
      id: 'thread_1',
      artistId: 'artist_1',
      artistName: 'OddMaree',
      artistAvatar:
          'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=400&q=80',
      studioName: 'Obsidian Atelier',
      lastMessage: 'Looking forward to our session! Make sure to stay hydrated beforehand.',
      lastMessageTime: DateTime.now().subtract(const Duration(minutes: 18)),
      unreadCount: 2,
      isOnline: true,
      flashTitleContext: 'Sacred Serpent & Peony',
      messages: [
        ChatMessage(
          id: 'm1',
          senderId: 'client_user',
          senderName: 'You',
          text: 'Hi OddMaree! Just claimed the Serpent & Peony flash for October 14.',
          timestamp: DateTime.now().subtract(const Duration(hours: 2)),
          isFromArtist: false,
        ),
        ChatMessage(
          id: 'm2',
          senderId: 'artist_1',
          senderName: 'OddMaree',
          text: 'Awesome! I got the deposit confirmation. The design will fit nicely on your forearm.',
          timestamp: DateTime.now().subtract(const Duration(hours: 1)),
          isFromArtist: true,
        ),
        ChatMessage(
          id: 'm3',
          senderId: 'artist_1',
          senderName: 'OddMaree',
          text: 'Looking forward to our session! Make sure to stay hydrated beforehand.',
          timestamp: DateTime.now().subtract(const Duration(minutes: 18)),
          isFromArtist: true,
        ),
      ],
    ),
    MessageThread(
      id: 'thread_2',
      artistId: 'artist_2',
      artistName: 'Maree Raven',
      artistAvatar:
          'https://images.unsplash.com/photo-1517841905240-472988babdf9?auto=format&fit=crop&w=400&q=80',
      studioName: 'Void & Bloom Tattoo',
      lastMessage: 'Yes, silent appointment is noted on your booking sheet!',
      lastMessageTime: DateTime.now().subtract(const Duration(hours: 3)),
      unreadCount: 0,
      isOnline: false,
      flashTitleContext: 'Lunar Moth & Geometry',
      messages: [
        ChatMessage(
          id: 'm4',
          senderId: 'client_user',
          senderName: 'You',
          text: 'Hello Maree, I requested a silent session for November 2nd, just checking if that came through.',
          timestamp: DateTime.now().subtract(const Duration(hours: 4)),
          isFromArtist: false,
        ),
        ChatMessage(
          id: 'm5',
          senderId: 'artist_2',
          senderName: 'Maree Raven',
          text: 'Yes, silent appointment is noted on your booking sheet!',
          timestamp: DateTime.now().subtract(const Duration(hours: 3)),
          isFromArtist: true,
        ),
      ],
    ),
    MessageThread(
      id: 'thread_3',
      artistId: 'artist_3',
      artistName: 'Kora Sol',
      artistAvatar:
          'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=400&q=80',
      studioName: 'Velvet Needle Parlor',
      lastMessage: 'How is the healed piece looking? Remember to keep applying unscented moisturizer.',
      lastMessageTime: DateTime.now().subtract(const Duration(days: 2)),
      unreadCount: 0,
      isOnline: true,
      flashTitleContext: 'Chrysanthemum Silhouette',
      messages: [
        ChatMessage(
          id: 'm6',
          senderId: 'artist_3',
          senderName: 'Kora Sol',
          text: 'How is the healed piece looking? Remember to keep applying unscented moisturizer.',
          timestamp: DateTime.now().subtract(const Duration(days: 2)),
          isFromArtist: true,
        ),
      ],
    ),
  ];
}
