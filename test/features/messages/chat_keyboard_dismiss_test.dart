import 'package:flash_ink/core/mock/mock_data_config.dart';
import 'package:flash_ink/features/messages/domain/models/message_thread.dart';
import 'package:flash_ink/features/messages/presentation/screens/chat_conversation_screen.dart';
import 'package:flash_ink/features/messages/presentation/screens/messages_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MessageThread buildSampleThread() {
    return MessageThread(
      id: 'thread_keyboard_test',
      artistId: 'artist_1',
      clientId: 'client_1',
      clientName: 'Maya Lin',
      artistName: 'Elena Vance',
      artistAvatar: '',
      studioName: 'Blackwork Studio',
      lastMessage: 'Looking forward to our session!',
      lastMessageTime: DateTime(2026, 11, 14, 15, 0),
      unreadCount: 0,
      flashTitleContext: 'Botanical Moth',
      messages: [
        ChatMessage(
          id: 'm_1',
          senderId: 'client_1',
          senderName: 'Maya Lin',
          text: 'Looking forward to our session!',
          timestamp: DateTime(2026, 11, 14, 15, 0),
          isFromArtist: false,
        ),
      ],
    );
  }

  bool isAnyEditableFocused(WidgetTester tester) {
    final editables = tester.widgetList<EditableText>(find.byType(EditableText));
    return editables.any((e) => e.focusNode.hasFocus);
  }

  group('Chat keyboard dismissal', () {
    setUp(() {
      MockDataConfig.debugOverride = false;
    });

    tearDown(() {
      MockDataConfig.resetDebugOverride();
    });

    testWidgets(
      'focusing artist chat shows collapse button and dismisses via button, tap outside, and pop',
      (tester) async {
        final thread = buildSampleThread();

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    key: const Key('open_chat_btn'),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => ChatConversationScreen(
                            thread: thread,
                            isArtistView: true,
                          ),
                        ),
                      );
                    },
                    child: const Text('Open Chat'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('open_chat_btn')));
        await tester.pumpAndSettle();

        // Initially unfocused -> collapse button hidden.
        expect(find.byKey(const Key('chat_collapse_keyboard_button')), findsNothing);
        expect(isAnyEditableFocused(tester), isFalse);

        // Tap TextField -> becomes focused and collapse button appears.
        await tester.tap(find.byType(TextField));
        await tester.pumpAndSettle();

        expect(isAnyEditableFocused(tester), isTrue);
        expect(tester.testTextInput.isVisible, isTrue);
        expect(find.byKey(const Key('chat_collapse_keyboard_button')), findsOneWidget);

        // 1. Tap collapse button -> unfocuses and hides keyboard.
        await tester.tap(find.byKey(const Key('chat_collapse_keyboard_button')));
        await tester.pumpAndSettle();

        expect(isAnyEditableFocused(tester), isFalse);
        expect(tester.testTextInput.isVisible, isFalse);
        expect(find.byKey(const Key('chat_collapse_keyboard_button')), findsNothing);

        // Focus again, then 2. Tap outside on message list -> unfocuses and hides keyboard.
        await tester.tap(find.byType(TextField));
        await tester.pumpAndSettle();
        expect(isAnyEditableFocused(tester), isTrue);
        expect(tester.testTextInput.isVisible, isTrue);

        await tester.tap(find.text('Looking forward to our session!'));
        await tester.pumpAndSettle();

        expect(isAnyEditableFocused(tester), isFalse);
        expect(tester.testTextInput.isVisible, isFalse);

        // Focus again, then 3. Navigate back -> unfocuses and hides keyboard.
        await tester.tap(find.byType(TextField));
        await tester.pumpAndSettle();
        expect(isAnyEditableFocused(tester), isTrue);
        expect(tester.testTextInput.isVisible, isTrue);

        await tester.tap(find.byKey(const Key('chat_back_button')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('open_chat_btn')), findsOneWidget);
        expect(isAnyEditableFocused(tester), isFalse);
        expect(tester.testTextInput.isVisible, isFalse);
        expect(
          FocusManager.instance.primaryFocus is FocusScopeNode ||
              FocusManager.instance.primaryFocus == null,
          isTrue,
        );
      },
    );

    testWidgets(
      'navigating MessagesScreen -> ChatConversationScreen and popping back leaves all fields unfocused',
      (tester) async {
        final thread = buildSampleThread();

        await tester.pumpWidget(
          MaterialApp(
            home: MessagesScreen(
              mockThreads: [thread],
              showBackButton: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Focus the search field on MessagesScreen before opening a thread.
        await tester.tap(find.byType(TextField));
        await tester.pumpAndSettle();
        expect(isAnyEditableFocused(tester), isTrue);
        expect(tester.testTextInput.isVisible, isTrue);

        // Tap the thread tile -> should unfocus search field and open ChatConversationScreen.
        await tester.tap(find.text('Elena Vance'));
        await tester.pumpAndSettle();

        expect(find.byType(ChatConversationScreen), findsOneWidget);
        expect(isAnyEditableFocused(tester), isFalse);
        expect(tester.testTextInput.isVisible, isFalse);

        // Focus chat TextField.
        await tester.tap(find.byType(TextField));
        await tester.pumpAndSettle();
        expect(isAnyEditableFocused(tester), isTrue);
        expect(tester.testTextInput.isVisible, isTrue);

        // Pop back to MessagesScreen.
        await tester.tap(find.byKey(const Key('chat_back_button')));
        await tester.pumpAndSettle();

        expect(find.byType(MessagesScreen), findsOneWidget);
        expect(find.byType(ChatConversationScreen), findsNothing);
        expect(isAnyEditableFocused(tester), isFalse);
        expect(tester.testTextInput.isVisible, isFalse);
      },
    );
  });
}
