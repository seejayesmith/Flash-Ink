import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flash_ink/core/mock/mock_data_config.dart';
import 'package:flash_ink/features/artist/presentation/widgets/artist_header_section.dart';
import 'package:flash_ink/features/messages/domain/models/message_thread.dart';
import 'package:flash_ink/models/artist.dart';
import 'package:flash_ink/models/artist_dashboard_data.dart';
import 'package:flash_ink/screens/artist_dashboard/artist_dashboard_screen.dart';
import 'package:flash_ink/screens/artist_dashboard/artist_earnings_screen.dart';
import 'package:flash_ink/screens/artist_dashboard/artist_waitlist_screen.dart';
import 'package:flash_ink/services/auth_service.dart';
import 'package:flash_ink/services/booking_sync_service.dart';

class _LiveTestUser extends Fake implements User {
  @override
  final String uid;
  @override
  final String? displayName = 'Nova Ink';
  @override
  final String? email = 'nova@studio.com';
  @override
  final String? photoURL = '';

  _LiveTestUser({required this.uid});
}

class _FakeLiveAuthService extends AuthService {
  final User _user;
  _FakeLiveAuthService(this._user);

  @override
  User? get currentUser => _user;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  group('Artist Live Mode Quarantine Tests (MockDataConfig.isEnabled == false)', () {
    late _FakeLiveAuthService liveAuth;

    setUp(() {
      MockDataConfig.debugOverride = false;
      BookingSyncService.enableCloudWrites = false;
      ArtistDashboardRepository.resetMockData();
      MessageThread.liveThreads.clear();
      liveAuth = _FakeLiveAuthService(_LiveTestUser(uid: 'artist_nova_1'));

      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      binding.platformDispatcher.views.first.physicalSize = const Size(1080, 2400);
      binding.platformDispatcher.views.first.devicePixelRatio = 1.0;
    });

    tearDown(() {
      MockDataConfig.resetDebugOverride();
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      binding.platformDispatcher.views.first.resetPhysicalSize();
      binding.platformDispatcher.views.first.resetDevicePixelRatio();
    });

    testWidgets('ArtistDashboardScreen renders clean empty states and zeroed stats in live mode with no mock leakage', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ArtistDashboardScreen(
            authService: liveAuth,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Uses authenticated live artist's displayName, not OddMaree
      expect(find.text('Nova Ink'), findsOneWidget);
      expect(find.text('OddMaree'), findsNothing);

      // Empty states rendered for hero next appointment and today's schedule
      expect(find.byKey(const Key('hero_next_appointment_empty_state')), findsOneWidget);
      expect(find.byKey(const Key('no_today_schedule_empty_state')), findsOneWidget);

      // No mock clients leaked
      expect(find.text('Marcus Cole'), findsNothing);
      expect(find.text('Sarah Jenkins'), findsNothing);
      expect(find.text('Elena Rostova'), findsNothing);

      // Tap Messages tab (index 2) -> verify empty state and no mock threads
      await tester.tap(find.byIcon(Icons.chat_bubble_outline_rounded));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('no_client_messages_empty_state')), findsOneWidget);
      expect(find.text('Sally McField'), findsNothing);
      expect(find.text('Jennie Banks'), findsNothing);
    });

