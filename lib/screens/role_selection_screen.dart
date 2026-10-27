import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_spacing.dart';
import '../theme/app_buttons.dart';
import '../widgets/adaptive_glass_container.dart';
import '../widgets/flash_glass_app_bar.dart';
import '../services/auth_service.dart';
import 'account_creation_screen.dart';

class RoleSelectionScreen extends StatefulWidget {
  final AuthService? authService;

  const RoleSelectionScreen({super.key, this.authService});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  String? _selectedRole; // Must be explicitly selected by the user

  void _handleContinue() {
    if (_selectedRole == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AccountCreationScreen(
          role: _selectedRole!,
          authService: widget.authService,
        ),
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
    return AdaptiveGlassContainer(
      margin: EdgeInsets.only(bottom: role == 'artist' ? 0 : AppSpacing.spaceMd),
      padding: AppPadding.card,
      borderRadius: 16.0,
      isSelected: isSelected,
      useGradient: false,
      unselectedBaseTintAlpha: 55, // Increased transparency for authentic glass refraction (~21% opacity)
      selectedBaseTintAlpha: 85,   // Tactile depth while slightly more transparent (~33% opacity)
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
      canPop: true,
      child: Scaffold(
        backgroundColor: const Color(0xFF121414),
        extendBodyBehindAppBar: true,
        resizeToAvoidBottomInset: false,
        appBar: FlashGlassAppBar(
          showBackButton: true,
          onBackPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          },
        ),
        body: Stack(
          children: [
            // Background tattoo setup texture - clear and vibrant pinned to full screen
            Positioned(
              top: 0,
              left: 0,
              width: MediaQuery.sizeOf(context).width,
              height: MediaQuery.sizeOf(context).height,
              child: Image.asset(
                'assets/images/tattoo_setup.png',
                fit: BoxFit.cover,
                cacheWidth: 1080,
              ),
            ),
            // Gentle gradient overlay: dark at top for text readability, subtle dark scrim over bright tray sections
            Positioned(
              top: 0,
              left: 0,
              width: MediaQuery.sizeOf(context).width,
              height: MediaQuery.sizeOf(context).height,
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
            Column(
              children: [
                // Spacing for extended transparent app bar
                SizedBox(
                  height: MediaQuery.paddingOf(context).top + kToolbarHeight,
                ),

                // Content area: top-aligned header, centered route options container
                Expanded(
                  child: MediaQuery.removePadding(
                    context: context,
                    removeTop: true,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.screenMargin,
                          ),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: constraints.maxHeight,
                            ),
                            child: IntrinsicHeight(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const SizedBox(height: 12),
                                  Text(
                                    "Let's get started.",
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 34,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFFF9FAFA),
                                      height: 1.15,
                                    ),
                                  ),
                                  AppGaps.headerTitleSubtitle,
                                  Text(
                                    "Tell us how you'll be using the platform so we can tailor your experience.",
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 15,
                                      color: const Color(0xFF919696),
                                      height: 1.4,
                                    ),
                                  ),

                                  // Spacer to center the route options container
                                  const SizedBox(height: 38),
                                  const Spacer(),

                                  // Centered route options container
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
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
                                    ],
                                  ),

                                  // Spacer to balance the vertical negative space
                                  const Spacer(),
                                  const SizedBox(height: 12),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // Anchored bottom CTA button
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.screenMargin,
                    12,
                    AppSpacing.screenMargin,
                    MediaQuery.paddingOf(context).bottom +
                        AppSpacing.ctaBottomPadding,
                  ),
                  child: AppButtons.primaryCTA(
                    onPressed: _selectedRole == null ? null : _handleContinue,
                    text: 'CONTINUE',
                    backgroundColor: _selectedRole == null
                        ? const Color(0xFF4D5252)
                        : const Color(0xFFEEC200),
                    foregroundColor: _selectedRole == null
                        ? const Color(0xFF919696)
                        : const Color(0xFF121414),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
