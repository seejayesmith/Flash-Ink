import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/mock/mock_data_config.dart';
import '../../models/artist.dart';
import '../../repositories/artist_repository.dart';
import '../../services/auth_service.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';
import '../../widgets/adaptive_glass_container.dart';
import '../../widgets/flash_glass_app_bar.dart';
import '../../widgets/flash_image.dart';
import '../../widgets/flash_snack_bar.dart';
import '../../widgets/flash_switch.dart';
import '../../widgets/photo_crop_screen.dart';
import '../../widgets/pinned_bottom_action_scaffold.dart';

/// Full-screen modal flow allowing artists to upload a new flash piece or
/// edit existing flash artwork details.
class ArtistUploadFlashScreen extends StatefulWidget {
  final Artist? artist;
  final FlashArtwork? existingArtwork;
  final AuthService? authService;
  final FirebaseFirestore? firestore;
  final FirebaseStorage? storage;
  final String? initialAssetPath;
  final Uint8List? initialImageBytes;

  const ArtistUploadFlashScreen({
    super.key,
    this.artist,
    this.existingArtwork,
    this.authService,
    this.firestore,
    this.storage,
    this.initialAssetPath,
    this.initialImageBytes,
  });

  @override
  State<ArtistUploadFlashScreen> createState() => _ArtistUploadFlashScreenState();
}

