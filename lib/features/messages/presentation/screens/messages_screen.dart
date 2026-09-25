import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_theme.dart';
import '../../domain/models/message_thread.dart';
import '../widgets/message_thread_tile.dart';

/// MessagesScreen:
/// Main inbox view displaying direct message threads with tattoo artists.
class MessagesScreen extends StatefulWidget {
  final List<MessageThread>? mockThreads;

  const MessagesScreen({
    super.key,
    this.mockThreads,
  });

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final _searchController = TextEditingController();
  late List<MessageThread> _threads;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _threads = widget.mockThreads ?? List.from(MessageThread.mockThreads);
  }

  @override
  void dispose() {
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

    return Scaffold(
      backgroundColor: AppTheme.onyxBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.onyxBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Row(
          children: [
            Text(
              'Messages',
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (_totalUnreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.gold,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$_totalUnreadCount NEW',
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
        centerTitle: false,
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Search Input
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spaceLg),
              child: Container(
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.cardBackground,
                  borderRadius: BorderRadius.circular(21),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    setState(() {
                      _query = val;
                    });
                  },
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search conversations...',
                    hintStyle: GoogleFonts.plusJakartaSans(
                      color: AppTheme.navInactive,
                      fontSize: 12,
                    ),
                    prefixIcon: const Icon(Icons.search, color: AppTheme.navInactive, size: 18),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Threads List
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        'No conversations found',
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.navInactive,
                          fontSize: 13,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.fromLTRB(
                        AppSpacing.spaceLg,
                        0,
                        AppSpacing.spaceLg,
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
