import 'package:flash_ink/core/mock/mock_data_config.dart';
import 'package:flash_ink/features/messages/domain/models/message_thread.dart';
import 'package:flash_ink/features/messages/presentation/screens/chat_conversation_screen.dart';
import 'package:flash_ink/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    MockDataConfig.debugOverride = false;
  });

  tearDown(() {
    MockDataConfig.resetDebugOverride();
  });

  testWidgets('chat input placeholder and text are vertically centered inside pill', (tester) async {
    final thread = MessageThread(
      id: 'thread_align_test',
      artistId: 'artist_1',
      clientId: 'client_1',
      clientName: 'Maya Lin',
      artistName: 'goatdaddy',
      artistAvatar: '',
      studioName: 'Blackwork Studio',
      lastMessage: 'Hello',
      lastMessageTime: DateTime(2026, 11, 14, 15, 0),
      unreadCount: 0,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme(),
        home: ChatConversationScreen(
          thread: thread,
          isArtistView: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final textFieldFinder = find.byType(TextField);
    expect(textFieldFinder, findsOneWidget);

    final pillFinder = find.byKey(const Key('chat_input_pill'));
    expect(pillFinder, findsOneWidget);

    // Attach clip sits inside the input pill.
    expect(
      find.descendant(
        of: pillFinder,
        matching: find.byKey(const Key('chat_attach_button')),
      ),
      findsOneWidget,
    );

    // Send button starts muted/disabled while draft is empty.
    final sendButtonEmpty =
        tester.widget<IconButton>(find.byKey(const Key('chat_send_button')));
    expect(sendButtonEmpty.onPressed, isNull);

    final hintFinder = find.text('Type a message to goatdaddy...');
    expect(hintFinder, findsOneWidget);

    final pillRect = tester.getRect(pillFinder);
    final hintRect = tester.getRect(hintFinder);
    final topGap = hintRect.top - pillRect.top;
    final bottomGap = pillRect.bottom - hintRect.bottom;

    expect((topGap - bottomGap).abs(), lessThanOrEqualTo(3.0));

    // Tapping inside the pill focuses the TextField, centers entered text, and activates Send.
    await tester.tap(textFieldFinder);
    await tester.enterText(textFieldFinder, 'Hello!');
    await tester.pumpAndSettle();

    final sendButtonActive =
        tester.widget<IconButton>(find.byKey(const Key('chat_send_button')));
    expect(sendButtonActive.onPressed, isNotNull);

    final editableFinder = find.byType(EditableText);
    expect(editableFinder, findsOneWidget);
    final editableRect = tester.getRect(editableFinder);
    final textTopGap = editableRect.top - pillRect.top;
    final textBottomGap = pillRect.bottom - editableRect.bottom;

    expect((textTopGap - textBottomGap).abs(), lessThanOrEqualTo(3.0));
  });
}
