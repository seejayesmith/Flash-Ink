import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../theme/app_radius.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_theme.dart';
import '../../../../theme/app_typography.dart';
import '../../../../widgets/flash_snack_bar.dart';
import '../../domain/models/artist_profile.dart';

/// Top header section of the artist profile screen containing:
/// - Flexible hero banner with dark gradient vignette
/// - Top action buttons (Share & Favorite)
/// - Row with circular avatar (with gold border) and artist name/badges/location
/// - About section bio
/// - 3-column Fun Facts row
class ArtistHeaderSection extends StatelessWidget {
  final ArtistProfile artist;
  final bool isFavorited;
  final VoidCallback onToggleFavorite;
  final VoidCallback? onBack;
  final bool isOwner;
  final bool isUpdatingBanner;
  final VoidCallback? onEditBanner;

  const ArtistHeaderSection({
    super.key,
    required this.artist,
    required this.isFavorited,
    required this.onToggleFavorite,
    this.onBack,
    this.isOwner = false,
    this.isUpdatingBanner = false,
    this.onEditBanner,
  });

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final coverImage = artist.effectiveBannerUrl;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 1. Hero Cover Image with Vignette Gradient
        SizedBox(
          height: 260,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildCoverImage(coverImage),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      AppTheme.onyxBackground.withAlpha(100),
                      AppTheme.onyxBackground.withAlpha(220),
                      AppTheme.onyxBackground,
                    ],
                    stops: const [0.15, 0.55, 0.85, 1.0],
                  ),
                ),
              ),
            ],
          ),
        ),

        // 2. Floating Top Right Action Buttons (Share & Favorite or Edit Banner for owner)
        Positioned(
          top: topPadding + AppSpacing.spaceXs,
          right: AppSpacing.screenGutter,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildCircularActionButton(
                buttonKey: const Key('artist_share_profile_button'),
                icon: Icons.share_outlined,
                onTap: () {
                  Clipboard.setData(ClipboardData(
                    text: 'https://flashink.app/artist/${artist.id}',
                  ));
                  FlashSnackBar.showSuccess(
                    context,
                    'Artist profile link copied to clipboard!',
                  );
                },
                tooltip: 'Share Profile',
              ),
              const SizedBox(width: AppSpacing.spaceSm),
              if (isOwner && onEditBanner != null)
                _buildCircularActionButton(
                  buttonKey: const Key('artist_edit_banner_button'),
                  icon: Icons.add_a_photo_outlined,
                  iconColor: AppTheme.gold,
                  isLoading: isUpdatingBanner,
                  onTap: isUpdatingBanner ? () {} : onEditBanner!,
                  tooltip: 'Edit Header Banner',
                )
              else
                _buildCircularActionButton(
                  buttonKey: const Key('artist_favorite_profile_button'),
                  icon: isFavorited ? Icons.favorite : Icons.favorite_border,
                  iconColor: isFavorited ? AppTheme.favoriteActive : AppTheme.textPrimary,
                  onTap: onToggleFavorite,
                  tooltip: isFavorited ? 'Unfavorite' : 'Favorite',
                ),
            ],
          ),
        ),

        // 3. Artist Details: Avatar + Name/Location Row, then Bio & Fun Facts
        Padding(
          padding: const EdgeInsets.only(top: 155),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenGutter),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar + Name/Location/Badges Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Circular Avatar
                    Container(
                      width: 86,
                      height: 86,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.avatarBorder,
                          width: 2.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(140),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: _buildAvatarImage(),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.spaceMd),

                    // Name, Books Open Badge, Location & Studio
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 10.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // "Books open" badge
                            if (artist.isBooksOpen) ...[
                              Container(
                                padding: const EdgeInsets.fromLTRB(7, 2, 7, 3),
                                decoration: BoxDecoration(
                                  color: AppTheme.goldBadgeBackground,
                                  border: Border.all(
                                    color: AppTheme.goldBadgeBorder,
                                    width: 1,
                                  ),
                                  borderRadius: BorderRadius.circular(AppRadius.radiusXs),
                                ),
                                child: Text(
                                  'Books open',
                                  maxLines: 1,
                                  softWrap: false,
                                  textHeightBehavior: const TextHeightBehavior(
                                    leadingDistribution: TextLeadingDistribution.even,
                                  ),
                                  style: AppTypography.labelBold.copyWith(
                                    color: AppTheme.gold,
                                    fontSize: 10,
                                    height: 1.0,
                                    leadingDistribution: TextLeadingDistribution.even,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                            ],

                            // Name
                            Text(
                              artist.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.profileHeaderTitle,
                            ),
                            const SizedBox(height: AppSpacing.spaceXxs + 2),

                            // Studio Name Row
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.storefront_outlined,
                                  color: AppTheme.navInactive,
                                  size: 14,
                                ),
                                const SizedBox(width: AppSpacing.spaceXxs - 1),
                                Text(
                                  artist.studioType,
                                  style: AppTypography.label.copyWith(
                                    color: AppTheme.navInactive,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.spaceLg - 4),

                // About Header & Bio
                Text(
                  'About',
                  style: AppTypography.label.copyWith(
                    color: AppTheme.navInactive,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: AppSpacing.spaceXxs + 1),
                Text(
                  artist.bio,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppTheme.textPrimary,
                    fontSize: 12.5,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: AppSpacing.spaceMd),

                // Fun Facts 3-Column Row
                _buildFunFactsRow(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCoverImage(String coverImage) {
    final trimmed = coverImage.trim();
    if (trimmed.isEmpty) {
      return _buildPlaceholderBanner();
    }
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return CachedNetworkImage(
        key: ValueKey('artist_banner_image_$trimmed'),
        imageUrl: trimmed,
        fit: BoxFit.cover,
        placeholder: (context, url) => _buildPlaceholderBanner(),
        errorWidget: (context, url, error) => _buildPlaceholderBanner(),
      );
    }
    return Image.asset(
      trimmed,
      key: ValueKey('artist_banner_image_$trimmed'),
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => _buildPlaceholderBanner(),
    );
  }

  Widget _buildPlaceholderBanner() {
    return Container(
      key: const Key('artist_banner_placeholder'),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF232018),
            Color(0xFF171A1A),
            AppTheme.onyxBackground,
          ],
          stops: [0.0, 0.55, 1.0],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            right: -30,
            top: -20,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.gold.withAlpha(28),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarImage() {
    final trimmedUrl = artist.avatarUrl.trim();
    if (trimmedUrl.isEmpty) {
      return Container(
        color: AppTheme.onyxContainer,
        child: const Icon(
          Icons.person,
          color: AppTheme.gold,
          size: 42,
        ),
      );
    }
    if (trimmedUrl.startsWith('http://') || trimmedUrl.startsWith('https://')) {
      return CachedNetworkImage(
        imageUrl: trimmedUrl,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(color: AppTheme.shimmerBase),
        errorWidget: (context, url, error) => Container(
          color: AppTheme.onyxContainer,
          child: const Icon(
            Icons.person,
            color: AppTheme.gold,
            size: 42,
          ),
        ),
      );
    }
    return Image.asset(
      trimmedUrl,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Container(
        color: AppTheme.onyxContainer,
        child: const Icon(
          Icons.person,
          color: AppTheme.gold,
          size: 42,
        ),
      ),
    );
  }

  Widget _buildCircularActionButton({
    Key? buttonKey,
    required IconData icon,
    Color iconColor = AppTheme.textPrimary,
    bool isLoading = false,
    required VoidCallback onTap,
    String? tooltip,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: buttonKey,
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.radiusFull),
        child: Tooltip(
          message: tooltip ?? '',
          child: Ink(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.actionButtonBackground.withAlpha(190),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppTheme.actionButtonBorder,
                width: 0.8,
              ),
            ),
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.gold),
                      ),
                    )
                  : Icon(
                      icon,
                      color: iconColor,
                      size: 20,
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFunFactsRow() {
    final facts = artist.funFacts.isNotEmpty
        ? artist.funFacts
        : [
            ArtistFunFact(
              label: 'Specialty',
              value: artist.tags.isNotEmpty ? artist.tags.first : 'Flash & Custom',
            ),
            ArtistFunFact(
              label: 'Studio',
              value: artist.studioType.isNotEmpty ? artist.studioType : 'Independent',
            ),
            ArtistFunFact(
              label: 'Booking',
              value: artist.isBooksOpen ? 'Books Open' : 'Waitlist',
            ),
          ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: facts.take(3).map((fact) {
        return Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                fact.label,
                style: AppTypography.label.copyWith(
                  color: AppTheme.navInactive,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: AppSpacing.spaceXxs - 1),
              Text(
                fact.value,
                style: AppTypography.bodySmallBold.copyWith(
                  color: AppTheme.textPrimary,
                  fontSize: 12.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
