import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_radius.dart';
import '../../../theme/app_theme.dart';

/// Step 2 of the flash booking flow: client contact details and studio policy agreement.
class BookingStepDetails extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final TextEditingController emailController;
  final TextEditingController notesController;
  final bool isUserPhoneVerified;
  final bool agreedToPolicies;
  final VoidCallback onFieldChanged;
  final VoidCallback onVerifyPhoneTap;
  final ValueChanged<bool> onAgreedChanged;

  const BookingStepDetails({
    super.key,
    required this.nameController,
    required this.phoneController,
    required this.emailController,
    required this.notesController,
    required this.isUserPhoneVerified,
    required this.agreedToPolicies,
    required this.onFieldChanged,
    required this.onVerifyPhoneTap,
    required this.onAgreedChanged,
  });

  static const List<String> _policies = [
    'Deposits are non-refundable and credited toward your session balance.',
    '48-hour advance notice is required to reschedule your appointment.',
    'A valid government-issued photo ID (18+) is required at the studio.',
    'Please arrive well-rested, hydrated, and within 10 minutes of start time.',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CLIENT INFORMATION',
          style: GoogleFonts.plusJakartaSans(
            color: AppTheme.navInactive,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 12),
        _buildInputField(
          controller: nameController,
          label: 'Full Legal Name',
          icon: Icons.person_outline,
        ),
        const SizedBox(height: 12),
        _buildInputField(
          controller: phoneController,
          label: 'Phone Number (for SMS reminders)',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
        ),
        if (!isUserPhoneVerified) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.info_outline, size: 14, color: AppTheme.gold),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'A verified phone number is required to book.',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.gold,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              TextButton(
                key: const Key('booking_verify_phone_link'),
                onPressed: onVerifyPhoneTap,
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  '+ Verify',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.gold,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        _buildInputField(
          controller: emailController,
          label: 'Email Address (for receipt & prep guide)',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 12),
        _buildInputField(
          controller: notesController,
          label: 'Special Notes or Allergies (optional)',
          icon: Icons.note_outlined,
          maxLines: 2,
        ),
        const SizedBox(height: 24),
        Text(
          'STUDIO POLICIES & TERMS',
          style: GoogleFonts.plusJakartaSans(
            color: AppTheme.navInactive,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        _buildPoliciesCard(),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () => onAgreedChanged(!agreedToPolicies),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: agreedToPolicies,
                onChanged: (val) => onAgreedChanged(val ?? false),
                activeColor: AppTheme.gold,
                checkColor: AppTheme.onyxBackground,
                side: const BorderSide(color: Color(0xFF4D5252), width: 1.5),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    'I confirm I am 18+ years old and agree to the studio deposit and cancellation policies.',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.textPrimary,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      onChanged: (_) => onFieldChanged(),
      style: GoogleFonts.plusJakartaSans(
        color: AppTheme.textPrimary,
        fontSize: 14,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.plusJakartaSans(
          color: AppTheme.navInactive,
          fontSize: 13,
        ),
        prefixIcon: Icon(icon, color: AppTheme.gold, size: 20),
        filled: true,
        fillColor: AppTheme.cardBackground,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.radiusSm),
          borderSide: const BorderSide(color: AppTheme.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.radiusSm),
          borderSide: const BorderSide(color: AppTheme.gold, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  Widget _buildPoliciesCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.radiusMd),
        border: Border.all(color: const Color(0xFF2B2F2F)),
      ),
      child: Column(
        children: _policies.map((policy) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  color: Color(0xFF4ADE80),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    policy,
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
        }).toList(),
      ),
    );
  }
}
