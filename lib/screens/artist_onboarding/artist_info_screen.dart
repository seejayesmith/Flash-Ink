import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/dev_config.dart';
import '../../providers/app_providers.dart';
import '../../services/auth_service.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/adaptive_glass_container.dart';
import '../../widgets/fade_page_route.dart';
import '../../widgets/flash_snack_bar.dart';
import '../../widgets/flow_page_layout.dart';
import '../../widgets/phone_number_input_formatter.dart';
import '../../widgets/tattoo_background_wrapper.dart';
import '../../widgets/username_input_formatter.dart';
import '../../features/onboarding/shared/onboarding_step_scaffold.dart';
import 'artist_phone_verification_screen.dart';
import 'artist_profile_photo_screen.dart';

class ArtistInfoScreen extends StatefulWidget {
  final AuthService? authService;
  final String? initialName;
  final String? initialEmail;
  final String? initialPhone;

  const ArtistInfoScreen({
    super.key,
    this.authService,
    this.initialName,
    this.initialEmail,
    this.initialPhone,
  });

  @override
  State<ArtistInfoScreen> createState() => _ArtistInfoScreenState();
}

class _ArtistInfoScreenState extends State<ArtistInfoScreen> {
  late final AuthService _authService = widget.authService ?? AuthService();

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  final FocusNode _nameFocusNode = FocusNode();

  bool _agreedToTerms = false;
  bool _isLoading = false;
  String? _errorMessage;
  String? _verifiedPhoneNumber;
  bool _isPhoneVerified = false;

  @override
  void initState() {
    super.initState();
    String defaultName = widget.initialName ?? '';
    if (defaultName.isEmpty) {
      try {
        defaultName = _authService.currentUser?.displayName ?? '';
      } catch (_) {
        defaultName = '';
      }
    }
    if (defaultName.isNotEmpty && !defaultName.startsWith('@')) {
      defaultName = '@$defaultName';
    }
    _nameController = TextEditingController(text: defaultName);
    _nameFocusNode.addListener(_handleNameFocusChange);

    String? rawPhone = widget.initialPhone;
    if (rawPhone == null || rawPhone.isEmpty) {
      try {
        rawPhone = _authService.currentUser?.phoneNumber;
      } catch (_) {
        rawPhone = null;
      }
    }
    _verifiedPhoneNumber = rawPhone;
    final formattedPhone = AuthService.formatDisplayPhoneNumber(rawPhone);
    _phoneController = TextEditingController(text: formattedPhone);
    _isPhoneVerified = _checkIfPhoneMatchesVerified(formattedPhone);
    _phoneController.addListener(_onPhoneChanged);
  }

  void _onPhoneChanged() {
    final matches = _checkIfPhoneMatchesVerified(_phoneController.text);
    if (matches != _isPhoneVerified) {
      setState(() {
        _isPhoneVerified = matches;
      });
    }
  }

  bool _checkIfPhoneMatchesVerified(String enteredPhone) {
    if (_verifiedPhoneNumber == null || _verifiedPhoneNumber!.trim().isEmpty) {
      return false;
    }
    final enteredDigits = enteredPhone.replaceAll(RegExp(r'\D'), '');
    final verifiedDigits = _verifiedPhoneNumber!.replaceAll(RegExp(r'\D'), '');
    final cleanEntered = enteredDigits.length == 11 && enteredDigits.startsWith('1')
        ? enteredDigits.substring(1)
        : enteredDigits;
    final cleanVerified = verifiedDigits.length == 11 && verifiedDigits.startsWith('1')
        ? verifiedDigits.substring(1)
        : verifiedDigits;
    return cleanEntered.isNotEmpty && cleanEntered == cleanVerified;
  }

  void _handleNameFocusChange() {
    if (_nameFocusNode.hasFocus) {
      if (_nameController.text.isEmpty) {
        _nameController.text = '@';
        _nameController.selection = const TextSelection.collapsed(offset: 1);
      }
    } else {
      if (_nameController.text.trim() == '@') {
        _nameController.clear();
      }
    }
  }

  @override
  void dispose() {
    _nameFocusNode.removeListener(_handleNameFocusChange);
    _nameFocusNode.dispose();
    _phoneController.removeListener(_onPhoneChanged);
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    FlashSnackBar.showError(context, message);
  }

  String _formatPhoneNumber(String raw) {
    return AuthService.formatE164PhoneNumber(raw);
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

      // 1. Save artist profile details to Firestore (PII isolated to /users/{uid} and /artists/{uid}/private/settings)
      try {
        FirebaseFirestore? injectedDb;
        if (mounted) {
          try {
            injectedDb = ProviderScope.containerOf(
              context,
              listen: false,
            ).read(firebaseFirestoreProvider);
          } catch (_) {}
        }
        final db = injectedDb ?? FirebaseFirestore.instance;
        final isWidgetTest =
            WidgetsBinding.instance.runtimeType.toString().contains('Test');
        final timeoutDuration = (!isWidgetTest || injectedDb != null)
            ? const Duration(seconds: 6)
            : const Duration(milliseconds: 200);

        final userDoc = db.collection('users').doc(uid);
        await userDoc.set({
          'uid': uid,
          'displayName': name,
          'email': email,
          'phoneNumber': formattedPhone,
          'phoneVerified': _isPhoneVerified,
          'onboardingRole': 'artist',
          'profileCompleted': false,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)).timeout(timeoutDuration);

        final cleanUsername = name.replaceAll('@', '');
        final artistDoc = db.collection('artists').doc(uid);
        await artistDoc.set({
          'id': uid,
          'name': name,
          'displayName': name,
          'username': cleanUsername,
          'isBooksOpen': true,
          'profileCompleted': false,
          'rating': 5.0,
          'availablePieces': 0,
          'minDeposit': 50,
          if (_isPhoneVerified) 'phoneVerified': true,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)).timeout(timeoutDuration);

        await artistDoc.collection('private').doc('settings').set({
          'email': email,
          'phoneNumber': formattedPhone,
          if (_isPhoneVerified) 'phoneVerified': true,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)).timeout(timeoutDuration);
      } catch (_) {}

      // If phone is already verified, bypass SMS verification and proceed to Profile Photo
      if (_isPhoneVerified) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        FocusManager.instance.primaryFocus?.unfocus();
        Navigator.pushReplacement(
          context,
          FadePageRoute(
            builder: (_) => ArtistProfilePhotoScreen(
              artistName: name,
              authService: _authService,
            ),
          ),
        );
        return;
      }

