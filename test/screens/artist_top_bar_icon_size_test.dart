import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';

import 'package:flash_ink/core/mock/mock_data_config.dart';
import 'package:flash_ink/screens/artist_dashboard/artist_dashboard_screen.dart';
import 'package:flash_ink/screens/artist_dashboard/artist_books_screen.dart';
import 'package:flash_ink/screens/artist_dashboard/artist_calendar_screen.dart';
import 'package:flash_ink/screens/artist_dashboard/artist_collections_screen.dart';
import 'package:flash_ink/screens/artist_dashboard/artist_earnings_screen.dart';
import 'package:flash_ink/services/auth_service.dart';
import 'package:flash_ink/widgets/artist_top_bar.dart';
import 'package:flash_ink/widgets/flash_mark_icon.dart';
import 'package:flash_ink/widgets/user_avatar.dart';

class MockUser extends Fake implements User {
  @override
  final String uid = 'test_artist';
  @override
  final String? displayName = 'OddMaree';
  @override
  final String? email = 'artist@test.com';
}

class FakeAuthService extends AuthService {
  final MockUser _user = MockUser();

  @override
  User? get currentUser => _user;
}

FlashMarkIcon _findFlashMarkByKey(
  WidgetTester tester,
  Key key, {
  Finder? scope,
}) {
  final keyFinder = (scope != null
          ? find.descendant(of: scope, matching: find.byKey(key))
          : find.byKey(key))
      .hitTestable();
  expect(keyFinder, findsOneWidget);
  final widget = tester.widget(keyFinder);
  if (widget is FlashMarkIcon) {
    return widget;
  }
  final descendant = find.descendant(
    of: keyFinder,
    matching: find.byType(FlashMarkIcon),
  );
  expect(descendant, findsOneWidget);
  return tester.widget<FlashMarkIcon>(descendant);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  group('Artist Top Left FlashMarkIcon Size & Navigation Tests', () {
    setUp(() {
      MockDataConfig.debugOverride = true;
    });

    tearDown(() {
      MockDataConfig.resetDebugOverride();
    });

    testWidgets(
        'ArtistDashboardScreen tab 0 has FlashMarkIcon matching avatar height and shifted right',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ArtistDashboardScreen(
            authService: FakeAuthService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final icon = _findFlashMarkByKey(
        tester,
        const Key('tattoo_machine_logo'),
      );
      expect(icon.size, equals(36));

      final topBarFinder = find.ancestor(
        of: find.byKey(const Key('tattoo_machine_logo')).hitTestable(),
        matching: find.byType(ArtistTopBar),
      );
      final topBarRect = tester.getRect(topBarFinder);
      final markRect = tester.getRect(find.byType(FlashMarkIcon).hitTestable());
      final avatarRect = tester.getRect(
        find.descendant(
          of: topBarFinder,
          matching: find.byType(UserAvatar),
        ),
      );

      expect(markRect.height, equals(avatarRect.height));
      expect(markRect.left - topBarRect.left, equals(16.0));
    });

    testWidgets(
        'ArtistDashboardScreen messages screen has FlashMarkIcon size 36 and tapping it returns to dashboard tab 0',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ArtistDashboardScreen(
            authService: FakeAuthService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('top_action_messages_button')));
      await tester.pumpAndSettle();

      final icon = _findFlashMarkByKey(
        tester,
        const Key('messages_tattoo_machine_logo'),
      );
      expect(icon.size, equals(36));
      expect(
        find.byKey(const Key('messages_artist_avatar_button')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('messages_tattoo_machine_logo')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('messages_tattoo_machine_logo')),
        findsNothing,
      );
      expect(
        tester.widget<IndexedStack>(find.byType(IndexedStack)).index,
        equals(0),
      );
    });

    testWidgets('ArtistCalendarScreen has FlashMarkIcon with size 36',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ArtistCalendarScreen(
            authService: FakeAuthService(),
            isEmbeddedInTab: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final icon = _findFlashMarkByKey(
        tester,
        const Key('calendar_tattoo_machine_logo'),
      );
      expect(icon.size, equals(36));
    });

    testWidgets('ArtistBooksScreen has FlashMarkIcon with size 36',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ArtistBooksScreen(
              authService: FakeAuthService(),
              isEmbeddedInTab: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final icon = _findFlashMarkByKey(
        tester,
        const Key('tattoo_machine_logo'),
      );
      expect(icon.size, equals(36));
    });

    testWidgets('ArtistEarningsScreen has FlashMarkIcon with size 36',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ArtistEarningsScreen(
            authService: FakeAuthService(),
            isEmbeddedInTab: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final icon = _findFlashMarkByKey(
        tester,
        const Key('earnings_tattoo_logo'),
      );
      expect(icon.size, equals(36));
    });

    testWidgets(
        'Tapping top-left FlashMarkIcon on Calendar, Collections, Books, and Earnings tabs navigates to Dashboard tab 0',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ArtistDashboardScreen(
            authService: FakeAuthService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final tabsToCheck = <(int, Key, Type)>[
        (1, const Key('calendar_tattoo_machine_logo'), ArtistCalendarScreen),
        (2, const Key('collections_tattoo_machine_logo'), ArtistCollectionsScreen),
        (3, const Key('tattoo_machine_logo'), ArtistBooksScreen),
        (4, const Key('earnings_tattoo_logo'), ArtistEarningsScreen),
      ];

      for (final (tabIndex, logoKey, screenType) in tabsToCheck) {
        await tester.tap(find.byKey(Key('nav_item_$tabIndex')));
        await tester.pumpAndSettle();

        final stack = tester.widget<IndexedStack>(find.byType(IndexedStack));
        expect(stack.index, equals(tabIndex));

        final screenFinder = find.byType(screenType);
        final icon = _findFlashMarkByKey(
          tester,
          logoKey,
          scope: screenFinder,
        );
        expect(icon.size, equals(36));

        final target = find.descendant(
          of: screenFinder,
          matching: find.byKey(logoKey),
        );
        await tester.tap(target);
        await tester.pumpAndSettle();

        final updatedStack =
            tester.widget<IndexedStack>(find.byType(IndexedStack));
        expect(updatedStack.index, equals(0));
      }
    });
  });
}
