import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// A minimal, subtle outlined pill button displaying "Skip", intended for
/// the top right of onboarding screens.
class SkipPillButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String text;

  const SkipPillButton({
    Key? key,
    required this.onPressed,
    this.text = 'Skip',
  }) : super(key: key ?? const Key('onboarding_skip_button'));

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        side: const BorderSide(
          color: Color(0x38FFFFFF), // Subtle translucent white outline
          width: 1.0,
        ),
        foregroundColor: const Color(0xFFD8DDDD), // Soft off-white text
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
          color: const Color(0xFFD8DDDD),
        ),
      ),
    );
  }
}
