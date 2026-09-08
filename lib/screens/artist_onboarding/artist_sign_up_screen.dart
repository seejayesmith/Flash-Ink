import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/dev_config.dart';
import '../../services/auth_service.dart';
import '../../theme/app_radius.dart';
import '../../widgets/artist_stepper_header.dart';
import '../login_screen.dart';
import 'artist_phone_verification_screen.dart';
import 'artist_profile_photo_screen.dart';

class ArtistSignUpScreen extends StatefulWidget {
  final AuthService? authService;

  const ArtistSignUpScreen({
    super.key,
    this.authService,
  });

  @override
  State<ArtistSignUpScreen> createState() => _ArtistSignUpScreenState();
}

class _ArtistSignUpScreenState extends State<ArtistSignUpScreen> {
  late final AuthService _authService = widget.authService ?? AuthService();

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _agreedToTerms = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

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

  String _formatPhoneNumber(String raw) {
    var digits = raw.replaceAll(RegExp(r'\D'), '');
    if (!digits.startsWith('1') && digits.length == 10) {
      digits = '1$digits';
    }
    return '+$digits';
  }

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_agreedToTerms) {
      setState(() {
        _errorMessage = 'Please agree to the Terms of Service & Privacy Policy.';
      });
      _showErrorSnackBar('Please agree to the Terms of Service & Privacy Policy.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final formattedPhone = _formatPhoneNumber(_phoneController.text.trim());

    try {
      // 1. Create account with email & password
      final credential = await _authService.signUpWithEmailAndPassword(email, password);
      final user = credential.user;

      if (user != null) {
        await user.updateDisplayName(name);

        // 2. Persist initial artist profile in Firestore
        final userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);
        await userDoc.set({
          'displayName': name,
          'email': email,
          'phoneNumber': formattedPhone,
          'role': 'artist',
          'phoneVerified': false,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        final artistDoc = FirebaseFirestore.instance.collection('artists').doc(user.uid);
        await artistDoc.set({
          'id': user.uid,
          'name': name,
          'email': email,
          'phoneNumber': formattedPhone,
          'isBooksOpen': true,
          'rating': 5.0,
          'availablePieces': 0,
          'minDeposit': 50,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      // 3. Dispatch SMS verification code
      await _authService.verifyPhoneNumber(
        phoneNumber: formattedPhone,
        onCodeSent: (String verificationId, int? resendToken) {
          if (!mounted) return;
          setState(() => _isLoading = false);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ArtistPhoneVerificationScreen(
                phoneNumber: formattedPhone,
                verificationId: verificationId,
                resendToken: resendToken,
                artistName: name,
                artistEmail: email,
                authService: _authService,
              ),
            ),
          );
        },
        onVerificationFailed: (Exception error) {
          if (!mounted) return;
          setState(() => _isLoading = false);
          final errorMsg = error.toString().replaceAll('Exception: ', '');
          _showErrorSnackBar(errorMsg);
          if (kDebugMode) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ArtistPhoneVerificationScreen(
                  phoneNumber: formattedPhone,
                  verificationId: 'dev_verification_id',
                  resendToken: 123,
                  artistName: name,
                  artistEmail: email,
                  authService: _authService,
                ),
              ),
            );
          }
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
      _showErrorSnackBar(_errorMessage!);
    }
  }

  Future<void> _handleOAuth(Future<UserCredential?> Function() method) async {
    setState(() => _isLoading = true);
    try {
      final credential = await method();
      if (credential != null && credential.user != null) {
        final uid = credential.user!.uid;
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'role': 'artist',
          'displayName': credential.user!.displayName ?? '',
          'email': credential.user!.email ?? '',
        }, SetOptions(merge: true));

        await FirebaseFirestore.instance.collection('artists').doc(uid).set({
          'id': uid,
          'name': credential.user!.displayName ?? 'Artist',
          'email': credential.user!.email ?? '',
          'isBooksOpen': true,
          'rating': 5.0,
          'availablePieces': 0,
          'minDeposit': 50,
        }, SetOptions(merge: true));

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ArtistProfilePhotoScreen(
                artistName: credential.user!.displayName ?? 'Artist',
                authService: _authService,
              ),
            ),
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

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: const Color(0xFFD8DDDD),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          style: GoogleFonts.plusJakartaSans(
            color: const Color(0xFFF9FAFA),
            fontSize: 15,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF242727),
            hintText: hintText,
            hintStyle: GoogleFonts.plusJakartaSans(
              color: const Color(0xFF6C7272),
              fontSize: 15,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            suffixIcon: suffixIcon,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF383C3C)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF383C3C)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFEEC200), width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFEF4444)),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }

  void _skipPastEmailAndPassword() {
    final name = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : 'OddMaree';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ArtistProfilePhotoScreen(
          artistName: name,
          authService: _authService,
        ),
      ),
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
        actions: [
          if (kEnableDevBypass)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: ElevatedButton.icon(
                onPressed: _skipPastEmailAndPassword,
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
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Onboarding Stepper (Step 1 active)
                const ArtistStepperHeader(currentStep: 1),
                const SizedBox(height: 16),

                // Headline & Subtitle
                Text(
                  'Create an\naccount',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFF9FAFA),
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Join the underground ink community.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    color: const Color(0xFF919696),
                  ),
                ),
                if (kEnableDevBypass) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEC200).withAlpha(25),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFEEC200).withAlpha(140)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.flash_on, color: Color(0xFFEEC200), size: 22),
                        const SizedBox(width: 10),
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
                              const SizedBox(height: 2),
                              Text(
                                'Skip email & password account creation',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFFF9FAFA),
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _skipPastEmailAndPassword,
                          icon: const Icon(Icons.arrow_forward, size: 14),
                          label: const Text('Skip'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEEC200),
                            foregroundColor: const Color(0xFF121414),
                            textStyle: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: const StadiumBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),

                // Main Form Card Container
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1C1C),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF2B2E2E)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name
                      _buildTextField(
                        label: 'Name',
                        controller: _nameController,
                        hintText: 'OddMaree',
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your name or artist handle';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Email
                      _buildTextField(
                        label: 'Email',
                        controller: _emailController,
                        hintText: 'ink@studio.com',
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your email';
                          }
                          if (!value.contains('@') || !value.contains('.')) {
                            return 'Please enter a valid email address';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Phone Number
                      _buildTextField(
                        label: 'Phone Number',
                        controller: _phoneController,
                        hintText: '(555) 000-0000',
                        keyboardType: TextInputType.phone,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your phone number for SMS verification';
                          }
                          final digits = value.replaceAll(RegExp(r'\D'), '');
                          if (digits.length < 10) {
                            return 'Please enter a valid 10-digit phone number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Password
                      _buildTextField(
                        label: 'Password',
                        controller: _passwordController,
                        hintText: '••••••••',
                        obscureText: _obscurePassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            color: const Color(0xFF8C9191),
                          ),
                          onPressed: () {
                            setState(() => _obscurePassword = !_obscurePassword);
                          },
                        ),
                        validator: (value) {
                          if (value == null || value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Terms and Privacy Checkbox
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: Checkbox(
                              value: _agreedToTerms,
                              activeColor: const Color(0xFFEEC200),
                              checkColor: const Color(0xFF121414),
                              side: const BorderSide(color: Color(0xFF4D5252), width: 1.5),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                              onChanged: (val) {
                                setState(() => _agreedToTerms = val ?? false);
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'I agree to the Terms of Service and Privacy Policy.',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: const Color(0xFFD8DDDD),
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // CREATE ACCOUNT CTA Button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleSignUp,
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
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'CREATE ACCOUNT',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.1,
                                        color: const Color(0xFF121414),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(
                                      Icons.arrow_forward,
                                      size: 18,
                                      color: Color(0xFF121414),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      if (kEnableDevBypass) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: OutlinedButton(
                            onPressed: _isLoading ? null : _skipPastEmailAndPassword,
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFEEC200), width: 1.2),
                              foregroundColor: const Color(0xFFEEC200),
                              shape: const StadiumBorder(),
                            ),
                            child: Text(
                              'Skip to Profile (Dev)',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Divider: ── OR CONTINUE WITH ──
                Row(
                  children: [
                    const Expanded(child: Divider(color: Color(0xFF2B2E2E), thickness: 1)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Text(
                        'OR CONTINUE WITH',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          color: const Color(0xFF6C7272),
                        ),
                      ),
                    ),
                    const Expanded(child: Divider(color: Color(0xFF2B2E2E), thickness: 1)),
                  ],
                ),
                const SizedBox(height: 20),

                // Social Auth Buttons: Google & Apple
                Row(
                  children: [
                    // Google
                    Expanded(
                      child: SizedBox(
                        height: 46,
                        child: OutlinedButton.icon(
                          onPressed: _isLoading ? null : () => _handleOAuth(_authService.signInWithGoogle),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF383C3C)),
                            backgroundColor: const Color(0xFF1A1C1C),
                            shape: const StadiumBorder(),
                          ),
                          icon: const Icon(Icons.g_mobiledata, size: 24, color: Colors.white),
                          label: Text(
                            'Google',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFF9FAFA),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Apple
                    Expanded(
                      child: SizedBox(
                        height: 46,
                        child: OutlinedButton.icon(
                          onPressed: _isLoading ? null : () => _handleOAuth(_authService.signInWithApple),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF383C3C)),
                            backgroundColor: const Color(0xFF1A1C1C),
                            shape: const StadiumBorder(),
                          ),
                          icon: const Icon(Icons.apple, size: 20, color: Colors.white),
                          label: Text(
                            'Apple',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFF9FAFA),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Footer: Already have an account? Log in
                Center(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    },
                    child: RichText(
                      text: TextSpan(
                        text: 'Already have an account? ',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          color: const Color(0xFF919696),
                        ),
                        children: [
                          TextSpan(
                            text: 'Log in',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFF9FAFA),
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
