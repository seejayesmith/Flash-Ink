# Project: Flash.Ink Master Architectural Specification

## Architecture Overview
- **State Management**: Pure Flutter local state management (`StatefulWidget`, `setState`) with imperative `Navigator` routing.
- **Authentication**: `FirebaseAuth.instance` encapsulated in `AuthService` (`lib/services/auth_service.dart`). Standard primary phone authentication, user deletion via `deleteAccount()`, and human-readable exception mapping (`requires-recent-login`, `invalid-phone-number`, `invalid-verification-code`, etc.).
- **Data Persistence**: `FirebaseFirestore.instance` storing user documents under `users/{uid}`.
- **Dependency Injection**: UI screens (`AccountCreationScreen`, `PhoneVerificationScreen`, `MainFeedScreen`, `BrowseArtistsScreen`) accept optional `AuthService? authService` parameters in constructors (defaulting to `AuthService()`), enabling fast headless testing via `FakeAuthService` and test harnesses.
- **Integration & Unit Testing**: Combines Flutter's official `integration_test` package (`package:integration_test/integration_test.dart`) for on-device/desktop E2E runs with comprehensive widget and unit tests.

---

## Consolidated Feature Inventory

| # | Feature | Description | Milestone | Source / Status |
|---|---------|-------------|-----------|-----------------|
| 1 | Standard Phone Sign-In in AuthService | Replace MFA enrollment with standard `verifyPhoneNumber` and `signInWithPhoneCredential` creating primary user | M1 | Completed |
| 2 | Phone Auth Exception Mapping | Map Firebase phone error codes (`invalid-phone-number`, `invalid-verification-code`, `session-expired`, etc.) | M1 | Completed |
| 3 | AuthService Dependency Injection | Allow constructor injection of `AuthService` in `AccountCreationScreen` and `PhoneVerificationScreen` | M1 | Completed |
| 4 | Remove Silent Anonymous Login & Fake IDs | Remove `signInAnonymously()`, fake `vid_${timestamp}`, and swallowed exceptions | M1 | Completed |
| 5 | Surface SMS Dispatch Errors in UI | Visibly display SMS dispatch failure in `AccountCreationScreen`, abort navigation, and keep modal open | M1 | Completed |
| 6 | Remove Silent Verification Fallback | Remove empty `catch (_)` in `PhoneVerificationScreen._verifyCode()`, prevent premature Firestore writes | M1 | Completed |
| 7 | Surface OTP Verification Errors in UI | Visibly display invalid OTP verification code error in `PhoneVerificationScreen`, clear code, abort navigation | M1 | Completed |
| 8 | Real Resend SMS Flow | Replace dummy green SnackBar in `PhoneVerificationScreen` with actual SMS re-request and token passing | M1 | Completed |
| 9 | Baseline Test Suite Fix | Fix stale `test/widget_test.dart` counter test to assert `SplashScreen` so baseline passes | M1 | Completed |
| 10 | Integration Test Infra Setup | Add `integration_test: sdk: flutter` to `pubspec.yaml`, setup test harness and `FakeAuthService` | M2 | Completed |
| 11 | Integration Test: Valid Flow | Verify complete UI flow: phone entry -> SMS code entry -> transition to `ProfileSetupScreen` | M2 | Completed |
| 12 | Integration Test: Simulated Failure | Verify UI error surfacing when SMS sending fails or invalid verification code is entered | M2 | Completed |
| 13 | Final E2E Suite & Hardening | Full integration & unit tests, adversarial coverage verification, zero integrity violations | M3 | Completed |
| 14 | iOS 15.0 Deployment Target Update | Explicitly set `IPHONEOS_DEPLOYMENT_TARGET` to 15.0 across all build configurations in `project.pbxproj` and xcconfigs | M4 | Completed |
| 15 | CocoaPods Platform Resolution | Set `platform :ios, '15.0'` and `post_install` hook in `Podfile` to permanently resolve Firebase version constraints | M4 | Completed |
| 16 | Onboarding Skip Photo Resilience | Wrap Firestore write in `ProfileSetupScreen._saveProfile()` with inner try-catch, guaranteeing Skip navigation to aesthetics | M5 | Completed |
| 17 | AuthService Account Deletion | Add `deleteAccount()` invoking `_auth.currentUser?.delete()` and handle `requires-recent-login` in `AuthService` | M5 | Completed |
| 18 | MainFeedScreen DI Support | Add optional `AuthService? authService` constructor parameter in `MainFeedScreen` and forward to `BrowseArtistsScreen` | M5 | Completed |
| 19 | Feed Delete Account Footer | Render styled "Delete Account" button with key `delete_account_button` at bottom of `BrowseArtistsScreen` with nav bar clearance | M5 | Completed |
| 20 | Centered Confirmation Modal | Centered dark `AlertDialog` modal with Cancel and Delete Account buttons, modal barrier dismissal safety | M5 | Completed |
| 21 | Deletion Feedback & Root Reset | On confirmation, invoke `deleteAccount()`, display simulated email SnackBar, and reset stack to `SplashScreen` via `pushAndRemoveUntil` | M5 | Completed |
| 22 | Deletion Error Surfacing | Surface `requires-recent-login` and generic deletion exceptions in red SnackBar while retaining user safely on feed | M5 | Completed |
| 23 | Client Onboarding & Deletion Tests | Author `test/screens/client_onboarding_and_deletion_test.dart` covering 7 baseline and error scenarios | M6 | Completed |
| 24 | Adversarial UI & Auth Stress Suites | Implement `test/challenger_ui_stress_test.dart` (10 tests) and `test/challenger_auth_stress_test.dart` (8 tests) | M6 | Completed |

