import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/utils/distance_calculator.dart';
import '../../models/artist.dart';
import '../../providers/app_providers.dart';
import '../../screens/flash_details_screen.dart';
import '../../services/auth_service.dart';
import '../../services/google_places_service.dart';
import '../../services/studio_map_service.dart';
import '../../theme/app_buttons.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';
import '../../widgets/animated_favorite_button.dart';
import '../../widgets/flash_image.dart';
import '../../widgets/flash_snack_bar.dart';
import '../../widgets/guest_auth_prompt_bottom_sheet.dart';
import '../artist/presentation/screens/artist_profile_screen.dart';
import '../explore/domain/models/explore_studio.dart';
import 'studio_map_screen.dart';

/// Session-scoped reactive bookmark state for favorited tattoo studios.
class FavoriteStudiosNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    ref.watch(activeUidProvider);
    return const <String>{};
  }

  bool isFavorited(String studioId) => state.contains(studioId);

  void toggle(String studioId) {
    final next = Set<String>.of(state);
    if (!next.remove(studioId)) {
      next.add(studioId);
    }
    state = next;
  }
}

final favoriteStudioIdsProvider =
    NotifierProvider<FavoriteStudiosNotifier, Set<String>>(
  FavoriteStudiosNotifier.new,
);

/// Dedicated full-screen Tattoo Shop Profile page combining live Google Places
/// storefront photos, ratings, contact details, and hours with verified
/// Flash.Ink resident artists and booking profiles.
class StudioProfileScreen extends StatelessWidget {
  final StudioMapMarkerData studio;
  final String apiKey;
  final GooglePlacesService? placesService;
  final GooglePlaceStudioDetails? initialDetails;
  final AuthService? authService;
  final bool initialIsFavorited;
  final bool openedFromMap;
  final VoidCallback? onOpenMap;
  final ValueChanged<Artist>? onArtistTap;

  const StudioProfileScreen({
    super.key,
    required this.studio,
    this.apiKey = kDefaultGoogleMapsApiKey,
    this.placesService,
    this.initialDetails,
    this.authService,
    this.initialIsFavorited = false,
    this.openedFromMap = false,
    this.onOpenMap,
    this.onArtistTap,
  });

  /// Builds a [StudioProfileScreen] directly from an [ExploreStudio] card.
  factory StudioProfileScreen.fromExploreStudio({
    Key? key,
    required ExploreStudio exploreStudio,
    List<Artist> allArtists = const [],
    GeoPointCoords? clientCoords,
    String apiKey = kDefaultGoogleMapsApiKey,
    GooglePlacesService? placesService,
    AuthService? authService,
  }) {
    final mappedStudios = const StudioMapService().mapArtistsToStudios(
      allArtists,
      clientCoords: clientCoords,
    );
    final matched = mappedStudios
        .where(
          (m) =>
              (exploreStudio.placeId != null &&
                  exploreStudio.placeId!.isNotEmpty &&
                  m.placeId == exploreStudio.placeId) ||
              m.name.trim().toLowerCase() ==
                  exploreStudio.name.trim().toLowerCase(),
        )
        .firstOrNull;

    final targetStudio = matched ??
        StudioMapMarkerData.fromExploreStudio(
          exploreStudio,
          clientCoords: clientCoords,
        );

    return StudioProfileScreen(
      key: key,
      studio: targetStudio,
      apiKey: apiKey,
      placesService: placesService,
      authService: authService,
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = _StudioProfileContent(
      studio: studio,
      apiKey: apiKey,
      placesService: placesService,
      initialDetails: initialDetails,
      authService: authService,
      initialIsFavorited: initialIsFavorited,
      openedFromMap: openedFromMap,
      onOpenMap: onOpenMap,
      onArtistTap: onArtistTap,
    );

    final hasScope =
        context.findAncestorWidgetOfExactType<ProviderScope>() != null ||
            context.findAncestorWidgetOfExactType<UncontrolledProviderScope>() !=
                null;
    return hasScope ? content : ProviderScope(child: content);
  }
}

class _StudioProfileContent extends ConsumerStatefulWidget {
  final StudioMapMarkerData studio;
  final String apiKey;
  final GooglePlacesService? placesService;
  final GooglePlaceStudioDetails? initialDetails;
  final AuthService? authService;
  final bool initialIsFavorited;
  final bool openedFromMap;
  final VoidCallback? onOpenMap;
  final ValueChanged<Artist>? onArtistTap;

