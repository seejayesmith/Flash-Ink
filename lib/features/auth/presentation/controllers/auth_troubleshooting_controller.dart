import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/auth_recovery_service.dart';

/// Compatibility typedef for Riverpod 3.x where [AsyncNotifier] backs
/// `AsyncNotifierProvider.autoDispose`.
typedef AutoDisposeAsyncNotifier<StateT> = AsyncNotifier<StateT>;

/// Discrete lifecycle phases for the login troubleshooting & account recovery flow.
enum AuthTroubleshootingStatus {
  idle,
  sendingCode,
  codeSent,
  verifying,
  accountMatched,
  rateLimited,
  success,
  error,
}

/// Immutable, strongly-typed state hierarchy for [AuthTroubleshootingController].
@immutable
sealed class AuthTroubleshootingState {
  final AuthTroubleshootingStatus status;
  final int? cooldown;
  final int? seconds;
  final String? email;
  final String? phoneNumber;
  final AuthCredential? pendingCredential;
  final String? errorMessage;
  final String? errorCode;
  final String? escalationTicketId;

  const AuthTroubleshootingState._({
    required this.status,
    this.cooldown,
    this.seconds,
    this.email,
    this.phoneNumber,
    this.pendingCredential,
    this.errorMessage,
    this.errorCode,
    this.escalationTicketId,
  });

  const factory AuthTroubleshootingState.idle() = AuthTroubleshootingIdle;

  const factory AuthTroubleshootingState.sendingCode({
    String? email,
    String? phoneNumber,
  }) = AuthTroubleshootingSendingCode;

  const factory AuthTroubleshootingState.codeSent(
    int cooldown, {
    String? email,
    String? phoneNumber,
  }) = AuthTroubleshootingCodeSent;

  const factory AuthTroubleshootingState.verifying({
    String? email,
    String? phoneNumber,
  }) = AuthTroubleshootingVerifying;

  const factory AuthTroubleshootingState.accountMatched({
    String? email,
    String? phoneNumber,
    AuthCredential? pendingCredential,
  }) = AuthTroubleshootingAccountMatched;

  const factory AuthTroubleshootingState.rateLimited(
    int seconds, {
    String? errorMessage,
    String? errorCode,
    String? email,
    String? phoneNumber,
  }) = AuthTroubleshootingRateLimited;

  const factory AuthTroubleshootingState.success({
    String? email,
    String? phoneNumber,
    String? escalationTicketId,
  }) = AuthTroubleshootingSuccess;

  const factory AuthTroubleshootingState.error(
    String message, {
    String? code,
    String? email,
    String? phoneNumber,
    AuthCredential? pendingCredential,
  }) = AuthTroubleshootingError;

  /// Remaining OTP resend cooldown in seconds (`0` when not in [codeSent] state).
  int get cooldownSeconds => cooldown ?? 0;

  /// Remaining rate-limit lockout in seconds (`0` when not in [rateLimited] state).
  int get rateLimitSeconds => seconds ?? 0;

  /// Whether an OTP resend is currently blocked by an active countdown.
  bool get isResendBlocked =>
      (status == AuthTroubleshootingStatus.codeSent && (cooldown ?? 0) > 0) ||
      (status == AuthTroubleshootingStatus.rateLimited && (seconds ?? 0) > 0);

  /// Whether the error represents an `account-exists-with-different-credential` collision.
  bool get isAccountCollision =>
      errorCode == 'account-exists-with-different-credential';
}

/// Initial idle state before any recovery action has started.
final class AuthTroubleshootingIdle extends AuthTroubleshootingState {
  const AuthTroubleshootingIdle()
      : super._(status: AuthTroubleshootingStatus.idle);

  @override
  bool operator ==(Object other) => other is AuthTroubleshootingIdle;

  @override
  int get hashCode => status.hashCode;

  @override
  String toString() => 'AuthTroubleshootingState.idle()';
}

/// State emitted while an OTP code is actively being dispatched.
final class AuthTroubleshootingSendingCode extends AuthTroubleshootingState {
  const AuthTroubleshootingSendingCode({
    super.email,
    super.phoneNumber,
  }) : super._(status: AuthTroubleshootingStatus.sendingCode);

