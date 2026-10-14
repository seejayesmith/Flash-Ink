import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_spacing.dart';
import '../widgets/social_auth_buttons.dart';
import '../widgets/flash_logo.dart';
import 'auth_routing.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _isAppleLoading = false;

  Future<void> _handleSignIn(
    Future<dynamic> Function() signInMethod, {
    bool isGoogle = false,
    bool isApple = false,
  }) async {
    setState(() {
      _isLoading = true;
      if (isGoogle) _isGoogleLoading = true;
      if (isApple) _isAppleLoading = true;
    });
    try {
      final credential = await signInMethod();
      if (credential != null && credential.user != null) {
        if (mounted) {
          await AuthRouting.routeUserAfterAuth(context, credential.user!);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sign in failed: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isGoogleLoading = false;
          _isAppleLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121414), // Background from grayscale frame 383/375
      body: Stack(
        children: [
          // Background tattoo setup image
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/tattoo_setup.png'),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black54,
                  BlendMode.darken,
                ),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),
                const FlashLogo(
                  fontSize: 72,
                ),
                const Spacer(flex: 1),
                Padding(
                  padding: AppPadding.screenHorizontal,
                  child: Column(
                    children: [
                      const SocialAuthDivider(label: 'SIGN IN WITH'),
                      AppGaps.gapLg,
                      SocialAuthRow(
                        onGooglePressed: () => _handleSignIn(
                          _authService.signInWithGoogle,
                          isGoogle: true,
                        ),
                        onApplePressed: () => _handleSignIn(
                          _authService.signInWithApple,
                          isApple: true,
                        ),
                        isLoading: _isLoading,
                        isGoogleLoading: _isGoogleLoading,
                        isAppleLoading: _isAppleLoading,
                      ),
                      AppGaps.gapLg,
                      TextButton(
                        onPressed: _isLoading ? null : () => _handleSignIn(_authService.signInAnonymously),
                        child: const Text(
                          'Continue as Guest',
                          style: TextStyle(color: Color(0xFF919696)),
                        ),
                      ),
                    ],
                  ),
                ),
                AppGaps.gapXxl,
              ],
            ),
          ),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEEC200)),
              ),
            ),
        ],
      ),
    );
  }
}
