import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/flash_image.dart';
import '../../domain/models/appointment_item.dart';
import 'appointment_detail_modal.dart';

/// Reusable appointment card displaying session details, deposit status, and artist metadata.
class AppointmentCard extends StatelessWidget {
  final ClientAppointment appointment;
  final VoidCallback? onTap;

  const AppointmentCard({
    super.key,
    required this.appointment,
    this.onTap,
  });

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isConfirmed = appointment.status == AppointmentStatus.confirmed;

    return GestureDetector(
      onTap: onTap ?? () => AppointmentDetailModal.show(context, appointment),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardBackground,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isConfirmed ? AppTheme.goldBorder : AppTheme.cardBorder,
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(90),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Date & Status Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.event, color: AppTheme.gold, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      _formatDate(appointment.dateTime),
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isConfirmed ? const Color(0xFF1E2E20) : AppTheme.onyxContainer,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isConfirmed ? const Color(0xFF4ADE80) : AppTheme.darkBorder,
                    ),
                  ),
                  child: Text(
                    appointment.status.label.toUpperCase(),
                    style: GoogleFonts.plusJakartaSans(
                      color: isConfirmed ? const Color(0xFF4ADE80) : AppTheme.navInactive,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(color: AppTheme.darkBorder, height: 20),

            // Artwork & Artist Details
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 52,
                    height: 52,
                    child: FlashImage(
                      urlOrPath: appointment.flashImageUrl,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appointment.flashTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'with ${appointment.artistName} • ${appointment.studioName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.gold,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${appointment.timeSlot} • ${appointment.placement}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.navInactive,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppTheme.navInactive, size: 20),
              ],
            ),
            const SizedBox(height: 12),

            // Financial Summary Pills
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      'Deposit: ',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.navInactive,
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      '\$${appointment.depositAmount} Paid',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.gold,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Text(
                  'Due: \$${appointment.balanceDue}',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
