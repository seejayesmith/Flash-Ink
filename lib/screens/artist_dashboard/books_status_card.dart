import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/artist_dashboard_data.dart';
import '../../models/waitlist_entry.dart';
import '../../theme/app_buttons.dart';
import '../../theme/app_radius.dart';
import '../../widgets/flash_switch.dart';

/// The hero status card displayed on the Artist Dashboard and Books management view.
/// Reflects the 7 distinct lifecycle states:
/// 1. Always Open (Rolling window)
/// 2. Paused (Inquiries temporarily paused)
/// 3. Closed (Waitlist active)
/// 4. Drop Scheduled (Pre-launch countdown)
/// 5. VIP Early Access (Waitlist window active)
/// 6. Drop Live / Open (Inquiries active + capacity counter)
/// 7. Drop Full (Capacity filled)
class BooksStatusCard extends StatelessWidget {
  final VoidCallback? onPlanDrop;
  final VoidCallback? onReviewRequests;
  final VoidCallback? onAddDays;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onStatusChanged;

  const BooksStatusCard({
    super.key,
    this.onPlanDrop,
    this.onReviewRequests,
    this.onAddDays,
    this.onOpenSettings,
    this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    final schedule = ArtistDashboardRepository.booksSchedule;
    final mode = ArtistDashboardRepository.bookingMode;
    final isPaused = ArtistDashboardRepository.isPaused;
    final drop = ArtistDashboardRepository.currentBookDrop;
    final waitingCount = ArtistDashboardRepository.waitlistEntries
        .where((e) => e.status == WaitlistStatus.waiting)
        .length;
    final pendingRequestsCount = ArtistDashboardRepository.pendingRequests.length;

    // Determine state
    final bool isDropMode = mode == BookingMode.drops;
    final bool isDropScheduled = isDropMode && drop?.status == BookDropStatus.scheduled;
    final bool isAlwaysOpen = mode == BookingMode.alwaysOpen && schedule.isBooksOpen && !isPaused;
    final bool isEarlyAccess = isDropMode
        ? (schedule.isBooksOpen && drop?.status == BookDropStatus.earlyAccess)
        : schedule.isEarlyAccessActive;
    final bool isDropFull = isDropMode && schedule.isBooksOpen && drop?.status == BookDropStatus.full;
    final bool isDropLive = isDropMode && schedule.isBooksOpen && drop?.status == BookDropStatus.open;
    final bool isClosed = !isDropScheduled &&
        (!schedule.isBooksOpen || (isDropMode && drop?.status == BookDropStatus.closed));

    // Color definitions
    Color accentColor;
    String statusBadge;
    String title;
    String description;
    String primaryButtonText;
    VoidCallback? onPrimaryTap;
    String? secondaryButtonText;
    VoidCallback? onSecondaryTap;

    if (isPaused) {
      accentColor = const Color(0xFFF97316); // Orange
      statusBadge = 'INQUIRIES PAUSED';
      title = 'Inquiries Currently Paused';
      description = 'Clients can view your portfolio, but cannot submit new requests. Existing sessions remain confirmed.';
      primaryButtonText = 'Resume Books';
      onPrimaryTap = () {
        ArtistDashboardRepository.resumeInquiries();
        onStatusChanged?.call();
      };
    } else if (isDropScheduled) {
      accentColor = const Color(0xFFA855F7); // Purple
      statusBadge = 'DROP SCHEDULED';
      title = drop?.title ?? 'Upcoming Booking Drop';
      final opens = drop?.opensAt;
      final opensLabel = opens != null
          ? 'Launches ${_formatLaunchDateTime(opens)}. '
          : 'Drop goes live soon. ';
      description = '${opensLabel}Waitlist members get exclusive VIP access first.';
      primaryButtonText = 'View / Edit Drop';
      onPrimaryTap = onPlanDrop;
      secondaryButtonText = 'Open Now';
      onSecondaryTap = () {
        ArtistDashboardRepository.openBooksPublicly();
        onStatusChanged?.call();
      };
    } else if (isEarlyAccess) {
      accentColor = const Color(0xFFEEC200); // Gold
      statusBadge = 'VIP EARLY ACCESS';
      title = 'VIP Waitlist Access Live';
      description = 'Your waitlist ($waitingCount contacts) has exclusive first dibs before public release.';
      primaryButtonText = 'Open to Public Now';
      onPrimaryTap = () {
        ArtistDashboardRepository.openBooksPublicly();
        onStatusChanged?.call();
      };
      secondaryButtonText = 'Review Requests ($pendingRequestsCount)';
      onSecondaryTap = onReviewRequests;
    } else if (isDropFull) {
      accentColor = const Color(0xFF38BDF8); // Sky blue
      statusBadge = 'FULLY BOOKED 🎉';
      title = 'All Booking Slots Filled';
      description = 'Every available date for this drop has been claimed. New clients can join your VIP waitlist.';
      primaryButtonText = '+ Add Extra Day';
      onPrimaryTap = onAddDays;
      secondaryButtonText = 'Close & Set Waitlist';
      onSecondaryTap = () {
        ArtistDashboardRepository.closeBooks();
        onStatusChanged?.call();
      };
    } else if (isDropLive) {
      accentColor = const Color(0xFF22C55E); // Green
      statusBadge = 'BOOKS OPEN (DROP)';
      final booked = drop?.requestCount ?? 0;
      final cap = drop?.requestCap;
      final capStr = cap != null ? '$booked of $cap spots filled' : '$booked requests received';
      title = drop?.title ?? 'December Booking Drop';
      description = '$capStr. Active until slots fill or close date.';
      primaryButtonText = pendingRequestsCount > 0
          ? 'Review Requests ($pendingRequestsCount)'
          : 'View Requests';
      onPrimaryTap = onReviewRequests;
      secondaryButtonText = '+ Add Days';
      onSecondaryTap = onAddDays;
    } else if (isAlwaysOpen) {
      accentColor = const Color(0xFF22C55E); // Green
      statusBadge = 'BOOKS OPEN';
      title = 'Accepting New Appointments';
      description = 'Clients can view available calendar dates up to 3 months ahead and submit inquiries.';
      primaryButtonText = pendingRequestsCount > 0
          ? 'Review Requests ($pendingRequestsCount)'
          : 'View Schedule';
      onPrimaryTap = onReviewRequests;
      secondaryButtonText = 'Pause Inquiries';
      onSecondaryTap = () {
        ArtistDashboardRepository.pauseInquiries();
        onStatusChanged?.call();
      };
    } else {
      // Closed / Waitlist mode
      accentColor = const Color(0xFF8C9191); // Neutral grey
      statusBadge = 'BOOKS CLOSED';
      title = 'Currently Closed to Inquiries';
      description = waitingCount > 0
          ? '$waitingCount contacts on your VIP waitlist eager for your next booking drop.'
          : 'Clients can browse your portfolio and join your waitlist for future booking drops.';
      primaryButtonText = 'Plan a Book Drop';
      onPrimaryTap = onPlanDrop;
    }

    return Container(
      key: const Key('books_status_card'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1C1C),
        borderRadius: BorderRadius.circular(AppRadius.radiusLg),
        border: Border.all(
          color: (!isClosed || isPaused || isDropScheduled) ? accentColor : const Color(0xFF282C2C),
          width: (!isClosed || isPaused || isDropScheduled) ? 1.5 : 1.0,
        ),
        boxShadow: [
          if (!isClosed || isPaused || isDropScheduled)
            BoxShadow(
              color: accentColor.withAlpha(20),
              blurRadius: 18,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Status badge & Switch/Settings
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: accentColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: accentColor.withAlpha(160),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        statusBadge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          color: accentColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  if (onOpenSettings != null) ...[
                    IconButton(
                      icon: const Icon(Icons.settings_outlined, color: Color(0xFF8C9191), size: 18),
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Schedule Settings',
                      onPressed: onOpenSettings,
                    ),
                    const SizedBox(width: 4),
                  ],
                  // Main switch for backwards-compatible test assertions
                  FlashSwitch(
                    key: const Key('books_status_switch'),
                    value: schedule.isBooksOpen && !isPaused,
                    onChanged: (val) {
                      if (!val) {
                        ArtistDashboardRepository.closeBooks();
                      } else {
                        ArtistDashboardRepository.openBooksPublicly();
                      }
                      onStatusChanged?.call();
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFFB0B6B6),
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: AppButtons.primaryCTA(
                  key: const Key('books_status_primary_cta'),
                  onPressed: onPrimaryTap ?? () {},
                  text: primaryButtonText,
                  backgroundColor: accentColor,
                  foregroundColor: accentColor == const Color(0xFFEEC200) ||
                          accentColor == const Color(0xFF22C55E)
                      ? const Color(0xFF121414)
                      : Colors.white,
                ),
              ),
              if (secondaryButtonText != null) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: AppButtons.secondaryCTA(
                    key: const Key('books_status_secondary_cta'),
                    onPressed: onSecondaryTap ?? () {},
                    text: secondaryButtonText,
                    borderColor: const Color(0xFF383C3C),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _formatLaunchDateTime(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final h = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final m = dt.minute.toString().padLeft(2, '0');
    final p = dt.hour >= 12 ? 'PM' : 'AM';
    return '${months[dt.month - 1]} ${dt.day} at $h:$m $p';
  }
}
