import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../models/artist.dart';
import '../../../../screens/splash_screen.dart';
import '../../../../screens/client_account_screen.dart';
import '../../../../services/auth_service.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_theme.dart';
import '../../domain/models/explore_studio.dart';
import '../widgets/discover_trending_artists.dart';
import '../widgets/featured_artist_spotlight.dart';
import '../widgets/trending_studios_section.dart';

/// ExploreScreen (Search & Discovery):
/// - Standalone search bar
/// - Trending artists in the local area
/// - Featured artist spotlight
/// - Trending shops or studios
class ExploreScreen extends StatefulWidget {
  final List<Artist>? mockArtists;
  final List<ExploreStudio>? mockStudios;
  final AuthService? authService;

  const ExploreScreen({
    super.key,
    this.mockArtists,
    this.mockStudios,
    this.authService,
  });

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  late final List<Artist> _artists;
  late final List<ExploreStudio> _studios;
  late final AuthService _authService;
  bool _isDeleting = false;
  String? _photoUrl;
  
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _artists = widget.mockArtists ?? List.from(Artist.mockArtists);
    _studios = widget.mockStudios ?? List.from(ExploreStudio.mockStudios);
    _authService = widget.authService ?? AuthService();
    _loadUserProfile();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    try {
      final user = _authService.currentUser;
      if (user != null) {
        if (mounted) {
          setState(() {
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
            if (data['photoURL'] != null && (data['photoURL'] as String).isNotEmpty) {
              setState(() {
                _photoUrl = data['photoURL'] as String;
              });
            }
          }
        } catch (_) {}
      }
    } catch (_) {}
  }

  Future<void> _handleDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E2020),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Center(
            child: Text(
              'Delete Account',
              key: const Key('delete_account_modal_title'),
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFFF9FAFA),
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
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
      await _performDeleteAccount();
    }
  }

  Future<void> _performDeleteAccount() async {
    setState(() => _isDeleting = true);
    try {
      await _authService.deleteAccount();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Account deleted. A confirmation email has been sent.',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            backgroundColor: const Color(0xFF22C55E),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const SplashScreen()),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String errorMessage;
        if (e.code == 'requires-recent-login') {
          errorMessage = 'Please sign in again before deleting your account.';
        } else {
          errorMessage = e.message ?? 'Failed to delete account. Please try again.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              errorMessage,
              style: GoogleFonts.plusJakartaSans(color: Colors.white),
            ),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to delete account. Please try again.',
              style: GoogleFonts.plusJakartaSans(color: Colors.white),
            ),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  List<Artist> get _filteredArtists {
    if (_searchQuery.isEmpty) return _artists;
    final lowerQuery = _searchQuery.toLowerCase();
    return _artists.where((artist) {
      return artist.name.toLowerCase().contains(lowerQuery) ||
             artist.location.toLowerCase().contains(lowerQuery) ||
             artist.studioType.toLowerCase().contains(lowerQuery) ||
             artist.tags.any((t) => t.toLowerCase().contains(lowerQuery));
    }).toList();
  }

  List<ExploreStudio> get _filteredStudios {
    if (_searchQuery.isEmpty) return _studios;
    final lowerQuery = _searchQuery.toLowerCase();
    return _studios.where((studio) {
      return studio.name.toLowerCase().contains(lowerQuery) ||
             studio.address.toLowerCase().contains(lowerQuery) ||
             studio.city.toLowerCase().contains(lowerQuery) ||
             studio.styles.any((s) => s.toLowerCase().contains(lowerQuery));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final filteredArtists = _filteredArtists;
    final trendingArtists = filteredArtists.take(5).toList();
    final featuredArtist = filteredArtists.length > 1 ? filteredArtists[1] : (filteredArtists.isNotEmpty ? filteredArtists.first : null);
    final studios = _filteredStudios;

    return Scaffold(
      backgroundColor: AppTheme.onyxBackground,
      body: CustomScrollView(
        slivers: [
          // Sticky / Floating Header
          SliverAppBar(
            backgroundColor: AppTheme.onyxBackground,
            elevation: 0,
            scrolledUnderElevation: 0,
            floating: true,
            pinned: false,
            snap: true,
            systemOverlayStyle: const SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.light,
            ),
            title: Row(
              children: [
                Text(
                  'Explore',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.onyxContainer,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.darkBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_on, color: AppTheme.gold, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        'Los Angeles',
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.textPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications_none_rounded, color: AppTheme.textPrimary),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('No new notifications'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
              ),
              GestureDetector(
                key: const Key('discover_avatar_button'),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ClientAccountScreen(
                        authService: widget.authService,
                      ),
                    ),
                  );
                  _loadUserProfile();
                },
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.goldBorder,
                      width: 1.5,
                    ),
                  ),
                  child: ClipOval(
                    child: _photoUrl != null && _photoUrl!.isNotEmpty
                        ? Image.network(
                            _photoUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Center(
                                child: Icon(Icons.person, size: 18),
                              );
                            },
                          )
                        : const Center(
                            child: Icon(Icons.person, size: 18),
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
            ],
          ),

          // Standalone Search Bar
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spaceLg, vertical: 10),
              child: Container(
                height: 46,
                decoration: BoxDecoration(
                  color: AppTheme.cardBackground,
                  borderRadius: BorderRadius.circular(23),
                  border: Border.all(color: AppTheme.cardBorder, width: 1.2),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search artists, styles, studios...',
                    hintStyle: GoogleFonts.plusJakartaSans(
                      color: AppTheme.navInactive,
                      fontSize: 13,
                    ),
                    prefixIcon: const Icon(Icons.search, color: AppTheme.gold, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close, color: AppTheme.navInactive, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 20)),

          // Row 1: Trending artists in the local area
          if (trendingArtists.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: DiscoverTrendingArtists(artists: trendingArtists),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
          ],

          // Row 2: Featured artist spotlight
          if (featuredArtist != null) ...[
            SliverToBoxAdapter(
              child: FeaturedArtistSpotlight(artist: featuredArtist),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
          ],

          // Row 3+: Trending shops or studios
          if (studios.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: TrendingStudiosSection(studios: studios),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
          ],
          
          if (trendingArtists.isEmpty && studios.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text(
                  'No results found for "$_searchQuery"',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.navInactive,
                    fontSize: 14,
                  ),
                ),
              ),
            ),

          // Delete Account Button for Account Lifecycle & Compliance
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spaceLg),
              child: Center(
                child: TextButton(
                  key: const Key('delete_account_button'),
                  onPressed: _isDeleting ? null : _handleDeleteAccount,
                  child: _isDeleting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFFEF4444),
                          ),
                        )
                      : Text(
                          'Delete Account',
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFFEF4444),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                ),
              ),
            ),
          ),

          // Safe area bottom inset clearance for floating nav bar
          SliverToBoxAdapter(
            child: SizedBox(
              height: AppSpacing.spaceXxl + AppTheme.navBarHeight + bottomInset,
            ),
          ),
        ],
      ),
    );
  }
}
