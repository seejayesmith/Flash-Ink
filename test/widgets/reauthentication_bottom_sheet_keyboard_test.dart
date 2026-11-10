import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flash_ink/services/auth_service.dart';
import 'package:flash_ink/widgets/reauthentication_bottom_sheet.dart';

class _FakeAuthService extends AuthService {
  @override
  List<String> get currentUserProviders => ['password'];

  @override
  bool get isGuest => false;
}

void main() {
  group('ReauthenticationBottomSheet Keyboard Avoidance Tests', () {
    testWidgets('Renders seamless keyboard spacer and hairline divider without external padding', (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      tester.view.padding = const FakeViewPadding(bottom: 102);
      tester.view.viewPadding = const FakeViewPadding(bottom: 102);
      tester.view.viewInsets = const FakeViewPadding(bottom: 900); // 300 pt keyboard
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetPadding();
        tester.view.resetViewPadding();
        tester.view.resetViewInsets();
      });

      final authService = _FakeAuthService();

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(390, 844),
              viewPadding: EdgeInsets.only(bottom: 34),
              viewInsets: EdgeInsets.only(bottom: 300),
            ),
            child: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () {
                      ReauthenticationBottomSheet.show(
                        context: context,
                        authService: authService,
                      );
                    },
                    child: const Text('Open Sheet'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      // Verify the sheet content is present
      expect(find.text('Security Verification'), findsOneWidget);
      expect(find.byKey(const Key('reauth_password_field')), findsOneWidget);

      // Verify hairline divider and keyboard spacer are rendered
      expect(find.byKey(const Key('sheet_keyboard_hairline_divider')), findsOneWidget);
      expect(find.byKey(const Key('sheet_keyboard_spacer')), findsOneWidget);

      final spacer = tester.widget<SizedBox>(find.byKey(const Key('sheet_keyboard_spacer')));
      expect(spacer.height, equals(300.0));

      // Verify SingleChildScrollView has onDrag keyboard dismissal
      final scrollView = tester.widget<SingleChildScrollView>(
        find.descendant(
          of: find.byType(ReauthenticationBottomSheet),
          matching: find.byType(SingleChildScrollView),
        ),
      );
      expect(
        scrollView.keyboardDismissBehavior,
        equals(ScrollViewKeyboardDismissBehavior.onDrag),
      );
    });
  });
}
