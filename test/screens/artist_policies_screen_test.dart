import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flash_ink/models/artist.dart';
import 'package:flash_ink/models/studio_information.dart';
import 'package:flash_ink/screens/artist_onboarding/artist_policies_screen.dart';
import 'package:flash_ink/screens/artist_onboarding/artist_set_price_screen.dart';
import 'package:flash_ink/widgets/flash_switch.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.physicalSize = const Size(1080, 2400);
    binding.platformDispatcher.views.first.devicePixelRatio = 1.0;
  });

  tearDown(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.resetPhysicalSize();
    binding.platformDispatcher.views.first.resetDevicePixelRatio();
  });

  Widget buildTestWidget({
    List<StudioPolicy>? initialPolicies,
  }) {
    return MaterialApp(
      home: ArtistPoliciesScreen(
        artistName: 'OddMaree',
        studioInformation: const StudioInformation(
          name: 'Rose Water Tattoo',
          formattedAddress: '123 SE Hawthorne Blvd',
          city: 'Portland',
          state: 'OR',
        ),
        artistBio: 'Custom illustrative blackwork and flash.',
        initialPolicies: initialPolicies,
      ),
    );
  }

  group('ArtistPoliciesScreen Widget Tests', () {
    testWidgets('Renders all standard policy cards and enabled CTA', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Studio Policies & Rules'), findsOneWidget);
      expect(find.text('Deposits & Cancellations'), findsOneWidget);
      expect(find.text('Health & Day-of Prep'), findsOneWidget);
      expect(find.text('Studio Etiquette & Guests'), findsOneWidget);
      expect(find.text('Touch-ups'), findsOneWidget);

      final continueButton = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(continueButton.onPressed, isNotNull);
    });

    testWidgets('Disabling all policies shows warning banner and disables CTA', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Find all FlashSwitch switches and turn them off
      final switches = find.byType(FlashSwitch);
      expect(switches, findsNWidgets(4));

      for (int i = 0; i < 4; i++) {
        await tester.tap(find.byKey(Key('policy_switch_$i')));
        await tester.pumpAndSettle();
      }

      // Warning message should be visible
      expect(
        find.text('Enable at least one studio policy to protect both you and your clients.'),
        findsOneWidget,
      );

      // CTA should now be disabled
      final continueButton = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(continueButton.onPressed, isNull);

      // Turn one policy back on
      await tester.tap(find.byKey(const Key('policy_switch_0')));
      await tester.pumpAndSettle();

      final updatedContinueButton = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(updatedContinueButton.onPressed, isNotNull);
    });

    testWidgets('Editing a policy updates its title and description', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Tap Edit text on first policy
      await tester.tap(find.byKey(const Key('edit_policy_btn_0')));
      await tester.pumpAndSettle();

      expect(find.text('Edit Policy'), findsOneWidget);
      expect(find.byKey(const Key('edit_policy_title_field')), findsOneWidget);
      expect(find.byKey(const Key('edit_policy_desc_field')), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('edit_policy_desc_field')),
        'Non-refundable 50% deposit required. 72-hour notice to reschedule.',
      );

      await tester.tap(find.byKey(const Key('save_policy_button')));
      await tester.pumpAndSettle();

      expect(
        find.text('Non-refundable 50% deposit required. 72-hour notice to reschedule.'),
        findsOneWidget,
      );
    });

    testWidgets('Adding a custom policy appends new card and can proceed to price screen', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Tap Add Custom Policy
      await tester.tap(find.byKey(const Key('add_custom_policy_button')));
      await tester.pumpAndSettle();

      expect(find.text('Add Custom Policy'), findsOneWidget);
      expect(find.byKey(const Key('custom_policy_title_field')), findsOneWidget);
      expect(find.byKey(const Key('custom_policy_desc_field')), findsOneWidget);

      // Fill in custom policy fields
      await tester.enterText(
        find.byKey(const Key('custom_policy_title_field')),
        'Artwork Design Revisions',
      );
      await tester.enterText(
        find.byKey(const Key('custom_policy_desc_field')),
        'Up to 2 small design revisions included. Major concept overhaul requires new deposit.',
      );

      // Tap icon category chip
      await tester.tap(find.byKey(const Key('policy_icon_chip_etiquette')));
      await tester.pumpAndSettle();

      // Submit
      await tester.tap(find.byKey(const Key('add_custom_policy_submit_button')));
      await tester.pumpAndSettle();

      // New policy should be rendered
      expect(find.text('Artwork Design Revisions'), findsOneWidget);
      expect(
        find.text('Up to 2 small design revisions included. Major concept overhaul requires new deposit.'),
        findsOneWidget,
      );

      // Tap Continue and verify navigation to ArtistSetPriceScreen
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      expect(find.byType(ArtistSetPriceScreen), findsOneWidget);
    });
  });
}
