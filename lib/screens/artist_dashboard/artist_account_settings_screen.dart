import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/adaptive_glass_container.dart';
import '../../widgets/flash_glass_app_bar.dart';
import '../../widgets/flash_snack_bar.dart';
import '../../widgets/reauthentication_bottom_sheet.dart';
import '../../services/auth_service.dart';
import '../../providers/app_providers.dart';
import '../splash_screen.dart';

class ArtistAccountSettingsScreen extends StatefulWidget {
  final String email;
  final AuthService? authService;
  final FutureOr<void> Function()? onDeleteAccount;

  const ArtistAccountSettingsScreen({
    super.key,
    required this.email,
    this.authService,
    this.onDeleteAccount,
  });

  @override
  State<ArtistAccountSettingsScreen> createState() => _ArtistAccountSettingsScreenState();
}

class _ArtistAccountSettingsScreenState extends State<ArtistAccountSettingsScreen> {
  late final AuthService _authService = widget.authService ?? AuthService();
  bool _isDeleting = false;

  Future<void> _handleDeleteAccount() async {
    if (_isDeleting) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        bool dialogDismissed = false;
        return AlertDialog(
          key: const Key('delete_account_dialog'),
          backgroundColor: const Color(0xFF1E2020),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFEF4444), width: 1.2),
          ),
          title: Text(
            'Delete Account',
            key: const Key('delete_account_modal_title'),
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFFF9FAFA),
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          content: Text(
            'Are you sure you want to delete your account? This action cannot be undone.',
            key: const Key('delete_account_modal_message'),
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFF919696),
              fontSize: 14,
              height: 1.4,
            ),
          ),
          actionsAlignment: MainAxisAlignment.spaceEvenly,
          actions: [
            TextButton(
              key: const Key('delete_account_cancel_button'),
              onPressed: () {
                if (dialogDismissed) return;
                dialogDismissed = true;
                Navigator.of(dialogContext).pop(false);
              },
              child: Text(
                'Cancel',
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF919696),
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            ElevatedButton(
              key: const Key('delete_account_confirm_button'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                if (dialogDismissed) return;
                dialogDismissed = true;
                Navigator.of(dialogContext).pop(true);
              },
              child: Text(
                'Delete Account',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      await _executeAccountDeletion();
    }
  }

  Future<void> _executeAccountDeletion() async {
    setState(() => _isDeleting = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => PopScope(
        canPop: false,
        child: AlertDialog(
          key: const Key('delete_account_loading_dialog'),
          backgroundColor: const Color(0xFF1E2020),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppTheme.darkBorder),
          ),
          content: Row(
            children: [
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEF4444)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Deleting account...',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      if (widget.onDeleteAccount != null) {
        await widget.onDeleteAccount!();
      } else {
        await _authService.deleteAccount();
      }

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // dismiss loading dialog
        _onAccountDeletedSuccessfully();
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // dismiss loading dialog
        setState(() => _isDeleting = false);

        final isRequiresRecentLogin = e is RequiresRecentLoginException ||
            (e is FirebaseAuthException && e.code == 'requires-recent-login') ||
            e.toString().toLowerCase().contains('requires recent authentication') ||
            e.toString().toLowerCase().contains('requires-recent-login');

        final errorMsg = e is FirebaseAuthException
            ? _authService.handleFirebaseAuthException(e).toString().replaceFirst('Exception: ', '')
            : e.toString().replaceFirst('Exception: ', '');

        if (isRequiresRecentLogin) {
          _showReauthenticationSheet();
        } else {
          FlashSnackBar.showError(
            context,
            errorMsg.isNotEmpty ? errorMsg : 'Failed to delete account. Please try again.',
          );
        }
      }
    }
  }

  void _onAccountDeletedSuccessfully() {
    if (!mounted) return;
    invalidateUserSessionFromContext(context);
    FlashSnackBar.showSuccess(
      context,
      'Account deleted. A confirmation email has been sent.',
      duration: const Duration(seconds: 4),
    );

    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SplashScreen()),
      (route) => false,
    );
  }

  Future<void> _showReauthenticationSheet() async {
    final deleted = await ReauthenticationBottomSheet.show(
      context: context,
      authService: _authService,
    );

    if (deleted == true && mounted) {
      _onAccountDeletedSuccessfully();
    } else if (mounted) {
      FlashSnackBar.showError(
        context,
        'This action requires recent authentication. Please log in again before deleting your account.',
        action: SnackBarAction(
          label: 'Verify',
          textColor: AppTheme.gold,
          onPressed: () => _showReauthenticationSheet(),
        ),
      );
    }
  }

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
                            widget.email,
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
                      onTap: _isDeleting ? null : _handleDeleteAccount,
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
