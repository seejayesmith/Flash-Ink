import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../services/booking_sync_service.dart';
import '../../../../theme/app_radius.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_theme.dart';
import '../../domain/models/message_thread.dart';
import '../widgets/booking_receipt_message_tile.dart';

/// Interactive conversation screen for chatting directly between a client and a tattoo artist.
class ChatConversationScreen extends StatefulWidget {
  final MessageThread thread;
  final bool isArtistView;

  const ChatConversationScreen({
    super.key,
    required this.thread,
    this.isArtistView = false,
  });

  @override
  State<ChatConversationScreen> createState() => _ChatConversationScreenState();
}

class _ChatConversationScreenState extends State<ChatConversationScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  late List<ChatMessage> _messages;

  @override
  void initState() {
    super.initState();
    _messages = List.from(widget.thread.messages);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      MessageThread.markThreadAsRead(widget.thread.id);
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final senderId = BookingSyncService.resolveCurrentUid(
      widget.isArtistView ? widget.thread.artistId : 'client_user',
    );
    final newMessage = ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      senderId: senderId,
      senderName: widget.isArtistView ? widget.thread.artistName : 'You',
      text: text,
      timestamp: DateTime.now(),
      isFromArtist: widget.isArtistView,
    );

    setState(() {
      _messages.add(newMessage);
    });
    BookingSyncService.appendAndSyncChatMessage(
      threadId: widget.thread.id,
      message: newMessage,
    );

    _textController.clear();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final headerTitle = widget.isArtistView
        ? (widget.thread.clientName?.isNotEmpty == true
            ? widget.thread.clientName!
            : 'Client Inquiry')
        : widget.thread.artistName;
    final headerSubtitle = widget.isArtistView
        ? (widget.thread.flashTitleContext ?? 'Direct Consultation')
        : (widget.thread.isOnline ? 'Online now' : widget.thread.studioName);

    return Scaffold(
      backgroundColor: AppTheme.onyxBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.onyxSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.goldBorder, width: 1.5),
              ),
              child: ClipOval(
                child: widget.thread.artistAvatar.isNotEmpty
                    ? Image.network(
                        widget.thread.artistAvatar,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: AppTheme.onyxContainer,
                          child: const Icon(Icons.person, color: AppTheme.gold, size: 20),
                        ),
                      )
                    : Container(
                        color: AppTheme.onyxContainer,
                        child: const Icon(Icons.person, color: AppTheme.gold, size: 20),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    headerTitle,
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    headerSubtitle,
                    style: GoogleFonts.plusJakartaSans(
                      color: !widget.isArtistView && widget.thread.isOnline
                          ? const Color(0xFF4ADE80)
                          : AppTheme.navInactive,
                      fontSize: 11,
                      fontWeight: !widget.isArtistView && widget.thread.isOnline
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Context Banner (Flash piece or booking)
            if (widget.thread.flashTitleContext != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenGutter, vertical: 8),
                decoration: const BoxDecoration(
                  color: AppTheme.onyxContainer,
                  border: Border(
                    bottom: BorderSide(color: AppTheme.darkBorder),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.palette_outlined, color: AppTheme.gold, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Regarding: ',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.navInactive,
                        fontSize: 12,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        widget.thread.flashTitleContext!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.gold,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Messages List
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenGutter, vertical: 12),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  if (msg.type == ChatMessageType.receipt) {
                    return BookingReceiptMessageTile(message: msg);
                  }

                  final isClient = !msg.isFromArtist;

                  return Align(
                    alignment: isClient ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.78,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isClient
                            ? const Color(0xFF2C2818)
                            : AppTheme.cardBackground,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(16),
                          topRight: const Radius.circular(16),
                          bottomLeft: Radius.circular(isClient ? 16 : 4),
                          bottomRight: Radius.circular(isClient ? 4 : 16),
                        ),
                        border: Border.all(
                          color: isClient ? AppTheme.goldBorder : AppTheme.cardBorder,
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment:
                            isClient ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        children: [
                          Text(
                            msg.text,
                            style: GoogleFonts.plusJakartaSans(
                              color: AppTheme.textPrimary,
                              fontSize: 13,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatTime(msg.timestamp),
                            style: GoogleFonts.plusJakartaSans(
                              color: isClient ? AppTheme.gold : AppTheme.navInactive,
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Message Input Bar
            Container(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.screenGutter,
                8,
                AppSpacing.screenGutter,
                MediaQuery.paddingOf(context).bottom + 8,
              ),
              decoration: const BoxDecoration(
                color: AppTheme.onyxSurface,
                border: Border(
                  top: BorderSide(color: AppTheme.darkBorder),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppTheme.cardBackground,
                        borderRadius: BorderRadius.circular(AppRadius.radiusFull),
                        border: Border.all(color: AppTheme.cardBorder),
                      ),
                      child: TextField(
                        controller: _textController,
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.textPrimary,
                          fontSize: 13,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Type a message to ${widget.thread.artistName}...',
                          hintStyle: GoogleFonts.plusJakartaSans(
                            color: AppTheme.navInactive,
                            fontSize: 12,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 42,
                    height: 42,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.gold,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send, color: AppTheme.onyxBackground, size: 18),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
