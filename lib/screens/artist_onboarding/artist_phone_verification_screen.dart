import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../features/auth/presentation/screens/account_recovery_hub_screen.dart';
import '../../features/auth/presentation/sheets/delivery_troubleshooting_sheet.dart';
import '../../services/auth_service.dart';
import '../../widgets/adaptive_glass_container.dart';
import '../../widgets/fade_page_route.dart';
import '../../widgets/flash_snack_bar.dart';
import '../../widgets/tattoo_background_wrapper.dart';
import '../../features/onboarding/shared/onboarding_step_scaffold.dart';
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
  late String _verificationId = widget.verificationId.isNotEmpty
      ? widget.verificationId
      : (_authService.verificationId ?? '');
  late int? _resendToken = widget.resendToken ?? _authService.resendToken;

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
    FlashSnackBar.showError(context, message);
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

        // Update public artist document in Firestore (without PII)
        final artistDoc = FirebaseFirestore.instance.collection('artists').doc(uid);
        await artistDoc.set({
          'phoneVerified': true,
          'name': widget.artistName,
        }, SetOptions(merge: true));

        // Store private contact details in isolated subcollection
        await artistDoc.collection('private').doc('settings').set({
          'phoneVerified': true,
          'phoneNumber': widget.phoneNumber,
          'email': widget.artistEmail,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      if (mounted) {
        FocusManager.instance.primaryFocus?.unfocus();
        Navigator.pushReplacement(
          context,
          FadePageRoute(
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

  void _skipVerification() {
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.pushReplacement(
      context,
      FadePageRoute(
        builder: (_) => ArtistProfilePhotoScreen(
          artistName: widget.artistName,
          authService: _authService,
        ),
      ),
    );
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
            FlashSnackBar.showSuccess(
              context,
              'A new 6-digit code has been sent.',
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
        onCodeAutoRetrievalTimeout: (String verificationId) {
          if (mounted) {
            setState(() => _verificationId = verificationId);
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
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
        onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
        scrollPadding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
        ),
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
    return OnboardingStepScaffold(
      currentStep: 1,
      totalSteps: 9,
      onBack: Navigator.canPop(context)
          ? () {
              FocusManager.instance.primaryFocus?.unfocus();
              Navigator.pop(context);
            }
          : null,
      onSkip: _skipVerification,
      skipText: 'Skip',
      title: 'Verify your phone\nnumber',
      subtitle: 'We\'ve sent a 6-digit verification code\nto your device. Please enter it below.',
      ctaText: 'VERIFY',
      isCtaLoading: _isLoading,
      onCtaPressed: _isLoading ? null : _verifyCode,
      backgroundOverlay: const TattooBackgroundWrapper(child: SizedBox.expand()),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AdaptiveGlassContainer(
            useGradient: false,
            borderRadius: 16,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              children: [
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
                const SizedBox(height: 28),
                // 6-digit OTP Inputs Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(6, (index) => _buildDigitBox(index)),
                ),
                const SizedBox(height: 24),
                // Didn't receive code? Resend / Troubleshoot
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
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        DeliveryTroubleshootingSheet.show(
                          context: context,
                          destination: widget.phoneNumber,
                          isPhone: true,
                          onEditDestination: () => Navigator.pop(context),
                          onResendSms: _resendCode,
                          onSwitchToEmail: () {
                            Navigator.push(
                              context,
                              FadePageRoute(
                                builder: (_) => const AccountRecoveryHubScreen(),
                              ),
                            );
                          },
                        );
                      },
                      child: Text(
                        'Troubleshoot',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFEEC200),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
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
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
