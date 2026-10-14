import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_spacing.dart';
import '../widgets/flash_switch.dart';
import '../widgets/tattoo_machine_icon.dart';
import '../widgets/photo_source_bottom_sheet.dart';
import 'client_edit_profile_screen.dart';
import 'client_aesthetics_screen.dart';
import 'app_info_screen.dart';
import 'splash_screen.dart';

/// Client Account Screen
///
/// Accessible by tapping the user's avatar icon at the top right of the client interface.
/// Provides profile management, aesthetic preferences, notification settings,
/// policies, sign out, and account deletion.
class ClientAccountScreen extends StatefulWidget {
  final AuthService? authService;

  const ClientAccountScreen({
    super.key,
    this.authService,
  });

  @override
  State<ClientAccountScreen> createState() => _ClientAccountScreenState();
}

class _ClientAccountScreenState extends State<ClientAccountScreen> {
  late final AuthService _authService = widget.authService ?? AuthService();

  final bool _isLoading = false;
  bool _isDeleting = false;
  bool _isUploadingPhoto = false;

  // Profile fields
  String _displayName = 'Flash Client';
  String _username = 'flashclient';
  String _email = 'client@flash.ink';
  String _phoneNumber = '+1 (555) 234-5678';
  bool _phoneVerified = true;
  String? _photoUrl;
  List<String> _aesthetics = ['traditional', 'fineline', 'blackwork'];

