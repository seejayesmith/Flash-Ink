import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../config/dev_config.dart';
import '../features/auth/presentation/screens/account_recovery_hub_screen.dart';
import '../features/auth/presentation/screens/auth_lockout_screen.dart';
import '../features/auth/presentation/sheets/account_collision_sheet.dart';
import '../services/auth_service.dart';
import '../theme/app_spacing.dart';
import '../theme/app_radius.dart';
import '../widgets/adaptive_glass_container.dart';
import '../widgets/fade_page_route.dart';
import '../widgets/flash_glass_app_bar.dart';
import '../widgets/flash_logo.dart';
import '../widgets/flash_snack_bar.dart';
import '../widgets/pinned_bottom_action_scaffold.dart';
import 'artist_onboarding/artist_info_screen.dart';
import 'auth_routing.dart';
import 'email_verification_screen.dart';
import 'profile_setup_screen.dart';

class EmailAuthScreen extends StatefulWidget {
  final String role;
  final AuthService? authService;
  final bool initialIsSignUp;
  final String? initialEmail;

  const EmailAuthScreen({
    super.key,
    required this.role,
    this.authService,
    this.initialIsSignUp = true,
    this.initialEmail,
  });

  @override
  State<EmailAuthScreen> createState() => _EmailAuthScreenState();
}

class _EmailAuthScreenState extends State<EmailAuthScreen> {
  late final AuthService _authService = widget.authService ?? AuthService();
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  final _passwordController = TextEditingController();

  late bool _isSignUp = widget.initialIsSignUp;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail ?? '');
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    FlashSnackBar.showError(context, message);
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
        if (errorMsg.contains('too-many-requests') || errorMsg.contains('Too many attempts')) {
          Navigator.push(
            context,
            FadePageRoute(builder: (_) => const AuthLockoutScreen()),
          );
          return;
        }
        if (e is FirebaseAuthException && e.code == 'account-exists-with-different-credential') {
          AccountCollisionSheet.show(
            context: context,
            email: e.email ?? _emailController.text.trim(),
            existingProvider: 'Existing Account',
            newProvider: 'Email',
            pendingCredential: e.credential,
          );
          return;
        }
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
    if (kEnableDevBypass) {
      if (widget.role == 'artist') {
        AuthService.createDevMockArtist();
      } else {
        AuthService.createDevMockClient();
      }
    }
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
          builder: (_) => ProfileSetupScreen(
            authService: _authService,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PinnedBottomActionScaffold(
      extendBodyBehindAppBar: true,
      appBar: FlashGlassAppBar(
        title: const FlashLogo(fontSize: 28),
        onSkipPressed: _handleSkip,
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
        ],
      ),
      centerContent: false,
      ctaText: _isSignUp ? 'CREATE ACCOUNT' : 'SIGN IN',
      onCtaPressed: _submit,
      isCtaLoading: _isLoading,
      secondaryAction: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
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
          TextButton(
            key: const Key('email_auth_trouble_link'),
            onPressed: () {
              Navigator.push(
                context,
                FadePageRoute(
                  builder: (_) => const AccountRecoveryHubScreen(),
                ),
              );
            },
            child: Text(
              'Trouble signing in?',
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF8C9191),
                fontSize: 13,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
                decorationColor: const Color(0xFF8C9191),
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
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
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
                      fontSize: 15,
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
                  AppGaps.gapSm,
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
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
}
