import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flash_ink/features/auth/data/services/auth_recovery_service.dart';
import 'package:flash_ink/features/auth/presentation/controllers/auth_troubleshooting_controller.dart';
import 'package:flash_ink/features/auth/presentation/screens/account_recovery_hub_screen.dart';
import 'package:flash_ink/features/auth/presentation/screens/auth_lockout_screen.dart';
import 'package:flash_ink/features/auth/presentation/screens/support_escalation_screen.dart';
import 'package:flash_ink/features/auth/presentation/sheets/account_collision_sheet.dart';
import 'package:flash_ink/features/auth/presentation/sheets/delivery_troubleshooting_sheet.dart';

class TestAuthCredential extends Fake implements AuthCredential {
  @override
  final String providerId = 'apple.com';
  @override
  final String signInMethod = 'apple.com';
}

class TestLinkedUser extends Fake implements User {
  @override
  final String uid = 'test_user_ui';
  @override
  final String email = 'tester@flash.ink';
  @override
  final String phoneNumber = '+15551234567';
  @override
  final bool isAnonymous = false;

  int linkCount = 0;
  AuthCredential? linkedCredential;

  @override
  Future<UserCredential> linkWithCredential(AuthCredential credential) async {
    linkCount++;
    linkedCredential = credential;
    return TestUserCredential(user: this, credential: credential);
  }

  @override
  Future<void> updatePhoneNumber(PhoneAuthCredential phoneCredential) async {}
}

class TestUserCredential extends Fake implements UserCredential {
  @override
  final User? user;
  @override
  final AuthCredential? credential;

  TestUserCredential({this.user, this.credential});
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirebaseFirestore fakeFirestore;
  late TestLinkedUser fakeUser;
  late AuthRecoveryService recoveryService;

  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.physicalSize = const Size(1080, 2400);
    binding.platformDispatcher.views.first.devicePixelRatio = 1.0;
    addTearDown(() {
      binding.platformDispatcher.views.first.resetPhysicalSize();
      binding.platformDispatcher.views.first.resetDevicePixelRatio();
    });

