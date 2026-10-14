import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/dev_config.dart';
import '../../services/auth_service.dart';
import '../../theme/app_radius.dart';
import '../../widgets/adaptive_glass_container.dart';
import '../../widgets/artist_stepper_header.dart';
import '../../widgets/tattoo_background_wrapper.dart';
import '../../widgets/skip_pill_button.dart';
import 'artist_phone_verification_screen.dart';
import 'artist_profile_photo_screen.dart';

class ArtistInfoScreen extends StatefulWidget {
  final AuthService? authService;
  final String? initialName;
  final String? initialEmail;

  const ArtistInfoScreen({
    super.key,
    this.authService,
    this.initialName,
    this.initialEmail,
  });

  @override
  State<ArtistInfoScreen> createState() => _ArtistInfoScreenState();
}

class _ArtistInfoScreenState extends State<ArtistInfoScreen> {
  late final AuthService _authService = widget.authService ?? AuthService();

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;

  bool _agreedToTerms = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final defaultName = widget.initialName ?? _authService.currentUser?.displayName ?? '';
    _nameController = TextEditingController(text: defaultName);
    _phoneController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
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

  Future<void> _handleContinue() async {
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
    final formattedPhone = _formatPhoneNumber(_phoneController.text.trim());
    final currentUser = _authService.currentUser;
    final uid = currentUser?.uid ?? 'artist_${DateTime.now().millisecondsSinceEpoch}';
    final email = widget.initialEmail ?? currentUser?.email ?? '';

    try {
      if (currentUser != null) {
        try {
          await currentUser.updateDisplayName(name);
        } catch (_) {}
      }

      // 1. Save artist profile details to Firestore
      try {
        final userDoc = FirebaseFirestore.instance.collection('users').doc(uid);
        await userDoc.set({
          'displayName': name,
          'email': email,
          'phoneNumber': formattedPhone,
          'role': 'artist',
          'phoneVerified': false,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        final artistDoc = FirebaseFirestore.instance.collection('artists').doc(uid);
        await artistDoc.set({
          'id': uid,
          'name': name,
          'email': email,
          'phoneNumber': formattedPhone,
          'isBooksOpen': true,
          'rating': 5.0,
          'availablePieces': 0,
          'minDeposit': 50,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (_) {}

      // 2. Dispatch SMS verification code
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
          if (kEnableDevBypass) {
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



  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
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

  void _skipInfo() {
    final name = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : (widget.initialName?.isNotEmpty == true
            ? widget.initialName!
            : (_authService.currentUser?.displayName?.isNotEmpty == true
                ? _authService.currentUser!.displayName!
                : 'OddMaree'));
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
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFF121414),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFFF9FAFA)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: SkipPillButton(
                key: const Key('skip_artist_info_button'),
                onPressed: _skipInfo,
              ),
            ),
          ),
        ],
      ),
      body: TattooBackgroundWrapper(
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
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
                    'Artist Profile',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFF9FAFA),
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enter your artist name and contact number to get set up.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      color: const Color(0xFF919696),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Main Form Card Container
                  AdaptiveGlassContainer(
                    padding: const EdgeInsets.all(20),
                    borderRadius: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name
                        _buildTextField(
                          label: 'Name or Artist Handle',
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

                        // CONTINUE CTA Button
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleContinue,
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
                                        'CONTINUE',
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
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
