import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flash_ink/widgets/flash_mark_icon.dart';

void main() {
  group('FlashMarkIcon Tests', () {
    testWidgets('renders PNG image asset with default size 36 and left alignment',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FlashMarkIcon(
              key: Key('test_flash_mark_icon'),
            ),
          ),
        ),
      );

      final iconFinder = find.byKey(const Key('test_flash_mark_icon'));
      expect(iconFinder, findsOneWidget);

      final imageFinder = find.descendant(
        of: iconFinder,
        matching: find.byType(Image),
      );
      expect(imageFinder, findsOneWidget);

      final imageWidget = tester.widget<Image>(imageFinder);
      expect(imageWidget.height, 36.0);
      expect(imageWidget.width, closeTo(36.0 * (79.0 / 142.0), 0.01));
      expect(imageWidget.alignment, Alignment.centerLeft);
      expect(imageWidget.fit, BoxFit.contain);
      expect(imageWidget.color, isNull);
      expect(
        imageWidget.image,
        equals(const AssetImage('assets/images/flash_f_icon.png')),
      );
    });

    testWidgets('renders Image with custom size and width', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FlashMarkIcon(
              key: Key('custom_flash_mark_icon'),
              size: 32.0,
              width: 20.0,
              alignment: Alignment.center,
            ),
          ),
        ),
      );

      final iconFinder = find.byKey(const Key('custom_flash_mark_icon'));
      final imageFinder = find.descendant(
        of: iconFinder,
        matching: find.byType(Image),
      );
      final imageWidget = tester.widget<Image>(imageFinder);
      expect(imageWidget.height, 32.0);
      expect(imageWidget.width, 20.0);
      expect(imageWidget.alignment, Alignment.center);
    });
  });
}
