import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../theme/app_spacing.dart';
import '../theme/app_radius.dart';
import '../theme/app_buttons.dart';
import '../widgets/adaptive_glass_container.dart';
import '../widgets/flash_logo.dart';
import '../widgets/skip_pill_button.dart';
import 'artist_onboarding/artist_info_screen.dart';
import 'phone_verification_screen.dart';
import 'profile_setup_screen.dart';

class PhoneEntryScreen extends StatefulWidget {
  final String role;
  final AuthService? authService;
  final String? initialPhone;

  const PhoneEntryScreen({
    super.key,
    required this.role,
    this.authService,
    this.initialPhone,
  });

  @override
  State<PhoneEntryScreen> createState() => _PhoneEntryScreenState();
}

class _PhoneEntryScreenState extends State<PhoneEntryScreen> {
  late final AuthService _authService = widget.authService ?? AuthService();
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _phoneController;

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController(text: widget.initialPhone ?? '');
  }

  @override
  void dispose() {
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final rawNumber = _phoneController.text.trim();
    String formattedNumber = rawNumber;
    if (!formattedNumber.startsWith('+')) {
      formattedNumber = '+1 $formattedNumber';
    }

    try {
      await _authService.verifyPhoneNumber(
        phoneNumber: formattedNumber,
        onCodeSent: (String verificationId, int? resendToken) {
          if (!mounted) return;
          Navigator.push(
            context,
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
          if (mounted) {
            setState(() {
              _isLoading = false;
              _errorMessage = errorMsg;
            });
            _showErrorSnackBar(errorMsg);
          }
        },
      );
    } catch (e) {
      final errorMsg = e.toString().replaceAll('Exception: ', '');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = errorMsg;
        });
        _showErrorSnackBar(errorMsg);
      }
    }
  }

  void _handleSkip() {
    if (widget.role == 'artist') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ArtistInfoScreen(
            authService: _authService,
          ),
        ),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const ProfileSetupScreen(),
        ),
      );
    }
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
        title: const FlashLogo(fontSize: 28),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: SkipPillButton(
                onPressed: _handleSkip,
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Background texture
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
                    Colors.black.withAlpha(240),
                    Colors.black.withAlpha(190),
                    Colors.black.withAlpha(210),
                    Colors.black.withAlpha(245),
                  ],
                  stops: const [0.0, 0.3, 0.7, 1.0],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.spaceLg,
                  vertical: AppSpacing.spaceMd,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: AdaptiveGlassContainer(
                    useGradient: false,
                    borderRadius: 24.0,
                    padding: const EdgeInsets.all(AppSpacing.spaceLg),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                                fontSize: 24,
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
                            controller: _phoneController,
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
                              prefixIcon: const Icon(
                                Icons.phone,
                                color: Color(0xFFEEC200),
                                size: 20,
                              ),
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
                          if (_errorMessage != null) ...[
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
                          AppGaps.gapLg,
                          AppButtons.primaryCTA(
                            isLoading: _isLoading,
                            onPressed: _submit,
                            text: 'SEND VERIFICATION CODE',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
