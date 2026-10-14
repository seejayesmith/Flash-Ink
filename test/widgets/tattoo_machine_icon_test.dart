import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flash_ink/widgets/tattoo_machine_icon.dart';

void main() {
  group('TattooMachineIcon Tests', () {
    testWidgets('renders SvgPicture with default values', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TattooMachineIcon(
              key: Key('test_tattoo_icon'),
            ),
          ),
        ),
      );

      final iconFinder = find.byKey(const Key('test_tattoo_icon'));
      expect(iconFinder, findsOneWidget);

      final svgFinder = find.descendant(
        of: iconFinder,
        matching: find.byType(SvgPicture),
      );
      expect(svgFinder, findsOneWidget);

      final svgWidget = tester.widget<SvgPicture>(svgFinder);
      expect(svgWidget.width, 24.0);
      expect(svgWidget.height, 24.0);
    });

    testWidgets('renders SvgPicture with custom size and color', (tester) async {
      const customColor = Colors.red;
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TattooMachineIcon(
              key: Key('custom_tattoo_icon'),
              size: 46.0,
              color: customColor,
            ),
          ),
        ),
      );

      final iconFinder = find.byKey(const Key('custom_tattoo_icon'));
      expect(iconFinder, findsOneWidget);

      final svgFinder = find.descendant(
        of: iconFinder,
        matching: find.byType(SvgPicture),
      );
      expect(svgFinder, findsOneWidget);

      final svgWidget = tester.widget<SvgPicture>(svgFinder);
      expect(svgWidget.width, 46.0);
      expect(svgWidget.height, 46.0);
    });
  });
}
