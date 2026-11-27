// Ensure Firebase Admin SDK is initialized once at entrypoint load.
import './firebase';

export { completeArtistOnboarding } from './onboarding';
export {
  createPaymentIntent,
  releaseCheckoutLock,
  stripeConnectWebhook,
  createStripeConnectAccountLink,
  syncStripeConnectStatus,
  createStripeExpressLoginLink,
  stripeConnectRedirect,
} from './payments';
export {
  setArtistRoleClaim,
  requestRecoveryOtp,
  verifyRecoveryOtp,
} from './auth';
export {
  dispatchPushNotification,
  onChatMessageCreated,
  onArtistFlashDrop,
} from './notifications';
export { dispatchAppointmentReminders } from './reminders';
export {
  syncArtistBookedSlotsOnAppointment,
  syncArtistBookedSlotsOnBooking,
} from './schedule';
export { bookFreeTouchUp } from './touchups';
