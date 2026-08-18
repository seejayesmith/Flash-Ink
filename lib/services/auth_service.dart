import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Sign in with Google (Placeholder logic, needs flutterfire_ui or google_sign_in package implementation)
  Future<UserCredential?> signInWithGoogle() async {
    // In a real app, you would use google_sign_in package here.
    // For now, we stub this out as the architecture requires it.
    throw UnimplementedError('Google Sign-In is not yet fully implemented with google_sign_in package.');
  }

  // Sign in with Apple (Placeholder logic, needs sign_in_with_apple package)
  Future<UserCredential?> signInWithApple() async {
    // In a real app, you would use sign_in_with_apple package here.
    throw UnimplementedError('Apple Sign-In is not yet fully implemented with sign_in_with_apple package.');
  }

  // Signs out the current user
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Synchronize Firebase Auth user with Firestore users collection
  Future<void> syncUserToFirestore(User authUser) async {
    final userRef = _firestore.collection('users').doc(authUser.uid);
    
    final docSnapshot = await userRef.get();
    
    // Only create profile if it doesn't exist
    if (!docSnapshot.exists) {
      final newUser = UserProfile(
        uid: authUser.uid,
        email: authUser.email ?? '',
        displayName: authUser.displayName,
        createdAt: DateTime.now(),
      );
      
      await userRef.set(newUser.toJson());
    }
  }

  // Get stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();
}
