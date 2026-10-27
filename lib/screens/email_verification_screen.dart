import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../theme/app_spacing.dart';
import '../widgets/adaptive_glass_container.dart';
import '../widgets/flash_glass_app_bar.dart';
import '../widgets/flash_snack_bar.dart';
import '../widgets/pinned_bottom_action_scaffold.dart';
import 'artist_onboarding/artist_info_screen.dart';
import 'auth_routing.dart';
import 'profile_setup_screen.dart';

class EmailVerificationScreen extends StatefulWidget {
  final AuthService? authService;
  final String? role;

  const EmailVerificationScreen({
    super.key, 
    this.authService,
    this.role,
  });

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  late final AuthService _authService = widget.authService ?? AuthService();
  bool _isLoading = false;
  bool _resendSuccess = false;

  Future<void> _checkEmailVerified() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.reload(); // Refresh the user's properties from Firebase
        final refreshedUser = FirebaseAuth.instance.currentUser;
        if (refreshedUser?.emailVerified ?? false) {
          if (mounted) {
            await AuthRouting.routeUserAfterAuth(
              context,
              refreshedUser!,
              defaultRole: widget.role ?? 'client',
              authService: _authService,
            );
          }
        } else {
          if (mounted) {
            FlashSnackBar.showError(
              context,
              'Email not verified yet. Please check your inbox.',
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        FlashSnackBar.showError(context, e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _resendEmail() async {
    setState(() {
      _isLoading = true;
      _resendSuccess = false;
    });
    try {
      await _authService.sendEmailVerification();
      setState(() => _resendSuccess = true);
      if (mounted) {
        FlashSnackBar.showSuccess(
          context,
          'Verification email resent!',
        );
      }
    } catch (e) {
      if (mounted) {
        FlashSnackBar.showError(context, e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _skipEmailVerification() async {
    User? user;
    try {
      user = FirebaseAuth.instance.currentUser;
    } catch (_) {
      user = null;
    }
    if (user != null) {
      await AuthRouting.routeUserAfterAuth(
        context,
        user,
        defaultRole: widget.role ?? 'client',
        authService: _authService,
        bypassEmailVerification: true,
      );
    } else {
      if (!mounted) return;
      if (widget.role == 'artist') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ArtistInfoScreen(
              authService: _authService,
            ),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const ProfileSetupScreen(),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;
    return PinnedBottomActionScaffold(
      backgroundColor: const Color(0xFF121414),
      extendBodyBehindAppBar: true,
      appBar: FlashGlassAppBar(
        onBackPressed: () async {
          // Sign out the unverified user and go back
          await _authService.signOut();
          if (context.mounted) {
            Navigator.pop(context);
          }
        },
        onSkipPressed: _skipEmailVerification,
      ),
      background: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/tattoo_setup.png',
              fit: BoxFit.cover,
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
      ctaText: "I've Verified My Email",
      onCtaPressed: _checkEmailVerified,
      isCtaLoading: _isLoading && !_resendSuccess,
      isCtaEnabled: !_isLoading,
      ctaBackgroundColor: const Color(0xFFEEC200),
      ctaForegroundColor: const Color(0xFF121414),
      secondaryAction: Center(
        child: TextButton(
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
                  'Verify your email',
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFFF9FAFA),
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
                AppGaps.gapSm,
                Text(
                  'We sent a verification link to:\n${user?.email ?? "your email"}',
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
