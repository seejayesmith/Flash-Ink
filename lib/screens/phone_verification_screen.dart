import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../features/auth/presentation/screens/account_recovery_hub_screen.dart';
import '../features/auth/presentation/screens/auth_lockout_screen.dart';
import '../features/auth/presentation/sheets/account_collision_sheet.dart';
import '../features/auth/presentation/sheets/delivery_troubleshooting_sheet.dart';
import '../services/auth_service.dart';
import '../theme/app_spacing.dart';
import '../theme/app_radius.dart';
import '../widgets/adaptive_glass_container.dart';
import '../widgets/flash_glass_app_bar.dart';
import '../widgets/flash_snack_bar.dart';
import '../widgets/fade_page_route.dart';
import '../widgets/pinned_bottom_action_scaffold.dart';
import 'auth_routing.dart';
import 'profile_setup_screen.dart';
import 'role_selection_screen.dart';

class PhoneVerificationScreen extends StatefulWidget {
  final String phoneNumber;
  final String verificationId;
  final int? resendToken;
  final String? role;
  final AuthService? authService;

  const PhoneVerificationScreen({
    super.key,
    this.phoneNumber = '+1 (555) 019-2834',
    this.verificationId = 'test_verification_id',
    this.resendToken,
    this.role,
    this.authService,
  });

  @override
  State<PhoneVerificationScreen> createState() => _PhoneVerificationScreenState();
}

class _PhoneVerificationScreenState extends State<PhoneVerificationScreen> {
  late final AuthService _authService = widget.authService ?? AuthService();
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  late String _verificationId = widget.verificationId.isNotEmpty
      ? widget.verificationId
      : (_authService.verificationId ?? '');
  late int? _resendToken = widget.resendToken ?? _authService.resendToken;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _routeVerifiedUser(User? user) async {
    if (!mounted) return;
    if (user != null) {
      await AuthRouting.routeUserAfterAuth(
        context,
        user,
        defaultRole: widget.role,
        authService: _authService,
      );
    } else {
      Navigator.pushReplacement(
        context,
        FadePageRoute(builder: (_) => ProfileSetupScreen(authService: _authService)),
      );
    }
  }

