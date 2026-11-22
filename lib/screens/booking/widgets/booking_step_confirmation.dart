import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/artist.dart';
import '../../../theme/app_buttons.dart';
import '../../../theme/app_radius.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/flash_image.dart';
import 'booking_progress_stepper.dart';

/// Step 4 of the flash booking flow: confirmation badge, appointment recap,
/// calendar export CTA, and session prep guidelines.
class BookingStepConfirmation extends StatelessWidget {
  final FlashArtwork flash;
  final String artistName;
  final String artistLocation;
  final String confirmationCode;
  final String formattedDate;
  final String selectedTimeSlot;
  final String selectedPlacement;
  final String selectedPaymentMethod;
  final bool addedToCalendar;
  final bool isAddingToCalendar;
  final VoidCallback onAddToCalendar;
  final VoidCallback onDone;

  const BookingStepConfirmation({
    super.key,
    required this.flash,
    required this.artistName,
    required this.artistLocation,
    required this.confirmationCode,
    required this.formattedDate,
    required this.selectedTimeSlot,
    required this.selectedPlacement,
    required this.selectedPaymentMethod,
    required this.addedToCalendar,
    required this.isAddingToCalendar,
    required this.onAddToCalendar,
    required this.onDone,
  });

  static const List<String> _prepTips = [
    'Hydrate thoroughly & eat a solid meal 1-2 hours before.',
    'Bring valid 18+ government photo ID to the studio.',
    'Avoid alcohol or blood thinners for 24 hours prior.',
    'Wear loose, comfortable clothes for easy placement access.',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 10),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.goldBadgeBackground,
            border: Border.all(color: AppTheme.gold, width: 2),
            boxShadow: [
              BoxShadow(
                color: AppTheme.gold.withAlpha(40),
                blurRadius: 20,
                spreadRadius: 4,
              ),
            ],
          ),
          child: const Center(
            child: Icon(Icons.check, color: AppTheme.gold, size: 44),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Flash Claimed & Booked!',
          style: GoogleFonts.plusJakartaSans(
            color: AppTheme.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Ref: $confirmationCode',
          style: GoogleFonts.plusJakartaSans(
            color: AppTheme.gold,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'A confirmation email and SMS receipt have been sent.',
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            color: AppTheme.navInactive,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.cardBackground,
            borderRadius: BorderRadius.circular(AppRadius.radiusLg),
            border: Border.all(color: AppTheme.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.radiusSm),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: FlashImage(
                        urlOrPath: flash.imageUrl,
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
                          flash.title,
                          style: GoogleFonts.plusJakartaSans(
                            color: AppTheme.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Artist: $artistName',
                          style: GoogleFonts.plusJakartaSans(
                            color: AppTheme.gold,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(color: AppTheme.cardBorder, height: 20),
              BookingSummaryRow(label: 'Date', value: formattedDate),
              const SizedBox(height: 6),
              BookingSummaryRow(label: 'Time Slot', value: selectedTimeSlot),
              const SizedBox(height: 6),
              BookingSummaryRow(label: 'Placement', value: selectedPlacement),
              const SizedBox(height: 6),
              BookingSummaryRow(
                label: 'Studio Location',
                value: artistLocation,
              ),
              const SizedBox(height: 6),
              BookingSummaryRow(
                label: 'Deposit Paid',
                value: '\$${flash.deposit} ($selectedPaymentMethod)',
              ),
              const SizedBox(height: 6),
              BookingSummaryRow(
                label: 'Balance at Appointment',
                value: '\$${flash.price - flash.deposit}',
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          key: const Key('confirmation_add_to_calendar_button'),
          onPressed: isAddingToCalendar ? null : onAddToCalendar,
          icon: isAddingToCalendar
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.gold,
                  ),
                )
              : Icon(
                  addedToCalendar
                      ? Icons.check_circle_rounded
                      : Icons.calendar_month,
                  color: addedToCalendar
                      ? const Color(0xFF4ADE80)
                      : AppTheme.gold,
                  size: 18,
                ),
          label: Text(
            addedToCalendar ? 'Added to Calendar' : 'Add to Calendar',
            style: GoogleFonts.plusJakartaSans(
              color: addedToCalendar
                  ? const Color(0xFF4ADE80)
                  : AppTheme.gold,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
          style: OutlinedButton.styleFrom(
            backgroundColor: addedToCalendar
                ? const Color(0x1F4ADE80)
                : Colors.transparent,
            side: BorderSide(
              color: addedToCalendar
                  ? const Color(0xFF4ADE80)
                  : AppTheme.gold,
            ),
            minimumSize: const Size.fromHeight(44),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.radiusMd),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1D1D),
            borderRadius: BorderRadius.circular(AppRadius.radiusMd),
            border: Border.all(color: AppTheme.statDivider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SESSION PREPARATION TIPS',
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.gold,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),
              ..._prepTips.map(_buildPrepItem),
            ],
          ),
        ),
        const SizedBox(height: 24),
        AppButtons.primaryCTA(
          onPressed: onDone,
          text: 'Done',
          backgroundColor: AppTheme.gold,
          foregroundColor: AppTheme.onyxBackground,
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildPrepItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.arrow_right, color: AppTheme.gold, size: 18),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFFC0C5C5),
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
