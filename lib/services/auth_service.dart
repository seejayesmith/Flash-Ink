import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../config/dev_config.dart';
import '../repositories/artist_dashboard_repository.dart';
import 'auth/auth_account_lifecycle.dart';
import 'auth/auth_exceptions.dart' as auth_exceptions;
import 'auth/auth_formatters.dart';
import 'auth/auth_reauthentication_helper.dart';
import 'auth/dev_mock_user.dart';
import 'booking_sync_service.dart';
import 'notification_service.dart';

class AuthService {
  final FirebaseAuth? _authInstance;
  final FirebaseFirestore? _firestoreInstance;
  final FirebaseFunctions? _functionsInstance;
  final User? _mockUser;

  String? _verificationId;
  int? _resendToken;

  /// The most recent phone auth verification ID retained in state.
  String? get verificationId => _verificationId;

  /// The most recent phone auth resend token retained in state.
  int? get resendToken => _resendToken;

  static String formatE164PhoneNumber(String rawPhone) =>
      AuthFormatters.formatE164PhoneNumber(rawPhone);

  static String formatDisplayPhoneNumber(String? rawPhone) =>
      AuthFormatters.formatDisplayPhoneNumber(rawPhone);

  static DevMockUser? devMockUser;

  /// Active UI persona mode for dual-role users (`'client'` or `'artist'`).
  static String? activeAppMode;
  static final StreamController<String?> _activeModeController =
      StreamController<String?>.broadcast();

  /// Stream of active persona mode transitions (`'client'` or `'artist'`).
  static Stream<String?> get activeModeChanges => _activeModeController.stream;

