import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../theme/app_spacing.dart';
import '../theme/app_radius.dart';
import '../theme/app_buttons.dart';
import '../widgets/adaptive_glass_container.dart';
import 'profile_setup_screen.dart';
import 'role_selection_screen.dart';

class PhoneVerificationScreen extends StatefulWidget {
  final String phoneNumber;
  final String verificationId;
  final int? resendToken;
  final AuthService? authService;

  const PhoneVerificationScreen({
    super.key,
    this.phoneNumber = '+1 (555) 019-2834',
    this.verificationId = 'test_verification_id',
    this.resendToken,
    this.authService,
  });

  @override
  State<PhoneVerificationScreen> createState() => _PhoneVerificationScreenState();
}

class _PhoneVerificationScreenState extends State<PhoneVerificationScreen> {
  late final AuthService _authService = widget.authService ?? AuthService();
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = false;
  late String _verificationId = widget.verificationId;
  late int? _resendToken = widget.resendToken;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verifyCode() async {
    final code = _codeController.text.trim();
    if (code.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 6-digit verification code'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
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
      }

      if (mounted) {
        // Destructive routing: Replace SMS screen with Profile Setup
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ProfileSetupScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        _codeController.clear();
        final errorMsg = e.toString().replaceAll('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Verification failed: $errorMsg',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: AppBorderRadius.md),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _resendCode() async {
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
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  errorMsg,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                backgroundColor: const Color(0xFFEF4444),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: AppBorderRadius.md),
              ),
            );
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        final errorMsg = e.toString().replaceAll('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              errorMsg,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: AppBorderRadius.md),
          ),
        );
      }
    }
  }

  Future<void> _handleCancel() async {
    await _authService.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Prevent skipping SMS verification
      child: Scaffold(
        backgroundColor: const Color(0xFF121414),
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          flexibleSpace: const AdaptiveGlassContainer(
            borderRadius: 0,
            unselectedBorderWidth: 0,
            child: SizedBox.expand(),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFFF9FAFA)),
            onPressed: _handleCancel,
          ),
          title: Text(
            'Security Check',
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFFF9FAFA),
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          centerTitle: true,
        ),
        body: Stack(
          children: [
            // Background subtle tattoo texture extending edge to edge
            Positioned.fill(
              child: Image.asset(
                'assets/images/tattoo_setup.png',
                fit: BoxFit.cover,
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
                      Colors.black.withAlpha(140),
                      Colors.black.withAlpha(160),
                      Colors.black.withAlpha(220),
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
                    padding: AppPadding.screenHorizontal,
                    physics: const BouncingScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: IntrinsicHeight(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppGaps.gapLg,
                            // Liquid Glass Verification Card
                            AdaptiveGlassContainer(
                              borderRadius: 20.0,
                              padding: const EdgeInsets.all(AppSpacing.spaceLg),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(AppSpacing.spaceSm),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEEC200).withAlpha(25),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.phonelink_lock,
                                      color: Color(0xFFEEC200),
                                      size: 38,
                                    ),
                                  ),
                                  AppGaps.gapMd,
                                  Text(
                                    'Verify your number.',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: const Color(0xFFF9FAFA),
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      height: 1.15,
                                    ),
                                  ),
                                  AppGaps.gapSm,
                                  Text(
                                    'We\'ve sent a 6-digit verification code to ${widget.phoneNumber}.',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: const Color(0xFF919696),
                                      fontSize: 14,
                                      height: 1.4,
                                    ),
                                  ),
                                  AppGaps.gapXl,
                                  // OTP Field with translucent glass fill
                                  TextField(
                                    controller: _codeController,
                                    keyboardType: TextInputType.number,
                                    maxLength: 6,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Color(0xFFF9FAFA),
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 16,
                                    ),
                                    decoration: InputDecoration(
                                      counterText: '',
                                      filled: true,
                                      fillColor: Colors.black.withAlpha(120),
                                      contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.spaceMd),
                                      border: OutlineInputBorder(
                                        borderRadius: AppBorderRadius.md,
                                        borderSide: const BorderSide(color: Color(0xFF333737)),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: AppBorderRadius.md,
                                        borderSide: const BorderSide(color: Color(0xFF333737), width: 1.5),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: AppBorderRadius.md,
                                        borderSide: const BorderSide(color: Color(0xFFEEC200), width: 2),
                                      ),
                                    ),
                                    onChanged: (val) {
                                      if (val.length == 6) {
                                        _verifyCode();
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            AppGaps.gapLg,
                        AppButtons.primaryCTA(
                          isLoading: _isLoading,
                          onPressed: _verifyCode,
                          text: 'VERIFY',
                        ),
                        AppGaps.gapLg,
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              "Didn't receive code? ",
                              style: TextStyle(color: Color(0xFF919696), fontSize: 14),
                            ),
                            TextButton(
                              onPressed: _isLoading ? null : _resendCode,
                              child: const Text(
                                'Resend',
                                style: TextStyle(
                                  color: Color(0xFFEEC200),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                        AppGaps.gapLg,
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    ),
    ),
    );
  }
}
