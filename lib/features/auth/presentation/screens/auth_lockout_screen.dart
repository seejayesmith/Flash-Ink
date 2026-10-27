import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../providers/app_providers.dart';
import '../../../../theme/app_buttons.dart';
import '../../../../theme/app_radius.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_theme.dart';
import '../../../../theme/app_typography.dart';
import '../../../../widgets/fade_page_route.dart';
import '../../../../widgets/flash_glass_app_bar.dart';
import '../../../../widgets/flash_snack_bar.dart';
import '../../../../widgets/social_auth_buttons.dart';
import '../controllers/auth_troubleshooting_controller.dart';
import 'support_escalation_screen.dart';

/// Screen presented when an authentication flow has been rate-limited by Firebase
/// (`too-many-requests`), displaying a live countdown and alternative bypass methods.
class AuthLockoutScreen extends ConsumerStatefulWidget {
  final VoidCallback? onBypassSuccess;
  final VoidCallback? onCountdownExpired;

  const AuthLockoutScreen({
    super.key,
    this.onBypassSuccess,
    this.onCountdownExpired,
  });

  @override
  ConsumerState<AuthLockoutScreen> createState() => _AuthLockoutScreenState();
}

class _AuthLockoutScreenState extends ConsumerState<AuthLockoutScreen> {
  bool _isSocialLoading = false;
  bool _isGoogleLoading = false;
  bool _isAppleLoading = false;

  String _formatTimer(int totalSeconds) {
    final safeSeconds = totalSeconds < 0 ? 0 : totalSeconds;
    final minutes = (safeSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (safeSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _handleGoogleBypass() async {
    setState(() {
      _isSocialLoading = true;
      _isGoogleLoading = true;
    });

    try {
      final authService = ref.read(authServiceProvider);
      final userCredential = await authService.signInWithGoogle();
      if (userCredential != null && mounted) {
        ref.read(authTroubleshootingControllerProvider.notifier).reset();
        widget.onBypassSuccess?.call();
        FlashSnackBar.showSuccess(context, 'Signed in with Google successfully.');
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        FlashSnackBar.showError(
          context,
          'Google sign-in could not complete: ${e.toString().replaceFirst("Exception: ", "")}',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSocialLoading = false;
          _isGoogleLoading = false;
        });
      }
    }
  }

  Future<void> _handleAppleBypass() async {
    setState(() {
      _isSocialLoading = true;
      _isAppleLoading = true;
    });

    try {
      final authService = ref.read(authServiceProvider);
      final userCredential = await authService.signInWithApple();
      if (userCredential != null && mounted) {
        ref.read(authTroubleshootingControllerProvider.notifier).reset();
        widget.onBypassSuccess?.call();
        FlashSnackBar.showSuccess(context, 'Signed in with Apple successfully.');
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        FlashSnackBar.showError(
          context,
          'Apple sign-in could not complete: ${e.toString().replaceFirst("Exception: ", "")}',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSocialLoading = false;
          _isAppleLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(authTroubleshootingControllerProvider);
    final currentState = asyncState.value;
    final remainingSeconds = currentState?.rateLimitSeconds ?? 0;
    final isCountdownActive = remainingSeconds > 0;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: AppTheme.onyxBackground,
        appBar: const FlashGlassAppBar(
          title: Text('Security Notice'),
          showBackButton: true,
        ),
        body: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenMargin,
            AppSpacing.headerTop,
            AppSpacing.screenMargin,
            AppSpacing.ctaBottomPadding,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Warning indicator icon
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppTheme.goldContainer,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.gold,
                      width: 2.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.gold.withAlpha(50),
                        blurRadius: 24,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.lock_clock_rounded,
                    color: AppTheme.gold,
                    size: 36,
                  ),
                ),
              ),
              AppGaps.gapLg,

              // Screen Title
              Text(
                'Temporarily Locked',
                textAlign: TextAlign.center,
                key: const Key('auth_lockout_title'),
                style: AppTypography.heroTitle.copyWith(
                  color: AppTheme.textPrimary,
                ),
              ),
              AppGaps.gapXs,
              Text(
                'Too many unsuccessful verification attempts. For your security, this action has been temporarily paused.',
                textAlign: TextAlign.center,
                style: AppTypography.heroSubtitle.copyWith(
                  color: AppTheme.navInactive,
                ),
              ),
              AppGaps.gapLg,

              // Live MM:SS Countdown Container
              Container(
                key: const Key('auth_lockout_timer_card'),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenMargin,
                  vertical: AppSpacing.spaceLg,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.cardBackground,
                  borderRadius: AppBorderRadius.md,
                  border: Border.all(
                    color: isCountdownActive
                        ? AppTheme.goldBorder
                        : AppTheme.cardBorder,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      'TRY AGAIN IN',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.navInactive,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    AppGaps.gapSm,
                    Text(
                      _formatTimer(remainingSeconds),
                      key: const Key('auth_lockout_countdown_text'),
                      style: GoogleFonts.plusJakartaSans(
                        color: isCountdownActive
                            ? AppTheme.gold
                            : AppTheme.switchActive,
                        fontSize: 48,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.0,
                      ),
                    ),
                    AppGaps.gapSm,
                    Text(
                      isCountdownActive
                          ? 'Please keep this screen open or return after the cooldown.'
                          : 'Lockout expired. You may now retry verification.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.navInactive,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              AppGaps.gapLg,

              // Retry Action (if countdown has ended)
              if (!isCountdownActive) ...[
                AppButtons.primaryCTA(
                  key: const Key('auth_lockout_retry_button'),
                  text: 'Retry Sign In',
                  onPressed: () {
                    ref
                        .read(authTroubleshootingControllerProvider.notifier)
                        .reset();
                    widget.onCountdownExpired?.call();
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    }
                  },
                ),
                AppGaps.gapLg,
              ],

              // Secondary Fallback Bypass via Social Auth
              const SocialAuthDivider(
                label: 'OR BYPASS WITH LINKED ACCOUNT',
              ),
              AppGaps.gapMd,
              Text(
                'If you have already linked Google or Apple to this profile, you can sign in directly without an SMS code.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.navInactive,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              AppGaps.gapMd,
              SocialAuthRow(
                key: const Key('auth_lockout_social_bypass_row'),
                onGooglePressed: _handleGoogleBypass,
                onApplePressed: _handleAppleBypass,
                isGoogleLoading: _isGoogleLoading,
                isAppleLoading: _isAppleLoading,
                isLoading: _isSocialLoading,
              ),
              AppGaps.gapLg,

              // Support Escalation Action
              Center(
                child: TextButton.icon(
                  key: const Key('auth_lockout_contact_support_button'),
                  onPressed: () {
                    Navigator.of(context).push(
                      FadePageRoute(
                        builder: (_) => const SupportEscalationScreen(),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.support_agent_rounded,
                    color: AppTheme.gold,
                    size: 18,
                  ),
                  label: Text(
                    'Still having trouble? Contact Support',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.gold,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