    fakeFirestore = FakeFirebaseFirestore();
    fakeUser = TestLinkedUser();
    recoveryService = AuthRecoveryService(
      firestore: fakeFirestore,
      currentUserOverride: fakeUser,
      otpGenerator: () => '123456',
    );
  });

  Widget buildTestableWidget({
    required Widget child,
    List<dynamic> overrides = const [],
  }) {
    return ProviderScope(
      overrides: [
        authRecoveryServiceProvider.overrideWithValue(recoveryService),
        ...overrides.cast(),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: child,
        ),
      ),
    );
  }

  group('Auth Troubleshooting UI Presentation Tests', () {
    testWidgets(
      'DeliveryTroubleshootingSheet: Renders masked destination, edit action, channel options, and triage link',
      (tester) async {
        bool editTapped = false;
        bool resendTapped = false;

        await tester.pumpWidget(
          buildTestableWidget(
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  DeliveryTroubleshootingSheet.show(
                    context: context,
                    destination: '+15550192834',
                    isPhone: true,
                    onEditDestination: () => editTapped = true,
                    onResendSms: () => resendTapped = true,
                  );
                },
                child: const Text('Open Delivery Sheet'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap to open sheet
        await tester.tap(find.text('Open Delivery Sheet'));
        await tester.pumpAndSettle();

        // Check masked destination and header
        expect(find.byKey(const Key('delivery_troubleshooting_sheet')), findsOneWidget);
        expect(find.text("Didn't receive a code?"), findsOneWidget);
        expect(find.text('+1 (555) •••-2834'), findsOneWidget);

        // Check channel options
        expect(find.byKey(const Key('delivery_resend_sms_option')), findsOneWidget);
        expect(find.byKey(const Key('delivery_voice_option')), findsOneWidget);
        expect(find.byKey(const Key('delivery_switch_email_option')), findsOneWidget);

        // Check triage link
        expect(find.byKey(const Key('delivery_recovery_hub_link')), findsOneWidget);

        // Tap edit
        await tester.tap(find.byKey(const Key('delivery_edit_destination_button')));
        await tester.pumpAndSettle();
        expect(editTapped, isTrue);

        // Re-open and tap resend
        await tester.tap(find.text('Open Delivery Sheet'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('delivery_resend_sms_option')));
        await tester.pumpAndSettle();
        expect(resendTapped, isTrue);

        // Re-open and tap triage link -> navigates to AccountRecoveryHubScreen
        await tester.tap(find.text('Open Delivery Sheet'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('delivery_recovery_hub_link')));
        await tester.pumpAndSettle();
        expect(find.byType(AccountRecoveryHubScreen), findsOneWidget);
      },
    );

    testWidgets(
      'AccountRecoveryHubScreen: Renders triage menu cards and launches respective flows',
      (tester) async {
        await tester.pumpWidget(
          buildTestableWidget(
            child: const AccountRecoveryHubScreen(),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Trouble Signing In?'), findsOneWidget);
        expect(find.byKey(const Key('hub_changed_phone_option')), findsOneWidget);
        expect(find.byKey(const Key('hub_forgot_method_option')), findsOneWidget);
        expect(find.byKey(const Key('hub_code_never_arrived_option')), findsOneWidget);
        expect(find.byKey(const Key('hub_contact_support_option')), findsOneWidget);

        // 1. Tap Code never arrived -> shows carrier short-code diagnostics
        await tester.tap(find.byKey(const Key('hub_code_never_arrived_option')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('recovery_diagnostic_sheet')), findsOneWidget);
        expect(find.text('Carrier Short-Code Diagnostics'), findsOneWidget);
        await tester.tap(find.byKey(const Key('recovery_diagnostic_done_button')));
        await tester.pumpAndSettle();

        // 2. Tap Changed phone number -> shows update phone sheet
        await tester.tap(find.byKey(const Key('hub_changed_phone_option')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('recovery_phone_update_sheet')), findsOneWidget);
        expect(find.byKey(const Key('recovery_email_field')), findsOneWidget);
        Navigator.of(tester.element(find.byKey(const Key('recovery_phone_update_sheet')))).pop();
        await tester.pumpAndSettle();

        // 3. Tap Contact support -> navigates to SupportEscalationScreen
        await tester.tap(find.byKey(const Key('hub_contact_support_option')));
        await tester.pumpAndSettle();
        expect(find.byType(SupportEscalationScreen), findsOneWidget);
      },
    );

    testWidgets(
      'AccountCollisionSheet: Renders required copy and links credential on primary CTA',
      (tester) async {
        bool collisionResolved = false;
        final pendingCred = TestAuthCredential();

        await tester.pumpWidget(
          buildTestableWidget(
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  AccountCollisionSheet.show(
                    context: context,
                    email: 'artist@flash.ink',
                    existingProvider: 'Google',
                    newProvider: 'Apple',
                    pendingCredential: pendingCred,
                    onCollisionResolved: () => collisionResolved = true,
                  );
                },
                child: const Text('Open Collision Sheet'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open Collision Sheet'));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('account_collision_sheet')), findsOneWidget);
        expect(find.text('Account Already Exists'), findsOneWidget);

        // Check required collision copy
        expect(find.byKey(const Key('account_collision_message_card')), findsOneWidget);
        expect(
          find.textContaining('An account with artist@flash.ink already exists using Google', findRichText: true),
          findsOneWidget,
        );

        // Tap primary CTA to link credentials
        await tester.tap(find.byKey(const Key('account_collision_primary_cta')));
        await tester.pumpAndSettle();

        expect(fakeUser.linkCount, equals(1));
        expect(fakeUser.linkedCredential, same(pendingCred));
        expect(collisionResolved, isTrue);
      },
    );

    testWidgets(
      'AuthLockoutScreen: Renders countdown timer MM:SS, warning indicator, and secondary bypasses',
      (tester) async {
        await tester.pumpWidget(
          buildTestableWidget(
            overrides: [
              authTroubleshootingControllerProvider.overrideWith(
                () => FakeLockoutController(remainingSeconds: 85),
              ),
            ],
            child: const AuthLockoutScreen(),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('auth_lockout_title')), findsOneWidget);
        expect(find.text('Temporarily Locked'), findsOneWidget);

        // 85 seconds should format as 01:25
        expect(find.byKey(const Key('auth_lockout_countdown_text')), findsOneWidget);
        expect(find.text('01:25'), findsOneWidget);

        // Social auth row for bypass
        expect(find.byKey(const Key('auth_lockout_social_bypass_row')), findsOneWidget);
        expect(find.byKey(const Key('auth_lockout_contact_support_button')), findsOneWidget);

        // Tap contact support -> navigates to SupportEscalationScreen
        await tester.tap(find.byKey(const Key('auth_lockout_contact_support_button')));
        await tester.pumpAndSettle();
        expect(find.byType(SupportEscalationScreen), findsOneWidget);
      },
    );

    testWidgets(
      'SupportEscalationScreen: Pre-populates diagnostic badges and submits escalation ticket',
      (tester) async {
        await tester.pumpWidget(
          buildTestableWidget(
            child: const SupportEscalationScreen(
              initialEmail: 'client@flash.ink',
              initialPhone: '+15559876543',
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Account Concierge'), findsOneWidget);

        // Diagnostic badges
        expect(find.byKey(const Key('support_diagnostics_card')), findsOneWidget);
        expect(find.text('v1.0.0+1'), findsOneWidget);
        expect(find.text('+1 (•••) •••-6543'), findsOneWidget);

        // Pre-filled contact email
        expect(find.byKey(const Key('support_contact_email_field')), findsOneWidget);
        expect(find.text('client@flash.ink'), findsOneWidget);

        // Enter description
        await tester.enterText(
          find.byKey(const Key('support_description_field')),
          'Switched mobile carriers and my old SIM card is completely deactivated.',
        );
        await tester.pumpAndSettle();

        // Tap submit
        await tester.tap(find.byKey(const Key('support_submit_button')));
        await tester.pumpAndSettle();

        // Dialog with ticket reference should appear
        expect(find.text('Ticket Received'), findsOneWidget);
        expect(find.byKey(const Key('support_ticket_id_text')), findsOneWidget);

        // Tap Done to dismiss
        await tester.tap(find.byKey(const Key('support_ticket_done_button')));
        await tester.pumpAndSettle();
      },
    );
  });
}

class FakeLockoutController extends AuthTroubleshootingController {
  final int remainingSeconds;

  FakeLockoutController({required this.remainingSeconds});

  @override
  AuthTroubleshootingState build() {
    return AuthTroubleshootingState.rateLimited(
      remainingSeconds,
      errorMessage: 'Too many requests.',
    );
  }
}
