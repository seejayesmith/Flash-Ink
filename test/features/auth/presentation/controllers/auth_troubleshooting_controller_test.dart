// ignore: depend_on_referenced_packages
import 'package:fake_async/fake_async.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flash_ink/features/auth/data/services/auth_recovery_service.dart';
import 'package:flash_ink/features/auth/presentation/controllers/auth_troubleshooting_controller.dart';

class FakeAuthCredential extends Fake implements AuthCredential {
  @override
  final String providerId;
  @override
  final String signInMethod;

  FakeAuthCredential({
    this.providerId = 'google.com',
    this.signInMethod = 'google.com',
  });
}

class FakePhoneAuthCredential extends Fake implements PhoneAuthCredential {
  @override
  final String providerId = 'phone';
  @override
  final String signInMethod = 'phone';
  @override
  final String? verificationId;
  @override
  final String? smsCode;

  FakePhoneAuthCredential({
    this.verificationId = 'ver_123',
    this.smsCode = '654321',
  });
}

class FakeLinkedUser extends Fake implements User {
  @override
  final String uid;
  @override
  final String? email;
  @override
  String? phoneNumber;
  @override
  final bool isAnonymous;

  int linkWithCredentialCallCount = 0;
  AuthCredential? lastLinkedCredential;
  int updatePhoneCallCount = 0;
  PhoneAuthCredential? lastUpdatedPhoneCredential;
  FirebaseAuthException? linkExceptionToThrow;
  FirebaseAuthException? updatePhoneExceptionToThrow;

  FakeLinkedUser({
    this.uid = 'user_recovery_123',
    this.email = 'recovered@flash.ink',
    this.phoneNumber = '+15550192834',
    this.isAnonymous = false,
  });

  @override
  Future<UserCredential> linkWithCredential(AuthCredential credential) async {
    linkWithCredentialCallCount++;
    lastLinkedCredential = credential;
    if (linkExceptionToThrow != null) {
      throw linkExceptionToThrow!;
    }
    return FakeUserCredential(user: this, credential: credential);
  }

  @override
  Future<void> updatePhoneNumber(PhoneAuthCredential phoneCredential) async {
    updatePhoneCallCount++;
    lastUpdatedPhoneCredential = phoneCredential;
    if (updatePhoneExceptionToThrow != null) {
      throw updatePhoneExceptionToThrow!;
    }
  }
}

class FakeUserCredential extends Fake implements UserCredential {
  @override
  final User? user;
  @override
  final AuthCredential? credential;

  FakeUserCredential({this.user, this.credential});
}

class FakeControllableAuthRecoveryService extends AuthRecoveryService {
  FirebaseAuthException? sendOtpException;
  FirebaseAuthException? verifyOtpException;

  int sendOtpCallCount = 0;
  int verifyOtpCallCount = 0;
  int resolveCollisionCallCount = 0;

  FakeControllableAuthRecoveryService({
    super.firestore,
    super.currentUserOverride,
    super.otpGenerator,
  });

  @override
  Future<void> sendSecondaryEmailOtp(String email) async {
    sendOtpCallCount++;
    if (sendOtpException != null) {
      throw sendOtpException!;
    }
    return super.sendSecondaryEmailOtp(email);
  }

  @override
  Future<bool> verifySecondaryEmailOtp({
    required String email,
    required String code,
  }) async {
    verifyOtpCallCount++;
    if (verifyOtpException != null) {
      throw verifyOtpException!;
    }
    return super.verifySecondaryEmailOtp(email: email, code: code);
  }

  @override
  Future<UserCredential> resolveAccountCollision({
    required AuthCredential credential,
    AuthCredential? existingCredential,
  }) async {
    resolveCollisionCallCount++;
    return super.resolveAccountCollision(
      credential: credential,
      existingCredential: existingCredential,
    );
  }
}

