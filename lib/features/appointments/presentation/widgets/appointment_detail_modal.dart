import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../theme/app_buttons.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/flash_image.dart';
import '../../domain/models/appointment_item.dart';

/// Comprehensive modal sheet displaying complete appointment session breakdown.
class AppointmentDetailModal extends StatelessWidget {
  final ClientAppointment appointment;

  const AppointmentDetailModal({
    super.key,
    required this.appointment,
  });

  static Future<void> show(BuildContext context, ClientAppointment appointment) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AppointmentDetailModal(appointment: appointment),
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.onyxContainer,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: AppTheme.goldBorder, width: 1.2),
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.spaceLg,
        AppSpacing.spaceMd,
        AppSpacing.spaceLg,
        AppSpacing.spaceLg + bottomInset,
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
                  borderRadius: BorderRadius.circular(2),
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
                    borderRadius: BorderRadius.circular(12),
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
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
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
            _buildInfoRow(Icons.location_on_outlined, 'Studio Address', appointment.studioAddress),
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
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.darkBorder),
              ),
              child: Column(
                children: [
                  _buildPriceLine('Total Session Price', '\$${appointment.totalPrice}'),
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
            const SizedBox(height: 20),

            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Opening maps to ${appointment.studioAddress}...'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    icon: const Icon(Icons.directions, color: AppTheme.gold, size: 18),
                    label: Text(
                      'DIRECTIONS',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.gold,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.goldBorder),
                      minimumSize: const Size.fromHeight(42),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButtons.primaryCTA(
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Message sent to ${appointment.artistName} regarding reschedule.'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    text: 'CONTACT',
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
