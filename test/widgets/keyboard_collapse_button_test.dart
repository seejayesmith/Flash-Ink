import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flash_ink/models/artist.dart';
import 'package:flash_ink/models/studio_information.dart';
import 'package:flash_ink/screens/artist_onboarding/artist_choose_style_screen.dart';
import 'package:flash_ink/screens/artist_onboarding/artist_policies_screen.dart';
import 'package:flash_ink/screens/booking/flash_booking_screen.dart';
import 'package:flash_ink/services/auth_service.dart';
import 'package:flash_ink/widgets/keyboard_collapse_button.dart';
import 'package:flash_ink/widgets/guest_auth_prompt_bottom_sheet.dart';
import 'package:flash_ink/widgets/reauthentication_bottom_sheet.dart';
import 'package:flash_ink/screens/artist_dashboard/add_waitlist_entry_sheet.dart';
import 'package:flash_ink/screens/phone_entry_screen.dart';
import 'package:flash_ink/screens/phone_verification_screen.dart';

class _FakeUserInfo extends Fake implements UserInfo {
  @override
  final String providerId;
  _FakeUserInfo(this.providerId);
}

class _ReauthTestUser extends Fake implements User {
  @override
  final String uid;
  @override
  final String? email;
  final List<String> providers = const ['password'];

  _ReauthTestUser({
    this.uid = 'user_reauth_test',
    this.email = 'client@example.com',
  });

