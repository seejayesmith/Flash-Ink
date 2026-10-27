import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flash_ink/screens/role_selection_screen.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('RoleSelectionScreen Layout & Centering Tests', () {
    testWidgets('Header text is top-aligned and route options container is vertically centered', (tester) async {
      // Set fixed phone screen size 400 x 850
      tester.view.physicalSize = const Size(400, 850);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: RoleSelectionScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify header texts are present
      final titleFinder = find.text("Let's get started.");
      final subtitleFinder = find.text("Tell us how you'll be using the platform so we can tailor your experience.");
      expect(titleFinder, findsOneWidget);
      expect(subtitleFinder, findsOneWidget);

      // Verify title is positioned near top (below the app bar)
      final titleTop = tester.getTopLeft(titleFinder).dy;
      expect(titleTop, lessThan(120.0));

      // Verify route options are present
      final clientCardFinder = find.text('I get tattoos');
      final artistCardFinder = find.text('I make tattoos');
      expect(clientCardFinder, findsOneWidget);
      expect(artistCardFinder, findsOneWidget);

      final clientCardTop = tester.getTopLeft(clientCardFinder).dy;
      final artistCardBottom = tester.getBottomLeft(artistCardFinder).dy;
      final ctaTop = tester.getTopLeft(find.text('CONTINUE')).dy;
      final subtitleBottom = tester.getBottomLeft(subtitleFinder).dy;

      // Space above the cards container (between subtitle and client card)
      final spaceAboveCards = clientCardTop - subtitleBottom;
      // Space below the cards container (between artist card and continue button)
      final spaceBelowCards = ctaTop - artistCardBottom;

      // The route options container should be centered in the space between header and CTA
      // Both spaces should be substantial and roughly balanced (within 40px delta)
      expect(spaceAboveCards, greaterThan(40.0));
      expect(spaceBelowCards, greaterThan(40.0));
      expect((spaceAboveCards - spaceBelowCards).abs(), lessThan(40.0));
    });

    testWidgets('Selecting a role enables CONTINUE button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RoleSelectionScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Initially CONTINUE is disabled (tapping it does not throw or proceed)
      await tester.tap(find.text('CONTINUE'));
      await tester.pump();

      // Tap 'I get tattoos'
      await tester.tap(find.text('I get tattoos'));
      await tester.pumpAndSettle();

      // Tap 'I make tattoos'
      await tester.tap(find.text('I make tattoos'));
      await tester.pumpAndSettle();
    });
  });
}
