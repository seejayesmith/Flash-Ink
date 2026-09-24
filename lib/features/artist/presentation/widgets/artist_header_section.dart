import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../theme/app_radius.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_theme.dart';
import '../../../../theme/app_typography.dart';
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

  const ArtistHeaderSection({
    super.key,
    required this.artist,
    required this.isFavorited,
    required this.onToggleFavorite,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final coverImage = artist.images.isNotEmpty
        ? artist.images.first
        : 'assets/images/flash_traditional_dagger.jpg';

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

        // 2. Floating Top Right Action Buttons (Share & Favorite)
        Positioned(
          top: topPadding + AppSpacing.spaceXs,
          right: AppSpacing.spaceLg,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildCircularActionButton(
                icon: Icons.share_outlined,
                onTap: () {
                  Clipboard.setData(ClipboardData(
                    text: 'https://flashink.app/artist/${artist.id}',
                  ));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: AppTheme.onyxContainer,
                      content: Text(
                        'Artist profile link copied to clipboard!',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.radiusSm),
                        side: const BorderSide(color: AppTheme.goldBorder),
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                tooltip: 'Share Profile',
              ),
              const SizedBox(width: AppSpacing.spaceSm),
              _buildCircularActionButton(
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
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spaceLg),
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Name and "Books open" badge
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: AppSpacing.spaceXs,
                            runSpacing: AppSpacing.spaceXxs,
                            children: [
                              Text(
                                artist.name,
                                style: AppTypography.h4.copyWith(
                                  color: AppTheme.gold,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.2,
                                  fontSize: 22,
                                ),
                              ),
                              if (artist.isBooksOpen)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.spaceXs - 1,
                                    vertical: AppSpacing.spaceXxs - 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.goldBadgeBackground,
                                    border: Border.all(
                                      color: AppTheme.goldBadgeBorder,
                                      width: 1,
                                    ),
                                    borderRadius: BorderRadius.circular(AppRadius.radiusXs + 2),
                                  ),
                                  child: Text(
                                    'Books open',
                                    style: AppTypography.labelBold.copyWith(
                                      color: AppTheme.gold,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.spaceXxs + 2),

                          // Location and Studio Type Row
                          Wrap(
                            spacing: AppSpacing.spaceSm,
                            runSpacing: AppSpacing.spaceXxs,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.location_on_outlined,
                                    color: AppTheme.navInactive,
                                    size: 14,
                                  ),
                                  const SizedBox(width: AppSpacing.spaceXxs - 1),
                                  Text(
                                    artist.location,
                                    style: AppTypography.label.copyWith(
                                      color: AppTheme.navInactive,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
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
                        ],
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
    if (coverImage.startsWith('http://') || coverImage.startsWith('https://')) {
      return CachedNetworkImage(
        imageUrl: coverImage,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(color: AppTheme.shimmerBase),
        errorWidget: (context, url, error) => Container(
          color: AppTheme.shimmerBase,
          child: const Icon(Icons.broken_image, color: AppTheme.navInactive),
        ),
      );
    }
    return Image.asset(
      coverImage,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Container(
        color: AppTheme.shimmerBase,
      ),
    );
  }

  Widget _buildAvatarImage() {
    if (artist.avatarUrl.startsWith('http://') || artist.avatarUrl.startsWith('https://')) {
      return CachedNetworkImage(
        imageUrl: artist.avatarUrl,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(color: AppTheme.shimmerBase),
        errorWidget: (context, error, stackTrace) => Container(
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
      artist.avatarUrl,
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
    required IconData icon,
    Color iconColor = AppTheme.textPrimary,
    required VoidCallback onTap,
    String? tooltip,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
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
              child: Icon(
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
        : const [
            ArtistFunFact(label: 'Fun Fact', value: 'XYZ'),
            ArtistFunFact(label: 'Fun Fact', value: 'XYZ'),
            ArtistFunFact(label: 'Fun Fact', value: 'XYZ'),
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
