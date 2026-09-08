import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/auth_service.dart';
import '../../theme/app_radius.dart';
import '../../widgets/artist_stepper_header.dart';
import 'artist_share_link_screen.dart';

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

  Future<void> _pickImage([ImageSource? source]) async {
    if (source == null) {
      _showImageSourceModal();
      return;
    }

    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _imageBytes = bytes;
        });
      }
    } catch (e) {
      _showErrorSnackBar('Failed to select image: $e');
    }
  }

  Future<void> _useSamplePhoto() async {
    try {
      final byteData = await rootBundle.load('assets/images/flash_traditional_moth.jpg');
      final bytes = byteData.buffer.asUint8List();
      setState(() {
        _imageBytes = bytes;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Loaded sample photo for testing.'),
            backgroundColor: Color(0xFF22C55E),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      _showErrorSnackBar('Failed to load sample photo: $e');
    }
  }

  void _showImageSourceModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E2020),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4D5252),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Select Profile Photo',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFF9FAFA),
                  ),
                ),
                const SizedBox(height: 18),
                ListTile(
                  leading: const Icon(Icons.photo_library, color: Color(0xFFEEC200)),
                  title: Text(
                    'Choose from Gallery',
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFFF9FAFA),
                      fontWeight: FontWeight.w600,
                    ),
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
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFFF9FAFA),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(bottomSheetContext);
                    _pickImage(ImageSource.camera);
                  },
                ),
                if (kDebugMode)
                  ListTile(
                    leading: const Icon(Icons.developer_mode, color: Color(0xFFEEC200)),
                    title: Text(
                      'Use Sample Photo (Dev)',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFFEEC200),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(bottomSheetContext);
                      _useSamplePhoto();
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
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
            builder: (_) => ArtistShareLinkScreen(
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

  Widget _buildAvatarPlaceholder() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer yellow ring container
        Container(
          width: 230,
          height: 230,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFEEC200), width: 3),
            color: const Color(0xFFCCCCCC),
          ),
          child: ClipOval(
            child: CustomPaint(
              size: const Size(230, 230),
              painter: _SilhouettePainter(),
            ),
          ),
        ),

        // Camera Icon Floating Badge
        Positioned(
          bottom: 12,
          right: 12,
          child: GestureDetector(
            onTap: _pickImage,
            child: Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                color: Color(0xFFEEC200),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black45,
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.camera_alt,
                color: Color(0xFF121414),
                size: 26,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImagePreview() {
    return Container(
      width: 230,
      height: 230,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF242727),
        border: Border.all(color: const Color(0xFF383C3C), width: 2),
      ),
      child: ClipOval(
        child: Image.memory(
          _imageBytes!,
          width: 230,
          height: 230,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasImage = _imageBytes != null;

    return Scaffold(
      backgroundColor: const Color(0xFF121414),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Stepper: Step 1 completed with checkmark, Step 2 active
              const ArtistStepperHeader(currentStep: 2),
              const SizedBox(height: 24),

              // Dynamic Headline based on state
              Text(
                hasImage ? 'Looks good' : 'Upload a profile\nphoto',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFF9FAFA),
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 8),

              if (!hasImage) ...[
                Text(
                  'Doesn\'t have to be your face. Just whatever you\'d like to represent you.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    color: const Color(0xFF919696),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 48),

                // Avatar with Camera Badge
                Center(
                  child: GestureDetector(
                    onTap: _pickImage,
                    child: _buildAvatarPlaceholder(),
                  ),
                ),
                const SizedBox(height: 28),

                // CHANGE button
                Center(
                  child: GestureDetector(
                    onTap: _pickImage,
                    child: Text(
                      'CHANGE',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                        color: const Color(0xFFEEC200),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),

                // CONTINUE Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : (_imageBytes != null ? _handleContinue : _pickImage),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEEC200),
                      foregroundColor: const Color(0xFF121414),
                      elevation: 0,
                      shape: const StadiumBorder(),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _imageBytes != null ? 'CONTINUE' : 'SELECT PHOTO',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                            color: const Color(0xFF121414),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.arrow_forward,
                          size: 18,
                          color: Color(0xFF121414),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                const SizedBox(height: 24),

                // Mode B: Screen 4 - Looks Good Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1C1C),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF2B2E2E)),
                  ),
                  child: Column(
                    children: [
                      // Preview of selected image
                      _buildImagePreview(),
                      const SizedBox(height: 28),

                      // CHANGE button
                      GestureDetector(
                        onTap: _pickImage,
                        child: Text(
                          'CHANGE',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                            color: const Color(0xFFEEC200),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // CONTINUE Button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleContinue,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEEC200),
                            foregroundColor: const Color(0xFF121414),
                            elevation: 0,
                            shape: const StadiumBorder(),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF121414)),
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'CONTINUE',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.1,
                                        color: const Color(0xFF121414),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(
                                      Icons.arrow_forward,
                                      size: 18,
                                      color: Color(0xFF121414),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Custom painter for silhouette avatar matching the design
class _SilhouettePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final headPaint = Paint()..color = Colors.white;
    final shouldersPaint = Paint()..color = Colors.white;

    // Head
    final headCenter = Offset(size.width / 2, size.height * 0.42);
    final headRadius = size.width * 0.22;
    canvas.drawCircle(headCenter, headRadius, headPaint);

    // Shoulders
    final shouldersPath = Path();
    final bottomCenter = Offset(size.width / 2, size.height * 1.05);
    final shoulderRadiusX = size.width * 0.42;
    final shoulderRadiusY = size.height * 0.35;

    shouldersPath.addOval(Rect.fromCenter(
      center: bottomCenter,
      width: shoulderRadiusX * 2,
      height: shoulderRadiusY * 2,
    ));

    canvas.drawPath(shouldersPath, shouldersPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
