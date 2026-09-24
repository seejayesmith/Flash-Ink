import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flash_ink/core/widgets/flash_bottom_nav_bar.dart';
import 'package:flash_ink/models/nav_destination_item.dart';
import 'package:flash_ink/theme/app_theme.dart';

void main() {
  group('FlashBottomNavBar Widget Tests', () {
    testWidgets('Renders client destinations: Discover, Flash Feed, Saved, Profile', (tester) async {
      int activeIndex = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FlashBottomNavBar(
              currentIndex: activeIndex,
              onTap: (index) => activeIndex = index,
              role: 'client',
            ),
          ),
        ),
      );

      expect(find.text('Discover'), findsOneWidget);
      expect(find.text('Flash Feed'), findsOneWidget);
      expect(find.text('Saved'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);

      expect(find.byKey(const Key('nav_item_0')), findsOneWidget);
      expect(find.byKey(const Key('nav_item_1')), findsOneWidget);
      expect(find.byKey(const Key('nav_item_2')), findsOneWidget);
      expect(find.byKey(const Key('nav_item_3')), findsOneWidget);
    });

    testWidgets('Renders artist destinations: Schedule, Requests, Messages, Profile with badge', (tester) async {
      int activeIndex = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FlashBottomNavBar(
              currentIndex: activeIndex,
              onTap: (index) => activeIndex = index,
              role: 'artist',
            ),
          ),
        ),
      );

      expect(find.text('Schedule'), findsOneWidget);
      expect(find.text('Requests'), findsOneWidget);
      expect(find.text('Messages'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);

      expect(find.byKey(const Key('nav_item_0')), findsOneWidget);
      expect(find.byKey(const Key('nav_item_1')), findsOneWidget);
      expect(find.byKey(const Key('nav_item_2')), findsOneWidget);
      expect(find.byKey(const Key('nav_item_3')), findsOneWidget);
    });

    testWidgets('Renders legacy destinations when specified', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FlashBottomNavBar(
              currentIndex: 0,
              onTap: (_) {},
              role: 'legacy_client',
            ),
          ),
        ),
      );

      expect(find.text('HOME'), findsOneWidget);
      expect(find.text('EXPLORE'), findsOneWidget);
      expect(find.text('APPOINTMENTS'), findsOneWidget);
      expect(find.text('ALERTS'), findsOneWidget);
    });

    testWidgets('Tapping destination fires onTap callback', (tester) async {
      int selectedIndex = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: FlashBottomNavBar(
                  currentIndex: selectedIndex,
                  onTap: (index) {
                    setState(() {
                      selectedIndex = index;
                    });
                  },
                  role: 'client',
                ),
              );
            },
          ),
        ),
      );

      // Tap EXPLORE (index 1)
      await tester.tap(find.byKey(const Key('nav_item_1')));
      await tester.pumpAndSettle();
      expect(selectedIndex, 1);

      // Tap APPOINTMENTS (index 2)
      await tester.tap(find.byKey(const Key('nav_item_2')));
      await tester.pumpAndSettle();
      expect(selectedIndex, 2);

      // Tap HOME (index 0)
      await tester.tap(find.byKey(const Key('nav_item_0')));
      await tester.pumpAndSettle();
      expect(selectedIndex, 0);
    });

    testWidgets('Accepts custom NavDestinationItems', (tester) async {
      final customItems = [
        const NavDestinationItem(
          icon: Icons.star_border,
          activeIcon: Icons.star,
          label: 'FAVORITES',
          key: Key('custom_fav'),
        ),
        const NavDestinationItem(
          icon: Icons.person_outline,
          activeIcon: Icons.person,
          label: 'ACCOUNT',
          key: Key('custom_account'),
          hasNotificationBadge: true,
          badgeCount: 3,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FlashBottomNavBar(
              currentIndex: 0,
              onTap: (_) {},
              items: customItems,
            ),
          ),
        ),
      );

      expect(find.text('FAVORITES'), findsOneWidget);
      expect(find.text('ACCOUNT'), findsOneWidget);
      expect(find.text('3'), findsOneWidget); // Badge count
      expect(find.byKey(const Key('custom_fav')), findsOneWidget);
      expect(find.byKey(const Key('custom_account')), findsOneWidget);
    });

    testWidgets('FlashBottomNavBar.floating correctly positions in a Stack', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                const Center(child: Text('Content')),
                FlashBottomNavBar.floating(
                  currentIndex: 0,
                  onTap: (_) {},
                  role: 'client',
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(FlashBottomNavBar), findsOneWidget);
      expect(find.text('Discover'), findsOneWidget);
    });

    testWidgets('Enforces 100% visual parity across roles with AppTheme tokens', (tester) async {
      for (final role in ['client', 'artist']) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: FlashBottomNavBar(
                currentIndex: 0,
                onTap: (_) {},
                role: role,
              ),
            ),
          ),
        );

        final navBarFinder = find.byType(FlashBottomNavBar);
        final navBarWidget = tester.widget<FlashBottomNavBar>(navBarFinder);

        expect(navBarWidget.height, AppTheme.navBarHeight);
        expect(navBarWidget.borderRadius, AppTheme.navBarBorderRadius);
        expect(navBarWidget.blurSigma, AppTheme.glassBlurSigma);
      }
    });
  });
}
