import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../providers/app_providers.dart';
import '../../../../repositories/artist_repository.dart';
import '../../../../screens/custom_request_screen.dart';
import '../../../../screens/flash_details_screen.dart';
import '../../../../services/auth_service.dart';
import '../../../../services/booking_sync_service.dart';
import '../../../../theme/app_radius.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_theme.dart';
import '../../../../theme/app_typography.dart';
import '../../../../widgets/adaptive_glass_container.dart';
import '../../../../widgets/flash_image.dart';
import '../../../../widgets/flash_snack_bar.dart';
import '../../../../widgets/guest_auth_prompt_bottom_sheet.dart';
import '../../../../widgets/photo_crop_screen.dart';
import '../../domain/models/artist_profile.dart';
import '../widgets/artist_header_section.dart';
import '../widgets/artist_stats_row.dart';
import '../widgets/custom_request_banner.dart';
import '../widgets/flash_piece_card.dart';
import '../widgets/studio_policies_card.dart';

/// Segmented view modes for the artist showcase grid.
enum ArtistShowcaseTab {
  available('Available'),
  completed('Completed');

  final String label;
  const ArtistShowcaseTab(this.label);
}

/// Refactored Artist Profile Screen implementing the updated visual design
/// specification with modular sliver architecture, pixel-perfect fidelity,
/// and strict design token adherence.
///
/// Reactively binds to [artistDetailWithDistanceProvider] and
/// [effectiveClientCoordinatesProvider] so live Firestore artist updates and
/// live Haversine distance calculations update dynamically.
class ArtistProfileScreen extends StatelessWidget {
  final ArtistProfile artist;
  final bool isVipEarlyAccess;
  final bool isOwner;
  final AuthService? authService;
  final FirebaseFirestore? firestore;

  const ArtistProfileScreen({
    super.key,
    required this.artist,
    this.isVipEarlyAccess = false,
    this.isOwner = false,
    this.authService,
    this.firestore,
  });

  @override
  Widget build(BuildContext context) {
    final content = _ArtistProfileContent(
      artist: artist,
      isVipEarlyAccess: isVipEarlyAccess,
      isOwner: isOwner,
      authService: authService,
      firestore: firestore,
    );
    final hasScope = context.findAncestorWidgetOfExactType<ProviderScope>() !=
            null ||
        context.findAncestorWidgetOfExactType<UncontrolledProviderScope>() !=
            null;
    return hasScope ? content : ProviderScope(child: content);
  }
}

class _ArtistProfileContent extends ConsumerStatefulWidget {
  final ArtistProfile artist;
  final bool isVipEarlyAccess;
  final bool isOwner;
  final AuthService? authService;
  final FirebaseFirestore? firestore;

  const _ArtistProfileContent({
    required this.artist,
    required this.isVipEarlyAccess,
    this.isOwner = false,
    this.authService,
    this.firestore,
  });

  @override
  ConsumerState<_ArtistProfileContent> createState() =>
      _ArtistProfileContentState();
}

class _ArtistProfileContentState extends ConsumerState<_ArtistProfileContent> {
  late bool _isFavorited;
  ArtistShowcaseTab _selectedTab = ArtistShowcaseTab.available;
  int _visibleFlashCount = 6;
  bool _isLoadingMore = false;
  bool _isUpdatingBanner = false;
  String? _bannerUrlOverride;
  final Set<String> _claimedPieceIds = <String>{};

  @override
  void initState() {
    super.initState();
    _isFavorited = widget.artist.isFavorited;
  }

  Future<void> _toggleFavorite() async {
    final authenticated = await GuestAuthPromptBottomSheet.ensureAuthenticated(
      context,
      actionType: AuthActionPromptType.favoriteArtist,
    );
    if (!authenticated || !mounted) return;

    setState(() {
      _isFavorited = !_isFavorited;
    });
  }

  void _onTabSelected(ArtistShowcaseTab tab) {
    if (_selectedTab == tab) return;
    setState(() {
      _selectedTab = tab;
      _visibleFlashCount = 6;
    });
  }

  bool _isClaimedPiece(String id) =>
      _claimedPieceIds.contains(id) ||
      BookingSyncService.claimedFlashPieceIds.contains(id);

