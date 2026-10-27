import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_radius.dart';
import '../theme/app_theme.dart';
import 'adaptive_glass_container.dart';
import 'flash_snack_bar.dart';
import 'photo_crop_screen.dart';

enum _PhotoSourceAction {
  camera,
  gallery,
  sample,
  remove,
}

/// The result returned after a user picks/crops a photo or chooses to remove it.
class ProfilePhotoResult {
  final Uint8List? croppedBytes;
  final bool isRemoved;

  const ProfilePhotoResult.cropped(this.croppedBytes) : isRemoved = false;
  const ProfilePhotoResult.removed() : croppedBytes = null, isRemoved = true;
}

/// Modern bottom sheet for selecting, cropping, or removing profile photos.
/// Adapts to device-specific controls: CupertinoActionSheet on iOS,
/// and dark-onyx bottom sheet on Android/other platforms.
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

    if (Theme.of(context).platform == TargetPlatform.iOS) {
      return _showCupertinoActionSheet(
        context: context,
        picker: effectivePicker,
        hasExistingPhoto: hasExistingPhoto,
      );
    }

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

  static Future<ProfilePhotoResult?> _showCupertinoActionSheet({
    required BuildContext context,
    required ImagePicker picker,
    bool hasExistingPhoto = false,
  }) async {
    final choice = await showCupertinoModalPopup<_PhotoSourceAction>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: const Text('Profile Photo'),
        message: const Text('Select or capture an image to represent your profile'),
        actions: [
          CupertinoActionSheetAction(
            key: const Key('photo_source_camera'),
            onPressed: () => Navigator.pop(sheetContext, _PhotoSourceAction.camera),
            child: const Text('Take a Picture'),
          ),
          CupertinoActionSheetAction(
            key: const Key('photo_source_gallery'),
            onPressed: () => Navigator.pop(sheetContext, _PhotoSourceAction.gallery),
            child: const Text('Upload a Photo'),
          ),
          if (hasExistingPhoto)
            CupertinoActionSheetAction(
              key: const Key('photo_source_remove'),
              isDestructiveAction: true,
              onPressed: () => Navigator.pop(sheetContext, _PhotoSourceAction.remove),
              child: const Text('Remove Photo'),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(sheetContext),
          child: const Text('Cancel'),
        ),
      ),
    );

    if (choice == null || !context.mounted) return null;

    switch (choice) {
      case _PhotoSourceAction.camera:
        return _pickAndCropStatic(context, picker, ImageSource.camera);
      case _PhotoSourceAction.gallery:
        return _pickAndCropStatic(context, picker, ImageSource.gallery);
      case _PhotoSourceAction.remove:
        return const ProfilePhotoResult.removed();
      case _PhotoSourceAction.sample:
        return _useSamplePhotoStatic(context);
    }
  }

  static Future<ProfilePhotoResult?> _pickAndCropStatic(
    BuildContext context,
    ImagePicker picker,
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
        if (!context.mounted) return null;
        final croppedBytes = await Navigator.push<Uint8List?>(
          context,
          MaterialPageRoute(
            builder: (_) => PhotoCropScreen(imageBytes: bytes),
          ),
        );

        if (croppedBytes != null) {
          return ProfilePhotoResult.cropped(croppedBytes);
        }
      }
    } catch (e) {
      if (context.mounted) {
        FlashSnackBar.showError(context, 'Failed to select photo: $e');
      }
    }
    return null;
  }

  static Future<ProfilePhotoResult?> _useSamplePhotoStatic(BuildContext context) async {
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

        if (croppedBytes != null) {
          return ProfilePhotoResult.cropped(croppedBytes);
        }
      }
    } catch (e) {
      if (context.mounted) {
        FlashSnackBar.showError(context, 'Failed to load sample photo: $e');
      }
    }
    return null;
  }

  Future<void> _pickAndCrop(
    BuildContext context,
    ImageSource source,
  ) async {
    final result = await _pickAndCropStatic(context, picker, source);
    if (result != null && context.mounted) {
      Navigator.pop(context, result);
    }
  }

  Future<void> _useSamplePhoto(BuildContext context) async {
    final result = await _useSamplePhotoStatic(context);
    if (result != null && context.mounted) {
      Navigator.pop(context, result);
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
      topRadius: AppRadius.radiusSheet,
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
                    borderRadius: BorderRadius.circular(AppRadius.dragHandle),
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
        borderRadius: BorderRadius.circular(AppRadius.radiusMd),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: backgroundColor ?? const Color(0xFF141616),
            borderRadius: BorderRadius.circular(AppRadius.radiusMd),
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
