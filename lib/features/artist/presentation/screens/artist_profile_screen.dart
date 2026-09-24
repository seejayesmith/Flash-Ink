import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../screens/custom_request_screen.dart';
import '../../../../screens/flash_details_screen.dart';
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
class ArtistProfileScreen extends StatefulWidget {
  final ArtistProfile artist;

  const ArtistProfileScreen({
    super.key,
    required this.artist,
  });

  @override
  State<ArtistProfileScreen> createState() => _ArtistProfileScreenState();
}

class _ArtistProfileScreenState extends State<ArtistProfileScreen> {
  late bool _isFavorited;
  ArtistShowcaseTab _selectedTab = ArtistShowcaseTab.available;
  int _visibleFlashCount = 6;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _isFavorited = widget.artist.isFavorited;
  }

  void _toggleFavorite() {
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

  List<FlashPiece> _getFilteredPieces() {
    final allPieces = widget.artist.flashArtworks.isNotEmpty
        ? widget.artist.flashArtworks
        : List.generate(
            widget.artist.images.length,
            (index) => FlashPiece(
              id: 'flash_${widget.artist.id}_$index',
              artistId: widget.artist.id,
              artistName: widget.artist.name,
              title: 'Kiku & Serpent Half...',
              imageUrl: widget.artist.images[index],
              location: 'Arm / Thigh',
              dimensions: '6" × 12"',
              deposit: widget.artist.minDeposit * 3,
              status: index.isEven ? FlashStatus.available : FlashStatus.claimed,
            ),
          );

    if (_selectedTab == ArtistShowcaseTab.available) {
      final available = allPieces
          .where((p) => p.status != FlashStatus.claimed)
          .toList();
      return available.isNotEmpty ? available : allPieces;
    } else {
      final completed = allPieces
          .where((p) => p.status == FlashStatus.claimed)
          .toList();
      return completed.isNotEmpty ? completed : allPieces;
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
    final filteredPieces = _getFilteredPieces();
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
        leading: Padding(
          padding: const EdgeInsets.all(AppSpacing.spaceXs),
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
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // 1. Flexible Hero Header (Banner, Avatar, Name, Bio, Fun Facts)
          SliverToBoxAdapter(
            child: ArtistHeaderSection(
              artist: widget.artist,
              isFavorited: _isFavorited,
              onToggleFavorite: _toggleFavorite,
              onBack: () => Navigator.of(context).maybePop(),
            ),
          ),

          const SliverToBoxAdapter(
            child: SizedBox(height: AppSpacing.spaceLg - 4),
          ),

          // 2. Key Metrics Row (Rating, Avail Pieces, Min Deposit)
          SliverToBoxAdapter(
            child: ArtistStatsRow(
              artist: widget.artist,
            ),
          ),

          const SliverToBoxAdapter(
            child: SizedBox(height: AppSpacing.spaceMd),
          ),

          // 3. Mid-page CTA: Submit a Custom Request
          if (widget.artist.customRequestAvailable) ...[
            SliverToBoxAdapter(
              child: CustomRequestBanner(
                artist: widget.artist,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CustomRequestScreen(
                        artist: widget.artist,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SliverToBoxAdapter(
              child: SizedBox(height: AppSpacing.spaceLg),
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
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spaceLg),
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
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FlashDetailsScreen(
                            flash: item,
                            artist: widget.artist,
                          ),
                        ),
                      );
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
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spaceLg),
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
              artist: widget.artist,
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
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spaceLg),
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
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.spaceSm),
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
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ],
      ),
    );
  }
}
