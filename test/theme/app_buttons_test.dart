import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flash_ink/theme/app_buttons.dart';

void main() {
  group('AppButtons', () {
    testWidgets(
      'enforces 16dp horizontal padding and FittedBox scaleDown on all CTA variants',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 310,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: AppButtons.primaryCTA(
                            onPressed: () {},
                            text: 'Open to Public Now',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: AppButtons.secondaryCTA(
                            onPressed: () {},
                            text: 'Review Requests (0)',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: 150,
                      child: AppButtons.destructiveCTA(
                        onPressed: () {},
                        icon: Icons.delete_outline,
                        text: 'Cancel Appointment',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(AppButtons.ctaHorizontalPadding, 16.0);

        final fittedBoxes = tester.widgetList<FittedBox>(find.byType(FittedBox));
        expect(fittedBoxes.length, 3);
        for (final box in fittedBoxes) {
          expect(box.fit, BoxFit.scaleDown);
        }

        // Verify text stays inset by at least 16dp from button edges
        final primaryButtonRect = tester.getRect(find.byType(ElevatedButton).first);
        final primaryTextRect = tester.getRect(find.text('Open to Public Now'));
        expect(primaryTextRect.left - primaryButtonRect.left, greaterThanOrEqualTo(16.0));
        expect(primaryButtonRect.right - primaryTextRect.right, greaterThanOrEqualTo(16.0));

        final secondaryButtonRect = tester.getRect(find.byType(OutlinedButton).first);
        final secondaryTextRect = tester.getRect(find.text('Review Requests (0)'));
        expect(secondaryTextRect.left - secondaryButtonRect.left, greaterThanOrEqualTo(16.0));
        expect(secondaryButtonRect.right - secondaryTextRect.right, greaterThanOrEqualTo(16.0));
      },
    );
  });
}
