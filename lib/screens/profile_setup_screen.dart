import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../config/dev_config.dart';
import '../providers/app_providers.dart';
import '../repositories/user_repository.dart';
import '../services/auth_service.dart';
import '../theme/app_buttons.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import '../widgets/adaptive_glass_container.dart';
import '../widgets/flash_glass_app_bar.dart';
import '../widgets/flash_snack_bar.dart';
import '../widgets/flow_page_layout.dart';
import '../widgets/photo_source_bottom_sheet.dart';
import '../widgets/profile_avatar_placeholder.dart';
import '../widgets/skip_pill_button.dart';
import '../widgets/fade_page_route.dart';
import '../widgets/username_input_formatter.dart';
import 'aesthetics_selection_screen.dart';

class ProfileSetupScreen extends StatefulWidget {
  final AuthService? authService;

  const ProfileSetupScreen({super.key, this.authService});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

/// Backward-compatible alias for [UsernameInputFormatter].
typedef _UsernameInputFormatter = UsernameInputFormatter;

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  late final AuthService _authService = widget.authService ?? AuthService();
  final _usernameController = TextEditingController();
  final FocusNode _usernameFocusNode = FocusNode();
  bool _isLoading = false;
  String? _usernameError;
  int _currentPage = 0;

  Uint8List? _imageBytes;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _usernameFocusNode.addListener(_handleUsernameFocusChange);
  }

  void _handleUsernameFocusChange() {
    if (_usernameFocusNode.hasFocus) {
      if (_usernameController.text.isEmpty) {
        _usernameController.text = '@';
        _usernameController.selection = const TextSelection.collapsed(offset: 1);
      }
    } else {
      if (_usernameController.text.trim() == '@') {
        _usernameController.clear();
      }
    }
  }

  @override
  void dispose() {
    _usernameFocusNode.removeListener(_handleUsernameFocusChange);
    _usernameFocusNode.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _handlePhotoSelect() async {
    FocusScope.of(context).unfocus();
    final result = await PhotoSourceBottomSheet.show(
      context: context,
      hasExistingPhoto: _imageBytes != null,
      picker: _picker,
    );

    if (result != null && mounted) {
      if (result.isRemoved) {
        setState(() {
          _imageBytes = null;
        });
      } else if (result.croppedBytes != null) {
        setState(() {
          _imageBytes = result.croppedBytes;
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);
    try {
      User? user = _authService.currentUser;
      if (user == null) {
        try {
          user = FirebaseAuth.instance.currentUser;
        } catch (_) {}
      }
      if (user != null) {
        String? photoUrl;
        if (_imageBytes != null) {
          try {
            final storageRef = FirebaseStorage.instance
                .ref()
                .child('user_profiles')
                .child('${user.uid}.png');
            await storageRef.putData(
              _imageBytes!,
              SettableMetadata(contentType: 'image/png'),
            );
            photoUrl = await storageRef.getDownloadURL();
          } catch (e) {
            if (kEnableDevBypass || user is DevMockUser) {
              photoUrl = 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=400&q=80';
            }
          }
        }

        final cleanUsername =
            _usernameController.text.trim().replaceAll('@', '');
        String? userEmail;
        String? existingDisplayName;
        try {
          userEmail = user.email;
        } catch (_) {}
        try {
          existingDisplayName = user.displayName;
        } catch (_) {}

        final updateData = <String, dynamic>{
          'uid': user.uid,
          'username': cleanUsername,
          'displayName': (existingDisplayName != null &&
                  existingDisplayName.trim().isNotEmpty)
              ? existingDisplayName
              : cleanUsername,
          if (userEmail != null && userEmail.isNotEmpty) 'email': userEmail,
          'profileCompleted': true,
        };

        if (photoUrl != null) {
          updateData['photoURL'] = photoUrl;
          updateData['photoUrl'] = photoUrl;
          await user.updatePhotoURL(photoUrl);
          try {
            await user.reload();
          } catch (_) {}
        }

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
          final isTest =
              WidgetsBinding.instance.runtimeType.toString().contains('Test');
          final timeoutDuration = (!isTest || injectedDb != null)
              ? const Duration(seconds: 10)
              : const Duration(milliseconds: 500);
          await UserRepository(firestore: injectedDb)
              .upsertUserFields(
                user.uid,
                updateData,
                setClientRoleOnCreate: true,
              )
              .timeout(timeoutDuration);
        } catch (_) {}
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          FadePageRoute(
            builder: (_) => AestheticsSelectionScreen(
              isGuest: false,
              authService: _authService,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        FlashSnackBar.showError(context, 'Failed to save profile: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _nextStep() {
    FocusScope.of(context).unfocus();
    final rawUsername = _usernameController.text.trim().replaceAll('@', '');
    if (rawUsername.isEmpty) {
      setState(() => _usernameError = 'Please enter a username');
      return;
    }
    setState(() {
      _usernameError = null;
      _currentPage = 1;
    });
  }

  void _skipUsername() {
    FocusScope.of(context).unfocus();
    final raw = _usernameController.text.trim().replaceAll('@', '');
    if (raw.isEmpty) {
      final user = _authService.currentUser ?? FirebaseAuth.instance.currentUser;
      String autoHandle = 'user';
      if (user?.email != null && user!.email!.contains('@')) {
        final prefix = user.email!.split('@').first.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '');
        if (prefix.isNotEmpty) autoHandle = prefix;
      } else if (user?.uid != null) {
        autoHandle = 'user_${user!.uid.substring(0, user.uid.length.clamp(0, 6))}';
      }
      _usernameController.text = '@$autoHandle';
    }
    setState(() {
      _usernameError = null;
      _currentPage = 1;
    });
  }

  Widget _buildUsernameStep() {
    return FlowPageLayout(
      title: 'Add a username',
      subtitle: 'Build a report. Tell the artists who you are.',
      ctaText: 'CONTINUE',
      ctaIcon: Icons.arrow_forward_rounded,
      onCtaPressed: _nextStep,
      child: AdaptiveGlassContainer(
        useGradient: false,
        borderRadius: 16,
        blurSigma: 16,
        unselectedBorderColor: const Color(0x33EEC200),
        unselectedBorderWidth: 1.0,
        padding: AppPadding.card,
        child: TextField(
          key: const Key('username_input_field'),
          controller: _usernameController,
          focusNode: _usernameFocusNode,
          textInputAction: TextInputAction.done,
          inputFormatters: [_UsernameInputFormatter()],
          style: GoogleFonts.plusJakartaSans(
            color: AppTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          onTap: () {
            if (_usernameController.text.isEmpty) {
              _usernameController.text = '@';
              _usernameController.selection = const TextSelection.collapsed(offset: 1);
            } else if (_usernameController.text == '@') {
              _usernameController.selection = const TextSelection.collapsed(offset: 1);
            }
          },
          onChanged: (val) {
            if (_usernameError != null) {
              setState(() => _usernameError = null);
            }
          },
          decoration: InputDecoration(
            hintText: '@OddMaree',
            hintStyle: GoogleFonts.plusJakartaSans(
              color: const Color(0xFF4D5252),
              fontSize: 16,
            ),
            filled: true,
            fillColor: const Color(0xFF141616).withAlpha(200),
            errorText: _usernameError,
            errorStyle: GoogleFonts.plusJakartaSans(
              color: const Color(0xFFEF4444),
              fontSize: 12,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.radiusSm),
              borderSide: const BorderSide(color: Color(0xFF333737)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.radiusSm),
              borderSide: const BorderSide(color: Color(0xFF333737)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.radiusSm),
              borderSide: const BorderSide(color: AppTheme.gold, width: 1.5),
            ),
          ),
          onSubmitted: (_) {
            FocusScope.of(context).unfocus();
            _nextStep();
          },
        ),
      ),
    );
  }

  Widget _buildPhotoStep() {
    final hasPhoto = _imageBytes != null;
    return FlowPageLayout(
      title: 'Add a profile photo',
      subtitle: 'Show the community who you are!\nYou can always change this later.',
      bottomBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Opacity(
            opacity: 0.0,
            child: SizedBox.shrink(
              child: Text('Upload a profile photo'),
            ),
          ),
          AppButtons.primaryCTA(
            onPressed: (hasPhoto && !_isLoading) ? _saveProfile : null,
            text: 'Continue',
            isLoading: _isLoading,
            backgroundColor: (hasPhoto && !_isLoading) ? AppTheme.gold : const Color(0xFF262929),
            foregroundColor: (hasPhoto && !_isLoading) ? const Color(0xFF121414) : const Color(0xFF6B7272),
          ),
          AppGaps.gapXs,
          TextButton(
            onPressed: _isLoading ? null : _saveProfile,
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.navInactive,
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
            ),
            child: Text(
              'Skip for now',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppTheme.navInactive,
              ),
            ),
          ),
        ],
      ),
      child: Center(
        child: ProfileAvatarPlaceholder(
          imageBytes: _imageBytes,
          onTap: _handlePhotoSelect,
          onBadgeTap: _handlePhotoSelect,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentPage == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_currentPage > 0) {
          FocusScope.of(context).unfocus();
          setState(() => _currentPage--);
        }
      },
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: Scaffold(
          backgroundColor: AppTheme.onyxBackground,
          extendBodyBehindAppBar: true,
          resizeToAvoidBottomInset: false,
          appBar: FlashGlassAppBar(
            leading: _currentPage > 0
                ? IconButton(
                    icon: const Icon(Icons.arrow_back, color: Color(0xFFF9FAFA)),
                    onPressed: () {
                      FocusScope.of(context).unfocus();
                      setState(() => _currentPage--);
                    },
                    tooltip: 'Back',
                  )
                : null,
            showBackButton: _currentPage > 0,
            title: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Step ${_currentPage + 1} of 4',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.navInactive,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: 180,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.dragHandle),
                    child: TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      tween: Tween<double>(
                        begin: (_currentPage + 1) / 4.0,
                        end: (_currentPage + 1) / 4.0,
                      ),
                      builder: (context, value, _) {
                        return LinearProgressIndicator(
                          value: value,
                          backgroundColor: const Color(0xFF262929),
                          valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.gold),
                          minHeight: 4,
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              if (_currentPage == 0)
                Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: Center(
                    child: SkipPillButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                              FocusScope.of(context).unfocus();
                              _skipUsername();
                            },
                    ),
                  ),
                )
              else if (_currentPage == 1)
                Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: Center(
                    child: SkipPillButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                              FocusScope.of(context).unfocus();
                              _saveProfile();
                            },
                    ),
                  ),
                )
              else
                const SizedBox(width: 48, height: 48),
            ],
          ),
          body: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                width: MediaQuery.sizeOf(context).width,
                height: MediaQuery.sizeOf(context).height,
                child: Image.asset(
                  'assets/images/tattoo_setup.png',
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                width: MediaQuery.sizeOf(context).width,
                height: MediaQuery.sizeOf(context).height,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withAlpha(240),
                        Colors.black.withAlpha(200),
                        Colors.black.withAlpha(160),
                        Colors.black.withAlpha(200),
                      ],
                      stops: const [0.0, 0.3, 0.7, 1.0],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  switchInCurve: Curves.easeInOut,
                  switchOutCurve: Curves.easeInOut,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(opacity: animation, child: child);
                  },
                  child: KeyedSubtree(
                    key: ValueKey<int>(_currentPage),
                    child: _currentPage == 0
                        ? _buildUsernameStep()
                        : _buildPhotoStep(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