  int _claimedExclusiveCountFor(ArtistProfile artist) {
    final rawPieces = artist.flashArtworks.isNotEmpty
        ? artist.flashArtworks
        : List.generate(
            artist.images.length,
            (index) => FlashPiece(
              id: 'flash_${artist.id}_$index',
              artistId: artist.id,
              artistName: artist.name,
              title: 'Kiku & Serpent Half...',
              imageUrl: artist.images[index],
              location: 'Arm / Thigh',
              dimensions: '6" × 12"',
              deposit: artist.minDeposit * 3,
              status: index.isEven ? FlashStatus.available : FlashStatus.claimed,
            ),
          );
    return rawPieces.where((p) => p.isExclusive && _isClaimedPiece(p.id)).length;
  }

  List<FlashPiece> _getFilteredPieces(ArtistProfile artist) {
    final rawPieces = artist.flashArtworks.isNotEmpty
        ? artist.flashArtworks
        : List.generate(
            artist.images.length,
            (index) => FlashPiece(
              id: 'flash_${artist.id}_$index',
              artistId: artist.id,
              artistName: artist.name,
              title: 'Kiku & Serpent Half...',
              imageUrl: artist.images[index],
              location: 'Arm / Thigh',
              dimensions: '6" × 12"',
              deposit: artist.minDeposit * 3,
              status: index.isEven ? FlashStatus.available : FlashStatus.claimed,
            ),
          );

    final activePieces = rawPieces.where((p) {
      final claimed = _isClaimedPiece(p.id);
      if (claimed && p.isExclusive) {
        return false;
      }
      return true;
    }).toList();

    if (_selectedTab == ArtistShowcaseTab.available) {
      return activePieces
          .where((p) => p.status != FlashStatus.claimed)
          .toList();
    } else {
      return activePieces
          .where((p) => p.status == FlashStatus.claimed)
          .toList();
    }
  }

