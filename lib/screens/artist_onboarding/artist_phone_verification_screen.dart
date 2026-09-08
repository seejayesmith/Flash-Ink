import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/dev_config.dart';
import '../../services/auth_service.dart';
import '../../theme/app_radius.dart';
import '../../widgets/artist_stepper_header.dart';
import 'artist_profile_photo_screen.dart';

class ArtistPhoneVerificationScreen extends StatefulWidget {
  final String phoneNumber;
  final String verificationId;
  final int? resendToken;
  final String artistName;
  final String artistEmail;
  final AuthService? authService;

  const ArtistPhoneVerificationScreen({
    super.key,
    required this.phoneNumber,
    required this.verificationId,
    this.resendToken,
    required this.artistName,
    required this.artistEmail,
    this.authService,
  });

  @override
  State<ArtistPhoneVerificationScreen> createState() => _ArtistPhoneVerificationScreenState();
}

class _ArtistPhoneVerificationScreenState extends State<ArtistPhoneVerificationScreen> {
  late final AuthService _authService = widget.authService ?? AuthService();
  late String _verificationId = widget.verificationId;
  late int? _resendToken = widget.resendToken;

  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isLoading = false;
  int _resendCountdown = 30;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    setState(() => _resendCountdown = 30);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_resendCountdown > 1) {
        setState(() => _resendCountdown--);
      } else {
        setState(() => _resendCountdown = 0);
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    for (var c in _controllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _currentCode => _controllers.map((c) => c.text).join();

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

  Future<void> _verifyCode() async {
    final code = _currentCode.trim();
    if (code.length != 6) {
      _showErrorSnackBar('Please enter all 6 digits of the verification code.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userCredential = await _authService.signInWithPhoneCredential(
        verificationId: _verificationId,
        smsCode: code,
      );

      final uid = userCredential.user?.uid ?? _authService.currentUser?.uid;
      if (uid != null) {
        await _authService.updatePhoneVerificationStatus(
          uid: uid,
          phoneNumber: widget.phoneNumber,
        );

        // Update artist document in Firestore
        await FirebaseFirestore.instance.collection('artists').doc(uid).set({
          'phoneVerified': true,
          'phoneNumber': widget.phoneNumber,
          'name': widget.artistName,
          'email': widget.artistEmail,
        }, SetOptions(merge: true));
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ArtistProfilePhotoScreen(
              artistName: widget.artistName,
              authService: _authService,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        for (var c in _controllers) {
          c.clear();
        }
        _focusNodes[0].requestFocus();
        final errorMsg = e.toString().replaceAll('Exception: ', '');
        _showErrorSnackBar('Verification failed: $errorMsg');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _skipVerification() async {
    setState(() => _isLoading = true);
    try {
      final uid = _authService.currentUser?.uid;
      if (uid != null) {
        await _authService.updatePhoneVerificationStatus(
          uid: uid,
          phoneNumber: widget.phoneNumber,
        );

        await FirebaseFirestore.instance.collection('artists').doc(uid).set({
          'phoneVerified': true,
          'phoneNumber': widget.phoneNumber,
          'name': widget.artistName,
          'email': widget.artistEmail,
        }, SetOptions(merge: true));
      }
    } catch (_) {
      // Dev bypass allows local testing without remote backend connectivity
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ArtistProfilePhotoScreen(
              artistName: widget.artistName,
              authService: _authService,
            ),
          ),
        );
      }
    }
  }

  Future<void> _resendCode() async {
    if (_resendCountdown > 0) return;

    setState(() => _isLoading = true);
    try {
      await _authService.verifyPhoneNumber(
        phoneNumber: widget.phoneNumber,
        forceResendingToken: _resendToken,
        onCodeSent: (String verificationId, int? resendToken) {
          if (mounted) {
            setState(() {
              _verificationId = verificationId;
              _resendToken = resendToken;
              _isLoading = false;
            });
            _startCountdown();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('A new 6-digit code has been sent.'),
                backgroundColor: Color(0xFF22C55E),
              ),
            );
          }
        },
        onVerificationFailed: (Exception error) {
          if (mounted) {
            setState(() => _isLoading = false);
            final errorMsg = error.toString().replaceAll('Exception: ', '');
            _showErrorSnackBar(errorMsg);
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar(e.toString());
      }
    }
  }

  Widget _buildDigitBox(int index) {
    final hasText = _controllers[index].text.isNotEmpty;
    final isFocused = _focusNodes[index].hasFocus;

    return Container(
      width: 46,
      height: 58,
      decoration: BoxDecoration(
        color: const Color(0xFF1E2020),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (isFocused || hasText) ? const Color(0xFFEEC200) : const Color(0xFF383C3C),
          width: (isFocused || hasText) ? 2.0 : 1.0,
        ),
      ),
      alignment: Alignment.center,
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: const Color(0xFFEEC200),
        ),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(
          counterText: '',
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
        onChanged: (value) {
          if (value.isNotEmpty) {
            if (index < 5) {
              _focusNodes[index + 1].requestFocus();
            } else {
              _focusNodes[index].unfocus();
              _verifyCode();
            }
          } else if (index > 0) {
            _focusNodes[index - 1].requestFocus();
          }
          setState(() {});
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121414),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            children: [
              // Top Stepper (Still Step 1 active)
              const ArtistStepperHeader(currentStep: 1),
              const SizedBox(height: 24),

              // Main Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1C1C),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF2B2E2E)),
                ),
                child: Column(
                  children: [
                    // Back button in top-left & Dev-only Skip button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Color(0xFFF9FAFA)),
                          onPressed: () => Navigator.pop(context),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        if (kEnableDevBypass)
                          ElevatedButton.icon(
                            onPressed: _isLoading ? null : _skipVerification,
                            icon: const Icon(Icons.fast_forward, size: 16, color: Color(0xFF121414)),
                            label: Text(
                              'Skip',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF121414),
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEEC200),
                              foregroundColor: const Color(0xFF121414),
                              elevation: 2,
                              shape: const StadiumBorder(),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // SMS Chat Icon Badge
                    Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                        color: Color(0xFF252929),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.chat_bubble,
                          color: Color(0xFFEEC200),
                          size: 30,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Heading
                    Text(
                      'Verify your phone\nnumber',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFF9FAFA),
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Subtitle
                    Text(
                      'We\'ve sent a 6-digit verification code\nto your device. Please enter it below.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        color: const Color(0xFF919696),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // 6-digit OTP Inputs Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(6, (index) => _buildDigitBox(index)),
                    ),
                    const SizedBox(height: 32),

                    // VERIFY Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _verifyCode,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEEC200),
                          foregroundColor: const Color(0xFF121414),
                          disabledBackgroundColor: const Color(0xFFEEC200).withAlpha(120),
                          elevation: 0,
                          shape: const StadiumBorder(),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF121414)),
                                ),
                              )
                            : Text(
                                'VERIFY',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.1,
                                  color: const Color(0xFF121414),
                                ),
                              ),
                      ),
                    ),
                    if (kEnableDevBypass) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: OutlinedButton(
                          onPressed: _isLoading ? null : _skipVerification,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFEEC200), width: 1.2),
                            foregroundColor: const Color(0xFFEEC200),
                            shape: const StadiumBorder(),
                          ),
                          child: Text(
                            'Skip Verification (Dev)',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),

                    // Didn't receive code? Resend
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Didn't receive code? ",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            color: const Color(0xFF919696),
                          ),
                        ),
                        GestureDetector(
                          onTap: (_resendCountdown == 0 && !_isLoading) ? _resendCode : null,
                          child: Text(
                            _resendCountdown > 0 ? 'Resend in ${_resendCountdown}s' : 'Resend',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: _resendCountdown > 0
                                  ? const Color(0xFF6C7272)
                                  : const Color(0xFFEEC200),
                            ),
                          ),
                        ),
                      ],
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