  @override
  bool operator ==(Object other) =>
      other is AuthTroubleshootingSendingCode &&
      other.email == email &&
      other.phoneNumber == phoneNumber;

  @override
  int get hashCode => Object.hash(status, email, phoneNumber);

  @override
  String toString() =>
      'AuthTroubleshootingState.sendingCode(email: $email, phoneNumber: $phoneNumber)';
}

/// State emitted once a secondary email OTP has been sent, tracking the
/// remaining [cooldown] seconds before another code can be requested.
final class AuthTroubleshootingCodeSent extends AuthTroubleshootingState {
  @override
  int get cooldown => super.cooldown!;

  const AuthTroubleshootingCodeSent(
    int cooldown, {
    super.email,
    super.phoneNumber,
  }) : super._(
          status: AuthTroubleshootingStatus.codeSent,
          cooldown: cooldown,
        );

  @override
  bool operator ==(Object other) =>
      other is AuthTroubleshootingCodeSent &&
      other.cooldown == cooldown &&
      other.email == email &&
      other.phoneNumber == phoneNumber;

  @override
  int get hashCode => Object.hash(status, cooldown, email, phoneNumber);

  @override
  String toString() =>
      'AuthTroubleshootingState.codeSent($cooldown, email: $email)';
}

/// State emitted while OTP verification, phone update, or credential linking is in flight.
final class AuthTroubleshootingVerifying extends AuthTroubleshootingState {
  const AuthTroubleshootingVerifying({
    super.email,
    super.phoneNumber,
  }) : super._(status: AuthTroubleshootingStatus.verifying);

  @override
  bool operator ==(Object other) =>
      other is AuthTroubleshootingVerifying &&
      other.email == email &&
      other.phoneNumber == phoneNumber;

  @override
  int get hashCode => Object.hash(status, email, phoneNumber);

  @override
  String toString() =>
      'AuthTroubleshootingState.verifying(email: $email, phoneNumber: $phoneNumber)';
}

/// State emitted when a secondary email OTP has verified ownership of an existing
/// account, allowing phone number recovery or credential linking.
final class AuthTroubleshootingAccountMatched extends AuthTroubleshootingState {
  const AuthTroubleshootingAccountMatched({
    super.email,
    super.phoneNumber,
    super.pendingCredential,
  }) : super._(status: AuthTroubleshootingStatus.accountMatched);

  @override
  bool operator ==(Object other) =>
      other is AuthTroubleshootingAccountMatched &&
      other.email == email &&
      other.phoneNumber == phoneNumber &&
      other.pendingCredential == pendingCredential;

  @override
  int get hashCode =>
      Object.hash(status, email, phoneNumber, pendingCredential);

  @override
  String toString() =>
      'AuthTroubleshootingState.accountMatched(email: $email, phoneNumber: $phoneNumber)';
}

/// State emitted when Firebase rejects an action with `too-many-requests`,
/// tracking the remaining backoff [seconds].
final class AuthTroubleshootingRateLimited extends AuthTroubleshootingState {
  @override
  int get seconds => super.seconds!;

  const AuthTroubleshootingRateLimited(
    int seconds, {
    String? errorMessage,
    String? errorCode,
    super.email,
    super.phoneNumber,
  }) : super._(
          status: AuthTroubleshootingStatus.rateLimited,
          seconds: seconds,
          errorMessage: errorMessage ??
              'Too many attempts. Please wait before trying again.',
          errorCode: errorCode ?? 'too-many-requests',
        );

  @override
  bool operator ==(Object other) =>
      other is AuthTroubleshootingRateLimited &&
      other.seconds == seconds &&
      other.errorMessage == errorMessage &&
      other.errorCode == errorCode &&
      other.email == email &&
      other.phoneNumber == phoneNumber;

  @override
  int get hashCode =>
      Object.hash(status, seconds, errorMessage, errorCode, email, phoneNumber);