  Future<void> _verifyCode() async {
    if (_isLoading) return;
    final code = _codeController.text.trim();
    if (code.length < 6) {
      if (code.isEmpty && _errorMessage != null) {
        return;
      }
      setState(() {
        _errorMessage = 'Please enter a valid 6-digit verification code';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final effectiveVerificationId = _verificationId.isNotEmpty
          ? _verificationId
          : (_authService.verificationId ?? '');
      final userCredential = await _authService.signInWithPhoneCredential(
        verificationId: effectiveVerificationId,
        smsCode: code,
      );

      final user = userCredential.user ?? _authService.currentUser;
      final uid = user?.uid;
      if (uid != null) {
        await _authService.updatePhoneVerificationStatus(
          uid: uid,
          phoneNumber: widget.phoneNumber,
        );
      }

      if (mounted) {
        await _routeVerifiedUser(user);
      }
    } catch (e) {
      if (mounted) {
        _codeController.clear();
        final errorMsg = e.toString().replaceAll('Exception: ', '');
        if (errorMsg.contains('too-many-requests') || errorMsg.contains('Too many attempts')) {
          Navigator.push(
            context,
            FadePageRoute(builder: (_) => const AuthLockoutScreen()),
          );
          return;
        }
        if (e is FirebaseAuthException && e.code == 'account-exists-with-different-credential') {
          AccountCollisionSheet.show(
            context: context,
            email: e.email ?? '',
            existingProvider: 'Existing Provider',
            newProvider: 'Phone',
            pendingCredential: e.credential,
          );
          return;
        }
        setState(() {
          _errorMessage = 'Verification failed: $errorMsg';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showDeliveryTroubleshooting() {
    DeliveryTroubleshootingSheet.show(
      context: context,
      destination: widget.phoneNumber,
      isPhone: true,
      onEditDestination: () {
        Navigator.pop(context);
      },
      onResendSms: _resendCode,
      onWhatsAppVoice: () {
        FlashSnackBar.showInfo(
          context,
          'Voice call verification requested. An automated call will arrive shortly.',
        );
      },
      onSwitchToEmail: () {
        Navigator.push(
          context,
          FadePageRoute(builder: (_) => const AccountRecoveryHubScreen()),
        );
      },
    );
  }

  Future<void> _resendCode() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await _authService.verifyPhoneNumber(
        phoneNumber: widget.phoneNumber,
        forceResendingToken: _resendToken,
        onVerificationCompleted: (PhoneAuthCredential credential) async {
          final user = _authService.currentUser;
          if (user != null) {
            try {
              await _authService.updatePhoneVerificationStatus(
                uid: user.uid,
                phoneNumber: widget.phoneNumber,
              );
            } catch (_) {}
          }
          if (mounted) {
            setState(() => _isLoading = false);
            await _routeVerifiedUser(user);
          }
        },
        onCodeSent: (String verificationId, int? resendToken) {
          if (mounted) {
            setState(() {
              _verificationId = verificationId;
              _resendToken = resendToken;
              _errorMessage = null;
              _isLoading = false;
            });
            FlashSnackBar.showSuccess(
              context,
              'A new 6-digit code has been sent.',
            );
          }
        },
        onVerificationFailed: (Exception error) {
          if (mounted) {
            final errorMsg = error.toString().replaceAll('Exception: ', '');
            setState(() {
              _isLoading = false;
              _errorMessage = errorMsg;
            });
          }
        },
        onCodeAutoRetrievalTimeout: (String verificationId) {
          if (mounted) {
            setState(() {
              _verificationId = verificationId;
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        final errorMsg = e.toString().replaceAll('Exception: ', '');
        setState(() {
          _isLoading = false;
          _errorMessage = errorMsg;
        });
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

  Future<void> _handleSkip() async {
    setState(() => _isLoading = true);
    try {
      final uid = _authService.currentUser?.uid;
      if (uid != null) {
        await _authService.updatePhoneVerificationStatus(
          uid: uid,
          phoneNumber: widget.phoneNumber,
        );
      }
    } catch (_) {
      // Allow skip even if status update fails
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        await _routeVerifiedUser(_authService.currentUser);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Prevent skipping SMS verification via back swipe
      child: PinnedBottomActionScaffold(
        backgroundColor: const Color(0xFF121414),
        extendBodyBehindAppBar: true,
        appBar: FlashGlassAppBar(
          onBackPressed: _handleCancel,
          title: Text(
            'Security Check',
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFFF9FAFA),
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
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
          ],
        ),
        centerContent: false,
        ctaText: 'VERIFY',
        onCtaPressed: _verifyCode,
        isCtaLoading: _isLoading,
        secondaryAction: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                GestureDetector(
                  onTap: _showDeliveryTroubleshooting,
                  child: const Text(
                    "Didn't receive code? ",
                    style: TextStyle(color: Color(0xFF919696), fontSize: 14),
                  ),
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
                TextButton(
                  key: const Key('phone_verification_troubleshoot_button'),
                  onPressed: _isLoading ? null : _showDeliveryTroubleshooting,
                  child: const Text(
                    'Troubleshoot',
                    style: TextStyle(
                      color: Color(0xFFEEC200),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            TextButton(
              key: const Key('phone_verification_trouble_link'),
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
          ],
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: AdaptiveGlassContainer(
          useGradient: false,
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
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
              ),
              AppGaps.gapSm,
              Text(
                'We\'ve sent a 6-digit verification code to ${widget.phoneNumber}.',
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF919696),
                  fontSize: 15,
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
                  if (_errorMessage != null && val.isNotEmpty) {
                    setState(() => _errorMessage = null);
                  }
                  if (val.length == 6) {
                    _verifyCode();
                  }
                },
              ),
              if (_errorMessage != null) ...[
                AppGaps.gapMd,
                Container(
                  key: const Key('phone_verification_error_banner'),
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
