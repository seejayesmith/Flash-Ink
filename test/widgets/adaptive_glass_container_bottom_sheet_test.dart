import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flash_ink/widgets/adaptive_glass_container.dart';

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

      final containerFinder = find.byType(Container);
      expect(containerFinder, findsWidgets);

      // Find the container with decoration
      final containers = tester.widgetList<Container>(containerFinder);
      final decoratedContainer = containers.firstWhere(
        (c) => c.decoration is BoxDecoration,
      );

      final decoration = decoratedContainer.decoration as BoxDecoration;
      final borderRadius = decoration.borderRadius as BorderRadius;

      // 844 pt height with bottom padding => 50.0 pt corner radius
      expect(borderRadius.bottomLeft.x, equals(50.0));
      expect(borderRadius.bottomRight.x, equals(50.0));
      expect(borderRadius.topLeft.x, equals(28.0));
      expect(borderRadius.topRight.x, equals(28.0));

      // Effective margin: 1px inset to keep border inside hardware curve
      expect(
        find.byWidgetPredicate((w) => w is Padding && w.padding == const EdgeInsets.fromLTRB(1.0, 0, 1.0, 1.0)),
        findsOneWidget,
      );

      // Border uses strokeAlignInside
      final border = decoration.border as Border;
      expect(border.top.strokeAlign, equals(BorderSide.strokeAlignInside));

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

      final containerFinder = find.byType(Container);
      final containers = tester.widgetList<Container>(containerFinder);
      final decoratedContainer = containers.firstWhere(
        (c) => c.decoration is BoxDecoration,
      );

      final decoration = decoratedContainer.decoration as BoxDecoration;
      final borderRadius = decoration.borderRadius as BorderRadius;

      expect(borderRadius.bottomLeft.x, equals(0.0));
      expect(borderRadius.bottomRight.x, equals(0.0));
      expect(
        find.byWidgetPredicate((w) => w is Padding && w.padding == const EdgeInsets.fromLTRB(1.0, 0, 1.0, 0.0)),
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

      final containerFinder = find.byType(Container);
      final containers = tester.widgetList<Container>(containerFinder);
      final decoratedContainer = containers.firstWhere(
        (c) => c.decoration is BoxDecoration,
      );

      final decoration = decoratedContainer.decoration as BoxDecoration;
      final borderRadius = decoration.borderRadius as BorderRadius;

      expect(borderRadius.bottomLeft.x, equals(0.0));
      expect(borderRadius.bottomRight.x, equals(0.0));
      expect(
        find.byWidgetPredicate((w) => w is Padding && w.padding == const EdgeInsets.fromLTRB(1.0, 0, 1.0, 0.0)),
        findsOneWidget,
      );
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
  });
}


