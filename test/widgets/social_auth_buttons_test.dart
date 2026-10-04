import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flash_ink/widgets/social_auth_buttons.dart';

void main() {
  group('SocialAuthButtons Widget Tests', () {
    testWidgets('Renders CircularGoogleSignInButton with correct properties and handles tap', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: CircularGoogleSignInButton(
                onPressed: () => tapped = true,
              ),
            ),
          ),
        ),
      );

      final buttonFinder = find.byKey(const Key('google_sign_in_button'));
      expect(buttonFinder, findsOneWidget);
      expect(find.byType(GoogleLogo), findsOneWidget);

      await tester.tap(buttonFinder);
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('CircularGoogleSignInButton displays progress indicator when loading', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: CircularGoogleSignInButton(
                isLoading: true,
                onPressed: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('Renders CircularAppleSignInButton with correct properties and handles tap', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: CircularAppleSignInButton(
                onPressed: () => tapped = true,
              ),
            ),
          ),
        ),
      );

      final buttonFinder = find.byKey(const Key('apple_sign_in_button'));
      expect(buttonFinder, findsOneWidget);
      expect(find.byIcon(Icons.apple), findsOneWidget);

      await tester.tap(buttonFinder);
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('CircularAppleSignInButton displays progress indicator when loading', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: CircularAppleSignInButton(
                isLoading: true,
                onPressed: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('SocialAuthRow renders both circular buttons side by side', (tester) async {
      bool googleTapped = false;
      bool appleTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SocialAuthRow(
                onGooglePressed: () => googleTapped = true,
                onApplePressed: () => appleTapped = true,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(CircularGoogleSignInButton), findsOneWidget);
      expect(find.byType(CircularAppleSignInButton), findsOneWidget);

      await tester.tap(find.byKey(const Key('google_sign_in_button')));
      await tester.pump();
      expect(googleTapped, isTrue);

      await tester.tap(find.byKey(const Key('apple_sign_in_button')));
      await tester.pump();
      expect(appleTapped, isTrue);
    });

    testWidgets('SocialAuthDivider renders custom or default label', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SocialAuthDivider(label: 'OR SIGN IN WITH'),
            ),
          ),
        ),
      );

      expect(find.text('OR SIGN IN WITH'), findsOneWidget);
      expect(find.byType(Divider), findsNWidgets(2));
    });
  });
}
