import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/mock/mock_data_config.dart';
import '../../../../services/booking_sync_service.dart';
import '../../../../services/chat_service.dart';
import '../../../../theme/app_radius.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/adaptive_glass_container.dart';
import '../../../../widgets/keyboard_collapse_button.dart';
import '../../../../widgets/user_avatar.dart';
import '../../domain/models/message_thread.dart';
import '../widgets/booking_receipt_message_tile.dart';
import '../widgets/proposal_options_message_tile.dart';

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
  final _messageFocusNode = FocusNode();
  final _scrollController = ScrollController();
  final _imagePicker = ImagePicker();
  late List<ChatMessage> _messages;
  late MessageThread _thread;
  final Map<String, Uint8List> _localAttachmentBytes = {};
  bool _isUploadingAttachment = false;
  bool _hasDraftText = false;

  @override
  void initState() {
    super.initState();
    _thread = widget.thread;
    _messages = List.from(widget.thread.messages);
    _messageFocusNode.addListener(_onFocusChange);
    _textController.addListener(_onTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      MessageThread.markThreadAsRead(widget.thread.id);
    });
    _backfillSenderAvatarIfNeeded();
  }

  @override
  void didUpdateWidget(covariant ChatConversationScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.thread != widget.thread ||
        oldWidget.isArtistView != widget.isArtistView) {
      _thread = widget.thread;
      _messages = List.from(widget.thread.messages);
      _backfillSenderAvatarIfNeeded();
    }
  }

  void _onFocusChange() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onTextChanged() {
    final hasText = _textController.text.trim().isNotEmpty;
    if (hasText != _hasDraftText && mounted) {
      setState(() => _hasDraftText = hasText);
    }
  }

  void _dismissKeyboard() {
    _messageFocusNode.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
    if (mounted) {
      FocusScope.of(context).unfocus();
    }
    SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  }

  Future<void> _backfillSenderAvatarIfNeeded() async {
    if (MockDataConfig.isEnabled) return;
    final needsClientAvatar =
        !widget.isArtistView && !UserAvatar.isValidUrl(_thread.clientAvatar);
    final needsArtistAvatar =
        widget.isArtistView && !UserAvatar.isValidUrl(_thread.artistAvatar);
    if (!needsClientAvatar && !needsArtistAvatar) return;

    final resolvedPhoto = await BookingSyncService.resolveCurrentUserPhotoUrl();
    if (resolvedPhoto.isEmpty || !mounted) return;

    final updated = needsClientAvatar
        ? _thread.copyWith(clientAvatar: resolvedPhoto)
        : _thread.copyWith(artistAvatar: resolvedPhoto);
    _updateActiveThread(updated);

    BookingSyncService.syncChatThreadToCloud(
      updated,
      clientId: updated.clientId,
      artistId: updated.artistId,
      clientName: updated.clientName,
      clientAvatar: updated.clientAvatar,
      artistAvatar: updated.artistAvatar,
    );
  }

  void _updateActiveThread(MessageThread updated) {
    final threads = MessageThread.activeThreads;
    final idx = threads.indexWhere((t) => t.id == updated.id);
    if (idx != -1) {
      threads[idx] = updated;
      MessageThread.unreadUpdateNotifier.value++;
    }
    if (mounted) {
      setState(() {
        _thread = updated;
      });
    }
  }

  @override
  void deactivate() {
    _messageFocusNode.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
    SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    super.deactivate();
  }

  @override
  void dispose() {
    _messageFocusNode.removeListener(_onFocusChange);
    _textController.removeListener(_onTextChanged);
    _messageFocusNode.unfocus();
    SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    _messageFocusNode.dispose();
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
    _dismissKeyboard();
    _scrollToBottom();
  }

  void _scrollToBottom() {
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

  Future<void> _showAttachmentOptions() async {
    _dismissKeyboard();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return AdaptiveGlassContainer.bottomSheet(
          glassEnabled: false,
          androidSurfaceColor: AppTheme.onyxSurface,
          topRadius: AppRadius.radiusSheet,
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: AppTheme.gold),
                title: Text(
                  'Photo Library',
                  style: GoogleFonts.plusJakartaSans(color: AppTheme.textPrimary),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: AppTheme.gold),
                title: Text(
                  'Camera',
                  style: GoogleFonts.plusJakartaSans(color: AppTheme.textPrimary),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.insert_drive_file_rounded, color: AppTheme.gold),
                title: Text(
                  'Choose File (PDF, Docs)',
                  style: GoogleFonts.plusJakartaSans(color: AppTheme.textPrimary),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickDocument();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 2048,
        imageQuality: 85,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      await _uploadAndSendAttachment(
        bytes: bytes,
        fileName: picked.name,
        isImage: true,
        mimeType: ChatService.inferMimeType(picked.name),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not pick image: $e')),
      );
    }
  }

  Future<void> _pickDocument() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg', 'webp', 'txt', 'doc', 'docx'],
      );
      if (files.isEmpty) return;
      final file = files.first;
      final bytes = await file.readAsBytes();
      final mimeType = ChatService.inferMimeType(file.name);
      await _uploadAndSendAttachment(
        bytes: bytes,
        fileName: file.name,
        isImage: mimeType.startsWith('image/'),
        mimeType: mimeType,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not pick file: $e')),
      );
    }
  }

  Future<void> _uploadAndSendAttachment({
    required Uint8List bytes,
    required String fileName,
    required bool isImage,
    String? mimeType,
  }) async {
    const maxBytes = 15 * 1024 * 1024;
    if (bytes.length >= maxBytes) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Attachment must be smaller than 15 MB.')),
      );
      return;
    }

    setState(() => _isUploadingAttachment = true);
    final msgId = 'msg_${DateTime.now().millisecondsSinceEpoch}';
    final senderId = BookingSyncService.resolveCurrentUid(
      widget.isArtistView ? widget.thread.artistId : 'client_user',
    );
    String attachmentUrl;
    try {
      attachmentUrl = await ChatService.uploadChatAttachment(
        threadId: widget.thread.id,
        bytes: bytes,
        fileName: fileName,
        contentType: mimeType,
        senderId: senderId,
      );
    } catch (_) {
      // Graceful fallback when running in offline/mock/test mode without Storage.
      attachmentUrl = 'local://$fileName';
    }

    if (!mounted) return;

    final caption = _textController.text.trim();
    final newMessage = ChatMessage(
      id: msgId,
      senderId: senderId,
      senderName: widget.isArtistView ? widget.thread.artistName : 'You',
      text: caption,
      timestamp: DateTime.now(),
      isFromArtist: widget.isArtistView,
      type: isImage ? ChatMessageType.image : ChatMessageType.file,
      attachmentUrl: attachmentUrl,
      attachmentName: isImage ? 'Photo' : fileName,
      attachmentMimeType: mimeType,
      attachmentSizeBytes: bytes.length,
    );

    setState(() {
      _isUploadingAttachment = false;
      if (caption.isNotEmpty) {
        _textController.clear();
      }
      if (isImage) {
        _localAttachmentBytes[msgId] = bytes;
      }
      _messages.add(newMessage);
    });
    BookingSyncService.appendAndSyncChatMessage(
      threadId: widget.thread.id,
      message: newMessage,
    );
    _scrollToBottom();
  }

  Future<void> _openFileAttachment(ChatMessage msg) async {
    final url = msg.attachmentUrl;
    if (url == null || url.isEmpty || url.startsWith('local://')) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${msg.attachmentName ?? 'File'} saved locally in preview mode.')),
      );
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open attachment URL.')),
      );
    }
  }

  void _openImagePreview(ChatMessage msg) {
    _dismissKeyboard();
    final localBytes = _localAttachmentBytes[msg.id];
    final url = msg.attachmentUrl;
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: AppTheme.onyxBackground,
          insetPadding: const EdgeInsets.all(16),
          child: Stack(
            children: [
              InteractiveViewer(
                child: localBytes != null
                    ? Image.memory(localBytes, fit: BoxFit.contain)
                    : (url != null && !url.startsWith('local://'))
                        ? Image.network(url, fit: BoxFit.contain)
                        : const SizedBox(
                            height: 240,
                            child: Center(
                              child: Icon(Icons.broken_image_outlined, color: AppTheme.navInactive),
                            ),
                          ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: const Icon(Icons.close, color: AppTheme.textPrimary),
                  onPressed: () => Navigator.pop(dialogContext),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatFileSize(int? bytes) {
    if (bytes == null || bytes <= 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Widget _buildImageAttachment(
    ChatMessage msg, {
    required bool isOutgoing,
    required bool hasCaption,
  }) {
    final localBytes = _localAttachmentBytes[msg.id];
    final url = msg.attachmentUrl;
    final radius = hasCaption
        ? const BorderRadius.only(
            topLeft: Radius.circular(17),
            topRight: Radius.circular(17),
          )
        : BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isOutgoing ? 16 : 6),
            bottomRight: Radius.circular(isOutgoing ? 6 : 16),
          );
    return GestureDetector(
      onTap: () => _openImagePreview(msg),
      child: ClipRRect(
        borderRadius: radius,
        child: SizedBox(
          width: 224,
          height: 180,
          child: localBytes != null
              ? Image.memory(localBytes, fit: BoxFit.cover)
              : (url != null && url.isNotEmpty && !url.startsWith('local://'))
                  ? Image.network(
                      url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _brokenImagePlaceholder(),
                    )
                  : _brokenImagePlaceholder(),
        ),
      ),
    );
  }

  Widget _brokenImagePlaceholder() {
    return Container(
      color: AppTheme.onyxSurface,
      child: const Center(
        child: Icon(Icons.image_outlined, color: AppTheme.navInactive, size: 32),
      ),
    );
  }

  Widget _buildFileAttachment(ChatMessage msg) {
    final sizeText = _formatFileSize(msg.attachmentSizeBytes);
    return InkWell(
      onTap: () => _openFileAttachment(msg),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.onyxSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.insert_drive_file_rounded, color: AppTheme.gold, size: 22),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    msg.attachmentName ?? 'Attachment',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (sizeText.isNotEmpty)
                    Text(
                      sizeText,
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.navInactive,
                        fontSize: 10,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.open_in_new_rounded, color: AppTheme.gold, size: 16),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  bool _isSameCalendarDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _formatDateDivider(DateTime dt) {
    final now = DateTime.now();
    if (_isSameCalendarDay(dt, now)) return 'Today';
    final yesterday = now.subtract(const Duration(days: 1));
    if (_isSameCalendarDay(dt, yesterday)) return 'Yesterday';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final month = months[dt.month - 1];
    return dt.year == now.year ? '$month ${dt.day}' : '$month ${dt.day}, ${dt.year}';
  }

  Widget _buildDateDivider(DateTime dt) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.onyxContainer,
            borderRadius: BorderRadius.circular(AppRadius.radiusFull),
            border: Border.all(color: AppTheme.darkBorder),
          ),
          child: Text(
            _formatDateDivider(dt),
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.navInactive,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final headerTitle = widget.isArtistView
        ? (_thread.clientName?.isNotEmpty == true
            ? _thread.clientName!
            : 'Client Inquiry')
        : _thread.artistName;
    final headerSubtitle = widget.isArtistView
        ? (_thread.flashTitleContext ?? 'Direct Consultation')
        : (_thread.isOnline ? 'Online now' : _thread.studioName);
    final headerAvatarUrl = widget.isArtistView
        ? _thread.clientAvatar
        : _thread.artistAvatar;

    return PopScope(
      onPopInvokedWithResult: (didPop, _) => _dismissKeyboard(),
      child: Scaffold(
        backgroundColor: AppTheme.onyxBackground,
        appBar: AppBar(
          backgroundColor: AppTheme.onyxSurface,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            key: const Key('chat_back_button'),
            icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
            onPressed: () {
              _dismissKeyboard();
              Navigator.pop(context);
            },
          ),
          title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(1.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.goldBorder, width: 1.5),
              ),
              child: UserAvatar(
                imageUrl: headerAvatarUrl,
                displayName: headerTitle,
                radius: 17.5,
                backgroundColor: AppTheme.onyxContainer,
                foregroundColor: AppTheme.gold,
                fallbackInitial: widget.isArtistView ? 'C' : 'A',
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
              GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _dismissKeyboard,
                child: Container(
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
              ),

            // Messages List
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _dismissKeyboard,
                child: ListView.builder(
                  controller: _scrollController,
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenGutter, vertical: 12),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    final prevMsg = index > 0 ? _messages[index - 1] : null;
                    final isCardMessage = msg.type == ChatMessageType.receipt ||
                        msg.type == ChatMessageType.proposal;
                    final prevIsCard = prevMsg != null &&
                        (prevMsg.type == ChatMessageType.receipt ||
                            prevMsg.type == ChatMessageType.proposal);
                    final showDateDivider = !isCardMessage &&
                        (prevMsg == null ||
                            prevIsCard ||
                            !_isSameCalendarDay(prevMsg.timestamp, msg.timestamp));

                    if (msg.type == ChatMessageType.receipt) {
                      return BookingReceiptMessageTile(
                        message: msg,
                        thread: _thread,
                      );
                    }

                    if (msg.type == ChatMessageType.proposal) {
                      return ProposalOptionsMessageTile(
                        message: msg,
                        thread: _thread,
                        isArtistView: widget.isArtistView,
                        onProposalConfirmed: (result) {
                          setState(() {
                            _messages = _messages
                                .map(
                                  (m) => m.id == result.updatedProposal.id
                                      ? result.updatedProposal
                                      : m,
                                )
                                .toList()
                              ..add(result.receiptMessage);
                          });
                          _scrollToBottom();
                        },
                      );
                    }

                    final isOutgoing = widget.isArtistView
                        ? msg.isFromArtist
                        : !msg.isFromArtist;
                    final isPureImage =
                        msg.type == ChatMessageType.image && msg.text.isEmpty;
                    final isCaptionedImage =
                        msg.type == ChatMessageType.image && msg.text.isNotEmpty;

                    final bubbleRadius = BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isOutgoing ? 18 : 5),
                      bottomRight: Radius.circular(isOutgoing ? 5 : 18),
                    );

                    final bubbleWidget = isPureImage
                        ? Container(
                            decoration: BoxDecoration(
                              borderRadius: bubbleRadius,
                              border: Border.all(
                                color: isOutgoing
                                    ? AppTheme.gold.withValues(alpha: 0.35)
                                    : AppTheme.cardBorder,
                                width: 1,
                              ),
                            ),
                            child: _buildImageAttachment(
                              msg,
                              isOutgoing: isOutgoing,
                              hasCaption: false,
                            ),
                          )
                        : Container(
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.78,
                            ),
                            decoration: BoxDecoration(
                              color: isOutgoing
                                  ? const Color(0xFF332B14)
                                  : const Color(0xFF1F1F23),
                              borderRadius: bubbleRadius,
                              border: Border.all(
                                color: isOutgoing
                                    ? AppTheme.gold.withValues(alpha: 0.35)
                                    : Colors.white.withValues(alpha: 0.06),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: isOutgoing
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isCaptionedImage)
                                  _buildImageAttachment(
                                    msg,
                                    isOutgoing: isOutgoing,
                                    hasCaption: true,
                                  ),
                                if (msg.type == ChatMessageType.file)
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                                    child: _buildFileAttachment(msg),
                                  ),
                                if (msg.text.isNotEmpty)
                                  Padding(
                                    padding: EdgeInsets.fromLTRB(
                                      14,
                                      isCaptionedImage || msg.type == ChatMessageType.file
                                          ? 8
                                          : 10,
                                      14,
                                      10,
                                    ),
                                    child: Text(
                                      msg.text,
                                      style: GoogleFonts.plusJakartaSans(
                                        color: AppTheme.textPrimary,
                                        fontSize: 14.5,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (showDateDivider) _buildDateDivider(msg.timestamp),
                        Align(
                          alignment: isOutgoing
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Column(
                              crossAxisAlignment: isOutgoing
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                              children: [
                                bubbleWidget,
                                const SizedBox(height: 4),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: Text(
                                    _formatTime(msg.timestamp),
                                    style: GoogleFonts.plusJakartaSans(
                                      color: AppTheme.navInactive,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
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
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Container(
                      key: const Key('chat_input_pill'),
                      constraints: const BoxConstraints(
                        minHeight: 42,
                        maxHeight: 112,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.cardBackground,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: AppTheme.cardBorder),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          SizedBox(
                            width: 40,
                            height: 40,
                            child: IconButton(
                              key: const Key('chat_attach_button'),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 40,
                                minHeight: 40,
                              ),
                              onPressed: _isUploadingAttachment
                                  ? null
                                  : _showAttachmentOptions,
                              icon: _isUploadingAttachment
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppTheme.gold,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.attach_file_rounded,
                                      color: AppTheme.navInactive,
                                      size: 20,
                                    ),
                              tooltip: 'Attach image or file',
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: _textController,
                              focusNode: _messageFocusNode,
                              minLines: 1,
                              maxLines: 4,
                              keyboardType: TextInputType.multiline,
                              textAlignVertical: TextAlignVertical.center,
                              textInputAction: TextInputAction.send,
                              onTapOutside: (_) => _dismissKeyboard(),
                              style: GoogleFonts.plusJakartaSans(
                                color: AppTheme.textPrimary,
                                fontSize: 14,
                                height: 1.35,
                              ),
                              decoration: InputDecoration(
                                isDense: true,
                                hintText: 'Type a message to $headerTitle...',
                                hintStyle: GoogleFonts.plusJakartaSans(
                                  color: AppTheme.navInactive,
                                  fontSize: 13,
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.fromLTRB(
                                  0,
                                  10,
                                  14,
                                  10,
                                ),
                              ),
                              onSubmitted: (_) => _sendMessage(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_messageFocusNode.hasFocus ||
                      MediaQuery.viewInsetsOf(context).bottom > 0) ...[
                    const SizedBox(width: 4),
                    KeyboardCollapseButton(
                      buttonKey: const Key('chat_collapse_keyboard_button'),
                      onPressed: _dismissKeyboard,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                  ],
                  const SizedBox(width: 8),
                  TextFieldTapRegion(
                    child: AnimatedContainer(
                      key: const Key('chat_send_button_container'),
                      duration: const Duration(milliseconds: 180),
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _hasDraftText
                            ? AppTheme.gold
                            : AppTheme.cardBackground,
                        border: _hasDraftText
                            ? null
                            : Border.all(color: AppTheme.cardBorder),
                      ),
                      child: IconButton(
                        key: const Key('chat_send_button'),
                        icon: Icon(
                          Icons.send,
                          color: _hasDraftText
                              ? AppTheme.onyxBackground
                              : AppTheme.navInactive,
                          size: 18,
                        ),
                        onPressed: _hasDraftText ? _sendMessage : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
