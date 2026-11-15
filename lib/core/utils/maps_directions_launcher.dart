import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';
import '../../widgets/adaptive_glass_container.dart';
import '../../widgets/flash_snack_bar.dart';

/// Supported external navigation apps for opening studio directions.
enum MapsApp {
  appleMaps(
    label: 'Apple Maps',
    subtitle: 'Open route in Apple Maps',
    icon: Icons.explore_rounded,
  ),
  googleMaps(
    label: 'Google Maps',
    subtitle: 'Open route in Google Maps',
    icon: Icons.location_on_rounded,
  ),
  waze(
    label: 'Waze',
    subtitle: 'Open live navigation in Waze',
    icon: Icons.navigation_rounded,
  );

  final String label;
  final String subtitle;
  final IconData icon;

  const MapsApp({
    required this.label,
    required this.subtitle,
    required this.icon,
  });
}

typedef CanLaunchUrlCallback = Future<bool> Function(Uri uri);
typedef LaunchUrlCallback = Future<bool> Function(Uri uri);

/// Detects installed maps apps and launches route directions in the user's
/// preferred maps app (or opens an in-app picker when 2+ apps are installed).
class MapsDirectionsLauncher {
  MapsDirectionsLauncher._();

  @visibleForTesting
  static CanLaunchUrlCallback? debugCanLaunchUrl;

  @visibleForTesting
  static LaunchUrlCallback? debugLaunchUrl;

  @visibleForTesting
  static TargetPlatform? debugPlatformOverride;

  /// Clears test overrides between widget/unit tests.
  @visibleForTesting
  static void resetDebugOverrides() {
    debugCanLaunchUrl = null;
    debugLaunchUrl = null;
    debugPlatformOverride = null;
  }

  /// Returns `true` when [latitude] and [longitude] are non-null and not (0, 0).
  static bool hasValidCoordinates(double? latitude, double? longitude) {
    return latitude != null &&
        longitude != null &&
        (latitude.abs() > 0.0001 || longitude.abs() > 0.0001);
  }

  static String _destinationString({
    required String address,
    double? latitude,
    double? longitude,
  }) {
    if (hasValidCoordinates(latitude, longitude)) {
      return '${latitude!},${longitude!}';
    }
    return address.trim();
  }

  /// Probe URI used with `canLaunchUrl` to detect whether [app] is installed.
  static Uri? probeUriForApp(MapsApp app, TargetPlatform platform) {
    switch (app) {
      case MapsApp.appleMaps:
        if (platform != TargetPlatform.iOS) return null;
        return Uri.parse('maps://?daddr=0,0');
      case MapsApp.googleMaps:
        if (platform == TargetPlatform.iOS) {
          return Uri.parse('comgooglemaps://');
        }
        if (platform == TargetPlatform.android) {
          return Uri.parse('google.navigation:q=0,0');
        }
        return null;
      case MapsApp.waze:
        if (platform == TargetPlatform.iOS ||
            platform == TargetPlatform.android) {
          return Uri.parse('waze://');
        }
        return null;
    }
  }

  /// Builds a route/directions launch URI for [app].
  static Uri directionsUriForApp(
    MapsApp app, {
    required String address,
    double? latitude,
    double? longitude,
    required TargetPlatform platform,
  }) {
    final hasCoords = hasValidCoordinates(latitude, longitude);
    final destination = _destinationString(
      address: address,
      latitude: latitude,
      longitude: longitude,
    );

    switch (app) {
      case MapsApp.appleMaps:
        return Uri.parse(
          'maps://?daddr=${Uri.encodeComponent(destination)}&dirflg=d',
        );
      case MapsApp.googleMaps:
        if (platform == TargetPlatform.iOS) {
          return Uri.parse(
            'comgooglemaps://?daddr=${Uri.encodeComponent(destination)}&directionsmode=driving',
          );
        }
        if (platform == TargetPlatform.android) {
          return Uri.parse(
            'google.navigation:q=${Uri.encodeComponent(destination)}',
          );
        }
        return webDirectionsUri(
          address: address,
          latitude: latitude,
          longitude: longitude,
        );
      case MapsApp.waze:
        if (hasCoords) {
          return Uri.parse(
            'waze://?ll=${latitude!},${longitude!}&navigate=yes',
          );
        }
        return Uri.parse(
          'waze://?q=${Uri.encodeComponent(address.trim())}&navigate=yes',
        );
    }
  }

