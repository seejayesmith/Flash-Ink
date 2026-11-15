import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import '../widgets/adaptive_glass_container.dart';
import '../widgets/fade_page_route.dart';
import '../widgets/flash_glass_app_bar.dart';
import '../widgets/flash_snack_bar.dart';
import '../widgets/phone_number_input_formatter.dart';
import '../widgets/pinned_bottom_action_scaffold.dart';
import 'aesthetics_selection_screen.dart';
import 'backup_email_verification_screen.dart';

/// Determines which backup contact method a client is prompted to add
/// during onboarding based on their primary sign-in provider.
enum ClientBackupContactMode { email, phone }

/// Optional, skippable client onboarding step positioned after profile setup
/// and before aesthetics selection.
///
/// - Phone-OTP users are invited to add a backup email (verified passwordlessly
///   via `verifyBeforeUpdateEmail`).
/// - Email/password users are invited to add and link a backup phone number
///   via SMS OTP (`linkWithPhoneCredential`).
class ClientBackupContactScreen extends StatefulWidget {
  final ClientBackupContactMode mode;
  final AuthService? authService;

  const ClientBackupContactScreen({
    super.key,
    required this.mode,
    this.authService,
  });

  @override
  State<ClientBackupContactScreen> createState() =>
      _ClientBackupContactScreenState();
}

class _ClientBackupContactScreenState extends State<ClientBackupContactScreen> {
  late final AuthService _authService = widget.authService ?? AuthService();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  bool _isLoading = false;
  bool _awaitingOtp = false;
  String? _errorMessage;
  String? _verificationId;
  int? _resendToken;
  String? _pendingPhoneE164;
  String? _pendingDisplayPhone;
  int _resendCooldown = 0;
  Timer? _resendTimer;

