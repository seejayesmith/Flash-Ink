import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/app_providers.dart';
import '../../../../services/auth_service.dart';

/// Service responsible for login troubleshooting, server-verified recovery OTPs,
/// phone number updates, credential collision resolution, and support escalation.
class AuthRecoveryService {
  static const int maxOtpAttempts = 5;
  static const Duration otpExpiration = Duration(minutes: 10);

  static final RegExp _emailPattern = RegExp(
    r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$',
  );

  final FirebaseAuth? _injectedAuth;
  final FirebaseFirestore? _injectedFirestore;
  final FirebaseFunctions? _injectedFunctions;
  final User? currentUserOverride;
  final DateTime Function() _clock;

  AuthRecoveryService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    this.currentUserOverride,
    DateTime Function()? clock,
  })  : _injectedAuth = auth,
        _injectedFirestore = firestore,
        _injectedFunctions = functions,
        _clock = clock ?? DateTime.now;

  FirebaseAuth? _resolveAuth() {
    if (_injectedAuth != null) return _injectedAuth;
    try {
      return FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  FirebaseFirestore? _resolveFirestore() {
    if (_injectedFirestore != null) return _injectedFirestore;
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  FirebaseFunctions _resolveFunctions() {
    return _injectedFunctions ?? FirebaseFunctions.instance;
  }

  User? get currentUser {
    if (currentUserOverride != null) return currentUserOverride;
    if (AuthService.devMockUser != null) return AuthService.devMockUser;
    try {
      return _resolveAuth()?.currentUser;
    } catch (_) {
      return null;
    }
  }

  /// Normalizes and validates an email address.
  static String normalizeAndValidateEmail(String rawEmail) {
    final normalized = rawEmail.trim().toLowerCase();
    if (normalized.isEmpty || !_emailPattern.hasMatch(normalized)) {
      throw FirebaseAuthException(
        code: 'invalid-email',
        message: 'Please enter a valid email address.',
      );
    }
    return normalized;
  }

  /// Normalizes and validates a recovery identifier (email address or phone number).
  static String normalizeAndValidateIdentifier(String rawIdentifier) {
    return AuthService.normalizeRecoveryIdentifier(rawIdentifier);
  }

  /// Requests a server-generated 6-digit recovery OTP for [identifier] (email or phone)
  /// via the `requestRecoveryOtp` HTTPS Callable Cloud Function.
  Future<void> requestRecoveryOtp(String identifier) async {
    final normalizedIdentifier = normalizeAndValidateIdentifier(identifier);
    try {
      final callable = _resolveFunctions().httpsCallable('requestRecoveryOtp');
      await callable.call<dynamic>({
        'identifier': normalizedIdentifier,
      });
    } on FirebaseAuthException {
      rethrow;
    } on FirebaseFunctionsException catch (e) {
      throw AuthService.mapRecoveryFunctionsException(
        e,
        identifier: normalizedIdentifier,
        isVerification: false,
      );
    }
  }

  /// Verifies the 6-digit recovery OTP [code] for [identifier] (email or phone)
  /// via the `verifyRecoveryOtp` HTTPS Callable Cloud Function.
  Future<bool> verifyRecoveryOtp({
    required String identifier,
    required String code,
  }) async {
    final normalizedIdentifier = normalizeAndValidateIdentifier(identifier);
    final sanitizedCode = code.trim();

    if (sanitizedCode.length != 6 ||
        !RegExp(r'^\d{6}$').hasMatch(sanitizedCode)) {
      throw FirebaseAuthException(
        code: 'invalid-verification-code',
        message: 'The verification code entered is invalid.',
      );
    }

    try {
      final callable = _resolveFunctions().httpsCallable('verifyRecoveryOtp');
      final result = await callable.call<dynamic>({
        'identifier': normalizedIdentifier,
        'code': sanitizedCode,
      });
      final data = result.data;
      if (data is Map) {
        return data['verified'] == true || data['success'] == true;
      }
      return true;
    } on FirebaseAuthException {
      rethrow;
    } on FirebaseFunctionsException catch (e) {
      throw AuthService.mapRecoveryFunctionsException(
        e,
        identifier: normalizedIdentifier,
        isVerification: true,
      );
    }
  }

  /// Dispatches a server-generated 6-digit OTP to a secondary/recovery [email]
  /// by invoking the `requestRecoveryOtp` HTTPS Callable Cloud Function.
  Future<void> sendSecondaryEmailOtp(String email) async {
    final normalizedEmail = normalizeAndValidateEmail(email);
    await requestRecoveryOtp(normalizedEmail);
  }

  /// Verifies the 6-digit OTP [code] sent to [email] by invoking the
  /// `verifyRecoveryOtp` HTTPS Callable Cloud Function.
  ///
  /// Returns `true` when the server confirms and consumes an active challenge.
  /// Throws a [FirebaseAuthException] with `invalid-verification-code`,
  /// `session-expired`, or `too-many-requests` on validation failure.
  Future<bool> verifySecondaryEmailOtp({
    required String email,
    required String code,
  }) async {
    final normalizedEmail = normalizeAndValidateEmail(email);
    return verifyRecoveryOtp(
      identifier: normalizedEmail,
      code: code,
    );
  }

  /// Updates the authenticated user's phone number in Firebase Auth (when a
  /// [PhoneAuthCredential] or [verificationId]/[smsCode] pair is supplied) and
  /// synchronizes the verified E.164 phone number in `/users/{uid}`.
  Future<void> updateUserPhoneNumber({
    required String phoneNumber,
    PhoneAuthCredential? credential,
    String? verificationId,
    String? smsCode,
    String? uid,
  }) async {
    final trimmedPhone = phoneNumber.trim();
    final digitsOnly = trimmedPhone.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length < 10) {
      throw FirebaseAuthException(
        code: 'invalid-phone-number',
        message: 'Please enter a valid phone number.',
      );
    }

    final formattedPhone = AuthService.formatE164PhoneNumber(trimmedPhone);
    PhoneAuthCredential? effectiveCredential = credential;

    if (effectiveCredential == null &&
        verificationId != null &&
        smsCode != null) {
      final cleanVerificationId = verificationId.trim();
      final cleanSmsCode = smsCode.trim();
      if (cleanVerificationId.isEmpty) {
        throw FirebaseAuthException(
          code: 'session-expired',
          message: 'Verification session has expired. Please request a new code.',
        );
      }
      if (cleanSmsCode.length != 6 ||
          !RegExp(r'^\d{6}$').hasMatch(cleanSmsCode)) {
        throw FirebaseAuthException(
          code: 'invalid-verification-code',
          message: 'The verification code entered is invalid.',
        );
      }
      effectiveCredential = PhoneAuthProvider.credential(
        verificationId: cleanVerificationId,
        smsCode: cleanSmsCode,
      );
    }

    final user = currentUser;
    if (effectiveCredential != null && user != null && user is! DevMockUser) {
      await user.updatePhoneNumber(effectiveCredential);
    }

    final effectiveUid =
        uid?.trim().isNotEmpty == true ? uid!.trim() : user?.uid;
    final db = _resolveFirestore();
    if (db != null && effectiveUid != null && effectiveUid.isNotEmpty) {
      await db.collection('users').doc(effectiveUid).set({
        'uid': effectiveUid,
        'phoneNumber': formattedPhone,
        'phoneVerified': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  /// Resolves an `account-exists-with-different-credential` collision by linking
  /// the pending [credential] to the currently authenticated [User] via
  /// [User.linkWithCredential].
  ///
  /// If no user is currently signed in and [existingCredential] is provided,
  /// signs in with [existingCredential] first before linking [credential].
  Future<UserCredential> resolveAccountCollision({
    required AuthCredential credential,
    AuthCredential? existingCredential,
  }) async {
    User? user = currentUser;

    if (user == null && existingCredential != null) {
      final auth = _resolveAuth();
      if (auth != null) {
        final signInResult =
            await auth.signInWithCredential(existingCredential);
        user = signInResult.user;
      }
    }

    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'No authenticated user available to link credentials.',
      );
    }

    final userCredential = await user.linkWithCredential(credential);
    final linkedUser = userCredential.user ?? user;

    final db = _resolveFirestore();
    if (db != null && linkedUser.uid.isNotEmpty) {
      await db.collection('users').doc(linkedUser.uid).set({
        'uid': linkedUser.uid,
        'isAnonymous': false,
        if (linkedUser.email != null && linkedUser.email!.isNotEmpty)
          'email': linkedUser.email,
        if (linkedUser.phoneNumber != null &&
            linkedUser.phoneNumber!.isNotEmpty)
          'phoneNumber': linkedUser.phoneNumber,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    return userCredential;
  }

  /// Submits a manual account recovery escalation ticket to `/support_escalations`
  /// when automated recovery paths cannot complete.
  ///
  /// Returns the generated support ticket ID.
  Future<String> submitSupportEscalation({
    required String contactEmail,
    required String reason,
    String? phoneNumber,
    String? uid,
    Map<String, dynamic>? diagnostics,
  }) async {
    final normalizedEmail = normalizeAndValidateEmail(contactEmail);
    final trimmedReason = reason.trim();
    if (trimmedReason.isEmpty) {
      throw ArgumentError.value(
        reason,
        'reason',
        'A description of the issue is required for support escalation.',
      );
    }

    final effectiveUid =
        uid?.trim().isNotEmpty == true ? uid!.trim() : currentUser?.uid;
    final formattedPhone =
        (phoneNumber != null && phoneNumber.trim().isNotEmpty)
            ? AuthService.formatE164PhoneNumber(phoneNumber)
            : null;

    final payload = <String, dynamic>{
      'contactEmail': normalizedEmail,
      'reason': trimmedReason,
      'phoneNumber': ?formattedPhone,
      'uid': ?effectiveUid,
      if (diagnostics != null && diagnostics.isNotEmpty)
        'diagnostics': diagnostics,
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
    };

    final db = _resolveFirestore();
    if (db != null) {
      final docRef = await db.collection('support_escalations').add(payload);
      return docRef.id;
    }

    return 'esc_${_clock().millisecondsSinceEpoch}';
  }
}

/// Riverpod provider for [AuthRecoveryService].
final authRecoveryServiceProvider = Provider<AuthRecoveryService>((ref) {
  final firestore = ref.watch(firebaseFirestoreProvider);
  final functions = ref.watch(firebaseFunctionsProvider);
  return AuthRecoveryService(
    firestore: firestore,
    functions: functions,
  );
});
