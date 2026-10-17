import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../models/artist.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/flash_switch.dart';
import '../../widgets/flash_image.dart';
import '../../widgets/photo_source_bottom_sheet.dart';
import 'artist_edit_profile_screen.dart';
import 'artist_account_settings_screen.dart';
import '../app_info_screen.dart';
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

  final bool _isLoading = false;
  bool _isDeleting = false;
  bool _isUploadingPhoto = false;

  // Profile fields
  late String _displayName;
  late String _username;
  late String _bio;
  late String _location;
  String _email = 'artist@flash.ink';
  String _phoneNumber = '+1 (555) 345-6789';
  bool _phoneVerified = true;
  String? _photoUrl;

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
    _photoUrl = effective.avatarUrl.isNotEmpty ? effective.avatarUrl : null;
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
          }
          if (user.email != null && user.email!.isNotEmpty) {
            _email = user.email!;
          }
          if (user.photoURL != null && user.photoURL!.isNotEmpty) {
            _photoUrl = user.photoURL;
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

  Future<void> _handleEditPhoto() async {
    final result = await PhotoSourceBottomSheet.show(
      context: context,
      hasExistingPhoto: _photoUrl != null && _photoUrl!.isNotEmpty,
    );

    if (result == null || !mounted) return;

    final user = _authService.currentUser ?? FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (result.isRemoved) {
      setState(() => _isUploadingPhoto = true);
      try {
        try {
          await FirebaseStorage.instance.ref().child('artist_profiles/${user.uid}.png').delete();
        } catch (_) {}
        try {
          await FirebaseStorage.instance.ref().child('artist_profiles/${user.uid}.jpg').delete();
        } catch (_) {}

        await user.updatePhotoURL(null);
        try {
          await FirebaseFirestore.instance.collection('artists').doc(user.uid).set({
            'avatarUrl': null,
          }, SetOptions(merge: true));
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'photoURL': null,
          }, SetOptions(merge: true));
        } catch (_) {}

        if (mounted) {
          setState(() {
            _photoUrl = null;
            _isUploadingPhoto = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Artist profile photo removed')),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isUploadingPhoto = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to remove photo: $e')),
          );
        }
      }
      return;
    }

    if (result.croppedBytes != null) {
      setState(() => _isUploadingPhoto = true);
      try {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('artist_profiles')
            .child('${user.uid}.png');

        await storageRef.putData(
          result.croppedBytes!,
          SettableMetadata(contentType: 'image/png'),
        );
        final downloadUrl = await storageRef.getDownloadURL();

        await user.updatePhotoURL(downloadUrl);
        try {
          await FirebaseFirestore.instance.collection('artists').doc(user.uid).set({
            'avatarUrl': downloadUrl,
          }, SetOptions(merge: true));
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'photoURL': downloadUrl,
          }, SetOptions(merge: true));
        } catch (_) {}

        if (mounted) {
          setState(() {
            _photoUrl = downloadUrl;
            _isUploadingPhoto = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Artist profile photo updated successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isUploadingPhoto = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update photo: $e')),
          );
        }
      }
    }
  }

  Future<void> _showEditProfileDialog() async {
    final result = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(
        builder: (_) => ArtistEditProfileScreen(
          initialDisplayName: _displayName,
          initialUsername: _username,
          initialBio: _bio,
          initialLocation: _location,
          onSave: (newName, newUsername, newBio, newLocation) async {
            setState(() {
              _displayName = newName;
              _username = newUsername;
              _bio = newBio;
              _location = newLocation;
            });

            await _updateProfileInFirestore(
              name: newName,
              username: newUsername,
              bio: newBio,
              location: newLocation,
            );
          },
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _displayName = result['name'] ?? _displayName;
        _username = result['username'] ?? _username;
        _bio = result['bio'] ?? _bio;
        _location = result['location'] ?? _location;
      });

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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AppInfoScreen(
          title: title,
          content: content,
        ),
      ),
    );
  }

  void _showAccountSettingsModal() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ArtistAccountSettingsScreen(
          email: _email,
          onDeleteAccount: _handleDeleteAccount,
        ),
      ),
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
        bool dialogDismissed = false;
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
              onPressed: () {
                if (dialogDismissed) return;
                dialogDismissed = true;
                Navigator.of(dialogContext).pop(false);
              },
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
              onPressed: () {
                if (dialogDismissed) return;
                dialogDismissed = true;
                Navigator.of(dialogContext).pop(true);
              },
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

            const SizedBox(height: 24),

            // About & Studio Section
            _buildSectionHeader('ABOUT & STUDIO'),
            const SizedBox(height: 10),
            _buildSettingsContainer([
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
            ]),

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
                icon: Icons.healing_outlined,
                title: 'Tattoo Aftercare Guide',
                subtitle: 'Standardized healing instructions and recommended balms',
                trailing: const Icon(Icons.chevron_right, color: Color(0xFF919696), size: 18),
                onTap: () => _showInfoModal(
                  'Aftercare Instructions',
                  'Leave second-skin barrier on for 3-5 days unless leaking. Wash gently with antibacterial soap and warm water. Apply a thin layer of unscented moisturizer twice daily.',
                ),
              ),
            ]),

            const SizedBox(height: 28),

            // Section 4: Support & Legal
            _buildSectionHeader('SUPPORT & LEGAL'),
            const SizedBox(height: 10),
            _buildSettingsContainer([
              _buildSettingsTile(
                icon: Icons.help_outline,
                title: 'Help Center & FAQ',
                subtitle: 'Answers to frequently asked questions for artists',
                trailing: const Icon(Icons.chevron_right, color: Color(0xFF919696), size: 18),
                onTap: () => _showInfoModal(
                  'Help Center',
                  'Need assistance with artist tools, booking settings, or payout transfers? Reach our artist support desk at artist-support@flash.ink or through our concierge.',
                ),
              ),
              const Divider(color: AppTheme.darkBorder, height: 1),
              _buildSettingsTile(
                icon: Icons.description_outlined,
                title: 'Terms of Service',
                subtitle: 'Artist terms, licensing, and platform agreements',
                trailing: const Icon(Icons.chevron_right, color: Color(0xFF919696), size: 18),
                onTap: () => _showInfoModal(
                  'Terms of Service',
                  'By using Flash.Ink as a verified artist, you retain copyright of your original flash artworks and grant Flash.Ink a license to display portfolio images. Client contact information must remain confidential and handled in compliance with privacy laws.',
                ),
              ),
              const Divider(color: AppTheme.darkBorder, height: 1),
              _buildSettingsTile(
                icon: Icons.privacy_tip_outlined,
                title: 'Privacy Policy',
                subtitle: 'Artist confidentiality and data encryption',
                trailing: const Icon(Icons.chevron_right, color: Color(0xFF919696), size: 18),
                onTap: () => _showInfoModal(
                  'Privacy Policy',
                  'Artist banking information, client consultation notes, and contact details are strictly encrypted with TLS and AES-256 standards.',
                ),
              ),
            ]),

            const SizedBox(height: 28),

            // Section 5: Account Security & Settings
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

            // Account Actions: Sign Out & Delete Account
            _buildSignOutButton(),

            const SizedBox(height: 12),

            _buildDeleteAccountButton(),

            const SizedBox(height: 24),

            // App Version Footer
            Center(
              child: Text(
                'Flash.Ink v1.0.0 (Build 42) • Premium Flash Collective',
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF4D5353),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
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
        border: Border.all(color: AppTheme.goldBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(60),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar with Gold Border, Silhouette fallback, and Edit Badge
          Stack(
            children: [
              GestureDetector(
                key: const Key('artist_avatar_image_button'),
                onTap: _handleEditPhoto,
                child: Container(
                  width: 76,
                  height: 76,
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
                    child: _isUploadingPhoto
                        ? Container(
                            color: const Color(0xFF262929),
                            child: const Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.gold),
                                ),
                              ),
                            ),
                          )
                        : (_photoUrl != null && _photoUrl!.isNotEmpty)
                            ? FlashImage(
                                urlOrPath: _photoUrl!,
                                width: 76,
                                height: 76,
                                fit: BoxFit.cover,
                                errorWidget: Container(
                                  color: const Color(0xFF262929),
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    Icons.person_outline,
                                    color: AppTheme.gold,
                                    size: 40,
                                  ),
                                ),
                              )
                            : Container(
                                color: const Color(0xFF262929),
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.person_outline,
                                  color: AppTheme.gold,
                                  size: 40,
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
                  onTap: _handleEditPhoto,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: AppTheme.gold,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.onyxBackground, width: 2),
                    ),
                    child: const Icon(
                      Icons.camera_alt_outlined,
                      size: 13,
                      color: AppTheme.onyxBackground,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),

          // Name, Username, Email, and Location
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _displayName,
                  key: const Key('account_display_name'),
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '@$_username',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.gold,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _email,
                  key: const Key('account_email'),
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF919696),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, color: Color(0xFF919696), size: 13),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _location,
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF919696),
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.plusJakartaSans(
        color: const Color(0xFF919696),
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildSettingsContainer(List<Widget> children) {
    return Material(
      color: AppTheme.cardBackground,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.darkBorder, width: 1),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSettingsTile({
    Key? key,
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        key: key,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        leading: Icon(icon, color: AppTheme.gold, size: 20),
        title: Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            color: AppTheme.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF919696),
                  fontSize: 12,
                ),
              )
            : null,
        trailing: trailing,
        onTap: onTap,
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
    return Material(
      color: Colors.transparent,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        leading: Icon(icon, color: AppTheme.gold, size: 20),
        title: Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            color: AppTheme.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.plusJakartaSans(
            color: const Color(0xFF919696),
            fontSize: 12,
          ),
        ),
        trailing: FlashSwitch(
          value: value,
          onChanged: onChanged,
        ),
        onTap: () => onChanged(!value),
      ),
    );
  }

  Widget _buildSignOutButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        key: const Key('artist_account_sign_out_button'),
        onPressed: _handleSignOut,
        icon: const Icon(
          Icons.logout,
          color: AppTheme.gold,
          size: 18,
        ),
        label: Text(
          'Sign Out',
          style: GoogleFonts.plusJakartaSans(
            color: AppTheme.gold,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          backgroundColor: AppTheme.onyxContainer,
          side: const BorderSide(color: AppTheme.goldBorder, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteAccountButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        key: const Key('artist_account_delete_account_button'),
        onPressed: _isDeleting ? null : _handleDeleteAccount,
        icon: const Icon(
          Icons.delete_outline,
          color: Color(0xFFEF4444),
          size: 18,
        ),
        label: _isDeleting
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEF4444)),
                ),
              )
            : Text(
                'Delete Account',
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFFEF4444),
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          backgroundColor: const Color(0x11EF4444),
          side: const BorderSide(color: Color(0x55EF4444), width: 1.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}
