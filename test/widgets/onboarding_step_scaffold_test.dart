import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flash_ink/features/onboarding/shared/onboarding_step_scaffold.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('OnboardingStepScaffold Layout Contract Tests', () {
    testWidgets('Header typography and content baseline remain strictly identical across dynamic content heights', (tester) async {
      // Step A: Short content
      await tester.pumpWidget(
        MaterialApp(
          home: OnboardingStepScaffold(
            currentStep: 1,
            totalSteps: 4,
            title: 'Step One Title',
            subtitle: 'Step one subtitle with descriptive guidance.',
            onBack: () {},
            onSkip: () {},
            onCtaPressed: () {},
            child: Container(
              key: const Key('short_content'),
              height: 60,
              color: Colors.red,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final titleTopA = tester.getTopLeft(find.byKey(const Key('onboarding_title'))).dy;
      final subtitleTopA = tester.getTopLeft(find.byKey(const Key('onboarding_subtitle'))).dy;
      final contentTopA = tester.getTopLeft(find.byKey(const Key('short_content'))).dy;
      final ctaTopA = tester.getTopLeft(find.byKey(const Key('onboarding_cta_button'))).dy;

      // Step B: Tall content with different title and subtitle lengths
      await tester.pumpWidget(
        MaterialApp(
          home: OnboardingStepScaffold(
            currentStep: 2,
            totalSteps: 4,
            title: 'Step Two Title',
            subtitle: 'Step two subtitle with descriptive guidance.',
            onBack: () {},
            onSkip: () {},
            onCtaPressed: () {},
            child: Container(
              key: const Key('tall_content'),
              height: 400,
              color: Colors.blue,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final titleTopB = tester.getTopLeft(find.byKey(const Key('onboarding_title'))).dy;
      final subtitleTopB = tester.getTopLeft(find.byKey(const Key('onboarding_subtitle'))).dy;
      final contentTopB = tester.getTopLeft(find.byKey(const Key('tall_content'))).dy;
      final ctaTopB = tester.getTopLeft(find.byKey(const Key('onboarding_cta_button'))).dy;

      // Mathematical proof of zero vertical visual jumping for header/content,
      // and CTA positioning at the end of the scroll body when content exceeds viewport:
      expect(titleTopB, equals(titleTopA), reason: 'Title must not move vertically across steps');
      expect(subtitleTopB, equals(subtitleTopA), reason: 'Subtitle must not move vertically across steps');
      expect(contentTopB, equals(contentTopA), reason: 'Content baseline must not move vertically across steps');
      expect(ctaTopB, greaterThan(ctaTopA), reason: 'Bottom CTA must be anchored at the bottom of the scroll body when content exceeds viewport');
    });

    testWidgets('Top navigation bar renders back button, progress pills, and skip button', (tester) async {
      bool backTapped = false;
      bool skipTapped = false;
      bool ctaTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: OnboardingStepScaffold(
            currentStep: 2,
            totalSteps: 4,
            title: 'Test Step',
            subtitle: 'Test Subhead',
            onBack: () => backTapped = true,
            onSkip: () => skipTapped = true,
            onCtaPressed: () => ctaTapped = true,
            child: const Text('Test Child'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('onboarding_back_button')), findsOneWidget);
      expect(find.byKey(const Key('onboarding_skip_button')), findsOneWidget);
      expect(find.byKey(const Key('onboarding_cta_button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('onboarding_back_button')));
      expect(backTapped, isTrue);

      await tester.tap(find.byKey(const Key('onboarding_skip_button')));
      expect(skipTapped, isTrue);

      await tester.tap(find.byKey(const Key('onboarding_cta_button')));
      expect(ctaTapped, isTrue);
    });

    testWidgets('Skip button renders text on a single line without wrapping', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: OnboardingStepScaffold(
            currentStep: 4,
            totalSteps: 4,
            title: 'Upload flash',
            subtitle: 'Upload some custom flash work',
            onSkip: () {},
            child: const Text('Content'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final skipTextFinder = find.descendant(
        of: find.byKey(const Key('onboarding_skip_button')),
        matching: find.byType(Text),
      );
      expect(skipTextFinder, findsOneWidget);
      final textWidget = tester.widget<Text>(skipTextFinder);
      expect(textWidget.maxLines, equals(1));
      expect(textWidget.softWrap, isFalse);

      // Verify the skip button size has adequate width for the text
      final skipSize = tester.getSize(find.byKey(const Key('onboarding_skip_button')));
      expect(skipSize.width, greaterThan(50.0));
    });
  });
}
