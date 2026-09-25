import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../models/artist.dart';
import '../../../../screens/splash_screen.dart';
import '../../../../screens/client_account_screen.dart';
import '../../../../services/auth_service.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_theme.dart';
import '../widgets/discover_trending_artists.dart';
import '../widgets/featured_artist_spotlight.dart';
import '../widgets/trending_flash_grid.dart';

/// DiscoverScreen (Home Feed):
/// CustomScrollView with slivers displaying:
/// - Row 1: Trending artists in the local area
/// - Row 2: Featured artist spotlight (not location based)
/// - Row 3+: Trending flash drops grid
class DiscoverScreen extends StatefulWidget {
  final List<Artist>? mockArtists;
  final AuthService? authService;

  const DiscoverScreen({
    super.key,
    this.mockArtists,
    this.authService,
  });

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  late final List<Artist> _artists;
  late final AuthService _authService;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _artists = widget.mockArtists ?? List.from(Artist.mockArtists);
    _authService = widget.authService ?? AuthService();
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

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final trendingArtists = _artists.take(5).toList();
    final featuredArtist = _artists.length > 1 ? _artists[1] : _artists.first;
    final allPieces = FlashArtwork.mockFlashPieces;

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
                  'FLASH',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
                Text(
                  '.INK',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.gold,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
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
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ClientAccountScreen(
                        authService: widget.authService,
                      ),
                    ),
                  );
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
                    child: Image.network(
                      'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=200&q=80',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: const Color(0xFF262929),
                          child: const Icon(
                            Icons.person,
                            color: Color(0xFFEEC200),
                            size: 18,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
            ],
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 12)),

          // Row 1: Trending artists in the local area
          SliverToBoxAdapter(
            child: DiscoverTrendingArtists(artists: trendingArtists),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),

          // Row 2: Featured artist spotlight
          SliverToBoxAdapter(
            child: FeaturedArtistSpotlight(artist: featuredArtist),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 28)),

          // Row 3+: Trending flash drops grid
          SliverToBoxAdapter(
            child: TrendingFlashGrid(flashPieces: allPieces),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 36)),

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
