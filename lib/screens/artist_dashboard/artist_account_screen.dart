import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../core/mock/mock_data_config.dart';
import '../../models/artist.dart';
import '../../config/dev_config.dart';
import '../../providers/app_providers.dart';
import '../../repositories/artist_repository.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/flash_switch.dart';
import '../../widgets/flash_image.dart';
import '../../widgets/flash_snack_bar.dart';
import '../../widgets/inline_phone_verification_tile.dart';
import '../../widgets/photo_source_bottom_sheet.dart';
import 'artist_edit_profile_screen.dart';
import 'artist_account_settings_screen.dart';
import '../location_settings_screen.dart';
import '../app_info_screen.dart';
import '../main_feed_screen.dart';
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
  final FirebaseFirestore? firestore;

  const ArtistAccountScreen({
    super.key,
    this.artist,
    this.authService,
    this.firestore,
  });

  @override
  State<ArtistAccountScreen> createState() => _ArtistAccountScreenState();
}

class _ArtistAccountScreenState extends State<ArtistAccountScreen> {
  late final AuthService _authService = widget.authService ?? AuthService();

  FirebaseFirestore _resolveFirestore() {
    if (widget.firestore != null) return widget.firestore!;
    if (mounted) {
      try {
        final injected = ProviderScope.containerOf(
          context,
          listen: false,
        ).read(firebaseFirestoreProvider);
        if (injected != null) return injected;
      } catch (_) {}
    }
    return FirebaseFirestore.instance;
  }

