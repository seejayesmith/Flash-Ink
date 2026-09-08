import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ArtistStepperHeader extends StatelessWidget {
  final int currentStep; // 1: Setup account, 2: Create profile, 3: Share link

  const ArtistStepperHeader({
    super.key,
    required this.currentStep,
  });

  Widget _buildStepCircle(int stepNumber) {
    final isCompleted = currentStep > stepNumber;
    final isActive = currentStep == stepNumber;

    Color bgColor;
    Widget content;

    if (isCompleted) {
      bgColor = const Color(0xFFEEC200);
      content = const Icon(
        Icons.check,
        size: 20,
        color: Color(0xFF121414),
      );
    } else if (isActive) {
      bgColor = const Color(0xFFEEC200);
      content = Text(
        '$stepNumber',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF121414),
        ),
      );
    } else {
      bgColor = const Color(0xFF383C3C);
      content = Text(
        '$stepNumber',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF8C9191),
        ),
      );
    }

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: content,
    );
  }

  Widget _buildStepItem({
    required int stepNumber,
    required String label,
  }) {
    final isUpcoming = currentStep < stepNumber;
    return SizedBox(
      width: 68,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildStepCircle(stepNumber),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              height: 1.2,
              fontWeight: isUpcoming ? FontWeight.w500 : FontWeight.w700,
              color: isUpcoming ? const Color(0xFF8C9191) : const Color(0xFFF9FAFA),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepItem(stepNumber: 1, label: 'Setup\nyour\naccount'),
          Padding(
            padding: const EdgeInsets.only(top: 17),
            child: SizedBox(
              width: 54,
              child: Container(
                height: 2,
                color: currentStep > 1 ? const Color(0xFFEEC200) : const Color(0xFF383C3C),
              ),
            ),
          ),
          _buildStepItem(stepNumber: 2, label: 'Create\nyour\nprofile'),
          Padding(
            padding: const EdgeInsets.only(top: 17),
            child: SizedBox(
              width: 54,
              child: Container(
                height: 2,
                color: currentStep > 2 ? const Color(0xFFEEC200) : const Color(0xFF383C3C),
              ),
            ),
          ),
          _buildStepItem(stepNumber: 3, label: 'Share\nyour\nlink'),
        ],
      ),
    );
  }
}
