import '../core/utils/distance_calculator.dart';

class StudioInformation {
  final String name;
  final String formattedAddress;
  final String city;
  final String state;
  final String postalCode;
  final String? placeId;
  final double? latitude;
  final double? longitude;
  final bool isPrivateStudio;
  final String studioType;

  const StudioInformation({
    required this.name,
    this.formattedAddress = '',
    this.city = '',
    this.state = '',
    this.postalCode = '',
    this.placeId,
    this.latitude,
    this.longitude,
    this.isPrivateStudio = false,
    this.studioType = 'Street Shop',
  });

  String get displayLocation {
    if (city.isNotEmpty && state.isNotEmpty) {
      return '$city, $state';
    } else if (city.isNotEmpty) {
      return city;
    } else if (!isPrivateStudio && formattedAddress.isNotEmpty) {
      return formattedAddress;
    }
    return name;
  }

  /// Discovery-safe coordinates: coarsened to ~2 decimal places (~1.1 km) when
  /// [isPrivateStudio] is true so private street addresses cannot be pinpointed.
  GeoPointCoords? get discoveryCoordinates {
    if (latitude == null || longitude == null) return null;
    final raw = GeoPointCoords(
      latitude: latitude!,
      longitude: longitude!,
      resolvedLabel: displayLocation,
    );
    if (!raw.isValid) return null;
    return isPrivateStudio ? raw.coarsened(decimals: 2) : raw;
  }

  /// Full serialization (appropriate for local state or isolated private subcollections).
  Map<String, dynamic> toMap() => {
    'name': name,
    'formattedAddress': formattedAddress,
    'city': city,
    'state': state,
    'postalCode': postalCode,
    'placeId': placeId,
    'latitude': latitude,
    'longitude': longitude,
    'isPrivateStudio': isPrivateStudio,
    'studioType': studioType,
  };

  /// Privacy-safe serialization for public `/artists/{uid}` documents.
  /// Redacts private street addresses, place IDs, and coarsens coordinates
  /// when [isPrivateStudio] is enabled.
  Map<String, dynamic> toPublicMap() {
    final safeCoords = discoveryCoordinates;
    final safeAddress = isPrivateStudio
        ? (city.isNotEmpty && state.isNotEmpty ? '$city, $state' : city)
        : formattedAddress;
    return {
      'name': name,
      'formattedAddress': safeAddress,
      'city': city,
      'state': state,
      'postalCode': isPrivateStudio ? '' : postalCode,
      if (!isPrivateStudio && placeId != null) 'placeId': placeId,
      'latitude': safeCoords?.latitude,
      'longitude': safeCoords?.longitude,
      'isPrivateStudio': isPrivateStudio,
      'studioType': studioType,
    };
  }

  factory StudioInformation.fromMap(Map<String, dynamic> map) => StudioInformation(
    name: map['name']?.toString() ?? '',
    formattedAddress: map['formattedAddress']?.toString() ?? map['address']?.toString() ?? '',
    city: map['city']?.toString() ?? '',
    state: map['state']?.toString() ?? '',
    postalCode: map['postalCode']?.toString() ?? '',
    placeId: map['placeId']?.toString(),
    latitude: (map['latitude'] is num) ? (map['latitude'] as num).toDouble() : null,
    longitude: (map['longitude'] is num) ? (map['longitude'] as num).toDouble() : null,
    isPrivateStudio: map['isPrivateStudio'] == true,
    studioType: map['studioType']?.toString() ?? 'Street Shop',
  );

  StudioInformation copyWith({
    String? name,
    String? formattedAddress,
    String? city,
    String? state,
    String? postalCode,
    String? placeId,
    double? latitude,
    double? longitude,
    bool? isPrivateStudio,
    String? studioType,
  }) {
    return StudioInformation(
      name: name ?? this.name,
      formattedAddress: formattedAddress ?? this.formattedAddress,
      city: city ?? this.city,
      state: state ?? this.state,
      postalCode: postalCode ?? this.postalCode,
      placeId: placeId ?? this.placeId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isPrivateStudio: isPrivateStudio ?? this.isPrivateStudio,
      studioType: studioType ?? this.studioType,
    );
  }
}
