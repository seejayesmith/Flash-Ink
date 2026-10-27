import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../config/dev_config.dart';
import '../models/artist_dashboard_data.dart';
import '../models/user.dart';
import 'booking_sync_service.dart';

/// Minimal mock user for development and testing bypasses.
/// Implements [User] safely via [noSuchMethod] to prevent null-assertion errors in downstream widgets.
class DevMockUser implements User {
  @override
  final String uid;
  @override
  final String? displayName;
  @override
  final String? email;
  @override
  final bool isAnonymous;
  @override
  final String? phoneNumber;
  final String? role;
  @override
  final bool emailVerified;
  @override
  String? photoURL;

  DevMockUser({
    this.uid = 'dev_tester_uid',
    this.displayName = 'Dev Tester',
    this.email = 'dev@flash.ink',
    this.phoneNumber,
    this.isAnonymous = false,
    this.emailVerified = true,
    this.role,
    this.photoURL,
  });

  @override
  Future<void> reload() async {}

  @override
  Future<void> updatePhotoURL(String? photoURL) async {
    this.photoURL = photoURL;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Exception thrown when a sensitive operation requires recent authentication.
class RequiresRecentLoginException implements Exception {
  final String message;
  const RequiresRecentLoginException([
    this.message = 'This action requires recent authentication. Please log in again before deleting your account.',
  ]);

  @override
  String toString() => 'Exception: $message';
}

class AuthService {
  final FirebaseAuth? _authInstance;
  final FirebaseFirestore? _firestoreInstance;
  final User? _mockUser;

  String? _verificationId;
  int? _resendToken;

  /// The most recent phone auth verification ID retained in state.
  String? get verificationId => _verificationId;

  /// The most recent phone auth resend token retained in state.
  int? get resendToken => _resendToken;

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

  static DevMockUser? devMockUser;

  static final StreamController<User?> _sessionChangeController =
      StreamController<User?>.broadcast();
  static int _sessionEpoch = 0;
  static final StreamController<int> _sessionEpochController =
      StreamController<int>.broadcast();

  /// Monotonically increasing epoch incremented on every sign-out / session switch.
  static int get sessionEpoch => _sessionEpoch;

  /// Broadcast stream firing whenever session state is invalidated or switched.
  static Stream<int> get sessionEpochChanges => _sessionEpochController.stream;

  /// Broadcasts an explicit auth user transition to active [authStateChanges] subscribers.
  static void notifyAuthSessionChanged(User? user) {
    if (!_sessionChangeController.isClosed) {
      _sessionChangeController.add(user);
    }
  }

  static DevMockUser createDevMockClient({FirebaseFirestore? firestore}) {
    final user = DevMockUser(
      uid: 'dev_client_uid',
      displayName: 'Alex Rivers',
      email: 'alex.rivers@example.com',
      phoneNumber: '+15552345678',
      isAnonymous: false,
      role: 'client',
    );
    devMockUser = user;
    _sessionEpoch++;
    _sessionEpochController.add(_sessionEpoch);
    notifyAuthSessionChanged(user);
    _syncMockToFirestore(user, role: 'client', firestore: firestore);
    return user;
  }

  static DevMockUser createDevMockArtist({FirebaseFirestore? firestore}) {
    final user = DevMockUser(
      uid: 'dev_artist_uid',
      displayName: 'OddMaree',
      email: 'oddmaree@flash.ink',
      phoneNumber: '+15559876543',
      isAnonymous: false,
      role: 'artist',
    );
    devMockUser = user;
    _sessionEpoch++;
    _sessionEpochController.add(_sessionEpoch);
    notifyAuthSessionChanged(user);
    _syncMockToFirestore(user, role: 'artist', firestore: firestore);
    return user;
  }

  static void clearDevMockUser() {
    devMockUser = null;
    _sessionEpoch++;
    _sessionEpochController.add(_sessionEpoch);
    notifyAuthSessionChanged(null);
  }

  static Future<void> _syncMockToFirestore(
    DevMockUser mockUser, {
    required String role,
    FirebaseFirestore? firestore,
  }) async {
    try {
      final db = firestore ?? FirebaseFirestore.instance;
      await db.collection('users').doc(mockUser.uid).set({
        'uid': mockUser.uid,
        'email': mockUser.email,
        'displayName': mockUser.displayName,
        'phoneNumber': mockUser.phoneNumber,
        if (role == 'client') 'role': 'client',
        'onboardingRole': role,
        'profileCompleted': true,
        'isAnonymous': false,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).timeout(const Duration(milliseconds: 500));

      if (role == 'artist') {
        await db.collection('artists').doc(mockUser.uid).set({
          'id': mockUser.uid,
          'name': mockUser.displayName,
          'instagramHandle': '@oddmaree',
          'location': 'Los Angeles, CA',
          'latitude': 34.05,
          'longitude': -118.24,
          'isPrivateStudio': true,
          'profileCompleted': true,
          'minDeposit': 50,
          'tags': ['Traditional', 'Fine-line'],
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)).timeout(const Duration(milliseconds: 500));

        await db
            .collection('artists')
            .doc(mockUser.uid)
            .collection('private')
            .doc('settings')
            .set({
          'email': mockUser.email,
          'phoneNumber': mockUser.phoneNumber,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)).timeout(const Duration(milliseconds: 500));
      }
    } catch (_) {
      // Best-effort in offline/sandbox test mode
    }
  }

  AuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    this._mockUser,
  })  : _authInstance = auth,
        _firestoreInstance = firestore;

  FirebaseAuth get _auth => _authInstance ?? FirebaseAuth.instance;
  FirebaseFirestore get _firestore => _firestoreInstance ?? FirebaseFirestore.instance;

  User? get currentUser {
    if (_mockUser != null) return _mockUser;
    if (kEnableDevBypass && devMockUser != null) return devMockUser;
    try {
      return _auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  bool get isGuest {
    try {
      final user = currentUser;
      return user == null || user.isAnonymous;
    } catch (_) {
      return true;
    }
  }

  /// Resolves the user's verified role from server-minted Firebase Auth Custom Claims (`token.claims['role']`).
  ///
  /// Clients cannot self-assign `'artist'` via Firestore writes; only a server-signed ID token
  /// with `claims['role'] == 'artist'` (or an explicit `DevMockUser` in dev bypass mode) grants artist access.
  Future<String> getVerifiedRole({
    User? user,
    bool forceRefresh = false,
  }) async {
    final targetUser = user ?? currentUser;
    if (targetUser == null) {
      return 'client';
    }
    try {
      if (targetUser.isAnonymous) {
        return 'client';
      }
    } catch (_) {}
    if (kEnableDevBypass && targetUser is DevMockUser) {
      return targetUser.role ?? 'client';
    }
    try {
      final tokenResult = await targetUser.getIdTokenResult(forceRefresh);
      final claimRole = tokenResult.claims?['role'];
      if (claimRole is String && claimRole.isNotEmpty) {
        return claimRole;
      }
    } catch (_) {
      // Fallback safely to 'client' if token refresh is unavailable in headless/offline tests
    }
    return 'client';
  }

  /// Clears all cached in-memory repository state to prevent cross-role data leakage on sign-out.
  static void invalidateSessionState() {
    devMockUser = null;
    ArtistDashboardRepository.resetMockData();
    BookingSyncService.resetSyncState();
    _sessionEpoch++;
    if (!_sessionEpochController.isClosed) {
      _sessionEpochController.add(_sessionEpoch);
    }
    notifyAuthSessionChanged(null);
  }

  // Sign up with Email and Password
  Future<UserCredential> signUpWithEmailAndPassword(String email, String password, {String? role}) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      if (userCredential.user != null) {
        await syncUserToFirestore(userCredential.user!, role: role);
        if (!userCredential.user!.emailVerified) {
          await userCredential.user!.sendEmailVerification();
        }
      }
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseAuthException(e, 'email');
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
      throw _handleFirebaseAuthException(e, 'email');
    } catch (e) {
      throw Exception('Failed to sign in: ${e.toString()}');
    }
  }

  // Resend Email Verification Link
  Future<void> sendEmailVerification() async {
    try {
      final user = currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
      }
    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseAuthException(e, 'email');
    } catch (e) {
      throw Exception('Failed to send verification email: ${e.toString()}');
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
      throw _handleFirebaseAuthException(e, 'email');
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
      throw _handleFirebaseAuthException(e, 'email');
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
      throw _handleFirebaseAuthException(e, 'anonymous');
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
      if (e.code == 'credential-already-in-use') {
        return await signInWithGoogle();
      }
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
      if (e.code == 'credential-already-in-use') {
        return await signInWithApple();
      }
      throw _handleFirebaseAuthException(e);
    } catch (e) {
      throw Exception('Failed to link Apple account: ${e.toString()}');
    }
  }

