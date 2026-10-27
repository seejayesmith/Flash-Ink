import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flash_ink/services/auth_service.dart';
import 'package:flash_ink/theme/app_spacing.dart';
import 'package:flash_ink/widgets/adaptive_glass_container.dart';
import 'package:flash_ink/features/onboarding/shared/onboarding_step_scaffold.dart';
import 'package:flash_ink/screens/artist_onboarding/artist_info_screen.dart';
import 'package:flash_ink/screens/artist_onboarding/artist_phone_verification_screen.dart';
import 'package:flash_ink/screens/artist_onboarding/artist_studio_bio_screen.dart';
import 'package:flash_ink/screens/artist_onboarding/artist_set_price_screen.dart';
import 'package:flash_ink/screens/artist_onboarding/artist_profile_photo_screen.dart';
import 'package:flash_ink/features/onboarding/client/client_location_screen.dart';

class MockUser extends Fake implements User {
  @override
  final String uid;
  @override
  final String? email;
  @override
  final String? displayName;
  @override
  final String? phoneNumber;

  MockUser({
    required this.uid,
    this.email,
    this.displayName,
    this.phoneNumber,
  });

  @override
  Future<void> updateDisplayName(String? name) async {}

  @override
  Future<void> updatePhotoURL(String? photoUri) async {}

  @override
  Future<String> getIdToken([bool forceRefresh = false]) async => 'mock_token';
}

class FakeArtistAuthService extends AuthService {
  final MockUser mockUser = MockUser(
    uid: 'artist_test_123',
    email: 'ink@studio.com',
    displayName: 'OddMaree',
    phoneNumber: '+15551234567',
  );

  @override
  User? get currentUser => mockUser;

