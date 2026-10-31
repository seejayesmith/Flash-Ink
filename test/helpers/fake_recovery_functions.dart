import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';

/// Test-only [FirebaseFunctionsException] (the base constructor is `@protected`).
class TestFunctionsException extends FirebaseFunctionsException {
  TestFunctionsException({
    required super.code,
    required super.message,
    super.details,
  });
}

/// Records a single callable invocation for assertions.
class RecordedCallableInvocation {
  final String name;
  final Map<String, dynamic> data;

  const RecordedCallableInvocation(this.name, this.data);
}

class _FakeOtpChallenge {
  final String code;
  final DateTime expiresAt;
  int attempts = 0;

  _FakeOtpChallenge({required this.code, required this.expiresAt});
}

/// In-memory fake of the `requestRecoveryOtp` / `verifyRecoveryOtp` HTTPS
/// Callable Cloud Functions. Mirrors the server contract in
/// `functions/src/index.ts`: 10-minute TTL, max 5 attempts, single-use
/// consumption on success, and `HttpsError` codes/details on failure.
///
/// The plaintext OTP is never returned in the callable response; tests read
/// it via [issuedCodes] (the equivalent of the user's inbox).
class FakeRecoveryFunctions extends Fake implements FirebaseFunctions {
  static const int maxAttempts = 5;
  static const Duration ttl = Duration(minutes: 10);

  final String Function() otpGenerator;
  DateTime Function() clock;

  /// Optional forced failure for the next `requestRecoveryOtp` call.
  FirebaseFunctionsException? requestException;

  /// Optional forced failure for the next `verifyRecoveryOtp` call.
  FirebaseFunctionsException? verifyException;

  final List<RecordedCallableInvocation> invocations = [];
  final Map<String, String> issuedCodes = {};
  final Map<String, _FakeOtpChallenge> _challenges = {};

  FakeRecoveryFunctions({
    String Function()? otpGenerator,
    DateTime Function()? clock,
  })  : otpGenerator = otpGenerator ?? (() => '123456'),
        clock = clock ?? DateTime.now;

  /// Whether a server-side challenge currently exists for [identifier].
  bool hasActiveChallenge(String identifier) =>
      _challenges.containsKey(identifier);

  /// Current failed-attempt counter for [identifier] (or `null` if consumed).
  int? attemptsFor(String identifier) => _challenges[identifier]?.attempts;

  List<RecordedCallableInvocation> callsTo(String name) =>
      invocations.where((i) => i.name == name).toList();

  @override
  HttpsCallable httpsCallable(String name, {HttpsCallableOptions? options}) {
    return _FakeHttpsCallable(name, this);
  }

  Map<String, dynamic> _handle(String name, Map<String, dynamic> data) {
    invocations.add(RecordedCallableInvocation(name, data));
    switch (name) {
      case 'requestRecoveryOtp':
        return _request(data);
      case 'verifyRecoveryOtp':
        return _verify(data);
      default:
        throw TestFunctionsException(
          code: 'not-found',
          message: 'Unknown callable "$name".',
        );
    }
  }

  Map<String, dynamic> _request(Map<String, dynamic> data) {
    final forced = requestException;
    if (forced != null) {
      requestException = null;
      throw forced;
    }
    final identifier = data['identifier'] as String?;
    if (identifier == null || identifier.isEmpty) {
      throw TestFunctionsException(
        code: 'invalid-argument',
        message: 'A valid recovery email or phone number is required.',
      );
    }
    final code = otpGenerator();
    issuedCodes[identifier] = code;
    _challenges[identifier] = _FakeOtpChallenge(
      code: code,
      expiresAt: clock().add(ttl),
    );
    return {
      'success': true,
      'channel': identifier.contains('@') ? 'email' : 'phone',
      'expiresInSeconds': ttl.inSeconds,
    };
  }

  Map<String, dynamic> _verify(Map<String, dynamic> data) {
    final forced = verifyException;
    if (forced != null) {
      verifyException = null;
      throw forced;
    }
    final identifier = data['identifier'] as String? ?? '';
    final code = data['code'] as String? ?? '';
    final challenge = _challenges[identifier];

    if (challenge == null) {
      throw TestFunctionsException(
        code: 'not-found',
        message: 'No active verification code found. Please request a new code.',
        details: {'code': 'session-expired'},
      );
    }
    if (challenge.attempts >= maxAttempts) {
      throw TestFunctionsException(
        code: 'resource-exhausted',
        message: 'Too many failed verification attempts. Please try again later.',
        details: {'code': 'too-many-requests'},
      );
    }
    if (!clock().isBefore(challenge.expiresAt)) {
      _challenges.remove(identifier);
      throw TestFunctionsException(
        code: 'deadline-exceeded',
        message: 'The verification code has expired. Please request a new code.',
        details: {'code': 'session-expired'},
      );
    }
    if (challenge.code != code) {
      challenge.attempts++;
      if (challenge.attempts >= maxAttempts) {
        throw TestFunctionsException(
          code: 'resource-exhausted',
          message:
              'Too many failed verification attempts. Please try again later.',
          details: {'code': 'too-many-requests'},
        );
      }
      throw TestFunctionsException(
        code: 'permission-denied',
        message: 'The verification code entered is invalid.',
        details: {
          'code': 'invalid-verification-code',
          'attempts': challenge.attempts,
        },
      );
    }

    // Consume immediately so the code cannot be replayed.
    _challenges.remove(identifier);
    return {'success': true, 'verified': true};
  }
}

class _FakeHttpsCallable extends Fake implements HttpsCallable {
  final String name;
  final FakeRecoveryFunctions backend;

  _FakeHttpsCallable(this.name, this.backend);

  @override
  Future<HttpsCallableResult<T>> call<T>([dynamic parameters]) async {
    final data = <String, dynamic>{
      if (parameters is Map)
        for (final entry in parameters.entries)
          entry.key.toString(): entry.value,
    };
    final result = backend._handle(name, data);
    return _FakeHttpsCallableResult<T>(result as T);
  }
}

class _FakeHttpsCallableResult<T> extends Fake
    implements HttpsCallableResult<T> {
  @override
  final T data;

  _FakeHttpsCallableResult(this.data);
}
