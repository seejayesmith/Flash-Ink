import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flash_ink/widgets/flash_logo.dart';

void main() {
  group('FlashLogo Tests', () {
    testWidgets('renders logo image asset with proportional default sizing', (tester) async {
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
      final imageFinder = find.image(const AssetImage(FlashLogo.assetPath));
      expect(imageFinder, findsOneWidget);

      final imageWidget = tester.widget<Image>(find.byType(Image));
      final expectedHeight = 76.0 * 1.89;
      final expectedWidth = expectedHeight * (464.0 / 296.0);
      expect(imageWidget.height, closeTo(expectedHeight, 0.1));
      expect(imageWidget.width, closeTo(expectedWidth, 0.1));
      expect(imageWidget.fit, BoxFit.contain);
      expect(imageWidget.semanticLabel, 'Flash');
    });

    testWidgets('scales width and height proportionally for custom fontSize', (tester) async {
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
      expect(find.image(const AssetImage(FlashLogo.assetPath)), findsOneWidget);

      final imageWidget = tester.widget<Image>(find.byType(Image));
      final expectedHeight = 64.0 * 1.89;
      final expectedWidth = expectedHeight * (464.0 / 296.0);
      expect(imageWidget.height, closeTo(expectedHeight, 0.1));
      expect(imageWidget.width, closeTo(expectedWidth, 0.1));
    });
  });
}
