import 'package:flash_ink/core/mock/mock_data_config.dart';
import 'package:flash_ink/features/messages/domain/models/message_thread.dart';
import 'package:flash_ink/features/messages/presentation/screens/chat_conversation_screen.dart';
import 'package:flash_ink/models/artist_dashboard_data.dart';
import 'package:flash_ink/services/booking_sync_service.dart';
import 'package:flash_ink/services/chat_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChatMessage attachment serialization', () {
    test('round-trips image message via toMap and fromMap', () {
      final timestamp = DateTime(2026, 11, 14, 15, 30);
      final original = ChatMessage(
        id: 'msg_img_1',
        senderId: 'user_1',
        senderName: 'You',
        text: 'Placement photo',
        timestamp: timestamp,
        isFromArtist: false,
        type: ChatMessageType.image,
        attachmentUrl: 'https://example.com/placement.jpg',
        attachmentName: 'placement.jpg',
        attachmentMimeType: 'image/jpeg',
        attachmentSizeBytes: 245760,
      );

      final map = original.toMap();
      final decoded = ChatMessage.fromMap(map);

      expect(decoded.type, ChatMessageType.image);
      expect(decoded.attachmentUrl, 'https://example.com/placement.jpg');
      expect(decoded.attachmentName, 'placement.jpg');
      expect(decoded.attachmentMimeType, 'image/jpeg');
      expect(decoded.attachmentSizeBytes, 245760);
      expect(decoded.text, 'Placement photo');
    });

    test('round-trips file message via toMap and fromMap', () {
      final timestamp = DateTime(2026, 11, 14, 15, 35);
      final original = ChatMessage(
        id: 'msg_file_1',
        senderId: 'artist_1',
        senderName: 'Elena',
        text: '',
        timestamp: timestamp,
        isFromArtist: true,
        type: ChatMessageType.file,
        attachmentUrl: 'https://example.com/consent.pdf',
        attachmentName: 'consent.pdf',
        attachmentMimeType: 'application/pdf',
        attachmentSizeBytes: 2048,
      );

      final decoded = ChatMessage.fromMap(original.toMap());

      expect(decoded.type, ChatMessageType.file);
      expect(decoded.attachmentUrl, 'https://example.com/consent.pdf');
      expect(decoded.attachmentName, 'consent.pdf');
      expect(decoded.attachmentMimeType, 'application/pdf');
      expect(decoded.attachmentSizeBytes, 2048);
    });
  });

  group('ChatService.inferMimeType', () {
    test('infers common image and document mime types', () {
      expect(ChatService.inferMimeType('photo.JPG'), 'image/jpeg');
      expect(ChatService.inferMimeType('sketch.png'), 'image/png');
      expect(ChatService.inferMimeType('waiver.pdf'), 'application/pdf');
      expect(
        ChatService.inferMimeType('brief.docx'),
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      );
      expect(ChatService.inferMimeType('archive.bin'), 'application/octet-stream');
    });
  });

  group('ChatConversationScreen attachments UI', () {
    testWidgets('shows attachment sheet options and renders file/image bubbles',
        (tester) async {
      final thread = MessageThread(
        id: 'thread_attach_test',
        artistId: 'artist_1',
        artistName: 'Elena Vance',
        artistAvatar: 'assets/images/artist_1.jpg',
        studioName: 'Blackwork Studio',
        lastMessage: 'Reference stencil',
        lastMessageTime: DateTime(2026, 11, 14, 15, 0),
        unreadCount: 0,
        messages: [
          ChatMessage(
            id: 'm_file',
            senderId: 'client_1',
            senderName: 'You',
            text: '',
            timestamp: DateTime(2026, 11, 14, 15, 1),
            isFromArtist: false,
            type: ChatMessageType.file,
            attachmentUrl: 'local://aftercare.pdf',
            attachmentName: 'aftercare.pdf',
            attachmentMimeType: 'application/pdf',
            attachmentSizeBytes: 2048,
          ),
          ChatMessage(
            id: 'm_img',
            senderId: 'artist_1',
            senderName: 'Elena Vance',
            text: 'Reference stencil',
            timestamp: DateTime(2026, 11, 14, 15, 2),
            isFromArtist: true,
            type: ChatMessageType.image,
            attachmentUrl: 'local://stencil.png',
            attachmentName: 'stencil.png',
            attachmentMimeType: 'image/png',
            attachmentSizeBytes: 1024,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChatConversationScreen(thread: thread),
        ),
      );
      await tester.pump();

      expect(find.text('aftercare.pdf'), findsOneWidget);
      expect(find.text('2.0 KB'), findsOneWidget);
      expect(find.text('Reference stencil'), findsOneWidget);

      await tester.tap(find.byKey(const Key('chat_attach_button')));
      await tester.pumpAndSettle();

      expect(find.text('Photo Library'), findsOneWidget);
      expect(find.text('Camera'), findsOneWidget);
      expect(find.text('Choose File (PDF, Docs)'), findsOneWidget);
    });
  });

  group('ChatMessage.previewText & BookingSyncService preview', () {
    test('generates previewText and updates thread lastMessage on append', () async {
      MockDataConfig.debugOverride = true;
      MessageThread.resetMockThreads();
      BookingSyncService.enableCloudWrites = false;

      final targetThread = MessageThread.activeThreads.first;
      final imgMsg = ChatMessage(
        id: 'm_preview_img',
        senderId: 'client_1',
        senderName: 'You',
        text: '',
        timestamp: DateTime(2026, 11, 14, 16, 0),
        isFromArtist: false,
        type: ChatMessageType.image,
        attachmentName: 'forearm_ref.jpg',
      );
      final fileWithCaption = ChatMessage(
        id: 'm_preview_file',
        senderId: 'client_1',
        senderName: 'You',
        text: 'Signed consent form',
        timestamp: DateTime(2026, 11, 14, 16, 1),
        isFromArtist: false,
        type: ChatMessageType.file,
        attachmentName: 'consent.pdf',
      );

      expect(imgMsg.previewText, '📷 forearm_ref.jpg');
      expect(fileWithCaption.previewText, 'Signed consent form');

      await BookingSyncService.appendAndSyncChatMessage(
        threadId: targetThread.id,
        message: imgMsg,
      );

      final updated =
          MessageThread.activeThreads.firstWhere((t) => t.id == targetThread.id);
      expect(updated.lastMessage, '📷 forearm_ref.jpg');
      expect(updated.messages.last.id, 'm_preview_img');

      MessageThread.resetMockThreads();
      BookingSyncService.enableCloudWrites = true;
      MockDataConfig.resetDebugOverride();
    });
  });

  group('BookingRequest.referenceImageUrls', () {
    test('round-trips multiple referenceImageUrls via toMap and fromMap', () {
      const request = BookingRequest(
        id: 'req_refs_1',
        clientName: 'Alex Rivers',
        timeAgo: 'Just now',
        conceptDescription: 'Botanical sleeve concept',
        sketchImageUrl: 'https://example.com/ref1.jpg',
        referenceImageUrls: [
          'https://example.com/ref1.jpg',
          'https://example.com/ref2.jpg',
          'https://example.com/ref3.jpg',
        ],
      );

      final decoded = BookingRequest.fromMap(request.toMap());
      expect(decoded.referenceImageUrls, [
        'https://example.com/ref1.jpg',
        'https://example.com/ref2.jpg',
        'https://example.com/ref3.jpg',
      ]);
      expect(decoded.sketchImageUrl, 'https://example.com/ref1.jpg');
    });
  });
}
