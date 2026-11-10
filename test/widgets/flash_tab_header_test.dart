import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flash_ink/core/mock/mock_data_config.dart';
import 'package:flash_ink/features/appointments/presentation/screens/appointments_screen.dart';
import 'package:flash_ink/features/explore/presentation/screens/explore_screen.dart';
import 'package:flash_ink/features/messages/presentation/screens/messages_screen.dart';
import 'package:flash_ink/screens/browse_artists_screen.dart';
import 'package:flash_ink/widgets/flash_tab_header.dart';

void main() {
  setUp(() {
    MockDataConfig.debugOverride = true;
  });

  tearDown(() {
    MockDataConfig.resetDebugOverride();
  });

  group('FlashTabHeader Unit & Widget Tests', () {
    testWidgets('Renders title with standardized 30pt bold typography', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FlashTabHeader(
              title: 'Standard Header',
            ),
          ),
        ),
      );

      final textFinder = find.text('Standard Header');
      expect(textFinder, findsOneWidget);

      final textWidget = tester.widget<Text>(textFinder);
      expect(textWidget.style?.fontSize, 30);
      expect(textWidget.style?.fontWeight, FontWeight.bold);
      expect(textWidget.style?.letterSpacing, -0.5);
    });

    testWidgets('Renders titleAccessory and trailing action', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FlashTabHeader(
              title: 'Explore',
              titleAccessory: Container(
                key: const Key('test_accessory'),
                child: const Text('Accessory'),
              ),
              action: IconButton(
                key: const Key('test_action'),
                icon: const Icon(Icons.star),
                onPressed: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Explore'), findsOneWidget);
      expect(find.byKey(const Key('test_accessory')), findsOneWidget);
      expect(find.byKey(const Key('test_action')), findsOneWidget);
    });

    testWidgets('Renders multiple trailing actions when provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FlashTabHeader(
              title: 'Feed',
              actions: [
                IconButton(
                  key: const Key('action_1'),
                  icon: const Icon(Icons.notifications),
                  onPressed: () {},
                ),
                IconButton(
                  key: const Key('action_2'),
                  icon: const Icon(Icons.bookmark),
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Feed'), findsOneWidget);
      expect(find.byKey(const Key('action_1')), findsOneWidget);
      expect(find.byKey(const Key('action_2')), findsOneWidget);
    });
  });

  group('Standardized Client Tabs Header Consistency Tests', () {
    testWidgets('BrowseArtistsScreen uses standardized 30pt FlashTabHeader with avatar button', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: BrowseArtistsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FlashTabHeader), findsOneWidget);
      expect(find.text('Browse Artists'), findsOneWidget);
      expect(find.byKey(const Key('client_avatar_button')), findsOneWidget);

      final textWidget = tester.widget<Text>(find.text('Browse Artists'));
      expect(textWidget.style?.fontSize, 30);
      expect(textWidget.style?.fontWeight, FontWeight.bold);
    });

    testWidgets('ExploreScreen uses standardized 30pt FlashTabHeader with location pill and bookmark', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: ExploreScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FlashTabHeader), findsOneWidget);
      expect(find.text('Explore'), findsOneWidget);
      expect(find.byKey(const Key('explore_bookmark_button')), findsOneWidget);

      final textWidget = tester.widget<Text>(find.text('Explore'));
      expect(textWidget.style?.fontSize, 30);
      expect(textWidget.style?.fontWeight, FontWeight.bold);
    });

    testWidgets('AppointmentsScreen uses standardized 30pt FlashTabHeader', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AppointmentsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FlashTabHeader), findsOneWidget);
      expect(find.text('Appointments'), findsOneWidget);

      final textWidget = tester.widget<Text>(find.text('Appointments'));
      expect(textWidget.style?.fontSize, 30);
      expect(textWidget.style?.fontWeight, FontWeight.bold);
    });

    testWidgets('MessagesScreen uses standardized 30pt FlashTabHeader', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MessagesScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FlashTabHeader), findsOneWidget);
      expect(find.text('Messages'), findsOneWidget);

      final textWidget = tester.widget<Text>(find.text('Messages'));
      expect(textWidget.style?.fontSize, 30);
      expect(textWidget.style?.fontWeight, FontWeight.bold);
    });
  });
}
