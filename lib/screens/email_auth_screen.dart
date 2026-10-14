import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../theme/app_spacing.dart';
import '../theme/app_radius.dart';
import '../theme/app_buttons.dart';
import '../widgets/adaptive_glass_container.dart';
import '../widgets/flash_logo.dart';
import '../widgets/skip_pill_button.dart';
import 'artist_onboarding/artist_info_screen.dart';
import 'auth_routing.dart';
import 'email_verification_screen.dart';
import 'profile_setup_screen.dart';

class EmailAuthScreen extends StatefulWidget {
  final String role;
  final AuthService? authService;
  final bool initialIsSignUp;

  const EmailAuthScreen({
    super.key,
    required this.role,
    this.authService,
    this.initialIsSignUp = true,
  });

  @override
  State<EmailAuthScreen> createState() => _EmailAuthScreenState();
}

class _EmailAuthScreenState extends State<EmailAuthScreen> {
  late final AuthService _authService = widget.authService ?? AuthService();
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  late bool _isSignUp = widget.initialIsSignUp;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message.replaceAll('Exception: ', ''),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppBorderRadius.md),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      UserCredential credential;
      if (_isSignUp) {
        credential = await _authService.signUpWithEmailAndPassword(
          _emailController.text.trim(),
          _passwordController.text,
          role: widget.role,
        );
      } else {
        credential = await _authService.signInWithEmailAndPassword(
          _emailController.text.trim(),
          _passwordController.text,
        );
      }

      if (mounted && credential.user != null) {
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(credential.user!.uid)
              .set({'role': widget.role}, SetOptions(merge: true));
        } catch (_) {}

        if (!mounted) return;

        if (!credential.user!.emailVerified) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => EmailVerificationScreen(
                authService: _authService,
                role: widget.role,
              ),
            ),
          );
        } else {
          await AuthRouting.routeUserAfterAuth(
            context,
            credential.user!,
            defaultRole: widget.role,
            authService: _authService,
          );
        }
      }
    } catch (e) {
      final errorMsg = e.toString().replaceAll('Exception: ', '');
      if (mounted) {
        setState(() {
          _errorMessage = errorMsg;
        });
        _showErrorSnackBar(errorMsg);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _handleSkip() {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFF121414),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFFF9FAFA)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const FlashLogo(fontSize: 28),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: SkipPillButton(
                onPressed: _handleSkip,
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Background tattoo setup image texture
          Positioned.fill(
            child: Image.asset(
              'assets/images/tattoo_setup.png',
              fit: BoxFit.cover,
              cacheWidth: 1080,
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withAlpha(240),
                    Colors.black.withAlpha(190),
                    Colors.black.withAlpha(210),
                    Colors.black.withAlpha(245),
                  ],
                  stops: const [0.0, 0.3, 0.7, 1.0],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.spaceLg,
                  vertical: AppSpacing.spaceMd,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: AdaptiveGlassContainer(
                    useGradient: false,
                    borderRadius: 24.0,
                    padding: const EdgeInsets.all(AppSpacing.spaceLg),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              padding: const EdgeInsets.all(AppSpacing.spaceSm),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEC200).withAlpha(25),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.mail_outline,
                                color: Color(0xFFEEC200),
                                size: 36,
                              ),
                            ),
                          ),
                          AppGaps.gapMd,
                          Center(
                            child: Text(
                              _isSignUp ? 'Create with Email' : 'Sign in with Email',
                              style: GoogleFonts.plusJakartaSans(
                                color: const Color(0xFFF9FAFA),
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          AppGaps.gapXs,
                          Center(
                            child: Text(
                              _isSignUp
                                  ? (widget.role == 'artist'
                                      ? 'Sign up with your studio email to showcase your flash.'
                                      : 'Sign up to discover and book flash tattoos.')
                                  : 'Enter your email and password to access your account.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                color: const Color(0xFF919696),
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ),
                          AppGaps.gapLg,
                          Text(
                            'Email Address',
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFFF9FAFA),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          AppGaps.gapXs,
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: const TextStyle(color: Color(0xFFF9FAFA)),
                            validator: (v) => (v == null || !v.contains('@'))
                                ? 'Enter a valid email'
                                : null,
                            decoration: InputDecoration(
                              hintText: 'you@example.com',
                              hintStyle: const TextStyle(color: Color(0xFF4D5252)),
                              prefixIcon: const Icon(
                                Icons.email_outlined,
                                color: Color(0xFFEEC200),
                                size: 20,
                              ),
                              filled: true,
                              fillColor: const Color(0xFF121414),
                              border: OutlineInputBorder(
                                borderRadius: AppBorderRadius.md,
                                borderSide: const BorderSide(color: Color(0xFF262929)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: AppBorderRadius.md,
                                borderSide: const BorderSide(color: Color(0xFFEEC200)),
                              ),
                            ),
                          ),
                          AppGaps.gapMd,
                          Text(
                            'Password',
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFFF9FAFA),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          AppGaps.gapXs,
                          TextFormField(
                            controller: _passwordController,
                            obscureText: true,
                            style: const TextStyle(color: Color(0xFFF9FAFA)),
                            validator: (v) => (v == null || v.length < 6)
                                ? 'Password must be at least 6 characters'
                                : null,
                            decoration: InputDecoration(
                              hintText: '••••••••',
                              hintStyle: const TextStyle(color: Color(0xFF4D5252)),
                              prefixIcon: const Icon(
                                Icons.lock_outline,
                                color: Color(0xFFEEC200),
                                size: 20,
                              ),
                              filled: true,
                              fillColor: const Color(0xFF121414),
                              border: OutlineInputBorder(
                                borderRadius: AppBorderRadius.md,
                                borderSide: const BorderSide(color: Color(0xFF262929)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: AppBorderRadius.md,
                                borderSide: const BorderSide(color: Color(0xFFEEC200)),
                              ),
                            ),
                          ),
                          if (_errorMessage != null) ...[
                            AppGaps.gapMd,
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.spaceMd,
                                vertical: AppSpacing.spaceSm,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444).withAlpha(30),
                                borderRadius: AppBorderRadius.md,
                                border: Border.all(color: const Color(0xFFEF4444)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.error_outline,
                                    color: Color(0xFFEF4444),
                                    size: 18,
                                  ),
                                  AppGaps.gapSm,
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: GoogleFonts.plusJakartaSans(
                                        color: const Color(0xFFEF4444),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          AppGaps.gapLg,
                          AppButtons.primaryCTA(
                            isLoading: _isLoading,
                            onPressed: _submit,
                            text: _isSignUp ? 'CREATE ACCOUNT' : 'SIGN IN',
                          ),
                          AppGaps.gapSm,
                          Center(
                            child: TextButton(
                              onPressed: () {
                                setState(() {
                                  _isSignUp = !_isSignUp;
                                  _errorMessage = null;
                                });
                              },
                              child: Text(
                                _isSignUp
                                    ? 'Already have an account? Sign In'
                                    : "Don't have an account? Create One",
                                style: const TextStyle(
                                  color: Color(0xFF919696),
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
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
