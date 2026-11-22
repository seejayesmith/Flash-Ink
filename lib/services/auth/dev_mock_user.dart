import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

/// Best-effort Firestore synchronization for a development bypass [DevMockUser].
Future<void> syncDevMockUserToFirestore(
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
        'location': 'Portland, OR',
        'latitude': 45.5152,
        'longitude': -122.6784,
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
