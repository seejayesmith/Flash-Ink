import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/dev_config.dart';
import '../../models/artist.dart';
import '../../services/auth_service.dart';
import '../../widgets/adaptive_glass_container.dart';
import '../../widgets/artist_stepper_header.dart';
import '../../widgets/tattoo_background_wrapper.dart';
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

  const ArtistFlashUploadScreen({
    super.key,
    required this.artistName,
    this.photoBytes,
    this.photoUrl,
    required this.instagramHandle,
    required this.minDeposit,
    this.authService,
  });

  @override
  State<ArtistFlashUploadScreen> createState() => _ArtistFlashUploadScreenState();
}

class _ArtistFlashUploadScreenState extends State<ArtistFlashUploadScreen> {
  final List<UploadedFlashItem> _uploadedItems = [];

  // Active item in detail editor
  Uint8List? _activeImageBytes;
  String? _activeAssetPath;
  bool _isEditingDetails = false;

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

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _activeImageBytes = bytes;
          _activeAssetPath = null;
          _isEditingDetails = true;
        });
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

  void _showImageSourcePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E2121),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) {
        return SafeArea(
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
      id: 'flash_${DateTime.now().millisecondsSinceEpoch}_${_uploadedItems.length}',
      title: title,
      price: price,
      size: size,
      styleTag: _selectedStyle,
      isRepeatable: _isRepeatable,
      imageBytes: _activeImageBytes,
      assetPath: _activeAssetPath,
    );

    setState(() {
      _uploadedItems.add(newItem);
      _activeImageBytes = null;
      _activeAssetPath = null;
      _isEditingDetails = false;
    });

    if (addAnother) {
      _showImageSourcePicker();
    }
  }

  void _proceedToIdentityTags() {
    // Convert uploaded items to FlashArtwork list
    final flashArtworks = _uploadedItems.map((item) {
      return FlashArtwork(
        id: item.id,
        artistName: widget.artistName,
        title: item.title,
        imageUrl: item.assetPath ?? 'assets/images/flash_traditional_panther.jpg',
        price: item.price,
        deposit: widget.minDeposit,
        dimensions: item.size,
        status: item.isRepeatable ? FlashStatus.repeatable : FlashStatus.available,
        category: item.styleTag,
      );
    }).toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ArtistIdentityTagsScreen(
          artistName: widget.artistName,
          photoBytes: widget.photoBytes,
          photoUrl: widget.photoUrl,
          instagramHandle: widget.instagramHandle,
          minDeposit: widget.minDeposit,
          flashArtworks: flashArtworks,
          authService: widget.authService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121414),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (kEnableDevBypass)
            TextButton(
              key: const Key('dev_skip_flash'),
              onPressed: _proceedToIdentityTags,
              child: Text(
                'Skip (Dev)',
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFFEEC200),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
      body: TattooBackgroundWrapper(
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ArtistStepperHeader(currentStep: 2),
                const SizedBox(height: 24),

                Text(
                  'Showcase your\nwork',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFF9FAFA),
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 8),

                Text(
                  'Upload some custom flash work you plan on selling',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    color: const Color(0xFF919696),
                  ),
                ),
                const SizedBox(height: 28),

                // Dynamic content based on state:
                // 1. If currently editing item details (Creation 10)
                // 2. If uploaded items exist (Creation 11 & 12)
                // 3. If empty initial state (Creation 9)
                if (_isEditingDetails) ...[
                  _buildItemDetailsCard(),
                ] else ...[
                  _buildUploadBox(),
                  const SizedBox(height: 24),

                  if (_uploadedItems.isNotEmpty) ...[
                    _buildUploadedItemsGallery(),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        key: const Key('done_flash_button'),
                        onPressed: _proceedToIdentityTags,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEEC200),
                          foregroundColor: const Color(0xFF121414),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(26),
                          ),
                        ),
                        child: Text(
                          'DONE',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    Center(
                      child: TextButton(
                        key: const Key('skip_flash_button'),
                        onPressed: _proceedToIdentityTags,
                        child: Text(
                          'SKIP',
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFFEEC200),
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUploadBox() {
    return InkWell(
      key: const Key('upload_flash_trigger'),
      onTap: _showImageSourcePicker,
      borderRadius: BorderRadius.circular(16),
      child: AdaptiveGlassContainer(
        borderRadius: 16,
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
        child: Column(
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
    );
  }

  Widget _buildItemDetailsCard() {
    final styleOptions = ['TRADITIONAL', 'BLACKWORK', 'NEO-TRAD', 'JAPANESE', '+ CUSTOM'];

    return AdaptiveGlassContainer(
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

          // Flash Image Preview with Edit Icon
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
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
              Positioned(
                bottom: 8,
                right: 8,
                child: InkWell(
                  onTap: _showImageSourcePicker,
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
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFEEC200) : const Color(0xFF262929),
                    borderRadius: BorderRadius.circular(6),
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
              Switch(
                key: const Key('repeatable_switch'),
                value: _isRepeatable,
                activeColor: const Color(0xFFEEC200),
                onChanged: (val) {
                  setState(() => _isRepeatable = val);
                },
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Action Buttons: + Add More Flash & DONE
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              key: const Key('add_more_flash_button'),
              onPressed: () => _saveCurrentItem(addAnother: true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEEC200),
                foregroundColor: const Color(0xFF121414),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: Text(
                '+ Add More Flash',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: TextButton(
              key: const Key('done_details_button'),
              onPressed: () => _saveCurrentItem(addAnother: false),
              child: Text(
                'DONE',
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFFEEC200),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadedItemsGallery() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'UPLOADED FLASH (${_uploadedItems.length})',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF8C9191),
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 130,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _uploadedItems.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final item = _uploadedItems[index];
              return SizedBox(
                width: 110,
                child: AdaptiveGlassContainer(
                  borderRadius: 12,
                  padding: EdgeInsets.zero,
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
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
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF2E3232)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF2E3232)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFEEC200), width: 1.5),
      ),
    );
  }
}
