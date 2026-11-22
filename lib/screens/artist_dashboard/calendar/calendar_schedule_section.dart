import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/artist_dashboard/artist_books_schedule.dart';
import '../../../models/artist_dashboard/book_drop.dart';
import '../../../models/artist_dashboard/dashboard_appointment.dart';
import '../../../repositories/artist_dashboard_repository.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/flash_image.dart';
import '../../../widgets/flash_snack_bar.dart';
import '../../../widgets/tattoo_machine_icon.dart';
import '../appointment_detail_screen.dart';

/// Header row for the selected day's schedule, including session count badge
/// and quick time-off / force-open toggle button.
class CalendarScheduleHeader extends StatelessWidget {
  final String sectionTitle;
  final DateTime selectedDate;
  final int sessionCount;
  final String? artistId;
  final VoidCallback onBlockSelectedDate;
  final VoidCallback onScheduleMutated;

  const CalendarScheduleHeader({
    super.key,
    required this.sectionTitle,
    required this.selectedDate,
    required this.sessionCount,
    required this.artistId,
    required this.onBlockSelectedDate,
    required this.onScheduleMutated,
  });

  @override
  Widget build(BuildContext context) {
    final schedule = ArtistDashboardRepository.booksSchedule;
    final isBlocked = ArtistDashboardRepository.isDateBlocked(selectedDate);
    final isForceOpened =
        ArtistDashboardRepository.isDateForceOpened(selectedDate);
    final isWeekdayScheduled =
        schedule.workingDays.contains(selectedDate.weekday);

    IconData toggleIcon = Icons.beach_access_outlined;
    Color toggleColor = AppTheme.navInactiveAlt;
    String toggleTooltip = 'Block Date Off (Time Off)';
    if (isBlocked) {
      toggleIcon = Icons.beach_access;
      toggleColor = const Color(0xFFF97316);
      toggleTooltip = 'Unblock Date';
    } else if (!isWeekdayScheduled && !isForceOpened) {
      toggleIcon = Icons.event_available_outlined;
      toggleColor = AppTheme.gold;
      toggleTooltip = 'Open This Off-Day for Bookings';
    } else if (!isWeekdayScheduled && isForceOpened) {
      toggleIcon = Icons.event_available;
      toggleColor = const Color(0xFF22C55E);
      toggleTooltip = 'Revert to Weekly Off-Day';
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            sectionTitle,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Row(
          children: [
            if (sessionCount > 0)
              Container(
                key: const Key('calendar_session_count_badge'),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2121),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF282C2C)),
                ),
                child: Text(
                  '$sessionCount ${sessionCount == 1 ? 'session' : 'sessions'}',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.gold,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const SizedBox(width: 8),
            IconButton(
              key: const Key('calendar_toggle_time_off_button'),
              icon: Icon(
                toggleIcon,
                color: toggleColor,
                size: 20,
              ),
              tooltip: toggleTooltip,
              onPressed: () {
                if (isBlocked) {
                  ArtistDashboardRepository.unblockDate(
                    selectedDate,
                    artistId: artistId,
                  );
                  FlashSnackBar.showSuccess(context, 'Date unblocked.');
                  onScheduleMutated();
                } else if (!isWeekdayScheduled && !isForceOpened) {
                  ArtistDashboardRepository.forceOpenDate(
                    selectedDate,
                    artistId: artistId,
                  );
                  FlashSnackBar.showSuccess(
                    context,
                    'Date opened for bookings.',
                  );
                  onScheduleMutated();
                } else if (!isWeekdayScheduled && isForceOpened) {
                  ArtistDashboardRepository.revertForceOpenDate(
                    selectedDate,
                    artistId: artistId,
                  );
                  FlashSnackBar.showInfo(context, 'Returned to weekly off-day.');
                  onScheduleMutated();
                } else {
                  onBlockSelectedDate();
                }
              },
            ),
          ],
        ),
      ],
    );
  }
}

/// Renders the selected day's empty-state banner, 24h custom holds,
/// confirmed appointments, and remaining open-slot banner.
class CalendarScheduleList extends StatelessWidget {
  final DateTime selectedDate;
  final List<DashboardAppointment> appointments;
  final List<CustomHold> holds;
  final String? artistId;
  final VoidCallback onBlockSelectedDate;
  final VoidCallback onScheduleMutated;

  const CalendarScheduleList({
    super.key,
    required this.selectedDate,
    required this.appointments,
    required this.holds,
    required this.artistId,
    required this.onBlockSelectedDate,
    required this.onScheduleMutated,
  });