  Future<void> _handleSwitchToClientMode() async {
    final user = _authService.currentUser;
    await AuthService.setActiveAppMode(
      'client',
      uid: user?.uid,
      firestore: _resolveFirestore(),
    );
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => MainFeedScreen(authService: _authService),
      ),
      (route) => false,
    );
  }

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
    if (widget.artist != null) {
      final effective = widget.artist!;
      _displayName = effective.name.isNotEmpty
          ? (effective.name.startsWith('@')
              ? effective.name.substring(1)
              : effective.name)
          : 'Artist';
      _username = effective.username.isNotEmpty
          ? effective.username.replaceAll('@', '')
          : _displayName.toLowerCase().replaceAll(' ', '_').replaceAll('@', '');
      _bio = effective.bio;
      _location = effective.location;
      String? fallbackPhoto;
      try {
        fallbackPhoto = _authService.currentUser?.photoURL;
      } catch (_) {}
      _photoUrl = effective.avatarUrl.isNotEmpty
          ? effective.avatarUrl
          : ((fallbackPhoto != null && fallbackPhoto.isNotEmpty)
              ? fallbackPhoto
              : null);
      return;
    }

    final user = _authService.currentUser;
    if (user != null &&
        user.displayName != null &&
        user.displayName!.trim().isNotEmpty) {
      final cleanName = user.displayName!.trim();
      _displayName =
          cleanName.startsWith('@') ? cleanName.substring(1) : cleanName;
      _username =
          _displayName.toLowerCase().replaceAll(' ', '_').replaceAll('@', '');
      _bio = MockDataConfig.isEnabled
          ? 'Resident artist specializing in flash & custom illustrative blackwork.'
          : '';
      _location = MockDataConfig.isEnabled ? 'Portland, OR • Flash & Custom' : '';
      _photoUrl = (user.photoURL != null && user.photoURL!.isNotEmpty)
          ? user.photoURL
          : null;
      return;
    }

    if (MockDataConfig.isEnabled) {
      final mock = Artist.mockArtists.firstWhere(
        (a) => a.name.toLowerCase() == 'oddmaree',
        orElse: () => Artist.mockArtists.first,
      );
      _displayName = 'OddMaree';
      _username = 'oddmaree';
      _bio = mock.bio;
      _location = mock.location;
      _photoUrl = mock.avatarUrl;
    } else {
      _displayName = 'Artist';
      _username = 'artist';
      _bio = '';
      _location = '';
      _photoUrl = null;
    }
  }

  Artist _getEffectiveArtist() {
    String? fallbackAuthPhoto;
    try {
      fallbackAuthPhoto = _authService.currentUser?.photoURL;
    } catch (_) {}
    final effectiveAvatar = _photoUrl ?? fallbackAuthPhoto ?? '';

    if (widget.artist != null) {
      return widget.artist!.copyWith(
        name: _displayName,
        username: _username,
        bio: _bio,
        location: _location,
        avatarUrl: effectiveAvatar,
      );
    }
    if (MockDataConfig.isEnabled) {
      return Artist.mockArtists.firstWhere(
        (a) => a.name.toLowerCase() == 'oddmaree',
        orElse: () => Artist.mockArtists.first,
      );
    }
    final user = _authService.currentUser;
    return Artist(
      id: user?.uid ?? 'live_artist',
      name: _displayName,
      username: _username,
      avatarUrl: effectiveAvatar,
      location: _location,
      studioType: 'Independent Artist',
      bio: _bio,
      rating: 5.0,
      availablePieces: 0,
      minDeposit: 50,
      images: const [],
    );
  }

  Future<void> _loadUserProfile() async {
    final user = _authService.currentUser;
    if (user != null) {
      if (mounted) {
        setState(() {
          try {
            if (user.displayName != null && user.displayName!.isNotEmpty) {
              _displayName = user.displayName!;
            }
          } catch (_) {}
          try {
            if (user.email != null && user.email!.isNotEmpty) {
              _email = user.email!;
            }
          } catch (_) {}
          try {
            if (user.photoURL != null && user.photoURL!.isNotEmpty) {
              _photoUrl = user.photoURL;
            }
          } catch (_) {}
          String? uPhone;
          try {
            uPhone = user.phoneNumber;
          } catch (_) {}
          final isGoogle = AuthService.isGoogleAuthUser(user);
          if (isGoogle) {
            _phoneNumber = '';
            _phoneVerified = false;
          } else if (uPhone != null && uPhone.isNotEmpty) {
            _phoneNumber = uPhone;
            _phoneVerified = true;
          }
        });
      }

      try {
        final db = _resolveFirestore();
        // Attempt reading from artists collection first
        final artistDoc = await db
            .collection('artists')
            .doc(user.uid)
            .get();

        String? artistStoredPhoto;
        if (artistDoc.exists && artistDoc.data() != null && mounted) {
          final data = artistDoc.data()!;
          final photo = data['avatarUrl'] ?? data['photoUrl'] ?? data['photoURL'];
          if (photo is String && photo.trim().isNotEmpty) {
            artistStoredPhoto = photo.trim();
          }
          setState(() {
            if (data['name'] != null && (data['name'] as String).isNotEmpty) {
              final rawName = data['name'] as String;
              _displayName = rawName.startsWith('@') ? rawName.substring(1) : rawName;
            }
            if (data['username'] != null && (data['username'] as String).isNotEmpty) {
              _username = (data['username'] as String).replaceAll('@', '');
            }
            if (data['bio'] != null && (data['bio'] as String).isNotEmpty) {
              _bio = data['bio'] as String;
            }
            if (data['location'] != null && (data['location'] as String).isNotEmpty) {
              _location = data['location'] as String;
            }
            if (artistStoredPhoto != null && artistStoredPhoto.isNotEmpty) {
              _photoUrl = artistStoredPhoto;
            }
          });
        }

        // Read private artist contact details from isolated /artists/{uid}/private/settings subcollection
        final privateSettingsDoc = await db
            .collection('artists')
            .doc(user.uid)
            .collection('private')
            .doc('settings')
            .get();

        if (privateSettingsDoc.exists && privateSettingsDoc.data() != null && mounted) {
          final privateData = privateSettingsDoc.data()!;
          setState(() {
            if (privateData['email'] != null && (privateData['email'] as String).isNotEmpty) {
              _email = privateData['email'] as String;
            }
            if (privateData['phoneNumber'] != null && (privateData['phoneNumber'] as String).isNotEmpty) {
              _phoneNumber = privateData['phoneNumber'] as String;
            }
          });
        }

        // Also check users collection for fallback / verified flags
        final userDoc = await db
            .collection('users')
            .doc(user.uid)
            .get();
        if (userDoc.exists && userDoc.data() != null && mounted) {
          final uData = userDoc.data()!;
          final uPhoto = uData['photoUrl'] ?? uData['photoURL'] ?? uData['avatarUrl'];
          setState(() {
            if ((_photoUrl == null || _photoUrl!.isEmpty) &&
                uPhoto is String &&
                uPhoto.trim().isNotEmpty) {
              _photoUrl = uPhoto.trim();
            }
            if (uData['phoneVerified'] != null) {
              _phoneVerified = uData['phoneVerified'] as bool;
            }
            if (uData['email'] != null && (uData['email'] as String).isNotEmpty && (_email.isEmpty || _email == 'artist@flash.ink')) {
              _email = uData['email'] as String;
            }
            if (uData['phoneNumber'] != null && (uData['phoneNumber'] as String).isNotEmpty && (_phoneNumber.isEmpty || _phoneNumber == '+1 (555) 345-6789')) {
              _phoneNumber = uData['phoneNumber'] as String;
            }
          });
        }

        // Backfill /artists/{uid} if artist document exists without avatarUrl while account has a unified photo
        if (artistDoc.exists &&
            (artistStoredPhoto == null || artistStoredPhoto.isEmpty) &&
            _photoUrl != null &&
            _photoUrl!.trim().isNotEmpty) {
          await ArtistRepository.syncUnifiedProfilePhoto(
            uid: user.uid,
            photoUrl: _photoUrl!.trim(),
            firestore: db,
            createArtistIfMissing: true,
          );
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
        final db = _resolveFirestore();
        await db.collection('artists').doc(user.uid).set({
          'id': user.uid,
          'name': name,
          'username': username,
          'bio': bio,
          'location': location,
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
        try {
          await FirebaseStorage.instance.ref().child('user_profiles/${user.uid}.png').delete();
        } catch (_) {}
        try {
          await FirebaseStorage.instance.ref().child('user_profiles/${user.uid}.jpg').delete();
        } catch (_) {}

        await user.updatePhotoURL(null);
        try {
          await user.reload();
        } catch (_) {}
        final isTest = WidgetsBinding.instance.runtimeType.toString().contains('Test');
        final timeoutDuration = isTest ? const Duration(milliseconds: 500) : const Duration(seconds: 10);
        await ArtistRepository.syncUnifiedProfilePhoto(
          uid: user.uid,
          photoUrl: null,
          firestore: _resolveFirestore(),
          createArtistIfMissing: true,
          timeout: timeoutDuration,
        );

        if (mounted) {
          setState(() {
            _photoUrl = null;
            _isUploadingPhoto = false;
          });
          FlashSnackBar.showSuccess(context, 'Artist profile photo removed');
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isUploadingPhoto = false);
          FlashSnackBar.showError(context, 'Failed to remove photo: $e');
        }
      }
      return;
    }

    if (result.croppedBytes != null) {
      setState(() => _isUploadingPhoto = true);
      try {
        String downloadUrl;
        try {
          final storageRef = FirebaseStorage.instance
              .ref()
              .child('artist_profiles')
              .child('${user.uid}.png');

          await storageRef.putData(
            result.croppedBytes!,
            SettableMetadata(contentType: 'image/png'),
          );
          downloadUrl = await storageRef.getDownloadURL();
        } catch (storageErr) {
          if (kEnableDevBypass || user is DevMockUser) {
            downloadUrl = 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=400&q=80';
          } else {
            rethrow;
          }
        }

        await user.updatePhotoURL(downloadUrl);
        try {
          await user.reload();
        } catch (_) {}
        final isTest = WidgetsBinding.instance.runtimeType.toString().contains('Test');
        final timeoutDuration = isTest ? const Duration(milliseconds: 500) : const Duration(seconds: 10);
        await ArtistRepository.syncUnifiedProfilePhoto(
          uid: user.uid,
          photoUrl: downloadUrl,
          firestore: _resolveFirestore(),
          createArtistIfMissing: true,
          timeout: timeoutDuration,
        );

        if (mounted) {
          setState(() {
            _photoUrl = downloadUrl;
            _isUploadingPhoto = false;
          });
          FlashSnackBar.showSuccess(context, 'Artist profile photo updated successfully');
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isUploadingPhoto = false);
          FlashSnackBar.showError(context, 'Failed to update photo: $e');
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
              _displayName = newUsername;
              _username = newUsername;
              _bio = newBio;
              _location = newLocation;
            });

            await _updateProfileInFirestore(
              name: newUsername,
              username: newUsername,
              bio: newBio,
              location: newLocation,
            );
          },
        ),
      ),
    );

    if (result != null && mounted) {
      final updatedUsername = result['username'] ?? (result['name'] ?? _username);
      setState(() {
        _displayName = updatedUsername;
        _username = updatedUsername;
        _bio = result['bio'] ?? _bio;
        _location = result['location'] ?? _location;
      });

      FlashSnackBar.showSuccess(
        context,
        'Profile updated successfully',
        duration: const Duration(seconds: 2),
      );
    }
  }

  void _navigateToPublicProfile() {
    final effectiveArtist = _getEffectiveArtist();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ArtistProfileScreen(
          artist: effectiveArtist,
          isOwner: true,
          authService: _authService,
          firestore: _resolveFirestore(),
        ),
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
          authService: _authService,
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
        invalidateUserSessionFromContext(context);
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const SplashScreen()),
          (route) => false,
        );
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

            // Client Persona Switcher
            _buildSectionHeader('CLIENT MODE'),
            const SizedBox(height: 10),
            _buildSettingsContainer([
              _buildSettingsTile(
                key: const Key('switch_to_client_mode_button'),
                icon: Icons.swap_horiz_rounded,
                title: 'Switch to Client Mode',
                subtitle: 'Browse artists, explore flash drops & book tattoos',
                trailing: const Icon(
                  Icons.chevron_right,
                  color: AppTheme.gold,
                  size: 18,
                ),
                onTap: _handleSwitchToClientMode,
              ),
            ]),

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
              InlinePhoneVerificationTile(
                phoneNumber: _phoneNumber,
                phoneVerified: _phoneVerified,
                authService: _authService,
                firestore: _resolveFirestore(),
                isArtist: true,
                onPhoneVerified: (newPhone) {
                  setState(() {
                    _phoneNumber = newPhone;
                    _phoneVerified = true;
                  });
                },
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
                key: const Key('artist_location_permissions_tile'),
                icon: Icons.location_on_outlined,
                title: 'Location Permissions',
                subtitle: 'Manage app location access & device permissions',
                trailing: const Icon(Icons.chevron_right, color: Color(0xFF919696), size: 18),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LocationSettingsScreen(),
                    ),
                  );
                },
              ),
              const Divider(color: AppTheme.darkBorder, height: 1),
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

            // Account Actions: Sign Out
            _buildSignOutButton(),

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

            SizedBox(height: bottomInset + 16),
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
}