    testWidgets('ArtistDashboardScreen Messages tab renders live threads and opens ChatConversationScreen in artist mode', (tester) async {
      final liveThread = MessageThread(
        id: 'thread_live_1',
        artistId: 'artist_nova_1',
        clientId: 'client_maya_1',
        clientName: 'Maya Lin',
        artistName: 'Nova Ink',
        artistAvatar: '',
        studioName: 'Eclipse Tattoo',
        lastMessage: 'Looking forward to my session!',
        lastMessageTime: DateTime.now(),
        unreadCount: 1,
        flashTitleContext: 'Botanical Moth',
        messages: [
          ChatMessage(
            id: 'm1',
            senderId: 'client_maya_1',
            senderName: 'Maya Lin',
            text: 'Looking forward to my session!',
            timestamp: DateTime.now(),
            isFromArtist: false,
          ),
        ],
      );
      MessageThread.addThread(liveThread);

      await tester.pumpWidget(
        MaterialApp(
          home: ArtistDashboardScreen(
            authService: liveAuth,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.chat_bubble_outline_rounded));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('no_client_messages_empty_state')), findsNothing);
      expect(find.text('Maya Lin'), findsOneWidget);
      expect(find.text('Looking forward to my session!'), findsOneWidget);

      // Tap thread to open live artist conversation
      await tester.tap(find.byKey(const Key('artist_message_thread_thread_live_1')));
      await tester.pumpAndSettle();

      expect(find.text('Maya Lin'), findsWidgets);
    });

    testWidgets('ArtistEarningsScreen starts at \$0.00 in live mode and dynamically reflects live appointments', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ArtistEarningsScreen(
              authService: liveAuth,
              isEmbeddedInTab: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Zeroed live earnings
      expect(find.text('\$0', findRichText: true), findsWidgets);
      expect(find.text('.00'), findsOneWidget);
      expect(find.text('\$1,256', findRichText: true), findsNothing);
      expect(find.text('.09'), findsNothing);
      expect(find.text('\$3,467', findRichText: true), findsNothing);
      expect(find.text('\$16,987', findRichText: true), findsNothing);

      // Switch to History tab -> empty state, no 2023 mock transactions
      await tester.tap(find.byKey(const Key('earnings_tab_history')));
      await tester.pumpAndSettle();

      expect(find.text('Chloe Bennett'), findsNothing);
      expect(find.text('Julian Alvarez'), findsNothing);
      expect(find.text('No session history found.'), findsOneWidget);

      // Add a live appointment and verify dynamic earnings calculation
      ArtistDashboardRepository.addCalendarAppointment(
        DashboardAppointment(
          id: 'apt_live_101',
          clientId: 'client_leo',
          artistId: 'artist_nova_1',
          clientName: 'Leo Vance',
          serviceType: 'Flash: Lunar Serpent',
          duration: '2h',
          time: '2:00 PM',
          scheduledDate: DateTime.now(),
          date: 'Today',
          placement: 'Forearm',
          depositPaid: 100,
          fullPrice: 350,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Leo Vance'), findsOneWidget);
      expect(find.text('\$350'), findsWidgets);
    });

    testWidgets('ArtistWaitlistScreen and AddWaitlistEntrySheet have zero mock contacts in live mode', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ArtistWaitlistScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Chloe Bennett'), findsNothing);
      expect(find.text('Aunt Michelle'), findsNothing);
      expect(find.text('Marcus Cole'), findsNothing);

      // Open AddWaitlistEntrySheet
      await tester.tap(find.text('Add Friend'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('empty_flash_profiles_search_state')), findsOneWidget);
    });

    test('BookingSyncService.hydrateArtistDataFromCloud populates live schedule, appointments, requests, and chats', () async {
      final fakeFirestore = FakeFirebaseFirestore();
      const artistId = 'artist_nova_1';

      await fakeFirestore.collection('artist_schedules').doc(artistId).set({
        'artistId': artistId,
        'isBooksOpen': true,
        'defaultDepositAmount': 120,
        'locationNote': 'Eclipse Tattoo • Seattle, WA',
        'waitlistEntries': [
          {
            'id': 'wl_live_1',
            'artistId': artistId,
            'clientName': 'Zoe Kravitz',
            'conceptDescription': 'Minimalist botanical vine',
            'status': 'waiting',
            'createdAt': DateTime(2026, 10, 15).toIso8601String(),
          },
        ],
      });

      await fakeFirestore.collection('appointments').doc('apt_cloud_1').set({
        'id': 'apt_cloud_1',
        'artistId': artistId,
        'clientId': 'client_zoe',
        'clientName': 'Zoe Kravitz',
        'serviceType': 'Flash: Botanical Vine',
        'duration': '2h',
        'time': '1:00 PM',
        'scheduledDate': DateTime.now().toIso8601String(),
        'depositPaid': 120,
        'fullPrice': 400,
      });

      await fakeFirestore.collection('custom_requests').doc('req_cloud_1').set({
        'id': 'req_cloud_1',
        'artistId': artistId,
        'clientId': 'client_kai',
        'clientName': 'Kai Thorne',
        'conceptDescription': 'Geometric wolf shoulder piece',
        'placement': 'Upper Arm',
        'estimatedPrice': 500,
        'deposit': 120,
        'status': 'pending_artist_approval',
      });

      await fakeFirestore.collection('chats').doc('chat_cloud_1').set({
        'id': 'chat_cloud_1',
        'artistId': artistId,
        'clientId': 'client_zoe',
        'clientName': 'Zoe Kravitz',
        'artistName': 'Nova Ink',
        'studioName': 'Eclipse Tattoo',
        'lastMessage': 'Deposit confirmed!',
        'lastMessageTime': DateTime.now().toIso8601String(),
        'participants': ['client_zoe', artistId],
        'unreadCount': 1,
      });

      await BookingSyncService.hydrateArtistDataFromCloud(
        artistId,
        firestore: fakeFirestore,
      );

      expect(ArtistDashboardRepository.booksSchedule.defaultDepositAmount, 120);
      expect(ArtistDashboardRepository.booksSchedule.locationNote, 'Eclipse Tattoo • Seattle, WA');
      expect(ArtistDashboardRepository.waitlistEntries.length, 1);
      expect(ArtistDashboardRepository.waitlistEntries.first.clientName, 'Zoe Kravitz');
      expect(ArtistDashboardRepository.calendarAppointments.length, 1);
      expect(ArtistDashboardRepository.calendarAppointments.first.clientName, 'Zoe Kravitz');
      expect(ArtistDashboardRepository.pendingRequests.length, 1);
      expect(ArtistDashboardRepository.pendingRequests.first.clientName, 'Kai Thorne');
      expect(MessageThread.activeThreads.length, 1);
      expect(MessageThread.activeThreads.first.clientName, 'Zoe Kravitz');
    });

    testWidgets('Artist.fromMap in live mode does not inject MockFixtures.defaultFunFacts or XYZ placeholders', (tester) async {
      final liveArtist = Artist.fromMap({
        'id': 'artist_nova_1',
        'name': 'Nova Ink',
        'studioType': 'Private Studio',
        'isBooksOpen': true,
        'tags': ['Fine Line'],
      });

      expect(liveArtist.funFacts, isEmpty);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ArtistHeaderSection(
              artist: liveArtist,
              isFavorited: false,
              onToggleFavorite: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('XYZ'), findsNothing);
      expect(find.text('Specialty'), findsOneWidget);
      expect(find.text('Fine Line'), findsOneWidget);
      expect(find.text('Private Studio'), findsWidgets);
      expect(find.text('Books Open'), findsOneWidget);
    });
  });
}
