import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../models/artist.dart';
import '../../models/studio_information.dart';
import '../../services/auth_service.dart';
import '../../theme/app_buttons.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/adaptive_glass_container.dart';
import '../../widgets/fade_page_route.dart';
import '../../widgets/flash_switch.dart';
import '../../widgets/flow_page_layout.dart';
import '../../widgets/photo_crop_screen.dart';
import '../../widgets/tattoo_background_wrapper.dart';
import '../../features/onboarding/shared/onboarding_step_scaffold.dart';
import 'artist_identity_tags_screen.dart';

class UploadedFlashItem {
  final String id;
  final String title;
  final int price;
  final String size;
  final String styleTag;
  final bool isRepeatable;
  final Uint8List? imageBytes;
  final String? assetPath;

  UploadedFlashItem({
    required this.id,
    required this.title,
    required this.price,
    required this.size,
    required this.styleTag,
    required this.isRepeatable,
    this.imageBytes,
    this.assetPath,
  });
}

class ArtistFlashUploadScreen extends StatefulWidget {
  final String artistName;
  final Uint8List? photoBytes;
  final String? photoUrl;
  final String instagramHandle;
  final int minDeposit;
  final AuthService? authService;
  final StudioInformation? studioInformation;
  final String? artistBio;
  final List<StudioPolicy>? policies;

  const ArtistFlashUploadScreen({
    super.key,
    required this.artistName,
    this.photoBytes,
    this.photoUrl,
    required this.instagramHandle,
    required this.minDeposit,
    this.authService,
    this.studioInformation,
    this.artistBio,
    this.policies,
  });

  @override
  State<ArtistFlashUploadScreen> createState() => _ArtistFlashUploadScreenState();
}

class _ArtistFlashUploadScreenState extends State<ArtistFlashUploadScreen> {
  final List<UploadedFlashItem> _uploadedItems = [];

  // Active item in detail editor
  Uint8List? _activeImageBytes;
  Uint8List? _activeRawImageBytes;
  String? _activeAssetPath;
  bool _isEditingDetails = false;
  int? _editingItemIndex;

