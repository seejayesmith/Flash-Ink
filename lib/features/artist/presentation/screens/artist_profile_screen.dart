import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../providers/app_providers.dart';
import '../../../../screens/custom_request_screen.dart';
import '../../../../screens/flash_details_screen.dart';
import '../../../../widgets/guest_auth_prompt_bottom_sheet.dart';
import '../../../../services/booking_sync_service.dart';
import '../../../../theme/app_radius.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_theme.dart';
import '../../../../theme/app_typography.dart';
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

  const ArtistProfileScreen({
    super.key,
    required this.artist,
    this.isVipEarlyAccess = false,
  });

  @override
  Widget build(BuildContext context) {
    final content = _ArtistProfileContent(
      artist: artist,
      isVipEarlyAccess: isVipEarlyAccess,
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

  const _ArtistProfileContent({
    required this.artist,
    required this.isVipEarlyAccess,
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

  @override
  Widget build(BuildContext context) {
    final liveArtistAsync =
        ref.watch(artistDetailWithDistanceProvider(widget.artist.id));
    final clientCoords = ref.watch(effectiveClientCoordinatesProvider);
    final effectiveArtist = liveArtistAsync.maybeWhen(
      data: (live) => live ?? widget.artist.withLiveDistanceFrom(clientCoords),
      orElse: () => widget.artist.withLiveDistanceFrom(clientCoords),
    );

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
