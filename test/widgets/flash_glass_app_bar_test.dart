import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flash_ink/theme/app_theme.dart';
import 'package:flash_ink/widgets/flash_glass_app_bar.dart';
import 'package:flash_ink/widgets/skip_pill_button.dart';

void main() {
  group('FlashGlassAppBar', () {
    testWidgets('defaults to transparent with 0 blur and no BackdropFilter', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            appBar: FlashGlassAppBar(
              title: Text('Title'),
            ),
          ),
        ),
      );

      final backdropFilterFinder = find.byType(BackdropFilter);
      expect(backdropFilterFinder, findsNothing);

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.backgroundColor, equals(Colors.transparent));
      expect(appBar.elevation, equals(0));
    });

    testWidgets('renders BackdropFilter with frosted glass blur when blurSigma is explicitly set', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            appBar: FlashGlassAppBar(
              title: Text('Title'),
              blurSigma: AppTheme.glassBlurSigma,
            ),
          ),
        ),
      );

      final backdropFilterFinder = find.byType(BackdropFilter);
      expect(backdropFilterFinder, findsOneWidget);

      final backdropFilter = tester.widget<BackdropFilter>(backdropFilterFinder);
      expect(
        backdropFilter.filter,
        equals(ImageFilter.blur(sigmaX: AppTheme.glassBlurSigma, sigmaY: AppTheme.glassBlurSigma)),
      );
    });

    testWidgets('renders default back button and invokes onBackPressed', (tester) async {
      bool backPressed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: FlashGlassAppBar(
              showBackButton: true,
              onBackPressed: () => backPressed = true,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(backPressed, isTrue);
    });

    testWidgets('hides back button when showBackButton is false', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            appBar: FlashGlassAppBar(
              showBackButton: false,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.arrow_back), findsNothing);
    });

    testWidgets('renders SkipPillButton when onSkipPressed is provided', (tester) async {
      bool skipPressed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: FlashGlassAppBar(
              onSkipPressed: () => skipPressed = true,
              skipButtonText: 'Skip',
            ),
          ),
        ),
      );

      expect(find.byType(SkipPillButton), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);

      await tester.tap(find.byType(SkipPillButton));
      await tester.pumpAndSettle();

      expect(skipPressed, isTrue);
    });

    testWidgets('renders custom actions and custom leading', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            appBar: FlashGlassAppBar(
              leading: Icon(Icons.close),
              actions: [
                Icon(Icons.check),
              ],
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsNothing);
    });
  });
}
