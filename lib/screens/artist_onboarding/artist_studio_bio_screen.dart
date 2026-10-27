import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../features/onboarding/shared/onboarding_step_scaffold.dart';
import '../../models/studio_information.dart';
import '../../repositories/artist_repository.dart';
import '../../services/auth_service.dart';
import '../../services/google_places_service.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_theme.dart';
import '../../widgets/adaptive_glass_container.dart';
import '../../widgets/fade_page_route.dart';
import '../../widgets/flash_switch.dart';
import '../../widgets/tattoo_background_wrapper.dart';
import 'artist_policies_screen.dart';

class ArtistStudioBioScreen extends StatefulWidget {
  final String artistName;
  final Uint8List? photoBytes;
  final String? photoUrl;
  final String? instagramHandle;
  final AuthService? authService;
  final StudioInformation? initialStudio;
  final String? initialBio;
  final GooglePlacesService? googlePlacesService;

  const ArtistStudioBioScreen({
    super.key,
    required this.artistName,
    this.photoBytes,
    this.photoUrl,
    this.instagramHandle,
    this.authService,
    this.initialStudio,
    this.initialBio,
    this.googlePlacesService,
  });

  @override
  State<ArtistStudioBioScreen> createState() => _ArtistStudioBioScreenState();
}

class _ArtistStudioBioScreenState extends State<ArtistStudioBioScreen> {
  late final GooglePlacesService _placesService;
  late final TextEditingController _searchController;
  late final TextEditingController _manualStudioNameController;
  late final TextEditingController _manualLocationController;
  late final TextEditingController _bioController;

  Timer? _debounceTimer;
  List<GooglePlacePrediction> _predictions = [];
  bool _isSearching = false;
  bool _isLoadingDetails = false;
  String? _searchError;

  StudioInformation? _selectedStudio;
  bool _isManualEntry = false;
  bool _isPrivateStudio = false;
  String _selectedStudioType = 'Street Shop';

  static const int _maxBioLength = 500;

  static const List<String> _inspirationPrompts = [
    'Resident artist with 5+ yrs experience',
    'Focusing on illustrative blackwork & botanical flash',
    'Trauma-informed, queer-friendly studio space',
    'Silent appointments happily honored',
  ];

  static const List<String> _studioTypes = [
    'Street Shop',
    'Private Studio',
    'Guest Spot',
  ];

  @override
  void initState() {
    super.initState();
    _placesService = widget.googlePlacesService ?? GooglePlacesService();
    _searchController = TextEditingController();
    _manualStudioNameController = TextEditingController(
      text: widget.initialStudio?.name ?? '',
    );
    _manualLocationController = TextEditingController(
      text: widget.initialStudio?.displayLocation ?? '',
    );
    _bioController = TextEditingController(
      text: widget.initialBio ?? '',
    );

    if (widget.initialStudio != null) {
      _selectedStudio = widget.initialStudio;
      _isPrivateStudio = widget.initialStudio!.isPrivateStudio;
      _selectedStudioType = widget.initialStudio!.studioType;
    }

    _searchController.addListener(_onSearchChanged);
    _manualStudioNameController.addListener(_updateState);
    _manualLocationController.addListener(_updateState);
    _bioController.addListener(_updateState);
  }

