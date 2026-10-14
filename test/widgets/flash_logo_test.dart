import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flash_ink/widgets/flash_logo.dart';
import 'package:flash_ink/widgets/tattoo_machine_icon.dart';

void main() {
  group('FlashLogo Tests', () {
    testWidgets('renders Flash text and TattooMachineIcon with calibrated proportions', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FlashLogo(
              fontSize: 76.0,
            ),
          ),
        ),
      );

      expect(find.byType(FlashLogo), findsOneWidget);
      expect(find.text('Flash'), findsOneWidget);
      expect(find.byType(TattooMachineIcon), findsOneWidget);

      final iconFinder = find.byType(TattooMachineIcon);
      final iconWidget = tester.widget<TattooMachineIcon>(iconFinder);

      // Verify proportional sizing:
      // gunHeight = 76 * 0.82 = 62.32
      // gunWidth = gunHeight * (60 / 69) = 54.19
      expect(iconWidget.height, closeTo(62.32, 0.1));
      expect(iconWidget.width, closeTo(54.19, 0.1));
      expect(iconWidget.alignment, Alignment.topLeft);
    });

    testWidgets('supports custom font size and shadows', (tester) async {
      const customShadow = [
        Shadow(
          color: Colors.black,
          blurRadius: 10,
          offset: Offset(0, 2),
        ),
      ];

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FlashLogo(
              fontSize: 64.0,
              color: Color(0xFFEEC200),
              shadows: customShadow,
            ),
          ),
        ),
      );

      expect(find.byType(FlashLogo), findsOneWidget);
      expect(find.text('Flash'), findsOneWidget);

      final textWidget = tester.widget<Text>(find.text('Flash'));
      expect(textWidget.style?.fontSize, 64.0);
      expect(textWidget.style?.color, const Color(0xFFEEC200));
      expect(textWidget.style?.shadows, customShadow);

      final iconWidget = tester.widget<TattooMachineIcon>(find.byType(TattooMachineIcon));
      expect(iconWidget.height, closeTo(64.0 * 0.82, 0.1));
    });
  });
}
