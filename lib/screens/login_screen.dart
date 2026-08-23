import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../theme/app_spacing.dart';
import '../theme/app_buttons.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  Future<void> _handleSignIn(Future<dynamic> Function() signInMethod) async {
    setState(() {
      _isLoading = true;
    });
    try {
      await signInMethod();
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
          // Background placeholder for tattoo setup image
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: NetworkImage(
                    'https://images.unsplash.com/photo-1598371839696-5c5bb00bdc28?ixlib=rb-4.0.3&auto=format&fit=crop&w=1000&q=80'),
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
                Text(
                  'Flash',
                  style: GoogleFonts.kaushanScript(
                    fontSize: 72,
                    color: const Color(0xFFEEC200), // Yellow/gold from frame 376
                  ),
                ),
                const Spacer(flex: 1),
                Padding(
                  padding: AppPadding.screenHorizontal,
                  child: Column(
                    children: [
                      AppButtons.primaryCTA(
                        onPressed: _isLoading ? null : () => _handleSignIn(_authService.signInWithGoogle),
                        text: 'Continue with Google',
                        backgroundColor: const Color(0xFFF9FAFA),
                        foregroundColor: const Color(0xFF121414),
                      ),
                      AppGaps.gapMd,
                      AppButtons.primaryCTA(
                        onPressed: _isLoading ? null : () => _handleSignIn(_authService.signInWithApple),
                        text: 'Continue with Apple',
                        backgroundColor: const Color(0xFF1E2020),
                        foregroundColor: const Color(0xFFF9FAFA),
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