void main() {
  group('AuthTroubleshootingController & AuthRecoveryService Unit Tests', () {
    late FakeFirebaseFirestore fakeFirestore;
    late FakeLinkedUser fakeUser;
    late FakeControllableAuthRecoveryService fakeService;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      fakeUser = FakeLinkedUser();
      fakeService = FakeControllableAuthRecoveryService(
        firestore: fakeFirestore,
        currentUserOverride: fakeUser,
        otpGenerator: () => '482910',
      );
    });

    ProviderContainer createContainer() {
      return ProviderContainer(
        overrides: [
          authRecoveryServiceProvider.overrideWithValue(fakeService),
        ],
      );
    }

    test('Initial state is AuthTroubleshootingState.idle()', () {
      final container = createContainer();
      addTearDown(container.dispose);

      final asyncState = container.read(authTroubleshootingControllerProvider);
      expect(asyncState.value, equals(const AuthTroubleshootingState.idle()));
      expect(
        asyncState.value?.status,
        equals(AuthTroubleshootingStatus.idle),
      );
    });

    test(
      'Cooldown tick: sendSecondaryEmailOtp transitions sendingCode -> codeSent(60) and ticks down each second to 0',
      () {
        fakeAsync((async) {
          final container = createContainer();
          addTearDown(container.dispose);

          final observedStates = <AuthTroubleshootingState>[];
          container.listen<AsyncValue<AuthTroubleshootingState>>(
            authTroubleshootingControllerProvider,
            (_, next) {
              if (next.hasValue) {
                observedStates.add(next.requireValue);
              }
            },
            fireImmediately: true,
          );

          final controller = container.read(
            authTroubleshootingControllerProvider.notifier,
          );

          controller.sendSecondaryEmailOtp(
            'Artist@Flash.Ink',
            cooldownSeconds: 60,
          );

          // Flush microtasks so sendSecondaryEmailOtp completes
          async.flushMicrotasks();

          expect(fakeService.sendOtpCallCount, equals(1));
          expect(
            observedStates,
            containsAllInOrder([
              const AuthTroubleshootingState.idle(),
              const AuthTroubleshootingState.sendingCode(
                email: 'Artist@Flash.Ink',
              ),
              const AuthTroubleshootingState.codeSent(
                60,
                email: 'artist@flash.ink',
              ),
            ]),
          );

          // Advance 1 second -> cooldown should tick from 60 to 59
          async.elapse(const Duration(seconds: 1));
          expect(
            container.read(authTroubleshootingControllerProvider).value,
            equals(
              const AuthTroubleshootingState.codeSent(
                59,
                email: 'artist@flash.ink',
              ),
            ),
          );
          expect(
            container
                .read(authTroubleshootingControllerProvider)
                .value
                ?.isResendBlocked,
            isTrue,
          );

          // Advance 29 more seconds -> cooldown should be 30
          async.elapse(const Duration(seconds: 29));
          expect(
            container
                .read(authTroubleshootingControllerProvider)
                .value
                ?.cooldown,
            equals(30),
          );

          // Advance remaining 30 seconds -> cooldown reaches 0 and stops ticking
          async.elapse(const Duration(seconds: 30));
          expect(
            container.read(authTroubleshootingControllerProvider).value,
            equals(
              const AuthTroubleshootingState.codeSent(
                0,
                email: 'artist@flash.ink',
              ),
            ),
          );
          expect(
            container
                .read(authTroubleshootingControllerProvider)
                .value
                ?.isResendBlocked,
            isFalse,
          );

          // Extra time elapsed does not go negative
          async.elapse(const Duration(seconds: 5));
          expect(
            container
                .read(authTroubleshootingControllerProvider)
                .value
                ?.cooldown,
            equals(0),
          );
        });
      },
    );

    test(
      'Rate-limit catch: catches FirebaseAuthException(too-many-requests), emits rateLimited(seconds), and ticks down',
      () {
        fakeAsync((async) {
          fakeService.sendOtpException = FirebaseAuthException(
            code: 'too-many-requests',
            message: 'We have blocked all requests from this device.',
          );

          final container = createContainer();
          addTearDown(container.dispose);

          final sub = container.listen(
            authTroubleshootingControllerProvider,
            (_, _) {},
          );
          addTearDown(sub.close);

          final controller = container.read(
            authTroubleshootingControllerProvider.notifier,
          );

          controller.sendSecondaryEmailOtp(
            'locked@flash.ink',
            rateLimitSeconds: 45,
          );
          async.flushMicrotasks();

          final currentState =
              container.read(authTroubleshootingControllerProvider).value;
          expect(currentState, isA<AuthTroubleshootingRateLimited>());
          expect(
            currentState?.status,
            equals(AuthTroubleshootingStatus.rateLimited),
          );
          expect(currentState?.seconds, equals(45));
          expect(currentState?.errorCode, equals('too-many-requests'));
          expect(currentState?.isResendBlocked, isTrue);

          // Advance 5 seconds -> rate limit countdown ticks to 40
          async.elapse(const Duration(seconds: 5));
          expect(
            container
                .read(authTroubleshootingControllerProvider)
                .value
                ?.seconds,
            equals(40),
          );

          // Advance remaining 40 seconds -> reaches 0
          async.elapse(const Duration(seconds: 40));
          expect(
            container
                .read(authTroubleshootingControllerProvider)
                .value
                ?.seconds,
            equals(0),
          );
          expect(
            container
                .read(authTroubleshootingControllerProvider)
                .value
                ?.isResendBlocked,
            isFalse,
          );
        });
      },
    );

    test(
      'Successful credential linking: resolveAccountCollision invokes linkWithCredential, updates Firestore, and emits success',
      () async {
        final container = createContainer();
        addTearDown(container.dispose);

        final observedStatuses = <AuthTroubleshootingStatus>[];
        container.listen<AsyncValue<AuthTroubleshootingState>>(
          authTroubleshootingControllerProvider,
          (_, next) {
            if (next.hasValue) {
              observedStatuses.add(next.requireValue.status);
            }
          },
          fireImmediately: true,
        );

        final controller = container.read(
          authTroubleshootingControllerProvider.notifier,
        );
        final pendingCredential = FakeAuthCredential(
          providerId: 'google.com',
          signInMethod: 'google.com',
        );

        final credentialResult = await controller.resolveAccountCollision(
          credential: pendingCredential,
        );

        expect(credentialResult, isNotNull);
        expect(fakeService.resolveCollisionCallCount, equals(1));
        expect(fakeUser.linkWithCredentialCallCount, equals(1));
        expect(fakeUser.lastLinkedCredential, same(pendingCredential));

        // Verify state transitions: idle -> verifying -> success
        expect(
          observedStatuses,
          equals([
            AuthTroubleshootingStatus.idle,
            AuthTroubleshootingStatus.verifying,
            AuthTroubleshootingStatus.success,
          ]),
        );

        final finalState =
            container.read(authTroubleshootingControllerProvider).value;
        expect(finalState, isA<AuthTroubleshootingSuccess>());
        expect(finalState?.email, equals('recovered@flash.ink'));
        expect(finalState?.phoneNumber, equals('+15550192834'));

        // Verify Firestore user document was synced
        final userDoc = await fakeFirestore
            .collection('users')
            .doc(fakeUser.uid)
            .get();
        expect(userDoc.exists, isTrue);
        expect(userDoc.data()?['isAnonymous'], isFalse);
        expect(userDoc.data()?['email'], equals('recovered@flash.ink'));
      },
    );

    test(
      'Firebase exception mapping: account-exists-with-different-credential and invalid-verification-code',
      () async {
        final container = createContainer();
        addTearDown(container.dispose);

        final sub = container.listen(
          authTroubleshootingControllerProvider,
          (_, _) {},
        );
        addTearDown(sub.close);

        final controller = container.read(
          authTroubleshootingControllerProvider.notifier,
        );

        // 1. Send OTP then verify with wrong 6-digit code -> invalid-verification-code
        await controller.sendSecondaryEmailOtp('client@flash.ink');
        await controller.verifySecondaryEmailOtp(
          email: 'client@flash.ink',
          code: '000000',
        );

        final invalidCodeState =
            container.read(authTroubleshootingControllerProvider).value;
        expect(invalidCodeState, isA<AuthTroubleshootingError>());
        expect(
          invalidCodeState?.errorCode,
          equals('invalid-verification-code'),
        );
        expect(
          invalidCodeState?.errorMessage,
          contains('verification code entered is invalid'),
        );

        // 2. Verify with correct OTP -> accountMatched
        await controller.verifySecondaryEmailOtp(
          email: 'client@flash.ink',
          code: '482910',
        );
        final matchedState =
            container.read(authTroubleshootingControllerProvider).value;
        expect(matchedState, isA<AuthTroubleshootingAccountMatched>());
        expect(
          matchedState?.status,
          equals(AuthTroubleshootingStatus.accountMatched),
        );

        // 3. Collision error mapping for account-exists-with-different-credential
        final conflictingCredential = FakeAuthCredential(
          providerId: 'apple.com',
          signInMethod: 'apple.com',
        );
        fakeUser.linkExceptionToThrow = FirebaseAuthException(
          code: 'account-exists-with-different-credential',
          email: 'conflict@flash.ink',
          credential: conflictingCredential,
        );

        await controller.resolveAccountCollision(
          credential: conflictingCredential,
        );

        final collisionState =
            container.read(authTroubleshootingControllerProvider).value;
        expect(collisionState, isA<AuthTroubleshootingError>());
        expect(
          collisionState?.errorCode,
          equals('account-exists-with-different-credential'),
        );
        expect(collisionState?.isAccountCollision, isTrue);
        expect(collisionState?.email, equals('conflict@flash.ink'));
        expect(
          collisionState?.pendingCredential,
          same(conflictingCredential),
        );
      },
    );

    test(
      'updateUserPhoneNumber and submitSupportEscalation persist to Firestore and transition to success',
      () async {
        final container = createContainer();
        addTearDown(container.dispose);

        final sub = container.listen(
          authTroubleshootingControllerProvider,
          (_, _) {},
        );
        addTearDown(sub.close);

        final controller = container.read(
          authTroubleshootingControllerProvider.notifier,
        );

        final phoneCred = FakePhoneAuthCredential();
        await controller.updateUserPhoneNumber(
          phoneNumber: '(555) 234-5678',
          credential: phoneCred,
        );

        expect(fakeUser.updatePhoneCallCount, equals(1));
        expect(
          container.read(authTroubleshootingControllerProvider).value?.status,
          equals(AuthTroubleshootingStatus.success),
        );

        final userDoc = await fakeFirestore
            .collection('users')
            .doc(fakeUser.uid)
            .get();
        expect(userDoc.data()?['phoneNumber'], equals('+15552345678'));
        expect(userDoc.data()?['phoneVerified'], isTrue);

        // Support escalation
        final ticketId = await controller.submitSupportEscalation(
          contactEmail: 'help@flash.ink',
          reason: 'Lost access to my old carrier phone number.',
          phoneNumber: '+15552345678',
        );

        expect(ticketId, isNotNull);
        final escalationState =
            container.read(authTroubleshootingControllerProvider).value;
        expect(escalationState, isA<AuthTroubleshootingSuccess>());
        expect(escalationState?.escalationTicketId, equals(ticketId));

        final ticketDoc = await fakeFirestore
            .collection('support_escalations')
            .doc(ticketId)
            .get();
        expect(ticketDoc.exists, isTrue);
        expect(ticketDoc.data()?['contactEmail'], equals('help@flash.ink'));
        expect(ticketDoc.data()?['status'], equals('open'));
      },
    );
  });
}