  void _updateState() {
    if (mounted) setState(() {});
  }

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _predictions = [];
        _isSearching = false;
        _searchError = null;
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted) return;
      setState(() {
        _isSearching = true;
        _searchError = null;
      });

      try {
        final results = await _placesService.searchStudios(query);
        if (mounted) {
          setState(() {
            _predictions = results;
            _isSearching = false;
          });
        }
      } on GooglePlacesApiKeyMissingException {
        if (mounted) {
          setState(() {
            _isSearching = false;
            _searchError = 'GOOGLE_PLACES_API_KEY is not configured in .env. Enter studio manually below.';
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isSearching = false;
            _searchError = 'Unable to search studios. Please enter details manually.';
          });
        }
      }
    });
  }

  Future<void> _selectPrediction(GooglePlacePrediction prediction) async {
    setState(() {
      _isLoadingDetails = true;
      _predictions = [];
      _searchController.clear();
      _searchError = null;
    });

    try {
      final studio = await _placesService.getStudioDetails(
        prediction.placeId,
        fallbackName: prediction.primaryText,
      );
      if (mounted) {
        setState(() {
          _selectedStudio = studio.copyWith(
            isPrivateStudio: _isPrivateStudio,
            studioType: _selectedStudioType,
          );
          _isManualEntry = false;
          _isLoadingDetails = false;
        });
      }
    } catch (e) {
      if (mounted) {
        // Fallback to basic prediction text
        setState(() {
          _selectedStudio = StudioInformation(
            name: prediction.primaryText,
            formattedAddress: prediction.secondaryText,
            city: prediction.secondaryText.split(',').first.trim(),
            placeId: prediction.placeId,
            isPrivateStudio: _isPrivateStudio,
            studioType: _selectedStudioType,
          );
          _isLoadingDetails = false;
        });
      }
    }
  }

  void _clearSelectedStudio() {
    setState(() {
      _selectedStudio = null;
      _searchController.clear();
      _predictions = [];
    });
  }

  void _appendInspirationPrompt(String prompt) {
    final current = _bioController.text.trim();
    String updated;
    if (current.isEmpty) {
      updated = prompt;
    } else if (current.contains(prompt)) {
      return;
    } else {
      updated = '$current • $prompt';
    }

    if (updated.length > _maxBioLength) {
      updated = updated.substring(0, _maxBioLength);
    }

    _bioController.text = updated;
    _bioController.selection = TextSelection.collapsed(offset: updated.length);
  }

  StudioInformation _getEffectiveStudio() {
    if (_selectedStudio != null && !_isManualEntry) {
      return _selectedStudio!.copyWith(
        isPrivateStudio: _isPrivateStudio,
        studioType: _selectedStudioType,
      );
    }

    final name = _manualStudioNameController.text.trim();
    final location = _manualLocationController.text.trim();
    final parts = location.split(',');
    final city = parts.isNotEmpty ? parts[0].trim() : '';
    final state = parts.length > 1 ? parts[1].trim() : '';

    return StudioInformation(
      name: name.isNotEmpty ? name : 'Private Studio',
      formattedAddress: location,
      city: city,
      state: state,
      isPrivateStudio: _isPrivateStudio,
      studioType: _selectedStudioType,
    );
  }

  bool get _isContinueEnabled {
    if (_isLoadingDetails) return false;
    if (_selectedStudio != null && !_isManualEntry) {
      return _selectedStudio!.name.trim().isNotEmpty;
    }
    final name = _manualStudioNameController.text.trim();
    final location = _manualLocationController.text.trim();
    return name.isNotEmpty || location.isNotEmpty;
  }

  Future<void> _handleContinue() async {
    if (!_isContinueEnabled) return;

    final rawStudio = _getEffectiveStudio();
    final studio = await ArtistRepository.ensureStudioCoordinates(
      studioInformation: rawStudio,
      fallbackLocation: _manualLocationController.text.trim().isNotEmpty
          ? _manualLocationController.text.trim()
          : rawStudio.displayLocation,
      studioName: rawStudio.name,
      isPrivateStudio: _isPrivateStudio,
    );
    final bio = _bioController.text.trim();

    if (!mounted) return;
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(context).push(
      FadePageRoute(
        builder: (_) => ArtistPoliciesScreen(
          artistName: widget.artistName,
          photoBytes: widget.photoBytes,
          photoUrl: widget.photoUrl,
          instagramHandle: widget.instagramHandle,
          authService: widget.authService,
          studioInformation: studio,
          artistBio: bio,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _manualStudioNameController.removeListener(_updateState);
    _manualLocationController.removeListener(_updateState);
    _bioController.removeListener(_updateState);
    _searchController.dispose();
    _manualStudioNameController.dispose();
    _manualLocationController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasKey = _placesService.hasApiKey;

    return OnboardingStepScaffold(
      currentStep: 3,
      totalSteps: 9,
      title: 'Where do you tattoo?',
      subtitle: 'Search for your home shop or studio, and add a quick bio for clients.',
      ctaText: 'CONTINUE',
      isCtaEnabled: _isContinueEnabled,
      onCtaPressed: _handleContinue,
      onBack: () {
        FocusManager.instance.primaryFocus?.unfocus();
        Navigator.of(context).pop();
      },
      backgroundOverlay: const TattooBackgroundWrapper(child: SizedBox.expand()),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
            // API Key Missing Warning Banner (if no key in .env)
            if (!hasKey) ...[
              Container(
                key: const Key('places_api_key_missing_banner'),
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF2C2415),
                  borderRadius: BorderRadius.circular(AppRadius.radiusMd),
                  border: Border.all(color: AppTheme.gold.withValues(alpha: 0.4)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, color: AppTheme.gold, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Maps API Key Required in .env',
                            style: GoogleFonts.plusJakartaSans(
                              color: AppTheme.gold,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Add GOOGLE_PLACES_API_KEY to your .env file to enable live Google business search, or use manual studio entry below.',
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFFD4B78F),
                              fontSize: 12,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Section 1: Studio Search / Confirmation
            Text(
              'STUDIO OR SHOP LOCATION',
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.navInactive,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 10),

            if (_selectedStudio != null && !_isManualEntry)
              _buildSelectedStudioCard()
            else if (!_isManualEntry)
              _buildSearchStudioSection()
            else
              _buildManualStudioSection(),

            const SizedBox(height: 20),

            // Studio Type & Privacy toggles
            _buildStudioOptionsCard(),

            const SizedBox(height: 28),

            // Section 2: Artist Bio
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ARTIST BIO',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.navInactive,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
                Text(
                  '${_bioController.text.length}/$_maxBioLength',
                  key: const Key('bio_char_counter'),
                  style: GoogleFonts.plusJakartaSans(
                    color: _bioController.text.length >= _maxBioLength
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF919696),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Bio Input
            AdaptiveGlassContainer(
              useGradient: false,
              borderRadius: AppRadius.radiusMd,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: TextField(
                key: const Key('artist_bio_field'),
                controller: _bioController,
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                scrollPadding: EdgeInsets.only(
                  bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
                ),
                maxLength: _maxBioLength,
                maxLines: 4,
                minLines: 3,
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  height: 1.4,
                ),
                buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                decoration: InputDecoration(
                  hintText: 'Share a brief introduction about your tattoo experience, art focus, or booking philosophy...',
                  hintStyle: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF6B7280),
                    fontSize: 13,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Quick Inspiration Chips
            Text(
              'Quick inspiration prompts (tap to add):',
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF919696),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _inspirationPrompts.map((prompt) {
                return InkWell(
                  key: Key('inspiration_chip_${prompt.hashCode}'),
                  onTap: () => _appendInspirationPrompt(prompt),
                  borderRadius: BorderRadius.circular(AppRadius.radiusFull),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E2020),
                      borderRadius: BorderRadius.circular(AppRadius.radiusFull),
                      border: Border.all(
                        color: AppTheme.darkBorder,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      '+ $prompt',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFFCCCCCC),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 32),
          ],
        ),
      );
  }

  Widget _buildSearchStudioSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdaptiveGlassContainer(
          useGradient: false,
          borderRadius: AppRadius.radiusMd,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Row(
            children: [
              const Icon(Icons.search, color: Color(0xFF919696), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  key: const Key('studio_search_field'),
                  controller: _searchController,
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                  onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                  scrollPadding: EdgeInsets.only(
                    bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
                  ),
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search studio name, street, or city...',
                    hintStyle: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFF6B7280),
                      fontSize: 13,
                    ),
                    border: InputBorder.none,
                  ),
                ),
              ),
              if (_isSearching)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.gold),
                  ),
                ),
            ],
          ),
        ),

        // Error message if search failed
        if (_searchError != null) ...[
          const SizedBox(height: 8),
          Text(
            _searchError!,
            key: const Key('studio_search_error_text'),
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFFEF4444),
              fontSize: 12,
            ),
          ),
        ],

        // Suggestions Dropdown
        if (_predictions.isNotEmpty) ...[
          const SizedBox(height: 8),
          AdaptiveGlassContainer(
            key: const Key('studio_predictions_list'),
            useGradient: false,
            borderRadius: AppRadius.radiusMd,
            padding: EdgeInsets.zero,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: _predictions.length,
                separatorBuilder: (_, _) => const Divider(
                  color: AppTheme.darkBorder,
                  height: 1,
                ),
                itemBuilder: (context, index) {
                  final prediction = _predictions[index];
                  return ListTile(
                    key: Key('prediction_item_$index'),
                    dense: true,
                    leading: const Icon(
                      Icons.location_on_outlined,
                      color: AppTheme.gold,
                      size: 20,
                    ),
                    title: Text(
                      prediction.primaryText,
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: prediction.secondaryText.isNotEmpty
                        ? Text(
                            prediction.secondaryText,
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFF919696),
                              fontSize: 11,
                            ),
                          )
                        : null,
                    onTap: () => _selectPrediction(prediction),
                  );
                },
              ),
            ),
          ),
        ],

        // Manual Entry Switch button
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const Key('toggle_manual_studio_button'),
            onPressed: () {
              setState(() {
                _isManualEntry = true;
                _predictions = [];
              });
            },
            icon: const Icon(Icons.edit_location_alt_outlined, size: 16, color: AppTheme.gold),
            label: Text(
              "Can't find your studio? Enter manually",
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.gold,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedStudioCard() {
    final studio = _selectedStudio!;
    return AdaptiveGlassContainer(
      key: const Key('selected_studio_card'),
      useGradient: false,
      isSelected: true,
      selectedBorderColor: AppTheme.gold.withValues(alpha: 0.6),
      selectedBorderWidth: 1.2,
      borderRadius: AppRadius.radiusMd,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppTheme.goldBadgeBackground,
                  borderRadius: BorderRadius.circular(AppRadius.radiusSm),
                ),
                child: const Center(
                  child: Icon(Icons.storefront, color: AppTheme.gold, size: 20),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      studio.name,
                      key: const Key('selected_studio_name'),
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (studio.formattedAddress.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        studio.formattedAddress,
                        key: const Key('selected_studio_address'),
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF919696),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: AppTheme.darkBorder, height: 1),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              key: const Key('change_studio_button'),
              onPressed: _clearSelectedStudio,
              child: Text(
                'Change Studio',
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.gold,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManualStudioSection() {
    return AdaptiveGlassContainer(
      key: const Key('manual_studio_form'),
      useGradient: false,
      borderRadius: AppRadius.radiusMd,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'MANUAL STUDIO ENTRY',
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.gold,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.6,
                ),
              ),
              GestureDetector(
                key: const Key('switch_back_to_search_button'),
                onTap: () {
                  setState(() {
                    _isManualEntry = false;
                  });
                },
                child: Text(
                  'Switch to Maps Search',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.gold,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Studio / Shop Name *',
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFFCCCCCC),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            key: const Key('manual_studio_name_field'),
            controller: _manualStudioNameController,
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            scrollPadding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
            ),
            style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF121414),
              hintText: 'e.g. Scapegoat Tattoo or Odd Studio',
              hintStyle: GoogleFonts.plusJakartaSans(color: const Color(0xFF6B7280), fontSize: 13),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.radiusSm),
                borderSide: const BorderSide(color: AppTheme.darkBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.radiusSm),
                borderSide: const BorderSide(color: AppTheme.darkBorder),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'City & State *',
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFFCCCCCC),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            key: const Key('manual_studio_location_field'),
            controller: _manualLocationController,
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            scrollPadding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
            ),
            style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF121414),
              hintText: 'e.g. Portland, OR',
              hintStyle: GoogleFonts.plusJakartaSans(color: const Color(0xFF6B7280), fontSize: 13),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.radiusSm),
                borderSide: const BorderSide(color: AppTheme.darkBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.radiusSm),
                borderSide: const BorderSide(color: AppTheme.darkBorder),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudioOptionsCard() {
    return AdaptiveGlassContainer(
      useGradient: false,
      borderRadius: AppRadius.radiusMd,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Studio Type Chips
          Text(
            'STUDIO SETUP',
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFF919696),
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: _studioTypes.map((type) {
              final isSelected = _selectedStudioType == type;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  key: Key('studio_type_chip_$type'),
                  label: Text(type),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedStudioType = type;
                        if (type == 'Private Studio') {
                          _isPrivateStudio = true;
                        }
                      });
                    }
                  },
                  labelStyle: GoogleFonts.plusJakartaSans(
                    color: isSelected ? Colors.black : Colors.white,
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  ),
                  selectedColor: AppTheme.gold,
                  backgroundColor: const Color(0xFF121414),
                  side: BorderSide(
                    color: isSelected ? AppTheme.gold : AppTheme.darkBorder,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          const Divider(color: AppTheme.darkBorder, height: 1),
          const SizedBox(height: 10),

          // Private Studio / Hide Exact Street Address switch
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Private Studio Mode',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Hides exact street address until booking is confirmed with deposit',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF919696),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              FlashSwitch(
                key: const Key('private_studio_switch'),
                value: _isPrivateStudio,
                onChanged: (val) {
                  setState(() => _isPrivateStudio = val);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
