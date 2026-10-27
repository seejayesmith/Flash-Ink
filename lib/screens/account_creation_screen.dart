import 'package:flutter/material.dart';
import '../features/auth/presentation/screens/account_recovery_hub_screen.dart';
import '../features/auth/presentation/screens/auth_lockout_screen.dart';
import '../features/auth/presentation/sheets/account_collision_sheet.dart';
import '../features/auth/presentation/widgets/unified_auth_input_field.dart';
import '../widgets/fade_page_route.dart';
import '../widgets/flash_logo.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../config/dev_config.dart';
import '../services/auth_service.dart';
import '../theme/app_spacing.dart';
import '../theme/app_radius.dart';
import '../theme/app_buttons.dart';
import '../theme/app_theme.dart';
import 'email_auth_screen.dart';
import 'phone_verification_screen.dart';
import 'aesthetics_selection_screen.dart';
import '../widgets/adaptive_glass_container.dart';
import '../widgets/flash_glass_app_bar.dart';
import '../widgets/flash_snack_bar.dart';
import '../widgets/flow_page_layout.dart';
import '../widgets/social_auth_buttons.dart';
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
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _isAppleLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _identifierController.dispose();
    super.dispose();
  }



  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    FlashSnackBar.showError(context, message);
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
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      if (e.code == 'account-exists-with-different-credential') {
        AccountCollisionSheet.show(
          context: context,
          email: e.email ?? '',
          existingProvider: 'Existing Account',
          newProvider: isGoogle ? 'Google' : 'Apple',
          pendingCredential: e.credential,
        );
        return;
      }
      if (e.code == 'too-many-requests') {
        Navigator.push(
          context,
          FadePageRoute(builder: (_) => const AuthLockoutScreen()),
        );
        return;
      }
      _showErrorSnackBar(e.message ?? e.toString());
    } catch (e) {
      if (!mounted) return;
      final errorMsg = e.toString();
      if (errorMsg.contains('account-exists-with-different-credential')) {
        AccountCollisionSheet.show(
          context: context,
          email: '',
          existingProvider: 'Existing Account',
          newProvider: isGoogle ? 'Google' : 'Apple',
        );
        return;
      }
      if (errorMsg.contains('too-many-requests')) {
        Navigator.push(
          context,
          FadePageRoute(builder: (_) => const AuthLockoutScreen()),
        );
        return;
      }
      _showErrorSnackBar(errorMsg);
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

  void _navigateToEmailAuth({bool isSignUp = true, String? initialEmail}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EmailAuthScreen(
          role: widget.role,
          authService: _authService,
          initialIsSignUp: isSignUp,
          initialEmail: initialEmail,
        ),
      ),
    );
  }

  Future<void> _handleUnifiedContinue() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final rawInput = _identifierController.text.trim();
    final inputType = detectAuthInputType(rawInput);

    if (inputType == AuthInputType.email) {
      setState(() => _errorMessage = null);
      _navigateToEmailAuth(initialEmail: rawInput);
      return;
    }

    if (inputType == AuthInputType.phone) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final formattedNumber = AuthService.formatE164PhoneNumber(rawInput);

      try {
        await _authService.verifyPhoneNumber(
          phoneNumber: formattedNumber,
          onVerificationCompleted: (PhoneAuthCredential credential) async {
            if (!mounted) return;
            setState(() => _isLoading = false);
            final user = _authService.currentUser;
            if (user != null) {
              try {
                await _authService.updatePhoneVerificationStatus(
                  uid: user.uid,
                  phoneNumber: formattedNumber,
                );
              } catch (_) {}
              if (!mounted) return;
              await AuthRouting.routeUserAfterAuth(
                context,
                user,
                defaultRole: widget.role,
                authService: _authService,
              );
            }
          },
          onCodeSent: (String verificationId, int? resendToken) {
            if (!mounted) return;
            setState(() => _isLoading = false);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PhoneVerificationScreen(
                  phoneNumber: formattedNumber,
                  verificationId: verificationId,
                  resendToken: resendToken,
                  role: widget.role,
                  authService: _authService,
                ),
              ),
            );
          },
          onVerificationFailed: (Exception error) {
            final errorMsg = error.toString().replaceAll('Exception: ', '');
            if (mounted) {
              if (errorMsg.contains('too-many-requests') ||
                  errorMsg.contains('Too many attempts')) {
                setState(() => _isLoading = false);
                Navigator.push(
                  context,
                  FadePageRoute(builder: (_) => const AuthLockoutScreen()),
                );
                return;
              }
              setState(() {
                _isLoading = false;
                _errorMessage = errorMsg;
              });
              _showErrorSnackBar(errorMsg);
            }
          },
          onCodeAutoRetrievalTimeout: (String verificationId) {
            // Verification ID is retained in AuthService state for manual SMS code entry
          },
        );
      } catch (e) {
        final errorMsg = e.toString().replaceAll('Exception: ', '');
        if (mounted) {
          if (errorMsg.contains('too-many-requests') ||
              errorMsg.contains('Too many attempts')) {
            setState(() => _isLoading = false);
            Navigator.push(
              context,
              FadePageRoute(builder: (_) => const AuthLockoutScreen()),
            );
            return;
          }
          setState(() {
            _isLoading = false;
            _errorMessage = errorMsg;
          });
          _showErrorSnackBar(errorMsg);
        }
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
          builder: (_) => ProfileSetupScreen(
            authService: _authService,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFF121414),
      appBar: FlashGlassAppBar(
        onSkipPressed: _isLoading ? null : _handleSkip,
        skipButtonKey: const Key('skip_account_creation_button'),
      ),
      body: Stack(
        children: [
          // Background subtle tattoo texture extending edge to edge pinned to full screen
          Positioned(
            top: 0,
            left: 0,
            width: screenSize.width,
            height: screenSize.height,
            child: Image.asset(
              'assets/images/tattoo_setup.png',
              fit: BoxFit.cover,
              cacheWidth: 1080,
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            width: screenSize.width,
            height: screenSize.height,
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
          FlowPageLayout(
            crossAxisAlignment: CrossAxisAlignment.center,
            headerWidget: Column(
              children: [
                const FlashLogo(
                  fontSize: 64,
                ),
                AppGaps.headerTitleSubtitle,
                Text(
                  widget.role == 'artist'
                      ? 'Create an account to showcase your flash designs, manage bookings, and grow your studio.'
                      : 'Create an account or continue as guest to start exploring exclusive flash designs.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF919696),
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
              ],
            ),
            child: Column(
              children: [
                // Unified Email/Phone Input & Primary CTA within Liquid Glass Container
                AdaptiveGlassContainer(
                  useGradient: false,
                  borderRadius: 20.0,
                  padding: AppPadding.card,
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        UnifiedAuthInputField(
                          controller: _identifierController,
                          enabled: !_isLoading,
                          onChanged: (_) {
                            if (_errorMessage != null) {
                              setState(() => _errorMessage = null);
                            }
                          },
                          onFieldSubmitted: (_) {
                            if (!_isLoading) {
                              _handleUnifiedContinue();
                            }
                          },
                        ),
                        if (_errorMessage != null) ...[
                          AppGaps.gapSm,
                          Container(
                            key: const Key('account_creation_error_banner'),
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
                        AppGaps.gapMd,
                        AppButtons.primaryCTA(
                          key: const Key('unified_auth_continue_button'),
                          text: 'CONTINUE',
                          icon: Icons.arrow_forward,
                          isLoading: _isLoading,
                          onPressed: _isLoading ? null : _handleUnifiedContinue,
                          backgroundColor: AppTheme.gold,
                          foregroundColor: AppTheme.onyxBackground,
                        ),
                      ],
                    ),
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
                AppGaps.gapSm,
                TextButton(
                  key: const Key('account_creation_trouble_link'),
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
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                      decorationColor: const Color(0xFF8C9191),
                    ),
                  ),
                ),
              ],
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
