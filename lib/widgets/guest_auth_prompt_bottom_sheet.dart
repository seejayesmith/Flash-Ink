import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../features/auth/presentation/screens/account_recovery_hub_screen.dart';
import '../services/auth_service.dart';
import '../theme/app_buttons.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import 'adaptive_glass_container.dart';
import 'fade_page_route.dart';
import 'keyboard_collapse_button.dart';
import 'social_auth_buttons.dart';

/// Contextual trigger type for guest auth gating prompts.
enum AuthActionPromptType {
  favoriteArtist,
  favoriteArtwork,
  bookFlash,
  customRequest,
  waitlist,
}

extension AuthActionPromptTypeExtension on AuthActionPromptType {
  String get title {
    switch (this) {
      case AuthActionPromptType.favoriteArtist:
        return 'Save Your Favorites';
      case AuthActionPromptType.favoriteArtwork:
        return 'Save This Artwork';
      case AuthActionPromptType.bookFlash:
        return 'Book Your Flash Piece';
      case AuthActionPromptType.customRequest:
        return 'Submit Custom Request';
      case AuthActionPromptType.waitlist:
        return 'Join VIP Waitlist';
    }
  }

  String get description {
    switch (this) {
      case AuthActionPromptType.favoriteArtist:
        return 'Create an account to save artists, bookmark designs, and sync favorites across devices.';
      case AuthActionPromptType.favoriteArtwork:
        return 'Create an account to bookmark flash pieces, track availability, and view them anytime.';
      case AuthActionPromptType.bookFlash:
        return 'Create an account to reserve this flash design, select your appointment date, and confirm your booking.';
      case AuthActionPromptType.customRequest:
        return 'Create an account to share your concept, upload reference photos, and collaborate with the artist.';
      case AuthActionPromptType.waitlist:
        return 'Create an account to receive priority notifications and early access when books open.';
    }
  }

  IconData get icon {
    switch (this) {
      case AuthActionPromptType.favoriteArtist:
        return Icons.favorite_rounded;
      case AuthActionPromptType.favoriteArtwork:
        return Icons.favorite_rounded;
      case AuthActionPromptType.bookFlash:
        return Icons.bolt_rounded;
      case AuthActionPromptType.customRequest:
        return Icons.edit_note_rounded;
      case AuthActionPromptType.waitlist:
        return Icons.stars_rounded;
    }
  }
}

/// A branded liquid glass bottom sheet modal prompting guest clients
/// to upgrade/create an account before performing gated actions.
class GuestAuthPromptBottomSheet extends StatefulWidget {
  final AuthActionPromptType actionType;
  final AuthService? authService;

  const GuestAuthPromptBottomSheet({
    super.key,
    required this.actionType,
    this.authService,
  });

  /// Check whether the current user is authenticated or guest.
  /// If already permanent user, returns `true` immediately.
  /// If guest, displays this bottom sheet and returns `true` upon successful sign-up/sign-in.
  static Future<bool> ensureAuthenticated(
    BuildContext context, {
    required AuthActionPromptType actionType,
    AuthService? authService,
  }) async {
    final auth = authService ?? AuthService();
    if (!auth.isGuest) {
      return true;
    }

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => GuestAuthPromptBottomSheet(
        actionType: actionType,
        authService: auth,
      ),
    );

    return result == true;
  }

  @override
  State<GuestAuthPromptBottomSheet> createState() =>
      _GuestAuthPromptBottomSheetState();
}

