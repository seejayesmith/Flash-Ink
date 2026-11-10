import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../theme/app_buttons.dart';
import '../theme/app_radius.dart';
import '../theme/app_theme.dart';
import 'flash_snack_bar.dart';
import 'phone_number_input_formatter.dart';

/// An inline expandable settings tile for adding, verifying, or changing
/// a user's phone number via SMS OTP directly within Account Settings.
class InlinePhoneVerificationTile extends StatefulWidget {
  final String phoneNumber;
  final bool phoneVerified;
  final AuthService? authService;
  final FirebaseFirestore? firestore;
  final bool isArtist;
  final void Function(String newPhoneNumber)? onPhoneVerified;

  const InlinePhoneVerificationTile({
    super.key,
    required this.phoneNumber,
    required this.phoneVerified,
    this.authService,
    this.firestore,
    this.isArtist = false,
    this.onPhoneVerified,
  });

  @override
  State<InlinePhoneVerificationTile> createState() =>
      _InlinePhoneVerificationTileState();
}

class _InlinePhoneVerificationTileState
    extends State<InlinePhoneVerificationTile> {
  late final AuthService _authService = widget.authService ?? AuthService();

  bool _isExpanding = false;
  bool _isCodeSent = false;
  bool _isSendingCode = false;
  bool _isVerifying = false;
  String? _errorMessage;
  String? _verificationId;
  int? _resendToken;

  late final TextEditingController _phoneController;
  late final TextEditingController _otpController;

  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController(
      text: widget.phoneVerified
          ? AuthService.formatDisplayPhoneNumber(widget.phoneNumber)
          : '',
    );
    _otpController = TextEditingController();
  }

  @override
  void didUpdateWidget(covariant InlinePhoneVerificationTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.phoneNumber != widget.phoneNumber && !_isExpanding) {
      _phoneController.text = widget.phoneVerified
          ? AuthService.formatDisplayPhoneNumber(widget.phoneNumber)
          : '';
    }
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _cooldownSeconds = 30);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_cooldownSeconds <= 1) {
        timer.cancel();
        setState(() => _cooldownSeconds = 0);
      } else {
        setState(() => _cooldownSeconds--);
      }
    });
  }

  void _startInlineFlow() {
    setState(() {
      _isExpanding = true;
      _isCodeSent = false;
      _errorMessage = null;
      _otpController.clear();
      if (!widget.phoneVerified) {
        _phoneController.clear();
      }
    });
  }

  void _cancelInlineFlow() {
    FocusManager.instance.primaryFocus?.unfocus();
    _cooldownTimer?.cancel();
    setState(() {
      _isExpanding = false;
      _isCodeSent = false;
      _isSendingCode = false;
      _isVerifying = false;
      _errorMessage = null;
      _cooldownSeconds = 0;
      _otpController.clear();
      _phoneController.text = widget.phoneVerified
          ? AuthService.formatDisplayPhoneNumber(widget.phoneNumber)
          : '';
    });
  }

  Future<void> _sendCode() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final rawInput = _phoneController.text.trim();
    final digits = rawInput.replaceAll(RegExp(r'\D'), '');

    if (rawInput.isEmpty) {
      setState(() => _errorMessage = 'Please enter a phone number.');
      return;
    }
    if (digits.length < 10) {
      setState(() => _errorMessage = 'Please enter a valid 10-digit phone number.');
      return;
    }

    final formattedE164 = AuthService.formatE164PhoneNumber(rawInput);

    setState(() {
      _isSendingCode = true;
      _errorMessage = null;
    });

    try {
      await _authService.verifyPhoneNumber(
        phoneNumber: formattedE164,
        forceResendingToken: _resendToken,
        onVerificationCompleted: (PhoneAuthCredential credential) async {
          if (!mounted) return;
          // Instant auto-retrieval
          await _onAutoVerificationCompleted(credential, formattedE164);
        },
        onCodeSent: (String verificationId, int? resendToken) {
          if (!mounted) return;
          setState(() {
            _verificationId = verificationId;
            _resendToken = resendToken;
            _isCodeSent = true;
            _isSendingCode = false;
            _errorMessage = null;
          });
          _startCooldown();
        },
        onVerificationFailed: (Exception error) {
          if (!mounted) return;
          final cleanMsg = error.toString().replaceAll('Exception: ', '');
          setState(() {
            _isSendingCode = false;
            _errorMessage = cleanMsg;
          });
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSendingCode = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  Future<void> _onAutoVerificationCompleted(
    PhoneAuthCredential credential,
    String formattedE164,
  ) async {
    try {
      final user = _authService.currentUser;
      if (user != null) {
        try {
          await user.linkWithCredential(credential);
        } catch (_) {}

        await _authService.updatePhoneVerificationStatus(
          uid: user.uid,
          phoneNumber: formattedE164,
        );

        if (widget.isArtist) {
          final db = widget.firestore ?? FirebaseFirestore.instance;
          await db
              .collection('artists')
              .doc(user.uid)
              .collection('private')
              .doc('settings')
              .set({
            'phoneNumber': formattedE164,
            'phoneVerified': true,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      }
      if (!mounted) return;
      _finalizeSuccess(formattedE164);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSendingCode = false;
          _isVerifying = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  Future<void> _verifyOtp() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final smsCode = _otpController.text.trim();

    if (smsCode.length < 6) {
      setState(() => _errorMessage = 'Please enter the 6-digit verification code.');
      return;
    }

    final effectiveVid = _verificationId ?? _authService.verificationId ?? '';
    if (effectiveVid.isEmpty) {
      setState(() => _errorMessage = 'Verification session expired. Please request a new code.');
      return;
    }

    final formattedE164 = AuthService.formatE164PhoneNumber(_phoneController.text);

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      await _authService.linkWithPhoneCredential(
        verificationId: effectiveVid,
        smsCode: smsCode,
        phoneNumber: formattedE164,
      );

      final user = _authService.currentUser;
      if (user != null && widget.isArtist) {
        try {
          final db = widget.firestore ?? FirebaseFirestore.instance;
          await db
              .collection('artists')
              .doc(user.uid)
              .collection('private')
              .doc('settings')
              .set({
            'phoneNumber': formattedE164,
            'phoneVerified': true,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } catch (_) {}
      }

      if (!mounted) return;
      _finalizeSuccess(formattedE164);
    } catch (e) {
      if (mounted) {
        final cleanMsg = e.toString().replaceAll('Exception: ', '');
        setState(() {
          _isVerifying = false;
          _errorMessage = cleanMsg;
        });
      }
    }
  }

  void _finalizeSuccess(String formattedE164) {
    _cooldownTimer?.cancel();
    setState(() {
      _isExpanding = false;
      _isCodeSent = false;
      _isSendingCode = false;
      _isVerifying = false;
      _errorMessage = null;
    });
    FlashSnackBar.showSuccess(context, 'Phone number verified successfully');
    widget.onPhoneVerified?.call(formattedE164);
  }

  @override
  Widget build(BuildContext context) {
    final hasVerifiedPhone =
        widget.phoneVerified && widget.phoneNumber.trim().isNotEmpty;
    final displayPhone = hasVerifiedPhone
        ? AuthService.formatDisplayPhoneNumber(widget.phoneNumber)
        : 'Not added';

    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      child: _isExpanding
          ? _buildExpandedForm(hasVerifiedPhone: hasVerifiedPhone)
          : _buildCollapsedTile(
              hasVerifiedPhone: hasVerifiedPhone,
              displayPhone: displayPhone,
            ),
    );
  }

  Widget _buildCollapsedTile({
    required bool hasVerifiedPhone,
    required String displayPhone,
  }) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        key: const Key('account_phone_number_tile'),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        leading: const Icon(Icons.phone_outlined, color: AppTheme.gold, size: 20),
        title: Text(
          'Phone Number',
          style: GoogleFonts.plusJakartaSans(
            color: AppTheme.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          displayPhone,
          key: const Key('account_phone_subtitle'),
          style: GoogleFonts.plusJakartaSans(
            color: hasVerifiedPhone
                ? const Color(0xFF919696)
                : const Color(0xFF6B7280),
            fontSize: 12,
          ),
        ),
        trailing: hasVerifiedPhone
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    key: const Key('phone_verified_badge'),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0x2222C55E),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: const Color(0xFF22C55E), width: 0.8),
                    ),
                    child: Text(
                      'VERIFIED',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF22C55E),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    key: const Key('change_phone_button'),
                    onPressed: _startInlineFlow,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Change',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.gold,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              )
            : TextButton.icon(
                key: const Key('add_phone_button'),
                onPressed: _startInlineFlow,
                icon: const Icon(Icons.add, size: 14, color: AppTheme.gold),
                label: Text(
                  'Add',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.gold,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0x1AEEC200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: AppTheme.gold, width: 0.8),
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
        onTap: _startInlineFlow,
      ),
    );
  }

  Widget _buildExpandedForm({required bool hasVerifiedPhone}) {
    return Container(
      key: const Key('inline_phone_expansion_container'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2121),
        borderRadius: BorderRadius.circular(AppRadius.radiusSm),
        border: Border.all(color: const Color(0xFF2E3232)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.phone_outlined,
                      color: AppTheme.gold, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    _isCodeSent
                        ? 'Enter OTP Code'
                        : (hasVerifiedPhone
                            ? 'Change Phone Number'
                            : 'Add Phone Number'),
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              IconButton(
                key: const Key('inline_phone_cancel_button'),
                icon: const Icon(Icons.close, color: Color(0xFF919696), size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: _cancelInlineFlow,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!_isCodeSent) ...[
            Text(
              'A 6-digit SMS verification code will be sent to this number.',
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF919696),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const Key('inline_phone_input_field'),
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              enabled: !_isSendingCode,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 15,
              ),
              inputFormatters: const [PhoneNumberInputFormatter()],
              decoration: InputDecoration(
                hintText: '(555) 000-0000',
                hintStyle: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF6E7474),
                  fontSize: 15,
                ),
                filled: true,
                fillColor: const Color(0xFF141616),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                  borderSide:
                      const BorderSide(color: AppTheme.gold, width: 1.5),
                ),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                key: const Key('inline_phone_error_text'),
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFFEF4444),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const SizedBox(height: 14),
            AppButtons.primaryCTA(
              key: const Key('inline_phone_send_code_button'),
              text: 'SEND VERIFICATION CODE',
              isLoading: _isSendingCode,
              onPressed: _isSendingCode ? null : _sendCode,
            ),
          ] else ...[
            Text(
              'We sent a 6-digit code to ${_phoneController.text.trim()}',
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF919696),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const Key('inline_phone_otp_field'),
              controller: _otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              enabled: !_isVerifying,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 18,
                letterSpacing: 4,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                counterText: '',
                hintText: '••••••',
                hintStyle: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF6E7474),
                  letterSpacing: 4,
                ),
                filled: true,
                fillColor: const Color(0xFF141616),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                  borderSide:
                      const BorderSide(color: AppTheme.gold, width: 1.5),
                ),
              ),
              onSubmitted: (_) => _verifyOtp(),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                key: const Key('inline_phone_error_text'),
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFFEF4444),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: AppButtons.primaryCTA(
                    key: const Key('inline_phone_verify_button'),
                    text: 'VERIFY & SAVE',
                    isLoading: _isVerifying,
                    onPressed: _isVerifying ? null : _verifyOtp,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  key: const Key('inline_phone_edit_number_link'),
                  onPressed: _isVerifying
                      ? null
                      : () {
                          setState(() {
                            _isCodeSent = false;
                            _errorMessage = null;
                            _otpController.clear();
                          });
                        },
                  child: Text(
                    'Change Number',
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFF919696),
                      fontSize: 12,
                    ),
                  ),
                ),
                TextButton(
                  key: const Key('inline_phone_resend_code_button'),
                  onPressed: (_isSendingCode || _cooldownSeconds > 0)
                      ? null
                      : _sendCode,
                  child: Text(
                    _cooldownSeconds > 0
                        ? 'Resend in ${_cooldownSeconds}s'
                        : 'Resend Code',
                    style: GoogleFonts.plusJakartaSans(
                      color: _cooldownSeconds > 0
                          ? const Color(0xFF6E7474)
                          : AppTheme.gold,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
