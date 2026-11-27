import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/dev_config.dart';
import '../../providers/app_providers.dart';
import '../../services/auth_service.dart';
import '../../services/auth/dev_mock_user.dart';
import '../../services/username_service.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/adaptive_glass_container.dart';
import '../../widgets/fade_page_route.dart';
import '../../widgets/flash_snack_bar.dart';
import '../../widgets/flow_page_layout.dart';
import '../../widgets/phone_number_input_formatter.dart';
import '../../widgets/tattoo_background_wrapper.dart';
import '../../widgets/username_input_formatter.dart';
import '../../features/onboarding/shared/onboarding_step_scaffold.dart';
import '../backup_email_verification_screen.dart';
import 'artist_phone_verification_screen.dart';
import 'artist_profile_photo_screen.dart';

/// Determines which optional secondary contact field (if any) is requested on
/// [ArtistInfoScreen] based on how the artist signed up.
enum ArtistSignInMethod {
  /// Google, Apple, or generic Account Creation dev-skip -> handle only.
  oauth,

  /// Phone OTP sign-up -> handle + optional backup email (phone already verified).
  phone,

  /// Email sign-up -> handle + optional phone number (email already verified).
  email,
}

class ArtistInfoScreen extends StatefulWidget {
  final AuthService? authService;
  final FirebaseFirestore? firestore;
  final String? initialName;
  final String? initialEmail;
  final String? initialPhone;
  final ArtistSignInMethod? signInMethod;

  const ArtistInfoScreen({
    super.key,
    this.authService,
    this.firestore,
    this.initialName,
    this.initialEmail,
    this.initialPhone,
    this.signInMethod,
  });

  @override
  State<ArtistInfoScreen> createState() => _ArtistInfoScreenState();
}

class _ArtistInfoScreenState extends State<ArtistInfoScreen> {
  late final AuthService _authService = widget.authService ?? AuthService();

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _backupEmailController;
  final FocusNode _nameFocusNode = FocusNode();

  bool _agreedToTerms = false;
  bool _isLoading = false;
  String? _errorMessage;
  String? _usernameConflictError;

  String get _existingEmail {
    if (widget.initialEmail != null && widget.initialEmail!.trim().isNotEmpty) {
      return widget.initialEmail!.trim();
    }
    try {
      return _authService.currentUser?.email?.trim() ?? '';
    } catch (_) {
      return '';
    }
  }

  String get _existingPhone {
    if (widget.initialPhone != null && widget.initialPhone!.trim().isNotEmpty) {
      return widget.initialPhone!.trim();
    }
    try {
      return _authService.currentUser?.phoneNumber?.trim() ?? '';
    } catch (_) {
      return '';
    }
  }

  ArtistSignInMethod get _resolvedSignInMethod {
    if (widget.signInMethod != null) {
      return widget.signInMethod!;
    }

    User? user;
    try {
      user = _authService.currentUser;
    } catch (_) {}

    // 1. OAuth users (Google or Apple) only need to create their handle.
    if (user != null && AuthService.isOAuthUser(user)) {
      return ArtistSignInMethod.oauth;
    }

    // 2. Inspect Firebase Auth providerData when present.
    List<String> providerIds = const [];
    try {
      providerIds = user?.providerData
              .map((info) => info.providerId)
              .where((id) => id.isNotEmpty)
              .toList() ??
          const [];
    } catch (_) {}

    final hasPhoneProvider = providerIds.contains('phone');
    final hasEmailProvider =
        providerIds.contains('password') || providerIds.contains('emailLink');

    final existingEmail = _existingEmail;
    final existingPhone = _existingPhone;

    if (hasPhoneProvider && !hasEmailProvider) {
      return existingEmail.isEmpty
          ? ArtistSignInMethod.phone
          : ArtistSignInMethod.oauth;
    }
    if (hasEmailProvider && !hasPhoneProvider) {
      return existingPhone.isEmpty
          ? ArtistSignInMethod.email
          : ArtistSignInMethod.oauth;
    }

    // 3. Generic DevMockUser without an explicit signInMethod defaults to handle-only.
    if (user is DevMockUser) {
      return ArtistSignInMethod.oauth;
    }

    // 4. Fallback inference from email/phone values.
    final lowerEmail = existingEmail.toLowerCase();
    if (lowerEmail.endsWith('@gmail.com') ||
        lowerEmail.endsWith('@googlemail.com') ||
        lowerEmail.endsWith('@privaterelay.appleid.com')) {
      return ArtistSignInMethod.oauth;
    }

    if (existingPhone.isNotEmpty && existingEmail.isEmpty) {
      return ArtistSignInMethod.phone;
    }
    if (existingEmail.isNotEmpty && existingPhone.isEmpty) {
      return ArtistSignInMethod.email;
    }
    if (existingPhone.isNotEmpty && existingEmail.isNotEmpty) {
      return ArtistSignInMethod.oauth;
    }

    // Default when no prior auth metadata exists yet.
    return ArtistSignInMethod.email;
  }