class _GuestAuthPromptBottomSheetState extends State<GuestAuthPromptBottomSheet> {
  late final AuthService _authService;

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isSignUp = true;
  bool _showEmailFields = false;
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _isAppleLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? AuthService();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleOAuth(Future<dynamic> Function() oAuthCall, {bool isGoogle = false, bool isApple = false}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      if (isGoogle) _isGoogleLoading = true;
      if (isApple) _isAppleLoading = true;
    });

    try {
      final credential = await oAuthCall();
      if (credential != null && mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
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

  Future<void> _handleEmailAuth() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      if (_isSignUp) {
        await _authService.linkWithEmailAndPassword(email, password);
      } else {
        await _authService.signInWithEmailAndPassword(email, password);
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: AdaptiveGlassContainer.bottomSheet(
        topRadius: AppRadius.radiusSheet,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.spaceLg,
          14,
          AppSpacing.spaceLg,
          AppSpacing.spaceLg,
        ),
        child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top drag pill & keyboard collapse button
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFF4D5252),
                          borderRadius: BorderRadius.circular(AppRadius.dragHandle),
                        ),
                      ),
                    ),
                    const Align(
                      alignment: Alignment.centerRight,
                      child: KeyboardCollapseButton(
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
                AppGaps.gapLg,

                // Icon + Header Badge
                Center(
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFEEC200).withAlpha(30),
                      border: Border.all(
                        color: const Color(0xFFEEC200).withAlpha(120),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFEEC200).withAlpha(25),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      widget.actionType.icon,
                      color: const Color(0xFFEEC200),
                      size: 28,
                    ),
                  ),
                ),
                AppGaps.gapMd,

                // Title & Subtitle
                Text(
                  widget.actionType.title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFFF9FAFA),
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                AppGaps.gapXs,
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    widget.actionType.description,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFF919696),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
                AppGaps.gapLg,

                // Error message if any
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withAlpha(30),
                      borderRadius: BorderRadius.circular(AppRadius.radiusSm),
                      border: Border.all(color: const Color(0xFFEF4444).withAlpha(120)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFFFCA5A5),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  AppGaps.gapMd,
                ],

                // Social Auth Row (Google & Apple)
                SocialAuthRow(
                  onGooglePressed: () => _handleOAuth(
                    _authService.linkWithGoogle,
                    isGoogle: true,
                  ),
                  onApplePressed: () => _handleOAuth(
                    _authService.linkWithApple,
                    isApple: true,
                  ),
                  isLoading: _isLoading,
                  isGoogleLoading: _isGoogleLoading,
                  isAppleLoading: _isAppleLoading,
                ),
                AppGaps.gapMd,

                // Divider
                const SocialAuthDivider(),
                AppGaps.gapMd,

                // Expandable Email Auth Section
                if (!_showEmailFields)
                  AppButtons.primaryCTA(
                    icon: Icons.mail_outline_rounded,
                    text: 'Continue with Email',
                    backgroundColor: const Color(0xFF262929),
                    foregroundColor: const Color(0xFFF9FAFA),
                    onPressed: _isLoading ? null : () {
                      setState(() {
                        _showEmailFields = true;
                      });
                    },
                  )
                else ...[
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: const TextStyle(color: Color(0xFFF9FAFA), fontSize: 14),
                          validator: (v) =>
                              (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                          decoration: InputDecoration(
                            hintText: 'Email address',
                            hintStyle: const TextStyle(color: Color(0xFF4D5252), fontSize: 13),
                            prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF919696), size: 18),
                            filled: true,
                            fillColor: const Color(0xFF151818),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: AppBorderRadius.md,
                              borderSide: const BorderSide(color: Color(0xFF2D3131)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: AppBorderRadius.md,
                              borderSide: const BorderSide(color: Color(0xFFEEC200)),
                            ),
                          ),
                        ),
                        AppGaps.gapSm,
                        TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          style: const TextStyle(color: Color(0xFFF9FAFA), fontSize: 14),
                          validator: (v) =>
                              (v == null || v.length < 6) ? 'Password must be at least 6 characters' : null,
                          decoration: InputDecoration(
                            hintText: 'Password',
                            hintStyle: const TextStyle(color: Color(0xFF4D5252), fontSize: 13),
                            prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF919696), size: 18),
                            filled: true,
                            fillColor: const Color(0xFF151818),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: AppBorderRadius.md,
                              borderSide: const BorderSide(color: Color(0xFF2D3131)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: AppBorderRadius.md,
                              borderSide: const BorderSide(color: Color(0xFFEEC200)),
                            ),
                          ),
                        ),
                        AppGaps.gapMd,
                        AppButtons.primaryCTA(
                          text: _isSignUp ? 'Create Account' : 'Sign In',
                          isLoading: _isLoading && !_isGoogleLoading && !_isAppleLoading,
                          backgroundColor: const Color(0xFFEEC200),
                          foregroundColor: const Color(0xFF121414),
                          onPressed: _isLoading ? null : _handleEmailAuth,
                        ),
                        AppGaps.gapSm,
                        Center(
                          child: TextButton(
                            onPressed: _isLoading
                                ? null
                                : () {
                                    setState(() {
                                      _isSignUp = !_isSignUp;
                                      _errorMessage = null;
                                    });
                                  },
                            child: Text(
                              _isSignUp
                                  ? 'Already have an account? Sign In'
                                  : "Don't have an account? Create one",
                              style: GoogleFonts.plusJakartaSans(
                                color: const Color(0xFFD8DDDD),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // "Maybe Later" Cancel Option
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
                        child: Text(
                          'Maybe Later',
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFF6B7272),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const Text('•', style: TextStyle(color: Color(0xFF4D5252))),
                      TextButton(
                        onPressed: _isLoading
                            ? null
                            : () {
                                Navigator.of(context).pop(false);
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
                            fontWeight: FontWeight.w500,
                            decoration: TextDecoration.underline,
                            decorationColor: const Color(0xFF8C9191),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
  }
}
