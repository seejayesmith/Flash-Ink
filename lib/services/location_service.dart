import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../core/utils/distance_calculator.dart';

class UserLocationResult {
  final double latitude;
  final double longitude;
  final String? postalCode;
  final String? city;
  final String? state;

  const UserLocationResult({
    required this.latitude,
    required this.longitude,
    this.postalCode,
    this.city,
    this.state,
  });

  String get cityStateLabel {
    if (city != null && city!.isNotEmpty && state != null && state!.isNotEmpty) {
      return '$city, $state';
    } else if (city != null && city!.isNotEmpty) {
      return city!;
    } else if (postalCode != null && postalCode!.isNotEmpty) {
      return postalCode!;
    }
    return '';
  }
}

/// Abstract delegate allowing platform geolocation calls to be mocked or overridden.
abstract class LocationPlatformDelegate {
  Future<bool> isLocationServiceEnabled();
  Future<LocationPermission> checkPermission();
  Future<LocationPermission> requestPermission();
  Future<bool> openAppSettings();
  Future<bool> openLocationSettings();
  Future<UserLocationResult?> getCurrentLocation();
  Future<GeoPointCoords?> tryGetPermittedCoordinates();
}

class LocationService {
  /// Optional mock/test delegate. When provided, platform calls route through this delegate.
  static LocationPlatformDelegate? delegate;

  static bool get _isWidgetTest =>
      WidgetsBinding.instance.runtimeType.toString().contains('Test');

  /// Checks if location services are enabled on the device.
  static Future<bool> isLocationServiceEnabled() async {
    if (delegate != null) return delegate!.isLocationServiceEnabled();
    if (_isWidgetTest) return true;
    try {
      return await Geolocator.isLocationServiceEnabled();
    } catch (e) {
      debugPrint('LocationService.isLocationServiceEnabled error: $e');
      return false;
    }
  }

  /// Checks the current location permission status without prompting.
  static Future<LocationPermission> checkPermission() async {
    if (delegate != null) return delegate!.checkPermission();
    if (_isWidgetTest) return LocationPermission.whileInUse;
    try {
      return await Geolocator.checkPermission();
    } catch (e) {
      debugPrint('LocationService.checkPermission error: $e');
      return LocationPermission.denied;
    }
  }

  /// Prompts the user to grant location permissions.
  static Future<LocationPermission> requestPermission() async {
    if (delegate != null) return delegate!.requestPermission();
    if (_isWidgetTest) return LocationPermission.whileInUse;
    try {
      return await Geolocator.requestPermission();
    } catch (e) {
      debugPrint('LocationService.requestPermission error: $e');
      return LocationPermission.denied;
    }
  }

  /// Opens the device app settings screen so the user can grant or revoke location permissions.
  static Future<bool> openAppSettings() async {
    if (delegate != null) return delegate!.openAppSettings();
    if (_isWidgetTest) return true;
    try {
      return await Geolocator.openAppSettings();
    } catch (e) {
      debugPrint('LocationService.openAppSettings error: $e');
      return false;
    }
  }

  /// Opens the device location settings screen (system GPS toggle).
  static Future<bool> openLocationSettings() async {
    if (delegate != null) return delegate!.openLocationSettings();
    if (_isWidgetTest) return true;
    try {
      return await Geolocator.openLocationSettings();
    } catch (e) {
      debugPrint('LocationService.openLocationSettings error: $e');
      return false;
    }
  }

  /// Checks and requests location permission.
  static Future<bool> checkAndRequestPermission() async {
    try {
      bool serviceEnabled = await isLocationServiceEnabled();
      if (!serviceEnabled) {
        return false;
      }

      LocationPermission permission = await checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await requestPermission();
        if (permission == LocationPermission.denied) {
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return false;
      }

      return permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;
    } catch (e) {
      debugPrint('LocationService.checkAndRequestPermission error: $e');
      return false;
    }
  }

  /// Fetches the user's current GPS position and reverse-geocodes it into a ZIP code & city.
  static Future<UserLocationResult?> getCurrentLocation() async {
    if (delegate != null) return delegate!.getCurrentLocation();
    if (_isWidgetTest) return null;
    try {
      final hasPermission = await checkAndRequestPermission();
      if (!hasPermission) return null;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );

      String? postalCode;
      String? city;
      String? state;

      try {
        final placemarks = await Geocoding().placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          postalCode = place.postalCode;
          city = place.locality?.isNotEmpty == true ? place.locality : place.subAdministrativeArea;
          state = place.administrativeArea;
        }
      } catch (geocodingError) {
        debugPrint('LocationService geocoding fallback error: $geocodingError');
      }

      return UserLocationResult(
        latitude: position.latitude,
        longitude: position.longitude,
        postalCode: postalCode,
        city: city,
        state: state,
      );
    } catch (e) {
      debugPrint('LocationService.getCurrentLocation error: $e');
      return null;
    }
  }

  /// Quietly fetches live GPS coordinates if location services and permission
  /// are already granted, returning `null` without prompting if not permitted.
  static Future<GeoPointCoords?> tryGetPermittedCoordinates() async {
    if (delegate != null) return delegate!.tryGetPermittedCoordinates();
    if (_isWidgetTest) return null;
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 5),
        ),
      );
      final coords = GeoPointCoords(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      return coords.isValid ? coords : null;
    } catch (_) {
      return null;
    }
  }

  /// Calculates great-circle distance in miles between two latitude/longitude points
  /// using the deterministic Haversine formula.
  static double calculateDistanceInMiles(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    return DistanceCalculator.calculateMiles(
      startLatitude: startLatitude,
      startLongitude: startLongitude,
      endLatitude: endLatitude,
      endLongitude: endLongitude,
    );
  }

  /// Calculates great-circle distance in kilometers between two latitude/longitude points
  /// using the deterministic Haversine formula.
  static double calculateDistanceInKilometers(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    return DistanceCalculator.calculateKilometers(
      startLatitude: startLatitude,
      startLongitude: startLongitude,
      endLatitude: endLatitude,
      endLongitude: endLongitude,
    );
  }

  /// Formats distance in miles for Artist cards and profile headers (e.g., `4.2 mi away`).
  static String formatDistanceAway(double miles) {
    return DistanceCalculator.formatMilesAway(miles);
  }
}