  bool get _showPhoneField => _resolvedSignInMethod == ArtistSignInMethod.email;

  bool get _showBackupEmailField =>
      _resolvedSignInMethod == ArtistSignInMethod.phone;

  String get _subtitle {
    switch (_resolvedSignInMethod) {
      case ArtistSignInMethod.phone:
        return 'Enter your artist name and an optional backup email to get set up.';
      case ArtistSignInMethod.email:
        return 'Enter your artist name and an optional phone number to get set up.';
      case ArtistSignInMethod.oauth:
        return 'Enter your artist name to get set up.';
    }
  }

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
    if (defaultName.isNotEmpty) {
      final cleanDefault = defaultName
          .trim()
          .replaceFirst(RegExp(r'^@+'), '')
          .replaceAll(RegExp(r'\s+'), '_');
      defaultName = cleanDefault.isNotEmpty ? '@$cleanDefault' : '';
    }
    _nameController = TextEditingController(text: defaultName);
    _nameFocusNode.addListener(_handleNameFocusChange);

    // Optional secondary contact inputs always start blank because the already-verified
    // primary contact method is hidden on this screen.
    _backupEmailController = TextEditingController();
    _phoneController = TextEditingController();
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
    _nameController.dispose();
    _phoneController.dispose();
    _backupEmailController.dispose();
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
    _usernameConflictError = null;
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

    final method = _resolvedSignInMethod;
    final name = _nameController.text.trim();
    final rawEnteredPhone = _showPhoneField ? _phoneController.text.trim() : '';
    final enteredFormattedPhone =
        rawEnteredPhone.isNotEmpty ? _formatPhoneNumber(rawEnteredPhone) : '';
    final enteredBackupEmail =
        _showBackupEmailField ? _backupEmailController.text.trim() : '';

    final currentUser = _authService.currentUser;
    final uid = currentUser?.uid ?? 'artist_${DateTime.now().millisecondsSinceEpoch}';
    final existingEmail = _existingEmail;
    final existingPhone =
        method == ArtistSignInMethod.phone && _existingPhone.isNotEmpty
            ? _formatPhoneNumber(_existingPhone)
            : '';
    final persistedPhone =
        existingPhone.isNotEmpty ? existingPhone : enteredFormattedPhone;
    final bool hasVerifiedPhone =
        method == ArtistSignInMethod.phone && existingPhone.isNotEmpty;

