import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../widgets/adaptive_glass_container.dart';
import '../../widgets/flash_glass_app_bar.dart';
import '../../widgets/pinned_bottom_action_scaffold.dart';
import '../../widgets/username_input_formatter.dart';

class ArtistEditProfileScreen extends StatefulWidget {
  final String initialDisplayName;
  final String initialUsername;
  final String initialBio;
  final String initialLocation;
  final Future<void> Function(String name, String username, String bio, String location)? onSave;

  const ArtistEditProfileScreen({
    super.key,
    required this.initialDisplayName,
    required this.initialUsername,
    required this.initialBio,
    required this.initialLocation,
    this.onSave,
  });

  @override
  State<ArtistEditProfileScreen> createState() => _ArtistEditProfileScreenState();
}

class _ArtistEditProfileScreenState extends State<ArtistEditProfileScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _usernameController;
  late final TextEditingController _bioController;
  late final TextEditingController _locationController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialDisplayName);
    _usernameController = TextEditingController(
      text: widget.initialUsername.replaceFirst(RegExp(r'^@'), ''),
    );
    _bioController = TextEditingController(text: widget.initialBio);
    _locationController = TextEditingController(text: widget.initialLocation);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final newName = _nameController.text.trim();
    final newUsername = _usernameController.text.trim().replaceAll('@', '');
    final newBio = _bioController.text.trim();
    final newLocation = _locationController.text.trim();

    if (newName.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      if (widget.onSave != null) {
        await widget.onSave!(
          newName,
          newUsername.isNotEmpty ? newUsername : widget.initialUsername,
          newBio,
          newLocation,
        );
      }
      if (mounted) {
        Navigator.pop(context, {
          'name': newName,
          'username': newUsername.isNotEmpty ? newUsername : widget.initialUsername,
          'bio': newBio,
          'location': newLocation,
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PinnedBottomActionScaffold(
      backgroundColor: const Color(0xFF121414),
      extendBodyBehindAppBar: true,
      inlineCTA: true,
      appBar: FlashGlassAppBar(
        title: Text(
          'Edit Profile',
          key: const Key('edit_profile_sheet_title'),
          style: GoogleFonts.plusJakartaSans(
            color: AppTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      ctaKey: const Key('save_profile_button'),
      ctaText: 'Save Changes',
      onCtaPressed: _handleSave,
      isCtaLoading: _isSaving,
      child: AdaptiveGlassContainer(
                useGradient: false,
                borderRadius: 20.0,
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Display Name',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF919696),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      key: const Key('edit_profile_name_field'),
                      controller: _nameController,
                      style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 15),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFF141616),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppTheme.darkBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppTheme.darkBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppTheme.gold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Username / Handle',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF919696),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      key: const Key('edit_profile_username_field'),
                      controller: _usernameController,
                      inputFormatters: const [StripLeadingAtFormatter()],
                      style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 15),
                      decoration: InputDecoration(
                        prefixText: '@',
                        prefixStyle: GoogleFonts.plusJakartaSans(color: AppTheme.gold),
                        filled: true,
                        fillColor: const Color(0xFF141616),
                        hintText: 'yourhandle',
                        hintStyle: const TextStyle(color: Color(0xFF4D5252)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppTheme.darkBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppTheme.darkBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppTheme.gold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Bio',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF919696),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      key: const Key('edit_profile_bio_field'),
                      controller: _bioController,
                      maxLines: 4,
                      style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFF141616),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppTheme.darkBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppTheme.darkBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppTheme.gold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Studio & Location',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF919696),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      key: const Key('edit_profile_location_field'),
                      controller: _locationController,
                      style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 15),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFF141616),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppTheme.darkBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppTheme.darkBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppTheme.gold),
                        ),
                      ),
                    ),
          ],
        ),
      ),
    );
  }
}
