import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'auth_exceptions.dart';

/// Handles credential re-authentication flows (Password, Google, Apple, Phone).
class AuthReauthenticationHelper {
  const AuthReauthenticationHelper._();

  static Future<UserCredential?> reauthenticateWithCredential({
    required FirebaseAuth auth,
    required AuthCredential credential,
  }) async {
    final user = auth.currentUser;
    if (user == null) {
      throw Exception('No authenticated user found.');
    }
    try {
      return await user.reauthenticateWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw mapFirebaseAuthException(e);
    } catch (e) {
      throw Exception('Failed to re-authenticate: ${e.toString()}');
    }
  }

  static Future<UserCredential?> reauthenticateWithPassword({
    required FirebaseAuth auth,
    required String password,
  }) async {
    final user = auth.currentUser;
    final email = user?.email;
    if (user == null || email == null || email.isEmpty) {
      throw Exception('No authenticated user with an email address found.');
    }
    try {
      final credential = EmailAuthProvider.credential(
        email: email.trim(),
        password: password,
      );
      return await user.reauthenticateWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw mapFirebaseAuthException(e, 'email');
    } catch (e) {
      throw Exception('Failed to re-authenticate: ${e.toString()}');
    }
  }

  static Future<UserCredential?> reauthenticateWithGoogle({
    required FirebaseAuth auth,
  }) async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        throw Exception('Google sign-in was cancelled.');
      }
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final user = auth.currentUser;
      if (user != null) {
        return await user.reauthenticateWithCredential(credential);
      }
      return null;
    } on FirebaseAuthException catch (e) {
      throw mapFirebaseAuthException(e, 'email');
    } catch (e) {
      throw Exception('Google re-authentication failed: ${e.toString()}');
    }
  }

  static Future<UserCredential?> reauthenticateWithApple({
    required FirebaseAuth auth,
  }) async {
    try {
      final AuthorizationCredentialAppleID appleCredential =
          await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      final AuthCredential credential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );
      final user = auth.currentUser;
      if (user != null) {
        return await user.reauthenticateWithCredential(credential);
      }
      return null;
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        throw Exception('Apple sign-in was cancelled.');
      }
      throw Exception('Apple authorization failed: ${e.message}');
    } on FirebaseAuthException catch (e) {
      throw mapFirebaseAuthException(e, 'email');
    } catch (e) {
      throw Exception('Apple re-authentication failed: ${e.toString()}');
    }
  }

  static Future<UserCredential?> reauthenticateWithPhoneCredential({
    required FirebaseAuth auth,
    required String verificationId,
    required String? fallbackVerificationId,
    required String smsCode,
  }) async {
    final user = auth.currentUser;
    if (user == null) throw Exception('No authenticated user found.');
    final effectiveVerificationId = verificationId.trim().isNotEmpty
        ? verificationId.trim()
        : (fallbackVerificationId ?? '');
    if (effectiveVerificationId.isEmpty) {
      throw mapFirebaseAuthException(
        FirebaseAuthException(code: 'session-expired'),
        'phone',
      );
    }
    try {
      final PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: effectiveVerificationId,
        smsCode: smsCode.trim(),
      );
      return await user.reauthenticateWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw mapFirebaseAuthException(e, 'phone');
    } catch (e) {
      throw Exception('Phone re-authentication failed: ${e.toString()}');
    }
  }
}