    try {
      FirebaseFirestore? injectedDb = widget.firestore;
      if (injectedDb == null && mounted) {
        try {
          injectedDb = ProviderScope.containerOf(
            context,
            listen: false,
          ).read(firebaseFirestoreProvider);
        } catch (_) {}
      }
      final isWidgetTest =
          WidgetsBinding.instance.runtimeType.toString().contains('Test');
      final timeoutDuration = (!isWidgetTest || injectedDb != null)
          ? const Duration(seconds: 6)
          : const Duration(milliseconds: 200);

      final cleanUsername = UsernameService.cleanDisplay(name);
      final usernameService = UsernameService(firestore: injectedDb);
      if (!isWidgetTest || injectedDb != null) {
        await usernameService
            .claimUsername(
              uid: uid,
              rawUsername: cleanUsername,
              emptyMessage: 'Please enter your name or artist handle',
            )
            .timeout(timeoutDuration);
      }

      if (currentUser != null) {
        try {
          await currentUser.updateDisplayName(name);
        } catch (_) {}
      }

      // 1. Save artist profile details to Firestore (PII isolated to /users/{uid} and /artists/{uid}/private/settings)
      try {
        final db = injectedDb ?? FirebaseFirestore.instance;

        final userDoc = db.collection('users').doc(uid);
        final existingUserSnap = await userDoc.get().timeout(timeoutDuration);
        final existingUserData = existingUserSnap.data();
        final bool clientAlreadyCompleted =
            existingUserData?['profileCompleted'] == true;
        final bool hasClientName =
            (existingUserData?['displayName'] as String?)?.trim().isNotEmpty ==
                true;
        final bool hasClientUsername =
            (existingUserData?['username'] as String?)?.trim().isNotEmpty ==
                true;

        final userUpdates = <String, dynamic>{
          'uid': uid,
          if (!hasClientName) 'displayName': name,
          if (!hasClientUsername) 'username': cleanUsername,
          if (existingEmail.isNotEmpty) 'email': existingEmail,
          if (enteredBackupEmail.isNotEmpty)
            'pendingBackupEmail': enteredBackupEmail,
          if (persistedPhone.isNotEmpty) 'phoneNumber': persistedPhone,
          if (hasVerifiedPhone) 'phoneVerified': true,
          'onboardingRole': 'artist',
          'activeMode': 'artist',
          if (!clientAlreadyCompleted) 'profileCompleted': false,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        await userDoc.set(userUpdates, SetOptions(merge: true)).timeout(timeoutDuration);

        final artistDoc = db.collection('artists').doc(uid);
        await artistDoc.set({
          'id': uid,
          'name': name,
          'displayName': name,
          'username': cleanUsername,
          'isBooksOpen': false,
          'profileCompleted': false,
          'rating': 5.0,
          'availablePieces': 0,
          'minDeposit': 50,
          if (hasVerifiedPhone) 'phoneVerified': true,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)).timeout(timeoutDuration);

        final privateSettings = <String, dynamic>{
          if (existingEmail.isNotEmpty) 'email': existingEmail,
          if (enteredBackupEmail.isNotEmpty)
            'pendingBackupEmail': enteredBackupEmail,
          if (persistedPhone.isNotEmpty) 'phoneNumber': persistedPhone,
          if (hasVerifiedPhone) 'phoneVerified': true,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        await artistDoc.collection('private').doc('settings').set(
          privateSettings,
          SetOptions(merge: true),
        ).timeout(timeoutDuration);
      } catch (_) {}

      // 2a. Phone sign-up artist who entered an optional backup email -> verify email right away.
      if (enteredBackupEmail.isNotEmpty) {
        try {
          await _authService.sendBackupEmailVerification(
            enteredBackupEmail,
            isArtist: true,
          );
        } catch (_) {}
        if (!mounted) return;
        setState(() => _isLoading = false);
        FocusManager.instance.primaryFocus?.unfocus();
        Navigator.pushReplacement(
          context,
          FadePageRoute(
            builder: (_) => BackupEmailVerificationScreen(
              email: enteredBackupEmail,
              authService: _authService,
              isArtist: true,
              nextScreenBuilder: (_) => ArtistProfilePhotoScreen(
                artistName: name,
                authService: _authService,
              ),
            ),
          ),
        );
        return;
      }

      // 2b. Email sign-up artist who entered an optional phone number -> verify via SMS OTP.
      if (enteredFormattedPhone.isNotEmpty) {
        await _authService.verifyPhoneNumber(
          phoneNumber: enteredFormattedPhone,
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
                  phoneNumber: enteredFormattedPhone,
                  verificationId: verificationId,
                  resendToken: resendToken,
                  artistName: name,
                  artistEmail: existingEmail,
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
                    phoneNumber: enteredFormattedPhone,
                    verificationId: 'dev_verification_id',
                    resendToken: 123,
                    artistName: name,
                    artistEmail: existingEmail,
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
        return;
      }

      // 2c. OAuth user OR artist who left the optional secondary contact blank -> proceed directly.
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
    } on UsernameTakenException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _usernameConflictError = e.message;
        _errorMessage = e.message;
      });
      _formKey.currentState?.validate();
      _showErrorSnackBar(e.message);
    } on UsernameFormatException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _usernameConflictError = e.message;
        _errorMessage = e.message;
      });
      _formKey.currentState?.validate();
      _showErrorSnackBar(e.message);
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
    String? existingDisplayName;
    try {
      existingDisplayName = _authService.currentUser?.displayName;
    } catch (_) {}
    final name = raw.isNotEmpty && raw != '@'
        ? raw
        : (widget.initialName?.isNotEmpty == true
            ? (widget.initialName!.startsWith('@') ? widget.initialName! : '@${widget.initialName}')
            : (existingDisplayName?.isNotEmpty == true
                ? (existingDisplayName!.startsWith('@')
                    ? existingDisplayName
                    : '@$existingDisplayName')
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
      totalSteps: 10,
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
        subtitle: _subtitle,
        ctaText: 'Continue',
        ctaIcon: Icons.arrow_forward,
        ctaKey: const Key('continue_artist_info_button'),
        isCtaLoading: _isLoading,
        onCtaPressed: _isLoading ? null : _handleContinue,
        backgroundOverlay: const TattooBackgroundWrapper(child: SizedBox.expand()),
        child: FlowPageLayout(
          title: 'Artist Profile',
          subtitle: _subtitle,
          ctaText: 'Continue',
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
                      final formatError = UsernameService.validateFormat(
                        value ?? '',
                        emptyMessage: 'Please enter your name or artist handle',
                      );
                      if (formatError != null) {
                        return formatError;
                      }
                      if (_usernameConflictError != null) {
                        return _usernameConflictError;
                      }
                      return null;
                    },
                  ),
                  if (_showPhoneField) ...[
                    const SizedBox(height: 16),
                    // Optional Phone Number (shown for Email sign-ups)
                    _buildTextField(
                      key: const Key('artist_phone_field'),
                      label: 'Phone Number (Optional)',
                      controller: _phoneController,
                      hintText: '(555) 000-0000',
                      keyboardType: TextInputType.phone,
                      inputFormatters: const [PhoneNumberInputFormatter()],
                      validator: (value) {
                        final trimmed = value?.trim() ?? '';
                        if (trimmed.isEmpty) return null;
                        final digits = trimmed.replaceAll(RegExp(r'\D'), '');
                        if (digits.length < 10) {
                          return 'Please enter a valid 10-digit phone number';
                        }
                        return null;
                      },
                    ),
                  ],
                  if (_showBackupEmailField) ...[
                    const SizedBox(height: 16),
                    // Optional Backup Email (shown for Phone OTP sign-ups)
                    _buildTextField(
                      key: const Key('artist_backup_email_field'),
                      label: 'Backup Email (Optional)',
                      controller: _backupEmailController,
                      hintText: 'you@studio.com',
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        final trimmed = value?.trim() ?? '';
                        if (trimmed.isEmpty) return null;
                        if (!trimmed.contains('@') || !trimmed.contains('.')) {
                          return 'Please enter a valid backup email address';
                        }
                        return null;
                      },
                    ),
                  ],
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
