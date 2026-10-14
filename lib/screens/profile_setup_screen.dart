import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import '../widgets/adaptive_glass_container.dart';
import '../widgets/photo_crop_screen.dart';
import '../widgets/photo_source_bottom_sheet.dart';
import '../widgets/skip_pill_button.dart';
import 'aesthetics_selection_screen.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

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

  Future<void> _useSamplePhoto() async {
    try {
      final byteData = await rootBundle.load('assets/images/flash_traditional_moth.jpg');
      final bytes = byteData.buffer.asUint8List();
      if (mounted) {
        final croppedBytes = await Navigator.push<Uint8List?>(
          context,
          MaterialPageRoute(
            builder: (_) => PhotoCropScreen(
              imageBytes: bytes,
              title: 'CROP SAMPLE FLASH',
            ),
          ),
        );
        if (croppedBytes != null && mounted) {
          setState(() {
            _imageBytes = croppedBytes;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Loaded sample photo for testing.'),
              backgroundColor: Color(0xFF22C55E),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load sample photo: $e')),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
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
            builder: (_) => const AestheticsSelectionScreen(isGuest: false),
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
      final user = FirebaseAuth.instance.currentUser;
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
                'Profile Setup',
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildProgressIndicator(0),
                  const SizedBox(width: 6),
                  _buildProgressIndicator(1),
                ],
              ),
            ],
          ),
          SkipPillButton(
            onPressed: _isLoading
                ? null
                : () {
                    FocusScope.of(context).unfocus();
                    if (_currentPage == 0) {
                      _skipUsername();
                    } else {
                      _saveProfile();
                    }
                  },
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator(int stepIndex) {
    final isActive = _currentPage >= stepIndex;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: _currentPage == stepIndex ? 24 : 12,
      height: 4,
      decoration: BoxDecoration(
        color: isActive ? AppTheme.gold : const Color(0xFF333737),
        borderRadius: BorderRadius.circular(2),
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
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.spaceLg),
          Text(
            hasPhoto ? 'Looks good!' : 'Upload a profile photo',
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.textPrimary,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          AppGaps.gapSm,
          Text(
            hasPhoto
                ? 'Looking sharp! Tap the photo anytime to change it.'
                : "Doesn't have to be your face. Just whatever you'd like to represent you.",
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.navInactive,
              fontSize: 16,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.spaceXxl),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: _pickImage,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 156,
                        height: 156,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF1E2020),
                          border: Border.all(
                            color: const Color(0xFF333737),
                            width: 2.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(60),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                          image: hasPhoto
                              ? DecorationImage(
                                  image: MemoryImage(_imageBytes!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: !hasPhoto
                            ? const Center(
                                child: Icon(
                                  Icons.person_outline_rounded,
                                  size: 76,
                                  color: AppTheme.navInactive,
                                ),
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: AppTheme.gold,
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFF141616), width: 2.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(60),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            size: 20,
                            color: Color(0xFF121414),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                AppGaps.gapLg,
                GestureDetector(
                  onTap: _pickImage,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        hasPhoto ? Icons.edit_outlined : Icons.add_photo_alternate_outlined,
                        size: 16,
                        color: hasPhoto ? AppTheme.navInactive : AppTheme.textPrimary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        hasPhoto ? 'Tap to change photo' : 'Tap to select photo',
                        style: GoogleFonts.plusJakartaSans(
                          color: hasPhoto ? AppTheme.navInactive : AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (hasPhoto) ...[
            const SizedBox(height: 36),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.gold,
                  foregroundColor: const Color(0xFF121414),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF121414),
                        ),
                      )
                    : Row(
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
        ],
      ),
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
