import 'package:flutter/foundation.dart';
import '../../../../core/mock/mock_data_config.dart';
import '../../../../core/mock/mock_fixtures.dart';
import '../../../../models/artist_dashboard/schedule_slot_entry.dart';

DateTime? _parseOptionalDateTime(dynamic raw) {
  if (raw == null) return null;
  if (raw is DateTime) return raw;
  if (raw is String) return DateTime.tryParse(raw);
  if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
  try {
    final dynamic converted = (raw as dynamic).toDate();
    if (converted is DateTime) return converted;
  } catch (_) {}
  return null;
}

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
      timestamp: _parseOptionalDateTime(map['timestamp']) ?? DateTime.now(),
      isFromArtist: map['isFromArtist'] == true,
      type: parsedType,
      receiptAmount: (map['receiptAmount'] as num?)?.toDouble(),
      appointmentDate: _parseOptionalDateTime(map['appointmentDate']),
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
  final int clientUnreadCount;
  final int artistUnreadCount;
  final DateTime? clientLastReadAt;
  final DateTime? artistLastReadAt;
  final String? mergedInto;
  final List<String> mergedLegacyIds;
  final bool isOnline;
  final String? flashTitleContext;
  final List<ChatMessage> messages;

  /// Backward-compatible getter returning the client-side unread count.
  int get unreadCount => clientUnreadCount;

  /// Backward-compatible getter returning whether the client has unread messages.
  bool get hasUnread => clientUnreadCount > 0;

  /// Returns the unread count for either Artist Mode or Client Mode.
  int unreadCountFor({required bool isArtistView}) =>
      isArtistView ? artistUnreadCount : clientUnreadCount;

  /// Returns whether the viewer has unread messages for their active role.
  bool hasUnreadFor({required bool isArtistView}) =>
      unreadCountFor(isArtistView: isArtistView) > 0;

  /// Returns the last read timestamp for either Artist Mode or Client Mode.
  DateTime? lastReadAtFor({required bool isArtistView}) =>
      isArtistView ? artistLastReadAt : clientLastReadAt;

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
    int unreadCount = 0,
    int? clientUnreadCount,
    int? artistUnreadCount,
    this.clientLastReadAt,
    this.artistLastReadAt,
    this.mergedInto,
    this.mergedLegacyIds = const [],
    this.isOnline = false,
    this.flashTitleContext,
    this.messages = const [],
  })  : clientUnreadCount = clientUnreadCount ?? unreadCount,
        artistUnreadCount = artistUnreadCount ?? unreadCount;

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
    int? clientUnreadCount,
    int? artistUnreadCount,
    DateTime? clientLastReadAt,
    DateTime? artistLastReadAt,
    String? mergedInto,
    List<String>? mergedLegacyIds,
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
      clientUnreadCount:
          clientUnreadCount ?? unreadCount ?? this.clientUnreadCount,
      artistUnreadCount:
          artistUnreadCount ?? unreadCount ?? this.artistUnreadCount,
      clientLastReadAt: clientLastReadAt ?? this.clientLastReadAt,
      artistLastReadAt: artistLastReadAt ?? this.artistLastReadAt,
      mergedInto: mergedInto ?? this.mergedInto,
      mergedLegacyIds: mergedLegacyIds ?? this.mergedLegacyIds,
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
      'unreadCount': clientUnreadCount,
      'clientUnreadCount': clientUnreadCount,
      'artistUnreadCount': artistUnreadCount,
      if (clientLastReadAt != null)
        'clientLastReadAt': clientLastReadAt!.toIso8601String(),
      if (artistLastReadAt != null)
        'artistLastReadAt': artistLastReadAt!.toIso8601String(),
      if (mergedInto != null && mergedInto!.isNotEmpty)
        'mergedInto': mergedInto,
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
    parsedMsgs.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final hasClientUnread = map.containsKey('clientUnreadCount');
    final hasArtistUnread = map.containsKey('artistUnreadCount');
    final legacyUnread = ((map['unreadCount'] as num?)?.toInt() ?? 0).clamp(0, 9999);

    int resolvedClientUnread;
    int resolvedArtistUnread;
    if (hasClientUnread || hasArtistUnread) {
      resolvedClientUnread =
          ((map['clientUnreadCount'] as num?)?.toInt() ?? 0).clamp(0, 9999);
      resolvedArtistUnread =
          ((map['artistUnreadCount'] as num?)?.toInt() ?? 0).clamp(0, 9999);
    } else if (legacyUnread > 0 && parsedMsgs.isNotEmpty) {
      final latestMsg = parsedMsgs.last;
      if (latestMsg.isFromArtist) {
        resolvedClientUnread = legacyUnread;
        resolvedArtistUnread = 0;
      } else {
        resolvedClientUnread = 0;
        resolvedArtistUnread = legacyUnread;
      }
    } else {
      resolvedClientUnread = legacyUnread;
      resolvedArtistUnread = legacyUnread;
    }

    final parsedClientReadAt = _parseOptionalDateTime(map['clientLastReadAt']);
    final parsedArtistReadAt = _parseOptionalDateTime(map['artistLastReadAt']);
    final rawMergedInto = map['mergedInto']?.toString().trim();

    return MessageThread(
      id: (docId != null && docId.isNotEmpty)
          ? docId
          : (map['id']?.toString() ??
              'thread_${DateTime.now().millisecondsSinceEpoch}'),
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
      lastMessageTime: _parseOptionalDateTime(map['lastMessageTime']) ??
          (parsedMsgs.isNotEmpty ? parsedMsgs.last.timestamp : DateTime.now()),
      clientUnreadCount: resolvedClientUnread,
      artistUnreadCount: resolvedArtistUnread,
      clientLastReadAt: parsedClientReadAt,
      artistLastReadAt: parsedArtistReadAt,
      mergedInto: (rawMergedInto != null && rawMergedInto.isNotEmpty)
          ? rawMergedInto
          : null,
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

  static String _sanitizeIdSegment(String raw) {
    return raw.trim().replaceAll(RegExp(r'[/\s]+'), '_');
  }

  static bool _isValidParticipantId(String? raw, String placeholder) {
    final clean = (raw ?? '').trim();
    return clean.isNotEmpty && clean != placeholder;
  }

  /// Returns whether both [clientId] and [artistId] are real IDs suitable for a
  /// canonical `dm_<clientId>_<artistId>` document key.
  static bool hasCanonicalParticipants({String? clientId, String? artistId}) {
    return _isValidParticipantId(clientId, 'client_unknown') &&
        _isValidParticipantId(artistId, 'artist_unknown');
  }

  /// Returns `true` when [threadId] already uses the canonical `dm_` format.
  static bool isCanonicalThreadId(String threadId) {
    return threadId.trim().startsWith('dm_');
  }

  /// Deterministic canonical chat document ID for a `(clientId, artistId)` pair.
  ///
  /// Role-directional (`dm_<clientId>_<artistId>`) so dual-role users who book
  /// each other maintain independent Client Mode and Artist Mode timelines.
  static String canonicalThreadId({
    required String clientId,
    required String artistId,
  }) {
    final c = _sanitizeIdSegment(clientId);
    final a = _sanitizeIdSegment(artistId);
    if (c.isEmpty || a.isEmpty) {
      return 'thread_${DateTime.now().millisecondsSinceEpoch}';
    }
    return 'dm_${c}_$a';
  }

  /// Resolves the best deterministic thread ID for a pair, falling back cleanly
  /// when mock/offline fixtures omit a `clientId`.
  static String resolveCanonicalThreadId({
    String? clientId,
    required String artistId,
    String? clientName,
    String? fallbackId,
  }) {
    if (hasCanonicalParticipants(clientId: clientId, artistId: artistId)) {
      return canonicalThreadId(clientId: clientId!, artistId: artistId);
    }
    final cleanArtist = _sanitizeIdSegment(artistId);
    final cleanName = (clientName ?? '')
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    if (cleanArtist.isNotEmpty && cleanName.isNotEmpty) {
      return 'dm_guest_${cleanName}_$cleanArtist';
    }
    if (fallbackId != null && fallbackId.trim().isNotEmpty) {
      return fallbackId.trim();
    }
    return 'thread_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Merges two chronologically ordered message lists without duplicating IDs.
  static List<ChatMessage> mergeMessages(
    List<ChatMessage> existing,
    List<ChatMessage> incoming,
  ) {
    final byId = <String, ChatMessage>{
      for (final m in existing) m.id: m,
      for (final m in incoming) m.id: m,
    };
    final merged = byId.values.toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return merged;
  }

  static List<MessageThread> _sortedByRecent(Iterable<MessageThread> threads) {
    final list = threads.toList()
      ..sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
    return list;
  }

  /// Notifier triggered whenever thread read states, messages, or unread counts change.
  static final ValueNotifier<int> unreadUpdateNotifier = ValueNotifier<int>(0);

  /// Quarantined mock threads preserved in [MockFixtures].
  static List<MessageThread> mockThreads = MockFixtures.createMessageThreads();

  /// Live session threads populated during an active authenticated session.
  static final List<MessageThread> liveThreads = [];

  /// Tracks the thread currently open in [ChatConversationScreen], if any, so
  /// live listeners can automatically clear incoming unread counts.
  static String? activeOpenThreadId;
  static bool activeOpenThreadIsArtistView = false;

  /// Active message threads for the current runtime mode.
  static List<MessageThread> get activeThreads =>
      MockDataConfig.isEnabled ? mockThreads : liveThreads;

  /// Threads visible in Client Mode for [clientUid], sorted newest-first.
  static List<MessageThread> threadsForClient(String? clientUid) {
    final threads = activeThreads;
    if (MockDataConfig.isEnabled) return _sortedByRecent(threads);
    final cleanUid = (clientUid ?? '').trim();
    if (cleanUid.isEmpty) return _sortedByRecent(threads);
    return _sortedByRecent(
      threads.where((t) {
        final cid = (t.clientId ?? '').trim();
        if (cid.isNotEmpty) return cid == cleanUid;
        return t.artistId.trim() != cleanUid;
      }),
    );
  }

  /// Threads visible in Artist Mode for [artistUid], sorted newest-first.
  static List<MessageThread> threadsForArtist(String? artistUid) {
    final threads = activeThreads;
    if (MockDataConfig.isEnabled) return _sortedByRecent(threads);
    final cleanUid = (artistUid ?? '').trim();
    if (cleanUid.isEmpty) return _sortedByRecent(threads);
    return _sortedByRecent(
      threads.where((t) => t.artistId.trim() == cleanUid),
    );
  }

  /// Total unread messages for Client Mode (filtered by [clientUid] in live mode).
  static int totalUnreadCountForClient([String? clientUid]) {
    return threadsForClient(clientUid)
        .fold<int>(0, (sum, t) => sum + t.clientUnreadCount);
  }

  /// Total unread messages for Artist Mode (filtered by [artistUid]).
  static int totalUnreadCountForArtist([String? artistUid]) {
    final cleanUid = (artistUid ?? '').trim();
    final Iterable<MessageThread> relevant;
    if (MockDataConfig.isEnabled) {
      relevant = cleanUid.isNotEmpty
          ? activeThreads.where((t) => t.artistId.trim() == cleanUid)
          : activeThreads;
    } else {
      relevant = threadsForArtist(cleanUid);
    }
    return relevant.fold<int>(0, (sum, t) => sum + t.artistUnreadCount);
  }

  /// Total unread messages across active threads.
  ///
  /// When [artistId] is provided, sums artist-side unread counts for that artist;
  /// otherwise sums client-side unread counts.
  static int totalUnreadCount([String? artistId]) {
    if (artistId != null && artistId.trim().isNotEmpty) {
      return totalUnreadCountForArtist(artistId);
    }
    return totalUnreadCountForClient();
  }

  /// Finds an existing active thread matching [threadId] or the `(clientId, artistId)` pair.
  static MessageThread? findExistingThread({
    String? threadId,
    String? clientId,
    String? artistId,
    String? clientName,
  }) {
    final threads = activeThreads;
    final cleanThreadId = (threadId ?? '').trim();
    if (cleanThreadId.isNotEmpty) {
      for (final t in threads) {
        if (t.id == cleanThreadId || t.mergedLegacyIds.contains(cleanThreadId)) {
          return t;
        }
      }
    }
    if (hasCanonicalParticipants(clientId: clientId, artistId: artistId)) {
      final canonical = canonicalThreadId(
        clientId: clientId!,
        artistId: artistId!,
      );
      for (final t in threads) {
        if (t.id == canonical ||
            (t.artistId.trim() == artistId.trim() &&
                (t.clientId ?? '').trim() == clientId.trim())) {
          return t;
        }
      }
    }
    final cleanArtist = (artistId ?? '').trim();
    final lowerClient = (clientName ?? '').trim().toLowerCase();
    if (cleanArtist.isNotEmpty && lowerClient.isNotEmpty) {
      for (final t in threads) {
        if (t.artistId.trim() == cleanArtist &&
            (t.clientName ?? '').trim().toLowerCase() == lowerClient) {
          return t;
        }
      }
    }
    return null;
  }

  /// Marks a specific conversation thread as read locally for the viewer's role.
  static bool markThreadAsRead(
    String threadId, {
    bool isArtistView = false,
    DateTime? readAt,
  }) {
    final now = readAt ?? DateTime.now();
    bool updated = false;

    bool applyToList(List<MessageThread> list) {
      final idx = list.indexWhere(
        (t) => t.id == threadId || t.mergedLegacyIds.contains(threadId),
      );
      if (idx == -1) return false;
      final current = list[idx];
      final currentUnread = current.unreadCountFor(isArtistView: isArtistView);
      final currentReadAt = current.lastReadAtFor(isArtistView: isArtistView);
      if (currentUnread == 0 &&
          currentReadAt != null &&
          !now.isAfter(currentReadAt)) {
        return false;
      }
      list[idx] = isArtistView
          ? current.copyWith(artistUnreadCount: 0, artistLastReadAt: now)
          : current.copyWith(clientUnreadCount: 0, clientLastReadAt: now);
      return true;
    }

    if (applyToList(mockThreads)) updated = true;
    if (applyToList(liveThreads)) updated = true;

    if (updated) {
      unreadUpdateNotifier.value++;
    }
    return updated;
  }

  /// Inserts or merges [thread] into the active session list without creating duplicates.
  static MessageThread upsertThread(MessageThread thread) {
    final targetList = MockDataConfig.isEnabled ? mockThreads : liveThreads;
    final cleanArtist = thread.artistId.trim();
    final cleanClient = (thread.clientId ?? '').trim();

    final existingIndex = targetList.indexWhere((t) {
      if (t.id == thread.id || t.mergedLegacyIds.contains(thread.id)) {
        return true;
      }
      if (hasCanonicalParticipants(clientId: cleanClient, artistId: cleanArtist)) {
        return t.artistId.trim() == cleanArtist &&
            (t.clientId ?? '').trim() == cleanClient;
      }
      return false;
    });

    late final MessageThread resolved;
    if (existingIndex != -1) {
      final existing = targetList.removeAt(existingIndex);
      final mergedMsgs = mergeMessages(existing.messages, thread.messages);
      final newestTime = thread.lastMessageTime.isAfter(existing.lastMessageTime)
          ? thread.lastMessageTime
          : existing.lastMessageTime;
      final newestPreview =
          thread.lastMessageTime.isAfter(existing.lastMessageTime) ||
                  existing.lastMessage.trim().isEmpty
              ? thread.lastMessage
              : existing.lastMessage;
      final canonicalId =
          hasCanonicalParticipants(clientId: cleanClient, artistId: cleanArtist)
              ? canonicalThreadId(clientId: cleanClient, artistId: cleanArtist)
              : (isCanonicalThreadId(thread.id) ? thread.id : existing.id);
      final legacyIds = <String>{
        ...existing.mergedLegacyIds,
        ...thread.mergedLegacyIds,
        if (existing.id != canonicalId) existing.id,
        if (thread.id != canonicalId) thread.id,
      }.toList(growable: false);

      resolved = existing.copyWith(
        id: canonicalId,
        clientId: cleanClient.isNotEmpty ? cleanClient : existing.clientId,
        clientName: (thread.clientName?.trim().isNotEmpty == true)
            ? thread.clientName
            : existing.clientName,
        clientAvatar: thread.clientAvatar.trim().isNotEmpty
            ? thread.clientAvatar
            : existing.clientAvatar,
        artistName: thread.artistName.trim().isNotEmpty
            ? thread.artistName
            : existing.artistName,
        artistAvatar: thread.artistAvatar.trim().isNotEmpty
            ? thread.artistAvatar
            : existing.artistAvatar,
        studioName: thread.studioName.trim().isNotEmpty
            ? thread.studioName
            : existing.studioName,
        lastMessage: newestPreview,
        lastMessageTime: newestTime,
        clientUnreadCount: thread.clientUnreadCount,
        artistUnreadCount: thread.artistUnreadCount,
        clientLastReadAt: thread.clientLastReadAt ?? existing.clientLastReadAt,
        artistLastReadAt: thread.artistLastReadAt ?? existing.artistLastReadAt,
        flashTitleContext: thread.flashTitleContext ?? existing.flashTitleContext,
        mergedLegacyIds: legacyIds,
        messages: mergedMsgs,
      );
    } else {
      resolved = thread;
    }

    targetList.insert(0, resolved);
    unreadUpdateNotifier.value++;
    return resolved;
  }

  /// Prepends or merges a thread into the active session list (or mock list when sandboxed).
  static void addThread(MessageThread thread) {
    upsertThread(thread);
  }

  /// Clears session-scoped message threads upon sign-out.
  static void clearSessionThreads() {
    liveThreads.clear();
    activeOpenThreadId = null;
    activeOpenThreadIsArtistView = false;
    unreadUpdateNotifier.value++;
  }

  /// Resets mock threads to initial fixture data (useful for test isolation).
  static void resetMockThreads() {
    mockThreads = MockFixtures.createMessageThreads();
    activeOpenThreadId = null;
    activeOpenThreadIsArtistView = false;
    unreadUpdateNotifier.value++;
  }
}