  // Link or upgrade current anonymous user with Email and Password
  Future<UserCredential> linkWithEmailAndPassword(String email, String password) async {
    try {
      final user = currentUser;
      if (user == null) {
        return await signUpWithEmailAndPassword(email, password);
      }
      if (!user.isAnonymous) {
        return await signInWithEmailAndPassword(email, password);
      }

      final credential = EmailAuthProvider.credential(
        email: email.trim(),
        password: password,
      );

      final userCredential = await user.linkWithCredential(credential);
      await _firestore
          .collection('users')
          .doc(user.uid)
          .set({'isAnonymous': false, 'email': email.trim()}, SetOptions(merge: true));
      return userCredential;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'credential-already-in-use' || e.code == 'email-already-in-use') {
        return await signInWithEmailAndPassword(email, password);
      }
      throw _handleFirebaseAuthException(e);
    } catch (e) {
      throw Exception('Failed to link email account: ${e.toString()}');
    }
  }

  // Verify Phone Number (Sends SMS Code)
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(Exception error) onVerificationFailed,
    void Function(PhoneAuthCredential credential)? onVerificationCompleted,
    void Function(String verificationId)? onCodeAutoRetrievalTimeout,
    int? forceResendingToken,
  }) async {
    final formattedPhoneNumber = formatE164PhoneNumber(phoneNumber);
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: formattedPhoneNumber,
        forceResendingToken: forceResendingToken ?? _resendToken,
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            await signInWithPhoneAuthCredential(credential);
          } catch (_) {}
          if (onVerificationCompleted != null) {
            onVerificationCompleted(credential);
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          onVerificationFailed(_handleFirebaseAuthException(e, 'phone'));
        },
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
          _resendToken = resendToken;
          onCodeSent(verificationId, resendToken);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
          if (onCodeAutoRetrievalTimeout != null) {
            onCodeAutoRetrievalTimeout(verificationId);
          }
        },
      );
    } on FirebaseAuthException catch (e) {
      onVerificationFailed(_handleFirebaseAuthException(e, 'phone'));
    } catch (e) {
      onVerificationFailed(Exception('Failed to send verification SMS: ${e.toString()}'));
    }
  }

  // Sign in directly with a PhoneAuthCredential (used for auto-retrieval / instant verification)
  Future<UserCredential> signInWithPhoneAuthCredential(
    PhoneAuthCredential credential,
  ) async {
    try {
      final userCredential = await _auth.signInWithCredential(credential);
      if (userCredential.user != null) {
        await syncUserToFirestore(userCredential.user!);
      }
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseAuthException(e, 'phone');
    } catch (e) {
      throw Exception('Failed to sign in: ${e.toString()}');
    }
  }

  // Sign in with Phone Credential (verificationId + SMS code entered by user)
  Future<UserCredential> signInWithPhoneCredential({
    required String verificationId,
    required String smsCode,
  }) async {
    final effectiveVerificationId =
        verificationId.trim().isNotEmpty ? verificationId.trim() : (_verificationId ?? '');
    if (effectiveVerificationId.isEmpty) {
      throw _handleFirebaseAuthException(
        FirebaseAuthException(code: 'session-expired'),
        'phone',
      );
    }
    try {
      final PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: effectiveVerificationId,
        smsCode: smsCode.trim(),
      );
      return await signInWithPhoneAuthCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseAuthException(e, 'phone');
    } catch (e) {
      throw Exception('Failed to sign in: ${e.toString()}');
    }
  }

  // Update phone verification status in Firestore
  Future<void> updatePhoneVerificationStatus({
    required String uid,
    required String phoneNumber,
  }) async {
    try {
      await _firestore.collection('users').doc(uid).set({
        'uid': uid,
        'phoneVerified': true,
        'phoneNumber': phoneNumber,
      }, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Failed to update phone verification status: ${e.toString()}');
    }
  }

  // Returns a list of provider IDs linked to the current user (e.g. 'password', 'phone', 'google.com', 'apple.com').
  List<String> get currentUserProviders {
    final user = currentUser;
    if (user == null) return const [];
    final providers = user.providerData.map((p) => p.providerId).toList();
    if (providers.isEmpty) {
      if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty) {
        return ['phone'];
      }
      if (user.email != null && user.email!.isNotEmpty) {
        return ['password'];
      }
    }
    return providers;
  }

  // Re-authenticate with any given AuthCredential
  Future<UserCredential?> reauthenticateWithCredential(AuthCredential credential) async {
    if (devMockUser != null || _mockUser != null) {
      return null;
    }
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No authenticated user found.');
    }
    try {
      return await user.reauthenticateWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseAuthException(e);
    } catch (e) {
      throw Exception('Failed to re-authenticate: ${e.toString()}');
    }
  }

  // Re-authenticate with Email and Password
  Future<UserCredential?> reauthenticateWithPassword(String password) async {
    if (devMockUser != null || _mockUser != null) {
      return null;
    }
    final user = _auth.currentUser;
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
      throw _handleFirebaseAuthException(e, 'email');
    } catch (e) {
      throw Exception('Failed to re-authenticate: ${e.toString()}');
    }
  }

  // Re-authenticate with Google
  Future<UserCredential?> reauthenticateWithGoogle() async {
    if (devMockUser != null || _mockUser != null) {
      return null;
    }
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        throw Exception('Google sign-in was cancelled.');
      }
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final user = _auth.currentUser;
      if (user != null) {
        return await user.reauthenticateWithCredential(credential);
      }
      return null;
    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseAuthException(e, 'email');
    } catch (e) {
      throw Exception('Google re-authentication failed: ${e.toString()}');
    }
  }

  // Re-authenticate with Apple
  Future<UserCredential?> reauthenticateWithApple() async {
    if (devMockUser != null || _mockUser != null) {
      return null;
    }
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
      final user = _auth.currentUser;
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
      throw _handleFirebaseAuthException(e, 'email');
    } catch (e) {
      throw Exception('Apple re-authentication failed: ${e.toString()}');
    }
  }

  // Send verification code to current user's phone for re-authentication
  Future<void> sendPhoneReauthCode({
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(Exception error) onVerificationFailed,
    void Function(PhoneAuthCredential credential)? onVerificationCompleted,
  }) async {
    if (devMockUser != null || _mockUser != null) {
      _verificationId = 'mock_reauth_verification_id';
      onCodeSent('mock_reauth_verification_id', null);
      return;
    }
    final user = _auth.currentUser;
    final phoneNumber = user?.phoneNumber;
    if (phoneNumber == null || phoneNumber.isEmpty) {
      onVerificationFailed(Exception('No phone number associated with this account.'));
      return;
    }
    await verifyPhoneNumber(
      phoneNumber: phoneNumber,
      onCodeSent: onCodeSent,
      onVerificationFailed: onVerificationFailed,
      onVerificationCompleted: onVerificationCompleted,
    );
  }

  // Re-authenticate with Phone Credential (verificationId + SMS code)
  Future<UserCredential?> reauthenticateWithPhoneCredential({
    required String verificationId,
    required String smsCode,
  }) async {
    if (devMockUser != null || _mockUser != null) {
      return null;
    }
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user found.');
    final effectiveVerificationId =
        verificationId.trim().isNotEmpty ? verificationId.trim() : (_verificationId ?? '');
    if (effectiveVerificationId.isEmpty) {
      throw _handleFirebaseAuthException(
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
      throw _handleFirebaseAuthException(e, 'phone');
    } catch (e) {
      throw Exception('Phone re-authentication failed: ${e.toString()}');
    }
  }

  // Signs out the current user and clears all in-memory role/session state
  Future<void> signOut() async {
    _verificationId = null;
    _resendToken = null;
    invalidateSessionState();
    try {
      await _auth.signOut();
      await GoogleSignIn().signOut();
    } catch (_) {}
  }

  // Delete the currently authenticated user and their data
  Future<void> deleteAccount() async {
    if (devMockUser != null) {
      invalidateSessionState();
      return;
    }
    if (_mockUser != null) {
      invalidateSessionState();
      return;
    }
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      
      final uid = user.uid;

      // 1. Delete user documents
      try {
        await _firestore.collection('users').doc(uid).delete();
        await _firestore
            .collection('artists')
            .doc(uid)
            .collection('private')
            .doc('settings')
            .delete();
        await _firestore.collection('artists').doc(uid).delete();
      } catch (_) {}

      // 2. Delete storage files if they exist (ignore errors if missing)
      try {
        await FirebaseStorage.instance.ref().child('user_profiles/$uid.jpg').delete();
      } catch (_) {}
      try {
        await FirebaseStorage.instance.ref().child('artist_profiles/$uid.jpg').delete();
      } catch (_) {}

      // 3. Delete the Auth account
      try {
        await user.delete();
        invalidateSessionState();
      } on FirebaseAuthException catch (e) {
        if (e.code == 'user-not-found') {
          // User is already deleted on the backend; clear local session
          await signOut();
          return;
        }
        rethrow;
      }
    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseAuthException(e);
    } catch (e) {
      throw Exception('Failed to delete account: ${e.toString()}');
    }
  }

  // Synchronize Firebase Auth user with Firestore users collection.
  // Never self-assigns 'artist' role from client code; artist role is granted
  // exclusively by the server-side `completeArtistOnboarding` Cloud Function.
  Future<void> syncUserToFirestore(User authUser, {String? role}) async {
    try {
      final userRef = _firestore.collection('users').doc(authUser.uid);
      final docSnapshot = await userRef.get();
      final safeClientRole = role == 'artist' ? null : (role ?? 'client');

      if (!docSnapshot.exists) {
        final newUser = UserProfile(
          uid: authUser.uid,
          email: authUser.email ?? '',
          displayName: authUser.displayName,
          createdAt: DateTime.now(),
          role: safeClientRole,
          isAnonymous: authUser.isAnonymous,
        );

        await userRef.set(newUser.toJson());
      } else if (safeClientRole != null) {
        final data = docSnapshot.data();
        if (data == null || data['role'] == null) {
          await userRef.set({
            'uid': authUser.uid,
            'role': safeClientRole,
          }, SetOptions(merge: true));
        }
      }
    } catch (_) {
      // Allow auth flow to proceed even if offline or Firestore rule is syncing
    }
  }

  // Helper to format clean, user-friendly Firebase Auth error messages
  Exception _handleFirebaseAuthException(FirebaseAuthException e, [String? provider]) {
    switch (e.code) {
      case 'invalid-phone-number':
        return Exception('Please enter a valid phone number.');
      case 'missing-verification-code':
        return Exception('Please enter a valid 6-digit verification code.');
      case 'invalid-verification-code':
        return Exception('The verification code entered is invalid.');
      case 'invalid-verification-id':
      case 'session-expired':
        return Exception('Verification code has expired. Please request a new code.');
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
          return Exception('Phone authentication is disabled in the Firebase Console. Enable "Phone" under Authentication > Sign-in method in Firebase Console.');
        } else if (provider == 'email') {
          return Exception('Email/Password sign-in is disabled in the Firebase Console. Enable "Email/Password" under Authentication > Sign-in method in Firebase Console.');
        }
        return Exception('Anonymous authentication is disabled in the Firebase Console. Enable "Anonymous" under Authentication > Sign-in method in Firebase Console.');
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

  // Public exception mapper for testing and consistency
  Exception handleFirebaseAuthException(FirebaseAuthException e, [String? provider]) =>
      _handleFirebaseAuthException(e, provider);

  // Get stream of auth state changes, combining FirebaseAuth transitions with
  // local sign-out / cross-role session invalidation events.
  Stream<User?> get authStateChanges {
    final controller = StreamController<User?>.broadcast();
    StreamSubscription<User?>? firebaseSub;
    StreamSubscription<User?>? sessionSub;

    void emitCurrent([User? candidate]) {
      if (controller.isClosed) return;
      if (_mockUser != null) {
        controller.add(_mockUser);
        return;
      }
      if (kEnableDevBypass && devMockUser != null) {
        controller.add(devMockUser);
        return;
      }
      controller.add(candidate);
    }

    controller.onListen = () {
      // Emit initial state asynchronously so StreamBuilder / StreamProvider receives current session immediately.
      scheduleMicrotask(() => emitCurrent(currentUser));

      sessionSub = _sessionChangeController.stream.listen((user) {
        if (!controller.isClosed) {
          controller.add(user);
        }
      });

      try {
        firebaseSub = _auth.authStateChanges().listen(
          (firebaseUser) {
            if (kEnableDevBypass && devMockUser != null) {
              emitCurrent(devMockUser);
            } else {
              if (!controller.isClosed) {
                controller.add(_mockUser ?? firebaseUser);
              }
            }
          },
          onError: (_) {
            if (!controller.isClosed) {
              controller.add(currentUser);
            }
          },
        );
      } catch (_) {
        // Firebase Core not initialized in headless widget test; rely on session events.
      }
    };

    controller.onCancel = () async {
      await sessionSub?.cancel();
      await firebaseSub?.cancel();
    };

    return controller.stream;
  }
}