  /// Browser fallback URL for Google Maps directions.
  static Uri webDirectionsUri({
    required String address,
    double? latitude,
    double? longitude,
  }) {
    final destination = _destinationString(
      address: address,
      latitude: latitude,
      longitude: longitude,
    );
    return Uri.https(
      'www.google.com',
      '/maps/dir/',
      <String, String>{
        'api': '1',
        'destination': destination,
      },
    );
  }

  /// Detects installed supported maps apps on the current platform.
  static Future<List<MapsApp>> detectInstalledApps({
    CanLaunchUrlCallback? canLaunch,
    TargetPlatform? platform,
  }) async {
    final effectivePlatform =
        platform ?? debugPlatformOverride ?? defaultTargetPlatform;
    final effectiveCanLaunch = canLaunch ?? debugCanLaunchUrl ?? canLaunchUrl;

    final List<MapsApp> candidates;
    if (effectivePlatform == TargetPlatform.iOS) {
      candidates = const [
        MapsApp.appleMaps,
        MapsApp.googleMaps,
        MapsApp.waze,
      ];
    } else if (effectivePlatform == TargetPlatform.android) {
      candidates = const [
        MapsApp.googleMaps,
        MapsApp.waze,
      ];
    } else {
      candidates = const <MapsApp>[];
    }

    final installed = <MapsApp>[];
    for (final app in candidates) {
      final probe = probeUriForApp(app, effectivePlatform);
      if (probe == null) continue;
      try {
        if (await effectiveCanLaunch(probe)) {
          installed.add(app);
        }
      } catch (_) {
        // Ignore platform query exceptions and treat the app as unavailable.
      }
    }
    return installed;
  }

