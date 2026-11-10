import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flash_ink/core/mock/mock_data_config.dart';
import 'package:flash_ink/core/widgets/flash_bottom_nav_bar.dart';
import 'package:flash_ink/features/messages/domain/models/message_thread.dart';
import 'package:flash_ink/features/messages/presentation/screens/chat_conversation_screen.dart';
import 'package:flash_ink/models/nav_destination_item.dart';
import 'package:flash_ink/screens/main_feed_screen.dart';
import 'package:flash_ink/services/auth_service.dart';
import 'package:flash_ink/widgets/artist_top_bar.dart';

class MockTestUser extends Fake implements User {
  @override
  final String uid = 'test_artist_1';
  @override
  final String? displayName = 'Artist One';
  @override
  final String? email = 'artist1@test.com';
}

class FakeTestAuthService extends AuthService {
  final MockTestUser _user = MockTestUser();

  @override
  User? get currentUser => _user;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  group('Messages Notification Dot & Badge Behavior Tests', () {
    setUp(() {
      MockDataConfig.debugOverride = true;
      MessageThread.resetMockThreads();
      MessageThread.clearSessionThreads();
    });

    tearDown(() {
      MockDataConfig.resetDebugOverride();
      MessageThread.resetMockThreads();
      MessageThread.clearSessionThreads();
    });

    testWidgets('Client FlashBottomNavBar has no dot or badge when unreadCount is 0',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FlashBottomNavBar(
              currentIndex: 0,
              onTap: (_) {},
              items: NavDestinationItem.clientDestinations,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Messages item should exist
      expect(find.text('Messages'), findsOneWidget);
      // No badge number should be displayed
      expect(find.text('2'), findsNothing);
      expect(find.text('1'), findsNothing);

      // Verify no circular notification dot is drawn inside the nav bar
      // (The dot is rendered as a 7x7 Container with a BoxShadow when hasNotificationBadge == true)
      final dotFinders = find.byWidgetPredicate((widget) {
        if (widget is Container && widget.decoration is BoxDecoration) {
          final box = widget.decoration as BoxDecoration;
          return box.shape == BoxShape.circle && (widget.constraints?.maxWidth == 7 || widget.constraints?.minWidth == 7);
        }
        return false;
      });
      expect(dotFinders, findsNothing);
    });

    testWidgets('Client FlashBottomNavBar suppresses notification dot on messages icon when hasNotificationBadge is true but active threads have 0 unread',
        (tester) async {
      MessageThread.mockThreads = [];
      MessageThread.clearSessionThreads();

      final itemsWithBadgeTrue = NavDestinationItem.clientDestinations.map((item) {
        if (item.route == '/client/messages') {
          return item.copyWith(
            hasNotificationBadge: true,
            badgeCount: null,
          );
        }
        return item;
      }).toList();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FlashBottomNavBar(
              currentIndex: 0,
              onTap: (_) {},
              items: itemsWithBadgeTrue,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Messages'), findsOneWidget);

      // Verify no circular notification dot is drawn inside the nav bar for messages
      final dotFinders = find.byWidgetPredicate((widget) {
        if (widget is Container && widget.decoration is BoxDecoration) {
          final box = widget.decoration as BoxDecoration;
          return box.shape == BoxShape.circle && (widget.constraints?.maxWidth == 7 || widget.constraints?.minWidth == 7);
        }
        return false;
      });
      expect(dotFinders, findsNothing);
    });

    testWidgets('Client FlashBottomNavBar displays badge when unreadCount > 0',
        (tester) async {
      final itemsWithUnread = NavDestinationItem.clientDestinations.map((item) {
        if (item.route == '/client/messages') {
          return item.copyWith(
            hasNotificationBadge: true,
            badgeCount: 3,
          );
        }
        return item;
      }).toList();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FlashBottomNavBar(
              currentIndex: 0,
              onTap: (_) {},
              items: itemsWithUnread,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Messages'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('ArtistTopBar hides dot/badge when unreadCount is 0',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ArtistTopBar(
              onMessagesTap: () {},
              onAvatarTap: () {},
              avatarChild: const CircleAvatar(),
              explicitUnreadCount: 0,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsOneWidget);
      // No badge number
      expect(find.text('1'), findsNothing);
      expect(find.text('2'), findsNothing);

      // Verify no notification dot (CircleAvatar or small container) is rendered on the messages icon
      final badgeFinders = find.descendant(
        of: find.byKey(const Key('top_action_messages_button')),
        matching: find.byType(Container),
      );
      // Only the outer 40x40 circle button container should exist
      expect(badgeFinders, findsOneWidget);
    });

    testWidgets('ArtistTopBar hides dot/badge when there are no messages and explicitUnreadCount is null',
        (tester) async {
      MessageThread.mockThreads = [];
      MessageThread.clearSessionThreads();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ArtistTopBar(
              onMessagesTap: () {},
              onAvatarTap: () {},
              avatarChild: const CircleAvatar(),
              artistId: 'test_artist_1',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsOneWidget);
      expect(find.text('1'), findsNothing);
      expect(find.text('2'), findsNothing);

      final badgeFinders = find.descendant(
        of: find.byKey(const Key('top_action_messages_button')),
        matching: find.byType(Container),
      );
      expect(badgeFinders, findsOneWidget);
    });

    testWidgets('ArtistTopBar displays numeric badge when unreadCount > 0',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ArtistTopBar(
              onMessagesTap: () {},
              onAvatarTap: () {},
              avatarChild: const CircleAvatar(),
              explicitUnreadCount: 4,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
    });

    testWidgets('Viewing a conversation thread marks it read and clears unread count',
        (tester) async {
      // Create a mock thread with 2 unread messages
      const testThreadId = 'test_thread_read_flow';
      final thread = MessageThread(
        id: testThreadId,
        artistId: 'test_artist_1',
        artistName: 'Sera Fox',
        artistAvatar: '',
        studioName: 'Foxglove Studio',
        lastMessage: 'Hello there!',
        lastMessageTime: DateTime.now(),
        unreadCount: 2,
        messages: [
          ChatMessage(
            id: 'm1',
            senderId: 'test_artist_1',
            senderName: 'Sera Fox',
            text: 'Hello there!',
            timestamp: DateTime.now(),
            isFromArtist: true,
          ),
        ],
      );

      MessageThread.mockThreads = [thread];
      expect(MessageThread.totalUnreadCount(), equals(2));

      // Open ChatConversationScreen with this thread
      await tester.pumpWidget(
        MaterialApp(
          home: ChatConversationScreen(thread: thread),
        ),
      );
      await tester.pumpAndSettle();

      // Post-frame callback should have executed marking thread read
      expect(MessageThread.totalUnreadCount(), equals(0));
      expect(MessageThread.mockThreads.first.unreadCount, equals(0));
    });

    testWidgets('MainFeedScreen dynamically updates bottom nav unread badge when thread is read',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Start with exactly 1 thread with 2 unread messages
      const testThreadId = 'single_unread_thread';
      final thread = MessageThread(
        id: testThreadId,
        artistId: 'test_artist_1',
        artistName: 'Sera Fox',
        artistAvatar: '',
        studioName: 'Foxglove Studio',
        lastMessage: 'Ready for your appointment?',
        lastMessageTime: DateTime.now(),
        unreadCount: 2,
      );
      MessageThread.mockThreads = [thread];

      await tester.pumpWidget(
        MaterialApp(
          home: MainFeedScreen(authService: FakeTestAuthService()),
        ),
      );
      await tester.pumpAndSettle();

      // Badge '2' should be visible on the Messages tab
      expect(find.text('2'), findsOneWidget);

      // Now simulate opening and reading the thread
      MessageThread.markThreadAsRead(testThreadId);
      await tester.pumpAndSettle();

      // Unread count is now 0, so badge '2' should disappear
      expect(find.text('2'), findsNothing);
    });
  });
}
