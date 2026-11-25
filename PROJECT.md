# Project: Flash.Ink Master Technical Specification

> **Last Updated:** November 23, 2026
> **Companion Business & Product Roadmap:** [Flash v2 - Master Business Plan & Product Roadmap](https://docs.google.com/document/d/1mozr0hyHyaml05oyF4Vh4AYOT0n4pjUiAVhSvq_UBag/edit)

---

## Architecture Overview

- **Platform:** Native cross-platform Flutter (Dart) mobile application targeting iOS (15.0+) and Android. Web-only Artist Dashboard is planned; client marketplace remains mobile-only.
- **State Management:** Hybrid **Riverpod** (`lib/providers/app_providers.dart` for auth/session epochs, live user profile, GPS coordinates, and account recovery) paired with local `StatefulWidget` state and imperative `Navigator` routing.
- **Design System:** Concentric adaptive-glass theme system centralized in `lib/theme/` (`app_theme.dart`, `app_typography.dart`, `app_spacing.dart`, `app_radius.dart`, `app_buttons.dart`) with reusable components in `lib/widgets/`.
- **Authentication & Dual-Role Accounts:** `FirebaseAuth` wrapped by `AuthService` (`lib/services/auth_service.dart`) and modular helpers (`lib/services/auth/`). Supports Phone-first sign-in, Email, Google, Apple, and Guest browsing, dual-role persona switching (`isArtist`, `activeMode`), unique username registry (`usernames/{handleId}`), backup email/phone verification, account deletion, and server-issued 6-digit recovery OTPs (`AccountRecoveryHubScreen`).
- **Data Persistence & Security:** Cloud Firestore with strict access isolation in `firebase/firestore.rules` and `storage.rules`:
  - `users/{userId}`, `usernames/{handleId}`, `artists/{artistId}` (+ `artists/{artistId}/private/{docId}` for PII)
  - `artist_schedules/{artistId}` (working hours, cleanup buffers, dead-gap rules, `blockedDates`, 24h `heldSlots`, anonymized `bookedSlots`)
  - `checkout_locks/{lockId}` (server-managed atomic 10-minute slot & flash locks)
  - `bookings/{bookingId}` (+ `private_location/{docId}`), `appointments/{appointmentId}`, `custom_requests/{requestId}`
  - `chats/{threadId}` (+ `messages/{messageId}`), `notifications/{notificationId}`
  - `core_config/payments` (dynamic fee settings), `support_escalations/{ticketId}`, `auth_recovery_otps/{docId}`
- **Interval Scheduling Engine:** Shared half-open `[start, end)` interval overlap math implemented in both Flutter (`lib/services/scheduling/slot_availability_engine.dart`) and Cloud Functions (`functions/src/scheduling/intervalUtils.ts`), supporting duration + cleanup buffers (60-minute default) and **smart dead-gap protection** (`preventDeadGaps`, `minBookableSessionMinutes`).
- **Payments & Escrow:** Stripe PaymentSheet client integration (`lib/services/stripe_service.dart`) backed by server-authoritative Cloud Functions (`functions/src/payments.ts`): 10-minute atomic checkout locks (`checkout_locks`, `releaseCheckoutLock`), dynamic fee config (`core_config/payments`, Phase A default 0%), first-2-bookings fee waiver (`free_bookings_remaining`), and Stripe Separate Charges & Transfers escrow holding (`transfer_group`, `escrowStatus: 'held'`).
- **Maps, Media & Notifications:** Google Maps + Google Places studio discovery (`StudioMapScreen`, `GooglePlacesService`, `TattooPlaceClassifier`), Cloud Storage uploads with cropping, FCM + local notifications (`24h`/`2h` scheduled reminders, chat alerts, Book Drops), and native device calendar export (`add_2_calendar`).
- **Testing & Mock Quarantine:** 97 automated unit, widget, and integration test files (`test/` + `integration_test/`), constructor dependency injection (`AuthService`, `FirebaseFirestore`), and quarantined fixtures (`USE_MOCK_DATA` in `lib/core/mock/`).

---

## Current Feature Status

| Domain | Status | Implemented Capabilities | Next Deliverable |
| --- | --- | --- | --- |
| **Auth, Personas & Recovery** | Implemented | Phone-first auth, Email/Google/Apple/Guest, dual-role switching, username uniqueness, backup contacts, Account Recovery Hub + server OTPs, account deletion | Stripe KYC & artist credential vetting |
| **Discovery, Maps & Bookmarks** | Implemented | Style-based feeds, Spotlight/Trending carousels, Google Maps & Places studio explorer, saved bookmarks, artist flash collections | Featured local editorial feeds (backlog) |
| **Interval Scheduling & Books** | Implemented (Mobile) | `SlotAvailabilityEngine` + `intervalUtils` half-open overlap math, 60-min default cleanup buffers, smart dead-gap protection (`preventDeadGaps`, `minBookableSessionMinutes`), weekly caps, 24h artist holds, blocked dates, Book Drops, VIP waitlist, calendar export | Web-only Artist Dashboard |
| **Flash Booking & Checkout Locks** | Implemented | Step-based `FlashBookingScreen`, atomic 10-minute server checkout locks (`checkout_locks` + `releaseCheckoutLock`), server-authoritative pricing, anonymized `bookedSlots` sync triggers | High-demand drop countdown UX polish |
| **Custom Requests & Chat Proposals** | Implemented | Custom tattoo request flow with reference photos, deposit-gated chat threads, rich attachments (images/PDFs/docs), VIP invites, and **interactive 1–3 option booking proposal cards** (`ProposalOptionsMessageTile`) with live cloud/local conflict re-validation | Multi-session project proposals (backlog) |
| **Artist Studio Policies** | Implemented | Post-onboarding `ArtistManagePoliciesScreen` (create, edit, toggle, delete categorized deposit/cancellation/refund/health/etiquette rules) persisted to `/artists/{uid}` and rendered via `StudioPoliciesCard` | Policy acknowledgment logs on checkout |
| **Payments & Escrow** | Partial | Stripe PaymentSheet, `createPaymentIntent`, `releaseCheckoutLock`, `stripeConnectWebhook`, `core_config/payments` fee config, `free_bookings_remaining` (first 2 fee-free bookings), Separate Charges & Transfers escrow holding (`transfer_group` / `escrowStatus: 'held'`) | Mutual QR / in-person check-in payout release, Studio Hustle volume milestones, artist subscriptions |
| **Cloud Functions & Ops** | Partial | 13 modular Cloud Functions split into domain modules under `functions/src/` | Automated daily GCP Firestore backup exports, escrow release callable, `flashapp://` deep links |

---

## Firebase Cloud Functions (`functions/src/`)

13 exported Cloud Functions organized by domain (refactored from monolithic `index.ts`):

| Module | Exported Functions | Responsibility |
| --- | --- | --- |
| `onboarding.ts` | `completeArtistOnboarding` | Finalizes artist onboarding state and role provisioning |
| `payments.ts` | `createPaymentIntent`, `releaseCheckoutLock`, `stripeConnectWebhook` | Server-authoritative deposit pricing, dynamic fees (`core_config/payments`), `free_bookings_remaining` counter, atomic 10-min `checkout_locks`, Separate Charges escrow (`transfer_group`), webhook confirmation (`escrowStatus: 'held'`, flash claim, chat unlock) |
| `auth.ts` | `setArtistRoleClaim`, `requestRecoveryOtp`, `verifyRecoveryOtp` | Custom role claims and server-issued 6-digit account recovery OTPs |
| `notifications.ts` | `dispatchPushNotification`, `onChatMessageCreated`, `onArtistFlashDrop` | FCM push dispatch, chat message notifications, and Book Drop alerts to followers/waitlist |
| `reminders.ts` | `dispatchAppointmentReminders` | Scheduled 24h and 2h appointment reminder notifications |
| `schedule.ts` | `syncArtistBookedSlotsOnAppointment`, `syncArtistBookedSlotsOnBooking` | Keeps anonymized `bookedSlots` intervals synced on `artist_schedules/{artistId}` and enforces `assertSlotIsAvailable` |
| `scheduling/intervalUtils.ts` | *(shared server helpers)* | Half-open `[start, end)` interval overlap math, duration/buffer parsing, conflict validation |

---

## Code Layout

### Flutter Application (`lib/`)

- `lib/main.dart`, `lib/config/dev_config.dart`, `lib/providers/app_providers.dart`: App entrypoint, environment setup, and Riverpod session/profile/location providers.
- `lib/theme/`: Design tokens (`app_theme.dart`, `app_typography.dart`, `app_spacing.dart`, `app_radius.dart`, `app_buttons.dart`).
- `lib/core/`: Mock-data quarantine (`mock/mock_data_config.dart`, `mock_fixtures.dart`, `artist_dashboard_fixtures.dart`), shared navigation bar, and utility launchers (maps directions, native calendar export, distance calculator).
- `lib/features/`: Feature-sliced modules:
  - `appointments/`: Client appointments list, cards, and detail modals.
  - `artist/`: Public `ArtistProfileScreen`, flash piece cards, `StudioPoliciesCard`, stats, and custom request banner.
  - `auth/`: `AccountRecoveryHubScreen`, lockout, support escalation, recovery service, and troubleshooting sheets.
  - `explore/`: Discovery feed, trending studios/artists, spotlight carousel, and saved bookmarks.
  - `messages/`: `MessagesScreen`, `ChatConversationScreen`, `ProposalOptionsMessageTile`, `BookingReceiptMessageTile`, and `VipWaitlistInvitationCard`.
  - `onboarding/`: Client notification opt-in and shared onboarding scaffold.
  - `studios/`: `StudioMapScreen`, `StudioProfileScreen`, and `StudioPlaceDetailsSheet`.
- `lib/models/`: Domain models (`user.dart`, `artist.dart`, `booking.dart`, `booking_notification.dart`, `google_place_models.dart`, `studio_information.dart`, `waitlist_entry.dart`) and `artist_dashboard/` models (`artist_books_schedule.dart`, `schedule_slot_entry.dart`, `book_drop.dart`, `booking_request.dart`, `dashboard_appointment.dart`, `auto_response_preset.dart`).
- `lib/repositories/`: `artist_repository.dart`, `user_repository.dart`, `artist_dashboard_repository.dart`, and `artist_availability_calculator.dart`.
- `lib/services/`:
  - `auth_service.dart` + `auth/` (`auth_account_lifecycle.dart`, `auth_exceptions.dart`, `auth_formatters.dart`, `auth_reauthentication_helper.dart`, `dev_mock_user.dart`)
  - `booking_sync_service.dart` + `booking/` (`booking_cloud_hydrator.dart`, `chat_cloud_sync.dart`, `schedule_cloud_sync.dart`)
  - `scheduling/` (`slot_availability_engine.dart`, `booking_slot_profile.dart`)
  - `stripe_service.dart`, `chat_service.dart`, `notification_service.dart`, `username_service.dart`, `location_service.dart`, `studio_map_service.dart`, `google_places_service.dart` + `places/tattoo_place_classifier.dart`
- `lib/screens/`:
  - `booking/`: `FlashBookingScreen` modularized into step widgets (`booking_progress_stepper.dart`, `booking_step_details.dart`, `booking_step_schedule.dart`, `booking_step_payment.dart`, `booking_step_confirmation.dart`, `placement_selection_bottom_sheet.dart`).
  - `artist_dashboard/`: Dashboard, Books (`artist_books_screen.dart`), modular Calendar (`calendar/artist_calendar_card.dart`, `calendar_schedule_section.dart`, `manage_time_off_sheet.dart`), `ArtistManagePoliciesScreen`, `BookingRequestDetailScreen`, Waitlist, Collections, Book Drops, Earnings, and Account Settings.
  - `artist_onboarding/`: Multi-step artist onboarding flow (info, phone verification, photo, bio, style, identity tags, flash upload, pricing, policies, share link).
  - Auth & Client screens (`splash_screen.dart`, `account_creation_screen.dart`, `phone_verification_screen.dart`, `email_auth_screen.dart`, `profile_setup_screen.dart`, `main_feed_screen.dart`, `browse_artists_screen.dart`, `custom_request_screen.dart`, `flash_details_screen.dart`, etc.).
- `lib/widgets/`: Shared glass containers, snack bars, inline email/phone verification tiles (`inline_verification_shared.dart`), photo cropper, nav bar scaffold, and form formatters.

### Backend, Rules & Tests

- `functions/src/`: TypeScript Cloud Functions v2 modules (`index.ts`, `firebase.ts`, `auth.ts`, `onboarding.ts`, `payments.ts`, `schedule.ts`, `scheduling/intervalUtils.ts`, `notifications.ts`, `reminders.ts`).
- `firebase/firestore.rules` & `storage.rules`: Database and Cloud Storage security rules.
- `test/` & `integration_test/`: 97 test files covering interval scheduling & dead-gap protection (`test/services/scheduling/slot_availability_engine_test.dart`), Stripe payment flows (`test/services/stripe_service_test.dart`), custom request proposals, studio policies, flash booking flows, chat attachments, UI/auth adversarial stress suites, and E2E phone auth integration tests.

---

## Historical Milestones Summary

| # | Milestone Name | Scope | Status |
| --- | --- | --- | :--: |
| M1 | Phone Auth Migration & UI Error Surfacing | Replaced MFA with primary Phone Sign-In; eliminated mock IDs; surfaced UI errors | **DONE** |
| M2 | Phone Auth Integration Test Suite | Added Flutter `integration_test`, headless and on-device test harnesses | **DONE** |
| M3 | Auth Hardening & Audit | Full test pass rate, adversarial verification, zero integrity violations | **DONE** |
| M4 | iOS 15.0 Target & CocoaPods Fix | Updated deployment target across pbxproj, Podfile, and xcconfigs | **DONE** |
| M5 | Onboarding Skip Resilience & Account Deletion | Resilient skip photo routing; Delete Account modal and auth deletion | **DONE** |
| M6 | Automated Flow & Adversarial Stress Testing | Onboarding/deletion widget tests plus UI & auth concurrency stress suites | **DONE** |
| M7 | Discovery, Maps, Artist CRM & Messaging | Dual-role switching, Google Maps/Places studio explorer, Book Drops, VIP waitlist, custom requests, deposit-gated chat, Account Recovery Hub, FCM notifications & reminders | **DONE** |
| M8 | Codebase Modularization & Domain Refactor | Split Cloud Functions `index.ts` into domain modules; modularized `FlashBookingScreen`, `ArtistCalendarScreen`, `AuthService`, `BookingSyncService`, `ArtistDashboardRepository`, Places, and verification widgets | **DONE** |
| M9 | Escrow Payments, In-Chat Proposals, Policies & Interval Scheduling | 10-min atomic `checkout_locks`, `releaseCheckoutLock`, `free_bookings_remaining`, Separate Charges escrow holding, interactive 1–3 slot chat proposals, `ArtistManagePoliciesScreen`, and interval scheduling engine with dead-gap protection | **DONE** |
| M10 | Escrow Release, Backups & Web Artist Dashboard | Mutual QR/in-person check-in payout release, automated daily Firestore backups, `flashapp://` deep links, and web-only Artist Dashboard | **NEXT** |
