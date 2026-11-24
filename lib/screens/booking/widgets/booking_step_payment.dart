import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/artist.dart';
import '../../../theme/app_radius.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/flash_image.dart';
import 'booking_progress_stepper.dart';

/// Step 3 of the flash booking flow: appointment recap, deposit breakdown,
/// and Stripe checkout security notice.
class BookingStepPayment extends StatelessWidget {
  final FlashArtwork flash;
  final String artistName;
  final String artistLocation;
  final String formattedDate;
  final String selectedTimeSlot;
  final String selectedPlacement;
  final bool isSilentSession;

  const BookingStepPayment({
    super.key,
    required this.flash,
    required this.artistName,
    required this.artistLocation,
    required this.formattedDate,
    required this.selectedTimeSlot,
    required this.selectedPlacement,
    required this.isSilentSession,
  });

  @override
  Widget build(BuildContext context) {
    final deposit = flash.deposit;
    final total = flash.price;
    final balance = total - deposit;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.cardBackground,
            borderRadius: BorderRadius.circular(AppRadius.radiusLg),
            border: Border.all(color: const Color(0xFF38352A), width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.radiusSm),
                    child: SizedBox(
                      width: 50,
                      height: 50,
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
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'by $artistName',
                          style: GoogleFonts.plusJakartaSans(
                            color: AppTheme.gold,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(color: AppTheme.cardBorder, height: 24),
              BookingSummaryRow(label: 'Date', value: formattedDate),
              const SizedBox(height: 6),
              BookingSummaryRow(
                label: 'Time',
                value: '$selectedTimeSlot (${flash.estimatedTime})',
              ),
              const SizedBox(height: 6),
              BookingSummaryRow(label: 'Placement', value: selectedPlacement),
              if (isSilentSession) ...[
                const SizedBox(height: 6),
                const BookingSummaryRow(
                  label: 'Atmosphere',
                  value: 'Silent Appointment requested',
                ),
              ],
              const SizedBox(height: 6),
              BookingSummaryRow(label: 'Studio', value: artistLocation),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'PAYMENT BREAKDOWN',
          style: GoogleFonts.plusJakartaSans(
            color: AppTheme.navInactive,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.onyxContainer,
            borderRadius: BorderRadius.circular(AppRadius.radiusMd),
            border: Border.all(color: const Color(0xFF2B2F2F)),
          ),
          child: Column(
            children: [
              _buildPriceLine('Total Flash Price', '\$$total', isBold: false),
              const SizedBox(height: 8),
              _buildPriceLine(
                'Deposit Due Today',
                '\$$deposit',
                isBold: true,
                color: AppTheme.gold,
              ),
              const Divider(color: AppTheme.actionButtonBorder, height: 20),
              _buildPriceLine(
                'Balance Due at Studio',
                '\$$balance',
                isBold: false,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.cardBackground,
            borderRadius: BorderRadius.circular(AppRadius.radiusMd),
            border: Border.all(color: const Color(0xFF38352A), width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.gold.withAlpha(30),
                      borderRadius: BorderRadius.circular(AppRadius.radiusSm),
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      color: AppTheme.gold,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SECURE CHECKOUT VIA STRIPE',
                          style: GoogleFonts.plusJakartaSans(
                            color: AppTheme.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Supports Apple Pay, Cards & Link',
                          style: GoogleFonts.plusJakartaSans(
                            color: AppTheme.navInactive,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.lock_outline,
                    color: Color(0xFF22C55E),
                    size: 18,
                  ),
                ],
              ),
              const Divider(color: AppTheme.cardBorder, height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.verified_user_outlined,
                    color: AppTheme.gold,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Escrow Protection: Your \$$deposit deposit is held securely and released to $artistName only after mutual in-person check-in at your session.',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFFC0C5C5),
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.timer_outlined,
                    color: AppTheme.gold,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '10-Minute Checkout Lock: Starting checkout reserves this slot and design exclusively for you for 10 minutes so nobody can claim it while you pay.',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFFC0C5C5),
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: AppTheme.navInactive,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Remaining balance of \$$balance will be paid directly to $artistName on your appointment date.',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.navInactive,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPriceLine(
    String label,
    String value, {
    bool isBold = false,
    Color? color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: color ?? const Color(0xFFC0C5C5),
            fontSize: 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            color: color ?? AppTheme.textPrimary,
            fontSize: isBold ? 16 : 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