  static Future<bool> _defaultLaunch(Uri uri) {
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// Opens directions to the studio:
  /// - 1 installed app: opens directly in route/directions mode
  /// - 2+ installed apps: shows an in-app bottom sheet picker + Copy Address
  /// - 0 installed apps: falls back to web Google Maps (or clipboard copy)
  static Future<void> openDirections(
    BuildContext context, {
    required String address,
    double? latitude,
    double? longitude,
    String? studioName,
    CanLaunchUrlCallback? canLaunch,
    LaunchUrlCallback? launch,
    TargetPlatform? platform,
  }) async {
    final trimmedAddress = address.trim();
    if (trimmedAddress.isEmpty && !hasValidCoordinates(latitude, longitude)) {
      FlashSnackBar.showInfo(context, 'Studio address is not available yet.');
      return;
    }

    final effectivePlatform =
        platform ?? debugPlatformOverride ?? defaultTargetPlatform;
    final effectiveLaunch = launch ?? debugLaunchUrl ?? _defaultLaunch;

    final installedApps = await detectInstalledApps(
      canLaunch: canLaunch,
      platform: effectivePlatform,
    );
    if (!context.mounted) return;

    final copyableDestination = trimmedAddress.isNotEmpty
        ? trimmedAddress
        : '${latitude!},${longitude!}';

    if (installedApps.length == 1) {
      await _launchAppOrFallback(
        context,
        installedApps.single,
        address: trimmedAddress,
        latitude: latitude,
        longitude: longitude,
        copyableDestination: copyableDestination,
        launch: effectiveLaunch,
        platform: effectivePlatform,
      );
      return;
    }

    if (installedApps.length >= 2) {
      await _showMapsPickerSheet(
        context,
        installedApps: installedApps,
        address: trimmedAddress,
        latitude: latitude,
        longitude: longitude,
        studioName: studioName,
        copyableDestination: copyableDestination,
        launch: effectiveLaunch,
        platform: effectivePlatform,
      );
      return;
    }

    await _launchWebOrCopyFallback(
      context,
      address: trimmedAddress,
      latitude: latitude,
      longitude: longitude,
      copyableDestination: copyableDestination,
      launch: effectiveLaunch,
    );
  }

  static Future<void> _launchAppOrFallback(
    BuildContext context,
    MapsApp app, {
    required String address,
    double? latitude,
    double? longitude,
    required String copyableDestination,
    required LaunchUrlCallback launch,
    required TargetPlatform platform,
  }) async {
    final uri = directionsUriForApp(
      app,
      address: address,
      latitude: latitude,
      longitude: longitude,
      platform: platform,
    );

    bool launched = false;
    try {
      launched = await launch(uri);
    } catch (_) {
      launched = false;
    }

    if (launched || !context.mounted) return;

    await _launchWebOrCopyFallback(
      context,
      address: address,
      latitude: latitude,
      longitude: longitude,
      copyableDestination: copyableDestination,
      launch: launch,
    );
  }

  static Future<void> _launchWebOrCopyFallback(
    BuildContext context, {
    required String address,
    double? latitude,
    double? longitude,
    required String copyableDestination,
    required LaunchUrlCallback launch,
  }) async {
    final webUri = webDirectionsUri(
      address: address,
      latitude: latitude,
      longitude: longitude,
    );

    bool launched = false;
    try {
      launched = await launch(webUri);
    } catch (_) {
      launched = false;
    }

    if (launched || !context.mounted) return;

    await Clipboard.setData(ClipboardData(text: copyableDestination));
    if (!context.mounted) return;
    FlashSnackBar.showSuccess(context, 'Studio address copied for directions!');
  }

  static Future<void> _showMapsPickerSheet(
    BuildContext context, {
    required List<MapsApp> installedApps,
    required String address,
    double? latitude,
    double? longitude,
    String? studioName,
    required String copyableDestination,
    required LaunchUrlCallback launch,
    required TargetPlatform platform,
  }) {
    final rootContext = context;
    return showModalBottomSheet<void>(
      context: rootContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final displayName =
            (studioName != null && studioName.trim().isNotEmpty)
                ? studioName.trim()
                : 'Studio';
        return AdaptiveGlassContainer.bottomSheet(
          glassEnabled: false,
          androidSurfaceColor: AppTheme.onyxContainer,
          selectedBorderColor: AppTheme.goldBorder,
          unselectedBorderColor: AppTheme.goldBorder,
          selectedBorderWidth: 1.2,
          unselectedBorderWidth: 1.2,
          topRadius: AppRadius.radiusSheet,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.spaceLg,
            AppSpacing.spaceMd,
            AppSpacing.spaceLg,
            AppSpacing.spaceLg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.darkBorder,
                    borderRadius: BorderRadius.circular(AppRadius.dragHandle),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Open Directions',
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Choose your maps app for $displayName',
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.navInactive,
                  fontSize: 13,
                ),
              ),
              if (address.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  address,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.navInactiveAlt,
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              for (final app in installedApps) ...[
                _MapsPickerOptionTile(
                  key: Key('maps_option_${app.name}'),
                  icon: app.icon,
                  title: app.label,
                  subtitle: app.subtitle,
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await _launchAppOrFallback(
                      rootContext,
                      app,
                      address: address,
                      latitude: latitude,
                      longitude: longitude,
                      copyableDestination: copyableDestination,
                      launch: launch,
                      platform: platform,
                    );
                  },
                ),
                const SizedBox(height: 10),
              ],
              _MapsPickerOptionTile(
                key: const Key('maps_option_copy_address'),
                icon: Icons.copy_rounded,
                title: 'Copy Address',
                subtitle: copyableDestination,
                accentColor: AppTheme.navInactive,
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await Clipboard.setData(
                    ClipboardData(text: copyableDestination),
                  );
                  if (!rootContext.mounted) return;
                  FlashSnackBar.showSuccess(
                    rootContext,
                    'Studio address copied for directions!',
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MapsPickerOptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accentColor;
  final VoidCallback onTap;

  const _MapsPickerOptionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.accentColor = AppTheme.gold,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.radiusMd),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.cardBackground,
            borderRadius: BorderRadius.circular(AppRadius.radiusMd),
            border: Border.all(color: AppTheme.cardBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppTheme.onyxSurface,
                  borderRadius: BorderRadius.circular(AppRadius.radiusSm),
                  border: Border.all(color: AppTheme.darkBorder),
                ),
                child: Icon(icon, color: accentColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.navInactive,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.navInactive,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
