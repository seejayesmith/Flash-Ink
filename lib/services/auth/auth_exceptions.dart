import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Exception thrown when a sensitive operation requires recent authentication.
class RequiresRecentLoginException implements Exception {
  final String message;
  const RequiresRecentLoginException([
    this.message =
        'This action requires recent authentication. Please log in again before deleting your account.',
  ]);

  @override
  String toString() => 'Exception: $message';
}

/// Maps a [FirebaseFunctionsException] thrown by recovery OTP callables into
/// a structured [FirebaseAuthException] for downstream UI/controller handling.
FirebaseAuthException mapRecoveryFunctionsException(
  FirebaseFunctionsException e, {
  String? identifier,
  bool isVerification = false,
}) {
  final details = e.details;
  final detailsCode =
      details is Map ? (details['code'] as Object?)?.toString() : null;

  if (detailsCode == 'too-many-requests' || e.code == 'resource-exhausted') {
    return FirebaseAuthException(
      code: 'too-many-requests',
      message: (e.message != null && e.message!.isNotEmpty)
          ? e.message
          : 'Too many OTP requests or failed attempts. Please wait before trying again.',
    );
  }

  if (detailsCode == 'session-expired' ||
      e.code == 'not-found' ||
      e.code == 'deadline-exceeded') {
    return FirebaseAuthException(
      code: 'session-expired',
      message: (e.message != null && e.message!.isNotEmpty)
          ? e.message
          : 'The verification code has expired. Please request a new code.',
    );
  }

  if (detailsCode == 'invalid-verification-code' ||
      e.code == 'permission-denied') {
    return FirebaseAuthException(
      code: 'invalid-verification-code',
      message: (e.message != null && e.message!.isNotEmpty)
          ? e.message
          : 'The verification code entered is invalid.',
    );
  }

  if (e.code == 'invalid-argument') {
    if (isVerification) {
      return FirebaseAuthException(
        code: 'invalid-verification-code',
        message: (e.message != null && e.message!.isNotEmpty)
            ? e.message
            : 'The verification code entered is invalid.',
      );
    }
    final isPhone = identifier != null && !identifier.contains('@');
    return FirebaseAuthException(
      code: isPhone ? 'invalid-phone-number' : 'invalid-email',
      message: (e.message != null && e.message!.isNotEmpty)
          ? e.message
          : (isPhone
              ? 'Please enter a valid phone number.'
              : 'Please enter a valid email address.'),
    );
  }

  if (e.code == 'unavailable') {
    return FirebaseAuthException(
      code: 'network-request-failed',
      message: 'Network error. Please check your internet connection.',
    );
  }

  return FirebaseAuthException(
    code: e.code,
    message: e.message ?? 'An authentication recovery error occurred.',
  );
}

/// Maps a [FirebaseAuthException] to a clean, user-facing [Exception].
Exception mapFirebaseAuthException(
  FirebaseAuthException e, [
  String? provider,
]) {
  switch (e.code) {
    case 'invalid-phone-number':
      return Exception('Please enter a valid phone number.');
    case 'missing-verification-code':
      return Exception('Please enter a valid 6-digit verification code.');
    case 'invalid-verification-code':
      return Exception('The verification code entered is invalid.');
    case 'invalid-verification-id':
    case 'session-expired':
      return Exception(
        'Verification code has expired. Please request a new code.',
      );
    case 'quota-exceeded':
      return Exception('SMS quota exceeded. Please try again later.');
    case 'too-many-requests':
      return Exception('Too many attempts. Please try again later.');
    case 'invalid-email':
      return Exception('The email address is invalid.');
    case 'user-disabled':
      return Exception('This account has been disabled.');
    case 'user-not-found':
      return Exception('No account found with this email.');
    case 'wrong-password':
    case 'invalid-credential':
      return Exception('Incorrect password or credentials.');
    case 'email-already-in-use':
      return Exception('An account already exists for this email.');
    case 'operation-not-allowed':
    case 'admin-restricted-operation':
      if (provider == 'phone') {
        return Exception(
          'Phone authentication is disabled in the Firebase Console. Enable "Phone" under Authentication > Sign-in method in Firebase Console.',
        );
      } else if (provider == 'email') {
        return Exception(
          'Email/Password sign-in is disabled in the Firebase Console. Enable "Email/Password" under Authentication > Sign-in method in Firebase Console.',
        );
      }
      return Exception(
        'Anonymous authentication is disabled in the Firebase Console. Enable "Anonymous" under Authentication > Sign-in method in Firebase Console.',
      );
    case 'weak-password':
      return Exception('The password provided is too weak.');
    case 'credential-already-in-use':
      return Exception('This account is already linked to another user.');
    case 'network-request-failed':
      return Exception('Network error. Please check your internet connection.');
    case 'requires-recent-login':
      return const RequiresRecentLoginException(
        'This action requires recent authentication. Please log in again before deleting your account.',
      );
    default:
      return Exception(e.message ?? 'Authentication error (${e.code}).');
  }
}
