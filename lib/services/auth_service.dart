import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../models/user.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Sign up with Email and Password
  Future<UserCredential> signUpWithEmailAndPassword(String email, String password) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      if (userCredential.user != null) {
        await syncUserToFirestore(userCredential.user!);
      }
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseAuthException(e);
    } catch (e) {
      throw Exception('Failed to create account: ${e.toString()}');
    }
  }

  // Sign in with Email and Password
  Future<UserCredential> signInWithEmailAndPassword(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      if (userCredential.user != null) {
        await syncUserToFirestore(userCredential.user!);
      }
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseAuthException(e);
    } catch (e) {
      throw Exception('Failed to sign in: ${e.toString()}');
    }
  }

  // Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();

      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        // The user canceled the sign-in
        return null;
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create a new credential
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Once signed in, return the UserCredential
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      if (userCredential.user != null) {
        await syncUserToFirestore(userCredential.user!);
      }
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseAuthException(e);
    } catch (e) {
      throw Exception('Google sign-in failed: ${e.toString()}');
    }
  }

  // Sign in with Apple
  Future<UserCredential?> signInWithApple() async {
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

      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      if (userCredential.user != null) {
        await syncUserToFirestore(userCredential.user!);
      }
      return userCredential;
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return null; // User cancelled
      }
      throw Exception('Apple authorization failed: ${e.message}');
    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseAuthException(e);
    } catch (e) {
      throw Exception('Apple sign-in failed: ${e.toString()}');
    }
  }

  // Sign in Anonymously (Guest Mode)
  Future<UserCredential> signInAnonymously() async {
    try {
      final userCredential = await _auth.signInAnonymously();
      if (userCredential.user != null) {
        await syncUserToFirestore(userCredential.user!);
      }
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseAuthException(e);
    } catch (e) {
      throw Exception('Guest sign in failed: ${e.toString()}');
    }
  }

  // Link with Google
  Future<UserCredential?> linkWithGoogle() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception("No authenticated user to link account to.");

      final GoogleSignIn googleSignIn = GoogleSignIn();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await user.linkWithCredential(credential);
      await _firestore.collection('users').doc(user.uid).set({'isAnonymous': false}, SetOptions(merge: true));
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseAuthException(e);
    } catch (e) {
      throw Exception('Failed to link Google account: ${e.toString()}');
    }
  }

  // Link with Apple
  Future<UserCredential?> linkWithApple() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception("No authenticated user to link account to.");

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

      final UserCredential userCredential = await user.linkWithCredential(credential);
      await _firestore.collection('users').doc(user.uid).set({'isAnonymous': false}, SetOptions(merge: true));
      return userCredential;
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return null;
      }
      throw Exception('Apple authorization failed: ${e.message}');
    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseAuthException(e);
    } catch (e) {
      throw Exception('Failed to link Apple account: ${e.toString()}');
    }
  }

  // Start MFA Enrollment (Sends SMS Code)
  Future<String> enrollMfaStart(String phoneNumber) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception("User must be logged in to enroll in MFA");

      final multiFactorSession = await user.multiFactor.getSession();
      String verificationIdResult = '';

      await _auth.verifyPhoneNumber(
        multiFactorSession: multiFactorSession,
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) {},
        verificationFailed: (FirebaseAuthException e) {
          throw _handleFirebaseAuthException(e);
        },
        codeSent: (String verificationId, int? resendToken) {
          verificationIdResult = verificationId;
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );

      return verificationIdResult;
    } catch (e) {
      throw Exception('Failed to send verification SMS: ${e.toString()}');
    }
  }

  // Verify MFA Code (Completes Enrollment)
  Future<void> enrollMfaComplete(String verificationId, String smsCode, String displayName) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception("User must be logged in to complete MFA enrollment");

      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      final assertion = PhoneMultiFactorGenerator.getAssertion(credential);
      await user.multiFactor.enroll(assertion, displayName: displayName);
    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseAuthException(e);
    } catch (e) {
      throw Exception('Failed to complete verification: ${e.toString()}');
    }
  }

  // Signs out the current user
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      await GoogleSignIn().signOut();
    } catch (_) {}
  }

  // Synchronize Firebase Auth user with Firestore users collection
  Future<void> syncUserToFirestore(User authUser) async {
    try {
      final userRef = _firestore.collection('users').doc(authUser.uid);
      final docSnapshot = await userRef.get();

      if (!docSnapshot.exists) {
        final newUser = UserProfile(
          uid: authUser.uid,
          email: authUser.email ?? '',
          displayName: authUser.displayName,
          createdAt: DateTime.now(),
          isAnonymous: authUser.isAnonymous,
        );

        await userRef.set(newUser.toJson());
      }
    } catch (_) {
      // Allow auth flow to proceed even if offline or Firestore rule is syncing
    }
  }

  // Helper to format clean, user-friendly Firebase Auth error messages
  Exception _handleFirebaseAuthException(FirebaseAuthException e) {
    switch (e.code) {
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
        return Exception('Anonymous authentication is disabled in the Firebase Console. Enable "Anonymous" under Authentication > Sign-in method in Firebase Console.');
      case 'weak-password':
        return Exception('The password provided is too weak.');
      case 'credential-already-in-use':
        return Exception('This account is already linked to another user.');
      case 'network-request-failed':
        return Exception('Network error. Please check your internet connection.');
      default:
        return Exception(e.message ?? 'Authentication error (${e.code}).');
    }
  }

  // Get stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();
}
