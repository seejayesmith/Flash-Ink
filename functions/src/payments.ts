import { defineSecret } from 'firebase-functions/params';
import { onCall, HttpsError, onRequest } from 'firebase-functions/v2/https';
import Stripe from 'stripe';
import { admin, db } from './firebase';
import {
  assertSlotIsAvailable,
  buildFlashLockId,
  buildSlotLockId,
  CHECKOUT_LOCK_TTL_MS,
  CHECKOUT_LOCKS_COLLECTION,
  extractDateKey,
  normalizeSlotLabel,
} from './schedule';
import {
  assertIntervalIsAvailable,
  DEFAULT_FALLBACK_BUFFER_MINUTES,
  DEFAULT_FALLBACK_DURATION_MINUTES,
  parseDurationStringMinutes,
  parseTimeLabelToMinutes,
  throwTimeSlotConflict,
} from './scheduling/intervalUtils';
import {
  formatDurationLabel,
  validateTouchUpEligibility,
} from './touchups';

const stripeSecretKey = defineSecret('STRIPE_SECRET_KEY');
const stripeWebhookSecret = defineSecret('STRIPE_WEBHOOK_SECRET');

const DEFAULT_FREE_BOOKINGS_ALLOWANCE = 2;

export const getStripeClient = (): Stripe => {
  const secretKey = stripeSecretKey.value() || process.env.STRIPE_SECRET_KEY || '';
  if (!secretKey) {
    throw new HttpsError(
      'failed-precondition',
      'Stripe payment processing is not configured on the server.'
    );
  }
  return new Stripe(secretKey, {
    apiVersion: '2025-02-24.acacia',
  });
};

interface PaymentConfig {
  platformFeePercent: number;
  platformFeeFlatCents: number;
  requireArtistStripeConnect: boolean;
  defaultFreeBookingsAllowance: number;
}

async function loadPaymentConfig(): Promise<PaymentConfig> {
  const configSnap = await db.collection('core_config').doc('payments').get();
  const data = (configSnap.exists ? configSnap.data() : {}) as Record<string, unknown>;

  const feePercent =
    typeof data.platformFeePercent === 'number' && data.platformFeePercent >= 0
      ? data.platformFeePercent
      : 0; // Phase A launch default: 0% platform fee; adjust in core_config/payments for Phase B.
  const feeFlatCents =
    typeof data.platformFeeFlatCents === 'number' && data.platformFeeFlatCents >= 0
      ? Math.round(data.platformFeeFlatCents)
      : 0;
  const requireArtistStripeConnect = data.requireArtistStripeConnect !== false;
  const defaultFreeBookingsAllowance =
    typeof data.defaultFreeBookingsAllowance === 'number' &&
    data.defaultFreeBookingsAllowance >= 0
      ? Math.floor(data.defaultFreeBookingsAllowance)
      : DEFAULT_FREE_BOOKINGS_ALLOWANCE;

  return {
    platformFeePercent: feePercent,
    platformFeeFlatCents: feeFlatCents,
    requireArtistStripeConnect,
    defaultFreeBookingsAllowance,
  };
}

function readTimestampMillis(raw: unknown): number {
  if (raw instanceof admin.firestore.Timestamp) {
    return raw.toMillis();
  }
  if (typeof raw === 'string') {
    const parsed = Date.parse(raw);
    return Number.isNaN(parsed) ? 0 : parsed;
  }
  return 0;
}

function sanitizeBookingId(raw: unknown): string {
  const cleaned = typeof raw === 'string' ? raw.trim() : '';
  if (/^[A-Za-z0-9_-]{4,64}$/.test(cleaned)) {
    return cleaned;
  }
  return `INK-${Date.now()}`;
}

function isFlashExclusive(flashRecord: Record<string, unknown>): boolean {
  if (flashRecord.isExclusive === false) return false;
  const status = String(flashRecord.status || 'available').trim().toLowerCase();
  return status !== 'repeatable';
}

function isFlashClaimed(flashRecord: Record<string, unknown>): boolean {
  if (flashRecord.isClaimed === true) return true;
  const status = String(flashRecord.status || 'available').trim().toLowerCase();
  return status === 'claimed';
}

