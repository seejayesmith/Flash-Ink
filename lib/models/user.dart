import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/utils/distance_calculator.dart';

class UserProfile {
  final String uid;
  final String email;
  final String? displayName;
  final String? username;
  final String? photoUrl;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? role;
  final String? onboardingRole;
  final bool profileCompleted;
  final List<String> aesthetics;
  final List<String> placements;
  final String? zipCode;
  final String? cityState;
  final int travelRadiusMiles;
  final double? latitude;
  final double? longitude;
  final bool notificationsEnabled;
  final String? bio;
  final String? instagramHandle;
  final bool phoneVerified;
  final bool isAnonymous;

  const UserProfile({
    required this.uid,
    required this.email,
    this.displayName,
    this.username,
    this.photoUrl,
    required this.createdAt,
    this.updatedAt,
    this.role,
    this.onboardingRole,
    this.profileCompleted = false,
    this.aesthetics = const [],
    this.placements = const [],
    this.zipCode,
    this.cityState,
    this.travelRadiusMiles = 50,
    this.latitude,
    this.longitude,
    this.notificationsEnabled = true,
    this.bio,
    this.instagramHandle,
    this.phoneVerified = false,
    this.isAnonymous = false,
  });

  /// Saved geographic coordinates for this user, if valid.
  GeoPointCoords? get savedCoordinates {
    if (latitude == null || longitude == null) return null;
    final coords = GeoPointCoords(
      latitude: latitude!,
      longitude: longitude!,
      resolvedLabel: cityState ?? zipCode,
    );
    return coords.isValid ? coords : null;
  }

  static DateTime _parseDateTime(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw) ?? DateTime.now();
    return DateTime.now();
  }

  static DateTime? _parseOptionalDateTime(dynamic raw) {
    if (raw == null) return null;
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  static List<String> _parseStringList(dynamic raw) {
    if (raw is List) {
      return raw.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
    }
    return const [];
  }

  factory UserProfile.fromJson(Map<String, dynamic> json, {String? docId}) {
    final photo = json['photoUrl'] ?? json['photoURL'] ?? json['avatarUrl'];
    return UserProfile(
      uid: json['uid']?.toString() ?? docId ?? '',
      email: json['email']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? json['name']?.toString(),
      username: json['username']?.toString(),
      photoUrl: photo is String && photo.isNotEmpty ? photo : null,
      createdAt: _parseDateTime(json['createdAt']),
      updatedAt: _parseOptionalDateTime(json['updatedAt']),
      role: json['role']?.toString(),
      onboardingRole: json['onboardingRole']?.toString(),
      profileCompleted: json['profileCompleted'] == true,
      aesthetics: _parseStringList(json['aesthetics']),
      placements: _parseStringList(json['placements']),
      zipCode: json['zipCode']?.toString(),
      cityState: json['cityState']?.toString(),
      travelRadiusMiles: (json['travelRadiusMiles'] is num)
          ? (json['travelRadiusMiles'] as num).toInt()
          : 50,
      latitude: (json['latitude'] is num) ? (json['latitude'] as num).toDouble() : null,
      longitude: (json['longitude'] is num) ? (json['longitude'] as num).toDouble() : null,
      notificationsEnabled: json['notificationsEnabled'] != false,
      bio: json['bio']?.toString(),
      instagramHandle: json['instagramHandle']?.toString(),
      phoneVerified: json['phoneVerified'] == true,
      isAnonymous: json['isAnonymous'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      if (displayName != null) 'displayName': displayName,
      if (username != null) 'username': username,
      if (photoUrl != null) 'photoUrl': photoUrl,
      if (photoUrl != null) 'photoURL': photoUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      if (role != null) 'role': role,
      if (onboardingRole != null) 'onboardingRole': onboardingRole,
      'profileCompleted': profileCompleted,
      'aesthetics': aesthetics,
      'placements': placements,
      if (zipCode != null) 'zipCode': zipCode,
      if (cityState != null) 'cityState': cityState,
      'travelRadiusMiles': travelRadiusMiles,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      'notificationsEnabled': notificationsEnabled,
      if (bio != null) 'bio': bio,
      if (instagramHandle != null) 'instagramHandle': instagramHandle,
      'phoneVerified': phoneVerified,
      'isAnonymous': isAnonymous,
    };
  }

  UserProfile copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? username,
    String? photoUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? role,
    String? onboardingRole,
    bool? profileCompleted,
    List<String>? aesthetics,
    List<String>? placements,
    String? zipCode,
    String? cityState,
    int? travelRadiusMiles,
    double? latitude,
    double? longitude,
    bool? notificationsEnabled,
    String? bio,
    String? instagramHandle,
    bool? phoneVerified,
    bool? isAnonymous,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      username: username ?? this.username,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      role: role ?? this.role,
      onboardingRole: onboardingRole ?? this.onboardingRole,
      profileCompleted: profileCompleted ?? this.profileCompleted,
      aesthetics: aesthetics ?? this.aesthetics,
      placements: placements ?? this.placements,
      zipCode: zipCode ?? this.zipCode,
      cityState: cityState ?? this.cityState,
      travelRadiusMiles: travelRadiusMiles ?? this.travelRadiusMiles,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      bio: bio ?? this.bio,
      instagramHandle: instagramHandle ?? this.instagramHandle,
      phoneVerified: phoneVerified ?? this.phoneVerified,
      isAnonymous: isAnonymous ?? this.isAnonymous,
    );
  }
}
