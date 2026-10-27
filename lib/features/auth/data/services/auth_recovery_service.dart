import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/app_providers.dart';
import '../../../../services/auth_service.dart';

/// Represents an in-flight secondary email OTP verification challenge.
class SecondaryEmailOtpChallenge {
  final String email;
  final String code;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool verified;
  final int attempts;

  const SecondaryEmailOtpChallenge({
    required this.email,
    required this.code,
    required this.createdAt,
    required this.expiresAt,
    this.verified = false,
    this.attempts = 0,
  });

  bool isExpired([DateTime? now]) => (now ?? DateTime.now()).isAfter(expiresAt);

  SecondaryEmailOtpChallenge copyWith({
    String? email,
    String? code,
    DateTime? createdAt,
    DateTime? expiresAt,
    bool? verified,
    int? attempts,
  }) {
    return SecondaryEmailOtpChallenge(
      email: email ?? this.email,
      code: code ?? this.code,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      verified: verified ?? this.verified,
      attempts: attempts ?? this.attempts,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'code': code,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'verified': verified,
      'attempts': attempts,
    };
  }

  factory SecondaryEmailOtpChallenge.fromMap(Map<String, dynamic> map) {
    final createdRaw = map['createdAt'];
    final expiresRaw = map['expiresAt'];
    final now = DateTime.now();
    return SecondaryEmailOtpChallenge(
      email: (map['email'] as String?) ?? '',
      code: (map['code'] as String?) ?? '',
      createdAt: createdRaw is Timestamp ? createdRaw.toDate() : now,
      expiresAt: expiresRaw is Timestamp
          ? expiresRaw.toDate()
          : now.add(const Duration(minutes: 10)),
      verified: (map['verified'] as bool?) ?? false,
      attempts: (map['attempts'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Service responsible for login troubleshooting, secondary email OTP recovery,
/// phone number updates, credential collision resolution, and support escalation.
class AuthRecoveryService {
  static const int maxOtpAttempts = 5;
  static const Duration otpExpiration = Duration(minutes: 10);

  static final RegExp _emailPattern = RegExp(
    r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$',
  );

  final FirebaseAuth? _injectedAuth;
  final FirebaseFirestore? _injectedFirestore;
  final User? currentUserOverride;
  final String Function()? otpGenerator;
  final DateTime Function() _clock;

  final Map<String, SecondaryEmailOtpChallenge> _memoryOtpStore = {};

  AuthRecoveryService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    this.currentUserOverride,
    this.otpGenerator,
    DateTime Function()? clock,
  })  : _injectedAuth = auth,
        _injectedFirestore = firestore,
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

  String _generateSixDigitOtp() {
    if (otpGenerator != null) {
      return otpGenerator!();
    }
    final random = Random.secure();
    final value = 100000 + random.nextInt(900000);
    return value.toString();
  }

  /// Returns the latest generated OTP for [email] in local memory (useful for test inspection).
  String? peekGeneratedOtp(String email) {
    return _memoryOtpStore[email.trim().toLowerCase()]?.code;
  }

  /// Dispatches a 6-digit OTP to a secondary/recovery email address and records
  /// the verification challenge in Firestore (`auth_recovery_otps`).
  Future<void> sendSecondaryEmailOtp(String email) async {
    final normalizedEmail = normalizeAndValidateEmail(email);
    final now = _clock();
    final code = _generateSixDigitOtp();

    final challenge = SecondaryEmailOtpChallenge(
      email: normalizedEmail,
      code: code,
      createdAt: now,
      expiresAt: now.add(otpExpiration),
      verified: false,
      attempts: 0,
    );

    _memoryOtpStore[normalizedEmail] = challenge;

    final db = _resolveFirestore();
    if (db != null) {
      try {
        await db
            .collection('auth_recovery_otps')
            .doc(normalizedEmail)
            .set(challenge.toMap());
      } on FirebaseAuthException {
        rethrow;
      } on FirebaseException catch (e) {
        if (e.code == 'resource-exhausted' || e.code == 'too-many-requests') {
          throw FirebaseAuthException(
            code: 'too-many-requests',
            message: 'Too many OTP requests. Please wait before trying again.',
          );
        }
        rethrow;
      }
    }
  }

  /// Verifies the 6-digit OTP [code] sent to [email].
  ///
  /// Returns `true` when the code matches an active, unexpired challenge.
  /// Throws a [FirebaseAuthException] with `invalid-verification-code`,
  /// `session-expired`, or `too-many-requests` on validation failure.
  Future<bool> verifySecondaryEmailOtp({
    required String email,
    required String code,
  }) async {
    final normalizedEmail = normalizeAndValidateEmail(email);
    final sanitizedCode = code.trim();

    if (sanitizedCode.length != 6 || !RegExp(r'^\d{6}$').hasMatch(sanitizedCode)) {
      throw FirebaseAuthException(
        code: 'invalid-verification-code',
        message: 'The verification code entered is invalid.',
      );
    }

    final db = _resolveFirestore();
    SecondaryEmailOtpChallenge? challenge = _memoryOtpStore[normalizedEmail];

    if (db != null) {
      try {
        final doc = await db
            .collection('auth_recovery_otps')
            .doc(normalizedEmail)
            .get();
        if (doc.exists && doc.data() != null) {
          challenge = SecondaryEmailOtpChallenge.fromMap(doc.data()!);
        }
      } on FirebaseAuthException {
        rethrow;
      }
    }

    if (challenge == null) {
      throw FirebaseAuthException(
        code: 'session-expired',
        message: 'No active verification code found. Please request a new code.',
      );
    }

    if (challenge.attempts >= maxOtpAttempts) {
      throw FirebaseAuthException(
        code: 'too-many-requests',
        message: 'Too many failed verification attempts. Please try again later.',
      );
    }

    if (challenge.isExpired(_clock())) {
      throw FirebaseAuthException(
        code: 'session-expired',
        message: 'The verification code has expired. Please request a new code.',
      );
    }

    if (challenge.code != sanitizedCode) {
      final updatedChallenge = challenge.copyWith(
        attempts: challenge.attempts + 1,
      );
      _memoryOtpStore[normalizedEmail] = updatedChallenge;
      if (db != null) {
        await db
            .collection('auth_recovery_otps')
            .doc(normalizedEmail)
            .set(updatedChallenge.toMap(), SetOptions(merge: true));
      }
      if (updatedChallenge.attempts >= maxOtpAttempts) {
        throw FirebaseAuthException(
          code: 'too-many-requests',
          message: 'Too many failed verification attempts. Please try again later.',
        );
      }
      throw FirebaseAuthException(
        code: 'invalid-verification-code',
        message: 'The verification code entered is invalid.',
      );
    }

    final verifiedChallenge = challenge.copyWith(verified: true);
    _memoryOtpStore[normalizedEmail] = verifiedChallenge;

    if (db != null) {
      await db
          .collection('auth_recovery_otps')
          .doc(normalizedEmail)
          .set(verifiedChallenge.toMap(), SetOptions(merge: true));
    }

    return true;
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
      if (cleanSmsCode.length != 6 || !RegExp(r'^\d{6}$').hasMatch(cleanSmsCode)) {
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

    final effectiveUid = uid?.trim().isNotEmpty == true ? uid!.trim() : user?.uid;
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
        final signInResult = await auth.signInWithCredential(existingCredential);
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
        if (linkedUser.phoneNumber != null && linkedUser.phoneNumber!.isNotEmpty)
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
  return AuthRecoveryService(firestore: firestore);
});
