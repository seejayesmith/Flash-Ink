import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../models/artist_dashboard_data.dart';
import '../../../../models/waitlist_entry.dart';
import '../../../../theme/app_radius.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/client_empty_state.dart';
import '../../../../widgets/flash_tab_header.dart';
import '../../domain/models/message_thread.dart';
import '../widgets/message_thread_tile.dart';
import '../widgets/vip_waitlist_invitation_card.dart';

/// MessagesScreen:
/// Main inbox view displaying direct message threads with tattoo artists.
class MessagesScreen extends StatefulWidget {
  final List<MessageThread>? mockThreads;
  final bool? showBackButton;

  const MessagesScreen({
    super.key,
    this.mockThreads,
    this.showBackButton,
  });

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  List<MessageThread> get _threads =>
      widget.mockThreads ?? MessageThread.activeThreads;

  @override
  void initState() {
    super.initState();
    MessageThread.unreadUpdateNotifier.addListener(_onUnreadUpdate);
  }

  void _onUnreadUpdate() {
    if (!mounted) return;
    if (WidgetsBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    } else {
      setState(() {});
    }
  }

  @override
  void dispose() {
    MessageThread.unreadUpdateNotifier.removeListener(_onUnreadUpdate);
    _searchController.dispose();
    super.dispose();
  }

  List<MessageThread> get _filteredThreads {
    if (_query.isEmpty) return _threads;
    return _threads.where((t) {
      return t.artistName.toLowerCase().contains(_query.toLowerCase()) ||
          t.studioName.toLowerCase().contains(_query.toLowerCase()) ||
          t.lastMessage.toLowerCase().contains(_query.toLowerCase());
    }).toList();
  }

  int get _totalUnreadCount {
    return _threads.fold(0, (sum, t) => sum + t.unreadCount);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final filtered = _filteredThreads;
    final shouldShowBackButton =
        widget.showBackButton ?? Navigator.canPop(context);

    return Scaffold(
      backgroundColor: AppTheme.onyxBackground,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            FlashTabHeader(
              leading: shouldShowBackButton
                  ? IconButton(
                      key: const Key('messages_back_button'),
                      onPressed: () => Navigator.maybePop(context),
                      icon: const Icon(
                        Icons.arrow_back_ios_new,
                        color: AppTheme.textPrimary,
                        size: 20,
                      ),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                      tooltip: 'Back',
                    )
                  : null,
              title: 'Messages',
              titleAccessory: _totalUnreadCount > 0
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.gold,
                        borderRadius:
                            BorderRadius.circular(AppRadius.radiusFull),
                      ),
                      child: Text(
                        '$_totalUnreadCount NEW',
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.onyxBackground,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    )
                  : null,
            ),

            // Standardized Search Input
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenGutter,
                vertical: AppSpacing.spaceXs,
              ),
              child: Container(
                height: 46,
                decoration: BoxDecoration(
                  color: AppTheme.cardBackground,
                  borderRadius: BorderRadius.circular(AppRadius.radiusFull),
                  border: Border.all(color: AppTheme.cardBorder, width: 1.2),
                ),
                child: TextField(
                  controller: _searchController,
                  textAlignVertical: TextAlignVertical.center,
                  onChanged: (val) {
                    setState(() {
                      _query = val;
                    });
                  },
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Search conversations...',
                    hintStyle: GoogleFonts.plusJakartaSans(
                      color: AppTheme.navInactive,
                      fontSize: 13,
                    ),
                    prefixIcon: const Icon(Icons.search,
                        color: AppTheme.gold, size: 20),
                    prefixIconConstraints:
                        const BoxConstraints(minWidth: 48, minHeight: 46),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Exclusive VIP Waitlist Early Access Invitation Card
            Builder(
              builder: (context) {
                final schedule = ArtistDashboardRepository.booksSchedule;
                final invites = ArtistDashboardRepository.waitlistEntries
                    .where((e) => e.status == WaitlistStatus.earlyAccessSent)
                    .toList();
                if (schedule.isEarlyAccessActive && invites.isNotEmpty) {
                  return VipWaitlistInvitationCard(entry: invites.first);
                }
                return const SizedBox.shrink();
              },
            ),

            // Threads List
            Expanded(
              child: filtered.isEmpty
                  ? ClientEmptyState(
                      icon: _query.trim().isEmpty
                          ? Icons.chat_bubble_outline_rounded
                          : Icons.search_off_rounded,
                      title: _query.trim().isEmpty
                          ? 'No Conversations Yet'
                          : 'No Conversations Found',
                      subtitle: _query.trim().isEmpty
                          ? 'When you book an appointment or message an artist, your conversations will appear here.'
                          : 'No messages match "$_query". Try a different search.',
                    )
                  : ListView.builder(
                      padding: EdgeInsets.fromLTRB(
                        AppSpacing.screenGutter,
                        0,
                        AppSpacing.screenGutter,
                        AppSpacing.spaceXxl + AppTheme.navBarHeight + bottomInset,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        return MessageThreadTile(thread: filtered[index]);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