async function cleanupCheckoutLocks(params: {
  slotLockId?: string;
  flashLockId?: string;
  bookingId?: string;
  markStatus?: 'payment_failed' | 'canceled';
}): Promise<void> {
  const { slotLockId, flashLockId, bookingId, markStatus } = params;
    const batch = db.batch();
  if (slotLockId) {
    batch.delete(db.collection(CHECKOUT_LOCKS_COLLECTION).doc(slotLockId));
  }
  if (flashLockId) {
    batch.delete(db.collection(CHECKOUT_LOCKS_COLLECTION).doc(flashLockId));
  }
  if (bookingId && markStatus) {
    batch.set(
      db.collection('bookings').doc(bookingId),
      {
        status: markStatus,
        escrowStatus: 'canceled',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  }
  await batch.commit();
}

interface PersistedStripeStatus {
  hasAccount: boolean;
  stripeAccountId: string;
  stripePayoutsReady: boolean;
  payoutsEnabled: boolean;
  chargesEnabled: boolean;
  detailsSubmitted: boolean;
  currentlyDue: string[];
  externalAccountLabel: string;
}

function resolveStripeConnectRedirectBaseUrl(overrideOrigin?: string): string {
  const configured = (process.env.STRIPE_CONNECT_REDIRECT_URL || '').trim();
  if (configured.startsWith('https://') || configured.startsWith('http://localhost')) {
    return configured.replace(/\/+$/, '');
  }
  const cleanOrigin = (overrideOrigin || '').trim();
  if (cleanOrigin.startsWith('https://') || cleanOrigin.startsWith('http://localhost')) {
    return `${cleanOrigin.replace(/\/+$/, '')}/stripeConnectRedirect`;
  }
  const projectId =
    process.env.GCLOUD_PROJECT ||
    process.env.GCP_PROJECT ||
    admin.app().options.projectId ||
    'flash-ink';
  const region = process.env.FUNCTION_REGION || 'us-central1';
  if (process.env.FUNCTIONS_EMULATOR === 'true') {
    return `http://127.0.0.1:5001/${projectId}/${region}/stripeConnectRedirect`;
  }
  return `https://${region}-${projectId}.cloudfunctions.net/stripeConnectRedirect`;
}

async function persistStripeAccountState(
  uid: string,
  account: Stripe.Account
): Promise<PersistedStripeStatus> {
  const isReady =
    account.details_submitted === true &&
    account.charges_enabled === true &&
    account.payouts_enabled === true;

  let externalAccountLabel = '';
  let externalAccountLast4 = '';
  let externalAccountType = '';
  const externalAccounts = account.external_accounts?.data || [];
  if (externalAccounts.length > 0) {
    const primary = externalAccounts[0];
    if (primary.object === 'bank_account') {
      externalAccountType = 'bank_account';
      externalAccountLast4 = primary.last4 || '';
      externalAccountLabel = `${primary.bank_name || 'Bank Account'} •••• ${primary.last4 || ''}`.trim();
    } else if (primary.object === 'card') {
      externalAccountType = 'card';
      externalAccountLast4 = primary.last4 || '';
      externalAccountLabel = `${primary.brand || 'Debit Card'} •••• ${primary.last4 || ''}`.trim();
    }
  }

  const currentlyDue = account.requirements?.currently_due || [];

  if (isReady) {
    await admin.auth().setCustomUserClaims(uid, {
      role: 'artist',
      isArtist: true,
      isClient: true,
      stripeAccountId: account.id,
      verifiedArtist: true,
    });
  }

  const batch = db.batch();
  batch.set(
    db.collection('artists').doc(uid).collection('private').doc('financials'),
    {
      stripeAccountId: account.id,
      payoutsEnabled: account.payouts_enabled === true,
      chargesEnabled: account.charges_enabled === true,
      detailsSubmitted: account.details_submitted === true,
      requirementsCurrentlyDue: currentlyDue,
      ...(externalAccountLabel
        ? {
            externalAccountLabel,
            externalAccountLast4,
            externalAccountType,
          }
        : {}),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
  batch.set(
    db.collection('artists').doc(uid),
    {
      stripePayoutsReady: isReady,
      ...(!isReady ? { isBooksOpen: false } : {}),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
  await batch.commit();

  return {
    hasAccount: true,
    stripeAccountId: account.id,
    stripePayoutsReady: isReady,
    payoutsEnabled: account.payouts_enabled === true,
    chargesEnabled: account.charges_enabled === true,
    detailsSubmitted: account.details_submitted === true,
    currentlyDue,
    externalAccountLabel,
  };
}

/**
 * Callable Cloud Function: Create or Resume Live Stripe Connect Express Onboarding Link
 *
 * Creates (or reuses) a Stripe Connect Express account tied to the authenticated artist's
 * Firebase UID, stores `stripeAccountId` in `artists/{uid}/private/financials`, and issues
 * a single-use hosted Stripe Account Link (`account_onboarding`).
 */
export const createStripeConnectAccountLink = onCall(
  { secrets: [stripeSecretKey] },
  async (request) => {
    if (!request.auth || !request.auth.uid) {
      throw new HttpsError(
        'unauthenticated',
        'Please sign in to connect your Stripe payout account.'
      );
    }
    if (request.auth.token?.firebase?.sign_in_provider === 'anonymous') {
      throw new HttpsError(
        'unauthenticated',
        'Please create an artist account before connecting Stripe.'
      );
    }

    const uid = request.auth.uid;
    const data = (request.data || {}) as {
      email?: string;
      artistName?: string;
      returnOrigin?: string;
    };

    const stripe = getStripeClient();
    const artistRef = db.collection('artists').doc(uid);
    const financialsRef = artistRef.collection('private').doc('financials');
    const settingsRef = artistRef.collection('private').doc('settings');

    const [artistSnap, financialsSnap, settingsSnap] = await Promise.all([
      artistRef.get(),
      financialsRef.get(),
      settingsRef.get(),
    ]);

    const artistData = (artistSnap.data() || {}) as Record<string, unknown>;
    const financialsData = (financialsSnap.data() || {}) as Record<string, unknown>;
    const settingsData = (settingsSnap.data() || {}) as Record<string, unknown>;

    const resolvedEmail = (
      (typeof data.email === 'string' ? data.email : '') ||
      (typeof settingsData.email === 'string' ? settingsData.email : '') ||
      request.auth.token.email ||
      ''
    ).trim();

    const resolvedName = (
      (typeof data.artistName === 'string' ? data.artistName : '') ||
      (typeof artistData.name === 'string' ? artistData.name : '') ||
      request.auth.token.name ||
      ''
    ).trim();

    let existingAccountId =
      typeof financialsData.stripeAccountId === 'string'
        ? financialsData.stripeAccountId.trim()
        : '';

    let account: Stripe.Account | null = null;
    if (existingAccountId.startsWith('acct_')) {
      try {
        const retrieved = await stripe.accounts.retrieve(existingAccountId, {
          expand: ['external_accounts'],
        });
        if (!('deleted' in retrieved && retrieved.deleted)) {
          account = retrieved as Stripe.Account;
        }
      } catch (_) {
        account = null;
      }
    }

    if (!account) {
      account = await stripe.accounts.create({
        type: 'express',
        country: 'US',
        ...(resolvedEmail ? { email: resolvedEmail } : {}),
        business_type: 'individual',
        capabilities: {
          card_payments: { requested: true },
          transfers: { requested: true },
        },
        business_profile: {
          ...(resolvedName ? { name: resolvedName } : {}),
          product_description:
            'Tattoo artistry deposits and appointments booked through Flash.Ink.',
        },
        metadata: {
          firebaseUid: uid,
        },
      });
      existingAccountId = account.id;
    } else if (account.metadata?.firebaseUid !== uid) {
      account = await stripe.accounts.update(account.id, {
        metadata: {
          ...(account.metadata || {}),
          firebaseUid: uid,
        },
      });
    }

    const persisted = await persistStripeAccountState(uid, account);
    const redirectBase = resolveStripeConnectRedirectBaseUrl(data.returnOrigin);

    const accountLink = await stripe.accountLinks.create({
      account: account.id,
      refresh_url: `${redirectBase}?state=refresh`,
      return_url: `${redirectBase}?state=return`,
      type: 'account_onboarding',
    });

    return {
      url: accountLink.url,
      expiresAt: accountLink.expires_at,
      ...persisted,
    };
  }
);

/**
 * Callable Cloud Function: Live Sync of Artist Stripe Connect Account Readiness
 *
 * Queries Stripe's live Accounts API directly when the artist returns from the
 * hosted Stripe onboarding flow (so UI doesn't have to wait on webhook latency),
 * persists `stripePayoutsReady` to Firestore, and returns full verification status.
 */
export const syncStripeConnectStatus = onCall(
  { secrets: [stripeSecretKey] },
  async (request) => {
    if (!request.auth || !request.auth.uid) {
      throw new HttpsError(
        'unauthenticated',
        'Please sign in to check your Stripe payout status.'
      );
    }

    const uid = request.auth.uid;
    const financialsSnap = await db
      .collection('artists')
      .doc(uid)
      .collection('private')
      .doc('financials')
      .get();

    const financialsData = (financialsSnap.data() || {}) as Record<string, unknown>;
    const stripeAccountId =
      typeof financialsData.stripeAccountId === 'string'
        ? financialsData.stripeAccountId.trim()
        : '';

    if (!stripeAccountId.startsWith('acct_')) {
      return {
        hasAccount: false,
        stripeAccountId: '',
        stripePayoutsReady: false,
        payoutsEnabled: false,
        chargesEnabled: false,
        detailsSubmitted: false,
        currentlyDue: [] as string[],
        externalAccountLabel: '',
      };
    }

    const stripe = getStripeClient();
    const retrieved = await stripe.accounts.retrieve(stripeAccountId, {
      expand: ['external_accounts'],
    });
    if ('deleted' in retrieved && retrieved.deleted) {
      await db.collection('artists').doc(uid).set(
        {
          stripePayoutsReady: false,
          isBooksOpen: false,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
      return {
        hasAccount: false,
        stripeAccountId: '',
        stripePayoutsReady: false,
        payoutsEnabled: false,
        chargesEnabled: false,
        detailsSubmitted: false,
        currentlyDue: [] as string[],
        externalAccountLabel: '',
      };
    }

    return persistStripeAccountState(uid, retrieved as Stripe.Account);
  }
);

/**
 * Callable Cloud Function: Create Live Stripe Express Dashboard Login Link
 *
 * Generates a single-use login link to the Stripe Express Dashboard for artists
 * who have submitted their details, or seamlessly falls back to an onboarding link
 * if setup is still incomplete.
 */
export const createStripeExpressLoginLink = onCall(
  { secrets: [stripeSecretKey] },
  async (request) => {
    if (!request.auth || !request.auth.uid) {
      throw new HttpsError(
        'unauthenticated',
        'Please sign in to access your Stripe Express dashboard.'
      );
    }

    const uid = request.auth.uid;
    const financialsSnap = await db
      .collection('artists')
      .doc(uid)
      .collection('private')
      .doc('financials')
      .get();

    const financialsData = (financialsSnap.data() || {}) as Record<string, unknown>;
    const stripeAccountId =
      typeof financialsData.stripeAccountId === 'string'
        ? financialsData.stripeAccountId.trim()
        : '';

    const stripe = getStripeClient();
    if (stripeAccountId.startsWith('acct_')) {
      const retrieved = await stripe.accounts.retrieve(stripeAccountId);
      if (!('deleted' in retrieved && retrieved.deleted)) {
        const account = retrieved as Stripe.Account;
        await persistStripeAccountState(uid, account);
        if (account.details_submitted) {
          const loginLink = await stripe.accounts.createLoginLink(stripeAccountId);
          return {
            url: loginLink.url,
            type: 'login_link',
            stripeAccountId,
          };
        }
        const redirectBase = resolveStripeConnectRedirectBaseUrl();
        const onboardingLink = await stripe.accountLinks.create({
          account: stripeAccountId,
          refresh_url: `${redirectBase}?state=refresh`,
          return_url: `${redirectBase}?state=return`,
          type: 'account_onboarding',
        });
        return {
          url: onboardingLink.url,
          type: 'account_onboarding',
          stripeAccountId,
        };
      }
    }

    throw new HttpsError(
      'failed-precondition',
      'No Stripe account is connected yet. Connect Stripe first to manage payouts.'
    );
  }
);

/**
 * Public HTTPS Endpoint: Stripe Connect Return / Refresh Deep-Link Bridge
 *
 * Stripe requires HTTPS `return_url` and `refresh_url` targets. When Stripe finishes
 * or requests a link refresh, this endpoint bounces the mobile browser straight back
 * into Flash.Ink via `flashapp://stripe-connect?status=return|refresh` with a branded
 * fallback button.
 */
export const stripeConnectRedirect = onRequest((req, res) => {
  const rawState = String(req.query.state || 'return').toLowerCase();
  const status = rawState === 'refresh' ? 'refresh' : 'return';
  const deepLink = `flashapp://stripe-connect?status=${status}`;
  const headline =
    status === 'refresh'
      ? 'Refreshing your Stripe session…'
      : 'Stripe setup saved!';
  const subtitle =
    status === 'refresh'
      ? 'Tap below to return to Flash.Ink and generate a fresh Stripe link.'
      : 'Returning you to Flash.Ink to verify your payout status.';

  res
    .status(200)
    .set('Content-Type', 'text/html; charset=utf-8')
    .set('Cache-Control', 'no-store')
    .send(`<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <meta http-equiv="refresh" content="0;url=${deepLink}" />
  <title>Flash.Ink • Stripe Connect</title>
  <style>
    body {
      margin: 0;
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
      background: #121414;
      color: #F9FAFA;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      padding: 24px;
      box-sizing: border-box;
    }
    .card {
      max-width: 380px;
      width: 100%;
      background: #1A1C1C;
      border: 1px solid #2E3232;
      border-radius: 20px;
      padding: 28px 24px;
      text-align: center;
    }
    h1 { font-size: 22px; margin: 0 0 10px; font-weight: 800; }
    p { font-size: 14px; line-height: 1.5; color: #919696; margin: 0 0 22px; }
    a.btn {
      display: inline-block;
      width: 100%;
      box-sizing: border-box;
      padding: 14px 20px;
      background: #EEC200;
      color: #121414;
      font-weight: 700;
      font-size: 15px;
      text-decoration: none;
      border-radius: 999px;
    }
    .hint { margin-top: 16px; font-size: 12px; color: #6B7272; }
  </style>
</head>
<body>
  <div class="card">
    <h1>${headline}</h1>
    <p>${subtitle}</p>
    <a class="btn" href="${deepLink}">Return to Flash.Ink</a>
    <p class="hint">Using the in-app browser? You can also tap <strong>Done</strong> in the corner.</p>
  </div>
  <script>
    window.location.replace(${JSON.stringify(deepLink)});
  </script>
</body>
</html>`);
});

/**
 * Callable Cloud Function: Create Stripe PaymentIntent for Flash Deposit
 *
 * Enforces server-authoritative pricing, artist Stripe Connect readiness,
 * first-2-bookings 0% platform fee allowance (`free_bookings_remaining`),
 * an atomic 10-minute checkout lock in Firestore, and Separate Charges & Transfers
 * escrow holding (`transfer_group`) until mutual in-person check-in.
 */
export const createPaymentIntent = onCall(
  { secrets: [stripeSecretKey] },
  async (request) => {
    if (!request.auth || !request.auth.uid) {
      throw new HttpsError(
        'unauthenticated',
        'Please sign in to pay a deposit and confirm your booking.'
      );
    }

    const signInProvider = request.auth.token?.firebase?.sign_in_provider;
    if (signInProvider === 'anonymous') {
      throw new HttpsError(
        'unauthenticated',
        'Please create or sign in to an account before booking.'
      );
    }

    const clientUid = request.auth.uid;
    const data = (request.data || {}) as {
      currency?: string;
      flashId?: string;
      flashTitle?: string;
      customRequestId?: string;
      parentAppointmentId?: string;
      healedPhotoUrl?: string;
      threadId?: string;
      customerEmail?: string;
      customerName?: string;
      customerPhone?: string;
      artistId?: string;
      bookingId?: string;
      selectedDate?: string;
      selectedTimeSlot?: string;
      startMinutes?: number;
      durationMinutes?: number;
      bufferMinutes?: number;
      holdId?: string;
      placement?: string;
      clientNotes?: string;
      isSilentAppointment?: boolean;
    };

    const targetArtistId = typeof data.artistId === 'string' ? data.artistId.trim() : '';
    if (!targetArtistId) {
      throw new HttpsError(
        'invalid-argument',
        'A valid artistId is required to create a booking deposit.'
      );
    }
    if (targetArtistId === clientUid) {
      throw new HttpsError(
        'failed-precondition',
        'Artists cannot book their own flash designs.'
      );
    }

    const dateKey = extractDateKey(data.selectedDate);
    const normalizedSlot = normalizeSlotLabel(data.selectedTimeSlot);
    const parsedStartMinutes =
      typeof data.startMinutes === 'number' && Number.isFinite(data.startMinutes)
        ? Math.floor(data.startMinutes)
        : parseTimeLabelToMinutes(normalizedSlot);
    if (!dateKey || !normalizedSlot || parsedStartMinutes === null) {
      throw new HttpsError(
        'invalid-argument',
        'A valid appointment date and time slot are required.'
      );
    }
    const cleanHoldId =
      typeof data.holdId === 'string' && data.holdId.trim().length > 0
        ? data.holdId.trim()
        : undefined;

    const bookingId = sanitizeBookingId(data.bookingId);
    const flashId = typeof data.flashId === 'string' ? data.flashId.trim() : '';
    const customRequestId =
      typeof data.customRequestId === 'string' ? data.customRequestId.trim() : '';
    const parentAppointmentId =
      typeof data.parentAppointmentId === 'string'
        ? data.parentAppointmentId.trim()
        : '';
    const healedPhotoUrl =
      typeof data.healedPhotoUrl === 'string' ? data.healedPhotoUrl.trim() : '';
    const existingThreadId =
      typeof data.threadId === 'string' ? data.threadId.trim() : '';

    if (!flashId && !customRequestId && !parentAppointmentId) {
      throw new HttpsError(
        'invalid-argument',
        'A flashId, customRequestId, or parentAppointmentId is required so pricing can be verified on the server.'
      );
    }

    const currency = (data.currency || 'usd').toLowerCase();
    if (currency !== 'usd') {
      throw new HttpsError('invalid-argument', 'Only USD deposits are supported.');
    }

    // 1. Load payment config, artist profile, schedule, private artist Stripe account, and client profile.
    const [config, artistSnap, schedulePreSnap, financialsSnap, userSnap] = await Promise.all([
      loadPaymentConfig(),
      db.collection('artists').doc(targetArtistId).get(),
      db.collection('artist_schedules').doc(targetArtistId).get(),
      db
        .collection('artists')
        .doc(targetArtistId)
        .collection('private')
        .doc('financials')
        .get(),
      db.collection('users').doc(clientUid).get(),
    ]);

    if (!artistSnap.exists) {
      throw new HttpsError('not-found', 'Artist profile could not be found.');
    }
    const artistData = (artistSnap.data() || {}) as Record<string, unknown>;
    const financialsData = (financialsSnap.exists ? financialsSnap.data() : {}) as Record<
      string,
      unknown
    >;

    const artistStripeAccountId =
      typeof financialsData.stripeAccountId === 'string'
        ? financialsData.stripeAccountId.trim()
        : '';
    const artistPayoutsEnabled =
      financialsData.payoutsEnabled === true &&
      financialsData.chargesEnabled === true;

    if (
      config.requireArtistStripeConnect &&
      (!artistStripeAccountId.startsWith('acct_') || !artistPayoutsEnabled)
    ) {
      throw new HttpsError(
        'failed-precondition',
        'This artist has not completed Stripe payout setup yet and cannot accept deposits right now.'
      );
    }

    const schedulePreData = (schedulePreSnap.exists ? schedulePreSnap.data() : {}) as Record<
      string,
      unknown
    >;
    const scheduleSlotDuration =
      typeof schedulePreData.slotDurationMinutes === 'number' &&
      schedulePreData.slotDurationMinutes > 0
        ? Math.floor(schedulePreData.slotDurationMinutes)
        : DEFAULT_FALLBACK_DURATION_MINUTES;
    let resolvedBufferMinutes =
      typeof schedulePreData.bufferDurationMinutes === 'number' &&
      schedulePreData.bufferDurationMinutes >= 0
        ? Math.floor(schedulePreData.bufferDurationMinutes)
        : DEFAULT_FALLBACK_BUFFER_MINUTES;

    // 2. Authoritative server-side price & availability resolution.
    let depositCents = 0;
    let totalPriceCents = 0;
    let resolvedTitle =
      typeof data.flashTitle === 'string' && data.flashTitle.trim().length > 0
        ? data.flashTitle.trim()
        : 'Tattoo Deposit';
    let resolvedImageUrl = '';
    let resolvedDuration = '2.0 hrs';
    let resolvedDurationMinutes =
      typeof data.durationMinutes === 'number' && data.durationMinutes > 0
        ? Math.floor(data.durationMinutes)
        : scheduleSlotDuration;
    let exclusiveFlash = false;
    let isTouchUp = false;
    let parentTattooTitle = '';
    let resolvedPlacement = String(data.placement || 'Forearm').trim();

    if (flashId) {
      const flashList = Array.isArray(artistData.flashArtworks)
        ? artistData.flashArtworks
        : [];
      const matched = flashList.find(
        (item) =>
          item &&
          typeof item === 'object' &&
          String((item as Record<string, unknown>).id || '').trim() === flashId
      ) as Record<string, unknown> | undefined;

      if (!matched) {
        throw new HttpsError(
          'not-found',
          'This flash artwork is no longer listed on the artist profile.'
        );
      }

      exclusiveFlash = isFlashExclusive(matched);
      if (exclusiveFlash && isFlashClaimed(matched)) {
        throw new HttpsError(
          'already-exists',
          'This one-off flash piece has already been claimed.'
        );
      }

      const depositDollars =
        typeof matched.deposit === 'number' && matched.deposit > 0
          ? matched.deposit
          : typeof artistData.minDeposit === 'number' && artistData.minDeposit > 0
            ? artistData.minDeposit
            : 50;
      const fullDollars =
        typeof matched.price === 'number' && matched.price > 0
          ? matched.price
          : typeof matched.fullPrice === 'number' && matched.fullPrice > 0
            ? matched.fullPrice
            : depositDollars * 3;

      depositCents = Math.round(depositDollars * 100);
      totalPriceCents = Math.round(fullDollars * 100);
      resolvedTitle =
        typeof matched.title === 'string' && matched.title.trim().length > 0
          ? matched.title.trim()
          : resolvedTitle;
      resolvedImageUrl =
        typeof matched.imageUrl === 'string' ? matched.imageUrl.trim() : '';
      resolvedDuration =
        typeof matched.estimatedTime === 'string' && matched.estimatedTime.trim().length > 0
          ? matched.estimatedTime.trim()
          : resolvedDuration;
      resolvedDurationMinutes = parseDurationStringMinutes(
        matched.estimatedTime,
        resolvedDurationMinutes
      );
    } else if (customRequestId) {
      const reqSnap = await db.collection('custom_requests').doc(customRequestId).get();
      if (!reqSnap.exists) {
        throw new HttpsError('not-found', 'Custom tattoo request could not be found.');
      }
      const reqData = (reqSnap.data() || {}) as Record<string, unknown>;
      if (
        String(reqData.clientId || '').trim() !== clientUid ||
        String(reqData.artistId || '').trim() !== targetArtistId
      ) {
        throw new HttpsError(
          'permission-denied',
          'You are not authorized to pay for this custom request.'
        );
      }
      const depositDollars =
        typeof reqData.deposit === 'number' && reqData.deposit > 0
          ? reqData.deposit
          : typeof artistData.minDeposit === 'number' && artistData.minDeposit > 0
            ? artistData.minDeposit
            : 50;
      const fullDollars =
        typeof reqData.estimatedPrice === 'number' && reqData.estimatedPrice > 0
          ? reqData.estimatedPrice
          : depositDollars * 3;
      depositCents = Math.round(depositDollars * 100);
      totalPriceCents = Math.round(fullDollars * 100);
      resolvedTitle =
        typeof reqData.category === 'string' && reqData.category.trim().length > 0
          ? `Custom: ${reqData.category.trim()}`
          : 'Custom Tattoo Deposit';
      resolvedImageUrl =
        typeof reqData.sketchImageUrl === 'string' ? reqData.sketchImageUrl.trim() : '';
      if (typeof reqData.durationMinutes === 'number' && reqData.durationMinutes > 0) {
        resolvedDurationMinutes = Math.floor(reqData.durationMinutes);
      }
      const hrs = resolvedDurationMinutes / 60;
      resolvedDuration = Number.isInteger(hrs) ? `${hrs} hrs` : `${hrs.toFixed(1)} hrs`;
    } else if (parentAppointmentId) {
      const validatedTouchUp = await validateTouchUpEligibility({
        clientUid,
        targetArtistId,
        parentAppointmentId,
      });
      if (validatedTouchUp.feeDollars <= 0) {
        throw new HttpsError(
          'failed-precondition',
          'This touch-up is complimentary ($0). Confirm directly without Stripe checkout.'
        );
      }
      isTouchUp = true;
      parentTattooTitle = validatedTouchUp.parentTitle;
      depositCents = Math.round(validatedTouchUp.feeDollars * 100);
      totalPriceCents = depositCents;
      resolvedTitle = `Touch-up: ${validatedTouchUp.parentTitle}`;
      resolvedImageUrl = healedPhotoUrl || validatedTouchUp.parentImageUrl;
      resolvedDurationMinutes = validatedTouchUp.durationMinutes;
      resolvedBufferMinutes = validatedTouchUp.bufferMinutes;
      resolvedDuration = formatDurationLabel(resolvedDurationMinutes);
      resolvedPlacement = validatedTouchUp.parentPlacement;
    }

    if (depositCents < 50 || depositCents > 1000000) {
      throw new HttpsError(
        'failed-precondition',
        'Deposit amount must be between $0.50 and $10,000.00.'
      );
    }

    // 3. Server-side `free_bookings_remaining` promotional allowance & platform fee calculation.
    const userData = (userSnap.exists ? userSnap.data() : {}) as Record<string, unknown>;
    const hasExistingAllowance = typeof userData.free_bookings_remaining === 'number';
    const freeBookingsRemaining = hasExistingAllowance
      ? Math.max(0, Math.floor(userData.free_bookings_remaining as number))
      : config.defaultFreeBookingsAllowance;

    const basePlatformFeeCents =
      Math.round(depositCents * (config.platformFeePercent / 100)) +
      config.platformFeeFlatCents;
    const promoFeeWaived = freeBookingsRemaining > 0;
    const platformFeeCents = promoFeeWaived ? 0 : basePlatformFeeCents;
    const totalChargeCents = depositCents + platformFeeCents;

    const resolvedEndMinutes =
      parsedStartMinutes + resolvedDurationMinutes + resolvedBufferMinutes;

    // 4. Pre-check appointments/bookings/locks/schedule collections for interval conflicts.
    await assertSlotIsAvailable(
      targetArtistId,
      dateKey,
      normalizedSlot,
      bookingId,
      clientUid,
      {
        startMinutes: parsedStartMinutes,
        durationMinutes: resolvedDurationMinutes,
        bufferMinutes: resolvedBufferMinutes,
        ignoreHoldId: cleanHoldId,
        isTouchUp,
      }
    );

    // 5. Atomically acquire 10-minute checkout locks (time slot + one-off flash piece)
    // and persist server-authoritative pending_payment booking document.
    const slotLockId = buildSlotLockId(targetArtistId, dateKey, normalizedSlot);
    const flashLockId =
      flashId && exclusiveFlash ? buildFlashLockId(targetArtistId, flashId) : '';
    const slotLockRef = db.collection(CHECKOUT_LOCKS_COLLECTION).doc(slotLockId);
    const flashLockRef = flashLockId
      ? db.collection(CHECKOUT_LOCKS_COLLECTION).doc(flashLockId)
      : null;
    const scheduleRef = db.collection('artist_schedules').doc(targetArtistId);
    const artistRef = db.collection('artists').doc(targetArtistId);
    const bookingRef = db.collection('bookings').doc(bookingId);
    const userRef = db.collection('users').doc(clientUid);

    const nowMs = Date.now();
    const lockExpiresAtMs = nowMs + CHECKOUT_LOCK_TTL_MS;
    const nowTimestamp = admin.firestore.Timestamp.fromMillis(nowMs);
    const expiresAtTimestamp = admin.firestore.Timestamp.fromMillis(lockExpiresAtMs);
    const transferGroup = `booking_${bookingId}`;

    await db.runTransaction(async (tx) => {
      const [schedTxSnap, slotLockSnap, flashLockSnap, artistTxSnap] =
        await Promise.all([
          tx.get(scheduleRef),
          tx.get(slotLockRef),
          flashLockRef ? tx.get(flashLockRef) : Promise.resolve(null),
          flashId && exclusiveFlash ? tx.get(artistRef) : Promise.resolve(null),
        ]);

      // Re-verify schedule intervals inside transaction to eliminate race windows.
      if (schedTxSnap.exists) {
        const sched = (schedTxSnap.data() || {}) as Record<string, unknown>;
        assertIntervalIsAvailable({
          scheduleData: sched,
          dateKey,
          candidateStartMinutes: parsedStartMinutes,
          durationMinutes: resolvedDurationMinutes,
          bufferMinutes: resolvedBufferMinutes,
          nowMs,
          ignoreHoldId: cleanHoldId,
          isTouchUp,
        });
      }

      // Re-verify slot checkout lock.
      if (slotLockSnap.exists) {
        const lockData = (slotLockSnap.data() || {}) as Record<string, unknown>;
        const lockExp = readTimestampMillis(lockData.expiresAt);
        const holder = String(lockData.holderClientId || '').trim();
        if (lockExp > nowMs && holder && holder !== clientUid) {
          throwTimeSlotConflict(
            'TIME_SLOT_CONFLICT: Another collector is currently checking out this time slot. Please try again shortly or pick another time.'
          );
        }
      }

      // Re-verify exclusive flash artwork & flash lock.
      if (flashLockSnap && flashLockSnap.exists) {
        const lockData = (flashLockSnap.data() || {}) as Record<string, unknown>;
        const lockExp = readTimestampMillis(lockData.expiresAt);
        const holder = String(lockData.holderClientId || '').trim();
        if (lockExp > nowMs && holder && holder !== clientUid) {
          throw new HttpsError(
            'already-exists',
            'Another collector currently has this one-off flash piece reserved in checkout. Please try again in a few minutes.'
          );
        }
      }
      if (artistTxSnap && artistTxSnap.exists) {
        const freshArtist = (artistTxSnap.data() || {}) as Record<string, unknown>;
        const freshList = Array.isArray(freshArtist.flashArtworks)
          ? freshArtist.flashArtworks
          : [];
        const freshFlash = freshList.find(
          (item) =>
            item &&
            typeof item === 'object' &&
            String((item as Record<string, unknown>).id || '').trim() === flashId
        ) as Record<string, unknown> | undefined;
        if (freshFlash && isFlashExclusive(freshFlash) && isFlashClaimed(freshFlash)) {
          throw new HttpsError(
            'already-exists',
            'This one-off flash piece was just claimed by another collector.'
          );
        }
      }

      // Acquire locks atomically.
      tx.set(slotLockRef, {
        lockType: 'slot',
        artistId: targetArtistId,
        dateKey,
        timeSlot: normalizedSlot,
        startMinutes: parsedStartMinutes,
        durationMinutes: resolvedDurationMinutes,
        bufferMinutes: resolvedBufferMinutes,
        endMinutes: resolvedEndMinutes,
        bookingId,
        holderClientId: clientUid,
        createdAt: nowTimestamp,
        expiresAt: expiresAtTimestamp,
      });

      if (flashLockRef) {
        tx.set(flashLockRef, {
          lockType: 'flash',
          artistId: targetArtistId,
          flashId,
          bookingId,
          holderClientId: clientUid,
          createdAt: nowTimestamp,
          expiresAt: expiresAtTimestamp,
        });
      }

      if (!hasExistingAllowance) {
        tx.set(
          userRef,
          {
            uid: clientUid,
            free_bookings_remaining: config.defaultFreeBookingsAllowance,
            updatedAt: nowTimestamp,
          },
          { merge: true }
        );
      }

      tx.set(
        bookingRef,
        {
          id: bookingId,
          bookingId,
          clientId: clientUid,
          artistId: targetArtistId,
          artistName: String(artistData.name || artistData.displayName || 'Artist'),
          artistAvatar: String(artistData.avatarUrl || artistData.photoUrl || ''),
          studioName: String(artistData.studioName || artistData.studioType || 'Studio'),
          studioLocation: String(artistData.location || ''),
          ...(flashId ? { flashId, flashIsExclusive: exclusiveFlash } : {}),
          ...(customRequestId ? { customRequestId } : {}),
          ...(isTouchUp
            ? {
                isTouchUp: true,
                parentAppointmentId,
                parentTattooTitle,
                ...(healedPhotoUrl ? { healedPhotoUrl } : {}),
                ...(existingThreadId ? { threadId: existingThreadId } : {}),
              }
            : {}),
          flashTitle: resolvedTitle,
          flashImageUrl: resolvedImageUrl,
          artworkImageUrl: resolvedImageUrl,
          estimatedTime: resolvedDuration,
          selectedDate: data.selectedDate || dateKey,
          selectedDateKey: dateKey,
          selectedTimeSlot: String(data.selectedTimeSlot || normalizedSlot).trim(),
          startMinutes: parsedStartMinutes,
          durationMinutes: resolvedDurationMinutes,
          bufferMinutes: resolvedBufferMinutes,
          endMinutes: resolvedEndMinutes,
          placement: resolvedPlacement,
          clientName: String(
            data.customerName || userData.displayName || userData.username || 'Client'
          ).trim(),
          clientEmail: String(data.customerEmail || request.auth?.token.email || '').trim(),
          clientPhone: String(
            data.customerPhone || request.auth?.token.phone_number || ''
          ).trim(),
          ...(data.clientNotes ? { clientNotes: String(data.clientNotes).trim() } : {}),
          isSilentAppointment: data.isSilentAppointment === true,
          depositAmount: Math.round(depositCents / 100),
          totalAmount: Math.round(totalPriceCents / 100),
          depositAmountCents: depositCents,
          totalPriceCents,
          platformFeeCents,
          totalChargeCents,
          artistPayoutCents: depositCents,
          promoFeeWaived,
          transferGroup,
          slotLockId,
          ...(flashLockId ? { flashLockId } : {}),
          lockExpiresAt: expiresAtTimestamp,
          status: 'pending_payment',
          escrowStatus: 'pending',
          createdAt: nowTimestamp,
          updatedAt: nowTimestamp,
        },
        { merge: true }
      );
    });

    // 6. Create Stripe PaymentIntent held on platform account (Separate Charges & Transfers).
    try {
      const stripe = getStripeClient();
      const customerEmail =
        typeof data.customerEmail === 'string' && data.customerEmail.trim().length > 0
          ? data.customerEmail.trim()
          : request.auth.token.email || undefined;

      const params: Stripe.PaymentIntentCreateParams = {
        amount: totalChargeCents,
        currency,
        automatic_payment_methods: { enabled: true },
        transfer_group: transferGroup,
        payment_method_options: {
          card: {
            request_three_d_secure: 'automatic',
          },
        },
        description: `Flash.Ink Deposit: ${resolvedTitle}`,
        ...(customerEmail ? { receipt_email: customerEmail } : {}),
        metadata: {
          booking_id: bookingId,
          client_id: clientUid,
          artist_id: targetArtistId,
          artist_stripe_account_id: artistStripeAccountId,
          flash_id: flashId,
          flash_is_exclusive: exclusiveFlash ? 'true' : 'false',
          flash_title: resolvedTitle,
          custom_request_id: customRequestId,
          is_touch_up: isTouchUp ? 'true' : 'false',
          parent_appointment_id: parentAppointmentId,
          customer_name: String(data.customerName || '').trim(),
          selected_date: dateKey,
          selected_time_slot: String(data.selectedTimeSlot || normalizedSlot).trim(),
          start_minutes: String(parsedStartMinutes),
          duration_minutes: String(resolvedDurationMinutes),
          buffer_minutes: String(resolvedBufferMinutes),
          placement: resolvedPlacement,
          deposit_cents: String(depositCents),
          platform_fee_cents: String(platformFeeCents),
          total_price_cents: String(totalPriceCents),
          promo_fee_waived: promoFeeWaived ? 'true' : 'false',
          slot_lock_id: slotLockId,
          flash_lock_id: flashLockId,
        },
      };

      const paymentIntent = await stripe.paymentIntents.create(params);

      await bookingRef.set(
        {
          stripePaymentIntentId: paymentIntent.id,
          paymentIntentId: paymentIntent.id,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      return {
        clientSecret: paymentIntent.client_secret,
        id: paymentIntent.id,
        bookingId,
        lockExpiresAt: new Date(lockExpiresAtMs).toISOString(),
        depositCents,
        platformFeeCents,
        totalChargeCents,
        promoFeeWaived,
        freeBookingsRemaining,
      };
    } catch (err: unknown) {
      await cleanupCheckoutLocks({
        slotLockId,
        flashLockId: flashLockId || undefined,
        bookingId,
        markStatus: 'payment_failed',
      }).catch(() => undefined);

      if (err instanceof HttpsError) {
        throw err;
      }
      const message =
        err instanceof Error ? err.message : 'Unable to create Stripe PaymentIntent.';
      throw new HttpsError('internal', message);
    }
  }
);

/**
 * Callable Cloud Function: Release an active 10-minute checkout lock
 * when a collector cancels or backs out of Stripe PaymentSheet.
 */
export const releaseCheckoutLock = onCall(async (request) => {
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError('unauthenticated', 'Sign in is required to release a checkout lock.');
  }

  const clientUid = request.auth.uid;
  const data = (request.data || {}) as {
    bookingId?: string;
    artistId?: string;
    flashId?: string;
    selectedDate?: string;
    selectedTimeSlot?: string;
  };

  const bookingId = typeof data.bookingId === 'string' ? data.bookingId.trim() : '';
  if (!bookingId) {
    return { released: false };
  }

  const bookingRef = db.collection('bookings').doc(bookingId);
  const bookingSnap = await bookingRef.get();
  if (!bookingSnap.exists) {
    return { released: false };
  }

  const bookingData = (bookingSnap.data() || {}) as Record<string, unknown>;
  if (String(bookingData.clientId || '').trim() !== clientUid) {
    throw new HttpsError('permission-denied', 'Cannot release another user’s checkout lock.');
  }
  if (String(bookingData.status || '').trim() !== 'pending_payment') {
    return { released: false };
  }

  const slotLockId =
    typeof bookingData.slotLockId === 'string' && bookingData.slotLockId.trim().length > 0
      ? bookingData.slotLockId.trim()
      : undefined;
  const flashLockId =
    typeof bookingData.flashLockId === 'string' && bookingData.flashLockId.trim().length > 0
      ? bookingData.flashLockId.trim()
      : undefined;

  await cleanupCheckoutLocks({
    slotLockId,
    flashLockId,
    bookingId,
    markStatus: 'canceled',
  });

  return { released: true, bookingId };
});

/**
 * Stripe Connect Webhook: Verify Artist Payout Account & Confirm Escrowed Deposits
 *
 * Handles:
 * - `account.updated`: Confirms Stripe Connect onboarding and records payout readiness
 *   inside `artists/{uid}/private/financials` plus public `stripePayoutsReady` flag.
 * - `payment_intent.succeeded`: Atomically confirms booking in escrow, marks one-off
 *   flash claimed, decrements `free_bookings_remaining`, creates confirmed appointment,
 *   provisions deposit-gated chat (`chats/thread_booking_{bookingId}`), and clears locks.
 * - `payment_intent.payment_failed` / `payment_intent.canceled`: Releases 10-min checkout locks.
 */
export const stripeConnectWebhook = onRequest(
  { secrets: [stripeSecretKey, stripeWebhookSecret] },
  async (req, res) => {
    const sig = req.headers['stripe-signature'];
    const webhookSecret =
      stripeWebhookSecret.value() || process.env.STRIPE_WEBHOOK_SECRET || '';

    if (!sig || !webhookSecret) {
      res.status(400).send('Missing Stripe signature or webhook secret.');
      return;
    }

    let event: Stripe.Event;
    try {
      const stripe = getStripeClient();
      event = stripe.webhooks.constructEvent(req.rawBody, sig, webhookSecret);
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : 'Unknown webhook error';
      res.status(400).send(`Webhook Error: ${message}`);
      return;
    }

    if (event.type === 'account.updated') {
      const account = event.data.object as Stripe.Account;
      const uid = account.metadata?.firebaseUid;

      if (uid) {
        await persistStripeAccountState(uid, account);
      }
    } else if (event.type === 'payment_intent.succeeded') {
      const paymentIntent = event.data.object as Stripe.PaymentIntent;
      const metadata = paymentIntent.metadata || {};
      const bookingId = (metadata.booking_id || '').trim();
      const clientId = (metadata.client_id || '').trim();
      const artistId = (metadata.artist_id || '').trim();
      const flashId = (metadata.flash_id || '').trim();
      const flashIsExclusive = metadata.flash_is_exclusive === 'true';
      const promoFeeWaived = metadata.promo_fee_waived === 'true';
      const slotLockId = (metadata.slot_lock_id || '').trim();
      const flashLockId = (metadata.flash_lock_id || '').trim();

      const chargeId =
        typeof paymentIntent.latest_charge === 'string'
          ? paymentIntent.latest_charge
          : paymentIntent.latest_charge?.id || '';

      if (bookingId && clientId && artistId) {
        const bookingRef = db.collection('bookings').doc(bookingId);
        const artistRef = db.collection('artists').doc(artistId);
        const userRef = db.collection('users').doc(clientId);
        const appointmentRef = db.collection('appointments').doc(`cal_${bookingId}`);
        const defaultThreadId = `thread_booking_${bookingId}`;

        await db.runTransaction(async (tx) => {
          const [bookingSnap, artistSnap, userSnap] = await Promise.all([
            tx.get(bookingRef),
            flashId && flashIsExclusive ? tx.get(artistRef) : Promise.resolve(null),
            promoFeeWaived ? tx.get(userRef) : Promise.resolve(null),
          ]);

          const existingBooking = (bookingSnap.exists ? bookingSnap.data() : {}) as Record<
            string,
            unknown
          >;
          const threadId =
            typeof existingBooking.threadId === 'string' &&
            existingBooking.threadId.trim().length > 0
              ? existingBooking.threadId.trim()
              : defaultThreadId;
          const threadRef = db.collection('chats').doc(threadId);
          const isTouchUp =
            existingBooking.isTouchUp === true ||
            metadata.is_touch_up === 'true';
          const parentAppointmentId = String(
            existingBooking.parentAppointmentId ||
              metadata.parent_appointment_id ||
              ''
          ).trim();
          const parentTattooTitle = String(
            existingBooking.parentTattooTitle || ''
          ).trim();
          const healedPhotoUrl = String(
            existingBooking.healedPhotoUrl || ''
          ).trim();
          const alreadyConfirmed = existingBooking.status === 'deposit_confirmed';

          const depositCents =
            Number(metadata.deposit_cents) ||
            (typeof existingBooking.depositAmountCents === 'number'
              ? existingBooking.depositAmountCents
              : paymentIntent.amount);
          const platformFeeCents =
            Number(metadata.platform_fee_cents) ||
            (typeof existingBooking.platformFeeCents === 'number'
              ? existingBooking.platformFeeCents
              : 0);
          const totalPriceCents =
            Number(metadata.total_price_cents) ||
            (typeof existingBooking.totalPriceCents === 'number'
              ? existingBooking.totalPriceCents
              : depositCents * 3);

          const depositDollars = Math.round(depositCents / 100);
          const fullPriceDollars = Math.round(totalPriceCents / 100);
          const flashTitle =
            String(existingBooking.flashTitle || metadata.flash_title || 'Flash Tattoo').trim();
          const clientName =
            String(existingBooking.clientName || metadata.customer_name || 'Client').trim();
          const artistName = String(existingBooking.artistName || 'Artist').trim();
          const selectedDate = String(
            existingBooking.selectedDate || metadata.selected_date || ''
          ).trim();
          const selectedTimeSlot = String(
            existingBooking.selectedTimeSlot || metadata.selected_time_slot || ''
          ).trim();
          const placement = String(
            existingBooking.placement || metadata.placement || 'Forearm'
          ).trim();
          const nowIso = new Date().toISOString();

          tx.set(
            bookingRef,
            {
              status: 'deposit_confirmed',
              escrowStatus: 'held',
              paymentIntentId: paymentIntent.id,
              stripePaymentIntentId: paymentIntent.id,
              ...(chargeId ? { chargeId } : {}),
              depositPaidCents: depositCents,
              platformFeeCents,
              totalChargeCents: paymentIntent.amount,
              artistPayoutCents: depositCents,
              transferGroup: paymentIntent.transfer_group || `booking_${bookingId}`,
              depositPaidAt: admin.firestore.FieldValue.serverTimestamp(),
              confirmedAt: admin.firestore.FieldValue.serverTimestamp(),
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
              ...(promoFeeWaived ? { promoConsumed: true } : {}),
            },
            { merge: true }
          );

          // Decrement client's free booking promo allowance once (idempotently).
          if (
            promoFeeWaived &&
            existingBooking.promoConsumed !== true &&
            userSnap
          ) {
            const uData = (userSnap.exists ? userSnap.data() : {}) as Record<string, unknown>;
            const currentRemaining =
              typeof uData.free_bookings_remaining === 'number'
                ? Math.floor(uData.free_bookings_remaining)
                : DEFAULT_FREE_BOOKINGS_ALLOWANCE;
            tx.set(
              userRef,
              {
                free_bookings_remaining: Math.max(0, currentRemaining - 1),
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
              },
              { merge: true }
            );
          }

          // Mark one-off flash piece as claimed on the artist document.
          if (artistSnap && artistSnap.exists && flashId && flashIsExclusive) {
            const aData = (artistSnap.data() || {}) as Record<string, unknown>;
            const artworks = Array.isArray(aData.flashArtworks) ? aData.flashArtworks : [];
            let modified = false;
            const updatedArtworks = artworks.map((item) => {
              if (
                item &&
                typeof item === 'object' &&
                String((item as Record<string, unknown>).id || '').trim() === flashId
              ) {
                modified = true;
                return {
                  ...(item as Record<string, unknown>),
                  status: 'claimed',
                  isClaimed: true,
                };
              }
              return item;
            });
            if (modified) {
              const availableCount = updatedArtworks.filter((item) => {
                if (!item || typeof item !== 'object') return false;
                return !isFlashClaimed(item as Record<string, unknown>);
              }).length;
              tx.set(
                artistRef,
                {
                  flashArtworks: updatedArtworks,
                  availablePieces: availableCount,
                  updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                },
                { merge: true }
              );
            }
          }

          // Create/update authoritative confirmed appointment record.
          tx.set(
            appointmentRef,
            {
              id: `cal_${bookingId}`,
              bookingId,
              clientId,
              artistId,
              clientName,
              ...(existingBooking.clientAvatar
                ? { clientAvatar: existingBooking.clientAvatar }
                : {}),
              artistName,
              ...(existingBooking.artistAvatar
                ? { artistAvatar: existingBooking.artistAvatar }
                : {}),
              studioName: String(existingBooking.studioName || 'Studio'),
              studioAddress: String(existingBooking.studioLocation || ''),
              serviceType: isTouchUp
                ? (flashTitle.startsWith('Touch-up')
                    ? flashTitle
                    : `Touch-up: ${flashTitle}`)
                : `Flash: ${flashTitle}`,
              flashTitle,
              ...(isTouchUp
                ? {
                    isTouchUp: true,
                    ...(parentAppointmentId ? { parentAppointmentId } : {}),
                    ...(parentTattooTitle ? { parentTattooTitle } : {}),
                    ...(healedPhotoUrl ? { healedPhotoUrl } : {}),
                  }
                : {}),
              duration: String(existingBooking.estimatedTime || '2.0 hrs'),
              ...(typeof existingBooking.startMinutes === 'number'
                ? { startMinutes: existingBooking.startMinutes }
                : {}),
              ...(typeof existingBooking.durationMinutes === 'number'
                ? { durationMinutes: existingBooking.durationMinutes }
                : {}),
              ...(typeof existingBooking.bufferMinutes === 'number'
                ? { bufferMinutes: existingBooking.bufferMinutes }
                : {}),
              ...(typeof existingBooking.endMinutes === 'number'
                ? { endMinutes: existingBooking.endMinutes }
                : {}),
              time: selectedTimeSlot,
              scheduledDate: selectedDate,
              date: selectedDate,
              placement,
              notes: String(existingBooking.clientNotes || ''),
              isSilentAppointment: existingBooking.isSilentAppointment === true,
              depositPaid: depositDollars,
              fullPrice: fullPriceDollars,
              balanceDue: Math.max(0, fullPriceDollars - depositDollars),
              artworkImageUrl: String(existingBooking.flashImageUrl || ''),
              visitType: isTouchUp ? 'Touch-up' : 'Flash Tattoo',
              status: 'confirmed',
              escrowStatus: 'held',
              paymentIntentId: paymentIntent.id,
              updatedAt: nowIso,
            },
            { merge: true }
          );

          // Provision deposit-gated chat thread matching app thread ID convention.
          tx.set(
            threadRef,
            {
              id: threadId,
              bookingId,
              artistId,
              clientId,
              clientName,
              artistName,
              ...(existingBooking.clientAvatar
                ? { clientAvatar: existingBooking.clientAvatar }
                : {}),
              ...(existingBooking.artistAvatar
                ? { artistAvatar: existingBooking.artistAvatar }
                : {}),
              studioName: String(existingBooking.studioName || 'Studio'),
              flashTitleContext: flashTitle,
              participants: [clientId, artistId],
              depositConfirmed: true,
              status: 'active',
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            },
            { merge: true }
          );

          // Release temporary 10-minute checkout locks now that slot is permanently booked.
          if (slotLockId) {
            tx.delete(db.collection(CHECKOUT_LOCKS_COLLECTION).doc(slotLockId));
          }
          if (flashLockId) {
            tx.delete(db.collection(CHECKOUT_LOCKS_COLLECTION).doc(flashLockId));
          }

          if (!alreadyConfirmed) {
            const artistNotifId = `notif_deposit_artist_${bookingId}`;
            tx.set(
              db.collection('notifications').doc(artistNotifId),
              {
                id: artistNotifId,
                senderId: clientId,
                recipientId: artistId,
                category: 'booking_confirmed',
                type: 'booking_confirmed',
                title: 'New Booking Deposit Secured',
                body: `${clientName} paid a $${depositDollars} deposit for "${flashTitle}" (held in escrow until check-in).`,
                message: `${clientName} paid a $${depositDollars} deposit for "${flashTitle}".`,
                appointmentId: `cal_${bookingId}`,
                threadId,
                createdAt: nowIso,
              },
              { merge: true }
            );

            const clientNotifId = `notif_deposit_client_${bookingId}`;
            tx.set(
              db.collection('notifications').doc(clientNotifId),
              {
                id: clientNotifId,
                senderId: artistId,
                recipientId: clientId,
                category: 'booking_confirmed',
                type: 'booking_confirmed',
                title: 'Booking Confirmed!',
                body: `Your $${depositDollars} deposit for "${flashTitle}" is safely held in escrow. Direct chat with ${artistName} is now unlocked.`,
                message: `Your $${depositDollars} deposit for "${flashTitle}" is confirmed.`,
                appointmentId: `cal_${bookingId}`,
                threadId,
                createdAt: nowIso,
              },
              { merge: true }
            );
          }
        });
      }
    } else if (
      event.type === 'payment_intent.payment_failed' ||
      event.type === 'payment_intent.canceled'
    ) {
      const paymentIntent = event.data.object as Stripe.PaymentIntent;
      const metadata = paymentIntent.metadata || {};
      const bookingId = (metadata.booking_id || '').trim();
      const slotLockId = (metadata.slot_lock_id || '').trim();
      const flashLockId = (metadata.flash_lock_id || '').trim();
      const markStatus =
        event.type === 'payment_intent.canceled' ? 'canceled' : 'payment_failed';

      if (bookingId || slotLockId || flashLockId) {
        await cleanupCheckoutLocks({
          slotLockId: slotLockId || undefined,
          flashLockId: flashLockId || undefined,
          bookingId: bookingId || undefined,
          markStatus,
        });
      }
    }

    res.status(200).json({ received: true });
  }
);
