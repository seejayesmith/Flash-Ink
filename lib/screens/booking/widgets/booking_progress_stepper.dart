import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_radius.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_theme.dart';

/// Four-step progress header displayed at the top of the flash booking flow.
class BookingProgressStepper extends StatelessWidget {
  final int currentStep;

  const BookingProgressStepper({
    super.key,
    required this.currentStep,
  });

  static const List<String> _steps = [
    'Date & Time',
    'Details',
    'Payment',
    'Confirmed',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('booking_progress_stepper'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenGutter,
        vertical: 12,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.onyxBackground,
        border: Border(
          bottom: BorderSide(color: AppTheme.cardBorder, width: 1),
        ),
      ),
      child: Row(
        children: List.generate(_steps.length, (index) {
          final isPast = index < currentStep;
          final isCurrent = index == currentStep;
          final isLast = index == _steps.length - 1;

          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: isPast || isCurrent
                              ? AppTheme.gold
                              : const Color(0xFF2E3333),
                          borderRadius:
                              BorderRadius.circular(AppRadius.dragHandle),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _steps[index],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          color: isCurrent
                              ? AppTheme.gold
                              : (isPast
                                  ? AppTheme.textPrimary
                                  : const Color(0xFF6B7272)),
                          fontSize: 10,
                          fontWeight:
                              isCurrent ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isLast) const SizedBox(width: 8),
              ],
            ),
          );
        }),
      ),
    );
  }
}

/// Key-value summary row shared across the payment review and confirmation cards.
class BookingSummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const BookingSummaryRow({
    super.key,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: AppTheme.navInactive,
            fontSize: 12,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            color: AppTheme.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
