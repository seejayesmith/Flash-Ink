import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../theme/app_radius.dart';
import '../theme/app_theme.dart';
import 'adaptive_glass_container.dart';
import 'keyboard_collapse_button.dart';

/// Modal bottom sheet that prompts users to re-authenticate when attempting
/// sensitive actions (such as account deletion) when Firebase throws `requires-recent-login`.
class ReauthenticationBottomSheet extends StatefulWidget {
  final AuthService authService;
  final VoidCallback? onSuccess;

  const ReauthenticationBottomSheet({
    super.key,
    required this.authService,
    this.onSuccess,
  });

  /// Presents the bottom sheet with keyboard awareness.
  static Future<bool?> show({
    required BuildContext context,
    required AuthService authService,
    VoidCallback? onSuccess,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: ReauthenticationBottomSheet(
          authService: authService,
          onSuccess: onSuccess,
        ),
      ),
    );
  }

  @override
  State<ReauthenticationBottomSheet> createState() => _ReauthenticationBottomSheetState();
}

class _ReauthenticationBottomSheetState extends State<ReauthenticationBottomSheet> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _smsCodeController = TextEditingController();

  bool _obscurePassword = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  // Phone auth state
  String? _verificationId;
  bool _isCodeSent = false;
  bool _isSendingCode = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _smsCodeController.dispose();
    super.dispose();
  }

  List<String> get _providers => widget.authService.currentUserProviders;
  bool get _isGoogle => _providers.contains('google.com');
  bool get _isApple => _providers.contains('apple.com');
  bool get _isPhone => _providers.contains('phone');
  bool get _isPassword =>
      _providers.contains('password') ||
      (!_isGoogle && !_isApple && !_isPhone && (widget.authService.currentUser?.email != null));

  Future<void> _handleReauthSuccess() async {
    try {
      await widget.authService.deleteAccount();
      if (mounted) {
        widget.onSuccess?.call();
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _submitPassword() async {
    final password = _passwordController.text.trim();
    if (password.isEmpty) {
      setState(() => _errorMessage = 'Please enter your password.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await widget.authService.reauthenticateWithPassword(password);
      await _handleReauthSuccess();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _sendPhoneCode() async {
    setState(() {
      _isSendingCode = true;
      _errorMessage = null;
    });

    try {
      await widget.authService.sendPhoneReauthCode(
        onCodeSent: (verificationId, resendToken) {
          if (mounted) {
            setState(() {
              _verificationId = verificationId;
              _isCodeSent = true;
              _isSendingCode = false;
            });
          }
        },
        onVerificationFailed: (error) {
          if (mounted) {
            setState(() {
              _isSendingCode = false;
              _errorMessage = error.toString().replaceFirst('Exception: ', '');
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSendingCode = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _submitPhoneCode() async {
    final code = _smsCodeController.text.trim();
    if (code.isEmpty || code.length < 6) {
      setState(() => _errorMessage = 'Please enter the 6-digit verification code.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await widget.authService.reauthenticateWithPhoneCredential(
        verificationId: _verificationId ?? '',
        smsCode: code,
      );
      await _handleReauthSuccess();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _submitGoogle() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await widget.authService.reauthenticateWithGoogle();
      await _handleReauthSuccess();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _submitApple() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await widget.authService.reauthenticateWithApple();
      await _handleReauthSuccess();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.authService.currentUser;

    return AdaptiveGlassContainer.bottomSheet(
      glassEnabled: false,
      androidSurfaceColor: const Color(0xFF161818),
      selectedBorderColor: AppTheme.gold,
      unselectedBorderColor: AppTheme.goldBorder,
      selectedBorderWidth: 1.5,
      unselectedBorderWidth: 1.5,
      topRadius: AppRadius.radiusSheet,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 28),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF333838),
                    borderRadius: BorderRadius.circular(AppRadius.dragHandle),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.gold.withAlpha(28),
                      borderRadius: BorderRadius.circular(AppRadius.radiusMd),
                      border: Border.all(
                        color: AppTheme.gold.withAlpha(120),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      color: AppTheme.gold,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Security Verification',
                          key: const Key('reauth_modal_title'),
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Confirm your identity to delete your account',
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFF8C9191),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const KeyboardCollapseButton(),
                ],
              ),
              const SizedBox(height: 20),

              // Description banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.onyxContainer,
                  borderRadius: BorderRadius.circular(AppRadius.radiusMd),
                  border: Border.all(color: AppTheme.darkBorder),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: Color(0xFF8C9191),
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'For security, Firebase requires recent authentication before permanently deleting your account and all associated data.',
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFFB0B6B6),
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Inline Error
              if (_errorMessage != null) ...[
                Container(
                  key: const Key('reauth_error_banner'),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withAlpha(25),
                    borderRadius: BorderRadius.circular(AppRadius.radiusSm),
                    border: Border.all(
                      color: const Color(0xFFEF4444).withAlpha(120),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Color(0xFFEF4444),
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFFEF4444),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Provider-specific input forms
              if (_isPassword) _buildPasswordForm(user?.email),
              if (_isPhone) _buildPhoneForm(user?.phoneNumber),
              if (_isGoogle) _buildGoogleButton(user?.email),
              if (_isApple) _buildAppleButton(),

              const SizedBox(height: 12),

              // Cancel button
              Center(
                child: TextButton(
                  key: const Key('reauth_cancel_button'),
                  onPressed: _isSubmitting
                      ? null
                      : () => Navigator.of(context).pop(false),
                  child: Text(
                    'Cancel Deletion',
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFF8C9191),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
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

  Widget _buildPasswordForm(String? email) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (email != null && email.isNotEmpty) ...[
          Text(
            'Account Email: $email',
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFF8C9191),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
        ],
        Text(
          'Enter Password',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          key: const Key('reauth_password_field'),
          controller: _passwordController,
          obscureText: _obscurePassword,
          enabled: !_isSubmitting,
          style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Enter your account password',
            hintStyle: GoogleFonts.plusJakartaSans(color: const Color(0xFF6E7474), fontSize: 14),
            filled: true,
            fillColor: const Color(0xFF1E2020),
            prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF8C9191), size: 20),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                color: const Color(0xFF8C9191),
                size: 20,
              ),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.radiusSm),
              borderSide: const BorderSide(color: Color(0xFF2E3232)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.radiusSm),
              borderSide: const BorderSide(color: Color(0xFF2E3232)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.radiusSm),
              borderSide: const BorderSide(color: AppTheme.gold, width: 1.5),
            ),
          ),
          onSubmitted: (_) => _submitPassword(),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            key: const Key('reauth_confirm_button'),
            onPressed: _isSubmitting ? null : _submitPassword,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.radiusMd),
              ),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    'Verify & Delete Account',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneForm(String? phone) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (phone != null && phone.isNotEmpty) ...[
          Text(
            'Registered Phone: $phone',
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFF8C9191),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (!_isCodeSent) ...[
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              key: const Key('reauth_send_code_button'),
              onPressed: _isSendingCode ? null : _sendPhoneCode,
              icon: const Icon(Icons.sms_outlined, size: 20),
              label: _isSendingCode
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                      ),
                    )
                  : Text(
                      'Send Verification SMS',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.gold,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.radiusMd),
                ),
              ),
            ),
          ),
        ] else ...[
          Text(
            'Enter 6-digit Code',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('reauth_sms_code_field'),
            controller: _smsCodeController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            enabled: !_isSubmitting,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 18,
              letterSpacing: 4,
            ),
            decoration: InputDecoration(
              counterText: '',
              hintText: '••••••',
              hintStyle: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF6E7474),
                letterSpacing: 4,
              ),
              filled: true,
              fillColor: const Color(0xFF1E2020),
              prefixIcon: const Icon(Icons.lock_clock_outlined, color: Color(0xFF8C9191), size: 20),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.radiusSm),
                borderSide: const BorderSide(color: Color(0xFF2E3232)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.radiusSm),
                borderSide: const BorderSide(color: Color(0xFF2E3232)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.radiusSm),
                borderSide: const BorderSide(color: AppTheme.gold, width: 1.5),
              ),
            ),
            onSubmitted: (_) => _submitPhoneCode(),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              key: const Key('reauth_confirm_button'),
              onPressed: _isSubmitting ? null : _submitPhoneCode,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.radiusMd),
                ),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      'Verify & Delete Account',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              key: const Key('reauth_resend_code_button'),
              onPressed: _isSendingCode ? null : _sendPhoneCode,
              child: Text(
                'Resend SMS Code',
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.gold,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildGoogleButton(String? email) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (email != null && email.isNotEmpty) ...[
          Text(
            'Signed in with Google ($email)',
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFF8C9191),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
        ],
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            key: const Key('reauth_google_button'),
            onPressed: _isSubmitting ? null : _submitGoogle,
            icon: const Icon(Icons.g_mobiledata, size: 28),
            label: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    'Verify with Google & Delete',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.radiusMd),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAppleButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        key: const Key('reauth_apple_button'),
        onPressed: _isSubmitting ? null : _submitApple,
        icon: const Icon(Icons.apple, size: 22),
        label: _isSubmitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                'Verify with Apple & Delete',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFEF4444),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.radiusMd),
          ),
        ),
      ),
    );
  }
}