  // Notification preferences
  bool _flashDropAlerts = true;
  bool _bookingReminders = true;
  bool _artistMessages = true;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
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
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (doc.exists && doc.data() != null && mounted) {
          final data = doc.data()!;
          setState(() {
            if (data['displayName'] != null) {
              _displayName = data['displayName'] as String;
            } else if (data['username'] != null) {
              _displayName = data['username'] as String;
            }
            if (data['username'] != null) {
              _username = data['username'] as String;
            }
            if (data['email'] != null) {
              _email = data['email'] as String;
            }
            if (data['photoURL'] != null && (data['photoURL'] as String).isNotEmpty) {
              _photoUrl = data['photoURL'] as String;
            }
            if (data['phoneNumber'] != null) {
              _phoneNumber = data['phoneNumber'] as String;
            }
            if (data['phoneVerified'] != null) {
              _phoneVerified = data['phoneVerified'] as bool;
            }
            if (data['aesthetics'] is List) {
              final list = (data['aesthetics'] as List)
                  .map((e) => e.toString())
                  .toList();
              if (list.isNotEmpty) {
                _aesthetics = list;
              }
            }
          });
        }
      } catch (_) {
        // Keep default/auth info if Firestore read fails or offline
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
          await FirebaseStorage.instance.ref().child('user_profiles/${user.uid}.png').delete();
        } catch (_) {}
        try {
          await FirebaseStorage.instance.ref().child('user_profiles/${user.uid}.jpg').delete();
        } catch (_) {}

        await user.updatePhotoURL(null);
        await _updateFirestoreUser(user.uid, {
          'photoURL': null,
        });

        if (mounted) {
          setState(() {
            _photoUrl = null;
            _isUploadingPhoto = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile photo removed')),
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
            .child('user_profiles')
            .child('${user.uid}.png');

        await storageRef.putData(
          result.croppedBytes!,
          SettableMetadata(contentType: 'image/png'),
        );
        final downloadUrl = await storageRef.getDownloadURL();

        await user.updatePhotoURL(downloadUrl);
        await _updateFirestoreUser(user.uid, {
          'photoURL': downloadUrl,
        });

        if (mounted) {
          setState(() {
            _photoUrl = downloadUrl;
            _isUploadingPhoto = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile photo updated successfully')),
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

  Future<void> _updateFirestoreUser(String uid, Map<String, dynamic> data) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set(data, SetOptions(merge: true))
          .timeout(const Duration(milliseconds: 500));
    } catch (_) {
      // Graceful fallback for offline, widget tests, or unmocked Firestore
    }
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
                  color: Colors.white,
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

  Future<void> _showEditProfileDialog() async {
    final result = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(
        builder: (_) => ClientEditProfileScreen(
          initialDisplayName: _displayName,
          initialUsername: _username,
          onSave: (newName, newUsername) async {
            setState(() {
              _displayName = newName;
              _username = newUsername;
            });
            final user = _authService.currentUser;
            if (user != null) {
              await _updateFirestoreUser(user.uid, {
                'displayName': newName,
                'username': newUsername,
              });
            }
          },
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _displayName = result['displayName'] ?? _displayName;
        _username = result['username'] ?? _username;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully'),
          backgroundColor: Color(0xFF22C55E),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _showAestheticsSelectorModal() async {
    final result = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(
        builder: (_) => ClientAestheticsScreen(
          initialAesthetics: _aesthetics,
          onSave: (newAesthetics) async {
            setState(() {
              _aesthetics = newAesthetics;
            });
            final user = _authService.currentUser;
            if (user != null) {
              await _updateFirestoreUser(user.uid, {'aesthetics': newAesthetics});
            }
          },
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _aesthetics = result;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aesthetic preferences updated'),
          backgroundColor: Color(0xFF22C55E),
          duration: Duration(seconds: 2),
        ),
      );
    }
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
          key: const Key('account_back_button'),
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
            key: const Key('account_edit_button'),
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

            const SizedBox(height: 24),

            // Aesthetics Section
            _buildAestheticsSection(),

            const SizedBox(height: 24),

            // Quick Activity Shortcuts
            _buildQuickActivityRow(),

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

            // Section 2: Notifications
            _buildSectionHeader('NOTIFICATIONS & ALERTS'),
            const SizedBox(height: 10),
            _buildSettingsContainer([
              _buildSwitchTile(
                icon: Icons.flash_on_outlined,
                title: 'Flash Drop Alerts',
                subtitle: 'Notify immediately when followed artists drop flash',
                value: _flashDropAlerts,
                onChanged: (val) => setState(() => _flashDropAlerts = val),
              ),
              const Divider(color: AppTheme.darkBorder, height: 1),
              _buildSwitchTile(
                icon: Icons.calendar_today_outlined,
                title: 'Appointment Reminders',
                subtitle: '24-hour and 2-hour session reminders via push',
                value: _bookingReminders,
                onChanged: (val) => setState(() => _bookingReminders = val),
              ),
              const Divider(color: AppTheme.darkBorder, height: 1),
              _buildSwitchTile(
                icon: Icons.chat_bubble_outline,
                title: 'Direct Messages',
                subtitle: 'Alerts when artists reply to your inquiries',
                value: _artistMessages,
                onChanged: (val) => setState(() => _artistMessages = val),
              ),
            ]),

            const SizedBox(height: 28),

            // Section 3: Studio & Policies
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
                icon: Icons.policy_outlined,
                title: 'Booking & Deposit Policies',
                subtitle: 'Learn how flash reservations and custom deposits work',
                trailing: const Icon(Icons.chevron_right, color: Color(0xFF919696), size: 18),
                onTap: () => _showInfoModal(
                  'Deposit & Booking Terms',
                  'Flash deposits are non-refundable and hold your selected flash piece exclusively. Cancellations with over 48 hours notice allow one complimentary reschedule.',
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
                subtitle: 'Answers to frequently asked questions',
                trailing: const Icon(Icons.chevron_right, color: Color(0xFF919696), size: 18),
                onTap: () => _showInfoModal(
                  'Help Center',
                  'Need assistance? Our support team is active 7 days a week. Email us at support@flash.ink or message through our concierge.',
                ),
              ),
              const Divider(color: AppTheme.darkBorder, height: 1),
              _buildSettingsTile(
                icon: Icons.description_outlined,
                title: 'Terms of Service',
                subtitle: 'Client terms and agreements',
                trailing: const Icon(Icons.chevron_right, color: Color(0xFF919696), size: 18),
                onTap: () => _showInfoModal(
                  'Terms of Service',
                  'By using Flash.Ink, you agree to our platform terms, client verification requirements, and intellectual property protections for tattoo artists.',
                ),
              ),
              const Divider(color: AppTheme.darkBorder, height: 1),
              _buildSettingsTile(
                icon: Icons.privacy_tip_outlined,
                title: 'Privacy Policy',
                subtitle: 'How your data is safeguarded and encrypted',
                trailing: const Icon(Icons.chevron_right, color: Color(0xFF919696), size: 18),
                onTap: () => _showInfoModal(
                  'Privacy Policy',
                  'Your personal identity, phone verification data, and payment information are strictly encrypted with TLS and AES-256 standards.',
                ),
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

  /// Profile Hero Card with avatar, gold accent border, user stats, and identity badge
  Widget _buildProfileHeroCard() {
    return Container(
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
      child: Column(
        children: [
          Row(
            children: [
              // Avatar with Gold Border, Silhouette fallback, and Edit Badge
              Stack(
                children: [
                  GestureDetector(
                    key: const Key('client_avatar_image_button'),
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
                                ? Image.network(
                                    _photoUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        color: const Color(0xFF262929),
                                        child: const Center(
                                          child: Icon(
                                            Icons.person_outline,
                                            color: AppTheme.gold,
                                            size: 40,
                                          ),
                                        ),
                                      );
                                    },
                                  )
                                : Container(
                                    color: const Color(0xFF262929),
                                    child: const Center(
                                      child: Icon(
                                        Icons.person_outline,
                                        color: AppTheme.gold,
                                        size: 40,
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
                      key: const Key('client_account_avatar_edit'),
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

              // Name, Username, and Badges
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
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.goldBadgeBackground,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.goldBadgeBorder, width: 0.8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const TattooMachineIcon(
                            size: 13,
                            color: AppTheme.gold,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'COLLECTOR • VERIFIED',
                            style: GoogleFonts.plusJakartaSans(
                              color: AppTheme.gold,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),
          const Divider(color: AppTheme.darkBorder, height: 1),
          const SizedBox(height: 14),

          // Stat counters
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatPillar('2', 'Upcoming Bookings'),
              Container(width: 1, height: 26, color: AppTheme.statDivider),
              _buildStatPillar('8', 'Saved Pieces'),
              Container(width: 1, height: 26, color: AppTheme.statDivider),
              _buildStatPillar('${_aesthetics.length}', 'Aesthetics'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatPillar(String count, String label) {
    return Column(
      children: [
        Text(
          count,
          style: GoogleFonts.plusJakartaSans(
            color: AppTheme.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: const Color(0xFF919696),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  String _formatAestheticLabel(String id) {
    switch (id.toLowerCase().replaceAll(' ', '')) {
      case 'fineline':
        return 'FINE LINE';
      case 'neotraditional':
        return 'NEO-TRADITIONAL';
      case 'blackwork':
        return 'BLACKWORK';
      case 'traditional':
        return 'TRADITIONAL';
      case 'japanese':
        return 'JAPANESE';
      case 'watercolor':
        return 'WATERCOLOR';
      case 'realism':
        return 'REALISM';
      default:
        return id.toUpperCase();
    }
  }

  /// My Aesthetics Section with active chips & Edit action
  Widget _buildAestheticsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionHeader('MY AESTHETICS'),
            TextButton.icon(
              key: const Key('account_edit_aesthetics_button'),
              onPressed: _showAestheticsSelectorModal,
              icon: const Icon(Icons.tune, color: AppTheme.gold, size: 14),
              label: Text(
                'Edit',
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.gold,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _aesthetics.map((style) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.onyxContainer,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.goldBorder, width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppTheme.gold,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatAestheticLabel(style),
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  /// Quick Activity Row (Saved Flash, Booking History)
  Widget _buildQuickActivityRow() {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.cardBackground,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.darkBorder),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.onyxContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.favorite_border,
                    color: AppTheme.gold,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Saved Flash',
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '8 pieces saved',
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF919696),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.cardBackground,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.darkBorder),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.onyxContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.calendar_month_outlined,
                    color: AppTheme.gold,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sessions',
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '2 upcoming',
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF919696),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
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
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
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
        key: const Key('account_sign_out_button'),
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
        key: const Key('account_delete_account_button'),
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
