import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/utils/distance_calculator.dart';
import '../providers/app_providers.dart';
import '../services/location_service.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import '../widgets/adaptive_glass_container.dart';
import '../widgets/flash_glass_app_bar.dart';
import '../widgets/flash_snack_bar.dart';
import '../widgets/flash_switch.dart';

/// Screen allowing the user to view and manage their location permissions,
/// review privacy policies regarding location usage, and configure in-app
/// live GPS discovery preferences.
class LocationSettingsScreen extends ConsumerStatefulWidget {
  final LocationPlatformDelegate? locationDelegate;

  const LocationSettingsScreen({
    super.key,
    this.locationDelegate,
  });

  @override
  ConsumerState<LocationSettingsScreen> createState() => _LocationSettingsScreenState();
}

class _LocationSettingsScreenState extends ConsumerState<LocationSettingsScreen>
    with WidgetsBindingObserver {
  LocationPermission _permission = LocationPermission.denied;
  bool _isLocationServiceEnabled = true;
  bool _isLoading = true;
  bool _isLocating = false;
  String? _resolvedLocationLabel;
  double? _latitude;
  double? _longitude;

  LocationPlatformDelegate? get _delegate =>
      widget.locationDelegate ?? LocationService.delegate;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadLocationState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadLocationState(silent: true);
    }
  }

  Future<void> _loadLocationState({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final serviceEnabled = _delegate != null
          ? await _delegate!.isLocationServiceEnabled()
          : await LocationService.isLocationServiceEnabled();

      final permission = _delegate != null
          ? await _delegate!.checkPermission()
          : await LocationService.checkPermission();

      String? currentLabel = _resolvedLocationLabel;
      double? lat = _latitude;
      double? lng = _longitude;

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        final existingCoords = ref.read(effectiveClientCoordinatesProvider);
        if (existingCoords != null && existingCoords.isValid) {
          lat = existingCoords.latitude;
          lng = existingCoords.longitude;
          currentLabel = existingCoords.resolvedLabel;
        }
      }

      if (mounted) {
        setState(() {
          _isLocationServiceEnabled = serviceEnabled;
          _permission = permission;
          _latitude = lat;
          _longitude = lng;
          _resolvedLocationLabel = currentLabel;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  bool get _isGranted =>
      _permission == LocationPermission.whileInUse ||
      _permission == LocationPermission.always;

  Future<void> _requestPermission() async {
    setState(() => _isLoading = true);
    try {
      final result = _delegate != null
          ? await _delegate!.requestPermission()
          : await LocationService.requestPermission();

      final serviceEnabled = _delegate != null
          ? await _delegate!.isLocationServiceEnabled()
          : await LocationService.isLocationServiceEnabled();

      if (mounted) {
        setState(() {
          _permission = result;
          _isLocationServiceEnabled = serviceEnabled;
          _isLoading = false;
        });
      }

      if (result == LocationPermission.whileInUse ||
          result == LocationPermission.always) {
        await _fetchCurrentLocation();
      } else {
        if (mounted) {
          ref.read(useLiveLocationPreferenceProvider.notifier).setEnabled(false);
        }
        if (result == LocationPermission.deniedForever && mounted) {
          FlashSnackBar.showInfo(
            context,
            'Location access is blocked in device settings.',
          );
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openAppSettings() async {
    if (_delegate != null) {
      await _delegate!.openAppSettings();
      return;
    }
    await LocationService.openAppSettings();
  }

  Future<void> _openLocationSettings() async {
    if (_delegate != null) {
      await _delegate!.openLocationSettings();
      return;
    }
    await LocationService.openLocationSettings();
  }

  Future<void> _fetchCurrentLocation() async {
    setState(() => _isLocating = true);
    try {
      final result = _delegate != null
          ? await _delegate!.getCurrentLocation()
          : await LocationService.getCurrentLocation();

      if (result != null && mounted) {
        setState(() {
          _latitude = result.latitude;
          _longitude = result.longitude;
          _resolvedLocationLabel = result.cityStateLabel.isNotEmpty
              ? result.cityStateLabel
              : '${result.latitude.toStringAsFixed(3)}, ${result.longitude.toStringAsFixed(3)}';
        });

        ref.read(liveGpsCoordinatesProvider.notifier).setCoordinates(
              GeoPointCoords(
                latitude: result.latitude,
                longitude: result.longitude,
                resolvedLabel: result.cityStateLabel,
              ),
            );

        FlashSnackBar.showSuccess(
          context,
          'Location updated: ${_resolvedLocationLabel ?? "GPS position locked"}',
        );
      } else if (mounted) {
        FlashSnackBar.showError(
          context,
          'Unable to acquire current GPS location. Please check signal or device permissions.',
        );
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title,
        style: GoogleFonts.plusJakartaSans(
          color: const Color(0xFF6B7280),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSettingsContainer(List<Widget> children) {
    return AdaptiveGlassContainer(
      useGradient: false,
      borderRadius: 16.0,
      padding: EdgeInsets.zero,
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildPreferencesSection() {
    final useLive = ref.watch(useLiveLocationPreferenceProvider);
    final isToggleActive = useLive && _isGranted && _isLocationServiceEnabled;

    return _buildSettingsContainer([
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.gps_fixed_rounded, color: AppTheme.gold, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Use Live GPS Location',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Query live GPS coordinates for nearest studios and artists',
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFF919696),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FlashSwitch(
              key: const Key('use_precise_location_switch'),
              value: isToggleActive,
              onChanged: _isLoading
                  ? null
                  : (val) async {
                      if (!val) {
                        ref.read(useLiveLocationPreferenceProvider.notifier).setEnabled(false);
                        return;
                      }
                      if (!_isLocationServiceEnabled) {
                        await _openLocationSettings();
                        return;
                      }
                      if (_permission == LocationPermission.deniedForever) {
                        await _openAppSettings();
                        return;
                      }
                      ref.read(useLiveLocationPreferenceProvider.notifier).setEnabled(true);
                      if (!_isGranted) {
                        await _requestPermission();
                      }
                    },
            ),
          ],
        ),
      ),
      const Divider(color: AppTheme.darkBorder, height: 1),
      ListTile(
        key: const Key('current_location_tile'),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: const Icon(Icons.my_location_rounded, color: AppTheme.gold, size: 20),
        title: Text(
          'Resolved Location',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 14.5,
          ),
        ),
        subtitle: Text(
          _resolvedLocationLabel != null && _resolvedLocationLabel!.isNotEmpty
              ? _resolvedLocationLabel!
              : (_latitude != null && _longitude != null
                  ? '${_latitude!.toStringAsFixed(3)}, ${_longitude!.toStringAsFixed(3)}'
                  : 'No location detected yet'),
          style: GoogleFonts.plusJakartaSans(
            color: const Color(0xFF919696),
            fontSize: 12.5,
          ),
        ),
        trailing: IconButton(
          key: const Key('refresh_location_button'),
          tooltip: 'Refresh Current Location',
          icon: _isLocating
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.gold),
                )
              : const Icon(Icons.refresh_rounded, color: AppTheme.gold, size: 20),
          onPressed: _isLocating ? null : _fetchCurrentLocation,
        ),
      ),
    ]);
  }

  Widget _buildPrivacySection() {
    return _buildSettingsContainer([
      Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildPrivacyRow(
              icon: Icons.shield_outlined,
              title: 'On-Demand Access Only',
              description: 'We query GPS coordinates only when you actively discover artists or open the studio map.',
            ),
            const SizedBox(height: 14),
            _buildPrivacyRow(
              icon: Icons.not_interested_rounded,
              title: 'Zero Background Tracking',
              description: 'Flash.Ink never monitors your location when the app is in the background or closed.',
            ),
            const SizedBox(height: 14),
            _buildPrivacyRow(
              icon: Icons.lock_outline_rounded,
              title: 'Strict Privacy',
              description: 'Exact coordinates are encrypted and never sold to third parties or advertisers.',
            ),
          ],
        ),
      ),
    ]);
  }

  Widget _buildPrivacyRow({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppTheme.gold, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF919696),
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121414),
      extendBodyBehindAppBar: true,
      appBar: FlashGlassAppBar(
        leading: IconButton(
          key: const Key('location_settings_back_button'),
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppTheme.textPrimary,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Location Permissions',
          key: const Key('location_settings_title'),
          style: GoogleFonts.plusJakartaSans(
            color: AppTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          SizedBox(
            height: MediaQuery.paddingOf(context).top + kToolbarHeight,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.spaceLg,
                16,
                AppSpacing.spaceLg,
                MediaQuery.paddingOf(context).bottom + 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader('IN-APP PREFERENCES'),
                  const SizedBox(height: 10),
                  _buildPreferencesSection(),
                  const SizedBox(height: 24),
                  _buildSectionHeader('HOW WE PROTECT YOUR PRIVACY'),
                  const SizedBox(height: 10),
                  _buildPrivacySection(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
