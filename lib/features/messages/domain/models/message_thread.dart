import 'package:flutter/foundation.dart';
import '../../../../core/mock/mock_data_config.dart';
import '../../../../core/mock/mock_fixtures.dart';
import '../../../../models/artist_dashboard/schedule_slot_entry.dart';

enum ChatMessageType { text, receipt, image, file, proposal }

/// A single proposed date and time slot offered by an artist for a custom request.
class ProposedTimeOption {
  final DateTime date;
  final String timeSlot;
  final int startMinutes;
  final int durationMinutes;

  ProposedTimeOption({
    required this.date,
    String? timeSlot,
    int? startMinutes,
    this.durationMinutes = 120,
  })  : startMinutes = startMinutes ??
            ScheduleSlotEntry.parseTimeLabelToMinutes(timeSlot ?? '') ??
            0,
        timeSlot = (timeSlot != null && timeSlot.trim().isNotEmpty)
            ? timeSlot.trim()
            : ScheduleSlotEntry.formatMinutesToTimeLabel(startMinutes ?? 0);

  String get uniqueKey =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}__$startMinutes';

  ProposedTimeOption copyWith({
    DateTime? date,
    String? timeSlot,
    int? startMinutes,
    int? durationMinutes,
  }) {
    return ProposedTimeOption(
      date: date ?? this.date,
      timeSlot: timeSlot ?? this.timeSlot,
      startMinutes: startMinutes ?? this.startMinutes,
      durationMinutes: durationMinutes ?? this.durationMinutes,
    );
  }

  Map<String, dynamic> toMap() => {
        'date': DateTime(date.year, date.month, date.day).toIso8601String(),
        'timeSlot': timeSlot,
        'startMinutes': startMinutes,
        'durationMinutes': durationMinutes,
      };

  factory ProposedTimeOption.fromMap(Map<String, dynamic> map) {
    final parsedDate = map['date'] is String
        ? DateTime.tryParse(map['date'] as String) ?? DateTime.now()
        : DateTime.now();
    final rawTime = (map['timeSlot'] ?? map['time'] ?? '').toString();
    final parsedStart = (map['startMinutes'] as num?)?.toInt() ??
        ScheduleSlotEntry.parseTimeLabelToMinutes(rawTime) ??
        0;
    final parsedDuration = (map['durationMinutes'] as num?)?.toInt() ?? 120;
    return ProposedTimeOption(
      date: DateTime(parsedDate.year, parsedDate.month, parsedDate.day),
      timeSlot: rawTime.isNotEmpty
          ? rawTime
          : ScheduleSlotEntry.formatMinutesToTimeLabel(parsedStart),
      startMinutes: parsedStart,
      durationMinutes: parsedDuration,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProposedTimeOption && uniqueKey == other.uniqueKey;

  @override
  int get hashCode => uniqueKey.hashCode;
}

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
  final String? appointmentTimeSlot;
  final int? appointmentDurationMinutes;
  final String? artistName;
  final String? studioLocation;
  final String? flashTitle;
  final String? placement;
  final String? flashImageUrl;
  final String? attachmentUrl;
  final String? attachmentName;
  final String? attachmentMimeType;
  final int? attachmentSizeBytes;
  final String? requestId;
  final List<ProposedTimeOption> proposedSlots;
  final int? estimatedTotalPrice;
  final int? selectedProposalIndex;

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
    this.appointmentTimeSlot,
    this.appointmentDurationMinutes,
    this.artistName,
    this.studioLocation,
    this.flashTitle,
    this.placement,
    this.flashImageUrl,
    this.attachmentUrl,
    this.attachmentName,
    this.attachmentMimeType,
    this.attachmentSizeBytes,
    this.requestId,
    this.proposedSlots = const [],
    this.estimatedTotalPrice,
    this.selectedProposalIndex,
  });

  ChatMessage copyWith({
    String? id,
    String? senderId,
    String? senderName,
    String? text,
    DateTime? timestamp,
    bool? isFromArtist,
    ChatMessageType? type,
    double? receiptAmount,
    DateTime? appointmentDate,
    String? appointmentTimeSlot,
    int? appointmentDurationMinutes,
    String? artistName,
    String? studioLocation,
    String? flashTitle,
    String? placement,
    String? flashImageUrl,
    String? attachmentUrl,
    String? attachmentName,
    String? attachmentMimeType,
    int? attachmentSizeBytes,
    String? requestId,
    List<ProposedTimeOption>? proposedSlots,
    int? estimatedTotalPrice,
    int? selectedProposalIndex,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      isFromArtist: isFromArtist ?? this.isFromArtist,
      type: type ?? this.type,
      receiptAmount: receiptAmount ?? this.receiptAmount,
      appointmentDate: appointmentDate ?? this.appointmentDate,
      appointmentTimeSlot: appointmentTimeSlot ?? this.appointmentTimeSlot,
      appointmentDurationMinutes:
          appointmentDurationMinutes ?? this.appointmentDurationMinutes,
      artistName: artistName ?? this.artistName,
      studioLocation: studioLocation ?? this.studioLocation,
      flashTitle: flashTitle ?? this.flashTitle,
      placement: placement ?? this.placement,
      flashImageUrl: flashImageUrl ?? this.flashImageUrl,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      attachmentName: attachmentName ?? this.attachmentName,
      attachmentMimeType: attachmentMimeType ?? this.attachmentMimeType,
      attachmentSizeBytes: attachmentSizeBytes ?? this.attachmentSizeBytes,
      requestId: requestId ?? this.requestId,
      proposedSlots: proposedSlots ?? this.proposedSlots,
      estimatedTotalPrice: estimatedTotalPrice ?? this.estimatedTotalPrice,
      selectedProposalIndex:
          selectedProposalIndex ?? this.selectedProposalIndex,
    );
  }

  /// Summary text used for inbox thread previews when [text] is empty on attachments.
  String get previewText {
    final trimmed = text.trim();
    if (trimmed.isNotEmpty) return trimmed;
    return switch (type) {
      ChatMessageType.image => '📷 Photo',
      ChatMessageType.file => '📎 ${attachmentName ?? 'Attachment'}',
      ChatMessageType.receipt => 'Booking Receipt',
      ChatMessageType.proposal => 'Proposed Session Times',
      ChatMessageType.text => text,
    };
  }

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
      if (appointmentTimeSlot != null) 'appointmentTimeSlot': appointmentTimeSlot,
      if (appointmentDurationMinutes != null)
        'appointmentDurationMinutes': appointmentDurationMinutes,
      if (artistName != null) 'artistName': artistName,
      if (studioLocation != null) 'studioLocation': studioLocation,
      if (flashTitle != null) 'flashTitle': flashTitle,
      if (placement != null) 'placement': placement,
      if (flashImageUrl != null) 'flashImageUrl': flashImageUrl,
      if (attachmentUrl != null) 'attachmentUrl': attachmentUrl,
      if (attachmentName != null) 'attachmentName': attachmentName,
      if (attachmentMimeType != null) 'attachmentMimeType': attachmentMimeType,
      if (attachmentSizeBytes != null) 'attachmentSizeBytes': attachmentSizeBytes,
      if (requestId != null) 'requestId': requestId,
      if (proposedSlots.isNotEmpty)
        'proposedSlots': proposedSlots.map((s) => s.toMap()).toList(),
      if (estimatedTotalPrice != null)
        'estimatedTotalPrice': estimatedTotalPrice,
      if (selectedProposalIndex != null)
        'selectedProposalIndex': selectedProposalIndex,
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map, [String? docId]) {
    final rawType = map['type']?.toString() ?? 'text';
    final parsedType = switch (rawType) {
      'receipt' => ChatMessageType.receipt,
      'image' => ChatMessageType.image,
      'file' => ChatMessageType.file,
      'proposal' => ChatMessageType.proposal,
      _ => ChatMessageType.text,
    };
    final rawProposed = map['proposedSlots'];
    final parsedProposed = rawProposed is List
        ? rawProposed
            .whereType<Map>()
            .map((m) => ProposedTimeOption.fromMap(Map<String, dynamic>.from(m)))
            .where((o) => o.timeSlot.isNotEmpty)
            .toList()
        : const <ProposedTimeOption>[];
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
      appointmentTimeSlot: map['appointmentTimeSlot']?.toString(),
      appointmentDurationMinutes:
          (map['appointmentDurationMinutes'] as num?)?.toInt(),
      artistName: map['artistName']?.toString(),
      studioLocation: map['studioLocation']?.toString(),
      flashTitle: map['flashTitle']?.toString(),
      placement: map['placement']?.toString(),
      flashImageUrl: map['flashImageUrl']?.toString(),
      attachmentUrl: map['attachmentUrl']?.toString(),
      attachmentName: map['attachmentName']?.toString(),
      attachmentMimeType: map['attachmentMimeType']?.toString(),
      attachmentSizeBytes: (map['attachmentSizeBytes'] as num?)?.toInt(),
      requestId: map['requestId']?.toString(),
      proposedSlots: parsedProposed,
      estimatedTotalPrice: (map['estimatedTotalPrice'] as num?)?.toInt(),
      selectedProposalIndex: (map['selectedProposalIndex'] as num?)?.toInt(),
    );
  }
}

