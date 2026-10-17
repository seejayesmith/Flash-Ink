import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/artist_dashboard_data.dart';
import '../../models/waitlist_entry.dart';
import '../../widgets/adaptive_glass_container.dart';
import '../../widgets/flash_image.dart';

/// Modal bottom sheet providing the artist with a real-time outreach checklist
/// for non-app friends & family, and confirming in-app delivery for registered Flash users.
class EarlyAccessOutreachSheet extends StatefulWidget {
  final VoidCallback? onBooksUpdated;

  const EarlyAccessOutreachSheet({
    super.key,
    this.onBooksUpdated,
  });

  static Future<void> show({
    required BuildContext context,
    VoidCallback? onBooksUpdated,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EarlyAccessOutreachSheet(
        onBooksUpdated: onBooksUpdated,
      ),
    );
  }

  @override
  State<EarlyAccessOutreachSheet> createState() => _EarlyAccessOutreachSheetState();
}

class _EarlyAccessOutreachSheetState extends State<EarlyAccessOutreachSheet> {
  final Set<String> _manuallySentIds = {};

  String _formatTimeRemaining(Duration? duration) {
    if (duration == null || duration == Duration.zero) {
      return 'Ending Soon';
    }
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return '${hours}h ${minutes}m remaining';
  }

  void _copyVipLink(WaitlistEntry entry) {
    Clipboard.setData(ClipboardData(text: entry.vipBookingLink));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Color(0xFFEEC200), size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'VIP Link for ${entry.clientName} copied to clipboard!',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1E2121),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFEEC200), width: 1),
        ),
      ),
    );
  }

  void _simulateShare(WaitlistEntry entry) {
    Clipboard.setData(ClipboardData(
      text: 'Hey ${entry.clientName}! I just opened early access to my books on Flash. Here is your private VIP link to grab a spot before I open to the public: ${entry.vipBookingLink}',
    ));
    setState(() {
      _manuallySentIds.add(entry.id);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Personalized invite text copied! Ready to paste into SMS or Messages.',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 12.5,
          ),
        ),
        backgroundColor: const Color(0xFF1E2121),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF38BDF8), width: 1),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final schedule = ArtistDashboardRepository.booksSchedule;
    final waitlist = ArtistDashboardRepository.waitlistEntries;
    final registeredUsers = waitlist.where((e) => e.isRegisteredFlashUser).toList();
    final manualFriends = waitlist.where((e) => !e.isRegisteredFlashUser).toList();

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      child: AdaptiveGlassContainer.bottomSheet(
        glassEnabled: false,
        androidSurfaceColor: const Color(0xFF141616),
        selectedBorderColor: const Color(0xFFEEC200),
        unselectedBorderColor: const Color(0xFFEEC200),
        selectedBorderWidth: 1.5,
        unselectedBorderWidth: 1.5,
        topRadius: 28.0,
        child: Column(
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF333838),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEC200).withAlpha(28),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFEEC200).withAlpha(120),
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    Icons.stars_rounded,
                    color: Color(0xFFEEC200),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'VIP Early Access Active',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF22C55E),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _formatTimeRemaining(schedule.earlyAccessTimeRemaining),
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFF22C55E),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              '• Auto-opens to public after',
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                color: const Color(0xFF8C9191),
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF8C9191)),
                ),
              ],
            ),
          ),

          const Divider(color: Color(0xFF222626), height: 1),

          // Content List
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
              physics: const BouncingScrollPhysics(),
              children: [
                // Quick transition to public
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E2121),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF2C3232)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: Color(0xFF8C9191), size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Want to open to everyone now instead of waiting?',
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFFC7CDCD),
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () {
                          ArtistDashboardRepository.openBooksPublicly();
                          setState(() {});
                          widget.onBooksUpdated?.call();
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Books are now completely open to the public!'),
                              backgroundColor: Color(0xFF22C55E),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFEEC200)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Open Now',
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFFEEC200),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Section 1: Non-App Friends & Family (Combo 1 & 3: Outreach Checklist)
                Text(
                  'FRIENDS & FAMILY OUTREACH (${manualFriends.length})',
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFFEEC200),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'These contacts are not on Flash yet. Send them their private booking link via text or email so they can reserve their spot.',
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF8C9191),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),

                if (manualFriends.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B1D1D),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        'All waitlist members have registered Flash profiles!',
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF8C9191),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  )
                else
                  ...manualFriends.map((entry) => _buildManualFriendCard(entry)),

                const SizedBox(height: 24),

                // Section 2: In-App Flash Members
                Text(
                  'FLASH APP MEMBERS (${registeredUsers.length})',
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF38BDF8),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Automated VIP notifications and inbox cards have been dispatched to their Flash accounts.',
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF8C9191),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),

                ...registeredUsers.map((entry) => _buildRegisteredUserCard(entry)),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildManualFriendCard(WaitlistEntry entry) {
    final isSent = _manuallySentIds.contains(entry.id) || entry.hasEarlyAccessSent;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSent ? const Color(0xFF22C55E).withAlpha(80) : const Color(0xFF323838),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF2E3333),
                child: Text(
                  entry.clientName.isNotEmpty ? entry.clientName[0] : '?',
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFFEEC200),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          entry.clientName,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEC200).withAlpha(24),
                            borderRadius: BorderRadius.circular(4),
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
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entry.clientPhone ?? entry.clientEmail ?? 'No contact info',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF8C9191),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSent)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E).withAlpha(30),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_rounded, color: Color(0xFF22C55E), size: 12),
                      const SizedBox(width: 4),
                      Text(
                        'Sent',
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF22C55E),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Concept: ${entry.conceptDescription}',
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFFC7CDCD),
              fontSize: 11.5,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          // Action buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _simulateShare(entry),
                  icon: const Icon(Icons.send_rounded, size: 14),
                  label: const Text('Share Text Invite'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEEC200),
                    foregroundColor: const Color(0xFF121414),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    elevation: 0,
                    textStyle: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => _copyVipLink(entry),
                tooltip: 'Copy VIP Link',
                icon: const Icon(Icons.copy_rounded, color: Color(0xFFC7CDCD), size: 18),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF262B2B),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRegisteredUserCard(WaitlistEntry entry) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1E1E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF282D2D)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 17,
            backgroundColor: const Color(0xFF2E3333),
            child: ClipOval(
              child: entry.avatarUrl != null
                  ? FlashImage(
                      urlOrPath: entry.avatarUrl!,
                      width: 34,
                      height: 34,
                      fit: BoxFit.cover,
                    )
                  : Text(
                      entry.clientName[0],
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF38BDF8),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      entry.clientName,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.verified_rounded, color: Color(0xFF38BDF8), size: 13),
                  ],
                ),
                Text(
                  '${entry.designType} • ${entry.placement}',
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF8C9191),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF22C55E).withAlpha(24),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.done_all_rounded, color: Color(0xFF22C55E), size: 13),
                const SizedBox(width: 4),
                Text(
                  'Delivered',
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF22C55E),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
