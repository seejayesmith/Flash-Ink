import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../../theme/app_radius.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_theme.dart';
import '../../../../theme/app_typography.dart';
import '../../domain/models/artist_profile.dart';

/// Renders an individual flash artwork card with graceful caching,
/// onyx placeholder shimmer, and structured placement/size/deposit metadata.
class FlashPieceCard extends StatelessWidget {
  final FlashPiece piece;
  final VoidCallback? onTap;

  const FlashPieceCard({
    super.key,
    required this.piece,
    this.onTap,
  });

  bool get _isNetwork =>
      piece.imageUrl.startsWith('http://') ||
      piece.imageUrl.startsWith('https://');

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.radiusMd + 2),
        child: Ink(
          decoration: BoxDecoration(
            color: AppTheme.cardBackground,
            borderRadius: BorderRadius.circular(AppRadius.radiusMd + 2),
            border: Border.all(
              color: AppTheme.cardBorder,
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(90),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Artwork Image with Top Rounded Corners
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(AppRadius.radiusMd + 1),
                  ),
                  child: _buildImage(),
                ),
              ),

              // Metadata Section
              Padding(
                padding: const EdgeInsets.all(AppSpacing.spaceSm - 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      piece.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySmallBold.copyWith(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.spaceXs - 2),
                    _buildMetaRow('Placement:', piece.location),
                    const SizedBox(height: AppSpacing.spaceXxs - 1),
                    _buildMetaRow('Size:', piece.size),
                    const SizedBox(height: AppSpacing.spaceXxs - 1),
                    _buildMetaRow(
                      'Deposit:',
                      '\$${piece.deposit}',
                      valueColor: AppTheme.gold,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImage() {
    if (piece.imageUrl.isEmpty) {
      return _buildErrorPlaceholder();
    }

    if (_isNetwork) {
      return CachedNetworkImage(
        imageUrl: piece.imageUrl,
        fit: BoxFit.cover,
        placeholder: (context, url) => _buildShimmerPlaceholder(),
        errorWidget: (context, url, error) => _buildErrorPlaceholder(),
      );
    }

    return Image.asset(
      piece.imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => _buildErrorPlaceholder(),
    );
  }

  Widget _buildShimmerPlaceholder() {
    return Container(
      color: AppTheme.shimmerBase,
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.goldBorder),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorPlaceholder() {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.shimmerBase,
      ),
      child: const Center(
        child: Icon(
          Icons.draw_outlined,
          color: AppTheme.navInactiveAlt,
          size: 26,
        ),
      ),
    );
  }

  Widget _buildMetaRow(
    String label,
    String value, {
    Color valueColor = AppTheme.textPrimary,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTypography.label.copyWith(
            color: AppTheme.navInactive,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: AppTypography.labelBold.copyWith(
              color: valueColor,
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }
}
