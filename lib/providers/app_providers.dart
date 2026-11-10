import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/mock/mock_data_config.dart';
import '../core/mock/mock_fixtures.dart';
import '../core/utils/distance_calculator.dart';
import '../features/explore/domain/models/explore_studio.dart';
import '../models/artist.dart';
import '../models/user.dart';
import '../repositories/artist_repository.dart';
import '../repositories/user_repository.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';

/// Controls whether quarantined mock fixtures are injected (strictly `false` by default).
final mockModeProvider = Provider<bool>((ref) {
  return MockDataConfig.isEnabled;
});

/// Optional injected [FirebaseFirestore] instance (overridden in tests with `FakeFirebaseFirestore`).
/// Returns `null` when not overridden so repositories resolve `FirebaseFirestore.instance` lazily.
final firebaseFirestoreProvider = Provider<FirebaseFirestore?>((ref) {
  return null;
});

/// Optional injected [FirebaseFunctions] instance (overridden in tests with a fake/mock callable client).
/// Returns `null` when not overridden so services resolve `FirebaseFunctions.instance` lazily.
final firebaseFunctionsProvider = Provider<FirebaseFunctions?>((ref) {
  return null;
});

/// Active [AuthService] instance.
final authServiceProvider = Provider<AuthService>((ref) {
  final firestore = ref.watch(firebaseFirestoreProvider);
  final functions = ref.watch(firebaseFunctionsProvider);
  return AuthService(firestore: firestore, functions: functions);
});

/// Tracks sign-out / session-switch epochs so user-scoped providers reset cleanly.
final sessionEpochProvider = StreamProvider<int>((ref) async* {
  yield AuthService.sessionEpoch;
  yield* AuthService.sessionEpochChanges;
});

/// Live stream of the currently authenticated Firebase [User].
/// Watches [sessionEpochProvider] so `signOut()` / cross-role switches immediately
/// tear down the previous auth subscription and re-bind cleanly.
final authStateStreamProvider = StreamProvider<User?>((ref) {
  ref.watch(sessionEpochProvider);
  return ref.watch(authServiceProvider).authStateChanges;
});

/// Active authenticated UID. Watches both [authStateStreamProvider] and [sessionEpochProvider]
/// so signing out of an Artist account and signing into a Client account immediately
/// invalidates all user-scoped state.
final activeUidProvider = Provider<String?>((ref) {
  ref.watch(sessionEpochProvider);
  final authAsync = ref.watch(authStateStreamProvider);
  return authAsync.when(
    data: (user) => user?.uid,
    loading: () => ref.read(authServiceProvider).currentUser?.uid,
    error: (_, _) => ref.read(authServiceProvider).currentUser?.uid,
  );
});

/// Live [UserRepository] bound to [firebaseFirestoreProvider].
final userRepositoryProvider = Provider<UserRepository>((ref) {
  final firestore = ref.watch(firebaseFirestoreProvider);
  return UserRepository(firestore: firestore);
});

/// Live [ArtistRepository] bound to [firebaseFirestoreProvider].
final artistRepositoryProvider = Provider<ArtistRepository>((ref) {
  final firestore = ref.watch(firebaseFirestoreProvider);
  return ArtistRepository(firestore: firestore);
});

/// Real-time `/users/{uid}` profile stream for the active authenticated user.
/// Automatically emits `null` and unsubscribes from the previous document on sign-out or role switch.
final currentUserProfileProvider = StreamProvider<UserProfile?>((ref) {
  final uid = ref.watch(activeUidProvider);
  if (uid == null || uid.isEmpty) {
    return Stream<UserProfile?>.value(null);
  }
  return ref.watch(userRepositoryProvider).watchUserProfile(uid);
});

/// Mutable notifier holding live Client device GPS coordinates (when permitted or updated).
/// Resets automatically whenever [activeUidProvider] changes.
class LiveCoordinatesNotifier extends Notifier<GeoPointCoords?> {
  @override
  GeoPointCoords? build() {
    ref.watch(activeUidProvider);
    final isWidgetTest =
        WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (!isWidgetTest) {
      _hydratePermittedDeviceLocation();
    }
    return null;
  }

  Future<void> _hydratePermittedDeviceLocation() async {
    final permitted = await LocationService.tryGetPermittedCoordinates();
    if (permitted != null && permitted.isValid) {
      state = permitted;
    }
  }

  void setCoordinates(GeoPointCoords? coords) {
    state = (coords != null && coords.isValid) ? coords : null;
  }

  Future<void> refreshFromDevice() async {
    final permitted = await LocationService.tryGetPermittedCoordinates();
    if (permitted != null && permitted.isValid) {
      state = permitted;
    }
  }
}

final liveGpsCoordinatesProvider =
    NotifierProvider<LiveCoordinatesNotifier, GeoPointCoords?>(
  LiveCoordinatesNotifier.new,
);

class UseLiveLocationNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void setEnabled(bool enabled) {
    state = enabled;
  }
}

/// In-app user preference for querying live GPS coordinates.
final useLiveLocationPreferenceProvider =
    NotifierProvider<UseLiveLocationNotifier, bool>(
  UseLiveLocationNotifier.new,
);

/// Combines live permitted Client GPS coordinates with a graceful fallback to
/// the Client's persisted `/users/{uid}` profile coordinates (`latitude`/`longitude`).
final effectiveClientCoordinatesProvider = Provider<GeoPointCoords?>((ref) {
  final useLive = ref.watch(useLiveLocationPreferenceProvider);
  if (useLive) {
    final liveCoords = ref.watch(liveGpsCoordinatesProvider);
    if (liveCoords != null && liveCoords.isValid) {
      return liveCoords;
    }
  }
  final profile = ref.watch(currentUserProfileProvider).maybeWhen(
        data: (u) => u,
        orElse: () => null,
      );
  return profile?.savedCoordinates;
});

/// Real-time stream of active/onboarded Artists from Firestore (`.snapshots()`).
/// Emits strictly live Firestore documents unless [mockModeProvider] is explicitly enabled.
final artistDiscoveryStreamProvider = StreamProvider<List<Artist>>((ref) {
  final useMock = ref.watch(mockModeProvider);
  if (useMock) {
    return Stream<List<Artist>>.value(MockFixtures.artists);
  }
  return ref.watch(artistRepositoryProvider).watchActiveArtists();
});

/// Resolves the active authenticated user's unified profile photo URL (if any)
/// from `/users/{uid}` or Firebase Auth `photoURL`.
final activeUserPhotoUrlProvider = Provider<String?>((ref) {
  final activeUid = ref.watch(activeUidProvider);
  if (activeUid == null || activeUid.isEmpty) return null;

  final profilePhoto = ref.watch(currentUserProfileProvider).maybeWhen(
        data: (u) => u?.photoUrl,
        orElse: () => null,
      );
  if (profilePhoto != null &&
      profilePhoto.trim().isNotEmpty &&
      !profilePhoto.trim().startsWith('local://')) {
    return profilePhoto.trim();
  }

  try {
    final authPhoto = ref.read(authServiceProvider).currentUser?.photoURL;
    if (authPhoto != null &&
        authPhoto.trim().isNotEmpty &&
        !authPhoto.trim().startsWith('local://')) {
      return authPhoto.trim();
    }
  } catch (_) {}

  return null;
});

/// Reactive Artist discovery feed enriched with live Haversine distance (`e.g., 4.2 mi away`)
/// computed against [effectiveClientCoordinatesProvider]. Recomputes dynamically whenever
/// either the Artist's coordinates or the Client's coordinates change.
final artistsWithDistanceProvider = Provider<AsyncValue<List<Artist>>>((ref) {
  final useMock = ref.watch(mockModeProvider);
  final clientCoords = ref.watch(effectiveClientCoordinatesProvider);
  if (useMock) {
    return AsyncValue.data(
      MockFixtures.artists
          .map((artist) => artist.withLiveDistanceFrom(clientCoords))
          .toList(growable: false),
    );
  }
  final activeUid = ref.watch(activeUidProvider);
  final activePhotoUrl = ref.watch(activeUserPhotoUrlProvider);
  final artistsAsync = ref.watch(artistDiscoveryStreamProvider);
  return artistsAsync.whenData(
    (artists) => artists.map((artist) {
      var resolved = artist;
      if (activeUid != null &&
          artist.id == activeUid &&
          artist.avatarUrl.trim().isEmpty &&
          activePhotoUrl != null &&
          activePhotoUrl.isNotEmpty) {
        resolved = artist.copyWith(avatarUrl: activePhotoUrl);
        ArtistRepository.syncUnifiedProfilePhoto(
          uid: activeUid,
          photoUrl: activePhotoUrl,
          firestore: ref.read(firebaseFirestoreProvider),
          createArtistIfMissing: true,
        );
      }
      return resolved.withLiveDistanceFrom(clientCoords);
    }).toList(growable: false),
  );
});

