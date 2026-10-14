import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:flash_ink/screens/aesthetics_selection_screen.dart';
import 'package:flash_ink/screens/main_feed_screen.dart';
import 'package:flash_ink/widgets/adaptive_glass_container.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await Firebase.initializeApp();
  });

  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.physicalSize = const Size(1080, 2400);
    binding.platformDispatcher.views.first.devicePixelRatio = 1.0;
  });

  tearDown(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.resetPhysicalSize();
    binding.platformDispatcher.views.first.resetDevicePixelRatio();
  });

  group('AestheticsSelectionScreen Tests', () {
    testWidgets(
      'No aesthetic is selected by default and CTA button is disabled initially',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: AestheticsSelectionScreen(isGuest: false),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Verify header and all options rendered
        expect(find.text('Choose your aesthetics'), findsOneWidget);
        expect(find.text('TRADITIONAL'), findsOneWidget);
        expect(find.text('FINE LINE'), findsOneWidget);
        expect(find.text('JAPANESE'), findsOneWidget);
        expect(find.text('REALISM'), findsOneWidget);
        expect(find.text('BLACKWORK'), findsOneWidget);
        expect(find.text('WATERCOLOR'), findsOneWidget);

        // 2. Verify no checkmarks are present initially
        expect(find.byIcon(Icons.check_circle), findsNothing);

        // 3. Verify all AdaptiveGlassContainers have isSelected = false
        final glassContainers = tester.widgetList<AdaptiveGlassContainer>(
          find.byType(AdaptiveGlassContainer),
        );
        for (final container in glassContainers) {
          expect(container.isSelected, isFalse);
        }

        // 4. Verify CTA button is disabled initially
        final finishElevatedButton = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'FINISH'),
        );
        expect(finishElevatedButton.onPressed, isNull);
      },
    );

    testWidgets(
      'Requires user to select at least one: CTA toggles enabled/disabled with selection',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: AestheticsSelectionScreen(isGuest: false),
          ),
        );
        await tester.pumpAndSettle();

        // Initially disabled
        var finishButton = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'FINISH'),
        );
        expect(finishButton.onPressed, isNull);

        // Tap TRADITIONAL to select it
        await tester.tap(find.text('TRADITIONAL'));
        await tester.pumpAndSettle();

        // Now one checkmark is present
        expect(find.byIcon(Icons.check_circle), findsOneWidget);

        // CTA button is now enabled
        finishButton = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'FINISH'),
        );
        expect(finishButton.onPressed, isNotNull);

        // Tap TRADITIONAL again to deselect
        await tester.tap(find.text('TRADITIONAL'));
        await tester.pumpAndSettle();

        // No checkmarks and CTA is disabled again
        expect(find.byIcon(Icons.check_circle), findsNothing);
        finishButton = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'FINISH'),
        );
        expect(finishButton.onPressed, isNull);

        // Select multiple aesthetics: FINE LINE and JAPANESE
        await tester.tap(find.text('FINE LINE'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('JAPANESE'));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.check_circle), findsNWidgets(2));
        finishButton = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'FINISH'),
        );
        expect(finishButton.onPressed, isNotNull);
      },
    );

    testWidgets(
      'Back button is present and pops the screen',
      (WidgetTester tester) async {
        final backButtonKey = const Key('aesthetics_back_button');

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AestheticsSelectionScreen(isGuest: false),
                      ),
                    );
                  },
                  child: const Text('Go to Aesthetics'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Navigate to AestheticsSelectionScreen
        await tester.tap(find.text('Go to Aesthetics'));
        await tester.pumpAndSettle();

        expect(find.byType(AestheticsSelectionScreen), findsOneWidget);

        // Verify back button is visible
        final backFinder = find.byKey(backButtonKey);
        expect(backFinder, findsOneWidget);
        expect(find.byIcon(Icons.arrow_back), findsOneWidget);

        // Tap back button
        await tester.tap(backFinder);
        await tester.pumpAndSettle();

        // AestheticsSelectionScreen is popped, back to initial screen
        expect(find.byType(AestheticsSelectionScreen), findsNothing);
        expect(find.text('Go to Aesthetics'), findsOneWidget);
      },
    );

    testWidgets(
      'Guest mode displays DONE and back button works',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AestheticsSelectionScreen(isGuest: true),
                      ),
                    );
                  },
                  child: const Text('Go to Guest Aesthetics'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Go to Guest Aesthetics'));
        await tester.pumpAndSettle();

        // Verify CTA button text is DONE in guest mode
        var doneButton = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'DONE'),
        );
        expect(doneButton.onPressed, isNull);

        // Select an aesthetic to enable DONE
        await tester.tap(find.text('REALISM'));
        await tester.pumpAndSettle();

        doneButton = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'DONE'),
        );
        expect(doneButton.onPressed, isNotNull);

        // Back button is present and pops back
        final backFinder = find.byKey(const Key('aesthetics_back_button'));
        expect(backFinder, findsOneWidget);
        await tester.tap(backFinder);
        await tester.pumpAndSettle();

        expect(find.byType(AestheticsSelectionScreen), findsNothing);
      },
    );

    testWidgets(
      'Tapping enabled FINISH navigates to MainFeedScreen',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: AestheticsSelectionScreen(isGuest: false),
          ),
        );
        await tester.pumpAndSettle();

        // Select an aesthetic
        await tester.tap(find.text('TRADITIONAL'));
        await tester.pumpAndSettle();

        // Tap FINISH
        await tester.tap(find.text('FINISH'));
        await tester.pumpAndSettle();

        // Verifies navigation to MainFeedScreen
        expect(find.byType(AestheticsSelectionScreen), findsNothing);
        expect(find.byType(MainFeedScreen), findsOneWidget);
      },
    );
  });
}