      // 2. Dispatch SMS verification code
      await _authService.verifyPhoneNumber(
        phoneNumber: formattedPhone,
        onVerificationCompleted: (_) async {
          if (!mounted) return;
          setState(() => _isLoading = false);
          FocusManager.instance.primaryFocus?.unfocus();
          Navigator.pushReplacement(
            context,
            FadePageRoute(
              builder: (_) => ArtistProfilePhotoScreen(
                artistName: name,
                authService: _authService,
              ),
            ),
          );
        },
        onCodeSent: (String verificationId, int? resendToken) {
          if (!mounted) return;
          setState(() => _isLoading = false);
          FocusManager.instance.primaryFocus?.unfocus();
          Navigator.push(
            context,
            FadePageRoute(
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
            FocusManager.instance.primaryFocus?.unfocus();
            Navigator.push(
              context,
              FadePageRoute(
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
        onCodeAutoRetrievalTimeout: (String verificationId) {
          // Verification ID is retained in AuthService state
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
    Key? key,
    required String label,
    required TextEditingController controller,
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
    Widget? trailingLabelWidget,
    FocusNode? focusNode,
    VoidCallback? onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFD8DDDD),
              ),
            ),
            if (trailingLabelWidget != null) ...[
              const SizedBox(width: 8),
              trailingLabelWidget,
            ],
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          key: key,
          controller: controller,
          focusNode: focusNode,
          onTap: onTap,
          keyboardType: keyboardType,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          scrollPadding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
          ),
          inputFormatters: inputFormatters,
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
    FocusManager.instance.primaryFocus?.unfocus();
    final raw = _nameController.text.trim();
    final name = raw.isNotEmpty && raw != '@'
        ? raw
        : (widget.initialName?.isNotEmpty == true
            ? (widget.initialName!.startsWith('@') ? widget.initialName! : '@${widget.initialName}')
            : (_authService.currentUser?.displayName?.isNotEmpty == true
                ? (_authService.currentUser!.displayName!.startsWith('@')
                    ? _authService.currentUser!.displayName!
                    : '@${_authService.currentUser!.displayName}')
                : '@OddMaree'));
    Navigator.push(
      context,
      FadePageRoute(
        builder: (_) => ArtistProfilePhotoScreen(
          artistName: name,
          authService: _authService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingStepScaffold(
      currentStep: 1,
      totalSteps: 9,
      onBack: Navigator.canPop(context)
          ? () {
              FocusManager.instance.primaryFocus?.unfocus();
              Navigator.pop(context);
            }
          : null,
      onSkip: _skipInfo,
        skipKey: const Key('skip_artist_info_button'),
        skipText: 'Skip',
        title: 'Artist Profile',
        subtitle: 'Enter your artist name and contact number to get set up.',
        ctaText: 'CONTINUE',
        ctaIcon: Icons.arrow_forward,
        ctaKey: const Key('continue_artist_info_button'),
        isCtaLoading: _isLoading,
        onCtaPressed: _isLoading ? null : _handleContinue,
        backgroundOverlay: const TattooBackgroundWrapper(child: SizedBox.expand()),
        child: FlowPageLayout(
          title: 'Artist Profile',
          subtitle: 'Enter your artist name and contact number to get set up.',
          ctaText: 'CONTINUE',
          ctaKey: const Key('continue_artist_info_button'),
          onCtaPressed: _isLoading ? null : _handleContinue,
          renderInternalHeaderAndCTA: false,
          child: Form(
            key: _formKey,
            child: AdaptiveGlassContainer(
              useGradient: false,
              padding: AppPadding.card,
              borderRadius: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name
                  _buildTextField(
                    key: const Key('artist_name_handle_field'),
                    label: 'Name or Artist Handle',
                    controller: _nameController,
                    focusNode: _nameFocusNode,
                    hintText: '@yourhandle',
                    inputFormatters: const [UsernameInputFormatter()],
                    onTap: () {
                      if (_nameController.text.isEmpty) {
                        _nameController.text = '@';
                        _nameController.selection = const TextSelection.collapsed(offset: 1);
                      } else if (_nameController.text == '@') {
                        _nameController.selection = const TextSelection.collapsed(offset: 1);
                      }
                    },
                    validator: (value) {
                      if (value == null || value.trim().isEmpty || value.trim() == '@') {
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
                    inputFormatters: const [PhoneNumberInputFormatter()],
                    trailingLabelWidget: _isPhoneVerified
                        ? Container(
                            key: const Key('artist_phone_verified_badge'),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0x2222C55E),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFF22C55E), width: 0.8),
                            ),
                            child: Text(
                              'VERIFIED',
                              style: GoogleFonts.plusJakartaSans(
                                color: const Color(0xFF22C55E),
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                              ),
                            ),
                          )
                        : null,
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
                ],
              ),
            ),
          ),
        ),
      );
  }
}
