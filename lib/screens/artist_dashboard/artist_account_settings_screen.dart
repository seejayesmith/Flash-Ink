import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/adaptive_glass_container.dart';
import '../../widgets/flash_glass_app_bar.dart';

class ArtistAccountSettingsScreen extends StatelessWidget {
  final String email;
  final VoidCallback? onDeleteAccount;

  const ArtistAccountSettingsScreen({
    super.key,
    required this.email,
    this.onDeleteAccount,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121414),
      extendBodyBehindAppBar: true,
      appBar: FlashGlassAppBar(
        title: Text(
          'Account Settings',
          key: const Key('account_settings_modal_title'),
          style: GoogleFonts.plusJakartaSans(
            color: AppTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          SizedBox(
            height: MediaQuery.paddingOf(context).top + kToolbarHeight,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.spaceLg,
                16,
                AppSpacing.spaceLg,
                MediaQuery.paddingOf(context).bottom + 12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Manage security credentials, primary email, and irreversible account actions.',
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF919696),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              AdaptiveGlassContainer(
                useGradient: false,
                borderRadius: 16.0,
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.alternate_email, color: AppTheme.gold),
                      title: Text(
                        'Primary Account Email',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      subtitle: Text(
                        email,
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF919696),
                          fontSize: 13,
                        ),
                      ),
                      trailing: const Icon(Icons.lock_outline, color: Color(0xFF6B7280), size: 16),
                    ),
                    const Divider(color: AppTheme.darkBorder, height: 1),
                    ListTile(
                      leading: const Icon(Icons.shield_outlined, color: AppTheme.gold),
                      title: Text(
                        'Artist Verification Status',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      subtitle: Text(
                        'Verified Resident Tattooer',
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF22C55E),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      trailing: const Icon(Icons.check_circle, color: Color(0xFF22C55E), size: 18),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'DANGER ZONE',
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFFEF4444),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              Material(
                color: const Color(0xFF1A1212),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: const Color(0xFFEF4444).withAlpha(100), width: 1),
                ),
                child: ListTile(
                  key: const Key('delete_account_button'),
                  leading: const Icon(Icons.delete_forever_outlined, color: Color(0xFFEF4444)),
                  title: Text(
                    'Delete Account',
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFFEF4444),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    'Permanently delete your artist portfolio, bookings, and profile data',
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFFB06060),
                      fontSize: 12,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: Color(0xFFEF4444), size: 20),
                  onTap: () {
                    Navigator.pop(context);
                    if (onDeleteAccount != null) {
                      onDeleteAccount!();
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  ),
);
  }
}
