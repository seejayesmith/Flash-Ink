import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/artist.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/adaptive_glass_container.dart';
import '../../widgets/flash_switch.dart';
import '../../widgets/flash_image.dart';
import '../splash_screen.dart';
import '../artist_profile_screen.dart';

/// Artist Account Screen
///
/// Full-page account settings accessible by tapping the artist's avatar in the
/// artist dashboard, calendar, books, or earnings headers.
/// Provides profile management, notifications & alerts, studio & safety policies,
/// sensitive account management (housing account deletion), and sign out.
class ArtistAccountScreen extends StatefulWidget {
  final Artist? artist;
  final AuthService? authService;

  const ArtistAccountScreen({
    super.key,
    this.artist,
    this.authService,
  });

  @override
  State<ArtistAccountScreen> createState() => _ArtistAccountScreenState();
}

class _ArtistAccountScreenState extends State<ArtistAccountScreen> {
  late final AuthService _authService = widget.authService ?? AuthService();

  bool _isLoading = false;
  bool _isDeleting = false;

  // Profile fields
  late String _displayName;
  late String _username;
  late String _bio;
  late String _location;
  String _email = 'artist@flash.ink';
  String _phoneNumber = '+1 (555) 345-6789';
  bool _phoneVerified = true;
  late String _photoUrl;

  // Notification preferences
  bool _bookingAlerts = true;
  bool _reminderAlerts = true;
  bool _clientMessages = true;

  @override
  void initState() {
    super.initState();
    _initDefaultValues();
    _loadUserProfile();
  }

  void _initDefaultValues() {
    final effective = _getEffectiveArtist();
    _displayName = effective.name.isNotEmpty ? effective.name : 'OddMaree';
    _username = effective.name.isNotEmpty
        ? effective.name.toLowerCase().replaceAll(' ', '_')
        : 'oddmaree';
    _bio = effective.bio.isNotEmpty
        ? effective.bio
        : 'Resident artist specializing in flash & custom illustrative blackwork.';
    _location = effective.location.isNotEmpty
        ? effective.location
        : 'Portland, OR • Flash & Custom';
    _photoUrl = effective.avatarUrl.isNotEmpty
        ? effective.avatarUrl
        : 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=400&q=80';
  }

  Artist _getEffectiveArtist() {
    if (widget.artist != null) {
      return widget.artist!;
    }
    return Artist.mockArtists.firstWhere(
      (a) => a.name.toLowerCase() == 'oddmaree',
      orElse: () => Artist.mockArtists.first,
    );
  }

  Future<void> _loadUserProfile() async {
    final user = _authService.currentUser;
    if (user != null) {
      if (mounted) {
        setState(() {
          if (user.displayName != null && user.displayName!.isNotEmpty) {
            _displayName = user.displayName!;
            _username = user.displayName!.toLowerCase().replaceAll(' ', '_');
          }
          if (user.email != null && user.email!.isNotEmpty) {
            _email = user.email!;
          }
          if (user.photoURL != null && user.photoURL!.isNotEmpty) {
            _photoUrl = user.photoURL!;
          }
        });
      }

      try {
        // Attempt reading from artists collection first
        final artistDoc = await FirebaseFirestore.instance
            .collection('artists')
            .doc(user.uid)
            .get();

        if (artistDoc.exists && artistDoc.data() != null && mounted) {
          final data = artistDoc.data()!;
          setState(() {
            if (data['name'] != null && (data['name'] as String).isNotEmpty) {
              _displayName = data['name'] as String;
            }
            if (data['username'] != null && (data['username'] as String).isNotEmpty) {
              _username = data['username'] as String;
            }
            if (data['bio'] != null && (data['bio'] as String).isNotEmpty) {
              _bio = data['bio'] as String;
            }
            if (data['location'] != null && (data['location'] as String).isNotEmpty) {
              _location = data['location'] as String;
            }
            if (data['avatarUrl'] != null && (data['avatarUrl'] as String).isNotEmpty) {
              _photoUrl = data['avatarUrl'] as String;
            }
            if (data['email'] != null && (data['email'] as String).isNotEmpty) {
              _email = data['email'] as String;
            }
            if (data['phoneNumber'] != null && (data['phoneNumber'] as String).isNotEmpty) {
              _phoneNumber = data['phoneNumber'] as String;
            }
          });
        }

        // Also check users collection for fallback / verified flags
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (userDoc.exists && userDoc.data() != null && mounted) {
          final uData = userDoc.data()!;
          setState(() {
            if (uData['phoneVerified'] != null) {
              _phoneVerified = uData['phoneVerified'] as bool;
            }
          });
        }
      } catch (_) {
        // Fallback gracefully for offline or widget testing environments
      }
    }
  }