  final TextEditingController _titleController = TextEditingController(text: 'Traditional Panther');
  final TextEditingController _priceController = TextEditingController(text: '150');
  final TextEditingController _sizeController = TextEditingController(text: '4x4');
  String _selectedStyle = 'TRADITIONAL';
  bool _isRepeatable = true;

  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _sizeController.dispose();
    super.dispose();
  }

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

  Future<void> _cropCurrentActivePhoto() async {
    Uint8List? sourceBytes = _activeRawImageBytes ?? _activeImageBytes;
    if (sourceBytes == null && _activeAssetPath != null) {
      try {
        final byteData = await rootBundle.load(_activeAssetPath!);
        sourceBytes = byteData.buffer.asUint8List();
        _activeRawImageBytes = sourceBytes;
      } catch (_) {}
    }
    if (sourceBytes == null) return;

    final cropped = await _openCropScreen(sourceBytes);
    if (cropped != null && mounted) {
      setState(() {
        _activeImageBytes = cropped;
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
        _activeRawImageBytes = bytes;
        if (!mounted) return;
        final cropped = await _openCropScreen(bytes);
        if (mounted) {
          setState(() {
            _activeImageBytes = cropped ?? bytes;
            _activeAssetPath = null;
            _isEditingDetails = true;
          });
        }
      }
    } catch (_) {
      _useSampleFlash('assets/images/flash_traditional_panther.jpg');
    }
  }

  void _useSampleFlash(String assetPath) async {
    try {
      final byteData = await rootBundle.load(assetPath);
      final bytes = byteData.buffer.asUint8List();
      setState(() {
        _activeRawImageBytes = bytes;
        _activeImageBytes = bytes;
        _activeAssetPath = assetPath;
        _isEditingDetails = true;
      });
    } catch (_) {
      setState(() {
        _activeAssetPath = assetPath;
        _isEditingDetails = true;
      });
    }
  }

  void _showEditPhotoOptions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return AdaptiveGlassContainer.bottomSheet(
          glassEnabled: false,
          androidSurfaceColor: const Color(0xFF1E2121),
          topRadius: AppRadius.radiusSheet,
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Edit Flash Photo',
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
                          subtitle: Text(
                            'Zoom and pan to choose the displayed portion',
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFF919696),
                              fontSize: 12,
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(bottomSheetContext);
                            _cropCurrentActivePhoto();
                          },
                        ),
                        ListTile(
                          key: const Key('photo_option_gallery'),
                          leading: const Icon(Icons.photo_library, color: Color(0xFFEEC200)),
                          title: Text(
                            'Choose Different Photo from Gallery',
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
                            'Use Sample Flash: Traditional Panther',
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

  void _showImageSourcePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return AdaptiveGlassContainer.bottomSheet(
          glassEnabled: false,
          androidSurfaceColor: const Color(0xFF1E2121),
          topRadius: AppRadius.radiusSheet,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Upload Flash Artwork',
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
                      if (_activeImageBytes != null || _activeAssetPath != null)
                        ListTile(
                          key: const Key('photo_source_crop'),
                          leading: const Icon(Icons.crop, color: Color(0xFFEEC200)),
                          title: Text(
                            'Resize & Crop Current Photo',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(bottomSheetContext);
                            _cropCurrentActivePhoto();
                          },
                        ),
                      ListTile(
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
                        leading: const Icon(Icons.camera_alt, color: Color(0xFFEEC200)),
                        title: Text(
                          'Take a Photo',
                          style: GoogleFonts.plusJakartaSans(color: Colors.white),
                        ),
                        onTap: () {
                          Navigator.pop(bottomSheetContext);
                          _pickImage(ImageSource.camera);
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.auto_awesome, color: Color(0xFFEEC200)),
                        title: Text(
                          'Use Sample Flash: Traditional Panther',
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
        );
      },
    );
  }

  void _saveCurrentItem({bool addAnother = false}) {
    final title = _titleController.text.trim().isNotEmpty
        ? _titleController.text.trim()
        : 'Flash Artwork';
    final price = int.tryParse(_priceController.text.trim()) ?? 150;
    final size = _sizeController.text.trim().isNotEmpty ? _sizeController.text.trim() : '4x4';

    final newItem = UploadedFlashItem(
      id: (_editingItemIndex != null && _editingItemIndex! < _uploadedItems.length)
          ? _uploadedItems[_editingItemIndex!].id
          : 'flash_${DateTime.now().millisecondsSinceEpoch}_${_uploadedItems.length}',
      title: title,
      price: price,
      size: size,
      styleTag: _selectedStyle,
      isRepeatable: _isRepeatable,
      imageBytes: _activeImageBytes,
      assetPath: _activeAssetPath,
    );

    setState(() {
      if (_editingItemIndex != null && _editingItemIndex! < _uploadedItems.length) {
        _uploadedItems[_editingItemIndex!] = newItem;
        _editingItemIndex = null;
      } else {
        _uploadedItems.add(newItem);
      }
      _activeImageBytes = null;
      _activeRawImageBytes = null;
      _activeAssetPath = null;
      _isEditingDetails = false;
    });

    if (addAnother) {
      _showImageSourcePicker();
    }
  }

  void _onDonePressed() {
    _proceedToIdentityTags();
  }

  Future<void> _proceedToIdentityTags() async {
    final effectiveAuth = widget.authService ?? AuthService();
    final user = effectiveAuth.currentUser ?? FirebaseAuth.instance.currentUser;

    // Convert uploaded items to FlashArtwork list, uploading any picked images if online
    final flashArtworks = <FlashArtwork>[];
    for (final item in _uploadedItems) {
      String imageUrl = item.assetPath ?? 'assets/images/flash_traditional_panther.jpg';

      if (user != null && item.imageBytes != null) {
        try {
          final storageRef = FirebaseStorage.instance
              .ref()
              .child('artists')
              .child(user.uid)
              .child('flash')
              .child('${item.id}.jpg');
          await storageRef
              .putData(item.imageBytes!, SettableMetadata(contentType: 'image/jpeg'))
              .timeout(const Duration(seconds: 5));
          imageUrl = await storageRef.getDownloadURL().timeout(const Duration(seconds: 3));
        } catch (_) {
          // Graceful fallback if offline or in tests
        }
      }

      flashArtworks.add(
        FlashArtwork(
          id: item.id,
          artistName: widget.artistName,
          title: item.title,
          imageUrl: imageUrl,
          price: item.price,
          deposit: widget.minDeposit,
          dimensions: item.size,
          status: item.isRepeatable ? FlashStatus.repeatable : FlashStatus.available,
          category: item.styleTag,
          isExclusive: !item.isRepeatable,
        ),
      );
    }

    if (!mounted) return;

    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.push(
      context,
      FadePageRoute(
        builder: (_) => ArtistIdentityTagsScreen(
          artistName: widget.artistName,
          photoBytes: widget.photoBytes,
          photoUrl: widget.photoUrl,
          instagramHandle: widget.instagramHandle,
          minDeposit: widget.minDeposit,
          flashArtworks: flashArtworks,
          authService: widget.authService,
          studioInformation: widget.studioInformation,
          artistBio: widget.artistBio,
          policies: widget.policies,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingStepScaffold(
      currentStep: 6,
      totalSteps: 9,
      showCta: !_isEditingDetails,
      onBack: _isEditingDetails
          ? () {
              FocusManager.instance.primaryFocus?.unfocus();
              setState(() {
                _isEditingDetails = false;
                _activeImageBytes = null;
                _activeAssetPath = null;
              });
            }
          : (Navigator.canPop(context)
              ? () {
                  FocusManager.instance.primaryFocus?.unfocus();
                  Navigator.pop(context);
                }
              : null),
      onSkip: _proceedToIdentityTags,
      skipKey: const Key('skip_flash_button'),
      skipText: 'Skip',
      title: 'Showcase your\nwork',
      subtitle: 'Upload some custom flash work you plan on selling',
      ctaText: 'DONE',
      ctaKey: const Key('done_flash_button'),
      isCtaEnabled: _uploadedItems.isNotEmpty,
      onCtaPressed: _uploadedItems.isNotEmpty ? _onDonePressed : null,
      contentPadding: EdgeInsets.zero,
      backgroundOverlay: const TattooBackgroundWrapper(child: SizedBox.expand()),
      child: FlowPageLayout(
        title: 'Showcase your\nwork',
        subtitle: 'Upload some custom flash work you plan on selling',
        ctaText: 'DONE',
        ctaKey: const Key('done_flash_button'),
        onCtaPressed: _uploadedItems.isNotEmpty ? _onDonePressed : null,
        renderInternalHeaderAndCTA: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isEditingDetails) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenGutter),
                child: _buildItemDetailsCard(),
              ),
              const SizedBox(height: AppSpacing.spaceLg),
            ] else ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenGutter),
                child: _buildUploadBox(),
              ),
              if (_uploadedItems.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.spaceLg),
                _buildUploadedItemsGallery(),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUploadBox() {
    return SizedBox(
      width: double.infinity,
      child: InkWell(
        key: const Key('upload_flash_trigger'),
        onTap: _showImageSourcePicker,
        borderRadius: BorderRadius.circular(AppRadius.radiusLg),
        child: AdaptiveGlassContainer(
          width: double.infinity,
          useGradient: false,
          borderRadius: AppRadius.radiusLg,
          padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF242727),
                  border: Border.all(color: const Color(0xFF333636)),
                ),
                child: const Icon(
                  Icons.file_upload_outlined,
                  size: 24,
                  color: Color(0xFFEEC200),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'High-resolution JPEG or PNG.\nMax 10MB.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: const Color(0xFF919696),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemDetailsCard() {
    final styleOptions = ['TRADITIONAL', 'BLACKWORK', 'NEO-TRAD', 'JAPANESE', '+ CUSTOM'];

    return AdaptiveGlassContainer(
      useGradient: false,
      borderRadius: 16,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              'Upload Flash: Item Details',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF919696),
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Flash Image Preview with Edit & Crop Controls
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.radiusMd),
                child: InkWell(
                  key: const Key('flash_image_preview_tap'),
                  onTap: _cropCurrentActivePhoto,
                  child: Container(
                    width: double.infinity,
                    height: 220,
                    color: const Color(0xFF2E3232),
                    child: _activeImageBytes != null
                        ? Image.memory(_activeImageBytes!, fit: BoxFit.cover)
                        : (_activeAssetPath != null
                            ? Image.asset(_activeAssetPath!, fit: BoxFit.cover)
                            : const Icon(Icons.image, size: 60, color: Color(0xFF6B7280))),
                  ),
                ),
              ),
              Positioned(
                bottom: 8,
                left: 8,
                child: InkWell(
                  key: const Key('crop_flash_image_button'),
                  onTap: _cropCurrentActivePhoto,
                  borderRadius: BorderRadius.circular(AppRadius.radiusFull),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xCC121414),
                      borderRadius: BorderRadius.circular(AppRadius.radiusFull),
                      border: Border.all(color: const Color(0xFF333636)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.crop, size: 14, color: Color(0xFFEEC200)),
                        const SizedBox(width: 5),
                        Text(
                          'Resize & Crop',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 8,
                right: 8,
                child: InkWell(
                  key: const Key('edit_flash_image_button'),
                  onTap: _showEditPhotoOptions,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Color(0xCC121414),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.edit, size: 16, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // TITLE
          Text(
            'TITLE',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF8C9191),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            key: const Key('flash_title_field'),
            controller: _titleController,
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            scrollPadding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
            ),
            style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 14),
            decoration: _fieldDecoration('Traditional Panther'),
          ),
          const SizedBox(height: 14),

          // PRICE & SIZE
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PRICE (\$)',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF8C9191),
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      key: const Key('flash_price_field'),
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                      onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                      scrollPadding: EdgeInsets.only(
                        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
                      ),
                      style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 14),
                      decoration: _fieldDecoration('150', prefix: '\$ '),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SIZE (IN)',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF8C9191),
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      key: const Key('flash_size_field'),
                      controller: _sizeController,
                      keyboardType: TextInputType.text,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                      onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                      scrollPadding: EdgeInsets.only(
                        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
                      ),
                      style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 14),
                      decoration: _fieldDecoration('4x4'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // STYLE TAG
          Text(
            'STYLE TAG',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF8C9191),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: styleOptions.map((style) {
              final isSelected = _selectedStyle == style;
              return InkWell(
                onTap: () {
                  setState(() => _selectedStyle = style);
                },
                borderRadius: BorderRadius.circular(AppRadius.radiusSm),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFEEC200) : const Color(0xFF262929),
                    borderRadius: BorderRadius.circular(AppRadius.radiusSm),
                    border: Border.all(
                      color: isSelected ? const Color(0xFFEEC200) : const Color(0xFF333636),
                    ),
                  ),
                  child: Text(
                    style,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? const Color(0xFF121414) : const Color(0xFF919696),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // REPEATABLE FLASH
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'REPEATABLE FLASH',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFF9FAFA),
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    'Can this be tattooed multiple times?',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: const Color(0xFF8C9191),
                    ),
                  ),
                ],
              ),
              FlashSwitch(
                key: const Key('repeatable_switch'),
                value: _isRepeatable,
                onChanged: (val) {
                  setState(() => _isRepeatable = val);
                },
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Action Button: DONE (saves item and returns to flash upload screen)
          AppButtons.primaryCTA(
            key: const Key('done_details_button'),
            onPressed: () => _saveCurrentItem(addAnother: false),
            text: 'DONE',
            backgroundColor: const Color(0xFFEEC200),
            foregroundColor: const Color(0xFF121414),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadedItemsGallery() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenGutter),
          child: Text(
            'UPLOADED FLASH (${_uploadedItems.length})',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF8C9191),
              letterSpacing: 0.8,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 130,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenGutter),
            scrollDirection: Axis.horizontal,
            itemCount: _uploadedItems.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final item = _uploadedItems[index];
              return InkWell(
                key: Key('uploaded_flash_item_$index'),
                onTap: () {
                  setState(() {
                    _editingItemIndex = index;
                    _activeImageBytes = item.imageBytes;
                    _activeRawImageBytes = item.imageBytes;
                    _activeAssetPath = item.assetPath;
                    _titleController.text = item.title;
                    _priceController.text = item.price.toString();
                    _sizeController.text = item.size;
                    _selectedStyle = item.styleTag;
                    _isRepeatable = item.isRepeatable;
                    _isEditingDetails = true;
                  });
                },
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 110,
                  child: AdaptiveGlassContainer(
                    useGradient: false,
                    borderRadius: 12,
                    padding: EdgeInsets.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.radiusMd - 1)),
                            child: item.imageBytes != null
                                ? Image.memory(item.imageBytes!, fit: BoxFit.cover, width: double.infinity)
                                : (item.assetPath != null
                                    ? Image.asset(item.assetPath!, fit: BoxFit.cover, width: double.infinity)
                                    : Container(color: const Color(0xFF2E3232))),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                '\$${item.price}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFFEEC200),
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
            },
          ),
        ),
      ],
    );
  }

  InputDecoration _fieldDecoration(String hint, {String? prefix}) {
    return InputDecoration(
      filled: true,
      fillColor: const Color(0xFF232626),
      hintText: hint,
      prefixText: prefix,
      prefixStyle: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 14),
      hintStyle: GoogleFonts.plusJakartaSans(color: const Color(0xFF636767)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.radiusSm),
        borderSide: const BorderSide(color: Color(0xFF2E3232)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.radiusSm),
        borderSide: const BorderSide(color: Color(0xFF2E3232)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.radiusSm),
        borderSide: const BorderSide(color: Color(0xFFEEC200), width: 1.5),
      ),
    );
  }
}
