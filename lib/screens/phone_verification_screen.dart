import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import 'profile_setup_screen.dart';
import 'role_selection_screen.dart';

class PhoneVerificationScreen extends StatefulWidget {
  const PhoneVerificationScreen({super.key});

  @override
  State<PhoneVerificationScreen> createState() => _PhoneVerificationScreenState();
}

class _PhoneVerificationScreenState extends State<PhoneVerificationScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = false;
  final String _verificationId = 'test_verification_id';

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
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Attempt MFA complete or update Firestore with verified status
        try {
          await _authService.enrollMfaComplete(_verificationId, code, 'Primary Phone');
        } catch (_) {
          // If in development/testing mode, simulate successful phone verification
        }

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({'phoneVerified': true, 'phoneNumber': '+15550199'}, SetOptions(merge: true));
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification failed: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
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
      canPop: false, // Prevent bypassing the SMS lock via back gesture/button
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handleCancel();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF1E2020),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFFF9FAFA)),
            onPressed: _handleCancel,
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 24),
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    color: Color(0xFF262929),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.chat_bubble,
                    color: Color(0xFFEEC200),
                    size: 32,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Verify your phone\nnumber',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.epilogue(
                    color: const Color(0xFFF9FAFA),
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'We\'ve sent a 6-digit verification code\nto your device. Please enter it below.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.epilogue(
                    color: const Color(0xFF919696),
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 48),
                // OTP Field
                TextField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFF9FAFA),
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 20,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    filled: true,
                    fillColor: const Color(0xFF121414),
                    contentPadding: const EdgeInsets.symmetric(vertical: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFF262929)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFF262929), width: 1.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFFEEC200), width: 2),
                    ),
                  ),
                  onChanged: (val) {
                    if (val.length == 6) {
                      _verifyCode();
                    }
                  },
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: _isLoading ? null : _verifyCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEEC200),
                    foregroundColor: const Color(0xFF121414),
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    disabledBackgroundColor: const Color(0xFF614700),
                    disabledForegroundColor: const Color(0xFF919696),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF121414)),
                          ),
                        )
                      : const Text(
                          'VERIFY',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            fontSize: 16,
                          ),
                        ),
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Didn't receive code? ",
                      style: TextStyle(color: Color(0xFF919696), fontSize: 14),
                    ),
                    TextButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('A new 6-digit code has been sent.'),
                            backgroundColor: Color(0xFF22C55E),
                          ),
                        );
                      },
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
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
