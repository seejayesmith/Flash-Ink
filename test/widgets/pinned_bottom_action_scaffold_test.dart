import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flash_ink/widgets/pinned_bottom_action_scaffold.dart';

void main() {
  group('PinnedBottomActionScaffold Widget Tests', () {
    testWidgets('Renders content in SingleChildScrollView and primary CTA outside of it', (tester) async {
      bool ctaPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: PinnedBottomActionScaffold(
            ctaKey: const Key('test_cta_button'),
            ctaText: 'SUBMIT FORM',
            onCtaPressed: () => ctaPressed = true,
            child: Column(
              children: List.generate(
                20,
                (i) => SizedBox(height: 50, child: Text('Item $i')),
              ),
            ),
          ),
        ),
      );

      // Verify scrollable items are rendered
      expect(find.text('Item 0'), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsOneWidget);

      // Verify CTA is found on screen
      final ctaFinder = find.byKey(const Key('test_cta_button'));
      expect(ctaFinder, findsOneWidget);
      expect(find.text('SUBMIT FORM'), findsOneWidget);

      // CRITICAL: CTA must NOT be inside SingleChildScrollView
      final scrollFinder = find.byType(SingleChildScrollView);
      expect(find.descendant(of: scrollFinder, matching: ctaFinder), findsNothing);

      // Tap CTA
      await tester.tap(ctaFinder);
      expect(ctaPressed, isTrue);
    });

    testWidgets('Respects isCtaEnabled: false and isCtaLoading: true', (tester) async {
      bool ctaPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: PinnedBottomActionScaffold(
            ctaKey: const Key('disabled_cta'),
            ctaText: 'DISABLED',
            isCtaEnabled: false,
            onCtaPressed: () => ctaPressed = true,
            child: const Text('Content'),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('disabled_cta')));
      expect(ctaPressed, isFalse);

      // Loading state
      await tester.pumpWidget(
        MaterialApp(
          home: PinnedBottomActionScaffold(
            ctaKey: const Key('loading_cta'),
            ctaText: 'LOADING',
            isCtaLoading: true,
            onCtaPressed: () => ctaPressed = true,
            child: const Text('Content'),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.byKey(const Key('loading_cta')));
      expect(ctaPressed, isFalse);
    });

    testWidgets('Secondary action is placed in pinned bottom bar outside scroll view', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PinnedBottomActionScaffold(
            ctaKey: const Key('primary_action'),
            ctaText: 'VERIFY',
            onCtaPressed: () {},
            secondaryAction: const Text('Resend verification code'),
            child: const Text('Body Content'),
          ),
        ),
      );

      final scrollFinder = find.byType(SingleChildScrollView);
      final secondaryFinder = find.text('Resend verification code');

      expect(secondaryFinder, findsOneWidget);
      expect(find.descendant(of: scrollFinder, matching: secondaryFinder), findsNothing);
    });

    testWidgets('Renders docked bar with divider when isDocked is true', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PinnedBottomActionScaffold(
            isDocked: true,
            ctaText: 'SAVE PROFILE',
            onCtaPressed: () {},
            child: const Text('Profile Body'),
          ),
        ),
      );

      // Check docked container styling
      final dockedContainerFinder = find.byWidgetPredicate((widget) {
        if (widget is Container && widget.decoration is BoxDecoration) {
          final box = widget.decoration as BoxDecoration;
          return box.color == const Color(0xFF151717) && box.border?.top.color == const Color(0xFF262929);
        }
        return false;
      });

      expect(dockedContainerFinder, findsOneWidget);
    });

    testWidgets('Renders CTA inline inside SingleChildScrollView when inlineCTA is true (Option C)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PinnedBottomActionScaffold(
            inlineCTA: true,
            ctaKey: const Key('inline_test_cta'),
            ctaText: 'SAVE INLINE',
            onCtaPressed: () {},
            child: const Text('Inline Body Content'),
          ),
        ),
      );

      final scrollFinder = find.byType(SingleChildScrollView);
      final ctaFinder = find.byKey(const Key('inline_test_cta'));

      expect(scrollFinder, findsOneWidget);
      expect(ctaFinder, findsOneWidget);
      // CTA must be rendered inline inside SingleChildScrollView
      expect(find.descendant(of: scrollFinder, matching: ctaFinder), findsOneWidget);
    });

    testWidgets('Renders full-bleed background in Stack when provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PinnedBottomActionScaffold(
            background: const SizedBox.expand(key: Key('custom_background')),
            child: const Text('Foreground Content'),
          ),
        ),
      );

      expect(find.byKey(const Key('custom_background')), findsOneWidget);
      expect(
        find.ancestor(
          of: find.byKey(const Key('custom_background')),
          matching: find.byType(Stack),
        ),
        findsOneWidget,
      );
    });

    testWidgets('Dynamically expands scroll padding for keyboard insets while CTA stays at bottom', (tester) async {
      // Test with zero keyboard inset
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(viewInsets: EdgeInsets.zero),
            child: PinnedBottomActionScaffold(
              ctaText: 'CONTINUE',
              child: Text('Content'),
            ),
          ),
        ),
      );

      SingleChildScrollView scroll = tester.widget<SingleChildScrollView>(find.byType(SingleChildScrollView));
      final baseBottomPadding = (scroll.padding as EdgeInsets).bottom;

      // Now simulate software keyboard opening with 300px bottom inset
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(viewInsets: EdgeInsets.only(bottom: 300)),
            child: PinnedBottomActionScaffold(
              ctaText: 'CONTINUE',
              child: Text('Content'),
            ),
          ),
        ),
      );

      scroll = tester.widget<SingleChildScrollView>(find.byType(SingleChildScrollView));
      final keyboardBottomPadding = (scroll.padding as EdgeInsets).bottom;

      // Bottom padding should have increased by 300px
      expect(keyboardBottomPadding, equals(baseBottomPadding + 300.0));

      // Scaffold resizeToAvoidBottomInset must remain false
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.resizeToAvoidBottomInset, isFalse);
    });

    testWidgets('Renders iOS keyboard accessory toolbar with Done button when keyboard is open on iOS and dismisses focus on tap', (tester) async {
      final focusNode = FocusNode();

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.iOS),
          home: MediaQuery(
            data: const MediaQueryData(viewInsets: EdgeInsets.only(bottom: 300)),
            child: PinnedBottomActionScaffold(
              ctaText: 'CONTINUE',
              child: TextField(
                focusNode: focusNode,
              ),
            ),
          ),
        ),
      );

      // Verify iOS accessory toolbar Done button is present when keyboardInset > 0 on iOS
      final doneButtonFinder = find.byKey(const Key('scaffold_collapse_keyboard_button'));
      expect(doneButtonFinder, findsOneWidget);
      expect(find.text('Done'), findsOneWidget);

      // Focus the text field
      focusNode.requestFocus();
      await tester.pump();
      expect(focusNode.hasFocus, isTrue);

      // Tap the Done button
      await tester.tap(doneButtonFinder);
      await tester.pump();

      // Verify focus is dismissed
      expect(focusNode.hasFocus, isFalse);
    });

    testWidgets('Does not render iOS keyboard accessory toolbar on Android', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.android),
          home: MediaQuery(
            data: const MediaQueryData(viewInsets: EdgeInsets.only(bottom: 300)),
            child: PinnedBottomActionScaffold(
              ctaText: 'CONTINUE',
              child: const TextField(),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('scaffold_collapse_keyboard_button')), findsNothing);
      expect(find.text('Done'), findsNothing);
    });

    testWidgets('Tapping outside on empty space unfocuses active input (tap-out to collapse)', (tester) async {
      final focusNode = FocusNode();

      await tester.pumpWidget(
        MaterialApp(
          home: PinnedBottomActionScaffold(
            ctaText: 'CONTINUE',
            child: SizedBox(
              height: 400,
              child: Column(
                children: [
                  TextField(focusNode: focusNode),
                  const Spacer(),
                  const Text('Empty Area Below'),
                ],
              ),
            ),
          ),
        ),
      );

      focusNode.requestFocus();
      await tester.pump();
      expect(focusNode.hasFocus, isTrue);

      // Tap empty area below text field
      await tester.tap(find.text('Empty Area Below'));
      await tester.pump();

      expect(focusNode.hasFocus, isFalse);
    });
  });
}
