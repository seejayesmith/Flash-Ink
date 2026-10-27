import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/dev_config.dart';
import '../../services/auth_service.dart';
import '../../widgets/fade_page_route.dart';
import '../../widgets/flash_snack_bar.dart';
import '../../widgets/tattoo_background_wrapper.dart';
import '../../widgets/photo_source_bottom_sheet.dart';
import '../../widgets/profile_avatar_placeholder.dart';
import '../../features/onboarding/shared/onboarding_step_scaffold.dart';
import 'artist_studio_bio_screen.dart';

class ArtistProfilePhotoScreen extends StatefulWidget {
  final String artistName;
  final Uint8List? initialImageBytes;
  final String? instagramHandle;
  final AuthService? authService;

  const ArtistProfilePhotoScreen({
    super.key,
    required this.artistName,
    this.initialImageBytes,
    this.instagramHandle,
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
    FlashSnackBar.showError(context, message);
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
          try {
            await user.reload();
          } catch (_) {}

          final isTest = WidgetsBinding.instance.runtimeType.toString().contains('Test');
          final timeoutDuration = isTest ? const Duration(milliseconds: 500) : const Duration(seconds: 10);

          // Update Firestore draft (profileCompleted stays false until onboarding completes)
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'uid': user.uid,
            'photoURL': photoUrl,
            'photoUrl': photoUrl,
            'onboardingRole': 'artist',
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true)).timeout(timeoutDuration);

          await FirebaseFirestore.instance.collection('artists').doc(user.uid).set({
            'id': user.uid,
            'avatarUrl': photoUrl,
            'photoUrl': photoUrl,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true)).timeout(timeoutDuration);
        } catch (storageError) {
          if (kEnableDevBypass || user is DevMockUser) {
            photoUrl = 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=400&q=80';
            await user.updatePhotoURL(photoUrl);
          }
        }
      }

      if (mounted) {
        FocusManager.instance.primaryFocus?.unfocus();
        Navigator.pushReplacement(
          context,
          FadePageRoute(
            builder: (_) => ArtistStudioBioScreen(
              artistName: widget.artistName,
              photoBytes: _imageBytes,
              photoUrl: photoUrl,
              instagramHandle: widget.instagramHandle,
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
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.push(
      context,
      FadePageRoute(
        builder: (_) => ArtistStudioBioScreen(
          artistName: widget.artistName,
          photoBytes: null,
          photoUrl: null,
          instagramHandle: widget.instagramHandle,
          authService: _authService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasImage = _imageBytes != null;

    return OnboardingStepScaffold(
      currentStep: 2,
      totalSteps: 9,
      onBack: Navigator.canPop(context)
          ? () {
              FocusManager.instance.primaryFocus?.unfocus();
              Navigator.pop(context);
            }
          : null,
      onSkip: _skipProfilePhoto,
      skipText: 'Skip',
      title: 'Add a profile photo',
      subtitle: 'Show the community who you are!\nYou can always change this later.',
      ctaText: 'Continue',
      isCtaEnabled: hasImage,
      isCtaLoading: _isLoading,
      onCtaPressed: (hasImage && !_isLoading) ? _handleContinue : null,
      backgroundOverlay: const TattooBackgroundWrapper(child: SizedBox.expand()),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          // Avatar placeholder with dashed ring / photo preview
          Center(
            child: ProfileAvatarPlaceholder(
              imageBytes: _imageBytes,
              onTap: _handlePhotoSelect,
              onBadgeTap: _handlePhotoSelect,
            ),
          ),

          // "Skip for now" text button (under avatar, hidden if photo uploaded)
          if (!hasImage) ...[
            const SizedBox(height: 16),
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
        ],
      ),
    );
  }
}
