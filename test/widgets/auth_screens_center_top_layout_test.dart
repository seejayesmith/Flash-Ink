import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:flash_ink/theme/app_spacing.dart';
import 'package:flash_ink/widgets/adaptive_glass_container.dart';
import 'package:flash_ink/screens/phone_entry_screen.dart';
import 'package:flash_ink/screens/phone_verification_screen.dart';
import 'package:flash_ink/screens/email_auth_screen.dart';
import 'package:flash_ink/screens/email_verification_screen.dart';
import 'package:flash_ink/services/auth_service.dart';

class MockUser extends Fake implements User {
  @override
  String get uid => 'mock-uid-123';
  @override
  String? get email => 'test@flash.ink';
  @override
  String? get displayName => 'Test User';
}

class FakeAuthService extends Fake implements AuthService {
  final _controller = StreamController<User?>.broadcast();
  User? _currentUser = MockUser();

  @override
  User? get currentUser => _currentUser;

  @override
  Stream<User?> get authStateChanges => _controller.stream;

  @override
  Future<void> signOut() async {
    _currentUser = null;
    _controller.add(null);
  }
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('Auth & Verification Screens Center-Top Layout Alignment', () {
    const testScreenSize = Size(400, 850);

    testWidgets('PhoneEntryScreen: Container is positioned center-top with 24px headerTop spacing', (tester) async {
      tester.view.physicalSize = testScreenSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              padding: EdgeInsets.only(top: 44.0, bottom: 34.0),
              size: testScreenSize,
            ),
            child: PhoneEntryScreen(
              role: 'client',
              authService: FakeAuthService(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final cardFinder = find.byType(AdaptiveGlassContainer);
      expect(cardFinder, findsOneWidget);

      final cardTop = tester.getTopLeft(cardFinder).dy;
      final cardRect = tester.getRect(cardFinder);

      // topInset = topSafeArea (44) + kToolbarHeight (56) = 100.
      // Top spacing = AppSpacing.headerTop = 24.
      // Expected card top = 100 + 24 = 124.
      expect(cardTop, equals(124.0));

      // Horizontally centered within the 400px screen (margin of 20px on each side)
      expect(cardRect.left, equals(AppSpacing.screenMargin));
      expect(cardRect.right, equals(400.0 - AppSpacing.screenMargin));

      // Verify CTA button is at the bottom
      final ctaFinder = find.text('SEND VERIFICATION CODE');
      expect(ctaFinder, findsOneWidget);
      final ctaTop = tester.getTopLeft(ctaFinder).dy;

      // Space below card to CTA must be much larger than the 24px top space (center-top layout)
      final spaceBelowCard = ctaTop - cardRect.bottom;
      expect(spaceBelowCard, greaterThan(100.0));
    });

    testWidgets('PhoneVerificationScreen: Container is positioned center-top with 24px headerTop spacing', (tester) async {
      tester.view.physicalSize = testScreenSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              padding: EdgeInsets.only(top: 44.0, bottom: 34.0),
              size: testScreenSize,
            ),
            child: PhoneVerificationScreen(
              phoneNumber: '+15550192834',
              role: 'client',
              authService: FakeAuthService(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final cardFinder = find.byType(AdaptiveGlassContainer);
      expect(cardFinder, findsOneWidget);

      final cardTop = tester.getTopLeft(cardFinder).dy;
      final cardRect = tester.getRect(cardFinder);

      // Expected card top = 100 (topInset) + 24 (AppSpacing.headerTop) = 124.
      expect(cardTop, equals(124.0));

      // Horizontally centered with 20px margin
      expect(cardRect.left, equals(AppSpacing.screenMargin));
      expect(cardRect.right, equals(400.0 - AppSpacing.screenMargin));

      final ctaFinder = find.text('VERIFY');
      expect(ctaFinder, findsOneWidget);
      final ctaTop = tester.getTopLeft(ctaFinder).dy;
      expect(ctaTop - cardRect.bottom, greaterThan(80.0));
    });

    testWidgets('EmailAuthScreen: Container is positioned center-top with 24px headerTop spacing', (tester) async {
      tester.view.physicalSize = testScreenSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              padding: EdgeInsets.only(top: 44.0, bottom: 34.0),
              size: testScreenSize,
            ),
            child: EmailAuthScreen(
              role: 'client',
              authService: FakeAuthService(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final cardFinder = find.byType(AdaptiveGlassContainer);
      expect(cardFinder, findsOneWidget);

      final cardTop = tester.getTopLeft(cardFinder).dy;
      final cardRect = tester.getRect(cardFinder);

      expect(cardTop, equals(124.0));
      expect(cardRect.left, equals(AppSpacing.screenMargin));
      expect(cardRect.right, equals(400.0 - AppSpacing.screenMargin));

      final ctaFinder = find.text('CREATE ACCOUNT');
      expect(ctaFinder, findsOneWidget);
    });

    testWidgets('EmailVerificationScreen: Container is positioned center-top with 24px headerTop spacing', (tester) async {
      tester.view.physicalSize = testScreenSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              padding: EdgeInsets.only(top: 44.0, bottom: 34.0),
              size: testScreenSize,
            ),
            child: EmailVerificationScreen(
              role: 'client',
              authService: FakeAuthService(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final cardFinder = find.byType(AdaptiveGlassContainer);
      expect(cardFinder, findsOneWidget);

      final cardTop = tester.getTopLeft(cardFinder).dy;
      final cardRect = tester.getRect(cardFinder);

      expect(cardTop, equals(124.0));
      expect(cardRect.left, equals(AppSpacing.screenMargin));
      expect(cardRect.right, equals(400.0 - AppSpacing.screenMargin));

      final ctaFinder = find.text("I've Verified My Email");
      expect(ctaFinder, findsOneWidget);
    });
  });
}
