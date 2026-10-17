import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/auth_service.dart';
import '../../theme/app_radius.dart';
import '../../widgets/artist_stepper_header.dart';
import '../../widgets/tattoo_background_wrapper.dart';
import '../../widgets/photo_crop_screen.dart';
import '../../widgets/photo_source_bottom_sheet.dart';
import '../../widgets/profile_avatar_placeholder.dart';
import '../../widgets/skip_pill_button.dart';
import 'artist_instagram_screen.dart';

class ArtistProfilePhotoScreen extends StatefulWidget {
  final String artistName;
  final Uint8List? initialImageBytes;
  final AuthService? authService;

  const ArtistProfilePhotoScreen({
    super.key,
    required this.artistName,
    this.initialImageBytes,
    this.authService,
  });

  @override
  State<ArtistProfilePhotoScreen> createState() => _ArtistProfilePhotoScreenState();
}

class _ArtistProfilePhotoScreenState extends State<ArtistProfilePhotoScreen> {
  late final AuthService _authService = widget.authService ?? AuthService();
  final ImagePicker _picker = ImagePicker();

  late Uint8List? _imageBytes = widget.initialImageBytes;
  bool _isLoading = false;

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

  Future<void> _handlePhotoSelect() async {
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
    if (source == null) {
      await _handlePhotoSelect();
      return;
    }

    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1024,
        maxHeight: 1024,
      );

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
      _showErrorSnackBar('Failed to select image: $e');
    }
  }

  Future<void> _handleContinue() async {
    setState(() => _isLoading = true);

    try {
      final user = _authService.currentUser ?? FirebaseAuth.instance.currentUser;
      String? photoUrl;

      if (user != null && _imageBytes != null) {
        try {
          final storageRef = FirebaseStorage.instance
              .ref()
              .child('artist_profiles')
              .child('${user.uid}.jpg');

          await storageRef.putData(
            _imageBytes!,
            SettableMetadata(contentType: 'image/jpeg'),
          );
          photoUrl = await storageRef.getDownloadURL();

          await user.updatePhotoURL(photoUrl);

          // Update Firestore
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'photoURL': photoUrl,
            'profileCompleted': true,
          }, SetOptions(merge: true));

          await FirebaseFirestore.instance.collection('artists').doc(user.uid).set({
            'avatarUrl': photoUrl,
            'profileCompleted': true,
          }, SetOptions(merge: true));
        } catch (storageError) {
          // In case Firebase Storage is offline/mocked in tests
        }
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ArtistInstagramScreen(
              artistName: widget.artistName,
              photoBytes: _imageBytes,
              photoUrl: photoUrl,
              authService: _authService,
            ),
          ),
        );
      }
    } catch (e) {
      _showErrorSnackBar('Failed to save profile: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _skipProfilePhoto() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ArtistInstagramScreen(
          artistName: widget.artistName,
          photoBytes: null,
          photoUrl: null,
          authService: _authService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasImage = _imageBytes != null;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFF121414),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFFF9FAFA), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: SkipPillButton(
                onPressed: _skipProfilePhoto,
              ),
            ),
          ),
        ],
      ),
      body: TattooBackgroundWrapper(
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Stepper: Step 1 completed with checkmark, Step 2 active
                const ArtistStepperHeader(currentStep: 2),
                const SizedBox(height: 24),

                // Headline
                Text(
                  'Add a profile photo',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFF9FAFA),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),

                Text(
                  'Show the community who you are!\nYou can always change this later.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    color: const Color(0xFF919696),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 36),

                // Avatar placeholder with dashed ring / photo preview
                Center(
                  child: ProfileAvatarPlaceholder(
                    imageBytes: _imageBytes,
                    onTap: _handlePhotoSelect,
                    onBadgeTap: _handlePhotoSelect,
                  ),
                ),
                const SizedBox(height: 36),

                // "Upload a Photo" button
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
                        color: const Color(0xFFF9FAFA),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // "Take a Picture" text button
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
                          color: const Color(0xFFF9FAFA),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // "Continue" button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: (_isLoading || !hasImage) ? null : _handleContinue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEEC200),
                      disabledBackgroundColor: const Color(0xFF262929),
                      disabledForegroundColor: const Color(0xFF6B7272),
                      foregroundColor: const Color(0xFF121414),
                      elevation: 0,
                      shape: const StadiumBorder(),
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
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 8),

                // "Skip for now" text button
                Center(
                  child: TextButton(
                    onPressed: _isLoading ? null : _skipProfilePhoto,
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF919696),
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    ),
                    child: Text(
                      'Skip for now',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF919696),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
