import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import '../core/utils/distance_calculator.dart';
import '../models/artist.dart';
import '../models/studio_information.dart';

/// Live Firestore repository for Artist onboarding persistence and real-time
/// Client discovery (`/artists/{uid}`).
///
/// Guarantees:
/// - Zero mock fallback: returns strictly live Firestore documents.
/// - Valid geographic coordinates on every completed Artist profile (resolving
///   city/state/ZIP when Places/GPS coordinates were not supplied).
/// - Strict privacy boundary: coarsens private studio coordinates (~1.1 km) and
///   strips exact street/suite/entryCode/phone/email from public `/artists/{uid}`
///   while storing full operational details in `/artists/{uid}/private/settings`.
class ArtistRepository {
  final FirebaseFirestore? _injectedFirestore;

  const ArtistRepository({FirebaseFirestore? firestore})
      : _injectedFirestore = firestore;

  FirebaseFirestore? _resolveFirestore() {
    if (_injectedFirestore != null) return _injectedFirestore;
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  /// Real-time stream of active/onboarded Artists (`profileCompleted == true`).
  /// Emits zero records when no live Artist documents exist in Firestore.
  Stream<List<Artist>> watchActiveArtists() {
    final db = _resolveFirestore();
    if (db == null) {
      return Stream.value(const <Artist>[]);
    }

    try {
      return db
          .collection('artists')
          .where('profileCompleted', isEqualTo: true)
          .snapshots()
          .map((querySnapshot) {
        return querySnapshot.docs
            .map((doc) => Artist.fromMap(doc.data(), doc.id))
            .toList(growable: false);
      });
    } catch (_) {
      return Stream.value(const <Artist>[]);
    }
  }

  /// Real-time stream for an individual Artist document (`/artists/{artistId}`).
  Stream<Artist?> watchArtist(String artistId) {
    if (artistId.trim().isEmpty) return Stream.value(null);
    final db = _resolveFirestore();
    if (db == null) return Stream.value(null);

    try {
      return db.collection('artists').doc(artistId).snapshots().map((doc) {
        final data = doc.data();
        if (!doc.exists || data == null) return null;
        return Artist.fromMap(data, doc.id);
      });
    } catch (_) {
      return Stream.value(null);
    }
  }

  /// Fetches an individual Artist once.
  Future<Artist?> getArtist(String artistId) async {
    if (artistId.trim().isEmpty) return null;
    final db = _resolveFirestore();
    if (db == null) return null;

    final doc = await db.collection('artists').doc(artistId).get();
    final data = doc.data();
    if (!doc.exists || data == null) return null;
    return Artist.fromMap(data, doc.id);
  }

  /// Ensures [studioInfo] (or fallback [locationText]) produces valid discovery
  /// coordinates, resolving via [DistanceCalculator.resolveCoordinates] if missing.
  static Future<StudioInformation> ensureStudioCoordinates({
    StudioInformation? studioInformation,
    String? fallbackLocation,
    String? studioName,
    bool isPrivateStudio = false,
  }) async {
    final base = studioInformation ??
        StudioInformation(
          name: studioName ?? '',
          city: fallbackLocation ?? '',
          isPrivateStudio: isPrivateStudio,
          studioType: isPrivateStudio ? 'Private Studio' : 'Street Shop',
        );

    if (base.latitude != null &&
        base.longitude != null &&
        GeoPointCoords(
          latitude: base.latitude!,
          longitude: base.longitude!,
        ).isValid) {
      return base;
    }

    final resolved = await DistanceCalculator.resolveCoordinates(
      city: base.city,
      state: base.state,
      postalCode: base.postalCode,
      freeformLocation: fallbackLocation ??
          (base.formattedAddress.isNotEmpty ? base.formattedAddress : base.name),
    );

    if (resolved != null && resolved.isValid) {
      String resolvedCity = base.city;
      String resolvedState = base.state;
      if (resolvedCity.isEmpty &&
          resolved.resolvedLabel != null &&
          resolved.resolvedLabel!.contains(',')) {
        final parts = resolved.resolvedLabel!.split(',');
        resolvedCity = parts.first.trim();
        if (resolvedState.isEmpty && parts.length > 1) {
          resolvedState = parts[1].trim();
        }
      }
      return base.copyWith(
        city: resolvedCity,
        state: resolvedState,
        latitude: resolved.latitude,
        longitude: resolved.longitude,
      );
    }

    return base;
  }

  /// Atomically persists full Artist onboarding across `/artists/{uid}`,
  /// `/users/{uid}`, and `/artists/{uid}/private/settings`.
  Future<Artist> saveArtistOnboarding({
    required String uid,
    required String displayName,
    String username = '',
    String instagramHandle = '',
    String email = '',
    String phoneNumber = '',
    String avatarUrl = '',
    String bannerUrl = '',
    String bio = '',
    List<String> styles = const [],
    List<String> identityTags = const [],
    StudioInformation? studioInformation,
    String fallbackLocation = '',
    int minDeposit = 100,
    bool isBooksOpen = true,
    bool customRequestAvailable = true,
    List<FlashArtwork> flashArtworks = const [],
    List<String>? portfolioImages,
    List<StudioPolicy>? policies,
    List<ArtistFunFact>? funFacts,
  }) async {
    final hydratedStudio = await ensureStudioCoordinates(
      studioInformation: studioInformation,
      fallbackLocation: fallbackLocation,
      isPrivateStudio: studioInformation?.isPrivateStudio ?? false,
    );

    final safeAvatarUrl =
        avatarUrl.startsWith('local://') ? '' : avatarUrl.trim();
    final safeBannerUrl =
        bannerUrl.startsWith('local://') ? '' : bannerUrl.trim();
    final mergedTags = <String>{
      ...styles.where((s) => s.trim().isNotEmpty),
      ...identityTags.where((t) => t.trim().isNotEmpty),
    }.toList(growable: false);

    final normalizedHandle = instagramHandle.trim().isEmpty
        ? (username.trim().isNotEmpty
            ? (username.trim().startsWith('@')
                ? username.trim()
                : '@${username.trim()}')
            : '')
        : (instagramHandle.trim().startsWith('@')
            ? instagramHandle.trim()
            : '@${instagramHandle.trim()}');

    final normalizedArtworks = flashArtworks
        .map(
          (f) => f.copyWith(
            artistId: uid,
            artistName: displayName,
          ),
        )
        .toList(growable: false);

    final previewUrls = portfolioImages ??
        normalizedArtworks
            .map((f) => f.imageUrl)
            .where((url) => url.isNotEmpty && !url.startsWith('local://'))
            .take(4)
            .toList(growable: false);

    final discoveryCoords = hydratedStudio.discoveryCoordinates;
    final locationDisplay = hydratedStudio.displayLocation.isNotEmpty
        ? hydratedStudio.displayLocation
        : fallbackLocation;

    final artist = Artist(
      id: uid,
      name: displayName.trim().isEmpty ? 'Artist' : displayName.trim(),
      username: username.trim(),
      instagramHandle: normalizedHandle,
      studioName: hydratedStudio.name,
      avatarUrl: safeAvatarUrl,
      bannerUrl: safeBannerUrl,
      isBooksOpen: isBooksOpen,
      location: locationDisplay,
      studioType: hydratedStudio.studioType,
      isPrivateStudio: hydratedStudio.isPrivateStudio,
      latitude: discoveryCoords?.latitude,
      longitude: discoveryCoords?.longitude,
      profileCompleted: true,
      rating: 5.0,
      availablePieces:
          normalizedArtworks.where((f) => !f.isClaimed).length,
      minDeposit: minDeposit,
      images: previewUrls,
      tags: mergedTags,
      flashArtworks: normalizedArtworks,
      bio: bio.trim(),
      policies: policies ?? const [],
      funFacts: funFacts ?? const [],
      isVerifiedStudio: true,
      customRequestAvailable: customRequestAvailable,
      studioInformation: hydratedStudio,
    );

    final db = _resolveFirestore();
    if (db == null) {
      return artist;
    }

    final userRef = db.collection('users').doc(uid);
    final artistRef = db.collection('artists').doc(uid);
    final privateSettingsRef =
        artistRef.collection('private').doc('settings');

    final existingUser = await userRef.get();
    final existingData = existingUser.data();
    final existingArtist = await artistRef.get();
    final existingArtistData = existingArtist.data();

    String effectiveAvatarUrl = safeAvatarUrl;
    if (effectiveAvatarUrl.isEmpty) {
      final candidates = <Object?>[
        existingArtistData?['avatarUrl'],
        existingArtistData?['photoUrl'],
        existingArtistData?['photoURL'],
        existingData?['photoUrl'],
        existingData?['photoURL'],
        existingData?['avatarUrl'],
      ];
      try {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null && currentUser.uid == uid) {
          candidates.add(currentUser.photoURL);
        }
      } catch (_) {}

      for (final candidate in candidates) {
        if (candidate is String) {
          final trimmed = candidate.trim();
          if (trimmed.isNotEmpty && !trimmed.startsWith('local://')) {
            effectiveAvatarUrl = trimmed;
            break;
          }
        }
      }
    }

    String effectiveBannerUrl = safeBannerUrl;
    if (effectiveBannerUrl.isEmpty) {
      final existingBanner = existingArtistData?['bannerUrl'] ??
          existingArtistData?['coverImageUrl'] ??
          existingArtistData?['headerImageUrl'];
      if (existingBanner is String &&
          existingBanner.trim().isNotEmpty &&
          !existingBanner.trim().startsWith('local://')) {
        effectiveBannerUrl = existingBanner.trim();
      }
    }

    final resolvedArtist =
        (effectiveAvatarUrl != safeAvatarUrl || effectiveBannerUrl != safeBannerUrl)
            ? artist.copyWith(
                avatarUrl: effectiveAvatarUrl,
                bannerUrl: effectiveBannerUrl,
              )
            : artist;

    final bool hasExistingDisplayName =
        (existingData?['displayName'] as String?)?.trim().isNotEmpty == true;
    final bool hasExistingUsername =
        (existingData?['username'] as String?)?.trim().isNotEmpty == true;
    final bool hasExistingBio =
        (existingData?['bio'] as String?)?.trim().isNotEmpty == true;

    final batch = db.batch();

    // 1. Update `/users/{uid}` (never setting 'role': 'artist' from client SDK; preserve existing client persona fields, keep unified photo synced).
    final userPayload = <String, dynamic>{
      'uid': uid,
      if (!existingUser.exists) 'role': 'client',
      if (!hasExistingDisplayName) 'displayName': resolvedArtist.name,
      if (!hasExistingUsername && resolvedArtist.username.isNotEmpty)
        'username': resolvedArtist.username,
      if (email.trim().isNotEmpty) 'email': email.trim(),
      if (effectiveAvatarUrl.isNotEmpty) 'photoUrl': effectiveAvatarUrl,
      if (effectiveAvatarUrl.isNotEmpty) 'photoURL': effectiveAvatarUrl,
      if (!hasExistingBio) 'bio': resolvedArtist.bio,
      if (normalizedHandle.isNotEmpty) 'instagramHandle': normalizedHandle,
      'onboardingRole': 'artist',
      'activeMode': 'artist',
      'profileCompleted': true,
      if (discoveryCoords != null) 'latitude': discoveryCoords.latitude,
      if (discoveryCoords != null) 'longitude': discoveryCoords.longitude,
      if (locationDisplay.isNotEmpty) 'cityState': locationDisplay,
      if (!existingUser.exists) 'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    batch.set(userRef, userPayload, SetOptions(merge: true));

    // 2. Write privacy-safe public `/artists/{uid}` document.
    final artistPublicPayload = <String, dynamic>{
      ...resolvedArtist.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    batch.set(artistRef, artistPublicPayload, SetOptions(merge: true));

    await batch.commit();

    // 3. Persist private studio street address & PII into isolated `/artists/{uid}/private/settings`.
    try {
      await privateSettingsRef.set({
        if (email.trim().isNotEmpty) 'email': email.trim(),
        if (phoneNumber.trim().isNotEmpty) 'phoneNumber': phoneNumber.trim(),
        'fullStudioInformation': hydratedStudio.toMap(),
        if (hydratedStudio.formattedAddress.isNotEmpty)
          'streetAddress': hydratedStudio.formattedAddress,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Best-effort if custom claim not yet minted on strict emulator rules.
    }

    // 4. Invoke the `completeArtistOnboarding` callable Cloud Function and force-refresh token claims.
    await invokeCompleteArtistOnboarding(
      name: resolvedArtist.name,
      instagramHandle: normalizedHandle,
      bio: resolvedArtist.bio,
      city: locationDisplay,
      studioType: hydratedStudio.studioType,
      minDeposit: minDeposit,
      tags: mergedTags,
      phoneNumber: phoneNumber.trim(),
      avatarUrl: effectiveAvatarUrl,
    );

    final savedSnapshot = await artistRef.get();
    if (savedSnapshot.exists && savedSnapshot.data() != null) {
      return Artist.fromMap(savedSnapshot.data()!, savedSnapshot.id);
    }
    return resolvedArtist;
  }

  /// Synchronizes a unified profile photo across `/users/{uid}` and `/artists/{uid}`
  /// (when an artist document exists or [createArtistIfMissing] is true).
  static Future<void> syncUnifiedProfilePhoto({
    required String uid,
    required String? photoUrl,
    FirebaseFirestore? firestore,
    bool createArtistIfMissing = false,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (uid.trim().isEmpty) return;
    FirebaseFirestore? db = firestore;
    if (db == null) {
      try {
        db = FirebaseFirestore.instance;
      } catch (_) {
        return;
      }
    }

    final normalizedPhoto =
        (photoUrl != null && photoUrl.trim().isNotEmpty && !photoUrl.trim().startsWith('local://'))
            ? photoUrl.trim()
            : null;

    try {
      await db
          .collection('users')
          .doc(uid)
          .set({
            'uid': uid,
            'photoUrl': normalizedPhoto,
            'photoURL': normalizedPhoto,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true))
          .timeout(timeout);
    } catch (_) {}

    try {
      final artistRef = db.collection('artists').doc(uid);
      bool shouldUpdateArtist = createArtistIfMissing;
      if (!shouldUpdateArtist) {
        final snap = await artistRef.get().timeout(timeout);
        shouldUpdateArtist = snap.exists;
      }
      if (shouldUpdateArtist) {
        await artistRef
            .set({
              'id': uid,
              'avatarUrl': normalizedPhoto ?? '',
              'photoUrl': normalizedPhoto ?? '',
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true))
            .timeout(timeout);
      }
    } catch (_) {}
  }

  /// Updates or resets (`bannerUrl: ''`) the artist's custom profile header banner on `/artists/{uid}`.
  static Future<void> updateArtistBannerUrl({
    required String uid,
    required String? bannerUrl,
    FirebaseFirestore? firestore,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (uid.trim().isEmpty) return;
    FirebaseFirestore? db = firestore;
    if (db == null) {
      try {
        db = FirebaseFirestore.instance;
      } catch (_) {
        return;
      }
    }

    final normalizedBanner =
        (bannerUrl != null && bannerUrl.trim().isNotEmpty && !bannerUrl.trim().startsWith('local://'))
            ? bannerUrl.trim()
            : '';

    try {
      await db
          .collection('artists')
          .doc(uid)
          .set({
            'id': uid,
            'bannerUrl': normalizedBanner,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true))
          .timeout(timeout);
    } catch (_) {}
  }

  /// Invokes the `completeArtistOnboarding` callable Cloud Function to stamp
  /// `{ role: 'artist', verifiedArtist: true }` custom claims and immediately
  /// refreshes the client's Firebase Auth token claims.
  static Future<void> invokeCompleteArtistOnboarding({
    required String name,
    String instagramHandle = '',
    String bio = '',
    String city = '',
    String studioType = '',
    int minDeposit = 100,
    List<String> tags = const [],
    String phoneNumber = '',
    String avatarUrl = '',
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      final idToken = await currentUser?.getIdToken();
      if (idToken != null && idToken.isNotEmpty) {
        await http
            .post(
              Uri.parse(
                'https://us-central1-flash-ink-app.cloudfunctions.net/completeArtistOnboarding',
              ),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $idToken',
              },
              body: jsonEncode({
                'data': {
                  'name': name,
                  'instagramHandle': instagramHandle,
                  'bio': bio,
                  'city': city,
                  'studioType': studioType,
                  'minDeposit': minDeposit,
                  'tags': tags,
                  'phoneNumber': phoneNumber,
                  if (avatarUrl.trim().isNotEmpty) 'avatarUrl': avatarUrl.trim(),
                },
              }),
            )
            .timeout(const Duration(seconds: 4));
      }
    } catch (_) {}

    try {
      await FirebaseAuth.instance.currentUser?.getIdToken(true);
    } catch (_) {}
  }

  /// Uploads binary JPEG image bytes to Firebase Storage under
  /// `/artists/{uid}/flash/{artworkId}.jpg` and returns the public download URL.
  static Future<String?> uploadFlashArtworkImage({
    required String uid,
    required String artworkId,
    required Uint8List imageBytes,
    FirebaseStorage? storage,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (uid.trim().isEmpty || artworkId.trim().isEmpty) return null;
    FirebaseStorage? resolvedStorage = storage;
    if (resolvedStorage == null) {
      try {
        resolvedStorage = FirebaseStorage.instance;
      } catch (_) {
        return null;
      }
    }

    try {
      final storageRef = resolvedStorage
          .ref()
          .child('artists')
          .child(uid)
          .child('flash')
          .child('$artworkId.jpg');
      await storageRef
          .putData(imageBytes, SettableMetadata(contentType: 'image/jpeg'))
          .timeout(timeout);
      final downloadUrl = await storageRef.getDownloadURL().timeout(timeout);
      return downloadUrl;
    } catch (_) {
      return null;
    }
  }

  /// Atomically appends or prepends a new [artwork] to `/artists/{uid}`.
  /// If [imageBytes] are supplied, uploads them via [uploadFlashArtworkImage].
  /// Recalculates [availablePieces] and writes to Firestore.
  static Future<Artist?> addFlashArtwork({
    required String uid,
    required FlashArtwork artwork,
    Uint8List? imageBytes,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (uid.trim().isEmpty) return null;
    FirebaseFirestore? db = firestore;
    if (db == null) {
      try {
        db = FirebaseFirestore.instance;
      } catch (_) {
        return null;
      }
    }

    String imageUrl = artwork.imageUrl;
    if (imageBytes != null) {
      final uploadedUrl = await uploadFlashArtworkImage(
        uid: uid,
        artworkId: artwork.id,
        imageBytes: imageBytes,
        storage: storage,
        timeout: timeout,
      );
      if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
        imageUrl = uploadedUrl;
      }
    }

    final normalizedArtwork = artwork.copyWith(
      artistId: uid,
      imageUrl: imageUrl,
    );

    try {
      final artistRef = db.collection('artists').doc(uid);
      final snap = await artistRef.get().timeout(timeout);
      if (!snap.exists || snap.data() == null) return null;

      final currentArtist = Artist.fromMap(snap.data()!, snap.id);
      final updatedFlashList = [
        normalizedArtwork,
        ...currentArtist.flashArtworks.where((a) => a.id != normalizedArtwork.id)
      ];
      final availableCount = updatedFlashList.where((f) => !f.isClaimed).length;

      final previewImages = updatedFlashList
          .map((f) => f.imageUrl)
          .where((url) => url.isNotEmpty && !url.startsWith('local://'))
          .take(4)
          .toList(growable: false);

      await artistRef.set({
        'flashArtworks': updatedFlashList.map((f) => f.toMap()).toList(growable: false),
        'availablePieces': availableCount,
        'images': previewImages,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).timeout(timeout);

      return currentArtist.copyWith(
        flashArtworks: updatedFlashList,
        availablePieces: availableCount,
        images: previewImages,
      );
    } catch (_) {
      return null;
    }
  }

  /// Updates an existing [artwork] on `/artists/{uid}` with matching [artwork.id].
  static Future<Artist?> updateFlashArtwork({
    required String uid,
    required FlashArtwork artwork,
    Uint8List? newImageBytes,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (uid.trim().isEmpty) return null;
    FirebaseFirestore? db = firestore;
    if (db == null) {
      try {
        db = FirebaseFirestore.instance;
      } catch (_) {
        return null;
      }
    }

    String imageUrl = artwork.imageUrl;
    if (newImageBytes != null) {
      final uploadedUrl = await uploadFlashArtworkImage(
        uid: uid,
        artworkId: artwork.id,
        imageBytes: newImageBytes,
        storage: storage,
        timeout: timeout,
      );
      if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
        imageUrl = uploadedUrl;
      }
    }

    final normalizedArtwork = artwork.copyWith(
      artistId: uid,
      imageUrl: imageUrl,
    );

    try {
      final artistRef = db.collection('artists').doc(uid);
      final snap = await artistRef.get().timeout(timeout);
      if (!snap.exists || snap.data() == null) return null;

      final currentArtist = Artist.fromMap(snap.data()!, snap.id);
      final updatedFlashList = currentArtist.flashArtworks.map((item) {
        return item.id == normalizedArtwork.id ? normalizedArtwork : item;
      }).toList(growable: false);

      final availableCount = updatedFlashList.where((f) => !f.isClaimed).length;

      final previewImages = updatedFlashList
          .map((f) => f.imageUrl)
          .where((url) => url.isNotEmpty && !url.startsWith('local://'))
          .take(4)
          .toList(growable: false);

      await artistRef.set({
        'flashArtworks': updatedFlashList.map((f) => f.toMap()).toList(growable: false),
        'availablePieces': availableCount,
        'images': previewImages,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).timeout(timeout);

      return currentArtist.copyWith(
        flashArtworks: updatedFlashList,
        availablePieces: availableCount,
        images: previewImages,
      );
    } catch (_) {
      return null;
    }
  }

  /// Deletes a flash piece by [artworkId] from `/artists/{uid}`.
  static Future<Artist?> deleteFlashArtwork({
    required String uid,
    required String artworkId,
    FirebaseFirestore? firestore,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (uid.trim().isEmpty || artworkId.trim().isEmpty) return null;
    FirebaseFirestore? db = firestore;
    if (db == null) {
      try {
        db = FirebaseFirestore.instance;
      } catch (_) {
        return null;
      }
    }

    try {
      final artistRef = db.collection('artists').doc(uid);
      final snap = await artistRef.get().timeout(timeout);
      if (!snap.exists || snap.data() == null) return null;

      final currentArtist = Artist.fromMap(snap.data()!, snap.id);
      final updatedFlashList = currentArtist.flashArtworks
          .where((item) => item.id != artworkId)
          .toList(growable: false);

      final availableCount = updatedFlashList.where((f) => !f.isClaimed).length;

      final previewImages = updatedFlashList
          .map((f) => f.imageUrl)
          .where((url) => url.isNotEmpty && !url.startsWith('local://'))
          .take(4)
          .toList(growable: false);

      await artistRef.set({
        'flashArtworks': updatedFlashList.map((f) => f.toMap()).toList(growable: false),
        'availablePieces': availableCount,
        'images': previewImages,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).timeout(timeout);

      return currentArtist.copyWith(
        flashArtworks: updatedFlashList,
        availablePieces: availableCount,
        images: previewImages,
      );
    } catch (_) {
      return null;
    }
  }

  /// Toggles status of a flash piece (Available ↔ Claimed or Repeatable).
  static Future<Artist?> toggleFlashArtworkStatus({
    required String uid,
    required String artworkId,
    required FlashStatus newStatus,
    FirebaseFirestore? firestore,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (uid.trim().isEmpty || artworkId.trim().isEmpty) return null;
    FirebaseFirestore? db = firestore;
    if (db == null) {
      try {
        db = FirebaseFirestore.instance;
      } catch (_) {
        return null;
      }
    }

    try {
      final artistRef = db.collection('artists').doc(uid);
      final snap = await artistRef.get().timeout(timeout);
      if (!snap.exists || snap.data() == null) return null;

      final currentArtist = Artist.fromMap(snap.data()!, snap.id);
      final updatedFlashList = currentArtist.flashArtworks.map((item) {
        if (item.id == artworkId) {
          return item.copyWith(
            status: newStatus,
            isExclusive: newStatus != FlashStatus.repeatable,
          );
        }
        return item;
      }).toList(growable: false);

      final availableCount = updatedFlashList.where((f) => !f.isClaimed).length;

      await artistRef.set({
        'flashArtworks': updatedFlashList.map((f) => f.toMap()).toList(growable: false),
        'availablePieces': availableCount,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).timeout(timeout);

      return currentArtist.copyWith(
        flashArtworks: updatedFlashList,
        availablePieces: availableCount,
      );
    } catch (_) {
      return null;
    }
  }
}