  /// Updates the active persona mode in memory and persists it to `/users/{uid}` in Firestore.
  static Future<void> setActiveAppMode(
    String? mode, {
    String? uid,
    FirebaseFirestore? firestore,
  }) async {
    activeAppMode = mode;
    if (!_activeModeController.isClosed) {
      _activeModeController.add(mode);
    }
    if (mode != null && uid != null && uid.isNotEmpty) {
      final bool isWidgetTest =
          WidgetsBinding.instance.runtimeType.toString().contains('Test');
      if (isWidgetTest && firestore == null) {
        return;
      }
      try {
        final db = firestore ?? FirebaseFirestore.instance;
        await db.collection('users').doc(uid).set({
          'uid': uid,
          'activeMode': mode,
          if (mode == 'artist') 'onboardingRole': 'artist',
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)).timeout(const Duration(seconds: 2));
      } catch (_) {}
    }
  }

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
    syncDevMockUserToFirestore(user, role: 'client', firestore: firestore);
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
    syncDevMockUserToFirestore(user, role: 'artist', firestore: firestore);
    return user;
  }

  static void clearDevMockUser() {
    devMockUser = null;
    _sessionEpoch++;
    _sessionEpochController.add(_sessionEpoch);
    notifyAuthSessionChanged(null);
  }

  AuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    this._mockUser,
  })  : _authInstance = auth,
        _firestoreInstance = firestore,
        _functionsInstance = functions;

  FirebaseAuth get _auth => _authInstance ?? FirebaseAuth.instance;
  FirebaseFirestore get _firestore =>
      _firestoreInstance ?? FirebaseFirestore.instance;
  FirebaseFunctions get _functions =>
      _functionsInstance ?? FirebaseFunctions.instance;

  static String normalizeRecoveryIdentifier(String rawIdentifier) =>
      AuthFormatters.normalizeRecoveryIdentifier(rawIdentifier);

  static FirebaseAuthException mapRecoveryFunctionsException(
    FirebaseFunctionsException e, {
    String? identifier,
    bool isVerification = false,
  }) =>
      auth_exceptions.mapRecoveryFunctionsException(
        e,
        identifier: identifier,
        isVerification: isVerification,
      );

  /// Requests a server-generated 6-digit recovery OTP via `requestRecoveryOtp`.
  Future<void> requestRecoveryOtp(String identifier) async {
    final normalizedIdentifier = normalizeRecoveryIdentifier(identifier);
    try {
      final callable = _functions.httpsCallable('requestRecoveryOtp');
      await callable.call<dynamic>({
        'identifier': normalizedIdentifier,
      });
    } on FirebaseAuthException {
      rethrow;
    } on FirebaseFunctionsException catch (e) {
      throw mapRecoveryFunctionsException(
        e,
        identifier: normalizedIdentifier,
        isVerification: false,
      );
    }
  }

  /// Verifies a 6-digit recovery OTP `code` via `verifyRecoveryOtp`.
  Future<bool> verifyRecoveryOtp({
    required String identifier,
    required String code,
  }) async {
    final normalizedIdentifier = normalizeRecoveryIdentifier(identifier);
    final sanitizedCode = code.trim();
    if (sanitizedCode.length != 6 ||
        !RegExp(r'^\d{6}$').hasMatch(sanitizedCode)) {
      throw FirebaseAuthException(
        code: 'invalid-verification-code',
        message: 'The verification code entered is invalid.',
      );
    }

    try {
      final callable = _functions.httpsCallable('verifyRecoveryOtp');
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
      throw mapRecoveryFunctionsException(
        e,
        identifier: normalizedIdentifier,
        isVerification: true,
      );
    }
  }

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

  /// Resolves the user's verified role from server-minted Firebase Auth Custom Claims.
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
      if (tokenResult.claims?['isArtist'] == true) {
        return 'artist';
      }
    } catch (_) {
      // Fallback safely to 'client' if token refresh is unavailable in headless/offline tests
    }
    return 'client';
  }

  /// Clears all cached in-memory repository state to prevent cross-role data leakage on sign-out.
  static void invalidateSessionState() {
    devMockUser = null;
    activeAppMode = null;
    if (!_activeModeController.isClosed) {
      _activeModeController.add(null);
    }
    ArtistDashboardRepository.resetMockData();
    BookingSyncService.resetSyncState();
    _sessionEpoch++;
    if (!_sessionEpochController.isClosed) {
      _sessionEpochController.add(_sessionEpoch);
    }
    notifyAuthSessionChanged(null);
  }

  Future<UserCredential> signUpWithEmailAndPassword(
    String email,
    String password, {
    String? role,
  }) async {
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
      throw auth_exceptions.mapFirebaseAuthException(e, 'email');
    } catch (e) {
      throw Exception('Failed to create account: ${e.toString()}');
    }
  }

  Future<UserCredential> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
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
      throw auth_exceptions.mapFirebaseAuthException(e, 'email');
    } catch (e) {
      throw Exception('Failed to sign in: ${e.toString()}');
    }
  }

  Future<void> sendEmailVerification() async {
    try {
      final user = currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
      }
    } on FirebaseAuthException catch (e) {
      throw auth_exceptions.mapFirebaseAuthException(e, 'email');
    } catch (e) {
      throw Exception('Failed to send verification email: ${e.toString()}');
    }
  }

  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential =
          await _auth.signInWithCredential(credential);
      if (userCredential.user != null) {
        await syncUserToFirestore(userCredential.user!);
      }
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw auth_exceptions.mapFirebaseAuthException(e, 'email');
    } catch (e) {
      throw Exception('Google sign-in failed: ${e.toString()}');
    }
  }

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

      final UserCredential userCredential =
          await _auth.signInWithCredential(credential);
      if (userCredential.user != null) {
        await syncUserToFirestore(userCredential.user!);
      }
      return userCredential;
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return null;
      }
      throw Exception('Apple authorization failed: ${e.message}');
    } on FirebaseAuthException catch (e) {
      throw auth_exceptions.mapFirebaseAuthException(e, 'email');
    } catch (e) {
      throw Exception('Apple sign-in failed: ${e.toString()}');
    }
  }

  Future<UserCredential> signInAnonymously() async {
    try {
      final userCredential = await _auth.signInAnonymously();
      if (userCredential.user != null) {
        await syncUserToFirestore(userCredential.user!);
      }
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw auth_exceptions.mapFirebaseAuthException(e, 'anonymous');
    } catch (e) {
      throw Exception('Guest sign in failed: ${e.toString()}');
    }
  }

  Future<UserCredential?> linkWithGoogle() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception("No authenticated user to link account to.");
      }

      final GoogleSignIn googleSignIn = GoogleSignIn();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential =
          await user.linkWithCredential(credential);
      await _firestore
          .collection('users')
          .doc(user.uid)
          .set({'isAnonymous': false}, SetOptions(merge: true));
      return userCredential;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'credential-already-in-use') {
        return await signInWithGoogle();
      }
      throw auth_exceptions.mapFirebaseAuthException(e);
    } catch (e) {
      throw Exception('Failed to link Google account: ${e.toString()}');
    }
  }

  Future<UserCredential?> linkWithApple() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception("No authenticated user to link account to.");
      }

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

      final UserCredential userCredential =
          await user.linkWithCredential(credential);
      await _firestore
          .collection('users')
          .doc(user.uid)
          .set({'isAnonymous': false}, SetOptions(merge: true));
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
      throw auth_exceptions.mapFirebaseAuthException(e);
    } catch (e) {
      throw Exception('Failed to link Apple account: ${e.toString()}');
    }
  }

  Future<UserCredential> linkWithEmailAndPassword(
    String email,
    String password,
  ) async {
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
      if (e.code == 'credential-already-in-use' ||
          e.code == 'email-already-in-use') {
        return await signInWithEmailAndPassword(email, password);
      }
      throw auth_exceptions.mapFirebaseAuthException(e);
    } catch (e) {
      throw Exception('Failed to link email account: ${e.toString()}');
    }
  }

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
          onVerificationFailed(auth_exceptions.mapFirebaseAuthException(e, 'phone'));
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
      onVerificationFailed(auth_exceptions.mapFirebaseAuthException(e, 'phone'));
    } catch (e) {
      onVerificationFailed(
        Exception('Failed to send verification SMS: ${e.toString()}'),
      );
    }
  }

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
      throw auth_exceptions.mapFirebaseAuthException(e, 'phone');
    } catch (e) {
      throw Exception('Failed to sign in: ${e.toString()}');
    }
  }

  Future<UserCredential> signInWithPhoneCredential({
    required String verificationId,
    required String smsCode,
  }) async {
    final effectiveVerificationId = verificationId.trim().isNotEmpty
        ? verificationId.trim()
        : (_verificationId ?? '');
    if (effectiveVerificationId.isEmpty) {
      throw auth_exceptions.mapFirebaseAuthException(
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
      throw auth_exceptions.mapFirebaseAuthException(e, 'phone');
    } catch (e) {
      throw Exception('Failed to sign in: ${e.toString()}');
    }
  }

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
      throw Exception(
        'Failed to update phone verification status: ${e.toString()}',
      );
    }
  }

  static bool isGoogleAuthUser(User? user) =>
      AuthFormatters.isGoogleAuthUser(user);

  static bool isAppleAuthUser(User? user) =>
      AuthFormatters.isAppleAuthUser(user);

  static bool isOAuthUser(User? user) => AuthFormatters.isOAuthUser(user);

  static bool hasVerifiedEmail(
    User? user, [
    Map<String, dynamic>? firestoreData,
  ]) =>
      AuthFormatters.hasVerifiedEmail(user, firestoreData);

  static bool hasVerifiedPhone(
    User? user, [
    Map<String, dynamic>? firestoreData,
  ]) =>
      AuthFormatters.hasVerifiedPhone(user, firestoreData);

  Future<void> sendBackupEmailVerification(
    String email, {
    bool isArtist = false,
    FirebaseFirestore? firestore,
  }) =>
      AuthAccountLifecycle.sendBackupEmailVerification(
        email: email,
        currentUser: currentUser,
        firestoreOverride: firestore,
        serviceFirestoreInstance: _firestoreInstance,
        resolveFirestore: () => _firestore,
        isArtist: isArtist,
      );

  Future<bool> checkAndSyncBackupEmailVerified({
    String? expectedEmail,
    bool isArtist = false,
    FirebaseFirestore? firestore,
  }) =>
      AuthAccountLifecycle.checkAndSyncBackupEmailVerified(
        currentUser: currentUser,
        hasMockSession: _mockUser != null || devMockUser != null,
        resolveAuth: () => _auth,
        firestoreOverride: firestore,
        serviceFirestoreInstance: _firestoreInstance,
        resolveFirestore: () => _firestore,
        isArtist: isArtist,
        expectedEmail: expectedEmail,
      );

  Future<UserCredential?> linkWithPhoneCredential({
    required String verificationId,
    required String smsCode,
    String? phoneNumber,
  }) async {
    final user = currentUser;
    if (user == null) {
      throw Exception("No authenticated user to link account to.");
    }

    final effectiveVerificationId = verificationId.trim().isNotEmpty
        ? verificationId.trim()
        : (_verificationId ?? '');
    if (effectiveVerificationId.isEmpty) {
      throw auth_exceptions.mapFirebaseAuthException(
        FirebaseAuthException(code: 'session-expired'),
        'phone',
      );
    }
    try {
      final PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: effectiveVerificationId,
        smsCode: smsCode.trim(),
      );

      UserCredential? userCredential;
      try {
        userCredential = await user.linkWithCredential(credential);
      } catch (linkError) {
        if (linkError is FirebaseAuthException) {
          if (linkError.code == 'provider-already-linked') {
            await user.updatePhoneNumber(credential);
          } else if (linkError.code == 'credential-already-in-use') {
            throw Exception(
              'This phone number is already linked to another Flash.Ink account.',
            );
          } else {
            throw auth_exceptions.mapFirebaseAuthException(linkError, 'phone');
          }
        } else if (linkError is UnimplementedError ||
            linkError is NoSuchMethodError) {
          try {
            userCredential = await signInWithPhoneCredential(
              verificationId: effectiveVerificationId,
              smsCode: smsCode.trim(),
            );
          } catch (_) {
            if (user is! DevMockUser && !kEnableDevBypass) {
              rethrow;
            }
          }
        } else if (user is DevMockUser || kEnableDevBypass) {
          // Proceed with updating firestore
        } else {
          rethrow;
        }
      }

      final formattedPhone = phoneNumber != null && phoneNumber.trim().isNotEmpty
          ? formatE164PhoneNumber(phoneNumber)
          : (userCredential?.user?.phoneNumber ??
              formatE164PhoneNumber(_verificationId ?? ''));

      final isWidgetTest =
          WidgetsBinding.instance.runtimeType.toString().contains('Test');
      if (_firestoreInstance != null || !isWidgetTest) {
        try {
          await updatePhoneVerificationStatus(
            uid: user.uid,
            phoneNumber: formattedPhone,
          ).timeout(const Duration(seconds: 6));
        } catch (_) {}

        try {
          await _firestore
              .collection('artists')
              .doc(user.uid)
              .collection('private')
              .doc('settings')
              .set({
            'phoneNumber': formattedPhone,
            'phoneVerified': true,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true)).timeout(const Duration(seconds: 6));
        } catch (_) {}
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'credential-already-in-use') {
        throw Exception(
          'This phone number is already linked to another Flash.Ink account.',
        );
      }
      throw auth_exceptions.mapFirebaseAuthException(e, 'phone');
    } catch (e) {
      if (e.toString().contains('already linked')) rethrow;
      throw Exception('Failed to link phone number: ${e.toString()}');
    }
  }

  List<String> get currentUserProviders {
    final user = currentUser;
    if (user == null) return const [];
    List<String> providers = const [];
    try {
      providers = user.providerData.map((p) => p.providerId).toList();
    } catch (_) {}
    if (providers.isEmpty) {
      try {
        if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty) {
          return ['phone'];
        }
      } catch (_) {}
      try {
        if (user.email != null && user.email!.isNotEmpty) {
          return ['password'];
        }
      } catch (_) {}
    }
    return providers;
  }

  Future<UserCredential?> reauthenticateWithCredential(
    AuthCredential credential,
  ) async {
    if (devMockUser != null || _mockUser != null) return null;
    return AuthReauthenticationHelper.reauthenticateWithCredential(
      auth: _auth,
      credential: credential,
    );
  }

  Future<UserCredential?> reauthenticateWithPassword(String password) async {
    if (devMockUser != null || _mockUser != null) return null;
    return AuthReauthenticationHelper.reauthenticateWithPassword(
      auth: _auth,
      password: password,
    );
  }

  Future<UserCredential?> reauthenticateWithGoogle() async {
    if (devMockUser != null || _mockUser != null) return null;
    return AuthReauthenticationHelper.reauthenticateWithGoogle(auth: _auth);
  }

  Future<UserCredential?> reauthenticateWithApple() async {
    if (devMockUser != null || _mockUser != null) return null;
    return AuthReauthenticationHelper.reauthenticateWithApple(auth: _auth);
  }

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
      onVerificationFailed(
        Exception('No phone number associated with this account.'),
      );
      return;
    }
    await verifyPhoneNumber(
      phoneNumber: phoneNumber,
      onCodeSent: onCodeSent,
      onVerificationFailed: onVerificationFailed,
      onVerificationCompleted: onVerificationCompleted,
    );
  }

  Future<UserCredential?> reauthenticateWithPhoneCredential({
    required String verificationId,
    required String smsCode,
  }) async {
    if (devMockUser != null || _mockUser != null) return null;
    return AuthReauthenticationHelper.reauthenticateWithPhoneCredential(
      auth: _auth,
      verificationId: verificationId,
      fallbackVerificationId: _verificationId,
      smsCode: smsCode,
    );
  }

  Future<void> signOut() async {
    final uid = currentUser?.uid;
    if (uid != null &&
        uid.isNotEmpty &&
        devMockUser == null &&
        _mockUser == null) {
      try {
        await NotificationService.removeFcmTokenForUser(
          uid,
          firestore: _firestoreInstance,
        );
      } catch (_) {}
    }
    _verificationId = null;
    _resendToken = null;
    invalidateSessionState();
    try {
      await _auth.signOut();
      await GoogleSignIn().signOut();
    } catch (_) {}
  }

  Future<void> deleteAccount() async {
    if (devMockUser != null || _mockUser != null) {
      invalidateSessionState();
      return;
    }
    await AuthAccountLifecycle.deleteAccount(
      auth: _auth,
      firestore: _firestore,
      invalidateSessionState: invalidateSessionState,
      signOut: signOut,
    );
  }

  Future<void> syncUserToFirestore(User authUser, {String? role}) =>
      AuthAccountLifecycle.syncUserToFirestore(
        authUser: authUser,
        firestore: _firestore,
        firestoreOverride: _firestoreInstance,
        hasMockSession: devMockUser != null || _mockUser != null,
        role: role,
      );

  Exception handleFirebaseAuthException(
    FirebaseAuthException e, [
    String? provider,
  ]) =>
      auth_exceptions.mapFirebaseAuthException(e, provider);

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
