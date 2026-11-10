import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/artist.dart';
import '../../services/google_places_service.dart';
import '../../services/studio_map_service.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';
import '../../widgets/flash_image.dart';
import 'studio_profile_screen.dart';

/// Minimal, non-scrollable preview card for tattoo shops displayed as a bottom sheet.
/// Shows essential information (stacked photo banner, open status, shop name, rating,
/// distance/address) and opens the full [StudioProfileScreen] when tapped.
class StudioPlaceDetailsSheet extends StatefulWidget {
  final StudioMapMarkerData studio;
  final GooglePlacesService placesService;
  final GooglePlaceStudioDetails? initialDetails;
  final ValueChanged<Artist>? onArtistTap;

  const StudioPlaceDetailsSheet({
    super.key,
    required this.studio,
    required this.placesService,
    this.initialDetails,
    this.onArtistTap,
  });

  static Future<void> show(
    BuildContext context, {
    required StudioMapMarkerData studio,
    required GooglePlacesService placesService,
    GooglePlaceStudioDetails? initialDetails,
    ValueChanged<Artist>? onArtistTap,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StudioPlaceDetailsSheet(
        studio: studio,
        placesService: placesService,
        initialDetails: initialDetails,
        onArtistTap: onArtistTap,
      ),
    );
  }

  @override
  State<StudioPlaceDetailsSheet> createState() =>
      _StudioPlaceDetailsSheetState();
}

class _StudioPlaceDetailsSheetState extends State<StudioPlaceDetailsSheet> {
  GooglePlaceStudioDetails? _details;

  bool get _canFetchGoogleDetails =>
      !widget.studio.isPrivateStudio &&
      widget.studio.placeId != null &&
      widget.studio.placeId!.trim().isNotEmpty &&
      widget.placesService.hasApiKey;

  @override
  void initState() {
    super.initState();
    _details = widget.initialDetails;
    if (_details == null && _canFetchGoogleDetails) {
      _fetchPlaceDetails();
    }
  }

  Future<void> _fetchPlaceDetails() async {
    final placeId = widget.studio.placeId;
    if (placeId == null || placeId.trim().isEmpty) return;

    try {
      final details = await widget.placesService.getRichPlaceDetails(placeId);
      if (mounted) {
        setState(() {
          _details = details;
        });
      }
    } catch (_) {
      // Gracefully fall back to marker data
    }
  }

