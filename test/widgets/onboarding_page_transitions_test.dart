import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flash_ink/widgets/fade_page_route.dart';
import 'package:flash_ink/widgets/artist_stepper_header.dart';
import 'package:flash_ink/screens/profile_setup_screen.dart';
import 'package:flash_ink/services/auth_service.dart';

class MockTestUser extends Fake implements User {
  @override
  final String uid = 'test_user_1';
  @override
  final String? email = 'client@flash.ink';
  @override
  final String? displayName = 'Test Client';
}

class FakeTestAuthService extends AuthService {
  final MockTestUser mockUser = MockTestUser();

  @override
  User? get currentUser => mockUser;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  group('FadePageRoute Tests', () {
    testWidgets('FadePageRoute builds pure FadeTransition with no SlideTransition', (tester) async {
      final route = FadePageRoute(builder: (_) => const SizedBox(key: Key('route_child')));
      final controller = AnimationController(vsync: const TestVSync());

      final widget = route.buildTransitions(
        MockBuildContext(),
        controller,
        kAlwaysDismissedAnimation,
        const SizedBox(key: Key('route_child')),
      );

      // Verify FadeTransition is the root transition widget
      expect(widget, isA<FadeTransition>());
      final fade = widget as FadeTransition;
      expect(fade.child, isA<SizedBox>());
      expect((fade.child as SizedBox).key, const Key('route_child'));
    });

    testWidgets('FadePageRoute smoothly fades in page content over 250ms', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    FadePageRoute(
                      builder: (_) => const Scaffold(
                        body: Text('Fade Page 2'),
                      ),
                    ),
                  );
                },
                child: const Text('Navigate'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Navigate'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 125));

      // Fade page is in the middle of fading in
      expect(find.text('Fade Page 2'), findsOneWidget);
      final fadeWidgets = tester.widgetList<FadeTransition>(
        find.ancestor(of: find.text('Fade Page 2'), matching: find.byType(FadeTransition)),
      );
      expect(fadeWidgets, isNotEmpty);
      expect(fadeWidgets.first.opacity.value, greaterThan(0.0));
      expect(fadeWidgets.first.opacity.value, lessThan(1.0));

      await tester.pumpAndSettle();
      expect(find.text('Fade Page 2'), findsOneWidget);
    });
  });

  group('ArtistStepperHeader Stationary Hero Tests', () {
    testWidgets('Hero flight maintains stationary header and animates step pills across routes', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              title: const ArtistStepperHeader(currentStep: 1),
            ),
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    FadePageRoute(
                      builder: (_) => Scaffold(
                        appBar: AppBar(
                          title: const ArtistStepperHeader(currentStep: 2),
                        ),
                        body: const Text('Step 2 Content'),
                      ),
                    ),
                  );
                },
                child: const Text('Next Step'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Step 1 active: width 24; Step 2: width 12
      final size1Before = tester.getSize(find.byKey(const Key('artist_step_indicator_1')));
      final size2Before = tester.getSize(find.byKey(const Key('artist_step_indicator_2')));
      expect(size1Before.width, 24.0);
      expect(size2Before.width, 12.0);

      // Trigger navigation
      await tester.tap(find.text('Next Step'));
      await tester.pump();
      // Pump halfway through 250ms transition
      await tester.pump(const Duration(milliseconds: 125));

      // Stepper header is rendered during Hero flight shuttle
      expect(find.byKey(const Key('artist_step_indicator_1')), findsWidgets);
      expect(find.byKey(const Key('artist_step_indicator_2')), findsWidgets);

      // Complete navigation
      await tester.pumpAndSettle();

      // Step 2 active: width 24; Step 1 completed: width 12
      final size1After = tester.getSize(find.byKey(const Key('artist_step_indicator_1')));
      final size2After = tester.getSize(find.byKey(const Key('artist_step_indicator_2')));
      expect(size1After.width, 12.0);
      expect(size2After.width, 24.0);
    });
  });

  group('ProfileSetupScreen In-Place Transitions Tests', () {
    testWidgets('Transitions between username and photo without PageView horizontal slide', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ProfileSetupScreen(
            authService: FakeTestAuthService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Confirm Step 1 of 4 is shown
      expect(find.text('Step 1 of 4'), findsOneWidget);
      // Confirm AnimatedSwitcher is used rather than PageView
      expect(find.byType(PageView), findsNothing);
      expect(find.byType(AnimatedSwitcher), findsOneWidget);

      // Skip username step
      expect(find.text('Skip'), findsOneWidget);
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      // Now at Step 2 of 4 (Photo step)
      expect(find.text('Step 2 of 4'), findsOneWidget);
      expect(find.text('Add a profile photo'), findsOneWidget);

      // Tap back button in app bar
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      // Returned smoothly to Step 1 of 4
      expect(find.text('Step 1 of 4'), findsOneWidget);
    });
  });
}

class MockBuildContext extends Fake implements BuildContext {}
