import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flash_ink/core/mock/mock_data_config.dart';
import 'package:flash_ink/features/messages/domain/models/message_thread.dart';
import 'package:flash_ink/features/messages/presentation/screens/chat_conversation_screen.dart';
import 'package:flash_ink/features/messages/presentation/widgets/message_thread_tile.dart';
import 'package:flash_ink/repositories/artist_dashboard_repository.dart';
import 'package:flash_ink/screens/artist_dashboard/artist_dashboard_screen.dart';
import 'package:flash_ink/services/auth_service.dart';
import 'package:flash_ink/services/booking_sync_service.dart';
import 'package:flash_ink/widgets/flash_image.dart';
import 'package:flash_ink/widgets/user_avatar.dart';

class _MockFirebaseUser extends Fake implements User {
  @override
  final String uid;
  @override
  final String? displayName;
  @override
  final String? photoURL;

  _MockFirebaseUser({
    required this.uid,
    this.displayName,
    this.photoURL,
  });
}

class _FakeArtistAuthService extends AuthService {
  final User _user;

  _FakeArtistAuthService(this._user);

  @override
  User? get currentUser => _user;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  setUp(() {
    MockDataConfig.debugOverride = true;
    MessageThread.liveThreads.clear();
    ArtistDashboardRepository.liveTodaySchedule.clear();
    ArtistDashboardRepository.livePendingRequests.clear();
    ArtistDashboardRepository.liveCalendarAppointments.clear();
    ArtistDashboardRepository.resetMockData();
  });

  tearDown(() {
    MockDataConfig.debugOverride = null;
    MessageThread.liveThreads.clear();
    ArtistDashboardRepository.liveTodaySchedule.clear();
    ArtistDashboardRepository.livePendingRequests.clear();
    ArtistDashboardRepository.liveCalendarAppointments.clear();
    ArtistDashboardRepository.resetMockData();
  });