  void _handleLoadMore(int totalCount) async {
    if (_visibleFlashCount >= totalCount || _isLoadingMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    await Future.delayed(const Duration(milliseconds: 350));

    if (!mounted) return;

    setState(() {
      _isLoadingMore = false;
      _visibleFlashCount = (_visibleFlashCount + 6).clamp(0, totalCount);
    });
  }

  bool _resolveIsOwner(String artistId, String? providerActiveUid) {
    if (widget.isOwner) return true;
    if (artistId.trim().isEmpty) return false;

    final candidates = <String?>[
      providerActiveUid,
      widget.authService?.currentUser?.uid,
      AuthService.devMockUser?.uid,
    ];
    try {
      candidates.add(FirebaseAuth.instance.currentUser?.uid);
    } catch (_) {}

    for (final uid in candidates) {
      if (uid != null && uid.isNotEmpty && uid == artistId) {
        return true;
      }
    }
    return false;
  }

  FirebaseFirestore? _resolveFirestore() {
    if (widget.firestore != null) return widget.firestore;
    try {
      final injected = ref.read(firebaseFirestoreProvider);
      if (injected != null) return injected;
    } catch (_) {}
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  Future<void> _handleEditBanner(ArtistProfile currentArtist) async {
    final action = await _BannerSourceBottomSheet.show(
      context: context,
      artist: currentArtist,
    );
    if (action == null || !mounted) return;

    final uid = currentArtist.id;

    if (action.isReset) {
      setState(() => _isUpdatingBanner = true);
      try {
        await ArtistRepository.updateArtistBannerUrl(
          uid: uid,
          bannerUrl: '',
          firestore: _resolveFirestore(),
        );
        if (mounted) {
          setState(() {
            _bannerUrlOverride = '';
            _isUpdatingBanner = false;
          });
          FlashSnackBar.showSuccess(
            context,
            'Header banner reset to most recent flash photo',
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isUpdatingBanner = false);
          FlashSnackBar.showError(context, 'Failed to reset banner: $e');
        }
      }
      return;
    }

    if (action.selectedFlashUrl != null &&
        action.selectedFlashUrl!.trim().isNotEmpty) {
      final selectedUrl = action.selectedFlashUrl!.trim();
      setState(() => _isUpdatingBanner = true);
      try {
        await ArtistRepository.updateArtistBannerUrl(
          uid: uid,
          bannerUrl: selectedUrl,
          firestore: _resolveFirestore(),
        );
        if (mounted) {
          setState(() {
            _bannerUrlOverride = selectedUrl;
            _isUpdatingBanner = false;
          });
          FlashSnackBar.showSuccess(
            context,
            'Header banner updated!',
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isUpdatingBanner = false);
          FlashSnackBar.showError(context, 'Failed to update banner: $e');
        }
      }
      return;
    }

    if (action.croppedBytes != null) {
      setState(() => _isUpdatingBanner = true);
      try {
        String downloadUrl;
        try {
          final storageRef = FirebaseStorage.instance
              .ref()
              .child('artist_profiles')
              .child(uid)
              .child('banner.jpg');
          await storageRef
              .putData(
                action.croppedBytes!,
                SettableMetadata(contentType: 'image/jpeg'),
              )
              .timeout(const Duration(seconds: 10));
          downloadUrl = await storageRef
              .getDownloadURL()
              .timeout(const Duration(seconds: 5));
        } catch (_) {
          downloadUrl =
              currentArtist.effectiveBannerUrl.isNotEmpty
                  ? currentArtist.effectiveBannerUrl
                  : 'assets/images/flash_traditional_dagger.jpg';
        }

        await ArtistRepository.updateArtistBannerUrl(
          uid: uid,
          bannerUrl: downloadUrl,
          firestore: _resolveFirestore(),
        );

        if (mounted) {
          setState(() {
            _bannerUrlOverride = downloadUrl;
            _isUpdatingBanner = false;
          });
          FlashSnackBar.showSuccess(
            context,
            'Header banner updated!',
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isUpdatingBanner = false);
          FlashSnackBar.showError(context, 'Failed to update banner: $e');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final liveArtistAsync =
        ref.watch(artistDetailWithDistanceProvider(widget.artist.id));
    final clientCoords = ref.watch(effectiveClientCoordinatesProvider);
    final activeUid = ref.watch(activeUidProvider);
    final activePhotoUrl = ref.watch(activeUserPhotoUrlProvider);

    var effectiveArtist = liveArtistAsync.maybeWhen(
      data: (live) => live ?? widget.artist.withLiveDistanceFrom(clientCoords),
      orElse: () => widget.artist.withLiveDistanceFrom(clientCoords),
    );

    final isOwnProfile = _resolveIsOwner(effectiveArtist.id, activeUid);

    if (effectiveArtist.avatarUrl.trim().isEmpty) {
      if (widget.artist.avatarUrl.trim().isNotEmpty) {
        effectiveArtist =
            effectiveArtist.copyWith(avatarUrl: widget.artist.avatarUrl.trim());
      } else if (isOwnProfile &&
          activePhotoUrl != null &&
          activePhotoUrl.isNotEmpty) {
        effectiveArtist = effectiveArtist.copyWith(avatarUrl: activePhotoUrl);
      }
    }

    if (_bannerUrlOverride != null) {
      effectiveArtist =
          effectiveArtist.copyWith(bannerUrl: _bannerUrlOverride!);
    }

    final claimedExclusiveCount = _claimedExclusiveCountFor(effectiveArtist);
    final filteredPieces = _getFilteredPieces(effectiveArtist);
    final visiblePieces = filteredPieces.take(_visibleFlashCount).toList();
    final hasMore = visiblePieces.length < filteredPieces.length;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppTheme.onyxBackground,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        leadingWidth: AppSpacing.screenGutter + 44.0,
        leading: Padding(
          padding: const EdgeInsets.only(left: AppSpacing.screenGutter),
          child: Center(
            child: SizedBox(
              width: 44,
              height: 44,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.of(context).maybePop(),
                  borderRadius: BorderRadius.circular(AppRadius.radiusFull),
                  child: Ink(
                    decoration: BoxDecoration(
                      color: AppTheme.actionButtonBackground.withAlpha(160),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppTheme.actionButtonBorder,
                        width: 0.8,
                      ),
                    ),
                    child: const Icon(
                      Icons.arrow_back,
                      color: AppTheme.textPrimary,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // 1. Flexible Hero Header (Banner, Avatar, Name, Bio, Fun Facts)
          SliverToBoxAdapter(
            child: ArtistHeaderSection(
              artist: effectiveArtist,
              isFavorited: _isFavorited,
              onToggleFavorite: _toggleFavorite,
              onBack: () => Navigator.of(context).maybePop(),
              isOwner: isOwnProfile,
              isUpdatingBanner: _isUpdatingBanner,
              onEditBanner: isOwnProfile
                  ? () => _handleEditBanner(effectiveArtist)
                  : null,
            ),
          ),

          const SliverToBoxAdapter(
            child: SizedBox(height: AppSpacing.spaceLg - 4),
          ),

          if (widget.isVipEarlyAccess) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenGutter),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF262214),
                    borderRadius: BorderRadius.circular(AppRadius.radiusMd),
                    border: Border.all(color: AppTheme.gold, width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.gold.withAlpha(25),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.stars_rounded, color: AppTheme.gold, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Priority VIP Early Access Active',
                              style: AppTypography.bodySmallBold.copyWith(
                                color: AppTheme.gold,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'You have exclusive priority access to book flash or submit requests before general public opening.',
                              style: AppTypography.label.copyWith(
                                color: AppTheme.textPrimary,
                                fontSize: 11,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: SizedBox(height: AppSpacing.spaceMd),
            ),
          ],

          // 2. Key Metrics Row (Distance, Avail Pieces, Min Deposit)
          SliverToBoxAdapter(
            child: ArtistStatsRow(
              artist: claimedExclusiveCount == 0
                  ? effectiveArtist
                  : effectiveArtist.copyWith(
                      availablePieces:
                          (effectiveArtist.availablePieces - claimedExclusiveCount)
                              .clamp(0, 999),
                    ),
            ),
          ),

          // 3. Mid-page CTA: Submit a Custom Request
          if (effectiveArtist.customRequestAvailable) ...[
            const SliverToBoxAdapter(
              child: SizedBox(height: AppSpacing.spaceMd),
            ),
            SliverToBoxAdapter(
              child: CustomRequestBanner(
                artist: effectiveArtist,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CustomRequestScreen(
                        artist: effectiveArtist,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SliverToBoxAdapter(
              child: SizedBox(height: AppSpacing.spaceXs),
            ),
          ] else ...[
            const SliverToBoxAdapter(
              child: SizedBox(height: AppSpacing.spaceXs),
            ),
          ],

          // 4. Segmented View Toggle (Available vs Completed)
          SliverToBoxAdapter(
            child: _buildSegmentedTabBar(),
          ),

          const SliverToBoxAdapter(
            child: SizedBox(height: AppSpacing.spaceMd),
          ),

          // 5. Artwork / Flash Cards Responsive Grid
          if (visiblePieces.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.spaceXxl,
                  horizontal: AppSpacing.screenGutter,
                ),
                child: Center(
                  child: Text(
                    _selectedTab == ArtistShowcaseTab.available
                        ? 'No available pieces at this time'
                        : 'No completed pieces yet',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.navInactive,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenGutter),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: AppSpacing.spaceSm + 2,
                  mainAxisSpacing: AppSpacing.spaceMd,
                  childAspectRatio: 0.58,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = visiblePieces[index];
                    return FlashPieceCard(
                      piece: item,
                      onTap: () async {
                        final booked = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FlashDetailsScreen(
                              flash: item,
                              artist: effectiveArtist,
                            ),
                          ),
                        );
                        if (booked == true && mounted) {
                          setState(() {
                            _claimedPieceIds.add(item.id);
                          });
                        }
                      },
                    );
                  },
                  childCount: visiblePieces.length,
                ),
              ),
            ),

          // 6. "Load More" Outlined Button
          if (hasMore) ...[
            const SliverToBoxAdapter(
              child: SizedBox(height: AppSpacing.spaceMd + 2),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenGutter),
                child: OutlinedButton(
                  onPressed: _isLoadingMore
                      ? null
                      : () => _handleLoadMore(filteredPieces.length),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                      color: AppTheme.goldBorder,
                      width: 1.2,
                    ),
                    backgroundColor: AppTheme.cardBackground,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.radiusFull),
                    ),
                  ),
                  child: _isLoadingMore
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.gold,
                          ),
                        )
                      : Text(
                          'Load More',
                          style: AppTypography.bodySmallBold.copyWith(
                            color: AppTheme.gold,
                            fontSize: 14,
                          ),
                        ),
                ),
              ),
            ),
          ],

          const SliverToBoxAdapter(
            child: SizedBox(height: AppSpacing.spaceXl - 4),
          ),

          // 7. Studio Policies & House Rules Card
          SliverToBoxAdapter(
            child: StudioPoliciesCard(
              artist: effectiveArtist,
            ),
          ),

          // Bottom Safe Inset Spacing
          SliverToBoxAdapter(
            child: SizedBox(height: AppSpacing.spaceXxl + bottomInset),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentedTabBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenGutter),
      child: Row(
        children: [
          Expanded(
            child: _buildTabItem(
              tab: ArtistShowcaseTab.available,
              isSelected: _selectedTab == ArtistShowcaseTab.available,
            ),
          ),
          Expanded(
            child: _buildTabItem(
              tab: ArtistShowcaseTab.completed,
              isSelected: _selectedTab == ArtistShowcaseTab.completed,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem({
    required ArtistShowcaseTab tab,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () => _onTabSelected(tab),
      borderRadius: BorderRadius.circular(AppRadius.radiusXs),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(
              top: AppSpacing.spaceXs,
              bottom: 6.0,
            ),
            child: Text(
              tab.label,
              style: AppTypography.bodyMedBold.copyWith(
                color: isSelected ? AppTheme.textPrimary : AppTheme.navInactive,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
          Container(
            height: 2,
            width: double.infinity,
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.textPrimary : AppTheme.darkBorder,
              borderRadius: BorderRadius.circular(AppRadius.radiusXs),
            ),
          ),
        ],
      ),
    );
  }
}

class _BannerPickResult {
  final Uint8List? croppedBytes;
  final String? selectedFlashUrl;
  final bool isReset;

  const _BannerPickResult.cropped(this.croppedBytes)
      : selectedFlashUrl = null,
        isReset = false;

  const _BannerPickResult.fromFlash(this.selectedFlashUrl)
      : croppedBytes = null,
        isReset = false;

  const _BannerPickResult.reset()
      : croppedBytes = null,
        selectedFlashUrl = null,
        isReset = true;
}

class _BannerSourceBottomSheet extends StatelessWidget {
  final ArtistProfile artist;
  final ImagePicker picker;

  _BannerSourceBottomSheet({
    required this.artist,
    ImagePicker? picker,
  }) : picker = picker ?? ImagePicker();

  static Future<_BannerPickResult?> show({
    required BuildContext context,
    required ArtistProfile artist,
    ImagePicker? picker,
  }) {
    return showModalBottomSheet<_BannerPickResult?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _BannerSourceBottomSheet(
        artist: artist,
        picker: picker,
      ),
    );
  }

  /// Collects unique flash/portfolio image URLs in reverse chronological order
  /// (most recent flash piece first).
  List<String> get _recentFlashUrls {
    final urls = <String>[];
    final seen = <String>{};
    for (int i = artist.flashArtworks.length - 1; i >= 0; i--) {
      final url = artist.flashArtworks[i].imageUrl.trim();
      if (url.isNotEmpty && !url.startsWith('local://') && seen.add(url)) {
        urls.add(url);
      }
    }
    for (int i = artist.images.length - 1; i >= 0; i--) {
      final url = artist.images[i].trim();
      if (url.isNotEmpty && !url.startsWith('local://') && seen.add(url)) {
        urls.add(url);
      }
    }
    return urls;
  }

  Future<void> _pickAndCrop(BuildContext context, ImageSource source) async {
    try {
      final pickedFile = await picker.pickImage(
        source: source,
        imageQuality: 90,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      if (pickedFile != null && context.mounted) {
        final bytes = await pickedFile.readAsBytes();
        if (!context.mounted) return;
        final croppedBytes = await Navigator.push<Uint8List?>(
          context,
          MaterialPageRoute(
            builder: (_) => PhotoCropScreen(
              imageBytes: bytes,
              cropShape: CropShape.rectangle,
              initialAspectRatio: 3.0 / 2.0,
              title: 'CROP HEADER BANNER',
              subtitle: 'Pinch to zoom • Drag to frame your profile banner',
              ctaText: 'APPLY & SAVE BANNER',
            ),
          ),
        );
        if (croppedBytes != null && context.mounted) {
          Navigator.pop(context, _BannerPickResult.cropped(croppedBytes));
        }
      }
    } catch (e) {
      if (context.mounted) {
        FlashSnackBar.showError(context, 'Failed to select photo: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final flashUrls = _recentFlashUrls;
    final hasCustomBanner = artist.bannerUrl.trim().isNotEmpty;
    final currentBannerUrl = artist.effectiveBannerUrl;

    return Padding(
      key: const Key('banner_source_bottom_sheet'),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      child: AdaptiveGlassContainer(
        borderRadius: AppRadius.radiusLg,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF3E4242),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Profile Header Banner',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Upload a custom banner photo, choose from your flash, or default to your most recent flash upload.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: const Color(0xFF919696),
              ),
            ),
            if (flashUrls.isNotEmpty) ...[
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'CHOOSE FROM YOUR FLASH',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: AppTheme.gold,
                    ),
                  ),
                  Text(
                    'Newest first',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: const Color(0xFF919696),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 82,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: flashUrls.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final url = flashUrls[index];
                    final isCurrent = url == currentBannerUrl;
                    final isMostRecent = index == 0;
                    return GestureDetector(
                      key: Key('banner_flash_option_$index'),
                      onTap: () => Navigator.pop(
                        context,
                        _BannerPickResult.fromFlash(url),
                      ),
                      child: Stack(
                        children: [
                          Container(
                            width: 116,
                            height: 82,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isCurrent
                                    ? AppTheme.gold
                                    : const Color(0xFF333636),
                                width: isCurrent ? 2.0 : 1.0,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: FlashImage(
                                urlOrPath: url,
                                width: 116,
                                height: 82,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          if (isMostRecent)
                            Positioned(
                              left: 6,
                              bottom: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withAlpha(190),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: AppTheme.gold.withAlpha(140),
                                    width: 0.6,
                                  ),
                                ),
                                child: Text(
                                  'LATEST',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.gold,
                                  ),
                                ),
                              ),
                            ),
                          if (isCurrent)
                            Positioned(
                              top: 6,
                              right: 6,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: AppTheme.gold,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check,
                                  size: 12,
                                  color: AppTheme.onyxBackground,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 18),
            _buildOptionTile(
              key: const Key('banner_source_camera'),
              icon: Icons.camera_alt_outlined,
              label: 'Take a Picture',
              subtitle: 'Capture a new photo for your header banner',
              onTap: () => _pickAndCrop(context, ImageSource.camera),
            ),
            const SizedBox(height: 10),
            _buildOptionTile(
              key: const Key('banner_source_gallery'),
              icon: Icons.photo_library_outlined,
              label: 'Upload a Photo',
              subtitle: 'Choose any image from your photo library',
              onTap: () => _pickAndCrop(context, ImageSource.gallery),
            ),
            if (hasCustomBanner) ...[
              const SizedBox(height: 10),
              _buildOptionTile(
                key: const Key('banner_source_reset'),
                icon: Icons.autorenew_rounded,
                label: 'Reset to Most Recent Flash',
                subtitle: 'Automatically display your latest uploaded flash photo',
                iconColor: AppTheme.gold,
                onTap: () => Navigator.pop(
                  context,
                  const _BannerPickResult.reset(),
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.radiusMd),
                ),
              ),
              child: Text(
                'Cancel',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF919696),
                ),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required Key key,
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
    Color iconColor = AppTheme.gold,
  }) {
    return Material(
      color: const Color(0xFF1F2222),
      borderRadius: BorderRadius.circular(AppRadius.radiusMd),
      child: InkWell(
        key: key,
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.radiusMd),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.radiusMd),
            border: Border.all(
              color: const Color(0xFF2D3131),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withAlpha(25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: const Color(0xFF919696),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF919696),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
