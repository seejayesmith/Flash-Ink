import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flash_ink/core/utils/device_corner_radius.dart';
import 'package:flash_ink/widgets/adaptive_glass_container.dart';

({BorderRadius radius, BorderSide side}) _expectSuperellipseSheet(WidgetTester tester) {
  expect(
    find.descendant(
      of: find.byType(AdaptiveGlassContainer),
      matching: find.byType(ClipRSuperellipse),
    ),
    findsOneWidget,
  );

  final containerFinder = find.descendant(
    of: find.byType(AdaptiveGlassContainer),
    matching: find.byType(Container),
  );
  final decorated = tester.widgetList<Container>(containerFinder).firstWhere(
    (c) => c.foregroundDecoration is ShapeDecoration,
  );
  final bgDecoration = decorated.decoration as ShapeDecoration;
  expect(bgDecoration.shape, isA<RoundedSuperellipseBorder>());

  final fgDecoration = decorated.foregroundDecoration as ShapeDecoration;
  final shape = fgDecoration.shape as RoundedSuperellipseBorder;
  return (
    radius: shape.borderRadius as BorderRadius,
    side: shape.side,
  );
}

void main() {
  group('AdaptiveGlassContainer.bottomSheet Bezel & Border Tests', () {
    testWidgets('Matches hardware corner curve on bezel-less device with home indicator', (tester) async {
      tester.view.physicalSize = const Size(1170, 2532); // iPhone 13/14 Pro (390 x 844 pt)
      tester.view.devicePixelRatio = 3.0;
      tester.view.padding = const FakeViewPadding(bottom: 102); // 34 pt bottom padding
      tester.view.viewPadding = const FakeViewPadding(bottom: 102); // 34 pt bottom viewPadding
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetPadding();
        tester.view.resetViewPadding();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return AdaptiveGlassContainer.bottomSheet(
                  glassEnabled: false,
                  child: const Text('Sheet Content'),
                );
              },
            ),
          ),
        ),
      );

      final (:radius, :side) = _expectSuperellipseSheet(tester);

      // 390x844 pt (47.33 pt raw) with 2.0 dp inset => 45.33 pt concentric bottom radius
      expect(radius.bottomLeft.x, closeTo(45.33, 0.01));
      expect(radius.bottomRight.x, closeTo(45.33, 0.01));
      expect(radius.topLeft.x, equals(28.0));
      expect(radius.topRight.x, equals(28.0));

      // Effective margin: 2.0 dp clearance inset to keep border inside hardware bezel
      expect(
        find.byWidgetPredicate(
          (w) => w is Padding && w.padding == const EdgeInsets.fromLTRB(2.0, 0, 2.0, 2.0),
        ),
        findsOneWidget,
      );

      // Border uses strokeAlignInside
      expect(side.strokeAlign, equals(BorderSide.strokeAlignInside));

      // Contains internal SafeArea
      expect(find.byType(SafeArea), findsWidgets);
    });

    testWidgets('Collapses bottom radius to 0 on square-screen devices (viewPadding.bottom == 0)', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      tester.view.padding = FakeViewPadding.zero;
      tester.view.viewPadding = FakeViewPadding.zero;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetPadding();
        tester.view.resetViewPadding();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return AdaptiveGlassContainer.bottomSheet(
                  glassEnabled: false,
                  child: const Text('Square Device Content'),
                );
              },
            ),
          ),
        ),
      );

      final (:radius, side: _) = _expectSuperellipseSheet(tester);

      expect(radius.bottomLeft.x, equals(0.0));
      expect(radius.bottomRight.x, equals(0.0));
      expect(
        find.byWidgetPredicate(
          (w) => w is Padding && w.padding == const EdgeInsets.fromLTRB(2.0, 0, 2.0, 0.0),
        ),
        findsOneWidget,
      );
    });

    testWidgets('Collapses bottom radius to 0 when keyboard is open (viewInsets.bottom > 0)', (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      tester.view.padding = const FakeViewPadding(bottom: 102);
      tester.view.viewPadding = const FakeViewPadding(bottom: 102);
      tester.view.viewInsets = const FakeViewPadding(bottom: 900); // 300 pt keyboard
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetPadding();
        tester.view.resetViewPadding();
        tester.view.resetViewInsets();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(390, 844),
              viewPadding: EdgeInsets.only(bottom: 34),
              viewInsets: EdgeInsets.only(bottom: 300),
            ),
            child: AdaptiveGlassContainer.bottomSheet(
              glassEnabled: false,
              child: const Text('Keyboard Open Content'),
            ),
          ),
        ),
      );

      final (:radius, side: _) = _expectSuperellipseSheet(tester);

      expect(radius.bottomLeft.x, equals(0.0));
      expect(radius.bottomRight.x, equals(0.0));
      expect(
        find.byWidgetPredicate(
          (w) => w is Padding && w.padding == const EdgeInsets.fromLTRB(2.0, 0, 2.0, 0.0),
        ),
        findsOneWidget,
      );

      // Verifies subtle hairline accent divider and keyboard spacer backdrop
      expect(find.byKey(const Key('sheet_keyboard_hairline_divider')), findsOneWidget);
      expect(find.byKey(const Key('sheet_keyboard_spacer')), findsOneWidget);
      final spacer = tester.widget<SizedBox>(find.byKey(const Key('sheet_keyboard_spacer')));
      expect(spacer.height, equals(300.0));
    });

    testWidgets('Does not render hairline divider or keyboard spacer when viewInsets.bottom == 0', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(390, 844),
              viewPadding: EdgeInsets.only(bottom: 34),
              viewInsets: EdgeInsets.zero,
            ),
            child: AdaptiveGlassContainer.bottomSheet(
              glassEnabled: false,
              child: Text('No Keyboard Content'),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('sheet_keyboard_hairline_divider')), findsNothing);
      expect(find.byKey(const Key('sheet_keyboard_spacer')), findsNothing);
    });

    testWidgets('Respects avoidKeyboard: false even when viewInsets.bottom > 0', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(390, 844),
              viewPadding: EdgeInsets.only(bottom: 34),
              viewInsets: EdgeInsets.only(bottom: 300),
            ),
            child: AdaptiveGlassContainer.bottomSheet(
              glassEnabled: false,
              avoidKeyboard: false,
              child: Text('Opt-out Content'),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('sheet_keyboard_hairline_divider')), findsNothing);
      expect(find.byKey(const Key('sheet_keyboard_spacer')), findsNothing);
    });

    testWidgets('Preserves custom padding on standard AdaptiveGlassContainer', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdaptiveGlassContainer(
              glassEnabled: false,
              padding: EdgeInsets.all(24.0),
              child: Text('Padded Content'),
            ),
          ),
        ),
      );

      final containerFinder = find.byWidgetPredicate(
        (w) => w is Container && w.padding == const EdgeInsets.all(24.0),
      );
      expect(containerFinder, findsOneWidget);
    });

    testWidgets('AdaptiveGlassContainer defaults to useGradient: false and renders with no gradient', (tester) async {
      const widget = AdaptiveGlassContainer(
        child: Text('Test'),
      );
      expect(widget.useGradient, isFalse);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdaptiveGlassContainer(
              glassEnabled: true,
              child: Text('Content'),
            ),
          ),
        ),
      );

      final containerFinder = find.descendant(
        of: find.byType(AdaptiveGlassContainer),
        matching: find.byType(Container),
      );
      final containers = tester.widgetList<Container>(containerFinder);
      final decoratedContainer = containers.firstWhere(
        (c) => c.decoration is BoxDecoration && (c.decoration as BoxDecoration).color != null,
      );
      final decoration = decoratedContainer.decoration as BoxDecoration;
      expect(decoration.gradient, isNull);
      expect(decoration.color, isNotNull);
    });

    testWidgets('Computes accurate concentric corner radii for modern device sizes', (tester) async {
      final cases = <(Size size, double expectedConcentric)>[
        (const Size(393, 852), 53.0), // 55.0 - 2.0 (iPhone 14 Pro / 15 / 16)
        (const Size(402, 874), 60.0), // 62.0 - 2.0 (iPhone 16 Pro / 17 / 17 Pro)
        (const Size(440, 956), 60.0), // 62.0 - 2.0 (iPhone 16 Pro Max / 17 Pro Max)
      ];

      for (final (size, expectedConcentric) in cases) {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                viewPadding: const EdgeInsets.only(bottom: 34),
              ),
              child: const AdaptiveGlassContainer.bottomSheet(
                glassEnabled: false,
                child: Text('Sized Sheet'),
              ),
            ),
          ),
        );

        final (:radius, side: _) = _expectSuperellipseSheet(tester);
        expect(radius.bottomLeft.x, closeTo(expectedConcentric, 0.01), reason: 'Failed for $size');
        expect(radius.bottomRight.x, closeTo(expectedConcentric, 0.01), reason: 'Failed for $size');
      }
    });

    testWidgets('Prefers MediaQuery.displayCornerRadii when provided (Android API 31+)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(412, 915),
              viewPadding: EdgeInsets.only(bottom: 24),
              displayCornerRadii: BorderRadius.only(
                topLeft: Radius.circular(40),
                topRight: Radius.circular(40),
                bottomLeft: Radius.circular(38),
                bottomRight: Radius.circular(36),
              ),
            ),
            child: AdaptiveGlassContainer.bottomSheet(
              glassEnabled: false,
              child: Text('Android 12+ Corner Radii'),
            ),
          ),
        ),
      );

      final (:radius, side: _) = _expectSuperellipseSheet(tester);
      expect(radius.bottomLeft.x, closeTo(36.0, 0.01)); // 38 - 2.0
      expect(radius.bottomRight.x, closeTo(34.0, 0.01)); // 36 - 2.0
    });

    testWidgets('Uses DeviceCornerRadius iOS native override and reacts to updates', (tester) async {
      addTearDown(DeviceCornerRadius.resetForTesting);
      DeviceCornerRadius.setTestingIosRadii((bottomLeft: 58.0, bottomRight: 58.0));

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.iOS),
          home: const MediaQuery(
            data: MediaQueryData(
              size: Size(402, 874),
              viewPadding: EdgeInsets.only(bottom: 34),
            ),
            child: AdaptiveGlassContainer.bottomSheet(
              glassEnabled: false,
              child: Text('iOS Concentric Sheet'),
            ),
          ),
        ),
      );

      var (:radius, side: _) = _expectSuperellipseSheet(tester);
      expect(radius.bottomLeft.x, closeTo(56.0, 0.01)); // 58 - 2.0
      expect(radius.bottomRight.x, closeTo(56.0, 0.01));

      DeviceCornerRadius.setTestingIosRadii((bottomLeft: 62.0, bottomRight: 62.0));
      await tester.pump();

      (:radius, side: _) = _expectSuperellipseSheet(tester);
      expect(radius.bottomLeft.x, closeTo(60.0, 0.01)); // 62 - 2.0
      expect(radius.bottomRight.x, closeTo(60.0, 0.01));
    });

    testWidgets('Tap inside sheet unfocuses field, and first barrier tap dismisses keyboard before closing', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () {
                    showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => AdaptiveGlassContainer.bottomSheet(
                        glassEnabled: false,
                        padding: const EdgeInsets.all(20),
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Sheet Header Area'),
                            SizedBox(height: 16),
                            TextField(key: Key('sheet_input')),
                          ],
                        ),
                      ),
                    );
                  },
                  child: const Text('Open Sheet'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();
      expect(find.text('Sheet Header Area'), findsOneWidget);

      bool hasEditableFocus() {
        final ctx = FocusManager.instance.primaryFocus?.context;
        if (ctx == null || !ctx.mounted) return false;
        return ctx.widget is EditableText ||
            ctx.findAncestorStateOfType<EditableTextState>() != null;
      }

      // Focus TextField
      await tester.tap(find.byKey(const Key('sheet_input')));
      await tester.pumpAndSettle();
      expect(hasEditableFocus(), isTrue);

      // Tap non-input area inside sheet -> dismisses keyboard while keeping sheet open
      await tester.tap(find.text('Sheet Header Area'));
      await tester.pumpAndSettle();
      expect(hasEditableFocus(), isFalse);
      expect(find.text('Sheet Header Area'), findsOneWidget);

      // Re-focus TextField
      await tester.tap(find.byKey(const Key('sheet_input')));
      await tester.pumpAndSettle();
      expect(hasEditableFocus(), isTrue);

      // First barrier tap dismisses keyboard only; sheet stays open
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();
      expect(hasEditableFocus(), isFalse);
      expect(find.text('Sheet Header Area'), findsOneWidget);

      // Second barrier tap closes the modal sheet
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();
      expect(find.text('Sheet Header Area'), findsNothing);
    });
  });
}


