import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flash_ink/widgets/flash_snack_bar.dart';

void main() {
  group('FlashSnackBar Widget Tests', () {
    test('sanitizeMessage strips technical exception prefixes', () {
      expect(FlashSnackBar.sanitizeMessage('Exception: Invalid phone number'), 'Invalid phone number');
      expect(FlashSnackBar.sanitizeMessage('FirebaseException: [auth/user-not-found] User not found'), '[auth/user-not-found] User not found');
      expect(FlashSnackBar.sanitizeMessage('Simple error occurred'), 'Simple error occurred');
    });

    testWidgets('showError displays floating red SnackBar with icon and close button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  FlashSnackBar.showError(context, 'Exception: Verification failed');
                },
                child: const Text('Show Error'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Error'));
      await tester.pump(); // Start animation
      await tester.pump(const Duration(milliseconds: 750)); // Complete slide up

      expect(find.byType(SnackBar), findsOneWidget);
      final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(snackBar.behavior, SnackBarBehavior.floating);
      expect(snackBar.backgroundColor, FlashSnackBar.errorColor);
      expect(snackBar.showCloseIcon, isTrue);
      expect(snackBar.closeIconColor, Colors.white);
      expect(find.text('Verification failed'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);

      // Tap close button
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 750)); // Finish dismiss animation

      expect(find.text('Verification failed'), findsNothing);
    });

    testWidgets('showSuccess displays floating green SnackBar with check icon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  FlashSnackBar.showSuccess(context, 'Profile updated successfully');
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
      final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(snackBar.backgroundColor, FlashSnackBar.successColor);
      expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);
      expect(find.text('Profile updated successfully'), findsOneWidget);
    });

    testWidgets('showInfo displays floating dark SnackBar with info icon', (tester) async {
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
      final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(snackBar.backgroundColor, FlashSnackBar.infoColor);
      expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);
      expect(find.text('Feature coming soon'), findsOneWidget);
    });

    testWidgets('Clears active snackbar before presenting a new one', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Column(
                children: [
                  ElevatedButton(
                    onPressed: () => FlashSnackBar.showError(context, 'First error'),
                    child: const Text('First'),
                  ),
                  ElevatedButton(
                    onPressed: () => FlashSnackBar.showError(context, 'Second error'),
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