/// Real-time stream for an individual Artist profile with reactive Haversine distance.
final artistDetailWithDistanceProvider =
    StreamProvider.family<Artist?, String>((ref, artistId) {
  final useMock = ref.watch(mockModeProvider);
  final clientCoords = ref.watch(effectiveClientCoordinatesProvider);

  if (useMock) {
    final match = MockFixtures.artists
        .where((a) => a.id == artistId)
        .map((a) => a.withLiveDistanceFrom(clientCoords))
        .firstOrNull;
    return Stream<Artist?>.value(match);
  }

  final activeUid = ref.watch(activeUidProvider);
  final activePhotoUrl = ref.watch(activeUserPhotoUrlProvider);

  return ref
      .watch(artistRepositoryProvider)
      .watchArtist(artistId)
      .map((artist) {
    if (artist == null) return null;
    var resolved = artist;
    if (activeUid != null &&
        artist.id == activeUid &&
        artist.avatarUrl.trim().isEmpty &&
        activePhotoUrl != null &&
        activePhotoUrl.isNotEmpty) {
      resolved = artist.copyWith(avatarUrl: activePhotoUrl);
      ArtistRepository.syncUnifiedProfilePhoto(
        uid: activeUid,
        photoUrl: activePhotoUrl,
        firestore: ref.read(firebaseFirestoreProvider),
        createArtistIfMissing: true,
      );
    }
    return resolved.withLiveDistanceFrom(clientCoords);
  });
});

/// Live Explore studios derived from onboarded Artists.
final exploreStudiosProvider = Provider<AsyncValue<List<ExploreStudio>>>((ref) {
  final artistsAsync = ref.watch(artistsWithDistanceProvider);
  return artistsAsync.whenData((artists) {
    final groupedByName = <String, List<Artist>>{};
    for (final artist in artists) {
      final key = (artist.studioName.isNotEmpty
              ? artist.studioName
              : (artist.studioInformation?.name ?? artist.name))
          .trim()
          .toLowerCase();
      groupedByName.putIfAbsent(key, () => []).add(artist);
    }
    return groupedByName.values
        .map(
          (members) => ExploreStudio.fromArtist(
            members.first,
            residentArtistsCount: members.length,
          ),
        )
        .toList(growable: false);
  });
});

/// Represents the active persona view for dual-role users.
enum AppMode {
  client('client'),
  artist('artist');

  final String value;
  const AppMode(this.value);

  static AppMode fromString(String? raw, {AppMode fallback = AppMode.client}) {
    if (raw == 'artist') return AppMode.artist;
    if (raw == 'client') return AppMode.client;
    return fallback;
  }
}

/// Real-time `/artists/{uid}` profile stream for the active authenticated user (if an artist document exists).
final currentArtistProfileProvider = StreamProvider<Artist?>((ref) {
  final uid = ref.watch(activeUidProvider);
  if (uid == null || uid.isEmpty) {
    return Stream<Artist?>.value(null);
  }
  return ref.watch(artistRepositoryProvider).watchArtist(uid);
});

/// Reactive notifier tracking whether a dual-role user is currently operating in Client or Artist mode.
class ActiveAppModeNotifier extends Notifier<AppMode> {
  @override
  AppMode build() {
    ref.watch(sessionEpochProvider);
    final inMemory = AuthService.activeAppMode;
    if (inMemory != null) {
      return AppMode.fromString(inMemory);
    }
    final userProfile = ref.watch(currentUserProfileProvider).maybeWhen(
          data: (u) => u,
          orElse: () => null,
        );
    if (userProfile?.activeMode != null) {
      return AppMode.fromString(userProfile!.activeMode);
    }
    if (userProfile?.isArtist == true) {
      return AppMode.artist;
    }
    return AppMode.client;
  }

  Future<void> switchMode(AppMode newMode) async {
    state = newMode;
    final uid = ref.read(activeUidProvider);
    final firestore = ref.read(firebaseFirestoreProvider);
    await AuthService.setActiveAppMode(
      newMode.value,
      uid: uid,
      firestore: firestore,
    );
  }
}

final activeAppModeProvider =
    NotifierProvider<ActiveAppModeNotifier, AppMode>(
  ActiveAppModeNotifier.new,
);

/// Explicitly invalidates all user-scoped Riverpod providers on sign-out.
void invalidateUserSessionProviders(WidgetRef ref) {
  ref.invalidate(sessionEpochProvider);
  ref.invalidate(authStateStreamProvider);
  ref.invalidate(activeUidProvider);
  ref.invalidate(currentUserProfileProvider);
  ref.invalidate(currentArtistProfileProvider);
  ref.invalidate(activeAppModeProvider);
  ref.invalidate(liveGpsCoordinatesProvider);
  ref.invalidate(effectiveClientCoordinatesProvider);
}

/// Invalidates all user-scoped Riverpod providers via [BuildContext] if inside a [ProviderScope].
void invalidateUserSessionFromContext(BuildContext context) {
  try {
    final container = ProviderScope.containerOf(context, listen: false);
    container.invalidate(sessionEpochProvider);
    container.invalidate(authStateStreamProvider);
    container.invalidate(activeUidProvider);
    container.invalidate(currentUserProfileProvider);
    container.invalidate(currentArtistProfileProvider);
    container.invalidate(activeAppModeProvider);
    container.invalidate(liveGpsCoordinatesProvider);
    container.invalidate(effectiveClientCoordinatesProvider);
  } catch (_) {
    // Safe no-op in standalone widget tests rendered without a ProviderScope
  }
}
