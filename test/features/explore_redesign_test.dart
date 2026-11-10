import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flash_ink/core/utils/distance_calculator.dart';
import 'package:flash_ink/features/explore/presentation/screens/explore_screen.dart';
import 'package:flash_ink/features/explore/presentation/screens/saved_bookmarks_screen.dart';
import 'package:flash_ink/features/studios/studio_map_screen.dart';
import 'package:flash_ink/providers/app_providers.dart';
import 'package:flash_ink/widgets/outward_reveal_route.dart';
import 'package:flash_ink/widgets/artist_card.dart';
import 'package:flash_ink/widgets/flash_card.dart';

void main() {
  group('Explore Page Top Redesign Tests', () {
    testWidgets(
      'Renders bookmark button at top right and removes old avatar button',
      (tester) async {
        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              home: ExploreScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Top right actions: Notification bell and Bookmark tab icon
        expect(find.byKey(const Key('explore_bookmark_button')), findsOneWidget);
        expect(find.byIcon(Icons.bookmark_outline_rounded), findsOneWidget);
        expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);

        // Previous avatar button is removed
        expect(find.byKey(const Key('discover_avatar_button')), findsNothing);

        // Previous top bar map button is removed
        expect(find.byKey(const Key('explore_studio_map_button')), findsNothing);
      },
    );

    testWidgets(
      'Renders shortened search bar alongside the larger map tab icon',
      (tester) async {
        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              home: ExploreScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Search text field
        expect(find.byType(TextField), findsOneWidget);
        expect(find.text('Search artists, styles, studios...'), findsOneWidget);

        // Map tab icon button beside search bar
        final mapButton = find.byKey(const Key('explore_map_tab_button'));
        expect(mapButton, findsOneWidget);

        // Verify map icon is map_outlined and size is 28
        final mapIconFinder = find.descendant(
          of: mapButton,
          matching: find.byIcon(Icons.map_outlined),
        );
        expect(mapIconFinder, findsOneWidget);
        final mapIcon = tester.widget<Icon>(mapIconFinder);
        expect(mapIcon.size, 28);
      },
    );

    testWidgets(
      'Tapping bookmark tab icon navigates to SavedBookmarksScreen',
      (tester) async {
        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              home: ExploreScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final bookmarkButton = find.byKey(const Key('explore_bookmark_button'));
        await tester.tap(bookmarkButton);
        await tester.pumpAndSettle();

        expect(find.byType(SavedBookmarksScreen), findsOneWidget);
        expect(find.text('Saved & Bookmarks'), findsOneWidget);
      },
    );

    testWidgets(
      'Tapping map tab icon navigates to StudioMapScreen with autoCenterOnUserLocation enabled',
      (tester) async {
        const testCoords = GeoPointCoords(latitude: 45.3001, longitude: -122.9731);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              effectiveClientCoordinatesProvider.overrideWithValue(testCoords),
            ],
            child: const MaterialApp(
              home: ExploreScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final mapButton = find.byKey(const Key('explore_map_tab_button'));
        await tester.tap(mapButton);
        await tester.pumpAndSettle();

        expect(find.byType(StudioMapScreen), findsOneWidget);
        final mapScreen =
            tester.widget<StudioMapScreen>(find.byType(StudioMapScreen));
        expect(mapScreen.autoCenterOnUserLocation, isTrue);
        expect(mapScreen.initialCenter?.latitude, equals(45.3001));
        expect(mapScreen.initialCenter?.longitude, equals(-122.9731));
      },
    );

    testWidgets(
      'SavedBookmarksScreen displays segmented tabs and toggles between Artists and Flash',
      (tester) async {
        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              home: SavedBookmarksScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify segmented tab buttons
        expect(find.byKey(const Key('bookmarks_tab_artists')), findsOneWidget);
        expect(find.byKey(const Key('bookmarks_tab_flash')), findsOneWidget);

        // Default tab is Artists
        expect(find.byKey(const Key('saved_artists_list')), findsOneWidget);
        expect(find.byType(ArtistCard), findsWidgets);

        // Switch to Flash tab
        await tester.tap(find.byKey(const Key('bookmarks_tab_flash')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('saved_flash_list')), findsOneWidget);
        expect(find.byType(FlashCard), findsWidgets);
      },
    );

    testWidgets(
      'OutwardRevealPageRoute animates cleanly without errors',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      OutwardRevealPageRoute(
                        origin: const Offset(200, 100),
                        page: const Scaffold(body: Text('Map Target')),
                      ),
                    );
                  },
                  child: const Text('Go'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Go'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        await tester.pumpAndSettle();

        expect(find.text('Map Target'), findsOneWidget);
      },
    );

    testWidgets(
      'Does not render Delete Account button on ExploreScreen (only in App Settings)',
      (tester) async {
        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              home: ExploreScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('delete_account_button')), findsNothing);
        expect(find.text('Delete Account'), findsNothing);
      },
    );
  });
}