  const _StudioProfileContent({
    required this.studio,
    required this.apiKey,
    required this.placesService,
    required this.initialDetails,
    required this.authService,
    required this.initialIsFavorited,
    required this.openedFromMap,
    required this.onOpenMap,
    required this.onArtistTap,
  });

  @override
  ConsumerState<_StudioProfileContent> createState() =>
      _StudioProfileContentState();
}

class _StudioProfileContentState extends ConsumerState<_StudioProfileContent> {
  static const Color _coralHeartColor = Color(0xFFF4978E);

  late final GooglePlacesService _placesService;
  GooglePlaceStudioDetails? _details;
  bool _hoursExpanded = false;
  bool? _localStudioFavoriteOverride;
  final Map<String, bool> _artistFavoriteOverrides = <String, bool>{};

  bool get _canFetchGoogleDetails =>
      !widget.studio.isPrivateStudio &&
      widget.studio.placeId != null &&
      widget.studio.placeId!.trim().isNotEmpty &&
      _placesService.hasApiKey;

  @override
  void initState() {
    super.initState();
    _placesService =
        widget.placesService ?? GooglePlacesService(apiKey: widget.apiKey);
    _details = widget.initialDetails;
    if (widget.initialIsFavorited) {
      _localStudioFavoriteOverride = true;
    }
    if (_details == null && _canFetchGoogleDetails) {
      _fetchPlaceDetails();
    }
  }

  Future<void> _fetchPlaceDetails() async {
    final placeId = widget.studio.placeId;
    if (placeId == null || placeId.trim().isEmpty) return;

    try {
      final details = await _placesService.getRichPlaceDetails(placeId);
      if (mounted) {
        setState(() {
          _details = details;
        });
      }
    } catch (_) {}
  }

  Future<bool> _ensureAuthenticatedForFavorite() async {
    final effectiveAuth = widget.authService ?? ref.read(authServiceProvider);
    return GuestAuthPromptBottomSheet.ensureAuthenticated(
      context,
      actionType: AuthActionPromptType.favoriteArtist,
      authService: effectiveAuth,
    );
  }

  Future<void> _handleToggleStudioFavorite(bool currentlyFavorited) async {
    final ok = await _ensureAuthenticatedForFavorite();
    if (!ok || !mounted) return;

    ref.read(favoriteStudioIdsProvider.notifier).toggle(widget.studio.id);
    setState(() {
      _localStudioFavoriteOverride = !currentlyFavorited;
    });
  }

  Future<void> _handleToggleArtistFavorite(Artist artist) async {
    final ok = await _ensureAuthenticatedForFavorite();
    if (!ok || !mounted) return;

    final current = _artistFavoriteOverrides[artist.id] ?? artist.isFavorited;
    setState(() {
      _artistFavoriteOverrides[artist.id] = !current;
    });
  }

  void _handleShare(String studioName) {
    final shareLink = (_details?.googleMapsUri != null &&
            _details!.googleMapsUri!.trim().isNotEmpty)
        ? _details!.googleMapsUri!.trim()
        : 'https://flashink.app/studio/${widget.studio.id}';
    Clipboard.setData(ClipboardData(text: shareLink));
    FlashSnackBar.showSuccess(
      context,
      '$studioName link copied to clipboard!',
    );
  }

  void _handleDirections(StudioMapMarkerData effectiveStudio) {
    if (effectiveStudio.isPrivateStudio) {
      FlashSnackBar.showInfo(
        context,
        'Exact private studio address is shared after booking confirmation.',
      );
      return;
    }

    if (widget.onOpenMap != null) {
      widget.onOpenMap!();
      return;
    }

    if (widget.openedFromMap) {
      final destination = _details?.formattedAddress.isNotEmpty == true
          ? _details!.formattedAddress
          : effectiveStudio.address;
      Clipboard.setData(ClipboardData(text: destination));
      FlashSnackBar.showSuccess(
        context,
        'Studio address copied for directions!',
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StudioMapScreen(
          apiKey: widget.apiKey,
          placesService: widget.placesService,
          initialSelectedStudio: effectiveStudio,
          openDetailsOnLoad: false,
        ),
      ),
    );
  }

