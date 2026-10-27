import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/artist.dart';
import '../../models/artist_dashboard_data.dart';
import '../../models/waitlist_entry.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/adaptive_glass_container.dart';
import '../../widgets/flash_image.dart';
import '../../widgets/flash_snack_bar.dart';
import 'add_waitlist_entry_sheet.dart';
import 'books_open_options_modal.dart';
import 'early_access_outreach_sheet.dart';

/// Full-featured VIP Waitlist & Early Access Management Screen for tattoo artists.
class ArtistWaitlistScreen extends StatefulWidget {
  final Artist? artist;
  final VoidCallback? onBack;

  const ArtistWaitlistScreen({
    super.key,
    this.artist,
    this.onBack,
  });

  @override
  State<ArtistWaitlistScreen> createState() => _ArtistWaitlistScreenState();
}

class _ArtistWaitlistScreenState extends State<ArtistWaitlistScreen> {
  String _selectedFilter = 'All'; // 'All', 'Waiting', 'Early Access Sent', 'Booked'
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<WaitlistEntry> get _filteredEntries {
    final entries = ArtistDashboardRepository.waitlistEntries;
    return entries.where((e) {
      // 1. Status Filter
      if (_selectedFilter == 'Waiting' && e.status != WaitlistStatus.waiting) {
        return false;
      }
      if (_selectedFilter == 'Early Access Sent' && e.status != WaitlistStatus.earlyAccessSent) {
        return false;
      }
      if (_selectedFilter == 'Booked' && e.status != WaitlistStatus.booked) {
        return false;
      }

      // 2. Search Query
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchName = e.clientName.toLowerCase().contains(query);
        final matchConcept = e.conceptDescription.toLowerCase().contains(query);
        final matchTag = e.relationshipTag.toLowerCase().contains(query);
        final matchPlacement = e.placement.toLowerCase().contains(query);
        return matchName || matchConcept || matchTag || matchPlacement;
      }

      return true;
    }).toList();
  }

  void _openAddSheet({WaitlistEntry? entry}) {
    AddWaitlistEntrySheet.show(
      context: context,
      initialEntry: entry,
      onSaved: () => setState(() {}),
    );
  }

  void _copyVipLink(WaitlistEntry entry) {
    Clipboard.setData(ClipboardData(text: entry.vipBookingLink));
    FlashSnackBar.showSuccess(
      context,
      'VIP link for ${entry.clientName} copied!',
    );
  }

  void _showEntryActions(WaitlistEntry entry) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return AdaptiveGlassContainer.bottomSheet(
          glassEnabled: false,
          androidSurfaceColor: const Color(0xFF161818),
          topRadius: AppRadius.radiusSheet,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.clientName,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '${entry.relationshipTag} • ${entry.status.label}',
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF8C9191),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.edit_rounded, color: Color(0xFFEEC200)),
                  title: const Text('Edit Entry Details', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    _openAddSheet(entry: entry);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.copy_rounded, color: Color(0xFF38BDF8)),
                  title: const Text('Copy VIP Booking Link', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    _copyVipLink(entry);
                  },
                ),
                if (entry.status != WaitlistStatus.booked)
                  ListTile(
                    leading: const Icon(Icons.check_circle_rounded, color: Color(0xFF22C55E)),
                    title: const Text('Mark as Booked', style: TextStyle(color: Colors.white)),
                    onTap: () {
                      Navigator.pop(context);
                      ArtistDashboardRepository.updateWaitlistEntry(
                        entry.copyWith(status: WaitlistStatus.booked, bookedAt: DateTime.now()),
                      );
                      setState(() {});
                    },
                  ),
                if (entry.status != WaitlistStatus.earlyAccessSent)
                  ListTile(
                    leading: const Icon(Icons.send_rounded, color: Color(0xFF38BDF8)),
                    title: const Text('Send Early Access Invite', style: TextStyle(color: Colors.white)),
                    onTap: () {
                      Navigator.pop(context);
                      ArtistDashboardRepository.updateWaitlistEntry(
                        entry.copyWith(
                          status: WaitlistStatus.earlyAccessSent,
                          invitedAt: DateTime.now(),
                        ),
                      );
                      setState(() {});
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444)),
                  title: const Text('Remove from Waitlist', style: TextStyle(color: Color(0xFFEF4444))),
                  onTap: () {
                    Navigator.pop(context);
                    ArtistDashboardRepository.removeWaitlistEntry(entry.id);
                    setState(() {});
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final schedule = ArtistDashboardRepository.booksSchedule;
    final allEntries = ArtistDashboardRepository.waitlistEntries;
    final waitingCount = allEntries.where((e) => e.status == WaitlistStatus.waiting).length;
    final invitedCount = allEntries.where((e) => e.status == WaitlistStatus.earlyAccessSent).length;
    final bookedCount = allEntries.where((e) => e.status == WaitlistStatus.booked).length;

    return Scaffold(
      backgroundColor: const Color(0xFF121414),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top App Bar
            _buildTopAppBar(context),

            // Content List
            Expanded(
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenGutter,
                      10,
                      AppSpacing.screenGutter,
                      0,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        // Books & Early Access Status Banner
                        _buildStatusBanner(schedule),

                        const SizedBox(height: 18),

                        // Metrics Row
                        _buildMetricsRow(
                          total: allEntries.length,
                          waiting: waitingCount,
                          invited: invitedCount,
                          booked: bookedCount,
                        ),

                        const SizedBox(height: 20),

                        // Search & Filter Row
                        _buildSearchAndActionRow(),

                        const SizedBox(height: 14),
                      ]),
                    ),
                  ),

                  // Filter Chips (Full-bleed unclipped horizontal scrollable)
                  SliverToBoxAdapter(
                    child: _buildFilterChips(
                      allCount: allEntries.length,
                      waitingCount: waitingCount,
                      invitedCount: invitedCount,
                      bookedCount: bookedCount,
                    ),
                  ),

                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.screenGutter,
                      18,
                      AppSpacing.screenGutter,
                      MediaQuery.paddingOf(context).bottom + 20,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        // Waitlist Cards
                        if (_filteredEntries.isEmpty)
                          _buildEmptyState()
                        else
                          ..._filteredEntries.map((e) => _buildWaitlistCard(e)),
                      ]),
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

  Widget _buildTopAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenGutter - 8.0,
        vertical: 8,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: widget.onBack ?? () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'VIP Waitlist',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  'Friends, family & priority client access',
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF8C9191),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _openAddSheet(),
            tooltip: 'Add Contact',
            icon: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFFEEC200),
                borderRadius: BorderRadius.circular(AppRadius.radiusSm),
              ),
              child: const Icon(Icons.add_rounded, color: Color(0xFF121414), size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner(ArtistBooksSchedule schedule) {
    if (schedule.isEarlyAccessActive) {
      final remaining = schedule.earlyAccessTimeRemaining;
      final remainingStr = remaining != null
          ? '${remaining.inHours}h ${remaining.inMinutes.remainder(60)}m left'
          : 'Active';

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1C1C),
          borderRadius: BorderRadius.circular(AppRadius.radiusLg),
          border: Border.all(color: const Color(0xFFEEC200), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFEEC200).withAlpha(20),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEC200).withAlpha(30),
                    borderRadius: BorderRadius.circular(AppRadius.radiusSm),
                  ),
                  child: const Icon(Icons.stars_rounded, color: Color(0xFFEEC200), size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'VIP Early Access Active ($remainingStr)',
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFFEEC200),
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Only invited waitlist members can book slots right now.',
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF8C9191),
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      EarlyAccessOutreachSheet.show(
                        context: context,
                        onBooksUpdated: () => setState(() {}),
                      );
                    },
                    icon: const Icon(Icons.checklist_rounded, size: 16),
                    label: const Text('Outreach Checklist'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFEEC200),
                      side: const BorderSide(color: Color(0xFFEEC200)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.radiusSm),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      textStyle: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      ArtistDashboardRepository.openBooksPublicly();
                      setState(() {});
                      FlashSnackBar.showSuccess(
                        context,
                        'Books opened to public!',
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF242828),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.radiusSm),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      elevation: 0,
                      textStyle: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: const Text('Open Public Now'),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    if (!schedule.isBooksOpen) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1C1C),
          borderRadius: BorderRadius.circular(AppRadius.radiusLg),
          border: Border.all(color: const Color(0xFF2C3030)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF282C2C),
                borderRadius: BorderRadius.circular(AppRadius.radiusSm),
              ),
              child: const Icon(Icons.lock_clock_rounded, color: Color(0xFF8C9191), size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Books Currently Closed',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Ready to open? You can release early access to this waitlist.',
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFF8C9191),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () {
                BooksOpenOptionsModal.show(
                  context: context,
                  onEarlyAccessSelected: () {
                    setState(() {});
                    EarlyAccessOutreachSheet.show(
                      context: context,
                      onBooksUpdated: () => setState(() {}),
                    );
                  },
                  onPublicOpenSelected: () => setState(() {}),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEEC200),
                foregroundColor: const Color(0xFF121414),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.radiusSm),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                elevation: 0,
                textStyle: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: const Text('Open Books'),
            ),
          ],
        ),
      );
    }

    // Books are open publicly
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161E1A),
        borderRadius: BorderRadius.circular(AppRadius.radiusLg),
        border: Border.all(color: const Color(0xFF22C55E).withAlpha(100)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: Color(0xFF22C55E), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Books are Open Publicly • Clients can claim flash & submit requests.',
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF22C55E),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsRow({
    required int total,
    required int waiting,
    required int invited,
    required int booked,
  }) {
    return Row(
      children: [
        Expanded(child: _buildMetricTile('WAITLIST', total.toString(), const Color(0xFFFFFFFF))),
        const SizedBox(width: 8),
        Expanded(child: _buildMetricTile('WAITING', waiting.toString(), const Color(0xFFEEC200))),
        const SizedBox(width: 8),
        Expanded(child: _buildMetricTile('INVITED', invited.toString(), const Color(0xFF38BDF8))),
        const SizedBox(width: 8),
        Expanded(child: _buildMetricTile('BOOKED', booked.toString(), const Color(0xFF22C55E))),
      ],
    );
  }

  Widget _buildMetricTile(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1C1C),
        borderRadius: BorderRadius.circular(AppRadius.radiusMd),
        border: Border.all(color: const Color(0xFF282C2C)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFF8C9191),
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndActionRow() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1D1D),
              borderRadius: BorderRadius.circular(AppRadius.radiusFull),
              border: Border.all(color: const Color(0xFF2A2E2E)),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search by client, concept, tag...',
                hintStyle: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF6B7272),
                  fontSize: 12.5,
                ),
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF8C9191), size: 18),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        ElevatedButton.icon(
          onPressed: () => _openAddSheet(),
          icon: const Icon(Icons.person_add_alt_1_rounded, size: 15),
          label: const Text('Add Friend'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFEEC200),
            foregroundColor: const Color(0xFF121414),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.radiusMd),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            elevation: 0,
            textStyle: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChips({
    required int allCount,
    required int waitingCount,
    required int invitedCount,
    required int bookedCount,
  }) {
    final filters = [
      {'label': 'All', 'count': allCount},
      {'label': 'Waiting', 'count': waitingCount},
      {'label': 'Early Access Sent', 'count': invitedCount},
      {'label': 'Booked', 'count': bookedCount},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenGutter),
      child: Row(
        children: filters.map((f) {
          final label = f['label'] as String;
          final count = f['count'] as int;
          final isSelected = _selectedFilter == label;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => setState(() => _selectedFilter = label),
              borderRadius: BorderRadius.circular(AppRadius.radiusFull),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFEEC200) : const Color(0xFF1A1D1D),
                  borderRadius: BorderRadius.circular(AppRadius.radiusFull),
                  border: Border.all(
                    color: isSelected ? const Color(0xFFEEC200) : const Color(0xFF282C2C),
                  ),
                ),
                child: Text(
                  '$label ($count)',
                  style: GoogleFonts.plusJakartaSans(
                    color: isSelected ? const Color(0xFF121414) : const Color(0xFFC7CDCD),
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildWaitlistCard(WaitlistEntry entry) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF181B1B),
        borderRadius: BorderRadius.circular(AppRadius.radiusLg),
        border: Border.all(
          color: entry.status == WaitlistStatus.earlyAccessSent
              ? const Color(0xFF38BDF8).withAlpha(120)
              : const Color(0xFF262A2A),
          width: 1.2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openAddSheet(entry: entry),
          borderRadius: BorderRadius.circular(AppRadius.radiusLg),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: Avatar, Name, Relationship Tag, Status Badge, More Menu
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: const Color(0xFF282D2D),
                      child: ClipOval(
                        child: entry.avatarUrl != null
                            ? FlashImage(
                                urlOrPath: entry.avatarUrl!,
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                              )
                            : Text(
                                entry.clientName.isNotEmpty ? entry.clientName[0] : '?',
                                style: GoogleFonts.plusJakartaSans(
                                  color: const Color(0xFFEEC200),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  entry.clientName,
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              if (entry.isRegisteredFlashUser)
                                const Tooltip(
                                  message: 'Flash User',
                                  child: Icon(Icons.verified_rounded, color: Color(0xFF38BDF8), size: 14),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF282E2E),
                                    borderRadius: BorderRadius.circular(AppRadius.radiusXs),
                                  ),
                                  child: Text(
                                    'Non-App',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: const Color(0xFF8C9191),
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEEC200).withAlpha(24),
                                  borderRadius: BorderRadius.circular(AppRadius.radiusXs),
                                ),
                                child: Text(
                                  entry.relationshipTag,
                                  style: GoogleFonts.plusJakartaSans(
                                    color: const Color(0xFFEEC200),
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF282E2E),
                                  borderRadius: BorderRadius.circular(AppRadius.radiusXs),
                                ),
                                child: Text(
                                  entry.designType,
                                  style: GoogleFonts.plusJakartaSans(
                                    color: const Color(0xFFC7CDCD),
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: entry.status.badgeColor.withAlpha(24),
                        borderRadius: BorderRadius.circular(AppRadius.radiusSm),
                        border: Border.all(
                          color: entry.status.badgeColor.withAlpha(100),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(entry.status.icon, color: entry.status.badgeColor, size: 11),
                          const SizedBox(width: 4),
                          Text(
                            entry.status.label,
                            style: GoogleFonts.plusJakartaSans(
                              color: entry.status.badgeColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF8C9191), size: 18),
                      onPressed: () => _showEntryActions(entry),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Concept & Specs
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141616),
                    borderRadius: BorderRadius.circular(AppRadius.radiusMd),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.conceptDescription,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 12.5,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        children: [
                          _buildDetailIconText(Icons.location_on_outlined, entry.placement),
                          if (entry.budget != null)
                            _buildDetailIconText(Icons.attach_money_rounded, '\$${entry.budget}'),
                          _buildDetailIconText(Icons.schedule_rounded, entry.availabilityPreference),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Actions row
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _copyVipLink(entry),
                        icon: const Icon(Icons.copy_rounded, size: 13),
                        label: const Text('Copy VIP Link'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFC7CDCD),
                          side: const BorderSide(color: Color(0xFF333838)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.radiusSm),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          textStyle: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (entry.status == WaitlistStatus.waiting)
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            ArtistDashboardRepository.updateWaitlistEntry(
                              entry.copyWith(
                                status: WaitlistStatus.earlyAccessSent,
                                invitedAt: DateTime.now(),
                              ),
                            );
                            setState(() {});
                            FlashSnackBar.showSuccess(
                              context,
                              'Early access sent to ${entry.clientName}!',
                            );
                          },
                          icon: const Icon(Icons.send_rounded, size: 13),
                          label: const Text('Invite VIP'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEEC200),
                            foregroundColor: const Color(0xFF121414),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.radiusSm),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            elevation: 0,
                            textStyle: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      )
                    else if (entry.status == WaitlistStatus.earlyAccessSent)
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            ArtistDashboardRepository.updateWaitlistEntry(
                              entry.copyWith(
                                status: WaitlistStatus.booked,
                                bookedAt: DateTime.now(),
                              ),
                            );
                            setState(() {});
                          },
                          icon: const Icon(Icons.check_circle_outline_rounded, size: 13),
                          label: const Text('Mark Booked'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF22C55E),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.radiusSm),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            elevation: 0,
                            textStyle: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailIconText(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: const Color(0xFF8C9191), size: 13),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFF8C9191),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF181B1B),
        borderRadius: BorderRadius.circular(AppRadius.radiusXl),
        border: Border.all(color: const Color(0xFF282C2C)),
      ),
      child: Column(
        children: [
          const Icon(Icons.people_outline_rounded, color: Color(0xFF8C9191), size: 40),
          const SizedBox(height: 12),
          Text(
            'No contacts found in this view',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Add friends or family to easily send early booking access.',
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFF8C9191),
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _openAddSheet(),
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('Add to Waitlist'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEEC200),
              foregroundColor: const Color(0xFF121414),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.radiusMd),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
