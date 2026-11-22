import '../../models/google_place_models.dart';

/// Classifies whether a Google Places result represents a legitimate tattoo/body-art studio.
class TattooPlaceClassifier {
  const TattooPlaceClassifier._();

  /// Official Google Places Table A primary type for tattoo & body art studios.
  static const String kBodyArtServiceType = 'body_art_service';

  /// Positive Google Places category identifiers for tattoo shops.
  static const Set<String> tattooPlaceTypes = {
    'body_art_service',
    'tattoo_shop',
    'tattoo_parlor',
  };

  /// Non-tattoo commercial categories that must never be displayed in Flash.Ink
  /// unless the place also explicitly carries a [tattooPlaceTypes] classification.
  static const Set<String> excludedNonTattooTypes = {
    'restaurant',
    'cafe',
    'coffee_shop',
    'bar',
    'bakery',
    'meal_takeaway',
    'meal_delivery',
    'food',
    'grocery_or_supermarket',
    'supermarket',
    'convenience_store',
    'liquor_store',
    'lodging',
    'hotel',
    'motel',
    'hospital',
    'doctor',
    'dentist',
    'medical_lab',
    'skin_care_clinic',
    'pharmacy',
    'drugstore',
    'physiotherapist',
    'veterinary_care',
    'bank',
    'atm',
    'accounting',
    'insurance_agency',
    'real_estate_agency',
    'lawyer',
    'car_dealer',
    'car_rental',
    'car_repair',
    'car_wash',
    'gas_station',
    'parking',
    'transit_station',
    'subway_station',
    'train_station',
    'bus_station',
    'airport',
    'school',
    'primary_school',
    'secondary_school',
    'university',
    'church',
    'mosque',
    'synagogue',
    'hindu_temple',
    'gym',
    'fitness_center',
    'post_office',
    'hardware_store',
    'home_goods_store',
    'furniture_store',
    'electronics_store',
    'clothing_store',
    'shoe_store',
    'jewelry_store',
    'pet_store',
    'book_store',
    'florist',
    'laundry',
    'locksmith',
    'moving_company',
    'painter',
    'plumber',
    'roofing_contractor',
    'electrician',
    'movie_theater',
    'night_club',
    'stadium',
    'amusement_park',
    'park',
    'zoo',
    'nail_salon',
    'barber_shop',
  };

  /// Personal-care types occasionally assigned to older tattoo shops on Google Maps;
  /// permitted only when the shop name contains an explicit tattoo term.
  static const Set<String> _ambiguousPersonalCareTypes = {
    'beauty_salon',
    'hair_care',
    'hair_salon',
    'spa',
  };

  static final RegExp _unambiguousTattooRegex = RegExp(
    r'\b(tattoo\w*|tatuaje\w*|tatouage\w*|irezumi|tebori)\b',
    caseSensitive: false,
  );

  static final RegExp broadTattooStudioRegex = RegExp(
    r'\b(tattoo\w*|tatuaje\w*|tatouage\w*|irezumi|tebori|body\s*art|ink|inked)\b',
    caseSensitive: false,
  );

  static final RegExp nonTattooNoiseRegex = RegExp(
    r'\b(tattoo\s+removal|laser\s+removal|removery|laseraway|toner|cartridge\w*|printer\w*|printing|office\s+depot|staples|coffee|espresso|cafe|bistro|kitchen|grill|pizzeria)\b',
    caseSensitive: false,
  );

  /// Verifies whether a candidate Google Place represents an actual tattoo studio
  /// rather than an unrelated establishment.
  static bool isTattooPlace({
    required String name,
    String? primaryType,
    Iterable<String> types = const [],
    String? businessStatus,
  }) {
    if (businessStatus != null &&
        businessStatus.toUpperCase() == 'CLOSED_PERMANENTLY') {
      return false;
    }

    final trimmedName = name.trim();
    if (trimmedName.isEmpty) return false;

    if (nonTattooNoiseRegex.hasMatch(trimmedName)) {
      return false;
    }

    final normalizedTypes = <String>{
      if (primaryType != null && primaryType.trim().isNotEmpty)
        primaryType.trim().toLowerCase(),
      ...types.map((t) => t.trim().toLowerCase()).where((t) => t.isNotEmpty),
    };

    if (normalizedTypes.intersection(tattooPlaceTypes).isNotEmpty) {
      return true;
    }

    if (normalizedTypes.intersection(excludedNonTattooTypes).isNotEmpty) {
      return false;
    }

    if (normalizedTypes.intersection(_ambiguousPersonalCareTypes).isNotEmpty) {
      return _unambiguousTattooRegex.hasMatch(trimmedName);
    }

    return broadTattooStudioRegex.hasMatch(trimmedName);
  }

  static bool isTattooStudioSummary(GooglePlaceStudioSummary summary) {
    return isTattooPlace(
      name: summary.name,
      primaryType: summary.primaryType,
      types: summary.types,
      businessStatus: summary.businessStatus,
    );
  }

  static bool isTattooPrediction(GooglePlacePrediction prediction) {
    return isTattooPlace(
      name: prediction.primaryText.isNotEmpty
          ? prediction.primaryText
          : prediction.fullText,
      types: prediction.types,
    );
  }

  static String ensureTattooSearchQuery(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return 'tattoo studio';
    if (broadTattooStudioRegex.hasMatch(trimmed)) {
      return trimmed;
    }
    return '$trimmed tattoo studio';
  }
}
