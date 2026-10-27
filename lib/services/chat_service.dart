import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Deposit-Gated Direct Messaging Service.
///
/// Enforces Flash.Ink's anti-spam policy on the client and pairs with the
/// `/chats/{threadId}/messages/{messageId}` Cloud Firestore Security Rules:
/// - Clients cannot create chat threads directly (threads are provisioned
///   server-side by Cloud Functions when a booking reaches `deposit_confirmed`).
/// - Messages can only be sent by thread participants on bookings with
///   `status == 'deposit_confirmed'`.
class ChatService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  ChatService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  /// Verifies whether a chat thread has an active, deposit-confirmed booking.
  Future<bool> isThreadUnlocked(String threadId) async {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) return false;

    final threadDoc = await _firestore.collection('chats').doc(threadId).get();
    if (!threadDoc.exists) return false;

    final data = threadDoc.data();
    if (data == null) return false;

    final participants = data['participants'];
    if (participants is! List || !participants.contains(user.uid)) {
      return false;
    }

    final bookingId = data['bookingId'] as String?;
    if (bookingId == null || bookingId.isEmpty) return false;

    final bookingDoc = await _firestore.collection('bookings').doc(bookingId).get();
    if (!bookingDoc.exists) return false;

    return bookingDoc.data()?['status'] == 'deposit_confirmed';
  }

  /// Sends a message to an existing, deposit-confirmed chat thread.
  ///
  /// Throws a [StateError] if the user is not authenticated, the text exceeds
  /// 2,000 characters, or the underlying booking is not `deposit_confirmed`.
  Future<void> sendMessage({
    required String threadId,
    required String text,
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) {
      throw StateError('Authentication required to send messages.');
    }

    final trimmed = text.trim();
    if (trimmed.isEmpty || trimmed.length > 2000) {
      throw ArgumentError('Message must be between 1 and 2,000 characters.');
    }

    final unlocked = await isThreadUnlocked(threadId);
    if (!unlocked) {
      throw StateError(
        'Direct messaging is locked until your booking deposit is confirmed.',
      );
    }

    await _firestore
        .collection('chats')
        .doc(threadId)
        .collection('messages')
        .add({
      'senderId': user.uid,
      'text': trimmed,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