  @override
  String toString() =>
      'AuthTroubleshootingState.rateLimited($seconds, errorCode: $errorCode)';
}

/// State emitted when phone recovery, credential collision linking, or support
/// escalation completes cleanly.
final class AuthTroubleshootingSuccess extends AuthTroubleshootingState {
  const AuthTroubleshootingSuccess({
    super.email,
    super.phoneNumber,
    super.escalationTicketId,
  }) : super._(status: AuthTroubleshootingStatus.success);

  @override
  bool operator ==(Object other) =>
      other is AuthTroubleshootingSuccess &&
      other.email == email &&
      other.phoneNumber == phoneNumber &&
      other.escalationTicketId == escalationTicketId;

  @override
  int get hashCode =>
      Object.hash(status, email, phoneNumber, escalationTicketId);

  @override
  String toString() =>
      'AuthTroubleshootingState.success(email: $email, phoneNumber: $phoneNumber, escalationTicketId: $escalationTicketId)';
}

/// State emitted when a recoverable or terminal authentication error occurs.
final class AuthTroubleshootingError extends AuthTroubleshootingState {
  String get message => super.errorMessage!;
  String? get code => super.errorCode;

  const AuthTroubleshootingError(
    String message, {
    String? code,
    super.email,
    super.phoneNumber,
    super.pendingCredential,
  }) : super._(
          status: AuthTroubleshootingStatus.error,
          errorMessage: message,
          errorCode: code,
        );

  @override
  bool operator ==(Object other) =>
      other is AuthTroubleshootingError &&
      other.errorMessage == errorMessage &&
      other.errorCode == errorCode &&
      other.email == email &&
      other.phoneNumber == phoneNumber &&
      other.pendingCredential == pendingCredential;

  @override
  int get hashCode => Object.hash(
        status,
        errorMessage,
        errorCode,
        email,
        phoneNumber,
        pendingCredential,
      );

  @override
  String toString() =>
      'AuthTroubleshootingState.error($errorMessage, code: $errorCode)';
}

