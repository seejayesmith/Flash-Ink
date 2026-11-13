import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flash_ink/theme/app_spacing.dart';
import 'package:flash_ink/theme/app_theme.dart';
import 'package:flash_ink/widgets/flash_snack_bar.dart';

void main() {
  group('FlashSnackBar Widget Tests', () {
    test('sanitizeMessage strips technical exception prefixes', () {
      expect(
        FlashSnackBar.sanitizeMessage('Exception: Invalid phone number'),
        'Invalid phone number',
      );
      expect(
        FlashSnackBar.sanitizeMessage(
          'FirebaseException: [auth/user-not-found] User not found',
        ),
        '[auth/user-not-found] User not found',
      );
      expect(
        FlashSnackBar.sanitizeMessage('Simple error occurred'),
        'Simple error occurred',
      );
    });

    testWidgets(
      'showError displays floating glassmorphic SnackBar with error accent and close button',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    FlashSnackBar.showError(
                      context,
                      'Exception: Verification failed',
                    );
                  },
                  child: const Text('Show Error'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Show Error'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 750));

        expect(find.byType(SnackBar), findsOneWidget);
        final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
        expect(snackBar.behavior, SnackBarBehavior.floating);
        expect(snackBar.backgroundColor, Colors.transparent);
        expect(snackBar.elevation, 0);
        expect(find.text('Verification failed'), findsOneWidget);

        final errorIcon = tester.widget<Icon>(
          find.byIcon(Icons.error_outline_rounded),
        );
        expect(errorIcon.color, FlashSnackBar.errorColor);
        expect(find.byIcon(Icons.close), findsOneWidget);

        await tester.tap(find.byIcon(Icons.close));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 750));

        expect(find.text('Verification failed'), findsNothing);
      },
    );

    testWidgets(
      'showSuccess displays floating glassmorphic SnackBar with check icon',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    FlashSnackBar.showSuccess(
                      context,
                      'Profile updated successfully',
                    );
                  },
                  child: const Text('Show Success'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Show Success'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 750));

        expect(find.byType(SnackBar), findsOneWidget);
        final successIcon = tester.widget<Icon>(
          find.byIcon(Icons.check_circle_outline_rounded),
        );
        expect(successIcon.color, FlashSnackBar.successColor);
        expect(find.text('Profile updated successfully'), findsOneWidget);
      },
    );

    testWidgets(
      'showInfo displays floating glassmorphic SnackBar with gold info icon',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    FlashSnackBar.showInfo(context, 'Feature coming soon');
                  },
                  child: const Text('Show Info'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Show Info'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 750));

        expect(find.byType(SnackBar), findsOneWidget);
        final infoIcon = tester.widget<Icon>(
          find.byIcon(Icons.info_outline_rounded),
        );
        expect(infoIcon.color, FlashSnackBar.infoColor);
        expect(find.text('Feature coming soon'), findsOneWidget);
      },
    );

    testWidgets(
      'offsets bottom margin above floating nav bar when FlashNavBarScope is present',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: FlashNavBarScope(
                child: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () {
                      FlashSnackBar.showSuccess(context, 'Date unblocked.');
                    },
                    child: const Text('Trigger'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Trigger'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 750));

        final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
        final expectedBottom = AppTheme.navBarHeight +
            AppTheme.navBarBottomMargin +
            AppSpacing.spaceSm;
        expect(
          snackBar.margin,
          EdgeInsets.fromLTRB(
            AppSpacing.screenGutter,
            0,
            AppSpacing.screenGutter,
            expectedBottom,
          ),
        );
      },
    );

    testWidgets(
      'renders action button inside SnackBar and invokes callback',
      (tester) async {
        var actionTapped = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    FlashSnackBar.showInfo(
                      context,
                      'Verification required',
                      action: SnackBarAction(
                        label: 'Verify',
                        onPressed: () => actionTapped = true,
                      ),
                    );
                  },
                  child: const Text('Trigger'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Trigger'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 750));

        expect(find.text('Verify'), findsOneWidget);
        await tester.tap(find.text('Verify'));
        await tester.pumpAndSettle();

        expect(actionTapped, isTrue);
      },
    );

    testWidgets('Clears active snackbar before presenting a new one', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Column(
                children: [
                  ElevatedButton(
                    onPressed: () =>
                        FlashSnackBar.showError(context, 'First error'),
                    child: const Text('First'),
                  ),
                  ElevatedButton(
                    onPressed: () =>
                        FlashSnackBar.showError(context, 'Second error'),
                    child: const Text('Second'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('First'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 750));
      expect(find.text('First error'), findsOneWidget);

      await tester.tap(find.text('Second'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 750));
      expect(find.text('Second error'), findsOneWidget);
      expect(find.text('First error'), findsNothing);
    });
  });
}