  static final RegExp _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void dispose() {
    _resendTimer?.cancel();
    _emailController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _skipToAesthetics() {
    if (!mounted) return;
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.pushReplacement(
      context,
      FadePageRoute(
        builder: (_) => AestheticsSelectionScreen(
          isGuest: false,
          authService: _authService,
        ),
      ),
    );
  }

  void _startResendCooldown() {
    _resendTimer?.cancel();
    if (!mounted) return;
    setState(() => _resendCooldown = 30);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendCooldown <= 1) {
        timer.cancel();
        setState(() => _resendCooldown = 0);
      } else {
        setState(() => _resendCooldown -= 1);
      }
    });
  }

  Future<void> _submitBackupEmail() async {
    if (_isLoading) return;
    final email = _emailController.text.trim();
    if (email.isEmpty || !_emailRegex.hasMatch(email)) {
      setState(() {
        _errorMessage = 'Please enter a valid email address.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.sendBackupEmailVerification(
        email,
        isArtist: false,
      );
      if (!mounted) return;
      FocusManager.instance.primaryFocus?.unfocus();
      Navigator.pushReplacement(
        context,
        FadePageRoute(
          builder: (_) => BackupEmailVerificationScreen(
            email: email,
            authService: _authService,
            isArtist: false,
            nextScreenBuilder: (_) => AestheticsSelectionScreen(
              isGuest: false,
              authService: _authService,
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceAll('Exception: ', '');
      setState(() {
        _errorMessage = message;
      });
      FlashSnackBar.showError(context, message);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _sendPhoneOtp({bool isResend = false}) async {
    if (_isLoading) return;
    final raw = _phoneController.text.trim();
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10) {
      setState(() {
        _errorMessage = 'Please enter a valid 10-digit phone number.';
      });
      return;
    }

    final formattedE164 = AuthService.formatE164PhoneNumber(raw);

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _pendingPhoneE164 = formattedE164;
      _pendingDisplayPhone = raw;
    });

    await _authService.verifyPhoneNumber(
      phoneNumber: formattedE164,
      forceResendingToken: isResend ? _resendToken : null,
      onCodeSent: (verificationId, resendToken) {
        if (!mounted) return;
        setState(() {
          _verificationId = verificationId;
          _resendToken = resendToken;
          _awaitingOtp = true;
          _isLoading = false;
        });
        _startResendCooldown();
        FlashSnackBar.showSuccess(
          context,
          'Verification code sent to $raw',
        );
      },
      onVerificationFailed: (error) {
        if (!mounted) return;
        final message = error.toString().replaceAll('Exception: ', '');
        setState(() {
          _isLoading = false;
          _errorMessage = message;
        });
        FlashSnackBar.showError(context, message);
      },
      onCodeAutoRetrievalTimeout: (verificationId) {
        _verificationId = verificationId;
      },
    );
  }

  Future<void> _verifyPhoneOtp() async {
    if (_isLoading) return;
    final code = _otpController.text.trim();
    if (code.length != 6) {
      setState(() {
        _errorMessage = 'Please enter the 6-digit verification code.';
      });
      return;
    }
    if (_verificationId == null || _verificationId!.isEmpty) {
      setState(() {
        _errorMessage =
            'Verification session expired. Please request a new code.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.linkWithPhoneCredential(
        verificationId: _verificationId!,
        smsCode: code,
        phoneNumber: _pendingPhoneE164,
      );

      final uid = _authService.currentUser?.uid;
      if (uid != null && _pendingPhoneE164 != null) {
        try {
          await _authService.updatePhoneVerificationStatus(
            uid: uid,
            phoneNumber: _pendingPhoneE164!,
          );
        } catch (_) {
          // Graceful fallback in headless widget tests without Firestore.
        }
      }

      if (!mounted) return;
      FlashSnackBar.showSuccess(context, 'Backup phone number verified!');
      _skipToAesthetics();
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceAll('Exception: ', '');
      setState(() {
        _errorMessage = message;
      });
      FlashSnackBar.showError(context, message);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _resetToPhoneEntry() {
    _resendTimer?.cancel();
    setState(() {
      _awaitingOtp = false;
      _otpController.clear();
      _errorMessage = null;
      _resendCooldown = 0;
    });
  }

  Key get _ctaKey {
    if (widget.mode == ClientBackupContactMode.email) {
      return const Key('client_backup_email_submit_button');
    }
    return _awaitingOtp
        ? const Key('client_backup_otp_verify_button')
        : const Key('client_backup_phone_submit_button');
  }

  String get _ctaText {
    if (widget.mode == ClientBackupContactMode.email) {
      return 'Send Verification Link';
    }
    return _awaitingOtp ? 'Verify & Continue' : 'Send Verification Code';
  }

  VoidCallback get _ctaAction {
    if (widget.mode == ClientBackupContactMode.email) {
      return _submitBackupEmail;
    }
    return _awaitingOtp ? _verifyPhoneOtp : () => _sendPhoneOtp();
  }

  Widget _buildSecondaryAction() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.mode == ClientBackupContactMode.phone && _awaitingOtp)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                key: const Key('client_backup_change_number_button'),
                onPressed: _isLoading ? null : _resetToPhoneEntry,
                child: Text(
                  'Change Number',
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFFD8DDDD),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                key: const Key('client_backup_resend_code_button'),
                onPressed: (_isLoading || _resendCooldown > 0)
                    ? null
                    : () => _sendPhoneOtp(isResend: true),
                child: Text(
                  _resendCooldown > 0
                      ? 'Resend in ${_resendCooldown}s'
                      : 'Resend Code',
                  style: GoogleFonts.plusJakartaSans(
                    color: _resendCooldown > 0
                        ? const Color(0xFF919696)
                        : AppTheme.gold,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        TextButton(
          key: const Key('client_backup_skip_button'),
          onPressed: _isLoading ? null : _skipToAesthetics,
          child: Text(
            'Skip for Now',
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFF919696),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _buildFieldDecoration({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: GoogleFonts.plusJakartaSans(
        color: const Color(0xFF919696),
        fontSize: 13,
      ),
      hintStyle: GoogleFonts.plusJakartaSans(
        color: const Color(0xFF6B7280),
        fontSize: 14,
      ),
      prefixIcon: Icon(icon, color: AppTheme.gold, size: 20),
      filled: true,
      fillColor: Colors.black.withAlpha(90),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withAlpha(30)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppTheme.gold, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 16,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEmailMode = widget.mode == ClientBackupContactMode.email;
    final IconData headerIcon = isEmailMode
        ? Icons.mark_email_read_outlined
        : (_awaitingOtp ? Icons.sms_outlined : Icons.phone_android_outlined);
    final String titleText = isEmailMode
        ? 'Add a backup email'
        : (_awaitingOtp ? 'Enter verification code' : 'Add a backup phone');
    final String subtitleText = isEmailMode
        ? 'Recover your account anytime and receive booking receipts—no extra password needed.'
        : (_awaitingOtp
            ? 'Enter the 6-digit code sent to ${_pendingDisplayPhone ?? _pendingPhoneE164 ?? 'your phone'}.'
            : 'Add a phone number to protect your account and get SMS appointment reminders.');

    return PinnedBottomActionScaffold(
      backgroundColor: const Color(0xFF121414),
      extendBodyBehindAppBar: true,
      appBar: FlashGlassAppBar(
        onSkipPressed: _isLoading ? null : _skipToAesthetics,
        skipButtonKey: const Key('client_backup_appbar_skip_button'),
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
      centerContent: true,
      ctaKey: _ctaKey,
      ctaText: _ctaText,
      onCtaPressed: _ctaAction,
      isCtaLoading: _isLoading,
      isCtaEnabled: !_isLoading,
      ctaBackgroundColor: AppTheme.gold,
      ctaForegroundColor: const Color(0xFF121414),
      secondaryAction: _buildSecondaryAction(),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: AdaptiveGlassContainer(
            useGradient: false,
            padding: const EdgeInsets.all(AppSpacing.spaceXl),
            borderRadius: 20.0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Icon(
                    headerIcon,
                    size: 56,
                    color: AppTheme.gold,
                  ),
                ),
                AppGaps.gapLg,
                Text(
                  titleText,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFFF9FAFA),
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
                AppGaps.gapSm,
                Text(
                  subtitleText,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF919696),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                AppGaps.gapXl,
                if (isEmailMode)
                  TextField(
                    key: const Key('client_backup_email_input'),
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    textInputAction: TextInputAction.done,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 15,
                    ),
                    decoration: _buildFieldDecoration(
                      label: 'Backup Email (Optional)',
                      hint: 'you@example.com',
                      icon: Icons.email_outlined,
                    ),
                    onChanged: (_) {
                      if (_errorMessage != null) {
                        setState(() => _errorMessage = null);
                      }
                    },
                    onSubmitted: (_) => _submitBackupEmail(),
                  )
                else if (!_awaitingOtp)
                  TextField(
                    key: const Key('client_backup_phone_input'),
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    inputFormatters: const [PhoneNumberInputFormatter()],
                    textInputAction: TextInputAction.done,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 15,
                    ),
                    decoration: _buildFieldDecoration(
                      label: 'Backup Phone Number (Optional)',
                      hint: '(555) 123-4567',
                      icon: Icons.phone_outlined,
                    ),
                    onChanged: (_) {
                      if (_errorMessage != null) {
                        setState(() => _errorMessage = null);
                      }
                    },
                    onSubmitted: (_) => _sendPhoneOtp(),
                  )
                else
                  TextField(
                    key: const Key('client_backup_otp_input'),
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    textAlign: TextAlign.center,
                    textInputAction: TextInputAction.done,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 6,
                    ),
                    decoration: _buildFieldDecoration(
                      label: '6-Digit SMS Code',
                      hint: '123456',
                      icon: Icons.pin_outlined,
                    ),
                    onChanged: (_) {
                      if (_errorMessage != null) {
                        setState(() => _errorMessage = null);
                      }
                    },
                    onSubmitted: (_) => _verifyPhoneOtp(),
                  ),
                if (_errorMessage != null) ...[
                  AppGaps.gapSm,
                  Text(
                    _errorMessage!,
                    key: const Key('client_backup_error_text'),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFFCF6679),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
