import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:flash_ink/screens/profile_setup_screen.dart';
import 'package:flash_ink/widgets/adaptive_glass_container.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await Firebase.initializeApp();
  });

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

  group('ProfileSetupScreen Username Field Auto-@ Tests', () {
    testWidgets('shows placeholder @OddMaree when empty', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ProfileSetupScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('@OddMaree'), findsOneWidget);
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, isEmpty);
    });

    testWidgets('auto-populates @ when user taps the input field', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ProfileSetupScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(TextField));
      await tester.pump();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, equals('@'));
      expect(textField.controller?.selection.baseOffset, equals(1));
    });

    testWidgets('prepends @ when user starts typing', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ProfileSetupScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'OddMaree');
      await tester.pump();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, equals('@OddMaree'));
    });

    testWidgets('prevents double @ if user explicitly types @ in front', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ProfileSetupScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '@OddMaree');
      await tester.pump();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, equals('@OddMaree'));
    });

    testWidgets('clears @ on blur when user taps away without typing a username', (WidgetTester tester) async {
      final unfocusNode = FocusNode();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                const Expanded(child: ProfileSetupScreen()),
                TextField(focusNode: unfocusNode, key: const Key('other_field')),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap username field
      await tester.tap(find.byKey(const Key('username_input_field')));
      await tester.pump();

      final textField = tester.widget<TextField>(find.byKey(const Key('username_input_field')));
      expect(textField.controller?.text, equals('@'));

      // Tap other field to unfocus
      await tester.tap(find.byKey(const Key('other_field')));
      await tester.pump();

      expect(textField.controller?.text, isEmpty);
      expect(find.text('@OddMaree'), findsOneWidget);
    });

    testWidgets('shows validation error if CONTINUE is tapped with only @', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ProfileSetupScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(TextField));
      await tester.pump();

      await tester.tap(find.text('CONTINUE'));
      await tester.pump();

      expect(find.text('Please enter a username'), findsOneWidget);
    });

    testWidgets('advances to photo step when valid username is entered', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ProfileSetupScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'OddMaree');
      await tester.pump();
      expect(find.text('@OddMaree'), findsWidgets);

      await tester.tap(find.text('CONTINUE'));
      await tester.pumpAndSettle();

      expect(find.text('Add a profile photo'), findsOneWidget);
    });
  });

  group('ProfileSetupScreen Photo Step and Keyboard Behavior Tests', () {
    testWidgets('unfocuses keyboard and renders wireframe photo step elements', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ProfileSetupScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Step 1 of 4 and progress bar on username step
      expect(find.text('Step 1 of 4'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      // Focus username input field
      await tester.tap(find.byType(TextField));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'OddMaree');
      await tester.pump();

      // Tap CONTINUE to advance to photo step
      await tester.tap(find.text('CONTINUE'));
      await tester.pumpAndSettle();

      // Verify on photo step
      expect(find.text('Step 2 of 4'), findsOneWidget);
      expect(find.text('Add a profile photo'), findsOneWidget);
      expect(find.text('Show the community who you are!\nYou can always change this later.'), findsOneWidget);

      // Verify keyboard was dismissed (no focused child)
      final FocusScopeNode currentScope = FocusScope.of(tester.element(find.text('Add a profile photo')));
      expect(currentScope.hasFocus, isFalse);

      // Verify no AdaptiveGlassContainer on the photo step
      expect(
        find.descendant(
          of: find.byType(SingleChildScrollView).last,
          matching: find.byType(AdaptiveGlassContainer),
        ),
        findsNothing,
      );

      // Verify wireframe buttons are present
      expect(find.text('Upload a Photo'), findsOneWidget);
      expect(find.text('Take a Picture'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
      expect(find.text('Skip for now'), findsOneWidget);

      // Verify avatar container circle exists with non-yellow border
      final avatarContainerFinder = find.byWidgetPredicate((widget) {
        if (widget is Container && widget.decoration is BoxDecoration) {
          final box = widget.decoration as BoxDecoration;
          return box.shape == BoxShape.circle && box.border != null;
        }
        return false;
      });
      expect(avatarContainerFinder, findsWidgets);

      final avatarContainer = tester.widget<Container>(avatarContainerFinder.first);
      final box = avatarContainer.decoration as BoxDecoration;
      final border = box.border as Border;
      expect(border.top.color, equals(const Color(0xFF333737)));

      // Verify avatar section is inside a Center widget
      expect(find.byType(Center), findsWidgets);
    });

    testWidgets('tapping screen background dismisses keyboard focus', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ProfileSetupScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap to focus textfield
      await tester.tap(find.byType(TextField));
      await tester.pump();

      FocusScopeNode currentScope = FocusScope.of(tester.element(find.byType(TextField)));
      expect(currentScope.hasFocus, isTrue);

      // Tap on background
      await tester.tapAt(const Offset(10, 10));
      await tester.pump();

      currentScope = FocusScope.of(tester.element(find.byType(TextField)));
      expect(currentScope.hasFocus, isFalse);
    });
  });
}