  void _handleOpenArtistProfile(Artist artist) {
    if (widget.onArtistTap != null) {
      widget.onArtistTap!(artist);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ArtistProfileScreen(artist: artist),
      ),
    );
  }

  void _handleOpenFlashDetails(FlashArtwork flash, Artist artist) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FlashDetailsScreen(flash: flash, artist: artist),
      ),
    );
  }

  void _copyValue(String value, String label) {
    Clipboard.setData(ClipboardData(text: value));
    FlashSnackBar.showSuccess(context, '$label copied to clipboard');
  }

  List<Artist> _resolveResidentArtists(List<Artist> liveArtists) {
    if (liveArtists.isEmpty) {
      return widget.studio.residentArtists;
    }

    final targetPlaceId = widget.studio.placeId?.trim();
    final targetName = _normalizeStudioName(widget.studio.name);

    final matched = liveArtists.where((artist) {
      final artistPlaceId = artist.studioInformation?.placeId?.trim();
      if (!widget.studio.isPrivateStudio &&
          targetPlaceId != null &&
          targetPlaceId.isNotEmpty &&
          artistPlaceId == targetPlaceId) {
        return true;
      }
      final candidateName = artist.studioName.trim().isNotEmpty
          ? artist.studioName
          : (artist.studioInformation?.name ?? '');
      return candidateName.trim().isNotEmpty &&
          _normalizeStudioName(candidateName) == targetName;
    }).toList();

    if (matched.isNotEmpty) return matched;
    return widget.studio.residentArtists;
  }

  static String _normalizeStudioName(String raw) {
    return raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  String _resolveHeroImageUrl(List<Artist> residentArtists) {
    final details = _details;
    if (details != null && details.photoReferences.isNotEmpty) {
      final url = _placesService.buildPhotoUrl(
        details.photoReferences.first,
        maxWidth: 1000,
      );
      if (url != null && url.isNotEmpty) return url;
    }

    if (widget.studio.photoReference != null &&
        widget.studio.photoReference!.isNotEmpty) {
      final url = _placesService.buildPhotoUrl(
        widget.studio.photoReference,
        maxWidth: 1000,
      );
      if (url != null && url.isNotEmpty) return url;
    }

    if (widget.studio.imageUrl != null &&
        widget.studio.imageUrl!.trim().isNotEmpty) {
      return widget.studio.imageUrl!.trim();
    }

    for (final artist in residentArtists) {
      if (artist.flashArtworks.isNotEmpty &&
          artist.flashArtworks.first.imageUrl.isNotEmpty) {
        return artist.flashArtworks.first.imageUrl;
      }
      if (artist.images.isNotEmpty && artist.images.first.isNotEmpty) {
        return artist.images.first;
      }
    }

    return '';
  }

  static String _formatCompactDistance(double? miles) {
    if (miles == null || miles.isNaN || miles.isInfinite || miles < 0) {
      return '--';
    }
    if (miles < 0.1) return '<0.1mi';
    final roundedOneDecimal = (miles * 10).round() / 10.0;
    if ((roundedOneDecimal - roundedOneDecimal.roundToDouble()).abs() < 0.05) {
      return '${roundedOneDecimal.round()}mi';
    }
    return '${roundedOneDecimal.toStringAsFixed(1)}mi';
  }

  static String _cleanWebsiteLabel(String? websiteUri) {
    if (websiteUri == null || websiteUri.trim().isEmpty) return '';
    var cleaned = websiteUri.trim();
    cleaned = cleaned.replaceFirst(RegExp(r'^https?://', caseSensitive: false), '');
    cleaned = cleaned.replaceFirst(RegExp(r'^www\.', caseSensitive: false), '');
    if (cleaned.endsWith('/')) {
      cleaned = cleaned.substring(0, cleaned.length - 1);
    }
    return cleaned;
  }

  String _resolveOpenStatusLabel(bool? openNow, List<String> weekdayDescriptions) {
    if (openNow == null && weekdayDescriptions.isEmpty) {
      return 'Open daily';
    }
    if (openNow == false) return 'Closed';

    if (weekdayDescriptions.isNotEmpty) {
      final now = DateTime.now();
      final days = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday'
      ];
      final currentDayName = days[now.weekday - 1].toLowerCase();
      final todayLine = weekdayDescriptions.firstWhere(
        (d) => d.toLowerCase().contains(currentDayName),
        orElse: () => '',
      );
      if (todayLine.isNotEmpty && todayLine.contains('–')) {
        final parts = todayLine.split('–');
        if (parts.length > 1) {
          final closing = parts.last.trim();
          return 'Open until $closing';
        }
      }
    }
    return 'Open now';
  }

  Widget _buildCircleBarButton({
    required Key buttonKey,
    required IconData icon,
    required Color iconColor,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 42,
      height: 42,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: buttonKey,
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.radiusFull),
          child: Tooltip(
            message: tooltip,
            child: Ink(
              decoration: BoxDecoration(
                color: const Color(0xFF222525).withAlpha(190),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.actionButtonBorder,
                  width: 0.9,
                ),
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 19,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final clientCoords = ref.watch(effectiveClientCoordinatesProvider);
    final liveArtists = ref.watch(artistsWithDistanceProvider).maybeWhen(
          data: (list) => list,
          orElse: () => const <Artist>[],
        );
    final favoritedIds = ref.watch(favoriteStudioIdsProvider);
    final isStudioFavorited = _localStudioFavoriteOverride ??
        favoritedIds.contains(widget.studio.id);

    final residentArtists = _resolveResidentArtists(liveArtists);
    final details = _details;

    final studioName =
        details?.name.trim().isNotEmpty == true ? details!.name : widget.studio.name;
    final locationSubtitle = widget.studio.isPrivateStudio
        ? 'Private Studio • Shared upon booking'
        : (widget.studio.cityState.trim().isNotEmpty
            ? widget.studio.cityState
            : (details?.formattedAddress.isNotEmpty == true
                ? details!.formattedAddress
                : widget.studio.address));

    final rating = details?.rating ?? widget.studio.rating;
    final artistCount = residentArtists.isNotEmpty
        ? residentArtists.length
        : widget.studio.residentArtistsCount;

    double? effectiveMiles = widget.studio.distanceMiles;
    if (clientCoords != null &&
        clientCoords.isValid &&
        (widget.studio.position.latitude != 0 ||
            widget.studio.position.longitude != 0)) {
      effectiveMiles = DistanceCalculator.calculateMiles(
        startLatitude: clientCoords.latitude,
        startLongitude: clientCoords.longitude,
        endLatitude: widget.studio.position.latitude,
        endLongitude: widget.studio.position.longitude,
      );
    }

    final effectiveStudio = widget.studio.copyWith(
      name: studioName,
      residentArtists: residentArtists,
      distanceMiles: effectiveMiles,
      rating: rating,
    );

    final heroUrl = _resolveHeroImageUrl(residentArtists);
    final websiteUri = details?.websiteUri?.trim();
    final websiteDomain = _cleanWebsiteLabel(websiteUri);
    final phoneNumber = details?.formattedPhoneNumber?.trim();
    final bottomInset = MediaQuery.of(context).padding.bottom;

    final openNow = details?.openNow ?? widget.studio.openNow;
    final weekdayDescriptions = details?.weekdayDescriptions ?? const [];

    final reviewsCount = (details?.userRatingsTotal != null &&
            details!.userRatingsTotal > 0)
        ? details.userRatingsTotal
        : (effectiveStudio.reviewCount != null &&
                effectiveStudio.reviewCount! > 0
            ? effectiveStudio.reviewCount
            : (details?.reviews.isNotEmpty == true
                ? details!.reviews.length
                : null));

    final tagline = widget.studio.isPrivateStudio
        ? ''
        : (widget.studio.styles.isNotEmpty
            ? '${widget.studio.styles.take(2).join(' & ')} Specialists'
            : 'Custom & Fine Line Specialists');

    return Scaffold(
      key: const Key('studio_profile_screen'),
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
        leadingWidth: AppSpacing.spaceMd + 44.0,
        leading: Padding(
          padding: const EdgeInsets.only(left: AppSpacing.spaceMd),
          child: Center(
            child: SizedBox(
              width: 42,
              height: 42,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  key: const Key('studio_back_button'),
                  onTap: () => Navigator.of(context).maybePop(),
                  borderRadius: BorderRadius.circular(AppRadius.radiusFull),
                  child: Ink(
                    decoration: BoxDecoration(
                      color: const Color(0xFF222525).withAlpha(190),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppTheme.actionButtonBorder,
                        width: 0.9,
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
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.spaceMd),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildCircleBarButton(
                  buttonKey: const Key('studio_share_button'),
                  icon: Icons.share_outlined,
                  iconColor: AppTheme.textPrimary,
                  tooltip: 'Share Shop',
                  onTap: () => _handleShare(studioName),
                ),
                const SizedBox(width: 8),
                _buildCircleBarButton(
                  buttonKey: const Key('studio_favorite_button'),
                  icon: isStudioFavorited ? Icons.favorite : Icons.favorite_border,
                  iconColor: isStudioFavorited
                      ? _coralHeartColor
                      : AppTheme.textPrimary,
                  tooltip: isStudioFavorited ? 'Saved' : 'Save Shop',
                  onTap: () => _handleToggleStudioFavorite(isStudioFavorited),
                ),
              ],
            ),
          ),
        ],
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // 1. Hero Storefront Header + Badges + Title + Stats Card + 3-Pill Actions Row
          SliverToBoxAdapter(
            child: _buildHeroAndHeaderSection(
              heroUrl: heroUrl,
              studioName: studioName,
              locationSubtitle: locationSubtitle,
              tagline: tagline,
              rating: rating,
              reviewsCount: reviewsCount,
              artistCount: artistCount,
              compactDistance: _formatCompactDistance(effectiveMiles),
              effectiveStudio: effectiveStudio,
              openNow: openNow,
              weekdayDescriptions: weekdayDescriptions,
              websiteUri: websiteUri,
              websiteDomain: websiteDomain,
              phoneNumber: phoneNumber,
            ),
          ),

          // 2. "Resident Artists & Flash" Section Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.spaceMd,
                26,
                AppSpacing.spaceMd,
                14,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Resident Artists & Flash',
                    key: const Key('studio_profile_artists_heading'),
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.3,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Claim ready-to-ink designs or book custom sessions',
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFF8E9595),
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. Resident Artists List (or empty state)
          if (residentArtists.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spaceMd),
              sliver: SliverList.separated(
                itemCount: residentArtists.length,
                separatorBuilder: (_, _) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final artist = residentArtists[index];
                  final isArtistFav =
                      _artistFavoriteOverrides[artist.id] ?? artist.isFavorited;
                  return _StudioResidentArtistCard(
                    artist: artist,
                    isFavorited: isArtistFav,
                    onViewProfile: () => _handleOpenArtistProfile(artist),
                    onToggleFavorite: () => _handleToggleArtistFavorite(artist),
                    onFlashTap: (flash) => _handleOpenFlashDetails(flash, artist),
                  );
                },
              ),
            )
          else
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spaceMd),
                child: _buildEmptyArtistsCard(),
              ),
            ),

          // 4. Supplemental Live Google Places Hours & Reviews (when available)
          if (details != null && details.weekdayDescriptions.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.spaceMd,
                  22,
                  AppSpacing.spaceMd,
                  0,
                ),
                child: _buildHoursCard(details.weekdayDescriptions),
              ),
            ),

          if (details != null && details.reviews.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.spaceMd,
                  22,
                  AppSpacing.spaceMd,
                  0,
                ),
                child: _buildReviewsSection(details.reviews),
              ),
            ),

          SliverToBoxAdapter(
            child: SizedBox(height: AppSpacing.spaceXxl + bottomInset),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroAndHeaderSection({
    required String heroUrl,
    required String studioName,
    required String locationSubtitle,
    required String tagline,
    required double? rating,
    required int? reviewsCount,
    required int artistCount,
    required String compactDistance,
    required StudioMapMarkerData effectiveStudio,
    required bool? openNow,
    required List<String> weekdayDescriptions,
    required String? websiteUri,
    required String websiteDomain,
    required String? phoneNumber,
  }) {
    final openLabel = _resolveOpenStatusLabel(openNow, weekdayDescriptions);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Storefront Cover Photo + Dark Gradient Vignette
        SizedBox(
          height: 330,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (heroUrl.isNotEmpty)
                FlashImage(
                  urlOrPath: heroUrl,
                  fit: BoxFit.cover,
                )
              else
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF2B251B),
                        Color(0xFF151818),
                      ],
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.storefront_rounded,
                      color: AppTheme.gold.withAlpha(80),
                      size: 64,
                    ),
                  ),
                ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withAlpha(70),
                      Colors.black.withAlpha(90),
                      AppTheme.onyxBackground.withAlpha(225),
                      AppTheme.onyxBackground,
                    ],
                    stops: const [0.0, 0.40, 0.82, 1.0],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Foreground Content: Badges + Studio Name + Subtitle + Stats Card + Action Row
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.spaceMd,
            126,
            AppSpacing.spaceMd,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Badges: VERIFIED STUDIO & Open Status
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1F1D17).withAlpha(220),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppTheme.gold.withAlpha(170),
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          color: AppTheme.gold,
                          size: 13,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'VERIFIED STUDIO',
                          style: GoogleFonts.plusJakartaSans(
                            color: AppTheme.gold,
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF131A16).withAlpha(220),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: (openNow == false
                                ? const Color(0xFF5B3030)
                                : const Color(0xFF2E6343))
                            .withAlpha(160),
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: openNow == false
                                ? const Color(0xFFE57373)
                                : const Color(0xFF4EBA6F),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          openLabel,
                          style: GoogleFonts.plusJakartaSans(
                            color: openNow == false
                                ? const Color(0xFFE57373)
                                : const Color(0xFF6ED390),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Studio Name in Large White Typography
              Text(
                studioName,
                key: const Key('studio_profile_name'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  height: 1.12,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 6),

              // Location + Specialty Tagline
              Row(
                children: [
                  const Icon(
                    Icons.location_on_rounded,
                    color: AppTheme.gold,
                    size: 15,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            locationSubtitle,
                            key: const Key('studio_profile_location'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFFD5D9D9),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (tagline.isNotEmpty) ...[
                          Text(
                            ' • $tagline',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFF9EA3A3),
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 3-Column Studio Metrics Card (RATING | ARTISTS | DISTANCE)
              Container(
                key: const Key('studio_profile_stats_card'),
                padding: const EdgeInsets.symmetric(
                  vertical: 18,
                  horizontal: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF151818),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppTheme.cardBorder,
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(140),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Col 1: RATING / REVIEWS
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                color: AppTheme.gold,
                                size: 19,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                rating != null
                                    ? rating.toStringAsFixed(1)
                                    : 'New',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  height: 1.1,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            reviewsCount != null && reviewsCount > 0
                                ? '$reviewsCount REVIEWS'
                                : 'RATING',
                            style: GoogleFonts.plusJakartaSans(
                              color: AppTheme.navInactive,
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 32,
                      color: AppTheme.statDivider,
                    ),

                    // Col 2: ARTISTS
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$artistCount',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'ARTISTS',
                            style: GoogleFonts.plusJakartaSans(
                              color: AppTheme.navInactive,
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 32,
                      color: AppTheme.statDivider,
                    ),

                    // Col 3: DISTANCE
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            compactDistance,
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'DISTANCE',
                            style: GoogleFonts.plusJakartaSans(
                              color: AppTheme.navInactive,
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // 3-Pill Quick Actions Row (Website, Phone, Directions)
              Row(
                children: [
                  Expanded(
                    child: _buildQuickActionPill(
                      key: const Key('studio_info_website_row'),
                      icon: Icons.language_rounded,
                      label: websiteDomain.isNotEmpty ? 'Website' : 'Website',
                      onTap: () {
                        if (websiteUri != null && websiteUri.isNotEmpty) {
                          _copyValue(websiteUri, 'Website');
                        } else {
                          FlashSnackBar.showInfo(
                            context,
                            'No website listed for this tattoo shop yet.',
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildQuickActionPill(
                      key: const Key('studio_info_phone_row'),
                      icon: Icons.phone_rounded,
                      label: phoneNumber != null && phoneNumber.isNotEmpty
                          ? phoneNumber
                          : 'Call Shop',
                      onTap: () {
                        if (phoneNumber != null && phoneNumber.isNotEmpty) {
                          _copyValue(phoneNumber, 'Phone number');
                        } else {
                          FlashSnackBar.showInfo(
                            context,
                            'No phone number listed for this tattoo shop yet.',
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildQuickActionPill(
                      key: const Key('studio_directions_button'),
                      icon: Icons.near_me_rounded,
                      label: 'Directions',
                      onTap: () => _handleDirections(effectiveStudio),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionPill({
    required Key key,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      key: key,
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.radiusFull),
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1B1E1E),
            borderRadius: BorderRadius.circular(AppRadius.radiusFull),
            border: Border.all(
              color: const Color(0xFF2B3030),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: AppTheme.gold,
                size: 15,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyArtistsCard() {
    return Container(
      key: const Key('studio_profile_empty_artists'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.cardBorder, width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.goldBadgeBackground,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.goldBadgeBorder),
            ),
            child: const Icon(
              Icons.storefront_outlined,
              color: AppTheme.gold,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Verified Tattoo Shop',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'No resident artists at this shop have linked their Flash.Ink profile yet.',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.navInactive,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHoursCard(List<String> weekdayLines) {
    final openNow = _details?.openNow ?? widget.studio.openNow;
    return Material(
      color: AppTheme.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppTheme.cardBorder, width: 1.2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            key: const Key('studio_profile_hours_toggle'),
            onTap: () => setState(() => _hoursExpanded = !_hoursExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  const Icon(
                    Icons.schedule_rounded,
                    color: AppTheme.gold,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Shop Hours',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (openNow != null) ...[
                    Text(
                      openNow ? 'Open now' : 'Closed',
                      style: GoogleFonts.plusJakartaSans(
                        color: openNow
                            ? AppTheme.switchActive
                            : AppTheme.favoriteActive,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Icon(
                    _hoursExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppTheme.navInactive,
                  ),
                ],
              ),
            ),
          ),
          if (_hoursExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: weekdayLines
                    .map(
                      (line) => Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Text(
                          line,
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFFCFD4D4),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReviewsSection(List<GooglePlaceReview> reviews) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Reviews',
          style: GoogleFonts.plusJakartaSans(
            color: AppTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 12),
        ...reviews.take(3).map(
              (review) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.cardBackground,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            review.authorName,
                            style: GoogleFonts.plusJakartaSans(
                              color: AppTheme.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(
                            5,
                            (idx) => Icon(
                              idx < review.rating.round()
                                  ? Icons.star_rounded
                                  : Icons.star_border_rounded,
                              color: AppTheme.gold,
                              size: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (review.text.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        review.text,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFFD0D4D4),
                          fontSize: 12.5,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
      ],
    );
  }
}

/// Resident artist card tailored for the Tattoo Shop Page:
/// - Circular portrait avatar + "Books open" pill badge + Artist name + Style subtitle
/// - Top-right circular outline favorite button
/// - 3-column metrics container (RATING | AVAIL PIECES | MIN DEPOSIT)
/// - Up to 3 preview flash cards with placement, size, and deposit pricing
/// - Full-width gold "VIEW PROFILE" CTA
class _StudioResidentArtistCard extends StatelessWidget {
  final Artist artist;
  final bool isFavorited;
  final VoidCallback onViewProfile;
  final VoidCallback onToggleFavorite;
  final ValueChanged<FlashArtwork>? onFlashTap;

  const _StudioResidentArtistCard({
    required this.artist,
    required this.isFavorited,
    required this.onViewProfile,
    required this.onToggleFavorite,
    this.onFlashTap,
  });

  @override
  Widget build(BuildContext context) {
    final previewFlash = artist.flashArtworks.take(3).toList();
    final stylesSubtitle = artist.tags.isNotEmpty
        ? artist.tags.join(' & ')
        : (artist.studioType.isNotEmpty
            ? artist.studioType
            : 'Custom & Fine Line');

    return Container(
      key: Key('studio_artist_card_${artist.id}'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.cardBorder,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(120),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Avatar + (Badge, Name, Styles) + Top-Right Favorite Heart
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Circular Portrait Avatar with Gold Border
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.gold,
                    width: 1.6,
                  ),
                ),
                child: ClipOval(
                  child: artist.avatarUrl.trim().isNotEmpty
                      ? FlashImage(
                          urlOrPath: artist.avatarUrl,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          color: AppTheme.onyxContainer,
                          child: const Icon(
                            Icons.person,
                            color: AppTheme.gold,
                            size: 32,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 14),
              // Artist details: Books open badge, Name, Styles
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (artist.isBooksOpen) ...[
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.goldBadgeBackground,
                          borderRadius:
                              BorderRadius.circular(AppRadius.radiusXs),
                          border: Border.all(
                            color: AppTheme.goldBadgeBorder,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          'Books open',
                          style: GoogleFonts.plusJakartaSans(
                            color: AppTheme.gold,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            height: 1.1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                    ],
                    Text(
                      artist.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      stylesSubtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF8E9595),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              // Top-Right Favorite Heart Button
              AnimatedFavoriteButton(
                key: Key('studio_artist_favorite_${artist.id}'),
                isFavorited: isFavorited,
                onToggle: onToggleFavorite,
                size: 38,
                iconSize: 20,
                backgroundColor: Colors.transparent,
                inactiveBorderColor: const Color(0xFF474C4C),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Middle Inner 3-Column Metrics Box (RATING | AVAIL PIECES | MIN DEPOSIT)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF141616),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFF242828),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                // Col 1: RATING
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            color: AppTheme.gold,
                            size: 17,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            artist.rating.toStringAsFixed(1),
                            style: GoogleFonts.plusJakartaSans(
                              color: AppTheme.gold,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'RATING',
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.navInactive,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 28,
                  color: AppTheme.statDivider,
                ),

                // Col 2: AVAIL PIECES
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${artist.availablePieces}',
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'AVAIL PIECES',
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.navInactive,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 28,
                  color: AppTheme.statDivider,
                ),

                // Col 3: MIN DEPOSIT
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '\$${artist.minDeposit}',
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'MIN DEPOSIT',
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.navInactive,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Flash preview row of up to 3 cards
          if (previewFlash.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                for (int i = 0; i < previewFlash.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: _buildFlashPreviewCard(
                      context,
                      previewFlash[i],
                    ),
                  ),
                ],
              ],
            ),
          ],

          const SizedBox(height: 16),

          // Full-Width Gold "VIEW PROFILE" CTA
          SizedBox(
            width: double.infinity,
            child: AppButtons.primaryCTA(
              key: Key('studio_artist_view_profile_${artist.id}'),
              onPressed: onViewProfile,
              text: 'View Profile',
              backgroundColor: AppTheme.gold,
              foregroundColor: AppTheme.onyxBackground,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlashPreviewCard(BuildContext context, FlashArtwork flash) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (onFlashTap != null) {
            onFlashTap!(flash);
          } else {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    FlashDetailsScreen(flash: flash, artist: artist),
              ),
            );
          }
        },
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          decoration: BoxDecoration(
            color: const Color(0xFF191C1C),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: const Color(0xFF282D2D),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(9)),
                child: AspectRatio(
                  aspectRatio: 0.95,
                  child: FlashImage(
                    urlOrPath: flash.imageUrl,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 6, 6, 7),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      flash.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Placement: ${flash.location}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF888F8F),
                        fontSize: 8.5,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Size: ${flash.dimensions}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF888F8F),
                        fontSize: 8.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: 'Deposit: ',
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFF888F8F),
                              fontSize: 9,
                            ),
                          ),
                          TextSpan(
                            text: '\$${flash.deposit}',
                            style: GoogleFonts.plusJakartaSans(
                              color: AppTheme.gold,
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
}
