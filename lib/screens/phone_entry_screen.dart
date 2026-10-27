import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/dev_config.dart';
import '../features/auth/presentation/screens/account_recovery_hub_screen.dart';
import '../features/auth/presentation/screens/auth_lockout_screen.dart';
import '../services/auth_service.dart';
import '../theme/app_spacing.dart';
import '../theme/app_radius.dart';
import '../widgets/adaptive_glass_container.dart';
import '../widgets/fade_page_route.dart';
import '../widgets/flash_glass_app_bar.dart';
import '../widgets/flash_logo.dart';
import '../widgets/flash_snack_bar.dart';
import '../widgets/phone_number_input_formatter.dart';
import '../widgets/pinned_bottom_action_scaffold.dart';
import 'artist_onboarding/artist_info_screen.dart';
import 'auth_routing.dart';
import 'phone_verification_screen.dart';
import 'profile_setup_screen.dart';

class PhoneEntryScreen extends StatefulWidget {
  final String role;
  final AuthService? authService;
  final String? initialPhone;

  const PhoneEntryScreen({
    super.key,
    required this.role,
    this.authService,
    this.initialPhone,
  });

  @override
  State<PhoneEntryScreen> createState() => _PhoneEntryScreenState();
}

class _PhoneEntryScreenState extends State<PhoneEntryScreen> {
  late final AuthService _authService = widget.authService ?? AuthService();
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _phoneController;

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController(
      text: AuthService.formatDisplayPhoneNumber(widget.initialPhone ?? ''),
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
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

    final formattedNumber = AuthService.formatE164PhoneNumber(_phoneController.text);

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
            if (errorMsg.contains('too-many-requests') || errorMsg.contains('Too many attempts')) {
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
        if (errorMsg.contains('too-many-requests') || errorMsg.contains('Too many attempts')) {
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
      ctaText: 'SEND VERIFICATION CODE',
      onCtaPressed: _submit,
      isCtaLoading: _isLoading,
      secondaryAction: TextButton(
        key: const Key('phone_entry_trouble_link'),
        onPressed: () {
          Navigator.push(
            context,
            FadePageRoute(builder: (_) => const AccountRecoveryHubScreen()),
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
                      Icons.phone_iphone,
                      color: Color(0xFFEEC200),
                      size: 36,
                    ),
                  ),
                ),
                AppGaps.gapMd,
                Center(
                  child: Text(
                    'Verify Phone Number',
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
                    'Enter your mobile number to receive a 6-digit verification code.',
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
                  'Mobile Number',
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFFF9FAFA),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                AppGaps.gapXs,
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: const [PhoneNumberInputFormatter()],
                  style: const TextStyle(color: Color(0xFFF9FAFA)),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Please enter your phone number';
                    }
                    final digitsOnly = v.replaceAll(RegExp(r'\D'), '');
                    if (digitsOnly.length < 10) {
                      return 'Please enter a valid 10-digit phone number';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    hintText: '(555) 019-2834',
                    hintStyle: const TextStyle(color: Color(0xFF4D5252)),
                    prefixIcon: const Icon(
                      Icons.phone,
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