  @override
  List<UserInfo> get providerData => providers.map((p) => _FakeUserInfo(p)).toList();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('KeyboardCollapseButton Component Tests', () {
    testWidgets('Renders with standard icon, tooltip, and key', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: KeyboardCollapseButton(),
            ),
          ),
        ),
      );

      final buttonFinder = find.byKey(const Key('collapse_keyboard_button'));
      expect(buttonFinder, findsOneWidget);

      final iconFinder = find.descendant(
        of: buttonFinder,
        matching: find.byIcon(Icons.keyboard_hide_rounded),
      );
      expect(iconFinder, findsOneWidget);

      final iconButton = tester.widget<IconButton>(buttonFinder);
      expect(iconButton.tooltip, equals('Collapse keyboard'));
    });

    testWidgets('Tapping KeyboardCollapseButton unfocuses active text input and calls callback', (tester) async {
      bool callbackFired = false;
      final focusNode = FocusNode();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                TextField(
                  focusNode: focusNode,
                ),
                KeyboardCollapseButton(
                  onPressed: () => callbackFired = true,
                ),
              ],
            ),
          ),
        ),
      );

      // Focus the text field
      focusNode.requestFocus();
      await tester.pump();
      expect(focusNode.hasFocus, isTrue);

      // Tap collapse button
      await tester.tap(find.byKey(const Key('collapse_keyboard_button')));
      await tester.pump();

      // Verify focus is dismissed and callback is called
      expect(focusNode.hasFocus, isFalse);
      expect(callbackFired, isTrue);
    });
  });

  group('Modal Keyboard Collapse Button Integration Tests', () {
    testWidgets('AddWaitlistEntrySheet includes collapse keyboard button in header', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AddWaitlistEntrySheet(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final collapseButton = find.byKey(const Key('collapse_keyboard_button'));
      expect(collapseButton, findsOneWidget);

      // Find one of the text fields and focus it
      final nameField = find.byType(TextField).first;
      await tester.tap(nameField);
      await tester.pump();

      // Tap collapse button
      await tester.tap(collapseButton);
      await tester.pump();

      // Verify no primary focus on the text field
      final primaryFocus = FocusManager.instance.primaryFocus;
      expect(primaryFocus?.context?.widget is! EditableText, isTrue);
    });

    testWidgets('GuestAuthPromptBottomSheet includes collapse keyboard button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GuestAuthPromptBottomSheet(
              actionType: AuthActionPromptType.bookFlash,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final collapseButton = find.byKey(const Key('collapse_keyboard_button'));
      expect(collapseButton, findsOneWidget);

      await tester.tap(collapseButton);
      await tester.pump();
    });

    testWidgets('ReauthenticationBottomSheet includes collapse keyboard button', (tester) async {
      final mockAuth = AuthService(
        mockUser: _ReauthTestUser(
          uid: 'user_reauth_test',
          email: 'client@example.com',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReauthenticationBottomSheet(
              authService: mockAuth,
              onSuccess: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final collapseButton = find.byKey(const Key('collapse_keyboard_button'));
      expect(collapseButton, findsOneWidget);

      // Focus password field
      final passwordField = find.byKey(const Key('reauth_password_field'));
      expect(passwordField, findsOneWidget);
      await tester.tap(passwordField);
      await tester.pump();

      // Tap collapse button
      await tester.tap(collapseButton);
      await tester.pump();

      final primaryFocus = FocusManager.instance.primaryFocus;
      expect(primaryFocus?.context?.widget is! EditableText, isTrue);
    });

    testWidgets('ArtistPoliciesScreen Edit Policy modal includes collapse keyboard button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ArtistPoliciesScreen(
            artistName: 'OddMaree',
            studioInformation: StudioInformation(
              name: 'Rose Water Tattoo',
              formattedAddress: '123 SE Hawthorne Blvd',
              city: 'Portland',
              state: 'OR',
            ),
            artistBio: 'Custom illustrative blackwork and flash.',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open Edit Policy modal
      await tester.tap(find.byKey(const Key('edit_policy_btn_0')));
      await tester.pumpAndSettle();

      expect(find.text('Edit Policy'), findsOneWidget);
      final collapseButton = find.byKey(const Key('collapse_keyboard_button'));
      expect(collapseButton, findsOneWidget);

      // Focus the title field
      await tester.tap(find.byKey(const Key('edit_policy_title_field')));
      await tester.pump();

      // Tap collapse button
      await tester.tap(collapseButton);
      await tester.pump();

      final primaryFocus = FocusManager.instance.primaryFocus;
      expect(primaryFocus?.context?.widget is! EditableText, isTrue);
    });

    testWidgets('ArtistPoliciesScreen Add Custom Policy modal includes collapse keyboard button', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: ArtistPoliciesScreen(
            artistName: 'OddMaree',
            studioInformation: StudioInformation(
              name: 'Rose Water Tattoo',
              formattedAddress: '123 SE Hawthorne Blvd',
              city: 'Portland',
              state: 'OR',
            ),
            artistBio: 'Custom illustrative blackwork and flash.',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Ensure button is visible and tap Add Custom Policy
      final addButton = find.byKey(const Key('add_custom_policy_button'));
      await tester.ensureVisible(addButton);
      await tester.pumpAndSettle();
      await tester.tap(addButton);
      await tester.pumpAndSettle();

      expect(find.text('Add Custom Policy'), findsOneWidget);
      final collapseButton = find.byKey(const Key('collapse_keyboard_button'));
      expect(collapseButton, findsOneWidget);

      // Focus the description field
      await tester.tap(find.byKey(const Key('custom_policy_desc_field')));
      await tester.pump();

      // Tap collapse button
      await tester.tap(collapseButton);
      await tester.pump();

      final primaryFocus = FocusManager.instance.primaryFocus;
      expect(primaryFocus?.context?.widget is! EditableText, isTrue);
    });

    testWidgets('ArtistChooseStyleScreen Add Style dialog includes collapse keyboard button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ArtistChooseStyleScreen(
            artistName: 'OddMaree',
            instagramHandle: 'oddmaree',
            minDeposit: 100,
            flashArtworks: const [],
            identityTags: const ['LGBTQ+ Owned'],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the + Add a style button
      await tester.tap(find.byKey(const Key('add_custom_style_trigger')));
      await tester.pumpAndSettle();

      expect(find.text('Add a Style'), findsOneWidget);
      final collapseButton = find.byKey(const Key('collapse_keyboard_button'));
      expect(collapseButton, findsOneWidget);

      // Input field has focus
      final customInput = find.byKey(const Key('custom_style_input'));
      expect(customInput, findsOneWidget);

      // Tap collapse button
      await tester.tap(collapseButton);
      await tester.pump();

      final primaryFocus = FocusManager.instance.primaryFocus;
      expect(primaryFocus?.context?.widget is! EditableText, isTrue);
    });

    testWidgets('FlashBookingScreen placement bottom sheet includes collapse keyboard button', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const testFlash = FlashArtwork(
        id: 'flash_test_101',
        artistId: 'artist_1',
        artistName: 'Maree Raven',
        title: 'Obsidian Serpent & Peony',
        imageUrl: 'https://images.unsplash.com/photo-1598371839696-5c5bb00bdc28',
        price: 250,
        deposit: 75,
        status: FlashStatus.available,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: FlashBookingScreen(
            flash: testFlash,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open placement bottom sheet
      await tester.tap(find.byKey(const Key('placement_selector_trigger')));
      await tester.pumpAndSettle();

      expect(find.text('Select Body Placement'), findsOneWidget);
      final collapseButton = find.byKey(const Key('collapse_keyboard_button'));
      expect(collapseButton, findsOneWidget);

      // Tap 'Other' to reveal custom placement text field
      await tester.tap(find.byKey(const Key('placement_option_Other')));
      await tester.pumpAndSettle();

      final customField = find.byKey(const Key('custom_placement_field'));
      expect(customField, findsOneWidget);

      // Focus the custom field
      await tester.tap(customField);
      await tester.pump();

      // Tap collapse button
      await tester.tap(collapseButton);
      await tester.pump();

      final primaryFocus = FocusManager.instance.primaryFocus;
      expect(primaryFocus?.context?.widget is! EditableText, isTrue);
    });
  });

  group('Numeric Keyboard and Phone Verification Screen Collapse Tests', () {
    testWidgets('PhoneEntryScreen removes in-card collapse buttons while retaining tap-out dismiss', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockAuth = AuthService(mockUser: _ReauthTestUser());

      await tester.pumpWidget(
        MaterialApp(
          home: PhoneEntryScreen(
            role: 'client',
            authService: mockAuth,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify card header collapse button is removed
      expect(find.byKey(const Key('phone_card_collapse_button')), findsNothing);

      // Verify TextFormField suffix collapse button is removed
      expect(find.byKey(const Key('collapse_keyboard_button')), findsNothing);

      // Find phone text field focus node
      final focusNode = tester.widget<EditableText>(find.byType(EditableText)).focusNode;
      expect(focusNode.hasFocus, isFalse);

      // 1. Focus the phone field
      focusNode.requestFocus();
      await tester.pump();
      expect(focusNode.hasFocus, isTrue);

      // 2. Tap out on background text (e.g. 'Verify Phone Number' title)
      await tester.tap(find.text('Verify Phone Number'));
      await tester.pump();
      expect(focusNode.hasFocus, isFalse);
    });

    testWidgets('PhoneVerificationScreen removes in-card collapse button while retaining tap-out dismiss', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockAuth = AuthService(mockUser: _ReauthTestUser());

      await tester.pumpWidget(
        MaterialApp(
          home: PhoneVerificationScreen(
            phoneNumber: '+15550192834',
            role: 'client',
            verificationId: 'vid_test_123',
            authService: mockAuth,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify header collapse button is removed
      expect(find.byKey(const Key('otp_header_collapse_button')), findsNothing);

      // Find OTP focus node
      final focusNode = tester.widget<EditableText>(find.byType(EditableText)).focusNode;
      expect(focusNode.hasFocus, isFalse);

      // 1. Focus OTP text field
      focusNode.requestFocus();
      await tester.pump();
      expect(focusNode.hasFocus, isTrue);

      // 2. Tap out on empty space / title
      await tester.tap(find.text('Verify your number.'));
      await tester.pump();
      expect(focusNode.hasFocus, isFalse);
    });
  });
}
