import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/utils/distance_calculator.dart';
import '../models/user.dart';

/// Live Firestore repository for Client and Artist user profiles (`/users/{uid}`).
///
/// Enforces Zero-Trust RBAC write constraints:
/// - Always stamps `'uid': uid` so `firestore.rules` ownership checks pass.
/// - Never writes `'isArtist'`, `'claimsUpdatedAt'`, or `'role': 'artist'` from client SDK.
/// - Automatically resolves geographic coordinates when `zipCode` or `cityState`
///   is persisted without explicit GPS `latitude`/`longitude`.
class UserRepository {
  final FirebaseFirestore? _injectedFirestore;

  const UserRepository({FirebaseFirestore? firestore})
      : _injectedFirestore = firestore;

  FirebaseFirestore? _resolveFirestore() {
    if (_injectedFirestore != null) return _injectedFirestore;
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  /// Watches `/users/{uid}` in real time.
  Stream<UserProfile?> watchUserProfile(String uid) {
    if (uid.trim().isEmpty) return Stream.value(null);
    final db = _resolveFirestore();
    if (db == null) return Stream.value(null);

    try {
      return db.collection('users').doc(uid).snapshots().map((snapshot) {
        final data = snapshot.data();
        if (!snapshot.exists || data == null) return null;
        return UserProfile.fromJson(data, docId: snapshot.id);
      });
    } catch (_) {
      return Stream.value(null);
    }
  }

  /// Fetches `/users/{uid}` once.
  Future<UserProfile?> getUserProfile(String uid) async {
    if (uid.trim().isEmpty) return null;
    final db = _resolveFirestore();
    if (db == null) return null;

    final snapshot = await db.collection('users').doc(uid).get();
    final data = snapshot.data();
    if (!snapshot.exists || data == null) return null;
    return UserProfile.fromJson(data, docId: snapshot.id);
  }

  /// Atomically persists or updates Client onboarding fields on `/users/{uid}`,
  /// resolving coordinates from [zipCode] / [cityState] when GPS coordinates
  /// are not explicitly provided.
  Future<UserProfile> saveClientOnboarding({
    required String uid,
    String? email,
    String? displayName,
    String? username,
    String? photoUrl,
    List<String>? aesthetics,
    List<String>? placements,
    String? zipCode,
    String? cityState,
    int? travelRadiusMiles,
    double? latitude,
    double? longitude,
    bool? notificationsEnabled,
    bool profileCompleted = true,
  }) async {
    double? resolvedLat = latitude;
    double? resolvedLng = longitude;
    String? resolvedCityState = cityState;

    if ((resolvedLat == null || resolvedLng == null) &&
        ((zipCode != null && zipCode.trim().isNotEmpty) ||
            (cityState != null && cityState.trim().isNotEmpty))) {
      final resolved = await DistanceCalculator.resolveCoordinates(
        postalCode: zipCode,
        freeformLocation: cityState,
      );
      if (resolved != null && resolved.isValid) {
        resolvedLat = resolved.latitude;
        resolvedLng = resolved.longitude;
        if ((resolvedCityState == null || resolvedCityState.trim().isEmpty) &&
            resolved.resolvedLabel != null) {
          resolvedCityState = resolved.resolvedLabel;
        }
      }
    }

    final db = _resolveFirestore();
    if (db == null) {
      return UserProfile(
        uid: uid,
        email: email ?? '',
        displayName: displayName,
        username: username,
        photoUrl: photoUrl,
        createdAt: DateTime.now(),
        role: 'client',
        profileCompleted: profileCompleted,
        aesthetics: aesthetics ?? const [],
        placements: placements ?? const [],
        zipCode: zipCode,
        cityState: resolvedCityState,
        travelRadiusMiles: travelRadiusMiles ?? 50,
        latitude: resolvedLat,
        longitude: resolvedLng,
        notificationsEnabled: notificationsEnabled ?? true,
      );
    }

    final docRef = db.collection('users').doc(uid);
    final existing = await docRef.get();

    final payload = <String, dynamic>{
      'uid': uid,
      if (!existing.exists) 'role': 'client',
      if (!existing.exists) 'createdAt': FieldValue.serverTimestamp(),
      'email': ?email,
      'displayName': ?displayName,
      'username': ?username,
      'photoUrl': ?photoUrl,
      'photoURL': ?photoUrl,
      'aesthetics': ?aesthetics,
      'placements': ?placements,
      'zipCode': ?zipCode,
      'cityState': ?resolvedCityState,
      'travelRadiusMiles': ?travelRadiusMiles,
      'latitude': ?resolvedLat,
      'longitude': ?resolvedLng,
      'notificationsEnabled': ?notificationsEnabled,
      'profileCompleted': profileCompleted,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await docRef.set(payload, SetOptions(merge: true));
    final fresh = await docRef.get();
    return UserProfile.fromJson(fresh.data() ?? payload, docId: uid);
  }

  /// Safely merges permitted profile fields onto `/users/{uid}`.
  Future<void> upsertUserFields(
    String uid,
    Map<String, dynamic> fields, {
    bool setClientRoleOnCreate = false,
  }) async {
    if (uid.trim().isEmpty) return;
    final db = _resolveFirestore();
    if (db == null) return;

    final sanitized = Map<String, dynamic>.from(fields)
      ..remove('isArtist')
      ..remove('claimsUpdatedAt');

    // Never allow client SDK to write 'role': 'artist' (forbidden by firestore.rules).
    if (sanitized['role'] != null && sanitized['role'] != 'client') {
      sanitized['onboardingRole'] = sanitized['role'];
      sanitized.remove('role');
    }

    final docRef = db.collection('users').doc(uid);
    final existing = await docRef.get();
    if (existing.exists) {
      // 'role' is immutable on update in firestore.rules.
      sanitized.remove('role');
    } else if (setClientRoleOnCreate && !sanitized.containsKey('role')) {
      sanitized['role'] = 'client';
    }

    sanitized['uid'] = uid;
    sanitized['updatedAt'] = FieldValue.serverTimestamp();
    if (!existing.exists && !sanitized.containsKey('createdAt')) {
      sanitized['createdAt'] = FieldValue.serverTimestamp();
    }

    await docRef.set(sanitized, SetOptions(merge: true));
  }
}
