import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flash_ink/widgets/scaffold_with_nav_bar.dart';

void main() {
  group('ScaffoldWithNavBar Shell Navigation Tests', () {
    testWidgets('Switches tabs and preserves scroll position across tab switches', (tester) async {
      final scrollController = ScrollController();

      final pages = [
        ListView.builder(
          key: const Key('tab_0_list'),
          controller: scrollController,
          itemCount: 100,
          itemBuilder: (context, index) => ListTile(
            title: Text('Item $index'),
          ),
        ),
        const Center(
          key: Key('tab_1_content'),
          child: Text('Tab 1 Content'),
        ),
        const Center(
          key: Key('tab_2_content'),
          child: Text('Tab 2 Content'),
        ),
        const Center(
          key: Key('tab_3_content'),
          child: Text('Tab 3 Content'),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: ScaffoldWithNavBar(
            pages: pages,
            role: 'client',
          ),
        ),
      );

      // Verify Tab 0 is active
      expect(find.text('Item 0'), findsOneWidget);

      // Scroll down in Tab 0
      scrollController.jumpTo(500.0);
      await tester.pumpAndSettle();
      expect(scrollController.offset, 500.0);

      // Switch to Tab 1 (EXPLORE)
      await tester.tap(find.byKey(const Key('nav_item_1')));
      await tester.pumpAndSettle();

      expect(find.text('Tab 1 Content'), findsOneWidget);

      // Switch back to Tab 0 (HOME)
      await tester.tap(find.byKey(const Key('nav_item_0')));
      await tester.pumpAndSettle();

      // Verify scroll position was preserved!
      expect(scrollController.offset, 500.0);
    });

    testWidgets('Controlled mode triggers onDestinationSelected callback', (tester) async {
      int selectedTab = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return ScaffoldWithNavBar(
                currentIndex: selectedTab,
                onDestinationSelected: (index) {
                  setState(() {
                    selectedTab = index;
                  });
                },
                role: 'artist',
                pages: const [
                  Center(child: Text('Bookings View')),
                  Center(child: Text('Calendar View')),
                  Center(child: Text('Messages View')),
                  Center(child: Text('Earnings View')),
                ],
              );
            },
          ),
        ),
      );

      expect(find.text('Bookings View'), findsOneWidget);

      // Tap CALENDAR
      await tester.tap(find.byKey(const Key('nav_item_1')));
      await tester.pumpAndSettle();

      expect(selectedTab, 1);
      expect(find.text('Calendar View'), findsOneWidget);
    });
  });
}
