import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/utils/maps_directions_launcher.dart';
import '../../../../models/artist_dashboard/artist_books_schedule.dart';
import '../../../../repositories/artist_dashboard_repository.dart';
import '../../../../screens/booking/touch_up_booking_screen.dart';
import '../../../../services/booking_sync_service.dart';
import '../../../../services/scheduling/touch_up_eligibility.dart';
import '../../../../services/touch_up_service.dart';
import '../../../../theme/app_buttons.dart';
import '../../../../theme/app_radius.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/adaptive_glass_container.dart';
import '../../../../widgets/flash_image.dart';
import '../../../../widgets/flash_snack_bar.dart';
import '../../../messages/domain/models/message_thread.dart';
import '../../../messages/presentation/screens/chat_conversation_screen.dart';
import '../../domain/models/appointment_item.dart';

/// Comprehensive modal sheet displaying complete appointment session breakdown,
/// including self-booked touch-up eligibility and booking for completed tattoos.
class AppointmentDetailModal extends StatefulWidget {
  final ClientAppointment appointment;
  final ArtistBooksSchedule? artistScheduleOverride;
  final List<ClientAppointment>? allAppointmentsOverride;
  final DateTime? nowOverride;
  final TouchUpService? touchUpService;

  const AppointmentDetailModal({
    super.key,
    required this.appointment,
    this.artistScheduleOverride,
    this.allAppointmentsOverride,
    this.nowOverride,
    this.touchUpService,
  });

  static Future<void> show(
    BuildContext context,
    ClientAppointment appointment, {
    ArtistBooksSchedule? artistScheduleOverride,
    List<ClientAppointment>? allAppointmentsOverride,
    DateTime? nowOverride,
    TouchUpService? touchUpService,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AppointmentDetailModal(
        appointment: appointment,
        artistScheduleOverride: artistScheduleOverride,
        allAppointmentsOverride: allAppointmentsOverride,
        nowOverride: nowOverride,
        touchUpService: touchUpService,
      ),
    );
  }

  @override
  State<AppointmentDetailModal> createState() => _AppointmentDetailModalState();
}

class _AppointmentDetailModalState extends State<AppointmentDetailModal> {
  late ArtistBooksSchedule _artistSchedule;

  ClientAppointment get appointment => widget.appointment;

  @override
  void initState() {
    super.initState();
    _artistSchedule =
        widget.artistScheduleOverride ?? ArtistDashboardRepository.booksSchedule;
    if (widget.artistScheduleOverride == null &&
        appointment.status == AppointmentStatus.completed &&
        !appointment.isTouchUp) {
      _loadRemoteArtistSchedule();
    }
  }