  Future<void> _updateProfileInFirestore({
    required String name,
    required String username,
    required String bio,
    required String location,
  }) async {
    final user = _authService.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance.collection('artists').doc(user.uid).set({
          'name': name,
          'username': username,
          'bio': bio,
          'location': location,
        }, SetOptions(merge: true)).timeout(const Duration(milliseconds: 600));

        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'displayName': name,
          'username': username,
        }, SetOptions(merge: true)).timeout(const Duration(milliseconds: 600));
      } catch (_) {
        // Keep offline resilience
      }
    }
  }

  void _showEditProfileDialog() {
    final nameController = TextEditingController(text: _displayName);
    final usernameController = TextEditingController(text: _username);
    final bioController = TextEditingController(text: _bio);
    final locationController = TextEditingController(text: _location);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E2020),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF383C3C),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Edit Profile',
                  key: const Key('edit_profile_sheet_title'),
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Display Name',
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF919696),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  key: const Key('edit_profile_name_field'),
                  controller: nameController,
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
                const SizedBox(height: 14),
                Text(
                  'Username / Handle',
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF919696),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  key: const Key('edit_profile_username_field'),
                  controller: usernameController,
                  style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 15),
                  decoration: InputDecoration(
                    prefixText: '@ ',
                    prefixStyle: GoogleFonts.plusJakartaSans(color: AppTheme.gold),
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
                const SizedBox(height: 14),
                Text(
                  'Bio',
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF919696),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  key: const Key('edit_profile_bio_field'),
                  controller: bioController,
                  maxLines: 3,
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
                const SizedBox(height: 14),
                Text(
                  'Studio & Location',
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF919696),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  key: const Key('edit_profile_location_field'),
                  controller: locationController,
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
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    key: const Key('save_profile_button'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.gold,
                      foregroundColor: AppTheme.onyxBackground,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      final newName = nameController.text.trim();
                      final newUsername = usernameController.text.trim();
                      final newBio = bioController.text.trim();
                      final newLocation = locationController.text.trim();

                      if (newName.isNotEmpty) {
                        setState(() {
                          _displayName = newName;
                          if (newUsername.isNotEmpty) _username = newUsername;
                          if (newBio.isNotEmpty) _bio = newBio;
                          if (newLocation.isNotEmpty) _location = newLocation;
                        });

                        _updateProfileInFirestore(
                          name: _displayName,
                          username: _username,
                          bio: _bio,
                          location: _location,
                        );

                        Navigator.of(sheetContext).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Profile updated successfully',
                              style: GoogleFonts.plusJakartaSans(color: Colors.white),
                            ),
                            backgroundColor: const Color(0xFF1E2020),
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                    child: Text(
                      'Save Changes',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _navigateToPublicProfile() {
    final effectiveArtist = _getEffectiveArtist();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ArtistProfileScreen(artist: effectiveArtist),
      ),
    );
  }

  void _showInfoModal(String title, String content) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E2020),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF383C3C),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                content,
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF919696),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.gold,
                    foregroundColor: AppTheme.onyxBackground,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: Text(
                    'Got It',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAccountSettingsModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E2020),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF383C3C),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Account Settings',
                key: const Key('account_settings_modal_title'),
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Manage security credentials, primary email, and irreversible account actions.',
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF919696),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 20),
              _buildSettingsContainer([
                _buildSettingsTile(
                  icon: Icons.alternate_email,
                  title: 'Primary Account Email',
                  subtitle: _email,
                  trailing: const Icon(Icons.lock_outline, color: Color(0xFF6B7280), size: 16),
                ),
                const Divider(color: AppTheme.darkBorder, height: 1),
                _buildSettingsTile(
                  icon: Icons.shield_outlined,
                  title: 'Artist Verification Status',
                  subtitle: 'Verified Resident Tattooer',
                  trailing: const Icon(Icons.check_circle, color: Color(0xFF22C55E), size: 18),
                ),
              ]),
              const SizedBox(height: 28),
              Text(
                'DANGER ZONE',
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFFEF4444),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1212),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFEF4444).withAlpha(100), width: 1),
                ),
                child: ListTile(
                  key: const Key('delete_account_button'),
                  leading: const Icon(Icons.delete_forever_outlined, color: Color(0xFFEF4444)),
                  title: Text(
                    'Delete Account',
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFFEF4444),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    'Permanently delete your artist portfolio, bookings, and profile data',
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFFB06060),
                      fontSize: 12,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: Color(0xFFEF4444), size: 20),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _handleDeleteAccount();
                  },
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleSignOut() async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2020),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppTheme.darkBorder),
        ),
        title: Text(
          'Sign Out',
          style: GoogleFonts.plusJakartaSans(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to sign out of Flash.Ink?',
          style: GoogleFonts.plusJakartaSans(
            color: const Color(0xFF919696),
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text(
              'Cancel',
              style: GoogleFonts.plusJakartaSans(color: const Color(0xFF919696)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.gold,
              foregroundColor: AppTheme.onyxBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: Text(
              'Sign Out',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (shouldSignOut == true) {
      await _authService.signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const SplashScreen()),
          (route) => false,
        );
      }
    }
  }

  Future<void> _handleDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          key: const Key('delete_account_dialog'),
          backgroundColor: const Color(0xFF1E2020),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFEF4444), width: 1.2),
          ),
          title: Text(
            'Delete Account',
            key: const Key('delete_account_modal_title'),
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFFF9FAFA),
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          content: Text(
            'Are you sure you want to delete your account? This action cannot be undone.',
            key: const Key('delete_account_modal_message'),
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFF919696),
              fontSize: 14,
              height: 1.4,
            ),
          ),
          actionsAlignment: MainAxisAlignment.spaceEvenly,
          actions: [
            TextButton(
              key: const Key('delete_account_cancel_button'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                'Cancel',
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF919696),
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            ElevatedButton(
              key: const Key('delete_account_confirm_button'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                'Delete Account',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      setState(() => _isDeleting = true);
      try {
        await _authService.deleteAccount();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Account deleted. A confirmation email has been sent.',
                style: GoogleFonts.plusJakartaSans(color: Colors.white),
              ),
              backgroundColor: const Color(0xFF1E2020),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );

          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const SplashScreen()),
            (route) => false,
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isDeleting = false);
          final errorMsg = e is FirebaseAuthException
              ? _authService.handleFirebaseAuthException(e).toString().replaceFirst('Exception: ', '')
              : e.toString().replaceFirst('Exception: ', '');

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                errorMsg,
                style: GoogleFonts.plusJakartaSans(color: Colors.white),
              ),
              backgroundColor: const Color(0xFFEF4444),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppTheme.onyxBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.onyxBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          key: const Key('artist_account_back_button'),
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppTheme.textPrimary,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Account',
          style: GoogleFonts.plusJakartaSans(
            color: AppTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            key: const Key('artist_account_view_public_profile_button'),
            icon: const Icon(
              Icons.remove_red_eye_outlined,
              color: AppTheme.gold,
              size: 22,
            ),
            tooltip: 'View Public Profile',
            onPressed: _navigateToPublicProfile,
          ),
          IconButton(
            key: const Key('artist_account_edit_button'),
            icon: const Icon(
              Icons.edit_outlined,
              color: AppTheme.gold,
              size: 20,
            ),
            tooltip: 'Edit Profile Settings',
            onPressed: _showEditProfileDialog,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spaceLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),

            // Profile Hero Card
            _buildProfileHeroCard(),

            const SizedBox(height: 28),

            // Section 1: Personal Details
            _buildSectionHeader('PERSONAL INFORMATION'),
            const SizedBox(height: 10),
            _buildSettingsContainer([
              _buildSettingsTile(
                icon: Icons.person_outline,
                title: 'Display Name',
                subtitle: _displayName,
                trailing: const Icon(Icons.chevron_right, color: Color(0xFF919696), size: 18),
                onTap: _showEditProfileDialog,
              ),
              const Divider(color: AppTheme.darkBorder, height: 1),
              _buildSettingsTile(
                icon: Icons.alternate_email,
                title: 'Username',
                subtitle: '@$_username',
                trailing: const Icon(Icons.chevron_right, color: Color(0xFF919696), size: 18),
                onTap: _showEditProfileDialog,
              ),
              const Divider(color: AppTheme.darkBorder, height: 1),
              _buildSettingsTile(
                icon: Icons.article_outlined,
                title: 'Artist Bio',
                subtitle: _bio,
                trailing: const Icon(Icons.chevron_right, color: Color(0xFF919696), size: 18),
                onTap: _showEditProfileDialog,
              ),
              const Divider(color: AppTheme.darkBorder, height: 1),
              _buildSettingsTile(
                icon: Icons.storefront_outlined,
                title: 'Studio & Location',
                subtitle: _location,
                trailing: const Icon(Icons.chevron_right, color: Color(0xFF919696), size: 18),
                onTap: _showEditProfileDialog,
              ),
              const Divider(color: AppTheme.darkBorder, height: 1),
              _buildSettingsTile(
                icon: Icons.email_outlined,
                title: 'Email Address',
                subtitle: _email,
                trailing: const Icon(Icons.lock_outline, color: Color(0xFF6B7280), size: 16),
              ),
              const Divider(color: AppTheme.darkBorder, height: 1),
              _buildSettingsTile(
                icon: Icons.phone_outlined,
                title: 'Phone Number',
                subtitle: _phoneNumber,
                trailing: _phoneVerified
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0x2222C55E),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF22C55E), width: 0.8),
                        ),
                        child: Text(
                          'VERIFIED',
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFF22C55E),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    : null,
              ),
            ]),

            const SizedBox(height: 28),

            // Section 2: Notifications & Alerts
            _buildSectionHeader('NOTIFICATIONS & ALERTS'),
            const SizedBox(height: 10),
            _buildSettingsContainer([
              _buildSwitchTile(
                icon: Icons.notifications_active_outlined,
                title: 'New Booking Requests',
                subtitle: 'Notify immediately when clients request or claim flash',
                value: _bookingAlerts,
                onChanged: (val) => setState(() => _bookingAlerts = val),
              ),
              const Divider(color: AppTheme.darkBorder, height: 1),
              _buildSwitchTile(
                icon: Icons.calendar_today_outlined,
                title: 'Appointment Reminders',
                subtitle: '24-hour and 2-hour session reminders with clients',
                value: _reminderAlerts,
                onChanged: (val) => setState(() => _reminderAlerts = val),
              ),
              const Divider(color: AppTheme.darkBorder, height: 1),
              _buildSwitchTile(
                icon: Icons.chat_bubble_outline,
                title: 'Client Messages',
                subtitle: 'Alerts when clients send you inquiries or replies',
                value: _clientMessages,
                onChanged: (val) => setState(() => _clientMessages = val),
              ),
            ]),

            const SizedBox(height: 28),

            // Section 3: Studio & Safety Policies
            _buildSectionHeader('STUDIO & SAFETY POLICIES'),
            const SizedBox(height: 10),
            _buildSettingsContainer([
              _buildSettingsTile(
                icon: Icons.health_and_safety_outlined,
                title: 'Health & Safety Standards',
                subtitle: 'Bloodborne pathogen protocol, sterilization & studio standards',
                trailing: const Icon(Icons.chevron_right, color: Color(0xFF919696), size: 18),
                onTap: () => _showInfoModal(
                  'Health & Safety Protocol',
                  'All resident and guest tattooers on Flash.Ink operate in state-licensed studios adhering to OSHA Bloodborne Pathogen standards, single-use sterilized needle cartridges, and medical-grade disinfectants.',
                ),
              ),
              const Divider(color: AppTheme.darkBorder, height: 1),
              _buildSettingsTile(
                icon: Icons.gavel_outlined,
                title: 'Studio Guidelines & Cancellation',
                subtitle: 'Client booking policies, deposit rules, and consultation requirements',
                trailing: const Icon(Icons.chevron_right, color: Color(0xFF919696), size: 18),
                onTap: () => _showInfoModal(
                  'Studio Guidelines & Terms',
                  'Flash deposits are non-refundable and applied to the final tattoo price. Cancellations made with at least 48 hours notice allow clients to reschedule once without forfeiting their deposit.',
                ),
              ),
              const Divider(color: AppTheme.darkBorder, height: 1),
              _buildSettingsTile(
                icon: Icons.description_outlined,
                title: 'Terms of Service & Privacy',
                subtitle: 'Platform agreements, licensing, and artist confidentiality terms',
                trailing: const Icon(Icons.chevron_right, color: Color(0xFF919696), size: 18),
                onTap: () => _showInfoModal(
                  'Terms & Privacy',
                  'By using Flash.Ink as a verified artist, you retain copyright of your original flash artworks and grant Flash.Ink a license to display portfolio images. Client contact information must remain confidential and handled in compliance with privacy laws.',
                ),
              ),
            ]),

            const SizedBox(height: 28),

            // Section 4: Account Settings & Security
            _buildSectionHeader('ACCOUNT SECURITY & SETTINGS'),
            const SizedBox(height: 10),
            _buildSettingsContainer([
              _buildSettingsTile(
                key: const Key('artist_account_settings_tile'),
                icon: Icons.shield_outlined,
                title: 'Account Settings',
                subtitle: 'Manage security credentials, email, and delete account',
                trailing: const Icon(Icons.chevron_right, color: Color(0xFF919696), size: 18),
                onTap: _showAccountSettingsModal,
              ),
            ]),

            const SizedBox(height: 32),

            // Sign Out Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                key: const Key('artist_account_sign_out_button'),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF383C3C), width: 1.2),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _handleSignOut,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.logout, color: Color(0xFFEF4444), size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Sign Out',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFFEF4444),
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: bottomInset + 32),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.darkBorder, width: 1),
      ),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.gold,
                    width: 2.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.gold.withAlpha(50),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: FlashImage(
                    urlOrPath: _photoUrl,
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    errorWidget: Container(
                      color: const Color(0xFF262929),
                      alignment: Alignment.center,
                      child: Text(
                        _displayName.isNotEmpty ? _displayName[0] : 'O',
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.gold,
                          fontWeight: FontWeight.bold,
                          fontSize: 32,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  key: const Key('artist_account_avatar_edit'),
                  onTap: _showEditProfileDialog,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.gold,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.onyxBackground, width: 2),
                    ),
                    child: const Icon(
                      Icons.camera_alt_outlined,
                      size: 14,
                      color: AppTheme.onyxBackground,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _displayName,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '@$_username',
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.gold,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_on_outlined, color: Color(0xFF919696), size: 14),
              const SizedBox(width: 4),
              Text(
                _location,
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF919696),
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              key: const Key('artist_account_edit_profile_hero_button'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.gold,
                foregroundColor: AppTheme.onyxBackground,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: Text(
                'Edit Profile',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              onPressed: _showEditProfileDialog,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: GoogleFonts.plusJakartaSans(
          color: const Color(0xFF919696),
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSettingsContainer(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.darkBorder, width: 1),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildSettingsTile({
    Key? key,
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF262929),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppTheme.gold, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFF919696),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing,
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF262929),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppTheme.gold, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF919696),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FlashSwitch(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
