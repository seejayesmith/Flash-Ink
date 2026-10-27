import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flash_ink/theme/app_spacing.dart';
import 'package:flash_ink/theme/app_buttons.dart';
import 'package:flash_ink/widgets/flow_page_layout.dart';
import 'package:flash_ink/screens/artist_onboarding/artist_info_screen.dart';
import 'package:flash_ink/screens/artist_onboarding/artist_set_price_screen.dart';
import 'package:flash_ink/screens/artist_onboarding/artist_flash_upload_screen.dart';
import 'package:flash_ink/screens/account_creation_screen.dart';

void main() {
  group('FlowPageLayout & AppSpacing Consistency Tests', () {
    test('AppSpacing and AppPadding tokens match specification', () {
      expect(AppSpacing.screenGutter, equals(12.0));
      expect(AppSpacing.screenMargin, equals(12.0));
      expect(AppSpacing.cardPadding, equals(16.0));
      expect(AppSpacing.headerTop, equals(24.0));
      expect(AppSpacing.headerTitleSubtitleGap, equals(8.0));
      expect(AppSpacing.headerContentGap, equals(24.0));
      expect(AppSpacing.ctaHeight, equals(52.0));
      expect(AppSpacing.ctaBottomPadding, equals(16.0));

      expect(AppPadding.screenHorizontal.left, equals(12.0));
      expect(AppPadding.screenHorizontal.right, equals(12.0));
      expect(AppPadding.card.top, equals(16.0));
      expect(AppButtons.ctaHeightPrimary, equals(52.0));
    });

    testWidgets('FlowPageLayout renders title, subtitle, content and anchored CTA with proper structure', (tester) async {
      bool ctaPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FlowPageLayout(
              title: 'Test Title',
              subtitle: 'Test Subtitle',
              ctaText: 'CONTINUE',
              onCtaPressed: () => ctaPressed = true,
              child: const SizedBox(height: 100, child: Text('Content')),
            ),
          ),
        ),
      );

      // Verify header elements
      expect(find.text('Test Title'), findsOneWidget);
      expect(find.text('Test Subtitle'), findsOneWidget);
      expect(find.text('Content'), findsOneWidget);

      // Verify CTA button
      expect(find.text('CONTINUE'), findsOneWidget);
      await tester.tap(find.text('CONTINUE'));
      expect(ctaPressed, isTrue);

      // Verify that CTA is outside the SingleChildScrollView
      final scrollFinder = find.byType(SingleChildScrollView);
      expect(scrollFinder, findsOneWidget);

      final ctaFinder = find.widgetWithText(ElevatedButton, 'CONTINUE');
      expect(find.descendant(of: scrollFinder, matching: ctaFinder), findsNothing);
    });

    testWidgets('ArtistInfoScreen uses FlowPageLayout and anchors CTA at the bottom', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ArtistInfoScreen(),
        ),
      );

      expect(find.byType(FlowPageLayout), findsOneWidget);
      expect(find.text('Artist Profile'), findsOneWidget);
      expect(find.text('Enter your artist name and contact number to get set up.'), findsOneWidget);

      final flowLayout = tester.widget<FlowPageLayout>(find.byType(FlowPageLayout));
      expect(flowLayout.title, equals('Artist Profile'));
      expect(flowLayout.ctaText, equals('CONTINUE'));

      // CTA is anchored outside the scroll view
      final scrollFinder = find.byType(SingleChildScrollView);
      final ctaFinder = find.byKey(const Key('continue_artist_info_button'));
      expect(find.descendant(of: scrollFinder, matching: ctaFinder), findsNothing);
    });

    testWidgets('ArtistSetPriceScreen uses FlowPageLayout and anchors CTA at the bottom', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ArtistSetPriceScreen(artistName: 'OddMaree'),
        ),
      );

      expect(find.byType(FlowPageLayout), findsOneWidget);
      expect(find.text('Set your price'), findsOneWidget);
      expect(find.text('Set your minimum deposit. This will be displayed on your profile.'), findsOneWidget);

      final flowLayout = tester.widget<FlowPageLayout>(find.byType(FlowPageLayout));
      expect(flowLayout.title, equals('Set your price'));
      expect(flowLayout.ctaText, equals('CONTINUE'));

      // CTA is anchored outside the scroll view
      final scrollFinder = find.byType(SingleChildScrollView);
      final ctaFinder = find.byKey(const Key('continue_price_button'));
      expect(find.descendant(of: scrollFinder, matching: ctaFinder), findsNothing);
    });

    testWidgets('ArtistFlashUploadScreen uses FlowPageLayout with top-aligned header', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ArtistFlashUploadScreen(
            artistName: 'OddMaree',
            instagramHandle: '@oddmaree',
            minDeposit: 100,
          ),
        ),
      );

      expect(find.byType(FlowPageLayout), findsOneWidget);
      expect(find.text('Showcase your\nwork'), findsOneWidget);
      expect(find.text('Upload some custom flash work you plan on selling'), findsOneWidget);

      final flowLayout = tester.widget<FlowPageLayout>(find.byType(FlowPageLayout));
      expect(flowLayout.title, equals('Showcase your\nwork'));
    });

    testWidgets('AccountCreationScreen uses FlowPageLayout with consistent horizontal margin', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AccountCreationScreen(role: 'artist'),
        ),
      );

      expect(find.byType(FlowPageLayout), findsOneWidget);
      expect(find.byKey(const Key('unified_auth_input_field')), findsOneWidget);
      expect(find.byKey(const Key('unified_auth_continue_button')), findsOneWidget);

      final scrollWidget = tester.widget<SingleChildScrollView>(find.byType(SingleChildScrollView));
      expect((scrollWidget.padding as EdgeInsets).left, equals(AppSpacing.screenMargin));
      expect((scrollWidget.padding as EdgeInsets).right, equals(AppSpacing.screenMargin));
    });

    testWidgets('FlowPageLayout removes duplicate top padding inside scrollview under safe area', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(padding: EdgeInsets.only(top: 50.0)),
            child: Scaffold(
              extendBodyBehindAppBar: true,
              body: FlowPageLayout(
                title: 'Artist Profile',
                subtitle: 'Enter your artist name',
                child: const Text('Form Content'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final titleTop = tester.getTopLeft(find.text('Artist Profile')).dy;
      // topInset = 50 + 56 = 106. AppGaps.belowAppBar = 24.
      // With removeTop: true, title is at 106 + 24 = 130 (exactly 80px below safeAreaTop of 50).
      expect(titleTop, equals(130.0));
    });
  });
}
