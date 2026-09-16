# Original User Request

## Initial Request — 2026-09-05T21:00:07Z

# Teamwork Project Prompt — Draft

> Status: Ready for launch — awaiting user approval
> Goal: Craft prompt → get user approval → delegate to teamwork_preview
> Requested team: Full multi-agent team

Refactor the phone verification authentication flow in the Flash Ink app to use standard Firebase Phone Sign-In rather than MFA. Use a full team of agents.

Working directory: /Users/csolis/Projects/Flash.Ink
Integrity mode: development

## Requirements

### R1. Migrate to Standard Phone Sign-In
Replace the current MFA-based phone verification in the application with standard Firebase Phone Sign-In. The phone number should act as the primary account.

### R2. Surface Authentication Errors
Implement robust error handling for the phone authentication flow. If SMS sending fails or the verification code is invalid, the error must be visibly surfaced to the user in the UI instead of silently falling back to a mock/dummy state.

## Acceptance Criteria

### Integration Testing
- [ ] A Flutter integration test is written to verify the Phone Authentication UI flow.
- [ ] The integration test successfully runs and passes, demonstrating that the UI transitions correctly when a valid flow occurs and displays an error message when a simulated failure occurs.

## Follow-up — 2026-09-10T23:05:35Z

# Teamwork Project Prompt — Draft

> Status: Launched
> Goal: Task successfully delegated to teamwork_preview
> Requested team: Small focused team

This is a single self-contained fix; keep it small and focused. Update the iOS project configuration in the Flutter app to set the minimum iOS deployment target to 15.0, permanently resolving the Firebase package version mismatch errors (cloud-firestore, firebase-auth, etc.) that currently require iOS 15.0 while the target supports 13.0.

Working directory: /Users/csolis/Projects/Flash.Ink
Integrity mode: demo

## Requirements

### R1. iOS Target Update
The project's iOS deployment target must be raised to 15.0 to satisfy the latest Firebase SDK constraints.

## Acceptance Criteria

### iOS Configuration
- [ ] The `IPHONEOS_DEPLOYMENT_TARGET` in `ios/Runner.xcodeproj/project.pbxproj` is explicitly set to `15.0` (or higher) for all build configurations (Debug, Release, Profile).
- [ ] The iOS version in `ios/Podfile` (typically `platform :ios`) is explicitly set to `15.0` (or higher).

### Build Verification
- [ ] A test build via `flutter build ios --simulator --no-codesign` succeeds without raising the minimum platform version errors for Firebase packages.

## Follow-up — 2026-09-15T04:25:11Z

Update the onboarding flow to ensure the "SKIP" button on the photo step routes correctly to the styles selection, and add a "Delete Account" button to the bottom of the mock feed with a confirmation modal. Write automated tests to verify these flows.

Working directory: /Users/csolis/Projects/Flash.Ink
Integrity mode: development

## Requirements

### R1. Ensure 'Skip Photo' Routing
Verify and ensure that the existing "SKIP" button on the 'add photo' step in the `ProfileSetupScreen` successfully bypasses the photo upload and routes the user to the 'select styles' page (`AestheticsSelectionScreen`), and subsequently to the mock feed.

### R2. Account Deletion Feature in Feed
Add a "Delete Account" button at the bottom of the mock feed (`MainFeedScreen`). When tapped, it should display a centered confirmation modal. If confirmed, the user's account should be deleted locally from Firebase Auth, a success message should be shown (simulating the email they will receive later), and the user should be routed back to the initial splash/startup screen.

### R3. Automated Testing
Write or update a Flutter widget/integration test to programmatically verify that tapping the "SKIP" button routes to the `AestheticsSelectionScreen`, and that the "Delete Account" modal appears and functions in the `MainFeedScreen`.

## Acceptance Criteria

### Onboarding Flow
- [ ] Tapping "SKIP" on the photo upload step routes the user to the aesthetics selection screen without requiring a photo.
- [ ] Completing the aesthetics selection routes the user to the main feed.

### Account Deletion
- [ ] The `MainFeedScreen` contains a visible "Delete Account" button at the bottom.
- [ ] Tapping "Delete Account" opens a centered confirmation modal.
- [ ] Confirming the deletion calls `FirebaseAuth.instance.currentUser?.delete()`, displays a success snackbar or dialog, and navigates back to the root of the app.

### Testing Verification
- [ ] `flutter test` executes and passes a test verifying the skip photo routing.
- [ ] `flutter test` executes and passes a test verifying the delete account modal and functionality.

