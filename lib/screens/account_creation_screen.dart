import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../config/dev_config.dart';
import '../services/auth_service.dart';
import '../theme/app_spacing.dart';
import '../theme/app_radius.dart';
import '../theme/app_buttons.dart';
import 'phone_verification_screen.dart';
import 'aesthetics_selection_screen.dart';
import 'profile_setup_screen.dart';
import '../widgets/adaptive_glass_container.dart';

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
  bool _isLoading = false;

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

  Future<void> _handleOAuth(Future<UserCredential?> Function() signInMethod) async {
    setState(() => _isLoading = true);
    try {
      final credential = await signInMethod();
      if (credential != null && credential.user != null) {
        // Save selected role to Firestore
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(credential.user!.uid)
              .set({'role': widget.role}, SetOptions(merge: true));
        } catch (_) {}

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const ProfileSetupScreen()),
          );
        }
      }
    } catch (e) {
      _showErrorSnackBar(e.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
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

  void _showEmailAuthModal() {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    bool isSignUp = true;
    bool isModalLoading = false;
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(modalContext).viewInsets.bottom,
              ),
              child: SafeArea(
                top: false,
                child: AdaptiveGlassContainer(
                  customBorderRadius: const BorderRadius.vertical(top: Radius.circular(24.0)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.spaceLg,
                      vertical: AppSpacing.spaceLg,
                    ),
                    child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: const Color(0xFF4D5252),
                          borderRadius: BorderRadius.circular(3), // Small pill
                        ),
                      ),
                    ),
                    AppGaps.gapLg,
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          isSignUp ? 'Create with Email' : 'Sign in with Email',
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFFF9FAFA),
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (kEnableDevBypass)
                          TextButton.icon(
                            onPressed: () {
                              Navigator.of(modalContext).pop();
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(builder: (_) => const ProfileSetupScreen()),
                              );
                            },
                            icon: const Icon(Icons.fast_forward, size: 14, color: Color(0xFFEEC200)),
                            label: const Text(
                              'Skip (Dev)',
                              style: TextStyle(
                                color: Color(0xFFEEC200),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                    AppGaps.gapLg,
                    Text(
                      'Email Address',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFFF9FAFA),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    AppGaps.gapXs,
                    TextFormField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: Color(0xFFF9FAFA)),
                      validator: (v) =>
                          (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                      decoration: InputDecoration(
                        hintText: 'you@example.com',
                        hintStyle: const TextStyle(color: Color(0xFF4D5252)),
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
                    AppGaps.gapMd,
                    Text(
                      'Password',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFFF9FAFA),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    AppGaps.gapXs,
                    TextFormField(
                      controller: passwordController,
                      obscureText: true,
                      style: const TextStyle(color: Color(0xFFF9FAFA)),
                      validator: (v) =>
                          (v == null || v.length < 6) ? 'Password must be at least 6 characters' : null,
                      decoration: InputDecoration(
                        hintText: '••••••••',
                        hintStyle: const TextStyle(color: Color(0xFF4D5252)),
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
                    AppGaps.gapLg,
                    AppButtons.primaryCTA(
                      isLoading: isModalLoading,
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;
                        setModalState(() => isModalLoading = true);
                        final modalNavigator = Navigator.of(modalContext);
                        try {
                          UserCredential credential;
                          if (isSignUp) {
                            credential = await _authService.signUpWithEmailAndPassword(
                              emailController.text,
                              passwordController.text,
                            );
                          } else {
                            credential = await _authService.signInWithEmailAndPassword(
                              emailController.text,
                              passwordController.text,
                            );
                          }

                          if (credential.user != null) {
                            try {
                              await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(credential.user!.uid)
                                  .set({'role': widget.role}, SetOptions(merge: true));
                            } catch (_) {}
                          }

                          modalNavigator.pop();
                          if (context.mounted) {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (_) => const ProfileSetupScreen()),
                            );
                          }
                        } catch (e) {
                          setModalState(() => isModalLoading = false);
                          _showErrorSnackBar(e.toString());
                        }
                      },
                      text: isSignUp ? 'CREATE ACCOUNT' : 'SIGN IN',
                    ),
                    if (kEnableDevBypass) ...[
                      AppGaps.gapSm,
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.of(modalContext).pop();
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (_) => const ProfileSetupScreen()),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFEEC200), width: 1.2),
                            foregroundColor: const Color(0xFFEEC200),
                            shape: const StadiumBorder(),
                          ),
                          child: Text(
                            'Skip Email / Password (Dev)',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                      ),
                    ],
                    AppGaps.gapSm,
                    Center(
                      child: TextButton(
                        onPressed: () {
                          setModalState(() => isSignUp = !isSignUp);
                        },
                        child: Text(
                          isSignUp
                              ? 'Already have an account? Sign In'
                              : "Don't have an account? Create One",
                          style: const TextStyle(color: Color(0xFF919696), fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
},
);
}

  void _showPhoneEntryModal({String? initialPhone}) {
    final phoneController = TextEditingController(text: initialPhone ?? '');
    bool isModalLoading = false;
    String? modalError;
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(modalContext).viewInsets.bottom,
              ),
              child: SafeArea(
                top: false,
                child: AdaptiveGlassContainer(
                  customBorderRadius: const BorderRadius.vertical(top: Radius.circular(24.0)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.spaceLg,
                      vertical: AppSpacing.spaceLg,
                    ),
                    child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFF333737),
                            borderRadius: AppBorderRadius.sm,
                          ),
                        ),
                      ),
                      AppGaps.gapLg,
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
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
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
                            fontSize: 14,
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
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
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
                          prefixIcon: const Icon(Icons.phone, color: Color(0xFFEEC200), size: 20),
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
                      if (modalError != null) ...[
                        AppGaps.gapMd,
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
                              const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 18),
                              AppGaps.gapSm,
                              Expanded(
                                child: Text(
                                  modalError!,
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
                      AppGaps.gapLg,
                      AppButtons.primaryCTA(
                        isLoading: isModalLoading,
                        onPressed: () async {
                          if (!formKey.currentState!.validate()) return;
                          setModalState(() {
                            isModalLoading = true;
                            modalError = null;
                          });
                          final rootNavigator = Navigator.of(context);
                          final modalNavigator = Navigator.of(modalContext);
                          final rawNumber = phoneController.text.trim();

                          String formattedNumber = rawNumber;
                          if (!formattedNumber.startsWith('+')) {
                            formattedNumber = '+1 $formattedNumber';
                          }

                          try {
                            await _authService.verifyPhoneNumber(
                              phoneNumber: formattedNumber,
                              onCodeSent: (String verificationId, int? resendToken) {
                                if (modalNavigator.canPop()) {
                                  modalNavigator.pop();
                                }
                                rootNavigator.push(
                                  MaterialPageRoute(
                                    builder: (_) => PhoneVerificationScreen(
                                      phoneNumber: formattedNumber,
                                      verificationId: verificationId,
                                      resendToken: resendToken,
                                      authService: _authService,
                                    ),
                                  ),
                                );
                              },
                              onVerificationFailed: (Exception error) {
                                final errorMsg = error.toString().replaceAll('Exception: ', '');
                                setModalState(() {
                                  isModalLoading = false;
                                  modalError = errorMsg;
                                });
                                _showErrorSnackBar(errorMsg);
                              },
                            );
                          } catch (e) {
                            final errorMsg = e.toString().replaceAll('Exception: ', '');
                            setModalState(() {
                              isModalLoading = false;
                              modalError = errorMsg;
                            });
                            _showErrorSnackBar(errorMsg);
                          }
                        },
                        text: 'SEND VERIFICATION CODE',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  },
);
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFF121414),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFFF9FAFA)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (kEnableDevBypass)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const ProfileSetupScreen()),
                  );
                },
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
            ),
        ],
      ),
      body: Stack(
        children: [
          // Background subtle tattoo texture extending edge to edge
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
                    Colors.black.withAlpha(130),
                    Colors.black.withAlpha(140),
                    Colors.black.withAlpha(210),
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
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.spaceXl,
                          vertical: AppSpacing.spaceLg,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Transform.rotate(
                              angle: -15 * (math.pi / 180),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Flash',
                                    style: GoogleFonts.kaushanScript(
                                      fontSize: 64,
                                      color: const Color(0xFFEEC200),
                                    ),
                                  ),
                                  AppGaps.gapXs,
                                  const Icon(
                                    Icons.electric_bolt,
                                    color: Color(0xFFEEC200),
                                    size: 34,
                                  ),
                                ],
                              ),
                            ),
                            AppGaps.gapMd,
                            Text(
                              'Create an account or continue as guest to start exploring exclusive flash designs.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                color: const Color(0xFF919696),
                                fontSize: 14,
                                height: 1.4,
                              ),
                            ),
                             AppGaps.gapLg,
                              if (kEnableDevBypass) ...[
                               Container(
                                 width: double.infinity,
                                 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                 decoration: BoxDecoration(
                                   color: const Color(0xFFEEC200).withAlpha(25),
                                   borderRadius: BorderRadius.circular(12),
                                   border: Border.all(color: const Color(0xFFEEC200).withAlpha(140)),
                                 ),
                                 child: Row(
                                   children: [
                                     const Icon(Icons.flash_on, color: Color(0xFFEEC200), size: 20),
                                     const SizedBox(width: 8),
                                     Expanded(
                                       child: Column(
                                         crossAxisAlignment: CrossAxisAlignment.start,
                                         children: [
                                           Text(
                                             'LOCAL DEV TESTING',
                                             style: GoogleFonts.plusJakartaSans(
                                               fontSize: 11,
                                               fontWeight: FontWeight.w800,
                                               letterSpacing: 1.0,
                                               color: const Color(0xFFEEC200),
                                             ),
                                           ),
                                           Text(
                                             'Skip account creation & proceed',
                                             style: GoogleFonts.plusJakartaSans(
                                               fontSize: 12,
                                               color: const Color(0xFFD8DDDD),
                                             ),
                                           ),
                                         ],
                                       ),
                                     ),
                                     ElevatedButton.icon(
                                       onPressed: () {
                                         Navigator.pushReplacement(
                                           context,
                                           MaterialPageRoute(builder: (_) => const ProfileSetupScreen()),
                                         );
                                       },
                                       icon: const Icon(Icons.arrow_forward, size: 14),
                                       label: const Text('Skip'),
                                       style: ElevatedButton.styleFrom(
                                         backgroundColor: const Color(0xFFEEC200),
                                         foregroundColor: const Color(0xFF121414),
                                         textStyle: GoogleFonts.plusJakartaSans(
                                           fontSize: 12,
                                           fontWeight: FontWeight.bold,
                                         ),
                                         padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                         minimumSize: Size.zero,
                                         tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                         shape: const StadiumBorder(),
                                       ),
                                     ),
                                   ],
                                 ),
                               ),
                               AppGaps.gapMd,
                             ],
                             // Primary Account Creation Options within Liquid Glass Container
                            AdaptiveGlassContainer(
                              borderRadius: 20.0,
                              padding: const EdgeInsets.all(AppSpacing.spaceMd),
                              child: Column(
                                children: [
                                  // Google OAuth Button
                                  AppButtons.primaryCTA(
                                    icon: Icons.g_mobiledata,
                                    text: 'Continue with Google',
                                    onPressed: _isLoading ? null : () => _handleOAuth(_authService.signInWithGoogle),
                                    backgroundColor: const Color(0xFFF9FAFA),
                                    foregroundColor: const Color(0xFF121414),
                                  ),
                                  AppGaps.gapSm,
                                  // Apple OAuth Button
                                  AppButtons.primaryCTA(
                                    icon: Icons.apple,
                                    text: 'Continue with Apple',
                                    onPressed: _isLoading ? null : () => _handleOAuth(_authService.signInWithApple),
                                    backgroundColor: const Color(0xFF1E2020),
                                    foregroundColor: const Color(0xFFF9FAFA),
                                  ),
                                  AppGaps.gapSm,
                                  // Email / Password Button
                                  AppButtons.primaryCTA(
                                    icon: Icons.mail_outline,
                                    text: 'Continue with Email',
                                    onPressed: _isLoading ? null : _showEmailAuthModal,
                                    backgroundColor: const Color(0xFF262929),
                                    foregroundColor: const Color(0xFFF9FAFA),
                                  ),
                                  AppGaps.gapSm,
                                  // Phone Verification Button
                                  AppButtons.primaryCTA(
                                    icon: Icons.phone_iphone,
                                    text: 'Continue with Phone',
                                    onPressed: _isLoading ? null : () => _showPhoneEntryModal(),
                                    backgroundColor: const Color(0xFF262929),
                                    foregroundColor: const Color(0xFFF9FAFA),
                                  ),
                                ],
                              ),
                            ),
                            AppGaps.gapLg,
                            // Visual Divider with "OR"
                            Row(
                              children: [
                                const Expanded(
                                  child: Divider(
                                    color: Color(0xFF333737),
                                    thickness: 1,
                                  ),
                                ),
                                Padding(
                                  padding: AppPadding.screenHorizontal,
                                  child: Text(
                                    'OR',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: const Color(0xFF919696),
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                ),
                                const Expanded(
                                  child: Divider(
                                    color: Color(0xFF333737),
                                    thickness: 1,
                                  ),
                                ),
                              ],
                            ),
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
                        ),
                      ),
                    ),
                  ),
                );
              },
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