/// Message thread representation for the Messages inbox.
class MessageThread {
  final String id;
  final String artistId;
  final String? clientId;
  final String? clientName;
  final String clientAvatar;
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
    this.clientAvatar = '',
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
    String? clientAvatar,
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
      clientAvatar: clientAvatar ?? this.clientAvatar,
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
      if (clientAvatar.isNotEmpty) 'clientAvatar': clientAvatar,
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
      clientAvatar: (map['clientAvatar'] ??
              map['clientPhotoUrl'] ??
              map['clientPhotoURL'] ??
              '')
          .toString(),
      artistName: map['artistName']?.toString() ?? 'Artist',
      artistAvatar: (map['artistAvatar'] ??
              map['artistPhotoUrl'] ??
              map['artistPhotoURL'] ??
              '')
          .toString(),
      studioName: map['studioName']?.toString() ?? '',
      lastMessage: _normalizeLastMessage(map['lastMessage']?.toString() ?? ''),
      lastMessageTime: map['lastMessageTime'] is String
          ? DateTime.tryParse(map['lastMessageTime'] as String) ?? DateTime.now()
          : DateTime.now(),
      unreadCount: (map['unreadCount'] as num?)?.toInt() ?? 0,
      isOnline: map['isOnline'] == true,
      flashTitleContext: map['flashTitleContext']?.toString(),
      messages: parsedMsgs,
    );
  }

  /// Replaces legacy image filename previews (e.g. `📷 image_picker_...jpg`)
  /// with a clean `📷 Photo` label.
  static String _normalizeLastMessage(String raw) {
    const prefix = '📷 ';
    if (!raw.startsWith(prefix)) return raw;
    final label = raw.substring(prefix.length).trim();
    if (label.isEmpty || label == 'Photo') return '📷 Photo';
    final looksLikeFileName = label.startsWith('image_picker_') ||
        RegExp(r'\.(jpe?g|png|webp|heic|heif|gif)$', caseSensitive: false)
            .hasMatch(label);
    return looksLikeFileName ? '📷 Photo' : raw;
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