/// Riverpod controller orchestrating login troubleshooting, OTP cooldown timers,
/// rate-limit backoff, phone number updates, credential collision linking, and
/// support escalation.
class AuthTroubleshootingController
    extends AutoDisposeAsyncNotifier<AuthTroubleshootingState> {
  static const int defaultCooldownSeconds = 60;
  static const int defaultRateLimitSeconds = 60;

  Timer? _cooldownTimer;
  Timer? _rateLimitTimer;

  AuthRecoveryService get _recoveryService =>
      ref.read(authRecoveryServiceProvider);

  @override
  FutureOr<AuthTroubleshootingState> build() {
    ref.onDispose(_cancelTimers);
    return const AuthTroubleshootingState.idle();
  }

  void _cancelTimers() {
    _cooldownTimer?.cancel();
    _cooldownTimer = null;
    _rateLimitTimer?.cancel();
    _rateLimitTimer = null;
  }

  /// Resets the controller to [AuthTroubleshootingState.idle] and cancels active timers.
  void reset() {
    _cancelTimers();
    state = const AsyncData(AuthTroubleshootingState.idle());
  }

  /// Sends a 6-digit recovery OTP to [email] and starts a 1-second periodic
  /// cooldown timer from [cooldownSeconds] down to `0`.
  Future<void> sendSecondaryEmailOtp(
    String email, {
    int cooldownSeconds = defaultCooldownSeconds,
    int rateLimitSeconds = defaultRateLimitSeconds,
  }) async {
    _cancelTimers();
    final trimmedEmail = email.trim();
    state = AsyncData(
      AuthTroubleshootingState.sendingCode(email: trimmedEmail),
    );

    try {
      await _recoveryService.sendSecondaryEmailOtp(trimmedEmail);
      final normalizedEmail = trimmedEmail.toLowerCase();
      final initialCooldown = cooldownSeconds < 0 ? 0 : cooldownSeconds;
      state = AsyncData(
        AuthTroubleshootingState.codeSent(
          initialCooldown,
          email: normalizedEmail,
        ),
      );
      if (initialCooldown > 0) {
        _startCooldownCountdown(
          initialSeconds: initialCooldown,
          email: normalizedEmail,
        );
      }
    } on FirebaseAuthException catch (e) {
      _handleFirebaseException(
        e,
        rateLimitSeconds: rateLimitSeconds,
        email: trimmedEmail,
      );
    } catch (e) {
      state = AsyncData(
        AuthTroubleshootingState.error(
          e.toString(),
          code: 'unknown',
          email: trimmedEmail,
        ),
      );
    }
  }

  void _startCooldownCountdown({
    required int initialSeconds,
    String? email,
    String? phoneNumber,
  }) {
    _cooldownTimer?.cancel();
    var remaining = initialSeconds;
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final current = state.value;
      if (current == null ||
          current.status != AuthTroubleshootingStatus.codeSent) {
        timer.cancel();
        return;
      }

      remaining -= 1;
      if (remaining <= 0) {
        timer.cancel();
        _cooldownTimer = null;
        state = AsyncData(
          AuthTroubleshootingState.codeSent(
            0,
            email: email ?? current.email,
            phoneNumber: phoneNumber ?? current.phoneNumber,
          ),
        );
      } else {
        state = AsyncData(
          AuthTroubleshootingState.codeSent(
            remaining,
            email: email ?? current.email,
            phoneNumber: phoneNumber ?? current.phoneNumber,
          ),
        );
      }
    });
  }

  void _startRateLimitCountdown({
    required int initialSeconds,
    String? errorMessage,
    String? email,
    String? phoneNumber,
  }) {
    _rateLimitTimer?.cancel();
    var remaining = initialSeconds;
    _rateLimitTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final current = state.value;
      if (current == null ||
          current.status != AuthTroubleshootingStatus.rateLimited) {
        timer.cancel();
        return;
      }

      remaining -= 1;
      if (remaining <= 0) {
        timer.cancel();
        _rateLimitTimer = null;
        state = AsyncData(
          AuthTroubleshootingState.rateLimited(
            0,
            errorMessage: errorMessage ?? current.errorMessage,
            email: email ?? current.email,
            phoneNumber: phoneNumber ?? current.phoneNumber,
          ),
        );
      } else {
        state = AsyncData(
          AuthTroubleshootingState.rateLimited(
            remaining,
            errorMessage: errorMessage ?? current.errorMessage,
            email: email ?? current.email,
            phoneNumber: phoneNumber ?? current.phoneNumber,
          ),
        );
      }
    });
  }

  /// Verifies the secondary email OTP [code] for [email] and transitions to
  /// [AuthTroubleshootingState.accountMatched] upon match.
  Future<void> verifySecondaryEmailOtp({
    required String email,
    required String code,
    int rateLimitSeconds = defaultRateLimitSeconds,
  }) async {
    _cancelTimers();
    final trimmedEmail = email.trim().toLowerCase();
    state = AsyncData(
      AuthTroubleshootingState.verifying(email: trimmedEmail),
    );

    try {
      final isMatched = await _recoveryService.verifySecondaryEmailOtp(
        email: trimmedEmail,
        code: code,
      );
      if (isMatched) {
        state = AsyncData(
          AuthTroubleshootingState.accountMatched(email: trimmedEmail),
        );
      } else {
        state = AsyncData(
          AuthTroubleshootingState.error(
            'The verification code entered is invalid. Please check the code and try again.',
            code: 'invalid-verification-code',
            email: trimmedEmail,
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      _handleFirebaseException(
        e,
        rateLimitSeconds: rateLimitSeconds,
        email: trimmedEmail,
      );
    } catch (e) {
      state = AsyncData(
        AuthTroubleshootingState.error(
          e.toString(),
          code: 'unknown',
          email: trimmedEmail,
        ),
      );
    }
  }

  /// Updates the user's phone number and transitions to [AuthTroubleshootingState.success].
  Future<void> updateUserPhoneNumber({
    required String phoneNumber,
    PhoneAuthCredential? credential,
    String? verificationId,
    String? smsCode,
    String? uid,
    int rateLimitSeconds = defaultRateLimitSeconds,
  }) async {
    _cancelTimers();
    final currentEmail = state.value?.email;
    state = AsyncData(
      AuthTroubleshootingState.verifying(
        email: currentEmail,
        phoneNumber: phoneNumber.trim(),
      ),
    );

    try {
      await _recoveryService.updateUserPhoneNumber(
        phoneNumber: phoneNumber,
        credential: credential,
        verificationId: verificationId,
        smsCode: smsCode,
        uid: uid,
      );
      state = AsyncData(
        AuthTroubleshootingState.success(
          email: currentEmail,
          phoneNumber: phoneNumber.trim(),
        ),
      );
    } on FirebaseAuthException catch (e) {
      _handleFirebaseException(
        e,
        rateLimitSeconds: rateLimitSeconds,
        email: currentEmail,
        phoneNumber: phoneNumber.trim(),
      );
    } catch (e) {
      state = AsyncData(
        AuthTroubleshootingState.error(
          e.toString(),
          code: 'unknown',
          email: currentEmail,
          phoneNumber: phoneNumber.trim(),
        ),
      );
    }
  }

  /// Resolves an `account-exists-with-different-credential` collision by linking
  /// [credential] via [AuthRecoveryService.resolveAccountCollision] and transitions
  /// to [AuthTroubleshootingState.success].
  Future<UserCredential?> resolveAccountCollision({
    required AuthCredential credential,
    AuthCredential? existingCredential,
    int rateLimitSeconds = defaultRateLimitSeconds,
  }) async {
    _cancelTimers();
    final currentEmail = state.value?.email;
    final currentPhone = state.value?.phoneNumber;
    state = AsyncData(
      AuthTroubleshootingState.verifying(
        email: currentEmail,
        phoneNumber: currentPhone,
      ),
    );

    try {
      final result = await _recoveryService.resolveAccountCollision(
        credential: credential,
        existingCredential: existingCredential,
      );
      state = AsyncData(
        AuthTroubleshootingState.success(
          email: result.user?.email ?? currentEmail,
          phoneNumber: result.user?.phoneNumber ?? currentPhone,
        ),
      );
      return result;
    } on FirebaseAuthException catch (e) {
      _handleFirebaseException(
        e,
        rateLimitSeconds: rateLimitSeconds,
        email: currentEmail,
        phoneNumber: currentPhone,
      );
      return null;
    } catch (e) {
      state = AsyncData(
        AuthTroubleshootingState.error(
          e.toString(),
          code: 'unknown',
          email: currentEmail,
          phoneNumber: currentPhone,
          pendingCredential: credential,
        ),
      );
      return null;
    }
  }

  /// Submits a support escalation ticket and transitions to [AuthTroubleshootingState.success]
  /// with the generated [AuthTroubleshootingState.escalationTicketId].
  Future<String?> submitSupportEscalation({
    required String contactEmail,
    required String reason,
    String? phoneNumber,
    String? uid,
    Map<String, dynamic>? diagnostics,
    int rateLimitSeconds = defaultRateLimitSeconds,
  }) async {
    _cancelTimers();
    final trimmedEmail = contactEmail.trim();
    state = AsyncData(
      AuthTroubleshootingState.verifying(
        email: trimmedEmail,
        phoneNumber: phoneNumber,
      ),
    );

    try {
      final ticketId = await _recoveryService.submitSupportEscalation(
        contactEmail: trimmedEmail,
        reason: reason,
        phoneNumber: phoneNumber,
        uid: uid,
        diagnostics: diagnostics,
      );
      state = AsyncData(
        AuthTroubleshootingState.success(
          email: trimmedEmail.toLowerCase(),
          phoneNumber: phoneNumber,
          escalationTicketId: ticketId,
        ),
      );
      return ticketId;
    } on FirebaseAuthException catch (e) {
      _handleFirebaseException(
        e,
        rateLimitSeconds: rateLimitSeconds,
        email: trimmedEmail,
        phoneNumber: phoneNumber,
      );
      return null;
    } catch (e) {
      state = AsyncData(
        AuthTroubleshootingState.error(
          e.toString(),
          code: 'unknown',
          email: trimmedEmail,
          phoneNumber: phoneNumber,
        ),
      );
      return null;
    }
  }

  /// Maps a [FirebaseAuthException] into a strongly-typed [AuthTroubleshootingState].
  ///
  /// Specifically handles:
  /// - `too-many-requests` -> [AuthTroubleshootingState.rateLimited]
  /// - `account-exists-with-different-credential` -> [AuthTroubleshootingState.error] (with collision metadata)
  /// - `invalid-verification-code` -> [AuthTroubleshootingState.error]
  AuthTroubleshootingState mapFirebaseException(
    FirebaseAuthException e, {
    int rateLimitSeconds = defaultRateLimitSeconds,
    String? email,
    String? phoneNumber,
  }) {
    final effectiveEmail = e.email ?? email;
    switch (e.code) {
      case 'too-many-requests':
        return AuthTroubleshootingState.rateLimited(
          rateLimitSeconds,
          errorMessage:
              'Too many attempts. Please wait $rateLimitSeconds seconds before trying again.',
          errorCode: 'too-many-requests',
          email: effectiveEmail,
          phoneNumber: phoneNumber,
        );
      case 'account-exists-with-different-credential':
        return AuthTroubleshootingState.error(
          'An account already exists with the same email address but different sign-in credentials. Please link your credentials to continue.',
          code: 'account-exists-with-different-credential',
          email: effectiveEmail,
          phoneNumber: phoneNumber,
          pendingCredential: e.credential,
        );
      case 'invalid-verification-code':
        return AuthTroubleshootingState.error(
          'The verification code entered is invalid. Please check the code and try again.',
          code: 'invalid-verification-code',
          email: effectiveEmail,
          phoneNumber: phoneNumber,
        );
      case 'session-expired':
      case 'invalid-verification-id':
        return AuthTroubleshootingState.error(
          'The verification code has expired. Please request a new code.',
          code: e.code,
          email: effectiveEmail,
          phoneNumber: phoneNumber,
        );
      case 'invalid-email':
        return AuthTroubleshootingState.error(
          'Please enter a valid email address.',
          code: 'invalid-email',
          email: effectiveEmail,
          phoneNumber: phoneNumber,
        );
      case 'invalid-phone-number':
        return AuthTroubleshootingState.error(
          'Please enter a valid phone number.',
          code: 'invalid-phone-number',
          email: effectiveEmail,
          phoneNumber: phoneNumber,
        );
      case 'credential-already-in-use':
        return AuthTroubleshootingState.error(
          'This credential is already linked to another user account.',
          code: 'credential-already-in-use',
          email: effectiveEmail,
          phoneNumber: phoneNumber,
          pendingCredential: e.credential,
        );
      default:
        return AuthTroubleshootingState.error(
          e.message ?? 'An authentication error occurred (${e.code}).',
          code: e.code,
          email: effectiveEmail,
          phoneNumber: phoneNumber,
          pendingCredential: e.credential,
        );
    }
  }

  void _handleFirebaseException(
    FirebaseAuthException e, {
    required int rateLimitSeconds,
    String? email,
    String? phoneNumber,
  }) {
    final mappedState = mapFirebaseException(
      e,
      rateLimitSeconds: rateLimitSeconds,
      email: email,
      phoneNumber: phoneNumber,
    );
    state = AsyncData(mappedState);

    if (mappedState is AuthTroubleshootingRateLimited &&
        mappedState.seconds > 0) {
      _startRateLimitCountdown(
        initialSeconds: mappedState.seconds,
        errorMessage: mappedState.errorMessage,
        email: mappedState.email,
        phoneNumber: mappedState.phoneNumber,
      );
    }
  }
}

/// Auto-disposing Riverpod provider for [AuthTroubleshootingController].
final authTroubleshootingControllerProvider = AsyncNotifierProvider.autoDispose<
    AuthTroubleshootingController, AuthTroubleshootingState>(
  AuthTroubleshootingController.new,
);
