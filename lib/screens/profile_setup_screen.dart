import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_spacing.dart';
import 'aesthetics_selection_screen.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _usernameController = TextEditingController();
  bool _isLoading = false;
  String? _usernameError;

  Uint8List? _imageBytes;
  final ImagePicker _picker = ImagePicker();
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _usernameController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _imageBytes = bytes;
        });
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

        await FirebaseFirestore.instance.collection('users').doc(user.uid).set(updateData, SetOptions(merge: true));
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
    final username = _usernameController.text.trim();
    if (username.isEmpty) {
      setState(() => _usernameError = 'Please enter a username');
      return;
    }
    setState(() => _usernameError = null);
    _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  Widget _buildUsernameStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Add a username',
          style: GoogleFonts.plusJakartaSans(
            color: const Color(0xFFF9FAFA),
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
        AppGaps.gapSm,
        Text(
          'Build a report. Tell the artists who you are.',
          style: GoogleFonts.plusJakartaSans(
            color: const Color(0xFF919696),
            fontSize: 16,
            height: 1.4,
          ),
        ),
        AppGaps.gapXl,
        Container(
          padding: const EdgeInsets.all(AppSpacing.spaceXl),
          decoration: BoxDecoration(
            color: const Color(0xFF1E2020).withAlpha(150),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF4D5252).withAlpha(100)),
          ),
          child: Column(
            children: [
              TextField(
                controller: _usernameController,
                style: const TextStyle(color: Color(0xFFF9FAFA)),
                decoration: InputDecoration(
                  hintText: '@OddMaree',
                  hintStyle: const TextStyle(color: Color(0xFF4D5252)),
                  filled: true,
                  fillColor: const Color(0xFF121414),
                  errorText: _usernameError,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF333737)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF333737)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFEEC200)),
                  ),
                ),
                onSubmitted: (_) => _nextStep(),
              ),
              AppGaps.gapXl,
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _nextStep,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEEC200),
                    foregroundColor: const Color(0xFF121414),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
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
                      const Icon(Icons.arrow_forward, size: 18),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoStep() {
    final hasPhoto = _imageBytes != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          hasPhoto ? 'Looks good!' : 'Upload a profile photo',
          style: GoogleFonts.plusJakartaSans(
            color: const Color(0xFFF9FAFA),
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
        AppGaps.gapSm,
        if (!hasPhoto)
          Text(
            "Doesn't have to be your face. Just whatever you'd like to represent you.",
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFF919696),
              fontSize: 16,
              height: 1.4,
            ),
          )
        else
          const SizedBox(height: 22), 
        AppGaps.gapXl,
        Container(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: AppSpacing.spaceXl),
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF1E2020).withAlpha(150),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF4D5252).withAlpha(100)),
          ),
          child: Column(
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFD9D9D9),
                        border: Border.all(
                          color: const Color(0xFFEEC200),
                          width: 4,
                        ),
                        image: hasPhoto
                            ? DecorationImage(
                                image: MemoryImage(_imageBytes!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: !hasPhoto
                          ? const Icon(
                              Icons.person,
                              size: 80,
                              color: Colors.white,
                            )
                          : null,
                    ),
                    if (!hasPhoto)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Color(0xFFEEC200),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            size: 20,
                            color: Color(0xFF121414),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              AppGaps.gapXl,
              if (!hasPhoto)
                TextButton(
                  onPressed: _isLoading ? null : _saveProfile,
                  child: Text(
                    'SKIP',
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFFEEC200),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      letterSpacing: 1.0,
                    ),
                  ),
                )
              else ...[
                TextButton(
                  onPressed: _pickImage,
                  child: Text(
                    'CHANGE',
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFFEEC200),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                AppGaps.gapLg,
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEEC200),
                      foregroundColor: const Color(0xFF121414),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
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
                              const Icon(Icons.arrow_forward, size: 18),
                            ],
                          ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF121414),
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
                      Colors.black.withAlpha(180),
                    ],
                    stops: const [0.0, 0.3, 0.7, 1.0],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.spaceXl, AppSpacing.spaceXl * 2, AppSpacing.spaceXl, 0),
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
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
    );
  }
}
