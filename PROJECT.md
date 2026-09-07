# Project: Flash Ink Phone Auth Migration & Error Surfacing

## Architecture
- **State Management**: Pure Flutter local state management (`StatefulWidget`, `setState`) with imperative `Navigator` routing.
- **Authentication**: `FirebaseAuth.instance` encapsulated in `AuthService` (`lib/services/auth_service.dart`).
- **Data Persistence**: `FirebaseFirestore.instance` storing user documents under `users/{uid}`.
- **Dependency Injection**: UI screens (`AccountCreationScreen`, `PhoneVerificationScreen`) accept an optional `AuthService? authService` parameter in constructors (defaulting to `AuthService()`) to allow test harnesses and `FakeAuthService` injection for automated UI/integration testing.
- **Integration Testing**: Uses Flutter's official `integration_test` package (`package:integration_test/integration_test.dart`) with test drivers / runners for macOS desktop and headless execution.

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| 1 | Standard Phone Sign-In in AuthService | Replace MFA enrollment with standard `verifyPhoneNumber` and `signInWithPhoneCredential` creating primary user | M1 | Survey (R1) |
| 2 | Phone Auth Exception Mapping | Map Firebase phone error codes (`invalid-phone-number`, `invalid-verification-code`, `session-expired`, etc.) in `AuthService` | M1 | Survey (R2) |
| 3 | AuthService Dependency Injection | Allow constructor injection of `AuthService` in `AccountCreationScreen` and `PhoneVerificationScreen` | M1 | Survey (Architecture) |
| 4 | Remove Silent Anonymous Login & Fake IDs | Remove `signInAnonymously()`, fake `vid_${timestamp}`, and swallowed exceptions from `AccountCreationScreen` | M1 | Survey (R1, R2) |
| 5 | Surface SMS Dispatch Errors in UI | Visibly display SMS dispatch failure in `AccountCreationScreen`, abort navigation, and keep modal open | M1 | Survey (R2) |
| 6 | Remove Silent Verification Fallback | Remove empty `catch (_)` in `PhoneVerificationScreen._verifyCode()`, prevent premature Firestore writes and navigation | M1 | Survey (R2) |
| 7 | Surface OTP Verification Errors in UI | Visibly display invalid OTP verification code error in `PhoneVerificationScreen`, clear code, and abort navigation | M1 | Survey (R2) |
| 8 | Real Resend SMS Flow | Replace dummy green SnackBar in `PhoneVerificationScreen` with actual SMS re-request and error handling | M1 | Survey (R2) |
| 9 | Baseline Test Suite Fix | Fix stale `test/widget_test.dart` counter test to assert `SplashScreen` so suite baseline passes | M1 | Survey (Test Infra) |
| 10 | Integration Test Infra Setup | Add `integration_test: sdk: flutter` to `pubspec.yaml`, setup test harness and `FakeAuthService` | M2 | Survey (AC) |
| 11 | Integration Test: Valid Flow | Verify complete UI flow: phone entry -> SMS code entry -> transition to `ProfileSetupScreen` | M2 | Survey (AC) |
| 12 | Integration Test: Simulated Failure | Verify UI error surfacing when SMS sending fails or invalid verification code is entered | M2 | Survey (AC) |
| 13 | Final E2E Suite & Hardening | Run 100% of integration & unit tests, adversarial coverage verification, zero integrity violations | M3 | Orchestration Plan |

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| 1 | M1: Phone Auth Migration & UI Error Surfacing | Migrate AuthService to standard phone auth, add exception mapping, update AccountCreationScreen & PhoneVerificationScreen to surface errors, remove silent mock fallbacks, fix widget_test.dart baseline | none | DONE |
| 2 | M2: E2E Integration Test Suite | Add integration_test dependency, build FakeAuthService test harness, implement integration_test/phone_auth_flow_test.dart for valid flow and simulated failures, publish TEST_READY.md | M1 | DONE |
| 3 | M3: 100% E2E Verification & Hardening | Execute full test suite, pass 100% of tests, perform adversarial coverage hardening (Tier 5) and forensic integrity audit | M2 | DONE |

## Interface Contracts

### `AuthService` ↔ UI Screens
```dart
abstract class BaseAuthService {
  User? get currentUser;
  Stream<User?> get authStateChanges;

  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(Exception error) onVerificationFailed,
    void Function(PhoneAuthCredential credential)? onVerificationCompleted,
    void Function(String verificationId)? onCodeAutoRetrievalTimeout,
    int? forceResendingToken,
  });

  Future<UserCredential> signInWithPhoneCredential({
    required String verificationId,
    required String smsCode,
  });

  Future<void> updatePhoneVerificationStatus({
    required String uid,
    required String phoneNumber,
  });
}
```

### `AccountCreationScreen` Constructor
```dart
const AccountCreationScreen({
  super.key,
  this.role = 'client',
  AuthService? authService,
});
```

### `PhoneVerificationScreen` Constructor
```dart
const PhoneVerificationScreen({
  super.key,
  required this.phoneNumber,
  required this.verificationId,
  this.resendToken,
  AuthService? authService,
});
```

## Code Layout
- `lib/services/auth_service.dart`: Main Firebase Auth service with standard phone auth and exception mapping.
- `lib/screens/account_creation_screen.dart`: Phone number entry bottom sheet, phone validation, SMS dispatch, error container / SnackBar.
- `lib/screens/phone_verification_screen.dart`: 6-digit OTP entry, verification via `signInWithPhoneCredential`, error container / SnackBar, resend action.
- `test/widget_test.dart`: Clean smoke test verifying app startup.
- `test/screens/phone_verification_flow_test.dart`: Fast headless widget-level flow tests (valid flow, invalid OTP error display, SMS failure error display).
- `integration_test/phone_auth_flow_test.dart`: Official Flutter integration test exercising the full phone auth UI transitions and simulated failure error surfacing.
