import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import '../widgets/adaptive_glass_container.dart';
import '../widgets/photo_crop_screen.dart';
import '../widgets/photo_source_bottom_sheet.dart';
import '../widgets/profile_avatar_placeholder.dart';
import '../widgets/skip_pill_button.dart';
import 'aesthetics_selection_screen.dart';

class ProfileSetupScreen extends StatefulWidget {
  final AuthService? authService;

  const ProfileSetupScreen({super.key, this.authService});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

/// Automatically ensures username has '@' prefix when typing,
/// while allowing the field to be cleared back to empty so hint text appears.
class _UsernameInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    final stripped = newValue.text.replaceAll('@', '');
    if (stripped.isEmpty) {
      return const TextEditingValue(
        text: '@',
        selection: TextSelection.collapsed(offset: 1),
      );
    }

    final formatted = '@$stripped';

    int nonAtBeforeCursor = 0;
    final end = newValue.selection.end.clamp(0, newValue.text.length);
    for (int i = 0; i < end; i++) {
      if (newValue.text[i] != '@') {
        nonAtBeforeCursor++;
      }
    }

    final newOffset = (1 + nonAtBeforeCursor).clamp(0, formatted.length);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: newOffset),
    );
  }
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  late final AuthService _authService = widget.authService ?? AuthService();
  final _usernameController = TextEditingController();
  final FocusNode _usernameFocusNode = FocusNode();
  bool _isLoading = false;
  String? _usernameError;
  int _currentPage = 0;

  Uint8List? _imageBytes;
  final ImagePicker _picker = ImagePicker();
  final PageController _pageController = PageController();

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
    _pageController.dispose();
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

  Future<void> _pickImage([ImageSource? source]) async {
    FocusScope.of(context).unfocus();
    if (source == null) {
      await _handlePhotoSelect();
      return;
    }

    try {
      final pickedFile = await _picker.pickImage(source: source, imageQuality: 80);
      if (pickedFile != null && mounted) {
        final bytes = await pickedFile.readAsBytes();
        if (!mounted) return;
        final croppedBytes = await Navigator.push<Uint8List?>(
          context,
          MaterialPageRoute(
            builder: (_) => PhotoCropScreen(imageBytes: bytes),
          ),
        );
        if (croppedBytes != null && mounted) {
          setState(() {
            _imageBytes = croppedBytes;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);
    try {
      final user = _authService.currentUser ?? FirebaseAuth.instance.currentUser;
      if (user != null) {
        String? photoUrl;
        if (_imageBytes != null) {
          try {
            final storageRef = FirebaseStorage.instance.ref().child('user_profiles').child('${user.uid}.jpg');
            await storageRef.putData(_imageBytes!, SettableMetadata(contentType: 'image/jpeg'));
            photoUrl = await storageRef.getDownloadURL();
          } catch (e) {
            // Ignore upload failure
          }
        }

        final updateData = {
          'username': _usernameController.text.trim().replaceAll('@', ''),
          'profileCompleted': true,
        };

        if (photoUrl != null) {
          updateData['photoURL'] = photoUrl;
          await user.updatePhotoURL(photoUrl);
        }

        try {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set(updateData, SetOptions(merge: true));
        } catch (_) {}
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => AestheticsSelectionScreen(
              isGuest: _authService.isGuest,
              authService: _authService,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save profile: $e'),
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

  void _nextStep() {
    FocusScope.of(context).unfocus();
    final rawUsername = _usernameController.text.trim().replaceAll('@', '');
    if (rawUsername.isEmpty) {
      setState(() => _usernameError = 'Please enter a username');
      return;
    }
    setState(() => _usernameError = null);
    _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
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
    setState(() => _usernameError = null);
    _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spaceSm, vertical: AppSpacing.spaceSm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentPage > 0)
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textPrimary, size: 20),
              onPressed: () {
                FocusScope.of(context).unfocus();
                _pageController.previousPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
              tooltip: 'Back',
            )
          else
            const SizedBox(width: 48, height: 48),
          Column(
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
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: (_currentPage + 1) / 4.0,
                    backgroundColor: const Color(0xFF262929),
                    valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.gold),
                    minHeight: 4,
                  ),
                ),
              ),
            ],
          ),
          if (_currentPage == 0)
            SkipPillButton(
              onPressed: _isLoading
                  ? null
                  : () {
                      FocusScope.of(context).unfocus();
                      _skipUsername();
                    },
            )
          else
            const SizedBox(width: 48, height: 48),
        ],
      ),
    );
  }

  Widget _buildUsernameStep() {
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.spaceLg),
          Text(
            'Add a username',
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.textPrimary,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          AppGaps.gapSm,
          Text(
            'Build a report. Tell the artists who you are.',
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.navInactive,
              fontSize: 16,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.spaceXxl),
          AdaptiveGlassContainer(
            borderRadius: 24,
            blurSigma: 16,
            unselectedBorderColor: const Color(0x33EEC200),
            unselectedBorderWidth: 1.0,
            padding: const EdgeInsets.all(AppSpacing.spaceXl),
            child: Column(
              children: [
                TextField(
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
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF333737)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF333737)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.gold, width: 1.5),
                    ),
                  ),
                  onSubmitted: (_) {
                    FocusScope.of(context).unfocus();
                    _nextStep();
                  },
                ),
                AppGaps.gapXl,
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _nextStep,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.gold,
                      foregroundColor: const Color(0xFF121414),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'CONTINUE',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_rounded, size: 18),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoStep() {
    final hasPhoto = _imageBytes != null;
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: AppSpacing.spaceLg),
                  Text(
                    'Add a profile photo',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.textPrimary,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Show the community who you are!\nYou can always change this later.',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.navInactive,
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Center(
                    child: ProfileAvatarPlaceholder(
                      imageBytes: _imageBytes,
                      onTap: _handlePhotoSelect,
                      onBadgeTap: _handlePhotoSelect,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Upload a Photo button
                  GestureDetector(
                    onTap: () => _pickImage(ImageSource.gallery),
                    child: Container(
                      width: double.infinity,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E2020),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: const Color(0xFF383C3C),
                          width: 1.2,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Upload a Photo',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Take a Picture button
                  Center(
                    child: GestureDetector(
                      onTap: () => _pickImage(ImageSource.camera),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'Take a Picture',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(height: 24),

                  // Continue Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: (hasPhoto && !_isLoading) ? _saveProfile : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.gold,
                        disabledBackgroundColor: const Color(0xFF262929),
                        disabledForegroundColor: const Color(0xFF6B7272),
                        foregroundColor: const Color(0xFF121414),
                        shape: const StadiumBorder(),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF121414)),
                              ),
                            )
                          : Text(
                              'Continue',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                letterSpacing: 0.8,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Skip for now button
                  Center(
                    child: TextButton(
                      onPressed: _isLoading ? null : _saveProfile,
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.navInactive,
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
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
                  ),
                  const SizedBox(height: AppSpacing.spaceMd),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: Scaffold(
          backgroundColor: AppTheme.onyxBackground,
          extendBodyBehindAppBar: true,
          body: Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  'assets/images/tattoo_setup.png',
                  fit: BoxFit.cover,
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
                        Colors.black.withAlpha(200),
                        Colors.black.withAlpha(160),
                        Colors.black.withAlpha(200),
                      ],
                      stops: const [0.0, 0.3, 0.7, 1.0],
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Column(
                  children: [
                    _buildTopBar(),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spaceXl),
                        child: PageView(
                          controller: _pageController,
                          physics: const NeverScrollableScrollPhysics(),
                          onPageChanged: (page) {
                            FocusScope.of(context).unfocus();
                            setState(() => _currentPage = page);
                          },
                          children: [
                            _buildUsernameStep(),
                            _buildPhotoStep(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