  void _openShopPage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StudioProfileScreen(
          studio: widget.studio,
          placesService: widget.placesService,
          initialDetails: _details,
          openedFromMap: true,
          onArtistTap: widget.onArtistTap,
        ),
      ),
    );
  }

  String _resolvePrimaryImageUrl() {
    final details = _details;
    if (details != null && details.photoReferences.isNotEmpty) {
      final url = widget.placesService.buildPhotoUrl(
        details.photoReferences.first,
        maxWidth: 900,
      );
      if (url != null && url.isNotEmpty) return url;
    }
    if (widget.studio.photoReference != null &&
        widget.studio.photoReference!.isNotEmpty) {
      final url = widget.placesService.buildPhotoUrl(
        widget.studio.photoReference,
        maxWidth: 900,
      );
      if (url != null && url.isNotEmpty) return url;
    }
    return widget.studio.imageUrl ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final details = _details;
    final studioName = details?.name.isNotEmpty == true
        ? details!.name
        : widget.studio.name;
    final rating = details?.rating ?? widget.studio.rating;
    final reviewCount = (details != null && details.userRatingsTotal > 0)
        ? details.userRatingsTotal
        : (widget.studio.reviewCount ?? 0);
    final openNow = details?.openNow ?? widget.studio.openNow;
    final displayAddress = widget.studio.isPrivateStudio
        ? 'Private Studio • ${widget.studio.cityState.isNotEmpty ? widget.studio.cityState : "Approximate Area"}'
        : (details?.formattedAddress.isNotEmpty == true
              ? details!.formattedAddress
              : widget.studio.address);
    final heroUrl = _resolvePrimaryImageUrl();
    final formattedDistance = widget.studio.formattedDistance;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenMargin,
          0,
          AppSpacing.screenMargin,
          16,
        ),
        child: Container(
          key: const Key('studio_place_details_sheet'),
          decoration: BoxDecoration(
            color: AppTheme.onyxBackground,
            borderRadius: BorderRadius.circular(AppRadius.radiusXl),
            border: Border.all(color: AppTheme.goldBorder, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(160),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.radiusXl),
            child: InkWell(
              key: const Key('details_sheet_view_shop_button'),
              onTap: _openShopPage,
              borderRadius: BorderRadius.circular(AppRadius.radiusXl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Drag handle
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 10, bottom: 8),
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppTheme.navInactive.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(
                            AppRadius.dragHandle,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Stacked Top Photo Banner
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.spaceMd,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.radiusLg),
                      child: SizedBox(
                        height: 125,
                        width: double.infinity,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            FlashImage(urlOrPath: heroUrl, fit: BoxFit.cover),
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black.withAlpha(20),
                                    Colors.black.withAlpha(140),
                                  ],
                                ),
                              ),
                            ),
                            // Top-left: Open/Closed status pill
                            if (openNow != null)
                              Positioned(
                                left: 10,
                                top: 10,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        (openNow
                                                ? const Color(0xFF131A16)
                                                : const Color(0xFF1A1313))
                                            .withAlpha(220),
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.radiusSm,
                                    ),
                                    border: Border.all(
                                      color:
                                          (openNow
                                                  ? const Color(0xFF2E6343)
                                                  : const Color(0xFF5B3030))
                                              .withAlpha(160),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color: openNow
                                              ? const Color(0xFF4EBA6F)
                                              : const Color(0xFFE57373),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        openNow ? 'OPEN NOW' : 'CLOSED',
                                        style: GoogleFonts.plusJakartaSans(
                                          color: openNow
                                              ? const Color(0xFF6ED390)
                                              : const Color(0xFFE57373),
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.6,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            // Top-right: Close button
                            Positioned(
                              right: 10,
                              top: 10,
                              child: Material(
                                color: Colors.black.withAlpha(160),
                                shape: const CircleBorder(),
                                child: InkWell(
                                  key: const Key('studio_preview_close_button'),
                                  customBorder: const CircleBorder(),
                                  onTap: () => Navigator.of(context).pop(),
                                  child: const Padding(
                                    padding: EdgeInsets.all(6),
                                    child: Icon(
                                      Icons.close_rounded,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Bottom Details Section
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.spaceMd,
                      12,
                      AppSpacing.spaceMd,
                      16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Row 1: Studio Name + Chevron
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                studioName,
                                style: GoogleFonts.plusJakartaSans(
                                  color: AppTheme.textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: AppTheme.gold,
                              size: 24,
                            ),
                          ],
                        ),

                        const SizedBox(height: 5),

                        // Row 2: Star rating & review count
                        if (rating != null) ...[
                          Row(
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                color: AppTheme.gold,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                rating.toStringAsFixed(1),
                                style: GoogleFonts.plusJakartaSans(
                                  color: AppTheme.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (reviewCount > 0) ...[
                                const SizedBox(width: 4),
                                Text(
                                  '($reviewCount reviews)',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: AppTheme.navInactive,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                        ],

                        // Row 3: Distance
                        if (formattedDistance != null &&
                            formattedDistance.isNotEmpty) ...[
                          Row(
                            children: [
                              const Icon(
                                Icons.near_me_outlined,
                                color: AppTheme.gold,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  formattedDistance,
                                  style: GoogleFonts.plusJakartaSans(
                                    color: AppTheme.gold,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                        ],

                        // Row 4: Address
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              color: AppTheme.navInactive,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                displayAddress,
                                style: GoogleFonts.plusJakartaSans(
                                  color: AppTheme.navInactive,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),

                        // Private studio privacy banner
                        if (widget.studio.isPrivateStudio)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Container(
                              key: const Key('private_studio_privacy_banner'),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.goldBadgeBackground.withAlpha(
                                  140,
                                ),
                                borderRadius: BorderRadius.circular(
                                  AppRadius.radiusSm,
                                ),
                                border: Border.all(
                                  color: AppTheme.goldBadgeBorder,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.lock_outline_rounded,
                                    color: AppTheme.gold,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      'Private Studio • Address shared upon confirmed booking',
                                      style: GoogleFonts.plusJakartaSans(
                                        color: AppTheme.gold,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
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
      ),
    );
  }
}