---

## Milestones Summary

| # | Milestone Name | Scope | Status |
|---|----------------|-------|:------:|
| M1 | Phone Auth Migration & UI Error Surfacing | Replaced MFA with primary Phone Sign-In; eliminated mock IDs; surfaced UI errors | **DONE** |
| M2 | Phone Auth Integration Test Suite | Added Flutter `integration_test`, created headless and on-device test harnesses | **DONE** |
| M3 | Auth Hardening & Forensic Victory Audit | 100% test pass rate, adversarial test verification, zero integrity violations | **DONE** |
| M4 | iOS 15.0 Target & CocoaPods Fix | Updated deployment target across pbxproj, Podfile, and xcconfigs to resolve Firebase SDK | **DONE** |
| M5 | Onboarding Skip Resilience & Account Deletion | Resilient skip photo routing; feed Delete Account button with centered confirmation modal and auth deletion | **DONE** |
| M6 | Automated Flow & Adversarial Stress Testing | Comprehensive widget tests, UI stress suite, auth & concurrency stress suite (25 tests green) | **DONE** |

---

## Core Interface Contracts

### 1. `BaseAuthService` & `AuthService`
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

  Future<void> deleteAccount();
}
```

### 2. `AccountCreationScreen` Constructor
```dart
const AccountCreationScreen({
  super.key,
  this.role = 'client',
  AuthService? authService,
});
```

### 3. `PhoneVerificationScreen` Constructor
```dart
const PhoneVerificationScreen({
  super.key,
  required this.phoneNumber,
  required this.verificationId,
  this.resendToken,
  AuthService? authService,
});
```

### 4. `MainFeedScreen` Constructor
```dart
const MainFeedScreen({
  super.key,
  this.authService,
});
final AuthService? authService;
```

### 5. `BrowseArtistsScreen` Constructor
```dart
const BrowseArtistsScreen({
  super.key,
  this.authService,
});
final AuthService? authService;
```

---

## Code Layout
- `lib/services/auth_service.dart`: Main Firebase Auth service with standard phone auth, account deletion, and exception mapping.
- `lib/screens/account_creation_screen.dart`: Phone number entry bottom sheet, phone validation, SMS dispatch, inline error alert.
- `lib/screens/phone_verification_screen.dart`: 6-digit OTP entry, verification via `signInWithPhoneCredential`, error container / SnackBar, resend action.
- `lib/screens/profile_setup_screen.dart`: Profile creation with resilient skip photo routing to `AestheticsSelectionScreen`.
- `lib/screens/main_feed_screen.dart`: Main feed container accepting `AuthService` dependency injection.
- `lib/screens/browse_artists_screen.dart`: Artist browsing with footer "Delete Account" button and centered confirmation modal.
- `test/widget_test.dart`: Baseline startup smoke test.
- `test/screens/client_onboarding_and_deletion_test.dart`: Onboarding skip photo and account deletion widget tests.
- `test/challenger_ui_stress_test.dart`: 10 adversarial UI stress tests (multi-tapping, barrier dismissal, viewport constraints).
- `test/challenger_auth_stress_test.dart`: 8 adversarial auth stress tests (null-user, `requires-recent-login`, concurrency races).
- `integration_test/phone_auth_flow_test.dart`: Flutter integration test verifying full phone auth UI transitions.
