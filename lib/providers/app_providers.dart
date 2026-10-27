import 'package:cloud_firestore/cloud_firestore.dart';
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

/// Active [AuthService] instance.
final authServiceProvider = Provider<AuthService>((ref) {
  final firestore = ref.watch(firebaseFirestoreProvider);
  return AuthService(firestore: firestore);
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

/// Combines live permitted Client GPS coordinates with a graceful fallback to
/// the Client's persisted `/users/{uid}` profile coordinates (`latitude`/`longitude`).
final effectiveClientCoordinatesProvider = Provider<GeoPointCoords?>((ref) {
  final liveCoords = ref.watch(liveGpsCoordinatesProvider);
  if (liveCoords != null && liveCoords.isValid) {
    return liveCoords;
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
  final artistsAsync = ref.watch(artistDiscoveryStreamProvider);
  return artistsAsync.whenData(
    (artists) => artists
        .map((artist) => artist.withLiveDistanceFrom(clientCoords))
        .toList(growable: false),
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

  return ref
      .watch(artistRepositoryProvider)
      .watchArtist(artistId)
      .map((artist) => artist?.withLiveDistanceFrom(clientCoords));
});

/// Live Explore studios derived from onboarded Artists (or mock studios when [mockModeProvider] is enabled).
final exploreStudiosProvider = Provider<AsyncValue<List<ExploreStudio>>>((ref) {
  final useMock = ref.watch(mockModeProvider);
  if (useMock) {
    return const AsyncValue.data(MockFixtures.studios);
  }
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

/// Explicitly invalidates all user-scoped Riverpod providers on sign-out.
void invalidateUserSessionProviders(WidgetRef ref) {
  ref.invalidate(sessionEpochProvider);
  ref.invalidate(authStateStreamProvider);
  ref.invalidate(activeUidProvider);
  ref.invalidate(currentUserProfileProvider);
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
    container.invalidate(liveGpsCoordinatesProvider);
    container.invalidate(effectiveClientCoordinatesProvider);
  } catch (_) {
    // Safe no-op in standalone widget tests rendered without a ProviderScope
  }
}
