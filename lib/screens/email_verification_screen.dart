import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../theme/app_spacing.dart';
import '../theme/app_buttons.dart';
import '../widgets/adaptive_glass_container.dart';
import 'profile_setup_screen.dart';

class EmailVerificationScreen extends StatefulWidget {
  final AuthService? authService;

  const EmailVerificationScreen({super.key, this.authService});

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
        if (FirebaseAuth.instance.currentUser?.emailVerified ?? false) {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const ProfileSetupScreen()),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Email not verified yet. Please check your inbox.'),
                backgroundColor: Color(0xFFEF4444),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification email resent!'),
            backgroundColor: Color(0xFF22C55E),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: const Color(0xFFEF4444),
          ),
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
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      backgroundColor: const Color(0xFF121414),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFFF9FAFA)),
          onPressed: () async {
            // Sign out the unverified user and go back
            await FirebaseAuth.instance.signOut();
            if (context.mounted) {
              Navigator.pop(context);
            }
          },
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Background Texture
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
          SafeArea(
            child: Center(
              child: Padding(
                padding: AppPadding.screenHorizontal,
                child: AdaptiveGlassContainer(
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
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      AppGaps.gapMd,
                      Text(
                        'We sent a verification link to:\n${user?.email ?? "your email"}',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF919696),
                          fontSize: 16,
                          height: 1.4,
                        ),
                      ),
                      AppGaps.gapXl,
                      AppButtons.primaryCTA(
                        onPressed: _isLoading ? null : _checkEmailVerified,
                        text: "I've Verified My Email",
                        isLoading: _isLoading && !_resendSuccess,
                        backgroundColor: const Color(0xFFEEC200),
                        foregroundColor: const Color(0xFF121414),
                      ),
                      AppGaps.gapLg,
                      TextButton(
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
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
