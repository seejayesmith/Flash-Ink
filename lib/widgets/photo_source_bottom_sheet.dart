import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import 'adaptive_glass_container.dart';
import 'photo_crop_screen.dart';

/// The result returned after a user picks/crops a photo or chooses to remove it.
class ProfilePhotoResult {
  final Uint8List? croppedBytes;
  final bool isRemoved;

  const ProfilePhotoResult.cropped(this.croppedBytes) : isRemoved = false;
  const ProfilePhotoResult.removed() : croppedBytes = null, isRemoved = true;
}

/// Modern dark-onyx bottom sheet for selecting, cropping, or removing profile photos.
class PhotoSourceBottomSheet extends StatelessWidget {
  final bool hasExistingPhoto;
  final ImagePicker picker;

  PhotoSourceBottomSheet({
    super.key,
    this.hasExistingPhoto = false,
    ImagePicker? picker,
  }) : picker = picker ?? ImagePicker();

  /// Static helper to display the sheet, handle picking, open the crop screen,
  /// and return the resulting [ProfilePhotoResult].
  static Future<ProfilePhotoResult?> show({
    required BuildContext context,
    bool hasExistingPhoto = false,
    ImagePicker? picker,
  }) async {
    final effectivePicker = picker ?? ImagePicker();

    return showModalBottomSheet<ProfilePhotoResult?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => PhotoSourceBottomSheet(
        hasExistingPhoto: hasExistingPhoto,
        picker: effectivePicker,
      ),
    );
  }

  Future<void> _pickAndCrop(
    BuildContext context,
    ImageSource source,
  ) async {
    try {
      final pickedFile = await picker.pickImage(
        source: source,
        imageQuality: 90,
        maxWidth: 1600,
        maxHeight: 1600,
      );

      if (pickedFile != null && context.mounted) {
        final bytes = await pickedFile.readAsBytes();
        final croppedBytes = await Navigator.push<Uint8List?>(
          context,
          MaterialPageRoute(
            builder: (_) => PhotoCropScreen(imageBytes: bytes),
          ),
        );

        if (croppedBytes != null && context.mounted) {
          Navigator.pop(context, ProfilePhotoResult.cropped(croppedBytes));
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to select photo: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  Future<void> _useSamplePhoto(BuildContext context) async {
    try {
      final byteData = await rootBundle.load('assets/images/flash_traditional_moth.jpg');
      final bytes = byteData.buffer.asUint8List();

      if (context.mounted) {
        final croppedBytes = await Navigator.push<Uint8List?>(
          context,
          MaterialPageRoute(
            builder: (_) => PhotoCropScreen(
              imageBytes: bytes,
              title: 'CROP SAMPLE FLASH',
            ),
          ),
        );

        if (croppedBytes != null && context.mounted) {
          Navigator.pop(context, ProfilePhotoResult.cropped(croppedBytes));
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load sample photo: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveGlassContainer.bottomSheet(
      glassEnabled: false,
      androidSurfaceColor: AppTheme.onyxContainer,
      selectedBorderColor: AppTheme.goldBorder,
      unselectedBorderColor: AppTheme.goldBorder,
      selectedBorderWidth: 0.8,
      unselectedBorderWidth: 0.8,
      topRadius: 24.0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Grab handle
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4D5252),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Title and Subtitle
              Text(
                'Profile Photo',
                key: const Key('photo_source_sheet_title'),
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Select or capture an image to represent your profile',
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.navInactive,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 20),

              // Option: Take Photo
              _buildOptionCard(
                key: const Key('photo_source_camera'),
                icon: Icons.camera_alt_outlined,
                iconColor: AppTheme.gold,
                title: 'Take Photo',
                subtitle: 'Capture a new selfie or image using your camera',
                onTap: () => _pickAndCrop(context, ImageSource.camera),
              ),
              const SizedBox(height: 10),

              // Option: Choose from Library
              _buildOptionCard(
                key: const Key('photo_source_gallery'),
                icon: Icons.photo_library_outlined,
                iconColor: AppTheme.gold,
                title: 'Choose from Library',
                subtitle: 'Browse your camera roll and saved photos',
                onTap: () => _pickAndCrop(context, ImageSource.gallery),
              ),
              const SizedBox(height: 10),

              // Option: Sample Flash Art (Dev)
              _buildOptionCard(
                key: const Key('photo_source_sample'),
                icon: Icons.auto_awesome,
                iconColor: const Color(0xFFE5A93C),
                title: 'Use Sample Flash (Dev)',
                subtitle: 'Load traditional moth flash artwork for testing',
                onTap: () => _useSamplePhoto(context),
              ),

              // Option: Remove Photo (if existing)
              if (hasExistingPhoto) ...[
                const SizedBox(height: 10),
                _buildOptionCard(
                  key: const Key('photo_source_remove'),
                  icon: Icons.delete_outline_rounded,
                  iconColor: const Color(0xFFEF4444),
                  title: 'Remove Photo',
                  subtitle: 'Revert to default gold & charcoal silhouette avatar',
                  borderColor: const Color(0x33EF4444),
                  backgroundColor: const Color(0x14EF4444),
                  onTap: () {
                    Navigator.pop(context, const ProfilePhotoResult.removed());
                  },
                ),
              ],

              const SizedBox(height: 12),
            ],
          ),
        ),
    );
  }

  Widget _buildOptionCard({
    required Key key,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? borderColor,
    Color? backgroundColor,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: key,
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: backgroundColor ?? const Color(0xFF141616),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: borderColor ?? AppTheme.darkBorder,
              width: 1.0,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconColor.withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.navInactive,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF4D5252),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
