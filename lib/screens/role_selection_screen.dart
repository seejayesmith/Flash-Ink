import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        decoration: BoxDecoration(
          color: const Color(0xFF1E2020),
          borderRadius: BorderRadius.circular(16),
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
                const SizedBox(width: 24), // Balance spacing
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
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.epilogue(
                color: const Color(0xFFF9FAFA),
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
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
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
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
                  const SizedBox(height: 12),
                  Text(
                    'Tell us how you\'ll be using the\nplatform so we can tailor your\nexperience.',
                    style: GoogleFonts.epilogue(
                      color: const Color(0xFF919696),
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 28),
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
                  const SizedBox(height: 12),
                  // Continue button tightly grouped directly below cards
                  ElevatedButton(
                    onPressed: _selectedRole == null ? null : _handleContinue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEEC200),
                      foregroundColor: const Color(0xFF121414),
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      disabledBackgroundColor: const Color(0xFF4D5252),
                      disabledForegroundColor: const Color(0xFF919696),
                    ),
                    child: const Text(
                      'CONTINUE',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        fontSize: 16,
                      ),
                    ),
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
