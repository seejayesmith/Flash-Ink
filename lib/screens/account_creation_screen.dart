import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../theme/app_spacing.dart';
import '../theme/app_radius.dart';
import '../theme/app_buttons.dart';
import 'phone_verification_screen.dart';
import 'aesthetics_selection_screen.dart';

class AccountCreationScreen extends StatefulWidget {
  final String role;

  const AccountCreationScreen({super.key, required this.role});

  @override
  State<AccountCreationScreen> createState() => _AccountCreationScreenState();
}

class _AccountCreationScreenState extends State<AccountCreationScreen> {
  final AuthService _authService = AuthService();
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
          // Path A: Destructive routing locked to Mandatory SMS Verification
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const PhoneVerificationScreen()),
            (route) => false,
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
                  style: GoogleFonts.epilogue(
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
                style: GoogleFonts.epilogue(
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
      backgroundColor: const Color(0xFF1E2020),
      isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: AppBorderRadius.topLg),
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: AppSpacing.spaceLg,
                right: AppSpacing.spaceLg,
                top: AppSpacing.spaceLg,
                bottom: MediaQuery.of(modalContext).viewInsets.bottom + AppSpacing.spaceXl,
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
                    Center(
                      child: Text(
                        isSignUp ? 'Create with Email' : 'Sign in with Email',
                        style: GoogleFonts.epilogue(
                          color: const Color(0xFFF9FAFA),
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    AppGaps.gapLg,
                    Text(
                      'Email Address',
                      style: GoogleFonts.epilogue(
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
                      style: GoogleFonts.epilogue(
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
                        final rootNavigator = Navigator.of(context);
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
                          rootNavigator.pushAndRemoveUntil(
                            MaterialPageRoute(builder: (_) => const PhoneVerificationScreen()),
                            (route) => false,
                          );
                        } catch (e) {
                          setModalState(() => isModalLoading = false);
                          _showErrorSnackBar(e.toString());
                        }
                      },
                      text: isSignUp ? 'CREATE ACCOUNT' : 'SIGN IN',
                    ),
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
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121414),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFFF9FAFA)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // Background subtle tattoo texture
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: NetworkImage(
                  'https://images.unsplash.com/photo-1598371839696-5c5bb00bdc28?ixlib=rb-4.0.3&auto=format&fit=crop&w=1000&q=80',
                ),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black87,
                  BlendMode.darken,
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spaceXl, vertical: AppSpacing.spaceLg),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
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
                    AppGaps.gapXs,
                    Text(
                      'Create an account or continue as guest to start exploring exclusive flash designs.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.epilogue(
                        color: const Color(0xFF919696),
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                    AppGaps.gapXl,
                    // Primary Account Creation Options
                    Column(
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
                      ],
                    ),
                    const SizedBox(height: AppSpacing.spaceXl),
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
                            style: GoogleFonts.epilogue(
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
                        style: GoogleFonts.epilogue(
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
