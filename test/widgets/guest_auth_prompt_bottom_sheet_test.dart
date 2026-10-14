import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flash_ink/services/auth_service.dart';
import 'package:flash_ink/widgets/guest_auth_prompt_bottom_sheet.dart';

void main() {
  group('GuestAuthPromptBottomSheet Tests', () {
    testWidgets('Renders favoriteArtist prompt with contextual copy and icons', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GuestAuthPromptBottomSheet(
              actionType: AuthActionPromptType.favoriteArtist,
            ),
          ),
        ),
      );

      expect(find.text('Save Your Favorites'), findsOneWidget);
      expect(
        find.text('Create an account to save artists, bookmark designs, and sync favorites across devices.'),
        findsOneWidget,
      );
      expect(find.text('Continue with Email'), findsOneWidget);
      expect(find.text('Maybe Later'), findsOneWidget);
    });

    testWidgets('Renders bookFlash prompt with contextual copy', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GuestAuthPromptBottomSheet(
              actionType: AuthActionPromptType.bookFlash,
            ),
          ),
        ),
      );

      expect(find.text('Book Your Flash Piece'), findsOneWidget);
      expect(
        find.text('Create an account to reserve this flash design, select your appointment date, and confirm your booking.'),
        findsOneWidget,
      );
    });

    testWidgets('Renders customRequest prompt with contextual copy', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GuestAuthPromptBottomSheet(
              actionType: AuthActionPromptType.customRequest,
            ),
          ),
        ),
      );

      expect(find.text('Submit Custom Request'), findsOneWidget);
      expect(
        find.text('Create an account to share your concept, upload reference photos, and collaborate with the artist.'),
        findsOneWidget,
      );
    });

    testWidgets('Renders waitlist prompt with contextual copy', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GuestAuthPromptBottomSheet(
              actionType: AuthActionPromptType.waitlist,
            ),
          ),
        ),
      );

      expect(find.text('Join VIP Waitlist'), findsOneWidget);
      expect(
        find.text('Create an account to receive priority notifications and early access when books open.'),
        findsOneWidget,
      );
    });

    testWidgets('Tapping Continue with Email reveals email & password input form', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GuestAuthPromptBottomSheet(
              actionType: AuthActionPromptType.favoriteArtist,
            ),
          ),
        ),
      );

      expect(find.byType(TextFormField), findsNothing);

      await tester.tap(find.text('Continue with Email'));
      await tester.pumpAndSettle();

      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.text('Create Account'), findsOneWidget);
      expect(find.text('Already have an account? Sign In'), findsOneWidget);

      // Toggle to Sign In
      await tester.tap(find.text('Already have an account? Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text("Don't have an account? Create one"), findsOneWidget);
    });

    testWidgets('Tapping Maybe Later pops bottom sheet with false', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    result = await showModalBottomSheet<bool>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => const GuestAuthPromptBottomSheet(
                        actionType: AuthActionPromptType.favoriteArtwork,
                      ),
                    );
                  },
                  child: const Text('Open Modal'),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      expect(find.text('Save This Artwork'), findsOneWidget);

      await tester.ensureVisible(find.text('Maybe Later'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Maybe Later'));
      await tester.pumpAndSettle();

      expect(result, isFalse);
    });

    testWidgets('ensureAuthenticated returns true immediately for non-guest user', (tester) async {
      final mockAuth = AuthService(
        mockUser: DevMockUser(uid: 'registered_1', isAnonymous: false),
      );

      bool? authenticated;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    authenticated = await GuestAuthPromptBottomSheet.ensureAuthenticated(
                      context,
                      actionType: AuthActionPromptType.bookFlash,
                      authService: mockAuth,
                    );
                  },
                  child: const Text('Trigger Action'),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Trigger Action'));
      await tester.pumpAndSettle();

      expect(authenticated, isTrue);
      // Bottom sheet was never shown
      expect(find.text('Book Your Flash Piece'), findsNothing);
    });

    testWidgets('ensureAuthenticated opens bottom sheet for anonymous guest user', (tester) async {
      final mockAuth = AuthService(
        mockUser: DevMockUser(uid: 'guest_1', isAnonymous: true),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    GuestAuthPromptBottomSheet.ensureAuthenticated(
                      context,
                      actionType: AuthActionPromptType.favoriteArtist,
                      authService: mockAuth,
                    );
                  },
                  child: const Text('Favorite Artist'),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Favorite Artist'));
      await tester.pumpAndSettle();

      expect(find.text('Save Your Favorites'), findsOneWidget);
    });
  });
}
