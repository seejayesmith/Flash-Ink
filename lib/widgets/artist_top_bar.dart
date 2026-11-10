import 'package:flutter/material.dart';
import '../features/messages/domain/models/message_thread.dart';
import '../theme/app_radius.dart';
import '../theme/app_theme.dart';
import 'tattoo_machine_icon.dart';

/// Standardized top action bar for Artist screens.
///
/// Features:
/// - Standardized left-side [TattooMachineIcon] (size 43, brand gold) or optional back button.
/// - Dynamic messages button with a numeric unread count badge (hidden when 0).
/// - Profile avatar with gold border.
class ArtistTopBar extends StatelessWidget {
  final Key? logoKey;
  final Key? messagesKey;
  final Key? avatarKey;
  final VoidCallback? onLogoTap;
  final VoidCallback onMessagesTap;
  final VoidCallback onAvatarTap;
  final Widget avatarChild;
  final Widget? leadingWidget;
  final String? artistId;
  final int? explicitUnreadCount;

  const ArtistTopBar({
    super.key,
    this.logoKey,
    this.messagesKey,
    this.avatarKey,
    this.onLogoTap,
    required this.onMessagesTap,
    required this.onAvatarTap,
    required this.avatarChild,
    this.leadingWidget,
    this.artistId,
    this.explicitUnreadCount,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: MessageThread.unreadUpdateNotifier,
      builder: (context, _, child) {
        final unreadCount = explicitUnreadCount ?? MessageThread.totalUnreadCount(artistId);

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            leadingWidget ??
                (onLogoTap != null
                    ? GestureDetector(
                        key: logoKey,
                        onTap: onLogoTap,
                        child: const TattooMachineIcon(
                          size: 43,
                          color: Color(0xFFEEC200),
                        ),
                      )
                    : TattooMachineIcon(
                        key: logoKey,
                        size: 43,
                        color: const Color(0xFFEEC200),
                      )),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  key: messagesKey ?? const Key('top_action_messages_button'),
                  onTap: onMessagesTap,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E2121),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF333737),
                        width: 1.2,
                      ),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(
                          Icons.chat_bubble_outline_rounded,
                          color: Color(0xFFEEC200),
                          size: 20,
                        ),
                        if (unreadCount > 0)
                          Positioned(
                            top: -2,
                            right: -2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEC200),
                                borderRadius:
                                    BorderRadius.circular(AppRadius.radiusSm),
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 14,
                                minHeight: 14,
                              ),
                              child: Text(
                                '$unreadCount',
                                style: const TextStyle(
                                  color: AppTheme.onyxBackground,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  key: avatarKey ?? const Key('top_action_avatar_button'),
                  onTap: onAvatarTap,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFEEC200).withAlpha(120),
                        width: 1.5,
                      ),
                    ),
                    child: avatarChild,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