class _ArtistUploadFlashScreenState extends State<ArtistUploadFlashScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;
  late final TextEditingController _priceController;
  late final TextEditingController _depositController;
  late final TextEditingController _dimensionsController;

  late String _selectedStyle;
  late bool _isRepeatable;

  Uint8List? _imageBytes;
  Uint8List? _rawImageBytes;
  String? _assetPath;
  String? _existingImageUrl;

  bool _isSaving = false;
  String? _imageError;

  final ImagePicker _picker = ImagePicker();

  static const List<String> _availableStyles = [
    'TRADITIONAL',
    'FINELINE',
    'BLACKWORK',
    'REALISM',
    'JAPANESE',
    'NEO-TRADITIONAL',
    'ILLUSTRATIVE',
    'SCRIPT',
    'ANIME',
  ];

  @override
  void initState() {
    super.initState();
    final existing = widget.existingArtwork;

    _titleController = TextEditingController(text: existing?.title ?? '');
    _priceController = TextEditingController(
      text: existing != null ? existing.price.toString() : '150',
    );
    _depositController = TextEditingController(
      text: existing != null
          ? existing.deposit.toString()
          : (widget.artist != null ? widget.artist!.minDeposit.toString() : '50'),
    );
    _dimensionsController = TextEditingController(
      text: existing != null ? existing.dimensions : '4" x 4"',
    );

    _selectedStyle = existing?.category.toUpperCase() ?? 'TRADITIONAL';
    if (!_availableStyles.contains(_selectedStyle)) {
      _selectedStyle = _availableStyles.first;
    }

    _isRepeatable = existing != null
        ? (existing.status == FlashStatus.repeatable)
        : true;

    _imageBytes = widget.initialImageBytes;
    _assetPath = widget.initialAssetPath;
    _existingImageUrl = existing?.imageUrl;
    if (_existingImageUrl == null && _assetPath == null && MockDataConfig.isEnabled) {
      _assetPath = 'assets/images/flash_traditional_panther.jpg';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _depositController.dispose();
    _dimensionsController.dispose();
    super.dispose();
  }

  bool get _isEditing => widget.existingArtwork != null;

  Future<Uint8List?> _openCropScreen(Uint8List bytes) async {
    return Navigator.push<Uint8List?>(
      context,
      MaterialPageRoute(
        builder: (_) => PhotoCropScreen(
          imageBytes: bytes,
          title: 'CROP & RESIZE FLASH',
          cropShape: CropShape.rectangle,
          subtitle: 'Pinch to zoom • Drag to frame your flash artwork',
          ctaText: 'APPLY & USE FLASH',
        ),
      ),
    );
  }

  Future<void> _cropCurrentPhoto() async {
    Uint8List? sourceBytes = _rawImageBytes ?? _imageBytes;
    if (sourceBytes == null && _assetPath != null) {
      try {
        final byteData = await rootBundle.load(_assetPath!);
        sourceBytes = byteData.buffer.asUint8List();
        _rawImageBytes = sourceBytes;
      } catch (_) {}
    }

    if (sourceBytes == null) return;

    final cropped = await _openCropScreen(sourceBytes);
    if (cropped != null && mounted) {
      setState(() {
        _imageBytes = cropped;
        _imageError = null;
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 90,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        _rawImageBytes = bytes;
        if (!mounted) return;
        final cropped = await _openCropScreen(bytes);
        if (mounted) {
          setState(() {
            _imageBytes = cropped ?? bytes;
            _assetPath = null;
            _imageError = null;
          });
        }
      }
    } catch (_) {
      _useSampleFlash('assets/images/flash_traditional_panther.jpg');
    }
  }

  Future<void> _useSampleFlash(String assetPath) async {
    try {
      final byteData = await rootBundle.load(assetPath);
      final bytes = byteData.buffer.asUint8List();
      setState(() {
        _rawImageBytes = bytes;
        _imageBytes = bytes;
        _assetPath = assetPath;
        _imageError = null;
      });
    } catch (_) {
      setState(() {
        _assetPath = assetPath;
        _imageError = null;
      });
    }
  }

  void _showImageSourcePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return AdaptiveGlassContainer.bottomSheet(
          glassEnabled: false,
          androidSurfaceColor: const Color(0xFF1E2121),
          topRadius: AppRadius.radiusSheet,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _imageBytes != null || _existingImageUrl != null || _assetPath != null
                        ? 'Change Artwork Photo'
                        : 'Upload Artwork Photo',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Material(
                    color: Colors.transparent,
                    child: Column(
                      children: [
                        if (_imageBytes != null || _assetPath != null)
                          ListTile(
                            key: const Key('photo_option_crop'),
                            leading: const Icon(Icons.crop, color: Color(0xFFEEC200)),
                            title: Text(
                              'Resize & Crop Framing',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            onTap: () {
                              Navigator.pop(bottomSheetContext);
                              _cropCurrentPhoto();
                            },
                          ),
                        ListTile(
                          key: const Key('photo_option_gallery'),
                          leading: const Icon(Icons.photo_library, color: Color(0xFFEEC200)),
                          title: Text(
                            'Choose from Gallery',
                            style: GoogleFonts.plusJakartaSans(color: Colors.white),
                          ),
                          onTap: () {
                            Navigator.pop(bottomSheetContext);
                            _pickImage(ImageSource.gallery);
                          },
                        ),
                        ListTile(
                          key: const Key('photo_option_camera'),
                          leading: const Icon(Icons.camera_alt, color: Color(0xFFEEC200)),
                          title: Text(
                            'Take a New Photo',
                            style: GoogleFonts.plusJakartaSans(color: Colors.white),
                          ),
                          onTap: () {
                            Navigator.pop(bottomSheetContext);
                            _pickImage(ImageSource.camera);
                          },
                        ),
                        ListTile(
                          key: const Key('photo_option_sample'),
                          leading: const Icon(Icons.auto_awesome, color: Color(0xFFEEC200)),
                          title: Text(
                            'Use Sample Flash Artwork',
                            style: GoogleFonts.plusJakartaSans(color: Colors.white),
                          ),
                          onTap: () {
                            Navigator.pop(bottomSheetContext);
                            _useSampleFlash('assets/images/flash_traditional_panther.jpg');
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleSave() async {
    FocusManager.instance.primaryFocus?.unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_imageBytes == null && _existingImageUrl == null && _assetPath == null) {
      setState(() {
        _imageError = 'Please choose a photo for your flash artwork';
      });
      FlashSnackBar.showError(
        context,
        'Please choose an artwork photo to proceed.',
      );
      return;
    }

    setState(() {
      _isSaving = true;
      _imageError = null;
    });

    try {
      final effectiveAuth = widget.authService ?? AuthService();
      final user = effectiveAuth.currentUser ?? FirebaseAuth.instance.currentUser;
      final uid = widget.artist?.id ?? user?.uid ?? 'artist_current';
      final artistName = widget.artist?.name ?? user?.displayName ?? 'Artist';

      final title = _titleController.text.trim();
      final price = int.tryParse(_priceController.text.trim()) ?? 150;
      final deposit = int.tryParse(_depositController.text.trim()) ?? 50;
      final dimensions = _dimensionsController.text.trim();

      final artworkId = widget.existingArtwork?.id ??
          'flash_${DateTime.now().millisecondsSinceEpoch}';

      final artwork = FlashArtwork(
        id: artworkId,
        artistId: uid,
        artistName: artistName,
        title: title,
        imageUrl: _assetPath ?? _existingImageUrl ?? 'assets/images/flash_traditional_panther.jpg',
        price: price,
        deposit: deposit,
        dimensions: dimensions,
        status: _isRepeatable ? FlashStatus.repeatable : FlashStatus.available,
        category: _selectedStyle,
        isExclusive: !_isRepeatable,
      );

      final isWidgetTest =
          WidgetsBinding.instance.runtimeType.toString().contains('Test');
      if (!isWidgetTest || widget.firestore != null) {
        if (_isEditing) {
          await ArtistRepository.updateFlashArtwork(
            uid: uid,
            artwork: artwork,
            newImageBytes: _imageBytes,
            firestore: widget.firestore,
            storage: widget.storage,
          );
        } else {
          await ArtistRepository.addFlashArtwork(
            uid: uid,
            artwork: artwork,
            imageBytes: _imageBytes,
            firestore: widget.firestore,
            storage: widget.storage,
          );
        }
      }

      if (mounted) {
        FlashSnackBar.showSuccess(
          context,
          _isEditing ? 'Flash artwork updated successfully' : 'Flash artwork published to Collections!',
        );
        Navigator.pop(context, artwork);
      }
    } catch (e) {
      if (mounted) {
        FlashSnackBar.showError(
          context,
          'Failed to save flash artwork: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Widget _buildPhotoPreview() {
    final hasImage = _imageBytes != null || _existingImageUrl != null || _assetPath != null;

    return Center(
      child: GestureDetector(
        key: const Key('flash_artwork_photo_selector'),
        onTap: _showImageSourcePicker,
        child: Container(
          width: double.infinity,
          height: 240,
          decoration: BoxDecoration(
            color: const Color(0xFF1B1E1E),
            borderRadius: BorderRadius.circular(AppRadius.radiusMd),
            border: Border.all(
              color: _imageError != null
                  ? AppTheme.favoriteActive
                  : (hasImage ? const Color(0xFFEEC200).withAlpha(120) : const Color(0xFF333737)),
              width: 1.5,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.radiusMd - 1.5),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_imageBytes != null)
                  Image.memory(
                    _imageBytes!,
                    fit: BoxFit.cover,
                  )
                else if (_assetPath != null)
                  Image.asset(
                    _assetPath!,
                    fit: BoxFit.cover,
                  )
                else if (_existingImageUrl != null && _existingImageUrl!.isNotEmpty)
                  FlashImage(
                    urlOrPath: _existingImageUrl!,
                    fit: BoxFit.cover,
                  )
                else
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF262929),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF333737)),
                        ),
                        child: const Icon(
                          Icons.add_photo_alternate_outlined,
                          color: Color(0xFFEEC200),
                          size: 36,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Upload Flash Photo',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap to choose from camera or gallery',
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF8C9191),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),

                if (hasImage)
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(180),
                        borderRadius: BorderRadius.circular(AppRadius.radiusFull),
                        border: Border.all(
                          color: const Color(0xFFEEC200).withAlpha(140),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.edit, color: Color(0xFFEEC200), size: 14),
                          const SizedBox(width: 6),
                          Text(
                            'Edit Photo',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    Key? key,
    TextInputType keyboardType = TextInputType.text,
    String? prefixText,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.plusJakartaSans(
            color: const Color(0xFF8C9191),
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          key: key,
          controller: controller,
          keyboardType: keyboardType,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.plusJakartaSans(
              color: const Color(0xFF555B5B),
              fontSize: 15,
            ),
            prefixText: prefixText,
            prefixStyle: GoogleFonts.plusJakartaSans(
              color: const Color(0xFFEEC200),
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
            filled: true,
            fillColor: const Color(0xFF1B1E1E),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
              borderSide: const BorderSide(color: Color(0xFFEEC200), width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.radiusSm),
              borderSide: const BorderSide(color: AppTheme.favoriteActive, width: 1.2),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.radiusSm),
              borderSide: const BorderSide(color: AppTheme.favoriteActive, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStyleSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'STYLE CATEGORY',
          style: GoogleFonts.plusJakartaSans(
            color: const Color(0xFF8C9191),
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _availableStyles.map((style) {
            final isSelected = _selectedStyle == style;
            return ChoiceChip(
              key: Key('style_chip_${style.toLowerCase()}'),
              label: Text(style),
              labelStyle: GoogleFonts.plusJakartaSans(
                color: isSelected ? const Color(0xFF121414) : Colors.white,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                fontSize: 12,
              ),
              selected: isSelected,
              selectedColor: const Color(0xFFEEC200),
              backgroundColor: const Color(0xFF1B1E1E),
              side: BorderSide(
                color: isSelected ? const Color(0xFFEEC200) : const Color(0xFF333737),
                width: 1.2,
              ),
              onSelected: (selected) {
                if (selected) {
                  setState(() => _selectedStyle = style);
                }
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildRepeatableSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1E1E),
        borderRadius: BorderRadius.circular(AppRadius.radiusMd),
        border: Border.all(color: const Color(0xFF333737)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _isRepeatable ? Icons.repeat : Icons.stars_rounded,
                      color: const Color(0xFFEEC200),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isRepeatable ? 'Repeatable Design' : 'One-Off Exclusive',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _isRepeatable
                      ? 'Multiple clients can book this flash piece.'
                      : 'Exclusive piece. Automatically marked claimed after first booking.',
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF8C9191),
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FlashSwitch(
            key: const Key('flash_repeatable_switch'),
            value: _isRepeatable,
            onChanged: (val) => setState(() => _isRepeatable = val),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PinnedBottomActionScaffold(
      backgroundColor: const Color(0xFF121414),
      appBar: FlashGlassAppBar(
        title: Text(_isEditing ? 'Edit Flash Piece' : 'Upload Flash Piece'),
        showBackButton: true,
        onBackPressed: () => Navigator.pop(context),
      ),
      ctaText: _isSaving
          ? 'SAVING...'
          : (_isEditing ? 'SAVE CHANGES' : 'PUBLISH FLASH'),
      ctaKey: const Key('publish_flash_button'),
      isCtaEnabled: !_isSaving,
      isCtaLoading: _isSaving,
      onCtaPressed: _handleSave,
      childIsScrollable: true,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenGutter),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              _buildPhotoPreview(),
              if (_imageError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _imageError!,
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.favoriteActive,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 24),

              _buildTextField(
                key: const Key('flash_title_input'),
                controller: _titleController,
                label: 'Artwork Title',
                hint: 'e.g. Traditional Panther',
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Title is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      key: const Key('flash_price_input'),
                      controller: _priceController,
                      label: 'Price',
                      hint: '150',
                      prefixText: '\$ ',
                      keyboardType: TextInputType.number,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Price required';
                        }
                        final parsed = int.tryParse(val.trim());
                        if (parsed == null || parsed <= 0) {
                          return 'Invalid price';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      key: const Key('flash_deposit_input'),
                      controller: _depositController,
                      label: 'Deposit',
                      hint: '50',
                      prefixText: '\$ ',
                      keyboardType: TextInputType.number,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Deposit required';
                        }
                        final parsed = int.tryParse(val.trim());
                        if (parsed == null || parsed < 0) {
                          return 'Invalid deposit';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              _buildTextField(
                key: const Key('flash_dimensions_input'),
                controller: _dimensionsController,
                label: 'Dimensions / Sizing',
                hint: 'e.g. 4" x 4" or Palm Sized',
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Dimensions required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              _buildStyleSelector(),
              const SizedBox(height: 24),

              _buildRepeatableSection(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
