import 'package:flutter/material.dart';
import '../widgets/flash_logo.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../theme/app_spacing.dart';
import '../theme/app_radius.dart';
import '../theme/app_buttons.dart';
import 'email_auth_screen.dart';
import 'phone_entry_screen.dart';
import 'aesthetics_selection_screen.dart';
import '../widgets/adaptive_glass_container.dart';
import '../widgets/social_auth_buttons.dart';
import '../widgets/skip_pill_button.dart';
import 'auth_routing.dart';
import 'profile_setup_screen.dart';
import 'artist_onboarding/artist_info_screen.dart';

class AccountCreationScreen extends StatefulWidget {
  final String role;
  final AuthService? authService;

  const AccountCreationScreen({
    super.key,
    required this.role,
    this.authService,
  });

  @override
  State<AccountCreationScreen> createState() => _AccountCreationScreenState();
}

class _AccountCreationScreenState extends State<AccountCreationScreen> {
  late final AuthService _authService = widget.authService ?? AuthService();
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _isAppleLoading = false;



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

  Future<void> _handleOAuth(
    Future<UserCredential?> Function() signInMethod, {
    bool isGoogle = false,
    bool isApple = false,
  }) async {
    setState(() {
      _isLoading = true;
      if (isGoogle) _isGoogleLoading = true;
      if (isApple) _isAppleLoading = true;
    });
    try {
      final credential = await signInMethod();
      if (credential != null && credential.user != null) {
        if (mounted) {
          await AuthRouting.routeUserAfterAuth(
            context, 
            credential.user!, 
            defaultRole: widget.role,
            authService: _authService,
          );
        }
      }
    } catch (e) {
      _showErrorSnackBar(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isGoogleLoading = false;
          _isAppleLoading = false;
        });
      }
    }
  }

  void _showAnonymousAuthDisabledDialog(String errorMsg) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E2020),
          shape: AppShapes.card,
          title: Row(
            children: [
              const Icon(Icons.info_outline, color: Color(0xFFEEC200)),
              AppGaps.gapSm,
              Expanded(
                child: Text(
                  'Anonymous Sign-In Disabled',
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFFF9FAFA),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Firebase returned: "$errorMsg"\n\n'
                'To enable Anonymous Auth for live Firebase accounts:\n'
                '1. Go to Firebase Console (flash-ink-app)\n'
                '2. Open Authentication > Sign-in method\n'
                '3. Enable "Anonymous" and Save.',
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF919696),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF919696))),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AestheticsSelectionScreen(isGuest: true),
                  ),
                  (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEEC200),
                foregroundColor: const Color(0xFF121414),
              ),
              child: const Text('Proceed to Test Mode'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleGuestMode() async {
    setState(() => _isLoading = true);
    try {
      final credential = await _authService.signInAnonymously();
      // Save role for anonymous user
      if (credential.user != null) {
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(credential.user!.uid)
              .set({'role': widget.role, 'isAnonymous': true}, SetOptions(merge: true));
        } catch (_) {}
      }

      if (mounted) {
        // Path B: Destructive routing directly to Style Preferences (Aesthetics)
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => const AestheticsSelectionScreen(isGuest: true),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      final errorStr = e.toString().replaceAll('Exception: ', '');
      if (errorStr.contains('Anonymous authentication is disabled') ||
          errorStr.contains('restricted to administrators') ||
          errorStr.contains('admin-restricted-operation')) {
        _showAnonymousAuthDisabledDialog(errorStr);
      } else {
        _showErrorSnackBar(errorStr);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _navigateToEmailAuth({bool isSignUp = true}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EmailAuthScreen(
          role: widget.role,
          authService: _authService,
          initialIsSignUp: isSignUp,
        ),
      ),
    );
  }

  void _navigateToPhoneAuth({String? initialPhone}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PhoneEntryScreen(
          role: widget.role,
          authService: _authService,
          initialPhone: initialPhone,
        ),
      ),
    );
  }

  void _showEmailAuthModal() => _navigateToEmailAuth();
  void _showPhoneEntryModal({String? initialPhone}) =>
      _navigateToPhoneAuth(initialPhone: initialPhone);

  void _handleSkip() {
    if (widget.role == 'artist') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ArtistInfoScreen(
            authService: _authService,
          ),
        ),
      );
    } else {
      Navigator.push(
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
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: SkipPillButton(
                key: const Key('skip_account_creation_button'),
                onPressed: _isLoading ? null : _handleSkip,
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Background subtle tattoo texture extending edge to edge
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
                    Colors.black.withAlpha(230),
                    Colors.black.withAlpha(130),
                    Colors.black.withAlpha(140),
                    Colors.black.withAlpha(210),
                  ],
                  stops: const [0.0, 0.25, 0.60, 1.0],
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
                          horizontal: AppSpacing.spaceXl,
                          vertical: AppSpacing.spaceLg,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const FlashLogo(
                              fontSize: 64,
                            ),
                            AppGaps.gapMd,
                            Text(
                              widget.role == 'artist'
                                  ? 'Create an account to showcase your flash designs, manage bookings, and grow your studio.'
                                  : 'Create an account or continue as guest to start exploring exclusive flash designs.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                color: const Color(0xFF919696),
                                fontSize: 14,
                                height: 1.4,
                              ),
                            ),
                             AppGaps.gapLg,
                             // Primary Account Creation Options within Liquid Glass Container
                            AdaptiveGlassContainer(
                              useGradient: false,
                              borderRadius: 20.0,
                              padding: const EdgeInsets.all(AppSpacing.spaceMd),
                              child: Column(
                                children: [
                                  AppButtons.primaryCTA(
                                    icon: Icons.mail_outline,
                                    text: 'Continue with Email',
                                    onPressed: _isLoading ? null : _showEmailAuthModal,
                                    backgroundColor: const Color(0xFF262929),
                                    foregroundColor: const Color(0xFFF9FAFA),
                                  ),
                                  AppGaps.gapSm,
                                  AppButtons.primaryCTA(
                                    icon: Icons.phone_iphone,
                                    text: 'Continue with Phone',
                                    onPressed: _isLoading ? null : () => _showPhoneEntryModal(),
                                    backgroundColor: const Color(0xFF262929),
                                    foregroundColor: const Color(0xFFF9FAFA),
                                  ),
                                ],
                              ),
                            ),
                            AppGaps.gapLg,
                            // Visual Divider with "OR CONTINUE WITH"
                            const SocialAuthDivider(),
                            AppGaps.gapMd,
                            // Circular Google & Apple buttons
                            SocialAuthRow(
                              onGooglePressed: () => _handleOAuth(
                                _authService.signInWithGoogle,
                                isGoogle: true,
                              ),
                              onApplePressed: () => _handleOAuth(
                                _authService.signInWithApple,
                                isApple: true,
                              ),
                              isLoading: _isLoading,
                              isGoogleLoading: _isGoogleLoading,
                              isAppleLoading: _isAppleLoading,
                            ),
                            if (widget.role != 'artist') ...[
                              AppGaps.gapLg,
                              // Guest Mode Action
                              TextButton(
                                onPressed: _isLoading ? null : _handleGuestMode,
                                child: Text(
                                  'Continue as Guest',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: const Color(0xFFEEC200),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                    decoration: TextDecoration.underline,
                                    decorationColor: const Color(0xFFEEC200),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEEC200)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