  group('UserAvatar helpers & rendering', () {
    test('resolveInitial strips leading @ symbols and trims whitespace', () {
      expect(UserAvatar.resolveInitial('@CJ Smith'), 'C');
      expect(UserAvatar.resolveInitial('@@alice'), 'A');
      expect(UserAvatar.resolveInitial('  @OddMaree'), 'O');
      expect(UserAvatar.resolveInitial('@', fallback: 'C'), 'C');
      expect(UserAvatar.resolveInitial('', fallback: '?'), '?');
      expect(UserAvatar.resolveInitial(null, fallback: 'A'), 'A');
    });

    test('isValidUrl accepts http(s)/asset paths and rejects empty or local://', () {
      expect(UserAvatar.isValidUrl('https://example.com/avatar.jpg'), isTrue);
      expect(UserAvatar.isValidUrl('http://example.com/avatar.jpg'), isTrue);
      expect(UserAvatar.isValidUrl('assets/images/flash_butterfly.jpg'), isTrue);
      expect(UserAvatar.isValidUrl(''), isFalse);
      expect(UserAvatar.isValidUrl('   '), isFalse);
      expect(UserAvatar.isValidUrl('local://avatar.png'), isFalse);
      expect(UserAvatar.isValidUrl(null), isFalse);
    });

    testWidgets('renders FlashImage when given valid asset path and @-stripped initial otherwise', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                UserAvatar(
                  imageUrl: 'assets/images/flash_butterfly.jpg',
                  displayName: '@CJ Smith',
                ),
                UserAvatar(
                  imageUrl: '',
                  displayName: '@CJ Smith',
                ),
                UserAvatar(
                  imageUrl: 'local://photo.png',
                  displayName: '@@Maya Lin',
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(FlashImage), findsOneWidget);
      expect(find.text('C'), findsOneWidget);
      expect(find.text('M'), findsOneWidget);
      expect(find.text('@'), findsNothing);
    });
  });

  group('MessageThread serialization', () {
    test('toMap and fromMap round-trip clientAvatar and omit empty clientAvatar', () {
      final withPhoto = MessageThread(
        id: 'thread_1',
        artistId: 'artist_1',
        clientId: 'client_1',
        clientName: '@CJ Smith',
        clientAvatar: 'https://example.com/cj.jpg',
        artistName: 'Nova Ink',
        artistAvatar: 'https://example.com/nova.jpg',
        studioName: 'Flash Studio',
        lastMessage: 'Hello!',
        lastMessageTime: DateTime(2026, 5, 1, 12, 0),
        unreadCount: 1,
      );

      final map = withPhoto.toMap();
      expect(map['clientAvatar'], 'https://example.com/cj.jpg');
      expect(map['artistAvatar'], 'https://example.com/nova.jpg');

      final restored = MessageThread.fromMap(map, 'thread_1');
      expect(restored.clientAvatar, 'https://example.com/cj.jpg');
      expect(restored.artistAvatar, 'https://example.com/nova.jpg');

      final withoutClientPhoto = withPhoto.copyWith(clientAvatar: '');
      expect(withoutClientPhoto.toMap().containsKey('clientAvatar'), isFalse);

      final fromAliases = MessageThread.fromMap({
        'artistId': 'artist_1',
        'clientId': 'client_1',
        'clientName': '@CJ Smith',
        'clientPhotoUrl': 'https://example.com/alias_cj.jpg',
        'artistName': 'Nova Ink',
        'artistPhotoURL': 'https://example.com/alias_nova.jpg',
        'studioName': 'Flash Studio',
        'lastMessage': 'Hey',
        'unreadCount': 0,
      }, 'thread_alias');
      expect(fromAliases.clientAvatar, 'https://example.com/alias_cj.jpg');
      expect(fromAliases.artistAvatar, 'https://example.com/alias_nova.jpg');
    });
  });

  group('Artist & client message UI avatars', () {
    testWidgets('ArtistDashboardScreen Client Messages renders client photo and never @ fallback', (tester) async {
      MockDataConfig.debugOverride = false;

      MessageThread.liveThreads.addAll([
        MessageThread(
          id: 'thread_with_photo',
          artistId: 'artist_live',
          clientId: 'client_cj',
          clientName: '@CJ Smith',
          clientAvatar: 'assets/images/flash_butterfly.jpg',
          artistName: 'Nova Ink',
          artistAvatar: 'assets/images/flash_anchor.jpg',
          studioName: 'Nova Studio',
          lastMessage: 'Flash piece "flower power" claimed',
          lastMessageTime: DateTime.now().subtract(const Duration(days: 3)),
          unreadCount: 1,
        ),
        MessageThread(
          id: 'thread_no_photo',
          artistId: 'artist_live',
          clientId: 'client_alex',
          clientName: '@Alex Rivera',
          clientAvatar: '',
          artistName: 'Nova Ink',
          artistAvatar: '',
          studioName: 'Nova Studio',
          lastMessage: 'Checking in about Friday',
          lastMessageTime: DateTime.now().subtract(const Duration(hours: 2)),
          unreadCount: 0,
        ),
      ]);

      final fakeAuth = _FakeArtistAuthService(
        _MockFirebaseUser(
          uid: 'artist_live',
          displayName: 'Nova Ink',
          photoURL: 'assets/images/flash_anchor.jpg',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ArtistDashboardScreen(authService: fakeAuth),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.chat_bubble_outline_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Client Messages'), findsOneWidget);
      expect(find.text('@CJ Smith'), findsOneWidget);
      expect(find.text('@Alex Rivera'), findsOneWidget);

      // Client photo renders in the thread row
      expect(
        find.byWidgetPredicate(
          (w) => w is FlashImage && w.urlOrPath == 'assets/images/flash_butterfly.jpg',
        ),
        findsOneWidget,
      );
      // Fallback initial strips '@' ('A' instead of '@')
      expect(find.text('A'), findsOneWidget);
      expect(find.text('@'), findsNothing);
    });

    testWidgets('ChatConversationScreen uses clientAvatar in artist view and artistAvatar in client view', (tester) async {
      final thread = MessageThread(
        id: 'thread_chat',
        artistId: 'artist_1',
        clientId: 'client_cj',
        clientName: '@CJ Smith',
        clientAvatar: 'assets/images/flash_butterfly.jpg',
        artistName: '@OddMaree',
        artistAvatar: 'assets/images/flash_anchor.jpg',
        studioName: 'Studio',
        lastMessage: 'See you soon',
        lastMessageTime: DateTime.now(),
        unreadCount: 0,
      );

      // Artist view -> displays clientAvatar & clientName
      await tester.pumpWidget(
        MaterialApp(
          home: ChatConversationScreen(
            thread: thread,
            isArtistView: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('@CJ Smith'), findsOneWidget);
      expect(find.text('Type a message to @CJ Smith...'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is FlashImage && w.urlOrPath == 'assets/images/flash_butterfly.jpg',
        ),
        findsOneWidget,
      );

      // Artist view with empty clientAvatar -> strips '@' to 'C'
      await tester.pumpWidget(
        MaterialApp(
          home: ChatConversationScreen(
            thread: thread.copyWith(clientAvatar: ''),
            isArtistView: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('C'), findsOneWidget);
      expect(find.text('@'), findsNothing);

      // Client view -> displays artistAvatar & artistName
      await tester.pumpWidget(
        MaterialApp(
          home: ChatConversationScreen(
            thread: thread,
            isArtistView: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('@OddMaree'), findsOneWidget);
      expect(find.text('Type a message to @OddMaree...'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is FlashImage && w.urlOrPath == 'assets/images/flash_anchor.jpg',
        ),
        findsOneWidget,
      );

      // Client view with empty artistAvatar -> strips '@' to 'O'
      await tester.pumpWidget(
        MaterialApp(
          home: ChatConversationScreen(
            thread: thread.copyWith(artistAvatar: ''),
            isArtistView: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('O'), findsOneWidget);
      expect(find.text('@'), findsNothing);
    });

    testWidgets('MessageThreadTile switches between artistAvatar and clientAvatar safely', (tester) async {
      final thread = MessageThread(
        id: 'thread_tile',
        artistId: 'artist_1',
        clientId: 'client_cj',
        clientName: '@CJ Smith',
        clientAvatar: 'assets/images/flash_butterfly.jpg',
        artistName: '@OddMaree',
        artistAvatar: '',
        studioName: 'Studio',
        lastMessage: 'Claimed!',
        lastMessageTime: DateTime.now(),
        unreadCount: 0,
      );

      // Client inbox view with empty artistAvatar -> renders 'O' (never '@') without crashing
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageThreadTile(thread: thread),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('O'), findsOneWidget);
      expect(find.text('@'), findsNothing);

      // Artist view -> renders clientAvatar image
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageThreadTile(
              thread: thread,
              isArtistView: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate(
          (w) => w is FlashImage && w.urlOrPath == 'assets/images/flash_butterfly.jpg',
        ),
        findsOneWidget,
      );
    });
  });

  group('BookingSyncService avatar hydration & backfill', () {
    test('hydrateArtistDataFromCloud backfills clientAvatar from bookings and public artists profile', () async {
      MockDataConfig.debugOverride = false;
      final fakeFirestore = FakeFirebaseFirestore();

      // Thread 1: clientAvatar missing on chat, present on appointment
      await fakeFirestore.collection('chats').doc('thread_booking').set({
        'artistId': 'artist_1',
        'clientId': 'client_1',
        'clientName': '@CJ Smith',
        'clientAvatar': '',
        'artistName': 'Nova Ink',
        'artistAvatar': 'https://example.com/nova.jpg',
        'studioName': 'Nova Studio',
        'lastMessage': 'Flower power claimed',
        'unreadCount': 1,
        'participants': ['artist_1', 'client_1'],
      });
      await fakeFirestore.collection('appointments').doc('apt_1').set({
        'artistId': 'artist_1',
        'clientId': 'client_1',
        'clientName': '@CJ Smith',
        'clientAvatar': 'https://example.com/cj_from_booking.jpg',
        'flashTitle': 'Flower Power',
        'date': DateTime(2026, 6, 1).toIso8601String(),
        'timeSlot': '2:00 PM',
        'price': 200,
        'depositPaid': 50,
        'status': 'confirmed',
      });

      // Thread 2: clientAvatar missing on chat, available on public artists/{clientId}
      await fakeFirestore.collection('chats').doc('thread_dual_role').set({
        'artistId': 'artist_1',
        'clientId': 'dual_user_2',
        'clientName': '@Maya',
        'clientAvatar': '',
        'artistName': 'Nova Ink',
        'artistAvatar': 'https://example.com/nova.jpg',
        'studioName': 'Nova Studio',
        'lastMessage': 'Hi!',
        'unreadCount': 0,
        'participants': ['artist_1', 'dual_user_2'],
      });
      await fakeFirestore.collection('artists').doc('dual_user_2').set({
        'name': '@Maya',
        'avatarUrl': 'https://example.com/maya_artist_avatar.jpg',
      });

      await BookingSyncService.hydrateArtistDataFromCloud(
        'artist_1',
        firestore: fakeFirestore,
      );

      final hydratedBookingThread = MessageThread.liveThreads.firstWhere(
        (t) => t.id == 'thread_booking',
      );
      expect(
        hydratedBookingThread.clientAvatar,
        'https://example.com/cj_from_booking.jpg',
      );

      final hydratedDualThread = MessageThread.liveThreads.firstWhere(
        (t) => t.id == 'thread_dual_role',
      );
      expect(
        hydratedDualThread.clientAvatar,
        'https://example.com/maya_artist_avatar.jpg',
      );

      // Verify Firestore backfill persisted
      final dualSnap = await fakeFirestore
          .collection('chats')
          .doc('thread_dual_role')
          .get();
      expect(
        dualSnap.data()?['clientAvatar'],
        'https://example.com/maya_artist_avatar.jpg',
      );
    });

    test('hydrateClientDataFromCloud hydrates threads and backfills missing artistAvatar', () async {
      MockDataConfig.debugOverride = false;
      final fakeFirestore = FakeFirebaseFirestore();

      await fakeFirestore.collection('chats').doc('client_thread_1').set({
        'artistId': 'artist_9',
        'clientId': 'client_9',
        'clientName': '@CJ Smith',
        'clientAvatar': 'https://example.com/cj.jpg',
        'artistName': 'Studio Ink',
        'artistAvatar': '',
        'studioName': 'Studio Nine',
        'lastMessage': 'Appointment confirmed',
        'unreadCount': 1,
        'participants': ['client_9', 'artist_9'],
      });
      await fakeFirestore.collection('artists').doc('artist_9').set({
        'name': 'Studio Ink',
        'avatarUrl': 'https://example.com/studio_ink.jpg',
      });

      await BookingSyncService.hydrateClientDataFromCloud(
        'client_9',
        firestore: fakeFirestore,
      );

      expect(MessageThread.liveThreads.length, 1);
      final thread = MessageThread.liveThreads.first;
      expect(thread.artistAvatar, 'https://example.com/studio_ink.jpg');
      expect(thread.clientAvatar, 'https://example.com/cj.jpg');

      final chatSnap = await fakeFirestore
          .collection('chats')
          .doc('client_thread_1')
          .get();
      expect(
        chatSnap.data()?['artistAvatar'],
        'https://example.com/studio_ink.jpg',
      );
    });
  });
}