  @override
  Widget build(BuildContext context) {
    final schedule = ArtistDashboardRepository.booksSchedule;
    final isBlocked = ArtistDashboardRepository.isDateBlocked(selectedDate);
    final isForceOpened =
        ArtistDashboardRepository.isDateForceOpened(selectedDate);
    final isWeekdayScheduled =
        schedule.workingDays.contains(selectedDate.weekday);
    final isWeeklyCapClosed =
        ArtistDashboardRepository.isClosedByWeeklyCap(selectedDate);

    if (appointments.isEmpty && holds.isEmpty) {
      return _buildEmptyDayState(
        context,
        schedule: schedule,
        isBlocked: isBlocked,
        isForceOpened: isForceOpened,
        isWeekdayScheduled: isWeekdayScheduled,
        isWeeklyCapClosed: isWeeklyCapClosed,
      );
    }

    final openMinutes =
        ArtistDashboardRepository.getRemainingOpenMinutes(selectedDate);
    final showOpenGap = !isBlocked && openMinutes >= 30;

    return Column(
      children: [
        if (isBlocked)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF231812),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFF97316).withAlpha(90)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.beach_access,
                  color: Color(0xFFF97316),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Remaining open slots blocked for time off',
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFFF97316),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    ArtistDashboardRepository.unblockDate(
                      selectedDate,
                      artistId: artistId,
                    );
                    onScheduleMutated();
                  },
                  child: const Text('Unblock'),
                ),
              ],
            ),
          ),
        ...holds.map((hold) => _buildCustomHoldCard(context, hold)),
        ...appointments
            .map((appointment) => _buildAppointmentCard(context, appointment)),
        if (showOpenGap) _buildOpenGapCard(openMinutes),
      ],
    );
  }

  Widget _buildEmptyDayState(
    BuildContext context, {
    required ArtistBooksSchedule schedule,
    required bool isBlocked,
    required bool isForceOpened,
    required bool isWeekdayScheduled,
    required bool isWeeklyCapClosed,
  }) {
    if (isBlocked) {
      return _buildStatusCard(
        verticalPadding: 36,
        icon: Icons.beach_access,
        iconColor: const Color(0xFFF97316),
        iconSize: 36,
        title: 'Day Blocked for Time Off',
        subtitle: 'Clients cannot book or request appointments on this day.',
        action: OutlinedButton(
          onPressed: () {
            ArtistDashboardRepository.unblockDate(
              selectedDate,
              artistId: artistId,
            );
            onScheduleMutated();
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.gold,
            side: const BorderSide(color: AppTheme.gold),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Text('Unblock Day'),
        ),
      );
    }

    if (isWeeklyCapClosed) {
      return _buildStatusCard(
        verticalPadding: 32,
        icon: Icons.event_note_rounded,
        iconColor: AppTheme.gold,
        iconSize: 34,
        title: 'Weekly Cap Reached (${schedule.maxWorkingDaysPerWeek}d/wk)',
        subtitle:
            'Other booked days filled this Sun–Sat week. Empty days auto-close until slots free up.',
      );
    }

    if (!isWeekdayScheduled && !isForceOpened) {
      return _buildStatusCard(
        verticalPadding: 32,
        icon: Icons.nights_stay_outlined,
        iconColor: AppTheme.navInactiveAlt,
        iconSize: 34,
        title: 'Weekly Off Day',
        subtitle:
            'Clients cannot book on this weekday unless you open it for this date.',
        action: OutlinedButton(
          key: const Key('calendar_open_override_button'),
          onPressed: () {
            ArtistDashboardRepository.forceOpenDate(
              selectedDate,
              artistId: artistId,
            );
            onScheduleMutated();
            FlashSnackBar.showSuccess(context, 'Date opened for bookings.');
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF22C55E),
            side: const BorderSide(color: Color(0xFF22C55E)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Text('Open This Date'),
        ),
      );
    }

    return _buildStatusCard(
      verticalPadding: 36,
      icon: Icons.event_available,
      iconColor: isForceOpened
          ? const Color(0xFF22C55E)
          : AppTheme.navInactiveAlt,
      iconSize: 36,
      title: isForceOpened
          ? 'Opened for Bookings (Override)'
          : 'No appointments on this date',
      subtitle: isForceOpened
          ? 'This off-weekday is open as a special booking date.'
          : 'Enjoy your open studio time or open booking slots.',
    );
  }

  Widget _buildStatusCard({
    required double verticalPadding,
    required IconData icon,
    required Color iconColor,
    required double iconSize,
    required String title,
    required String subtitle,
    Widget? action,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: verticalPadding, horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF191B1B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF252828)),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: iconSize),
          const SizedBox(height: 12),
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.navInactiveAlt,
              fontSize: 12,
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: 14),
            action,
          ],
        ],
      ),
    );
  }

  Widget _buildCustomHoldCard(BuildContext context, CustomHold hold) {
    final remaining = hold.remainingTime;
    final expiresLabel = remaining.inHours >= 1
        ? 'Expires in ${remaining.inHours}h'
        : 'Expires in ${remaining.inMinutes.clamp(1, 59)}m';
    return Container(
      key: Key('calendar_custom_hold_${hold.id}'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1726),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFA855F7).withAlpha(120),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.hourglass_top_rounded,
                    color: Color(0xFFA855F7),
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '24H PENDING HOLD',
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFFA855F7),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFA855F7).withAlpha(30),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  expiresLabel,
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFFA855F7),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Custom Session: ${hold.clientName}',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${hold.timeSlot} • ${(hold.durationMinutes / 60).toStringAsFixed(1)} hrs held • \$${hold.deposit} deposit pending',
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.navInactive,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  ArtistDashboardRepository.releaseCustomHold(
                    hold.id,
                    artistId: artistId,
                  );
                  onScheduleMutated();
                  FlashSnackBar.showInfo(context, 'Hold released.');
                },
                child: Text(
                  'Release Hold',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.favoriteActive,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOpenGapCard(int openMinutes) {
    final openHoursText = '${(openMinutes / 60).toStringAsFixed(1)} hrs open';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF141A16),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF22C55E).withAlpha(60)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF22C55E),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    openHoursText,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onBlockSelectedDate,
            child: Text(
              '+ Block Out Time',
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

  Widget _buildAppointmentCard(
    BuildContext context,
    DashboardAppointment item,
  ) {
    return Container(
      key: Key('calendar_appointment_item_${item.id}'),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF191B1B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF252828),
          width: 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTattooThumbnail(item),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              item.clientName,
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          _buildVisitTypeBadge(item),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: item.dotColor,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              item.serviceType,
                              style: GoogleFonts.plusJakartaSans(
                                color: const Color(0xFFD1D5DB),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 14,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.access_time_rounded,
                                size: 13,
                                color: AppTheme.navInactiveAlt,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                item.time,
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '• ${item.duration}',
                                style: GoogleFonts.plusJakartaSans(
                                  color: AppTheme.navInactiveAlt,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.payments_outlined,
                                size: 13,
                                color: AppTheme.gold,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Cost: \$${item.fullPrice}',
                                style: GoogleFonts.plusJakartaSans(
                                  color: AppTheme.gold,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (item.depositPaid > 0) ...[
                                const SizedBox(width: 4),
                                Text(
                                  '(\$${item.depositPaid} dep)',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: AppTheme.navInactiveAlt,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(
              color: Color(0xFF252828),
              height: 1,
              thickness: 1,
            ),
            const SizedBox(height: 4),
            Center(
              child: TextButton(
                key: Key('calendar_view_details_btn_${item.id}'),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          AppointmentDetailScreen(appointment: item),
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.gold,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'View Details',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.gold,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTattooThumbnail(DashboardAppointment item) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 62,
        height: 62,
        decoration: BoxDecoration(
          color: const Color(0xFF222525),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppTheme.darkBorder,
            width: 1.0,
          ),
        ),
        child: item.artworkImageUrl.isNotEmpty
            ? FlashImage(
                urlOrPath: item.artworkImageUrl,
                width: 62,
                height: 62,
                fit: BoxFit.cover,
                errorWidget: _buildThumbnailFallback(item),
              )
            : _buildThumbnailFallback(item),
      ),
    );
  }

  Widget _buildThumbnailFallback(DashboardAppointment item) {
    return Container(
      width: 62,
      height: 62,
      color: const Color(0xFF222525),
      alignment: Alignment.center,
      child: item.isConsultation
          ? const Icon(
              Icons.forum_outlined,
              color: AppTheme.gold,
              size: 24,
            )
          : const TattooMachineIcon(
              size: 24,
              color: AppTheme.gold,
            ),
    );
  }

  Widget _buildVisitTypeBadge(DashboardAppointment item) {
    final isConsultation = item.isConsultation;
    final badgeColor =
        isConsultation ? AppTheme.navInactiveAlt : AppTheme.gold;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: isConsultation
            ? const Color(0xFF242727)
            : AppTheme.gold.withAlpha(28),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isConsultation
              ? const Color(0xFF383C3C)
              : AppTheme.gold.withAlpha(100),
          width: 0.8,
        ),
      ),
      child: Text(
        item.effectiveVisitType.toUpperCase(),
        style: GoogleFonts.plusJakartaSans(
          color: badgeColor,
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
