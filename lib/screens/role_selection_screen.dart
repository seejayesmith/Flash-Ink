import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_spacing.dart';
import '../theme/app_buttons.dart';
import '../widgets/adaptive_glass_container.dart';
import '../config/dev_config.dart';
import 'account_creation_screen.dart';
import 'artist_onboarding/artist_sign_up_screen.dart';
import 'artist_onboarding/artist_profile_photo_screen.dart';
import 'profile_setup_screen.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  String? _selectedRole = 'client'; // Default selection per design

  void _handleContinue() {
    if (_selectedRole == null) return;

    if (_selectedRole == 'artist') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const ArtistSignUpScreen(),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AccountCreationScreen(role: _selectedRole!),
        ),
      );
    }
  }

  Widget _buildRoleCard({
    required String role,
    required String title,
    required String description,
    required IconData icon,
  }) {
    final isSelected = _selectedRole == role;
    return AdaptiveGlassContainer(
      margin: const EdgeInsets.only(bottom: AppSpacing.spaceMd),
      padding: const EdgeInsets.all(AppSpacing.spaceLg),
      borderRadius: 16.0,
      isSelected: isSelected,
      onTap: () => setState(() => _selectedRole = role),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(width: 24), // Balance radio icon spacing
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFFEEC200)
                      : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFEEC200), width: 2),
                ),
                child: Icon(
                  icon,
                  color: isSelected
                      ? const Color(0xFF121414)
                      : const Color(0xFFEEC200),
                  size: 30,
                ),
              ),
              Icon(
                isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: isSelected
                    ? const Color(0xFFEEC200)
                    : const Color(0xFF4D5252),
                size: 24,
              ),
            ],
          ),
          AppGaps.gapMd,
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFFF9FAFA),
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          AppGaps.gapXs,
          Text(
            description,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              color: const Color(
                0xFFD8DDDD,
              ), // Brightened for high contrast readability
              fontSize: 14,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Prevent popping back to splash
      child: Scaffold(
        backgroundColor: const Color(0xFF121414),
        body: Stack(
          children: [
            // Background tattoo setup texture - clear and vibrant
            Positioned.fill(
              child: Image.asset(
                'assets/images/tattoo_setup.png',
                fit: BoxFit.cover,
                cacheWidth: 1080,
              ),
            ),
            // Gentle gradient overlay: dark at top for text readability, subtle dark scrim over bright tray sections
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withAlpha(240), // Top dark for title text
                      Colors.black.withAlpha(140),
                      Colors.black.withAlpha(
                        100,
                      ), // Soft scrim over white paper towel area
                      Colors.black.withAlpha(160), // Subtle bottom gradient
                    ],
                    stops: const [0.0, 0.20, 0.50, 1.0],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: IntrinsicHeight(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.spaceLg,
                            vertical: AppSpacing.spaceLg,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (kEnableDevBypass) ...[
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Spacer(),
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        if (_selectedRole == 'artist') {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => const ArtistProfilePhotoScreen(artistName: 'OddMaree'),
                                            ),
                                          );
                                        } else {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(builder: (_) => const ProfileSetupScreen()),
                                          );
                                        }
                                      },
                                      icon: const Icon(Icons.fast_forward, size: 16, color: Color(0xFF121414)),
                                      label: Text(
                                        'Skip (Dev)',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF121414),
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFEEC200),
                                        foregroundColor: const Color(0xFF121414),
                                        elevation: 2,
                                        shape: const StadiumBorder(),
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                              ],
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Let\'s get started.',
                                  maxLines: 1,
                                  style: GoogleFonts.plusJakartaSans(
                                    color: const Color(0xFFF9FAFA),
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    height: 1.15,
                                  ),
                                ),
                              ),
                              AppGaps.gapSm,
                              Text(
                                'Tell us how you\'ll be using the\nplatform so we can tailor your\nexperience.',
                                style: GoogleFonts.plusJakartaSans(
                                  color: const Color(0xFF919696),
                                  fontSize: 15,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.spaceXl),
                              // Adaptive Glass / Material Role Cards
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
                              const Spacer(),
                              AppGaps.gapMd,
                              // Continue button pinned to the bottom dynamically
                              AppButtons.primaryCTA(
                                onPressed: _selectedRole == null
                                    ? null
                                    : _handleContinue,
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
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
