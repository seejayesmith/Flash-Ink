import 'package:firebase_auth/firebase_auth.dart';

/// Stateless formatting, validation, and provider inspection helpers for authentication.
class AuthFormatters {
  const AuthFormatters._();

  static final RegExp recoveryEmailPattern = RegExp(
    r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$',
  );

  /// Formats a raw phone input into E.164 format (e.g., `+15550192834`).
  static String formatE164PhoneNumber(String rawPhone) {
    final trimmed = rawPhone.trim();
    final digitsOnly = trimmed.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.isEmpty) return trimmed;
    if (trimmed.startsWith('+')) {
      return '+$digitsOnly';
    }
    if (digitsOnly.length == 11 && digitsOnly.startsWith('1')) {
      return '+$digitsOnly';
    }
    return '+1$digitsOnly';
  }

  /// Formats a raw phone input or E.164 string into standard 10-digit US display format `(555) 000-0000`.
  static String formatDisplayPhoneNumber(String? rawPhone) {
    if (rawPhone == null || rawPhone.trim().isEmpty) return '';
    final trimmed = rawPhone.trim();
    if (trimmed.startsWith('+') && !trimmed.startsWith('+1')) {
      return trimmed;
    }
    final digitsOnly = rawPhone.replaceAll(RegExp(r'\D'), '');
    final clean = digitsOnly.length == 11 && digitsOnly.startsWith('1')
        ? digitsOnly.substring(1)
        : digitsOnly;
    if (clean.length == 10) {
      return '(${clean.substring(0, 3)}) ${clean.substring(3, 6)}-${clean.substring(6)}';
    }
    if (clean.length > 6) {
      return '(${clean.substring(0, 3)}) ${clean.substring(3, 6)}-${clean.substring(6)}';
    }
    if (clean.length > 3) {
      return '(${clean.substring(0, 3)}) ${clean.substring(3)}';
    }
    if (clean.isNotEmpty) {
      return '($clean';
    }
    return rawPhone;
  }

  /// Normalizes and validates a recovery identifier (email address or phone number).
  static String normalizeRecoveryIdentifier(String rawIdentifier) {
    final trimmed = rawIdentifier.trim();
    if (trimmed.isEmpty) {
      throw FirebaseAuthException(
        code: 'invalid-email',
        message: 'Please enter a valid email address or phone number.',
      );
    }

    if (trimmed.contains('@')) {
      final normalizedEmail = trimmed.toLowerCase();
      if (!recoveryEmailPattern.hasMatch(normalizedEmail)) {
        throw FirebaseAuthException(
          code: 'invalid-email',
          message: 'Please enter a valid email address.',
        );
      }
      return normalizedEmail;
    }

    final digitsOnly = trimmed.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length < 10 || digitsOnly.length > 15) {
      throw FirebaseAuthException(
        code: 'invalid-phone-number',
        message: 'Please enter a valid phone number.',
      );
    }
    return formatE164PhoneNumber(trimmed);
  }

  static bool isGoogleAuthUser(User? user) {
    if (user == null) return false;
    try {
      final providers = user.providerData;
      for (final info in providers) {
        if (info.providerId == 'google.com') return true;
      }
    } catch (_) {}
    try {
      final email = user.email?.toLowerCase() ?? '';
      if (email.endsWith('@gmail.com') || email.endsWith('@googlemail.com')) {
        return true;
      }
    } catch (_) {}
    return false;
  }

  static bool isAppleAuthUser(User? user) {
    if (user == null) return false;
    try {
      final providers = user.providerData;
      for (final info in providers) {
        if (info.providerId == 'apple.com') return true;
      }
    } catch (_) {}
    return false;
  }

  static bool isOAuthUser(User? user) =>
      isGoogleAuthUser(user) || isAppleAuthUser(user);

  static bool hasVerifiedEmail(
    User? user, [
    Map<String, dynamic>? firestoreData,
  ]) {
    if (firestoreData != null && firestoreData['emailVerified'] == true) {
      final storedEmail = firestoreData['email'] as String?;
      if (storedEmail != null && storedEmail.trim().isNotEmpty) return true;
    }
    try {
      if (user != null &&
          user.email != null &&
          user.email!.trim().isNotEmpty &&
          user.emailVerified) {
        return true;
      }
    } catch (_) {}
    return false;
  }

  static bool hasVerifiedPhone(
    User? user, [
    Map<String, dynamic>? firestoreData,
  ]) {
    if (firestoreData != null && firestoreData['phoneVerified'] == true) {
      final phone = firestoreData['phoneNumber'] as String?;
      if (phone != null && phone.trim().isNotEmpty) return true;
    }
    try {
      if (user != null &&
          user.phoneNumber != null &&
          user.phoneNumber!.trim().isNotEmpty) {
        return true;
      }
    } catch (_) {}
    return false;
  }
}
