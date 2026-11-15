import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../theme/app_spacing.dart';
import '../widgets/adaptive_glass_container.dart';
import '../widgets/fade_page_route.dart';
import '../widgets/flash_glass_app_bar.dart';
import '../widgets/flash_snack_bar.dart';
import '../widgets/pinned_bottom_action_scaffold.dart';

/// Onboarding verification step shown after sending a passwordless
/// `verifyBeforeUpdateEmail` link to a Phone-OTP user's backup email.
///
/// Users can tap `"I've Verified My Email"` after clicking the link in their
/// inbox, resend the verification email, or skip to continue onboarding and
/// complete verification later from Account Settings.
class BackupEmailVerificationScreen extends StatefulWidget {
  final String email;
  final AuthService? authService;
  final bool isArtist;
  final Widget Function(BuildContext context) nextScreenBuilder;

  const BackupEmailVerificationScreen({
    super.key,
    required this.email,
    required this.nextScreenBuilder,
    this.authService,
    this.isArtist = false,
  });

  @override
  State<BackupEmailVerificationScreen> createState() =>
      _BackupEmailVerificationScreenState();
}

class _BackupEmailVerificationScreenState
    extends State<BackupEmailVerificationScreen> {
  late final AuthService _authService = widget.authService ?? AuthService();
  bool _isLoading = false;
  bool _resendSuccess = false;

  void _navigateNext() {
    if (!mounted) return;
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.pushReplacement(
      context,
      FadePageRoute(builder: widget.nextScreenBuilder),
    );
  }

  Future<void> _checkEmailVerified() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final verified = await _authService.checkAndSyncBackupEmailVerified(
        expectedEmail: widget.email,
        isArtist: widget.isArtist,
      );
      if (!mounted) return;
      if (verified) {
        FlashSnackBar.showSuccess(context, 'Backup email verified!');
        _navigateNext();
      } else {
        FlashSnackBar.showError(
          context,
          'Email not verified yet. Please check your inbox or skip for now.',
        );
      }
    } catch (e) {
      if (mounted) {
        FlashSnackBar.showError(
          context,
          e.toString().replaceAll('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _resendEmail() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _resendSuccess = false;
    });
    try {
      await _authService.sendBackupEmailVerification(
        widget.email,
        isArtist: widget.isArtist,
      );
      if (!mounted) return;
      setState(() => _resendSuccess = true);
      FlashSnackBar.showSuccess(context, 'Verification email resent!');
    } catch (e) {
      if (mounted) {
        FlashSnackBar.showError(
          context,
          e.toString().replaceAll('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PinnedBottomActionScaffold(
      backgroundColor: const Color(0xFF121414),
      extendBodyBehindAppBar: true,
      appBar: FlashGlassAppBar(
        onSkipPressed: _isLoading ? null : _navigateNext,
        skipButtonKey: const Key('backup_email_appbar_skip_button'),
      ),
      background: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/tattoo_setup.png',
              fit: BoxFit.cover,
              cacheWidth: 1080,
            ),
          ),
          Positioned.fill(
            child: Container(
              color: Colors.black.withAlpha(200),
            ),
          ),
        ],
      ),
      centerContent: false,
      ctaKey: const Key('backup_email_verified_cta'),
      ctaText: "I've Verified My Email",
      onCtaPressed: _checkEmailVerified,
      isCtaLoading: _isLoading && !_resendSuccess,
      isCtaEnabled: !_isLoading,
      ctaBackgroundColor: const Color(0xFFEEC200),
      ctaForegroundColor: const Color(0xFF121414),
      secondaryAction: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            key: const Key('backup_email_resend_button'),
            onPressed: _isLoading ? null : _resendEmail,
            child: Text(
              _resendSuccess ? 'Link sent again' : 'Resend verification link',
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFFD8DDDD),
                fontSize: 14,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
          TextButton(
            key: const Key('backup_email_skip_button'),
            onPressed: _isLoading ? null : _navigateNext,
            child: Text(
              'Skip for now',
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF919696),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: AdaptiveGlassContainer(
            useGradient: false,
            padding: const EdgeInsets.all(AppSpacing.spaceXl),
            borderRadius: 20.0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.mark_email_unread_outlined,
                  size: 64,
                  color: Color(0xFFEEC200),
                ),
                AppGaps.gapLg,
                Text(
                  'Verify backup email',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFFF9FAFA),
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
                AppGaps.gapSm,
                Text(
                  'We sent a verification link to:\n${widget.email}',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF919696),
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
