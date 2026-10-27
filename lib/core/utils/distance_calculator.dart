import 'dart:math' as math;
import 'package:geocoding/geocoding.dart' as geocoding;

/// Pure-Dart geographic coordinate pair.
class GeoPointCoords {
  final double latitude;
  final double longitude;
  final String? resolvedLabel;

  const GeoPointCoords({
    required this.latitude,
    required this.longitude,
    this.resolvedLabel,
  });

  bool get isValid =>
      !latitude.isNaN &&
      !longitude.isNaN &&
      latitude >= -90.0 &&
      latitude <= 90.0 &&
      longitude >= -180.0 &&
      longitude <= 180.0 &&
      !(latitude == 0.0 && longitude == 0.0);

  /// Coarsens coordinates to ~2 decimal places (~1.1 km precision) so
  /// discovery distance math works accurately without exposing exact street addresses.
  GeoPointCoords coarsened({int decimals = 2}) {
    final factor = math.pow(10, decimals).toDouble();
    return GeoPointCoords(
      latitude: (latitude * factor).round() / factor,
      longitude: (longitude * factor).round() / factor,
      resolvedLabel: resolvedLabel,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GeoPointCoords &&
          (latitude - other.latitude).abs() < 1e-6 &&
          (longitude - other.longitude).abs() < 1e-6;

  @override
  int get hashCode => Object.hash(
        (latitude * 1e6).round(),
        (longitude * 1e6).round(),
      );
}

/// Deterministic Haversine geospatial distance engine and fallback geocoder.
class DistanceCalculator {
  DistanceCalculator._();

  static const double _earthRadiusMiles = 3958.7613;
  static const double _earthRadiusKilometers = 6371.0088;

  /// Computes great-circle distance in **miles** between two WGS84 coordinates
  /// using the Haversine formula.
  static double calculateMiles({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  }) {
    final radians = _haversineCentralAngle(
      startLatitude: startLatitude,
      startLongitude: startLongitude,
      endLatitude: endLatitude,
      endLongitude: endLongitude,
    );
    return _earthRadiusMiles * radians;
  }

  /// Computes great-circle distance in **kilometers** between two WGS84 coordinates
  /// using the Haversine formula.
  static double calculateKilometers({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  }) {
    final radians = _haversineCentralAngle(
      startLatitude: startLatitude,
      startLongitude: startLongitude,
      endLatitude: endLatitude,
      endLongitude: endLongitude,
    );
    return _earthRadiusKilometers * radians;
  }

  static double _haversineCentralAngle({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  }) {
    final dLat = _toRadians(endLatitude - startLatitude);
    final dLon = _toRadians(endLongitude - startLongitude);
    final lat1 = _toRadians(startLatitude);
    final lat2 = _toRadians(endLatitude);

    final sinHalfDLat = math.sin(dLat / 2.0);
    final sinHalfDLon = math.sin(dLon / 2.0);

    final a = (sinHalfDLat * sinHalfDLat) +
        (math.cos(lat1) * math.cos(lat2) * sinHalfDLon * sinHalfDLon);
    final clampedA = a.clamp(0.0, 1.0);
    return 2.0 * math.atan2(math.sqrt(clampedA), math.sqrt(1.0 - clampedA));
  }

  static double _toRadians(double degrees) => degrees * (math.pi / 180.0);

  /// Formats a distance in miles for Client discovery cards & Artist headers
  /// (e.g., `4.2 mi away` or `< 0.1 mi away`).
  static String formatMilesAway(double miles) {
    if (miles.isNaN || miles.isInfinite || miles < 0) {
      return 'Location set';
    }
    if (miles < 0.1) {
      return '< 0.1 mi away';
    }
    return '${miles.toStringAsFixed(1)} mi away';
  }

  /// Formats a distance in kilometers (e.g., `6.8 km away`).
  static String formatKilometersAway(double kilometers) {
    if (kilometers.isNaN || kilometers.isInfinite || kilometers < 0) {
      return 'Location set';
    }
    if (kilometers < 0.1) {
      return '< 0.1 km away';
    }
    return '${kilometers.toStringAsFixed(1)} km away';
  }

  /// Parses an existing distance string (e.g. `'4.2 mi away'` or `'1.2 mi'`) to numeric miles.
  static double? tryParseMiles(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    if (raw.contains('< 0.1')) return 0.05;
    final match = RegExp(r'([0-9]+(?:\.[0-9]+)?)').firstMatch(raw);
    if (match == null) return null;
    return double.tryParse(match.group(1)!);
  }

  /// Known city/ZIP centroids used as an offline/headless fallback when native
  /// geocoding platform channels are unavailable (e.g. simulator without network or CI).
  static const Map<String, GeoPointCoords> _knownLocations = {
    // Oregon
    'newberg, or': GeoPointCoords(latitude: 45.3001, longitude: -122.9731, resolvedLabel: 'Newberg, OR'),
    'newberg': GeoPointCoords(latitude: 45.3001, longitude: -122.9731, resolvedLabel: 'Newberg, OR'),
    '97132': GeoPointCoords(latitude: 45.3001, longitude: -122.9731, resolvedLabel: 'Newberg, OR'),
    'portland, or': GeoPointCoords(latitude: 45.5152, longitude: -122.6784, resolvedLabel: 'Portland, OR'),
    'portland': GeoPointCoords(latitude: 45.5152, longitude: -122.6784, resolvedLabel: 'Portland, OR'),
    '97201': GeoPointCoords(latitude: 45.5152, longitude: -122.6784, resolvedLabel: 'Portland, OR'),
    '97204': GeoPointCoords(latitude: 45.5189, longitude: -122.6752, resolvedLabel: 'Portland, OR'),
    '97205': GeoPointCoords(latitude: 45.5202, longitude: -122.6844, resolvedLabel: 'Portland, OR'),
    '97209': GeoPointCoords(latitude: 45.5286, longitude: -122.6845, resolvedLabel: 'Portland, OR'),
    '97214': GeoPointCoords(latitude: 45.5135, longitude: -122.6531, resolvedLabel: 'Portland, OR'),
    'beaverton, or': GeoPointCoords(latitude: 45.4871, longitude: -122.8037, resolvedLabel: 'Beaverton, OR'),
    '97005': GeoPointCoords(latitude: 45.4871, longitude: -122.8037, resolvedLabel: 'Beaverton, OR'),
    'salem, or': GeoPointCoords(latitude: 44.9429, longitude: -123.0351, resolvedLabel: 'Salem, OR'),
    'eugene, or': GeoPointCoords(latitude: 44.0521, longitude: -123.0868, resolvedLabel: 'Eugene, OR'),
    // California
    'los angeles, ca': GeoPointCoords(latitude: 34.0522, longitude: -118.2437, resolvedLabel: 'Los Angeles, CA'),
    'los angeles': GeoPointCoords(latitude: 34.0522, longitude: -118.2437, resolvedLabel: 'Los Angeles, CA'),
    '90012': GeoPointCoords(latitude: 34.0614, longitude: -118.2386, resolvedLabel: 'Los Angeles, CA'),
    '90013': GeoPointCoords(latitude: 34.0446, longitude: -118.2400, resolvedLabel: 'Los Angeles, CA'),
    '90026': GeoPointCoords(latitude: 34.0869, longitude: -118.2702, resolvedLabel: 'Los Angeles, CA'),
    'silver lake, ca': GeoPointCoords(latitude: 34.0869, longitude: -118.2702, resolvedLabel: 'Silver Lake, CA'),
    '90210': GeoPointCoords(latitude: 34.0901, longitude: -118.4065, resolvedLabel: 'Beverly Hills, CA'),
    'beverly hills, ca': GeoPointCoords(latitude: 34.0901, longitude: -118.4065, resolvedLabel: 'Beverly Hills, CA'),
    'san francisco, ca': GeoPointCoords(latitude: 37.7749, longitude: -122.4194, resolvedLabel: 'San Francisco, CA'),
    'san francisco': GeoPointCoords(latitude: 37.7749, longitude: -122.4194, resolvedLabel: 'San Francisco, CA'),
    '94102': GeoPointCoords(latitude: 37.7793, longitude: -122.4193, resolvedLabel: 'San Francisco, CA'),
    '94103': GeoPointCoords(latitude: 37.7726, longitude: -122.4099, resolvedLabel: 'San Francisco, CA'),
    'san diego, ca': GeoPointCoords(latitude: 32.7157, longitude: -117.1611, resolvedLabel: 'San Diego, CA'),
    // Washington / NY / TX / IL / CO / FL
    'seattle, wa': GeoPointCoords(latitude: 47.6062, longitude: -122.3321, resolvedLabel: 'Seattle, WA'),
    'seattle': GeoPointCoords(latitude: 47.6062, longitude: -122.3321, resolvedLabel: 'Seattle, WA'),
    '98101': GeoPointCoords(latitude: 47.6101, longitude: -122.3344, resolvedLabel: 'Seattle, WA'),
    'new york, ny': GeoPointCoords(latitude: 40.7128, longitude: -74.0060, resolvedLabel: 'New York, NY'),
    'brooklyn, ny': GeoPointCoords(latitude: 40.6782, longitude: -73.9442, resolvedLabel: 'Brooklyn, NY'),
    '10001': GeoPointCoords(latitude: 40.7506, longitude: -73.9972, resolvedLabel: 'New York, NY'),
    '11211': GeoPointCoords(latitude: 40.7128, longitude: -73.9575, resolvedLabel: 'Brooklyn, NY'),
    'austin, tx': GeoPointCoords(latitude: 30.2672, longitude: -97.7431, resolvedLabel: 'Austin, TX'),
    '78701': GeoPointCoords(latitude: 30.2711, longitude: -97.7437, resolvedLabel: 'Austin, TX'),
    'chicago, il': GeoPointCoords(latitude: 41.8781, longitude: -87.6298, resolvedLabel: 'Chicago, IL'),
    '60601': GeoPointCoords(latitude: 41.8853, longitude: -87.6216, resolvedLabel: 'Chicago, IL'),
    'denver, co': GeoPointCoords(latitude: 39.7392, longitude: -104.9903, resolvedLabel: 'Denver, CO'),
    '80202': GeoPointCoords(latitude: 39.7527, longitude: -104.9997, resolvedLabel: 'Denver, CO'),
    'miami, fl': GeoPointCoords(latitude: 25.7617, longitude: -80.1918, resolvedLabel: 'Miami, FL'),
    '33101': GeoPointCoords(latitude: 25.7751, longitude: -80.1947, resolvedLabel: 'Miami, FL'),
  };

  /// Resolves discovery-safe coordinates from city/state/ZIP text.
  /// Tries platform geocoding first (when available), then falls back to known
  /// city/ZIP centroids or regional ZIP-prefix centroids so coordinates are guaranteed.
  static Future<GeoPointCoords?> resolveCoordinates({
    String? city,
    String? state,
    String? postalCode,
    String? freeformLocation,
  }) async {
    final zip = postalCode?.trim() ?? '';
    final cleanCity = city?.trim() ?? '';
    final cleanState = state?.trim() ?? '';
    final composed = [
      if (cleanCity.isNotEmpty) cleanCity,
      if (cleanState.isNotEmpty) cleanState,
    ].join(', ');
    final query = [
      if (composed.isNotEmpty) composed,
      if (zip.isNotEmpty) zip,
      if (composed.isEmpty && zip.isEmpty && (freeformLocation?.trim().isNotEmpty ?? false))
        freeformLocation!.trim(),
    ].join(' ').trim();

    // 1. Check exact local lookup first for deterministic instant match on known ZIPs/cities
    final normalizedComposed = composed.toLowerCase();
    if (zip.isNotEmpty && _knownLocations.containsKey(zip)) {
      return _knownLocations[zip];
    }
    if (normalizedComposed.isNotEmpty && _knownLocations.containsKey(normalizedComposed)) {
      return _knownLocations[normalizedComposed];
    }
    if (cleanCity.isNotEmpty && _knownLocations.containsKey(cleanCity.toLowerCase())) {
      return _knownLocations[cleanCity.toLowerCase()];
    }
    if (freeformLocation != null) {
      final normFree = freeformLocation.trim().toLowerCase();
      if (_knownLocations.containsKey(normFree)) {
        return _knownLocations[normFree];
      }
      for (final entry in _knownLocations.entries) {
        if (entry.key.length >= 5 && normFree.contains(entry.key)) {
          return entry.value;
        }
      }
    }

    // 2. Attempt platform geocoder when running on device/simulator with network
    if (query.isNotEmpty) {
      try {
        final locations = await geocoding.Geocoding()
            .locationFromAddress(query)
            .timeout(const Duration(seconds: 2));
        if (locations.isNotEmpty) {
          final loc = locations.first;
          final coords = GeoPointCoords(
            latitude: loc.latitude,
            longitude: loc.longitude,
            resolvedLabel: composed.isNotEmpty ? composed : freeformLocation,
          );
          if (coords.isValid) {
            return coords;
          }
        }
      } catch (_) {
        // Platform channel unavailable in unit tests or offline; continue to prefix fallback.
      }
    }

    // 3. Fallback by US 3-digit ZIP prefix / state code so manual entry always gets valid regional coords
    if (zip.length >= 3) {
      final prefix = int.tryParse(zip.substring(0, 3));
      if (prefix != null) {
        return _zipPrefixCentroid(prefix, label: composed.isNotEmpty ? composed : 'ZIP $zip');
      }
    }
    if (cleanState.isNotEmpty) {
      final stateCoords = _stateCentroid(cleanState.toUpperCase(), cityLabel: composed);
      if (stateCoords != null) return stateCoords;
    }

    return null;
  }

  static GeoPointCoords? _zipPrefixCentroid(int prefix, {String? label}) {
    if (prefix >= 970 && prefix <= 979) {
      return GeoPointCoords(latitude: 45.5152, longitude: -122.6784, resolvedLabel: label ?? 'Oregon');
    }
    if (prefix >= 980 && prefix <= 994) {
      return GeoPointCoords(latitude: 47.6062, longitude: -122.3321, resolvedLabel: label ?? 'Washington');
    }
    if (prefix >= 900 && prefix <= 935) {
      return GeoPointCoords(latitude: 34.0522, longitude: -118.2437, resolvedLabel: label ?? 'Southern California');
    }
    if (prefix >= 936 && prefix <= 961) {
      return GeoPointCoords(latitude: 37.7749, longitude: -122.4194, resolvedLabel: label ?? 'Northern California');
    }
    if (prefix >= 100 && prefix <= 149) {
      return GeoPointCoords(latitude: 40.7128, longitude: -74.0060, resolvedLabel: label ?? 'New York');
    }
    if (prefix >= 750 && prefix <= 799) {
      return GeoPointCoords(latitude: 30.2672, longitude: -97.7431, resolvedLabel: label ?? 'Texas');
    }
    if (prefix >= 600 && prefix <= 629) {
      return GeoPointCoords(latitude: 41.8781, longitude: -87.6298, resolvedLabel: label ?? 'Illinois');
    }
    if (prefix >= 800 && prefix <= 816) {
      return GeoPointCoords(latitude: 39.7392, longitude: -104.9903, resolvedLabel: label ?? 'Colorado');
    }
    if (prefix >= 320 && prefix <= 349) {
      return GeoPointCoords(latitude: 25.7617, longitude: -80.1918, resolvedLabel: label ?? 'Florida');
    }
    return GeoPointCoords(latitude: 39.8283, longitude: -98.5795, resolvedLabel: label);
  }

  static GeoPointCoords? _stateCentroid(String stateCode, {String? cityLabel}) {
    switch (stateCode) {
      case 'OR':
      case 'OREGON':
        return GeoPointCoords(latitude: 45.5152, longitude: -122.6784, resolvedLabel: cityLabel ?? 'Portland, OR');
      case 'WA':
      case 'WASHINGTON':
        return GeoPointCoords(latitude: 47.6062, longitude: -122.3321, resolvedLabel: cityLabel ?? 'Seattle, WA');
      case 'CA':
      case 'CALIFORNIA':
        return GeoPointCoords(latitude: 34.0522, longitude: -118.2437, resolvedLabel: cityLabel ?? 'Los Angeles, CA');
      case 'NY':
      case 'NEW YORK':
        return GeoPointCoords(latitude: 40.7128, longitude: -74.0060, resolvedLabel: cityLabel ?? 'New York, NY');
      case 'TX':
      case 'TEXAS':
        return GeoPointCoords(latitude: 30.2672, longitude: -97.7431, resolvedLabel: cityLabel ?? 'Austin, TX');
      case 'IL':
      case 'ILLINOIS':
        return GeoPointCoords(latitude: 41.8781, longitude: -87.6298, resolvedLabel: cityLabel ?? 'Chicago, IL');
      case 'CO':
      case 'COLORADO':
        return GeoPointCoords(latitude: 39.7392, longitude: -104.9903, resolvedLabel: cityLabel ?? 'Denver, CO');
      case 'FL':
      case 'FLORIDA':
        return GeoPointCoords(latitude: 25.7617, longitude: -80.1918, resolvedLabel: cityLabel ?? 'Miami, FL');
      default:
        return null;
    }
  }
}
