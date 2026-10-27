import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../models/artist.dart';
import '../../../../models/user.dart';
import '../../../../providers/app_providers.dart';
import '../../../../screens/splash_screen.dart';
import '../../../../screens/client_account_screen.dart';
import '../../../../services/auth_service.dart';
import '../../../../widgets/flash_snack_bar.dart';
import '../../../../theme/app_radius.dart';
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
class ExploreScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final content = _ExploreScreenContent(
      mockArtists: mockArtists,
      mockStudios: mockStudios,
      authService: authService,
    );
    final hasScope = context.findAncestorWidgetOfExactType<ProviderScope>() !=
            null ||
        context.findAncestorWidgetOfExactType<UncontrolledProviderScope>() !=
            null;
    return hasScope ? content : ProviderScope(child: content);
  }
}

class _ExploreScreenContent extends ConsumerStatefulWidget {
  final List<Artist>? mockArtists;
  final List<ExploreStudio>? mockStudios;
  final AuthService? authService;

  const _ExploreScreenContent({
    required this.mockArtists,
    required this.mockStudios,
    required this.authService,
  });

  @override
  ConsumerState<_ExploreScreenContent> createState() =>
      _ExploreScreenContentState();
}

class _ExploreScreenContentState extends ConsumerState<_ExploreScreenContent> {
  AuthService get _authService =>
      widget.authService ?? ref.read(authServiceProvider);
  bool _isDeleting = false;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String? _resolveAvatarUrl(UserProfile? profile) {
    if (profile?.photoUrl != null && profile!.photoUrl!.isNotEmpty) {
      return profile.photoUrl;
    }
    try {
      final authPhoto = _authService.currentUser?.photoURL;
      if (authPhoto != null && authPhoto.isNotEmpty) {
        return authPhoto;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _handleDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E2020),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.radiusLg),
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
                  borderRadius: BorderRadius.circular(AppRadius.radiusSm),
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
        invalidateUserSessionProviders(ref);
        FlashSnackBar.showSuccess(
          context,
          'Account deleted. A confirmation email has been sent.',
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
        FlashSnackBar.showError(context, errorMessage);
      }
    } catch (_) {
      if (mounted) {
        FlashSnackBar.showError(
          context,
          'Failed to delete account. Please try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  List<Artist> _filterArtists(List<Artist> source) {
    if (_searchQuery.isEmpty) return source;
    final lowerQuery = _searchQuery.toLowerCase();
    return source.where((artist) {
      return artist.name.toLowerCase().contains(lowerQuery) ||
          artist.username.toLowerCase().contains(lowerQuery) ||
          artist.studioName.toLowerCase().contains(lowerQuery) ||
          artist.location.toLowerCase().contains(lowerQuery) ||
          artist.studioType.toLowerCase().contains(lowerQuery) ||
          artist.tags.any((t) => t.toLowerCase().contains(lowerQuery));
    }).toList();
  }

  List<ExploreStudio> _filterStudios(List<ExploreStudio> source) {
    if (_searchQuery.isEmpty) return source;
    final lowerQuery = _searchQuery.toLowerCase();
    return source.where((studio) {
      return studio.name.toLowerCase().contains(lowerQuery) ||
          studio.address.toLowerCase().contains(lowerQuery) ||
          studio.city.toLowerCase().contains(lowerQuery) ||
          studio.styles.any((s) => s.toLowerCase().contains(lowerQuery));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final useMock = ref.watch(mockModeProvider);
    final clientCoords = ref.watch(effectiveClientCoordinatesProvider);
    final userProfile = ref.watch(currentUserProfileProvider).maybeWhen(
          data: (u) => u,
          orElse: () => null,
        );
    final artistsAsync = ref.watch(artistsWithDistanceProvider);
    final studiosAsync = ref.watch(exploreStudiosProvider);

    final allArtists = widget.mockArtists != null
        ? widget.mockArtists!
            .map((a) => a.withLiveDistanceFrom(clientCoords))
            .toList(growable: false)
        : artistsAsync.maybeWhen(
            data: (list) => list,
            orElse: () => const <Artist>[],
          );

    final List<ExploreStudio> allStudios = widget.mockStudios ??
        studiosAsync.maybeWhen<List<ExploreStudio>>(
          data: (list) => list,
          orElse: () => const <ExploreStudio>[],
        );

    final headerLocation = (userProfile?.cityState != null &&
            userProfile!.cityState!.trim().isNotEmpty)
        ? userProfile.cityState!.split(',').first.trim()
        : (useMock ? 'Los Angeles' : 'All Locations');

    final avatarUrl = _resolveAvatarUrl(userProfile);
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final filteredArtists = _filterArtists(allArtists);
    final trendingArtists = filteredArtists.take(5).toList();
    final featuredArtist = filteredArtists.length > 1
        ? filteredArtists[1]
        : (filteredArtists.isNotEmpty ? filteredArtists.first : null);
    final studios = _filterStudios(allStudios);

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
            titleSpacing: AppSpacing.screenGutter,
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
                    borderRadius: BorderRadius.circular(AppRadius.radiusFull),
                    border: Border.all(color: AppTheme.darkBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_on, color: AppTheme.gold, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        headerLocation,
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
                  FlashSnackBar.showInfo(
                    context,
                    'No new notifications',
                    duration: const Duration(seconds: 1),
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
                  if (mounted) {
                    ref.invalidate(currentUserProfileProvider);
                    setState(() {});
                  }
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
                    child: avatarUrl != null && avatarUrl.isNotEmpty
                        ? Image.network(
                            avatarUrl,
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
              const SizedBox(width: AppSpacing.screenGutter),
            ],
          ),

          // Standalone Search Bar
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenGutter, vertical: 10),
              child: Container(
                height: 46,
                decoration: BoxDecoration(
                  color: AppTheme.cardBackground,
                  borderRadius: BorderRadius.circular(AppRadius.radiusFull),
                  border: Border.all(color: AppTheme.cardBorder, width: 1.2),
                ),
                child: TextField(
                  controller: _searchController,
                  textAlignVertical: TextAlignVertical.center,
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
                    isDense: true,
                    hintText: 'Search artists, styles, studios...',
                    hintStyle: GoogleFonts.plusJakartaSans(
                      color: AppTheme.navInactive,
                      fontSize: 13,
                    ),
                    prefixIcon: const Icon(Icons.search, color: AppTheme.gold, size: 20),
                    prefixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 46),
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
                    suffixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 46),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
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
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spaceXl),
                  child: Text(
                    _searchQuery.trim().isEmpty
                        ? 'No artists or studios available yet.'
                        : 'No results found for "$_searchQuery"',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.navInactive,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),

          // Delete Account Button for Account Lifecycle & Compliance
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenGutter),
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