  Future<void> _loadRemoteArtistSchedule() async {
    final artistId = (appointment.artistId ?? '').trim();
    if (artistId.isEmpty) return;
    final fetched =
        await BookingSyncService.fetchArtistScheduleFromCloud(artistId);
    if (fetched != null && mounted) {
      setState(() => _artistSchedule = fetched);
    }
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  MessageThread? _findArtistThread() {
    final artistId = (appointment.artistId ?? '').trim();
    final lowerName = appointment.artistName.trim().toLowerCase();
    final currentUid = BookingSyncService.resolveCurrentUid('');
    final clientThreads = MessageThread.threadsForClient(currentUid);
    for (final t in clientThreads) {
      if (artistId.isNotEmpty && t.artistId.trim() == artistId) return t;
    }
    for (final t in clientThreads) {
      if (lowerName.isNotEmpty &&
          t.artistName.trim().toLowerCase() == lowerName) {
        return t;
      }
    }
    return null;
  }

  void _openChatWithArtist(BuildContext context, {String? fallbackNotice}) {
    final thread = _findArtistThread();
    Navigator.pop(context);
    if (thread != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatConversationScreen(thread: thread),
        ),
      );
    } else {
      FlashSnackBar.showInfo(
        context,
        fallbackNotice ??
            'Message ${appointment.artistName} from your Messages tab to coordinate.',
        duration: const Duration(seconds: 2),
      );
    }
  }

  Widget _buildTouchUpSection(BuildContext context) {
    final eligibility = TouchUpEligibilityService.evaluate(
      originalAppointment: appointment,
      schedule: _artistSchedule,
      allClientAppointments: widget.allAppointmentsOverride,
      now: widget.nowOverride,
    );

    if (eligibility.isEligible) {
      return Container(
        key: const Key('touch_up_eligible_section'),
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1F1C12),
          borderRadius: BorderRadius.circular(AppRadius.radiusMd),
          border: Border.all(color: AppTheme.goldBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.healing_outlined,
                  color: AppTheme.gold,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'Touch-up Available',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              eligibility.summary,
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.navInactive,
                fontSize: 12,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            AppButtons.primaryCTA(
              key: const Key('book_touch_up_button'),
              onPressed: () {
                final existingThread = _findArtistThread();
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TouchUpBookingScreen(
                      originalAppointment: appointment,
                      initialSchedule: _artistSchedule,
                      threadId: existingThread?.id,
                      touchUpService: widget.touchUpService,
                    ),
                  ),
                );
              },
              icon: Icons.event_available_outlined,
              text: eligibility.isFree
                  ? 'Book Free Touch-up'
                  : 'Book Touch-up (\$${eligibility.feeDollars})',
              backgroundColor: AppTheme.gold,
              foregroundColor: AppTheme.onyxBackground,
            ),
          ],
        ),
      );
    }

    if (eligibility.status == TouchUpEligibilityStatus.tooEarlyToHeal) {
      final unlockLabel = eligibility.availableAfter != null
          ? 'Available after ${TouchUpEligibilityService.formatShortDate(eligibility.availableAfter!)}'
          : 'Touch-up Healing Wait';
      return Container(
        key: const Key('touch_up_too_early_banner'),
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.cardBackground,
          borderRadius: BorderRadius.circular(AppRadius.radiusMd),
          border: Border.all(color: AppTheme.darkBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.hourglass_top_rounded,
                  color: AppTheme.gold,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    unlockLabel,
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.textPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              eligibility.summary,
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.navInactive,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ],
        ),
      );
    }

    if (eligibility.shouldDirectToChat) {
      return Container(
        key: const Key('touch_up_chat_only_banner'),
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.cardBackground,
          borderRadius: BorderRadius.circular(AppRadius.radiusMd),
          border: Border.all(color: AppTheme.darkBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: AppTheme.gold,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Need a Touch-up?',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.textPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              eligibility.summary,
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.navInactive,
                fontSize: 12,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            AppButtons.secondaryCTA(
              key: const Key('touch_up_message_artist_button'),
              onPressed: () => _openChatWithArtist(context),
              icon: Icons.chat_outlined,
              text: 'Message ${appointment.artistName} in Chat',
              borderColor: AppTheme.goldBorder,
              foregroundColor: AppTheme.gold,
            ),
          ],
        ),
      );
    }

    if (eligibility.status ==
        TouchUpEligibilityStatus.hasActiveUpcomingTouchUp) {
      return Container(
        key: const Key('touch_up_active_upcoming_banner'),
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.cardBackground,
          borderRadius: BorderRadius.circular(AppRadius.radiusMd),
          border: Border.all(color: AppTheme.darkBorder),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.event_repeat_rounded,
              color: AppTheme.gold,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                eligibility.summary,
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.navInactive,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveGlassContainer.bottomSheet(
      glassEnabled: false,
      androidSurfaceColor: AppTheme.onyxContainer,
      selectedBorderColor: AppTheme.goldBorder,
      unselectedBorderColor: AppTheme.goldBorder,
      selectedBorderWidth: 1.2,
      unselectedBorderWidth: 1.2,
      topRadius: AppRadius.radiusSheet,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.spaceLg,
        AppSpacing.spaceMd,
        AppSpacing.spaceLg,
        AppSpacing.spaceLg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.darkBorder,
                  borderRadius: BorderRadius.circular(AppRadius.dragHandle),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Top Status & Ref Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  appointment.id,
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.gold,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: appointment.status == AppointmentStatus.confirmed
                        ? const Color(0xFF1E2E20)
                        : AppTheme.onyxSurface,
                    borderRadius: BorderRadius.circular(AppRadius.radiusSm),
                    border: Border.all(
                      color: appointment.status == AppointmentStatus.confirmed
                          ? const Color(0xFF4ADE80)
                          : AppTheme.darkBorder,
                    ),
                  ),
                  child: Text(
                    appointment.status.label.toUpperCase(),
                    style: GoogleFonts.plusJakartaSans(
                      color: appointment.status == AppointmentStatus.confirmed
                          ? const Color(0xFF4ADE80)
                          : AppTheme.navInactive,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Artwork & Artist Card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.cardBackground,
                borderRadius: BorderRadius.circular(AppRadius.radiusMd),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.radiusSm),
                    child: SizedBox(
                      width: 58,
                      height: 58,
                      child: FlashImage(
                        urlOrPath: appointment.flashImageUrl,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appointment.flashTitle,
                          style: GoogleFonts.plusJakartaSans(
                            color: AppTheme.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Artist: ${appointment.artistName}',
                          style: GoogleFonts.plusJakartaSans(
                            color: AppTheme.gold,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          appointment.studioName,
                          style: GoogleFonts.plusJakartaSans(
                            color: AppTheme.navInactive,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Session Logistics
            _buildInfoRow(Icons.calendar_today_outlined, 'Date & Time',
                '${_formatDate(appointment.dateTime)} at ${appointment.timeSlot}'),
            const SizedBox(height: 10),
            _buildInfoRow(
              appointment.isExactLocationUnlocked()
                  ? Icons.location_on_outlined
                  : Icons.lock_clock_outlined,
              'Studio Address',
              appointment.effectiveStudioAddress(),
            ),
            const SizedBox(height: 10),
            _buildInfoRow(Icons.pan_tool_outlined, 'Placement', appointment.placement),
            if (appointment.isSilentAppointment) ...[
              const SizedBox(height: 10),
              _buildInfoRow(Icons.volume_off_outlined, 'Session Type', 'Silent Appointment requested'),
            ],
            const SizedBox(height: 16),

            // Financial Summary
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.cardBackground,
                borderRadius: BorderRadius.circular(AppRadius.radiusMd),
                border: Border.all(color: AppTheme.darkBorder),
              ),
              child: appointment.isTouchUp && appointment.totalPrice <= 0
                  ? _buildPriceLine(
                      'Touch-up Session',
                      'Complimentary (\$0)',
                      color: const Color(0xFF4ADE80),
                      isBold: true,
                    )
                  : Column(
                      children: [
                        _buildPriceLine(
                          'Total Session Price',
                          '\$${appointment.totalPrice}',
                        ),
                        const SizedBox(height: 6),
                        _buildPriceLine(
                          'Deposit Paid',
                          '\$${appointment.depositAmount}',
                          color: AppTheme.gold,
                          isBold: true,
                        ),
                        const Divider(color: AppTheme.darkBorder, height: 16),
                        _buildPriceLine(
                          'Remaining Balance Due at Studio',
                          '\$${appointment.balanceDue}',
                          isBold: true,
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 16),

            // Self-Booked Touch-Up Section (Completed Original Tattoos Only)
            if (appointment.status == AppointmentStatus.completed &&
                !appointment.isTouchUp)
              _buildTouchUpSection(context),

            // Actions
            Row(
              children: [
                Expanded(
                  child: AppButtons.secondaryCTA(
                    onPressed: () async {
                      if (!appointment.isExactLocationUnlocked()) {
                        Navigator.pop(context);
                        FlashSnackBar.showInfo(
                          context,
                          'Exact studio address unlocks 24 hours before your confirmed session.',
                          duration: const Duration(seconds: 2),
                        );
                        return;
                      }
                      await MapsDirectionsLauncher.openDirections(
                        context,
                        address: appointment.studioAddress,
                        studioName: appointment.studioName,
                      );
                    },
                    icon: Icons.directions,
                    text: 'Directions',
                    borderColor: AppTheme.goldBorder,
                    foregroundColor: AppTheme.gold,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButtons.primaryCTA(
                    onPressed: () => _openChatWithArtist(
                      context,
                      fallbackNotice:
                          'Message sent to ${appointment.artistName} regarding reschedule.',
                    ),
                    text: 'Contact',
                    backgroundColor: AppTheme.gold,
                    foregroundColor: AppTheme.onyxBackground,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppTheme.gold, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.navInactive,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.textPrimary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPriceLine(String label, String value, {bool isBold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: color ?? AppTheme.navInactive,
            fontSize: 12,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            color: color ?? AppTheme.textPrimary,
            fontSize: isBold ? 14 : 12,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