  @override
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(Exception error) onVerificationFailed,
    void Function(PhoneAuthCredential credential)? onVerificationCompleted,
    void Function(String verificationId)? onCodeAutoRetrievalTimeout,
    int? forceResendingToken,
  }) async {
    onCodeSent('test_vid_123', 123456);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await Firebase.initializeApp();
  });

  group('Onboarding Flow: CTA Bottom-Anchoring & Keyboard Avoidance Contract', () {
    // -------------------------------------------------------------------------
    // 1. Short Screen — CTA Pinned to Bottom Edge
    // -------------------------------------------------------------------------
    testWidgets('1. Short Screen: CTA sits flush against bottom safe-area boundary and does not float mid-screen', (tester) async {
      const double viewportWidth = 800.0;
      const double viewportHeight = 1200.0;
      const double safeAreaBottom = 34.0;

      tester.view.physicalSize = const Size(viewportWidth, viewportHeight);
      tester.view.devicePixelRatio = 1.0;
      tester.view.padding = const FakeViewPadding(bottom: safeAreaBottom);
      tester.view.viewPadding = const FakeViewPadding(bottom: safeAreaBottom);
      addTearDown(tester.view.reset);

      final authService = FakeArtistAuthService();

      await tester.pumpWidget(
        MaterialApp(
          home: ArtistInfoScreen(
            authService: authService,
            initialName: 'OddMaree',
            initialPhone: '+15551234567',
          ),
        ),
      );
      await tester.pumpAndSettle();

      final ctaFinder = find.byKey(const Key('continue_artist_info_button'));
      expect(ctaFinder, findsOneWidget);

      final formFinder = find.byType(AdaptiveGlassContainer);
      expect(formFinder, findsOneWidget);

      final ctaRect = tester.getRect(ctaFinder);
      final formRect = tester.getRect(formFinder);

      // Verify the CTA is pushed to the bottom of the viewport rather than floating beneath the inputs
      expect(
        ctaRect.top,
        greaterThan(formRect.bottom + 200.0),
        reason: 'CTA must not float mid-screen directly beneath the form fields',
      );

      // Verify the CTA sits flush against the bottom safe-area boundary
      // (viewportHeight - safeAreaBottom - AppSpacing.ctaBottomPadding)
      final expectedCtaBottom = viewportHeight - safeAreaBottom - AppSpacing.ctaBottomPadding;
      expect(
        ctaRect.bottom,
        closeTo(expectedCtaBottom, 1.0),
        reason: 'CTA bottom must align flush against the bottom safe-area boundary',
      );
    });

    // -------------------------------------------------------------------------
    // 2. Scrollable Screen — CTA Anchored at End of Scroll Content
    // -------------------------------------------------------------------------
    testWidgets('2. Scrollable Screen: CTA is below viewport fold on compact screen and requires scrolling to become hittable', (tester) async {
      const double compactWidth = 400.0;
      const double compactHeight = 600.0;

      tester.view.physicalSize = const Size(compactWidth, compactHeight);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      bool ctaTapped = false;

      // Pump an OnboardingStepScaffold with content that exceeds the 600px viewport height
      await tester.pumpWidget(
        MaterialApp(
          home: OnboardingStepScaffold(
            currentStep: 1,
            totalSteps: 4,
            title: 'Scrollable Form',
            subtitle: 'This form has multiple inputs exceeding the initial viewport.',
            ctaText: 'CONTINUE',
            ctaKey: const Key('scrollable_cta_button'),
            onCtaPressed: () => ctaTapped = true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: List.generate(
                6,
                (index) => Container(
                  height: 90,
                  margin: const EdgeInsets.only(bottom: 12),
                  color: const Color(0xFF242727),
                  alignment: Alignment.center,
                  child: Text(
                    'Form Section $index',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final ctaFinder = find.byKey(const Key('scrollable_cta_button'));

      // 1. Initial State: CTA is anchored at the end of the scroll body,
      // and NOT rendered as a sticky overlay at the bottom of the viewport.
      // If built, it sits below the viewport fold; if deferred past cacheExtent, it requires scrolling.
      if (ctaFinder.evaluate().isNotEmpty) {
        final initialCtaRect = tester.getRect(ctaFinder);
        expect(
          initialCtaRect.top,
          greaterThanOrEqualTo(compactHeight),
          reason: 'CTA must be positioned below the viewport fold and not rendered as a sticky overlay',
        );
      } else {
        expect(
          ctaFinder,
          findsNothing,
          reason: 'CTA is anchored past the scroll fold and requires scrolling to become hittable',
        );
      }

      // 2. Drag / scroll to the bottom of the page content
      final scrollableFinder = find.byType(CustomScrollView);
      expect(scrollableFinder, findsOneWidget);
      await tester.drag(scrollableFinder, const Offset(0, -500));
      await tester.pumpAndSettle();

      // 3. CTA is now scrolled into view and fully hittable
      expect(ctaFinder, findsOneWidget);
      final scrolledCtaRect = tester.getRect(ctaFinder);
      expect(
        scrolledCtaRect.bottom,
        lessThanOrEqualTo(compactHeight),
        reason: 'Scrolled CTA must be within viewport bounds',
      );
      expect(scrolledCtaRect.top, greaterThan(0));

      // 4. Tap the CTA and confirm it receives input
      await tester.tap(ctaFinder);
      await tester.pumpAndSettle();
      expect(ctaTapped, isTrue);
    });

    // -------------------------------------------------------------------------
    // 3. Zero Keyboard Avoidance (Simulated Soft Keyboard Insets)
    // -------------------------------------------------------------------------
    testWidgets('3. Zero Keyboard Avoidance: CTA stays anchored at bottom edge when keyboard opens', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final authService = FakeArtistAuthService();

      await tester.pumpWidget(
        MaterialApp(
          home: ArtistInfoScreen(
            authService: authService,
            initialName: 'OddMaree',
            initialPhone: '+15551234567',
          ),
        ),
      );
      await tester.pumpAndSettle();

      final ctaFinder = find.byKey(const Key('continue_artist_info_button'));
      final initialBottomY = tester.getBottomLeft(ctaFinder).dy;

      // Tap an input field to request focus
      final nameFieldFinder = find.descendant(
        of: find.byKey(const Key('artist_name_handle_field')),
        matching: find.byType(TextField),
      );
      await tester.tap(nameFieldFinder);
      await tester.pumpAndSettle();

      // Simulate soft-keyboard opening with bottom viewInsets
      tester.view.viewInsets = FakeViewPadding(bottom: 320 * tester.view.devicePixelRatio);
      await tester.pumpAndSettle();

      // The CTA bottom coordinate must remain exactly identical to initialBottomY
      final activeBottomY = tester.getBottomLeft(ctaFinder).dy;
      expect(
        activeBottomY,
        equals(initialBottomY),
        reason: 'Opening the keyboard must never push, dock, or animate the CTA upward',
      );
    });

    // -------------------------------------------------------------------------
    // 4. Keyboard Types & Enter/Done Action Configuration
    // -------------------------------------------------------------------------
    testWidgets('4. Keyboard Types & TextInputAction: All fields use TextInputAction.done and appropriate keyboardType', (tester) async {
      final authService = FakeArtistAuthService();

      // A. Verify ArtistInfoScreen
      await tester.pumpWidget(
        MaterialApp(
          home: ArtistInfoScreen(
            authService: authService,
            initialName: 'OddMaree',
            initialPhone: '+15551234567',
          ),
        ),
      );
      await tester.pumpAndSettle();

      final artistInfoFields = tester.widgetList<TextField>(find.byType(TextField)).toList();
      for (final field in artistInfoFields) {
        expect(field.textInputAction, equals(TextInputAction.done));
        expect(field.textInputAction, isNot(equals(TextInputAction.next)));
        expect(field.scrollPadding.bottom, greaterThanOrEqualTo(24.0));
      }

      final nameField = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const Key('artist_name_handle_field')),
          matching: find.byType(TextField),
        ),
      );
      expect(nameField.keyboardType, equals(TextInputType.text));

      final phoneField = tester.widget<TextField>(
        find.byWidgetPredicate((w) => w is TextField && w.keyboardType == TextInputType.phone),
      );
      expect(phoneField.keyboardType, equals(TextInputType.phone));

      // B. Verify ArtistPhoneVerificationScreen (OTP numeric keypad)
      await tester.pumpWidget(
        MaterialApp(
          home: ArtistPhoneVerificationScreen(
            phoneNumber: '+15551234567',
            verificationId: 'test_vid',
            authService: authService,
            artistName: 'OddMaree',
            artistEmail: 'ink@studio.com',
          ),
        ),
      );
      await tester.pumpAndSettle();

      final otpFields = tester.widgetList<TextField>(find.byType(TextField)).toList();
      expect(otpFields.length, equals(6));
      for (final field in otpFields) {
        expect(field.keyboardType, equals(TextInputType.number));
        expect(field.textInputAction, equals(TextInputAction.done));
        expect(field.textInputAction, isNot(equals(TextInputAction.next)));
      }

      // C. Verify ArtistStudioBioScreen (Text inputs)
      await tester.pumpWidget(
        const MaterialApp(
          home: ArtistStudioBioScreen(artistName: 'OddMaree'),
        ),
      );
      await tester.pumpAndSettle();

      final studioFields = tester.widgetList<TextField>(find.byType(TextField)).toList();
      expect(studioFields.isNotEmpty, isTrue);
      for (final field in studioFields) {
        expect(field.keyboardType, equals(TextInputType.text));
        expect(field.textInputAction, equals(TextInputAction.done));
        expect(field.textInputAction, isNot(equals(TextInputAction.next)));
      }

      // D. Verify ArtistSetPriceScreen (Numeric input)
      await tester.pumpWidget(
        const MaterialApp(
          home: ArtistSetPriceScreen(artistName: 'OddMaree'),
        ),
      );
      await tester.pumpAndSettle();

      final priceField = tester.widget<TextField>(find.byKey(const Key('price_text_field')));
      expect(priceField.keyboardType, equals(TextInputType.number));
      expect(priceField.textInputAction, equals(TextInputAction.done));
      expect(priceField.textInputAction, isNot(equals(TextInputAction.next)));

      // E. Verify ClientLocationScreen (Numeric input)
      await tester.pumpWidget(
        const MaterialApp(
          home: ClientLocationScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final zipField = tester.widget<TextField>(find.byKey(const Key('client_zip_input_field')));
      expect(zipField.keyboardType, equals(TextInputType.number));
      expect(zipField.textInputAction, equals(TextInputAction.done));
      expect(zipField.textInputAction, isNot(equals(TextInputAction.next)));
    });

    // -------------------------------------------------------------------------
    // 5. Three-Way Keyboard Dismissal (Enter, Tap Outside, & Scroll)
    // -------------------------------------------------------------------------
    group('5. Three-Way Keyboard Dismissal', () {
      testWidgets('Dismissal via Enter / Done key action', (tester) async {
        final authService = FakeArtistAuthService();

        await tester.pumpWidget(
          MaterialApp(
            home: ArtistInfoScreen(
              authService: authService,
              initialName: 'OddMaree',
              initialPhone: '+15551234567',
            ),
          ),
        );
        await tester.pumpAndSettle();

        final nameFieldFinder = find.descendant(
          of: find.byKey(const Key('artist_name_handle_field')),
          matching: find.byType(TextField),
        );
        final phoneFieldFinder = find.byWidgetPredicate(
          (w) => w is TextField && w.keyboardType == TextInputType.phone,
        );

        // Tap name field to focus and open keyboard
        await tester.tap(nameFieldFinder);
        await tester.pumpAndSettle();
        expect(tester.testTextInput.isVisible, isTrue);

        final nameEditable = tester.widget<EditableText>(
          find.descendant(of: nameFieldFinder, matching: find.byType(EditableText)),
        );
        expect(nameEditable.focusNode.hasFocus, isTrue);

        // Submit Done action
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();

        // Keyboard must be dismissed and focus cleared (not advanced to phone field)
        expect(tester.testTextInput.isVisible, isFalse);
        expect(nameEditable.focusNode.hasFocus, isFalse);

        final phoneEditable = tester.widget<EditableText>(
          find.descendant(of: phoneFieldFinder, matching: find.byType(EditableText)),
        );
        expect(
          phoneEditable.focusNode.hasFocus,
          isFalse,
          reason: 'Pressing Done must not advance focus to sibling field',
        );
        expect(FocusManager.instance.primaryFocus, isA<FocusScopeNode>());
      });

      testWidgets('Dismissal via Tap outside inputs', (tester) async {
        final authService = FakeArtistAuthService();

        await tester.pumpWidget(
          MaterialApp(
            home: ArtistInfoScreen(
              authService: authService,
              initialName: 'OddMaree',
              initialPhone: '+15551234567',
            ),
          ),
        );
        await tester.pumpAndSettle();

        final nameFieldFinder = find.descendant(
          of: find.byKey(const Key('artist_name_handle_field')),
          matching: find.byType(TextField),
        );

        await tester.tap(nameFieldFinder);
        await tester.pumpAndSettle();
        expect(tester.testTextInput.isVisible, isTrue);

        final nameEditable = tester.widget<EditableText>(
          find.descendant(of: nameFieldFinder, matching: find.byType(EditableText)),
        );
        expect(nameEditable.focusNode.hasFocus, isTrue);

        // Tap blank title header outside inputs
        await tester.tap(find.byKey(const Key('onboarding_title')));
        await tester.pumpAndSettle();

        expect(tester.testTextInput.isVisible, isFalse);
        expect(nameEditable.focusNode.hasFocus, isFalse);
        expect(FocusManager.instance.primaryFocus, isA<FocusScopeNode>());
      });

      testWidgets('Dismissal via Scroll drag', (tester) async {
        final authService = FakeArtistAuthService();

        await tester.pumpWidget(
          MaterialApp(
            home: ArtistInfoScreen(
              authService: authService,
              initialName: 'OddMaree',
              initialPhone: '+15551234567',
            ),
          ),
        );
        await tester.pumpAndSettle();

        final nameFieldFinder = find.descendant(
          of: find.byKey(const Key('artist_name_handle_field')),
          matching: find.byType(TextField),
        );

        await tester.tap(nameFieldFinder);
        await tester.pumpAndSettle();
        expect(tester.testTextInput.isVisible, isTrue);

        final nameEditable = tester.widget<EditableText>(
          find.descendant(of: nameFieldFinder, matching: find.byType(EditableText)),
        );
        expect(nameEditable.focusNode.hasFocus, isTrue);

        // Drag scroll view
        final scrollableFinder = find.byType(CustomScrollView);
        await tester.drag(scrollableFinder, const Offset(0, -150));
        await tester.pumpAndSettle();

        expect(tester.testTextInput.isVisible, isFalse);
        expect(nameEditable.focusNode.hasFocus, isFalse);
        expect(FocusManager.instance.primaryFocus, isA<FocusScopeNode>());
      });
    });

    // -------------------------------------------------------------------------
    // 6. Seamless Field-to-Field Focus Switching
    // -------------------------------------------------------------------------
    testWidgets('6. Seamless Field-to-Field Focus Switching: switches keyboard type in-place without bouncing closed', (tester) async {
      final authService = FakeArtistAuthService();

      await tester.pumpWidget(
        MaterialApp(
          home: ArtistInfoScreen(
            authService: authService,
            initialName: 'OddMaree',
            initialPhone: '+15551234567',
          ),
        ),
      );
      await tester.pumpAndSettle();

      final nameFieldFinder = find.descendant(
        of: find.byKey(const Key('artist_name_handle_field')),
        matching: find.byType(TextField),
      );
      final phoneFieldFinder = find.byWidgetPredicate(
        (w) => w is TextField && w.keyboardType == TextInputType.phone,
      );

      // 1. Focus name field (QWERTY text)
      await tester.tap(nameFieldFinder);
      await tester.pumpAndSettle();

      expect(tester.testTextInput.isVisible, isTrue);
      expect(
        tester.testTextInput.setClientArgs?['inputType']?['name'],
        equals('TextInputType.text'),
      );

      // 2. Directly tap phone field while keyboard is open
      await tester.tap(phoneFieldFinder);
      await tester.pump();

      // Keyboard must remain continuously visible and inputType switched to phone keypad
      expect(
        tester.testTextInput.isVisible,
        isTrue,
        reason: 'Keyboard must stay open when switching directly between fields',
      );
      expect(
        tester.testTextInput.setClientArgs?['inputType']?['name'],
        equals('TextInputType.phone'),
        reason: 'Keyboard layout must seamlessly switch to phone keypad',
      );

      // Focus must be held by the phone field's focus node
      final phoneEditable = tester.widget<EditableText>(
        find.descendant(of: phoneFieldFinder, matching: find.byType(EditableText)),
      );
      expect(phoneEditable.focusNode.hasFocus, isTrue);
    });

    // -------------------------------------------------------------------------
    // 7. Unfocus on Route Transition
    // -------------------------------------------------------------------------
    group('7. Unfocus on Route Transition', () {
      testWidgets('Forward Navigation: clears focus and dismisses keyboard before pushing next route', (tester) async {
        final authService = FakeArtistAuthService();

        await tester.pumpWidget(
          MaterialApp(
            home: ArtistInfoScreen(
              authService: authService,
              initialName: 'OddMaree',
              initialPhone: '+15551234567',
            ),
          ),
        );
        await tester.pumpAndSettle();

        final nameFieldFinder = find.descendant(
          of: find.byKey(const Key('artist_name_handle_field')),
          matching: find.byType(TextField),
        );

        // Focus input field so keyboard is open
        await tester.tap(nameFieldFinder);
        await tester.pumpAndSettle();
        expect(tester.testTextInput.isVisible, isTrue);

        final nameEditable = tester.widget<EditableText>(
          find.descendant(of: nameFieldFinder, matching: find.byType(EditableText)),
        );
        expect(nameEditable.focusNode.hasFocus, isTrue);

        // Tap skip button to advance to next route
        final skipFinder = find.byKey(const Key('skip_artist_info_button'));
        await tester.tap(skipFinder);
        await tester.pumpAndSettle();

        // Target screen is pushed
        expect(find.byType(ArtistProfilePhotoScreen), findsOneWidget);

        // Keyboard is closed and focus is cleared
        expect(tester.testTextInput.isVisible, isFalse);
        expect(nameEditable.focusNode.hasFocus, isFalse);
        expect(FocusManager.instance.primaryFocus, isA<FocusScopeNode>());
      });

      testWidgets('Backward Navigation: clears focus and dismisses keyboard before popping route', (tester) async {
        final authService = FakeArtistAuthService();

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                return Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      key: const Key('launch_flow_button'),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ArtistInfoScreen(
                              authService: authService,
                              initialName: 'OddMaree',
                              initialPhone: '+15551234567',
                            ),
                          ),
                        );
                      },
                      child: const Text('Launch Flow'),
                    ),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Launch screen
        await tester.tap(find.byKey(const Key('launch_flow_button')));
        await tester.pumpAndSettle();
        expect(find.byType(ArtistInfoScreen), findsOneWidget);

        final nameFieldFinder = find.descendant(
          of: find.byKey(const Key('artist_name_handle_field')),
          matching: find.byType(TextField),
        );

        // Focus field
        await tester.tap(nameFieldFinder);
        await tester.pumpAndSettle();
        expect(tester.testTextInput.isVisible, isTrue);

        final nameEditable = tester.widget<EditableText>(
          find.descendant(of: nameFieldFinder, matching: find.byType(EditableText)),
        );
        expect(nameEditable.focusNode.hasFocus, isTrue);

        // Tap back button
        final backButtonFinder = find.byKey(const Key('onboarding_back_button'));
        await tester.tap(backButtonFinder);
        await tester.pumpAndSettle();

        // Back on parent route
        expect(find.byKey(const Key('launch_flow_button')), findsOneWidget);
        expect(find.byType(ArtistInfoScreen), findsNothing);

        // Keyboard must be closed and focus cleared
        expect(tester.testTextInput.isVisible, isFalse);
        expect(FocusManager.instance.primaryFocus, isA<FocusScopeNode>());
      });
    });
  });
}
