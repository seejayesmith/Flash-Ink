import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_spacing.dart';
import '../theme/app_radius.dart';
import '../theme/app_buttons.dart';
import 'account_creation_screen.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  String? _selectedRole = 'client'; // Default selection per design

  void _handleContinue() {
    if (_selectedRole == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AccountCreationScreen(role: _selectedRole!),
      ),
    );
  }

  Widget _buildRoleCard({
    required String role,
    required String title,
    required String description,
    required IconData icon,
  }) {
    final isSelected = _selectedRole == role;
    return GestureDetector(
      onTap: () => setState(() => _selectedRole = role),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: AppSpacing.spaceMd),
        padding: const EdgeInsets.all(AppSpacing.spaceLg),
        decoration: BoxDecoration(
          color: const Color(0xFF1E2020),
          borderRadius: AppBorderRadius.lg,
          border: Border.all(
            color: isSelected ? const Color(0xFFEEC200) : const Color(0xFF262929),
            width: isSelected ? 2.5 : 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFFEEC200).withAlpha(30),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppGaps.gapLg, // Balance spacing
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFEEC200) : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFEEC200),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: isSelected ? const Color(0xFF121414) : const Color(0xFFEEC200),
                    size: 30,
                  ),
                ),
                Icon(
                  isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: isSelected ? const Color(0xFFEEC200) : const Color(0xFF4D5252),
                  size: 24,
                ),
              ],
            ),
            AppGaps.gapMd,
            Text(
              title,
              style: GoogleFonts.epilogue(
                color: const Color(0xFFF9FAFA),
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            AppGaps.gapXs,
            Text(
              description,
              textAlign: TextAlign.center,
              style: GoogleFonts.epilogue(
                color: const Color(0xFF919696),
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Prevent popping back to splash
      child: Scaffold(
        backgroundColor: const Color(0xFF121414),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.spaceLg,
                vertical: AppSpacing.spaceLg,
              ),
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Let\'s get\nstarted.',
                    style: GoogleFonts.epilogue(
                      color: const Color(0xFFF9FAFA),
                      fontSize: 38,
                      fontWeight: FontWeight.bold,
                      height: 1.15,
                    ),
                  ),
                  AppGaps.gapSm,
                  Text(
                    'Tell us how you\'ll be using the\nplatform so we can tailor your\nexperience.',
                    style: GoogleFonts.epilogue(
                      color: const Color(0xFF919696),
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.spaceXl),
                  // Grouped Role Cards
                  _buildRoleCard(
                    role: 'client',
                    title: 'I get tattoos',
                    description:
                        'Discover artists, book\nappointments, and build your\ncollection.',
                    icon: Icons.favorite,
                  ),
                  _buildRoleCard(
                    role: 'artist',
                    title: 'I make tattoos',
                    description:
                        'Manage bookings, showcase your\nportfolio, and connect with\nclients.',
                    icon: Icons.brush,
                  ),
                  AppGaps.gapSm,
                  // Continue button tightly grouped directly below cards
                  AppButtons.primaryCTA(
                    onPressed: _selectedRole == null ? null : _handleContinue,
                    text: 'CONTINUE',
                    backgroundColor: _selectedRole == null
                        ? const Color(0xFF4D5252)
                        : const Color(0xFFEEC200),
                    foregroundColor: _selectedRole == null
                        ? const Color(0xFF919696)
                        : const Color(0xFF121414),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
