import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../theme/app_radius.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/user_avatar.dart';
import '../../domain/models/message_thread.dart';
import '../screens/chat_conversation_screen.dart';

/// Reusable thread tile component for the Messages inbox.
class MessageThreadTile extends StatelessWidget {
  final MessageThread thread;
  final VoidCallback? onTap;
  final bool isArtistView;

  const MessageThreadTile({
    super.key,
    required this.thread,
    this.onTap,
    this.isArtistView = false,
  });

  String _formatRelativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h';
    } else {
      return '${diff.inDays}d';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusManager.instance.primaryFocus?.unfocus();
        FocusScope.of(context).unfocus();
        if (onTap != null) {
          onTap!();
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatConversationScreen(
              thread: thread,
              isArtistView: isArtistView,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.cardBackground,
          borderRadius: BorderRadius.circular(AppRadius.radiusLg),
          border: Border.all(
            color: thread.hasUnread ? AppTheme.goldBorder : AppTheme.cardBorder,
            width: thread.hasUnread ? 1.2 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(70),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Avatar with online status badge
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(1.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: thread.hasUnread ? AppTheme.gold : AppTheme.darkBorder,
                      width: 1.5,
                    ),
                  ),
                  child: UserAvatar(
                    imageUrl: isArtistView ? thread.clientAvatar : thread.artistAvatar,
                    displayName: isArtistView
                        ? (thread.clientName?.isNotEmpty == true
                            ? thread.clientName!
                            : (thread.flashTitleContext ?? 'Client'))
                        : thread.artistName,
                    radius: 24.5,
                    backgroundColor: AppTheme.onyxContainer,
                    foregroundColor: AppTheme.gold,
                    fallbackInitial: isArtistView ? 'C' : 'A',
                  ),
                ),
                if (thread.isOnline)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 13,
                      height: 13,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4ADE80),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.cardBackground, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),

            // Name, Studio, and Message Snippet
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          thread.artistName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            color: AppTheme.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        _formatRelativeTime(thread.lastMessageTime),
                        style: GoogleFonts.plusJakartaSans(
                          color: thread.hasUnread ? AppTheme.gold : AppTheme.navInactive,
                          fontSize: 11,
                          fontWeight: thread.hasUnread ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    thread.studioName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.gold,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          thread.lastMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            color: thread.hasUnread ? AppTheme.textPrimary : AppTheme.navInactive,
                            fontSize: 12,
                            fontWeight: thread.hasUnread ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (thread.hasUnread) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.gold,
                            borderRadius: BorderRadius.circular(AppRadius.radiusFull),
                          ),
                          child: Text(
                            '${thread.unreadCount}',
                            style: GoogleFonts.plusJakartaSans(
                              color: AppTheme.onyxBackground,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ],
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
