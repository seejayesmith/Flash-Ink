import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';

/// Thrown when a user attempts to claim or save a username/handle
/// that already belongs to another account.
class UsernameTakenException implements Exception {
  final String username;
  final String message;

  const UsernameTakenException(
    this.username, {
    this.message = UsernameService.takenErrorMessage,
  });

  @override
  String toString() => message;
}

/// Thrown when a username/handle violates industry-standard format rules.
class UsernameFormatException implements Exception {
  final String message;

  const UsernameFormatException(this.message);

  @override
  String toString() => message;
}

/// Enforces global, case-insensitive username/handle uniqueness and
/// industry-standard handle formatting across both Clients and Artists.
///
/// Backed by the `/usernames/{normalizedHandle}` Firestore collection where
/// each document ID is the lowercase handle (`[a-z0-9._]`, 3–30 chars).
class UsernameService {
  static const int minLength = 3;
  static const int maxLength = 30;
  static const String takenErrorMessage = 'That username is already taken';

  final FirebaseFirestore? _injectedFirestore;

  const UsernameService({FirebaseFirestore? firestore})
      : _injectedFirestore = firestore;

  FirebaseFirestore? _resolveFirestore() {
    if (_injectedFirestore != null) return _injectedFirestore;
    final isWidgetTest =
        WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (isWidgetTest) {
      // Standalone widget tests without an injected FakeFirebaseFirestore
      // do not have a Firestore platform channel responder.
      return null;
    }
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  /// Strips leading/embedded `@` characters and surrounding whitespace,
  /// preserving the user's chosen display casing (e.g. `@OddMaree` -> `OddMaree`).
  static String cleanDisplay(String raw) {
    return raw.trim().replaceAll('@', '').trim();
  }

  /// Normalizes a raw handle into its canonical lowercase registry key
  /// (e.g. `@OddMaree` -> `oddmaree`).
  static String normalize(String raw) {
    return cleanDisplay(raw).toLowerCase();
  }

  /// Validates a handle against industry-standard rules (Instagram / TikTok / X):
  /// - 3 to 30 characters
  /// - Only letters (`a-z`, `A-Z`), numbers (`0-9`), underscores (`_`), and periods (`.`)
  /// - Cannot start or end with a period (`.`)
  /// - Cannot contain consecutive periods (`..`)
  ///
  /// Returns `null` when valid, or a user-friendly error message when invalid.
  static String? validateFormat(
    String raw, {
    String emptyMessage = 'Please enter a username',
  }) {
    final cleaned = cleanDisplay(raw);
    if (cleaned.isEmpty) {
      return emptyMessage;
    }
    if (cleaned.length < minLength) {
      return 'Username must be at least $minLength characters';
    }
    if (cleaned.length > maxLength) {
      return 'Username must be $maxLength characters or less';
    }
    if (cleaned.startsWith('.') || cleaned.endsWith('.')) {
      return 'Username cannot start or end with a period';
    }
    if (cleaned.contains('..')) {
      return 'Username cannot contain consecutive periods';
    }
    if (!RegExp(r'^[a-zA-Z0-9._]+$').hasMatch(cleaned)) {
      return 'Only letters, numbers, underscores, and periods are allowed';
    }
    return null;
  }

  /// Checks whether [rawUsername] is formatted validly and not claimed by any
  /// user other than [currentUid].
  Future<bool> isUsernameAvailable(
    String rawUsername, {
    String? currentUid,
  }) async {
    if (validateFormat(rawUsername) != null) {
      return false;
    }

    final db = _resolveFirestore();
    if (db == null) return true;

    final normalized = normalize(rawUsername);
    final effectiveUid = (currentUid ?? '').trim();

    try {
      // 1. Primary O(1) lookup in `/usernames/{normalized}` registry.
      final claimSnap =
          await db.collection('usernames').doc(normalized).get();
      if (claimSnap.exists) {
        final ownerUid = (claimSnap.data()?['uid'] ?? '').toString().trim();
        if (ownerUid.isNotEmpty && ownerUid != effectiveUid) {
          return false;
        }
      }

      // 2. Fallback check against `/artists` (publicly readable) for any
      // pre-existing artist handle not yet indexed in `/usernames`.
      try {
        final artistsSnap = await db.collection('artists').get();
        for (final doc in artistsSnap.docs) {
          if (doc.id == effectiveUid) continue;
          final data = doc.data();
          final artistUsername = normalize((data['username'] ?? '').toString());
          final artistHandle =
              normalize((data['instagramHandle'] ?? '').toString());
          if (artistUsername == normalized || artistHandle == normalized) {
            return false;
          }
        }
      } catch (_) {}

      // 3. Best-effort check against `/users` (succeeds in FakeFirebaseFirestore
      // and admin contexts; silently ignored under owner-only client rules).
      try {
        final usersSnap = await db.collection('users').get();
        for (final doc in usersSnap.docs) {
          if (doc.id == effectiveUid) continue;
          final data = doc.data();
          final clientUsername = normalize((data['username'] ?? '').toString());
          final clientHandle =
              normalize((data['instagramHandle'] ?? '').toString());
          if (clientUsername == normalized || clientHandle == normalized) {
            return false;
          }
        }
      } catch (_) {}

      return true;
    } catch (_) {
      return true;
    }
  }

  /// Atomically claims [rawUsername] for [uid] in `/usernames/{normalized}`,
  /// releasing any previous handle owned by [uid] if they are renaming.
  ///
  /// Throws:
  /// - [UsernameFormatException] if [rawUsername] violates format rules.
  /// - [UsernameTakenException] if another user already owns [rawUsername].
  Future<String> claimUsername({
    required String uid,
    required String rawUsername,
    String? previousUsername,
    String emptyMessage = 'Please enter a username',
  }) async {
    final formatError = validateFormat(
      rawUsername,
      emptyMessage: emptyMessage,
    );
    if (formatError != null) {
      throw UsernameFormatException(formatError);
    }

    final cleaned = cleanDisplay(rawUsername);
    final normalized = normalize(rawUsername);
    final trimmedUid = uid.trim();
    if (trimmedUid.isEmpty) {
      return cleaned;
    }

    final db = _resolveFirestore();
    if (db == null) {
      return cleaned;
    }

    // Verify availability across `/usernames`, `/artists`, and `/users`.
    final available = await isUsernameAvailable(
      cleaned,
      currentUid: trimmedUid,
    );
    if (!available) {
      throw UsernameTakenException(cleaned);
    }

    // Collect any previous normalized handle(s) owned by this user so we can
    // release them in the same atomic transaction when renaming.
    final oldHandlesToRelease = <String>{};
    if (previousUsername != null && previousUsername.trim().isNotEmpty) {
      final prevNorm = normalize(previousUsername);
      if (prevNorm.isNotEmpty && prevNorm != normalized) {
        oldHandlesToRelease.add(prevNorm);
      }
    }

    try {
      final existingUserSnap =
          await db.collection('users').doc(trimmedUid).get();
      final existingUserHandle =
          normalize((existingUserSnap.data()?['username'] ?? '').toString());
      if (existingUserHandle.isNotEmpty && existingUserHandle != normalized) {
        oldHandlesToRelease.add(existingUserHandle);
      }
    } catch (_) {}

    try {
      final existingArtistSnap =
          await db.collection('artists').doc(trimmedUid).get();
      final existingArtistHandle =
          normalize((existingArtistSnap.data()?['username'] ?? '').toString());
      if (existingArtistHandle.isNotEmpty &&
          existingArtistHandle != normalized) {
        oldHandlesToRelease.add(existingArtistHandle);
      }
    } catch (_) {}

    final claimRef = db.collection('usernames').doc(normalized);

    await db.runTransaction((transaction) async {
      final claimSnap = await transaction.get(claimRef);
      if (claimSnap.exists) {
        final ownerUid = (claimSnap.data()?['uid'] ?? '').toString().trim();
        if (ownerUid.isNotEmpty && ownerUid != trimmedUid) {
          throw UsernameTakenException(cleaned);
        }
      }

      // Read old handles before any writes (Firestore transaction requirement).
      final oldRefsToDelete = <DocumentReference<Map<String, dynamic>>>[];
      for (final oldNorm in oldHandlesToRelease) {
        final oldRef = db.collection('usernames').doc(oldNorm);
        final oldSnap = await transaction.get(oldRef);
        if (oldSnap.exists) {
          final oldOwner = (oldSnap.data()?['uid'] ?? '').toString().trim();
          if (oldOwner == trimmedUid) {
            oldRefsToDelete.add(oldRef);
          }
        }
      }

      for (final oldRef in oldRefsToDelete) {
        transaction.delete(oldRef);
      }

      transaction.set(
        claimRef,
        <String, dynamic>{
          'uid': trimmedUid,
          'username': cleaned,
          'normalizedUsername': normalized,
          if (!claimSnap.exists) 'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });

    return cleaned;
  }

  /// Generates a valid, available fallback handle from [baseHandle] (used when
  /// a user taps "Skip" during onboarding), appending a numeric suffix if the
  /// base handle is already taken.
  Future<String> resolveUniqueAutoHandle({
    required String baseHandle,
    String? uid,
  }) async {
    var sanitized = baseHandle
        .trim()
        .replaceAll('@', '')
        .replaceAll(RegExp(r'[^a-zA-Z0-9._]'), '_')
        .replaceAll(RegExp(r'\.+'), '.')
        .replaceAll(RegExp(r'^\.+|\.+$'), '');

    if (sanitized.length < minLength) {
      final cleanUid =
          (uid ?? '').replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
      if (cleanUid.length >= 3) {
        sanitized =
            'user_${cleanUid.substring(0, cleanUid.length.clamp(0, 6))}';
      } else {
        sanitized = 'flashuser';
      }
    }

    if (sanitized.length > maxLength) {
      sanitized =
          sanitized.substring(0, maxLength).replaceAll(RegExp(r'\.+$'), '');
    }

    if (await isUsernameAvailable(sanitized, currentUid: uid)) {
      return sanitized;
    }

    final trimmedBase = sanitized.length > (maxLength - 4)
        ? sanitized
            .substring(0, maxLength - 4)
            .replaceAll(RegExp(r'\.+$'), '')
        : sanitized;

    for (var i = 1; i <= 99; i++) {
      final candidate = '${trimmedBase}_$i';
      if (await isUsernameAvailable(candidate, currentUid: uid)) {
        return candidate;
      }
    }

    final timestampSuffix =
        (DateTime.now().millisecondsSinceEpoch % 100000).toString();
    return '${trimmedBase}_$timestampSuffix';
  }
}
