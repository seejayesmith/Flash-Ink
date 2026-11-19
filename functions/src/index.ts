import * as crypto from 'crypto';
import * as admin from 'firebase-admin';
import { defineSecret } from 'firebase-functions/params';
import { onCall, HttpsError, onRequest } from 'firebase-functions/v2/https';
import {
  onDocumentCreated,
  onDocumentUpdated,
  onDocumentWritten,
} from 'firebase-functions/v2/firestore';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import Stripe from 'stripe';

admin.initializeApp();
const db = admin.firestore();

const stripeSecretKey = defineSecret('STRIPE_SECRET_KEY');

const getStripeClient = (): Stripe => {
  const secretKey = stripeSecretKey.value() || process.env.STRIPE_SECRET_KEY || '';
  return new Stripe(secretKey, {
    apiVersion: '2025-02-24.acacia',
  });
};

/**
 * 1. Callable Cloud Function: Complete Artist Onboarding & Issue Official Badge
 *
 * Called when an authenticated user finishes the artist onboarding steps.
 * Stamps the tamper-proof `{ role: 'artist' }` custom claim onto their Firebase Auth
 * token and segregates public discovery data from private PII (email, phone).
 */
export const completeArtistOnboarding = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError(
      'unauthenticated',
      'You must be signed in to complete artist onboarding.'
    );
  }

  const uid = request.auth.uid;
  const data = (request.data || {}) as {
    name?: string;
    username?: string;
    instagramHandle?: string;
    bio?: string;
    city?: string;
    studioType?: string;
    minDeposit?: number;
    tags?: string[];
    phoneNumber?: string;
    avatarUrl?: string;
    photoUrl?: string;
  };

  const artistName = (data.name || request.auth.token.name || 'Artist').trim();
  const rawHandleInput = (
    data.username ||
    data.instagramHandle ||
    data.name ||
    ''
  ).trim();
  const cleanHandle = rawHandleInput.replace(/@/g, '').trim();
  const normalizedHandle = cleanHandle.toLowerCase();
  const isValidHandleFormat =
    normalizedHandle.length >= 3 &&
    normalizedHandle.length <= 30 &&
    /^[a-z0-9_]([a-z0-9._]{1,28}[a-z0-9_])?$/.test(normalizedHandle) &&
    !normalizedHandle.includes('..');

  if (isValidHandleFormat) {
    const handleRef = db.collection('usernames').doc(normalizedHandle);
    await db.runTransaction(async (tx) => {
      const handleSnap = await tx.get(handleRef);
      if (handleSnap.exists) {
        const ownerUid = String(handleSnap.data()?.uid || '').trim();
        if (ownerUid.length > 0 && ownerUid !== uid) {
          throw new HttpsError(
            'already-exists',
            'That username is already taken'
          );
        }
      }
      tx.set(
        handleRef,
        {
          uid,
          username: cleanHandle,
          normalizedUsername: normalizedHandle,
          ...(handleSnap.exists
            ? {}
            : { createdAt: admin.firestore.FieldValue.serverTimestamp() }),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    });
  }

  const email = request.auth.token.email || '';
  const phoneNumber = (data.phoneNumber || request.auth.token.phone_number || '').trim();
  const minDeposit = typeof data.minDeposit === 'number' && data.minDeposit >= 20
    ? data.minDeposit
    : 50;

  // 1. Stamp the tamper-proof Custom Claim onto the user's Firebase Auth JWT
  await admin.auth().setCustomUserClaims(uid, {
    role: 'artist',
    isArtist: true,
    isClient: true,
    verifiedArtist: true,
  });

  const userRef = db.collection('users').doc(uid);
  const existingUserSnap = await userRef.get();
  const existingUserData = existingUserSnap.data();
  const hasExistingClientName =
    existingUserData &&
    typeof existingUserData.displayName === 'string' &&
    existingUserData.displayName.trim().length > 0;

  const resolvedPhotoUrl = (
    data.avatarUrl ||
    data.photoUrl ||
    (typeof existingUserData?.photoUrl === 'string' ? existingUserData.photoUrl : '') ||
    (typeof existingUserData?.photoURL === 'string' ? existingUserData.photoURL : '') ||
    request.auth.token.picture ||
    ''
  ).trim();

  const batch = db.batch();

  // 2. Update the user's own account record (server-authoritative dual-role support)
  batch.set(
    userRef,
    {
      uid,
      ...(!hasExistingClientName ? { displayName: artistName } : {}),
      ...(resolvedPhotoUrl.length > 0
        ? { photoUrl: resolvedPhotoUrl, photoURL: resolvedPhotoUrl }
        : {}),
      role: existingUserData?.role || 'client',
      isArtist: true,
      activeMode: 'artist',
      roles: admin.firestore.FieldValue.arrayUnion('client', 'artist'),
      profileCompleted: true,
      claimsUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  // 3. Save ONLY public discovery fields to `artists/{uid}`
  const artistPublicRef = db.collection('artists').doc(uid);
  batch.set(
    artistPublicRef,
    {
      id: uid,
      name: artistName,
      instagramHandle: data.instagramHandle || '',
      bio: data.bio || '',
      location: data.city || 'Portland, OR',
      studioType: data.studioType || 'Private Studio',
      minDeposit,
      tags: Array.isArray(data.tags) ? data.tags.slice(0, 20) : [],
      ...(resolvedPhotoUrl.length > 0
        ? { avatarUrl: resolvedPhotoUrl, photoUrl: resolvedPhotoUrl }
        : {}),
      profileCompleted: true,
      isBooksOpen: true,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  // 4. Segregate private PII (email, phone) into `artists/{uid}/private/settings`
  const artistPrivateRef = artistPublicRef.collection('private').doc('settings');
  batch.set(
    artistPrivateRef,
    {
      email,
      phoneNumber,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  await batch.commit();

  return {
    success: true,
    uid,
    role: 'artist',
  };
});

/**
 * 2. Callable Cloud Function: Create Stripe PaymentIntent for Flash Deposit
 *
 * Unlocks `STRIPE_SECRET_KEY` from Firebase Secret Manager, creates a PaymentIntent
 * in Stripe, and returns the one-time `clientSecret` to the Flutter app so it can
 * present the native Stripe PaymentSheet.
 */
export const createPaymentIntent = onCall(
  { secrets: [stripeSecretKey] },
  async (request) => {
    const data = (request.data || {}) as {
      amount?: number;
      currency?: string;
      flashTitle?: string;
      customerEmail?: string;
      customerName?: string;
      accountId?: string;
      artistId?: string;
      bookingId?: string;
      selectedDate?: string;
      selectedTimeSlot?: string;
      placement?: string;
    };

    const rawAmount = typeof data.amount === 'number' ? Math.round(data.amount) : 5000;
    if (rawAmount < 50 || rawAmount > 1000000) {
      throw new HttpsError(
        'invalid-argument',
        'Deposit amount must be between $0.50 and $10,000.00.'
      );
    }

    const currency = (data.currency || 'usd').toLowerCase();
    const clientUid = request.auth?.uid || 'guest_client';
    const targetArtistId = (
      data.artistId ||
      (data.accountId && !data.accountId.startsWith('acct_') ? data.accountId : '') ||
      ''
    ).trim();

    await assertSlotIsAvailable(
      targetArtistId,
      data.selectedDate,
      data.selectedTimeSlot,
      data.bookingId
    );

    try {
      const stripe = getStripeClient();

      const params: Stripe.PaymentIntentCreateParams = {
        amount: rawAmount,
        currency,
        automatic_payment_methods: { enabled: true },
        description: data.flashTitle
          ? `Flash.Ink Deposit: ${data.flashTitle}`
          : 'Flash.Ink Tattoo Deposit',
        ...(data.customerEmail ? { receipt_email: data.customerEmail } : {}),
        metadata: {
          booking_id: data.bookingId || '',
          client_id: clientUid,
          artist_id: data.artistId || data.accountId || '',
          flash_title: data.flashTitle || '',
          customer_name: data.customerName || '',
          selected_date: data.selectedDate || '',
          selected_time_slot: data.selectedTimeSlot || '',
          placement: data.placement || '',
        },
      };

      if (data.accountId && data.accountId.startsWith('acct_')) {
        params.transfer_data = {
          destination: data.accountId,
        };
      }

      const paymentIntent = await stripe.paymentIntents.create(params);

      return {
        clientSecret: paymentIntent.client_secret,
        id: paymentIntent.id,
      };
    } catch (err: unknown) {
      const message =
        err instanceof Error ? err.message : 'Unable to create Stripe PaymentIntent.';
      throw new HttpsError('internal', message);
    }
  }
);

/**
 * 3. Stripe Connect Webhook: Verify Artist Payout Account & Lock Deposit Escrow
 *
 * Handles:
 * - `account.updated`: Confirms Stripe Connect onboarding and records `stripeAccountId`
 *   inside the isolated `artists/{uid}/private/financials` subcollection.
 * - `payment_intent.succeeded`: Transitions booking status to `deposit_confirmed`
 *   and provisions the deposit-gated direct message thread (`chats/{threadId}`).
 */
export const stripeConnectWebhook = onRequest(
  { secrets: [stripeSecretKey] },
  async (req, res) => {
  const sig = req.headers['stripe-signature'];
  const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET;

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

    if (uid && account.details_submitted && account.charges_enabled && account.payouts_enabled) {
      await admin.auth().setCustomUserClaims(uid, {
        role: 'artist',
        stripeAccountId: account.id,
        verifiedArtist: true,
      });

      await db.collection('artists').doc(uid).collection('private').doc('financials').set(
        {
          stripeAccountId: account.id,
          payoutsEnabled: account.payouts_enabled,
          chargesEnabled: account.charges_enabled,
          detailsSubmitted: account.details_submitted,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    }
  } else if (event.type === 'payment_intent.succeeded') {
    const paymentIntent = event.data.object as Stripe.PaymentIntent;
    const bookingId = paymentIntent.metadata?.booking_id;
    const clientId = paymentIntent.metadata?.client_id;
    const artistId = paymentIntent.metadata?.artist_id;

    if (bookingId && clientId && artistId) {
      const batch = db.batch();
      const bookingRef = db.collection('bookings').doc(bookingId);
      batch.set(
        bookingRef,
        {
          status: 'deposit_confirmed',
          paymentIntentId: paymentIntent.id,
          depositPaidCents: paymentIntent.amount,
          confirmedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      // Provision the deposit-gated chat thread between Collector and Artist
      const threadRef = db.collection('chats').doc(`thread_${bookingId}`);
      batch.set(
        threadRef,
        {
          id: `thread_${bookingId}`,
          bookingId,
          artistId,
          clientId,
          participants: [clientId, artistId],
          status: 'active',
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      // Enqueue a booking confirmation notification for the artist
      const notifId = `notif_deposit_${bookingId}`;
      const notifRef = db.collection('notifications').doc(notifId);
      batch.set(
        notifRef,
        {
          id: notifId,
          senderId: clientId,
          recipientId: artistId,
          category: 'booking_confirmed',
          type: 'booking_confirmed',
          title: 'Deposit Confirmed',
          body: 'A collector confirmed their flash deposit.',
          message: 'A collector confirmed their flash deposit.',
          appointmentId: bookingId,
          createdAt: new Date().toISOString(),
        },
        { merge: true }
      );

      await batch.commit();
    }
  }

  res.status(200).json({ received: true });
});

/**
 * 3. Admin Role Management Callable Function
 *
 * Allows a platform administrator (`request.auth.token.admin === true`) to manually
 * assign or revoke the `'artist'` or `'client'` role claim.
 */
export const setArtistRoleClaim = onCall(async (request) => {
  if (!request.auth || request.auth.token.admin !== true) {
    throw new HttpsError(
      'permission-denied',
      'Only platform administrators can assign or revoke role claims.'
    );
  }

  const { targetUid, role } = (request.data || {}) as {
    targetUid?: string;
    role?: 'artist' | 'client';
  };

  if (!targetUid || (role !== 'artist' && role !== 'client')) {
    throw new HttpsError('invalid-argument', 'A valid targetUid and role ("artist" | "client") are required.');
  }

  await admin.auth().setCustomUserClaims(targetUid, { role });
  await db.collection('users').doc(targetUid).set(
    {
      role,
      claimsUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  return { success: true, uid: targetUid, role };
});

const RECOVERY_OTP_COLLECTION = 'auth_recovery_otps';
const RECOVERY_OTP_TTL_MS = 10 * 60 * 1000; // 10-minute TTL
const MAX_RECOVERY_OTP_ATTEMPTS = 5;
const EMAIL_PATTERN = /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/;

interface NormalizedRecoveryIdentifier {
  normalized: string;
  channel: 'email' | 'phone';
  identifierId: string;
}

const normalizeRecoveryIdentifier = (rawInput: unknown): NormalizedRecoveryIdentifier => {
  if (typeof rawInput !== 'string') {
    throw new HttpsError(
      'invalid-argument',
      'A valid recovery email or phone number is required.'
    );
  }

  const trimmed = rawInput.trim();
  if (trimmed.length === 0 || trimmed.length > 320) {
    throw new HttpsError(
      'invalid-argument',
      'A valid recovery email or phone number is required.'
    );
  }

  if (trimmed.includes('@')) {
    const email = trimmed.toLowerCase();
    if (!EMAIL_PATTERN.test(email)) {
      throw new HttpsError('invalid-argument', 'Please enter a valid email address.');
    }
    const identifierId = crypto.createHash('sha256').update(email).digest('hex');
    return { normalized: email, channel: 'email', identifierId };
  }

  const digitsOnly = trimmed.replace(/\D/g, '');
  if (digitsOnly.length < 10 || digitsOnly.length > 15) {
    throw new HttpsError('invalid-argument', 'Please enter a valid phone number.');
  }

  let e164Phone: string;
  if (trimmed.startsWith('+')) {
    e164Phone = `+${digitsOnly}`;
  } else if (digitsOnly.length === 11 && digitsOnly.startsWith('1')) {
    e164Phone = `+${digitsOnly}`;
  } else {
    e164Phone = `+1${digitsOnly}`;
  }

  const identifierId = crypto.createHash('sha256').update(e164Phone).digest('hex');
  return { normalized: e164Phone, channel: 'phone', identifierId };
};

const hashOtpCode = (code: string, salt: string): string => {
  return crypto.createHash('sha256').update(`${salt}:${code}`).digest('hex');
};

const verifyOtpCodeHash = (
  submittedCode: string,
  salt: string,
  expectedHashHex: string
): boolean => {
  if (!salt || !expectedHashHex) {
    return false;
  }
  const candidateHex = hashOtpCode(submittedCode, salt);
  const candidateBuf = Buffer.from(candidateHex, 'hex');
  const expectedBuf = Buffer.from(expectedHashHex, 'hex');
  if (candidateBuf.length === 0 || candidateBuf.length !== expectedBuf.length) {
    return false;
  }
  return crypto.timingSafeEqual(candidateBuf, expectedBuf);
};

/**
 * 4. Callable Cloud Function: Request Account Recovery OTP
 *
 * Accepts a user's recovery identifier (email or phone), generates a
 * cryptographically secure 6-digit OTP, and stores only its salted SHA-256 hash
 * in `auth_recovery_otps/{identifierId}` (Admin SDK only) with a 10-minute TTL
 * and `attempts: 0`. Never returns the plaintext OTP in production responses.
 */
export const requestRecoveryOtp = onCall(async (request) => {
  const data = (request.data || {}) as {
    identifier?: unknown;
    email?: unknown;
    phoneNumber?: unknown;
  };

  const rawIdentifier = data.identifier ?? data.email ?? data.phoneNumber;
  const { normalized, channel, identifierId } = normalizeRecoveryIdentifier(rawIdentifier);

  const otpCode = crypto.randomInt(100000, 1000000).toString();
  const salt = crypto.randomBytes(16).toString('hex');
  const codeHash = hashOtpCode(otpCode, salt);

  const docRef = db.collection(RECOVERY_OTP_COLLECTION).doc(identifierId);

  const txOutcome = await db.runTransaction<{ rateLimited: boolean }>(async (transaction) => {
    const existingSnap = await transaction.get(docRef);
    const nowMs = Date.now();
    let activeWindowRequests = 0;

    if (existingSnap.exists) {
      const existingData = existingSnap.data() || {};
      const existingExpiresMs =
        existingData.expiresAt instanceof admin.firestore.Timestamp
          ? existingData.expiresAt.toMillis()
          : 0;
      const existingAttempts =
        typeof existingData.attempts === 'number' ? existingData.attempts : 0;

      if (nowMs < existingExpiresMs) {
        activeWindowRequests =
          typeof existingData.requestCount === 'number' ? existingData.requestCount : 0;
        if (
          existingAttempts >= MAX_RECOVERY_OTP_ATTEMPTS ||
          activeWindowRequests >= MAX_RECOVERY_OTP_ATTEMPTS
        ) {
          return { rateLimited: true };
        }
      }
    }

    const createdAt = admin.firestore.Timestamp.fromMillis(nowMs);
    const expiresAt = admin.firestore.Timestamp.fromMillis(nowMs + RECOVERY_OTP_TTL_MS);

    transaction.set(docRef, {
      identifier: normalized,
      channel,
      codeHash,
      salt,
      createdAt,
      expiresAt,
      attempts: 0,
      requestCount: activeWindowRequests + 1,
    });

    return { rateLimited: false };
  });

  if (txOutcome.rateLimited) {
    throw new HttpsError(
      'resource-exhausted',
      'Too many OTP requests or failed attempts. Please wait before trying again.'
    );
  }

  // Note: Plaintext `otpCode` is intentionally omitted from the callable response
  // so it can never leak to unverified clients in production mode.
  return {
    success: true,
    channel,
    expiresInSeconds: RECOVERY_OTP_TTL_MS / 1000,
  };
});

/**
 * 5. Callable Cloud Function: Verify Account Recovery OTP
 *
 * Inside an Admin SDK Firestore transaction on `auth_recovery_otps/{identifierId}`,
 * verifies that the challenge exists, is unexpired (`now < expiresAt`), and has
 * `attempts < 5`. Increments `attempts` on mismatch (persisting before throwing
 * `HttpsError`), or deletes/consumes the document immediately on match to prevent replay.
 */
export const verifyRecoveryOtp = onCall(async (request) => {
  const data = (request.data || {}) as {
    identifier?: unknown;
    email?: unknown;
    phoneNumber?: unknown;
    code?: unknown;
  };

  const rawIdentifier = data.identifier ?? data.email ?? data.phoneNumber;
  const { identifierId } = normalizeRecoveryIdentifier(rawIdentifier);

  const submittedCode = typeof data.code === 'string' ? data.code.trim() : '';
  if (!/^\d{6}$/.test(submittedCode)) {
    throw new HttpsError(
      'invalid-argument',
      'The verification code entered is invalid.',
      { code: 'invalid-verification-code' }
    );
  }

  type VerifyOtpTxOutcome =
    | { status: 'verified' }
    | { status: 'not_found' }
    | { status: 'expired' }
    | { status: 'locked_out' }
    | { status: 'invalid_code'; attempts: number };

  const docRef = db.collection(RECOVERY_OTP_COLLECTION).doc(identifierId);

  const outcome = await db.runTransaction<VerifyOtpTxOutcome>(async (transaction) => {
    const snap = await transaction.get(docRef);
    if (!snap.exists) {
      return { status: 'not_found' };
    }

    const challengeData = snap.data() || {};
    const nowMs = Date.now();
    const expiresAtMs =
      challengeData.expiresAt instanceof admin.firestore.Timestamp
        ? challengeData.expiresAt.toMillis()
        : 0;
    const attempts =
      typeof challengeData.attempts === 'number' ? challengeData.attempts : 0;

    if (attempts >= MAX_RECOVERY_OTP_ATTEMPTS) {
      return { status: 'locked_out' };
    }

    if (!(nowMs < expiresAtMs)) {
      transaction.delete(docRef);
      return { status: 'expired' };
    }

    const storedHash =
      typeof challengeData.codeHash === 'string' ? challengeData.codeHash : '';
    const storedSalt =
      typeof challengeData.salt === 'string' ? challengeData.salt : '';

    if (!verifyOtpCodeHash(submittedCode, storedSalt, storedHash)) {
      const nextAttempts = attempts + 1;
      transaction.update(docRef, {
        attempts: nextAttempts,
        lastAttemptAt: admin.firestore.Timestamp.fromMillis(nowMs),
      });
      if (nextAttempts >= MAX_RECOVERY_OTP_ATTEMPTS) {
        return { status: 'locked_out' };
      }
      return { status: 'invalid_code', attempts: nextAttempts };
    }

    // Valid OTP: immediately consume/delete document so it cannot be replayed
    transaction.delete(docRef);
    return { status: 'verified' };
  });

  switch (outcome.status) {
    case 'verified':
      return { success: true, verified: true };
    case 'not_found':
      throw new HttpsError(
        'not-found',
        'No active verification code found. Please request a new code.',
        { code: 'session-expired' }
      );
    case 'expired':
      throw new HttpsError(
        'deadline-exceeded',
        'The verification code has expired. Please request a new code.',
        { code: 'session-expired' }
      );
    case 'locked_out':
      throw new HttpsError(
        'resource-exhausted',
        'Too many failed verification attempts. Please try again later.',
        { code: 'too-many-requests' }
      );
    case 'invalid_code':
      throw new HttpsError(
        'permission-denied',
        'The verification code entered is invalid.',
        { code: 'invalid-verification-code', attempts: outcome.attempts }
      );
  }
});

const isNotificationCategoryEnabled = (
  category: string,
  prefs?: Record<string, unknown>
): boolean => {
  if (!prefs) return true;
  switch (category) {
    case 'flash_drop':
      return prefs.flashDropAlerts !== false;
    case 'custom_request':
    case 'booking_request':
      return prefs.bookingAlerts !== false;
    case 'client_reminder':
      return prefs.bookingReminders !== false;
    case 'artist_reminder':
      return prefs.reminderAlerts !== false;
    case 'reminder':
      return prefs.bookingReminders !== false && prefs.reminderAlerts !== false;
    case 'artist_message':
      return prefs.artistMessages !== false;
    case 'client_message':
      return prefs.clientMessages !== false;
    case 'direct_message':
      return prefs.artistMessages !== false && prefs.clientMessages !== false;
    default:
      return true;
  }
};

/**
 * 6. Firestore Trigger: Dispatch Push Notifications via FCM
 *
 * Fires whenever a document is created in `notifications/{notificationId}`,
 * checks the recipient's `notificationPreferences`, sends a multicast FCM push
 * across all registered `fcmTokens`, and prunes invalid/expired tokens.
 */
export const dispatchPushNotification = onDocumentCreated(
  'notifications/{notificationId}',
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const payload = snap.data() as Record<string, unknown>;
    const recipientId =
      typeof payload.recipientId === 'string' ? payload.recipientId.trim() : '';
    if (!recipientId) return;

    const senderId =
      typeof payload.senderId === 'string' ? payload.senderId.trim() : '';
    const title =
      typeof payload.title === 'string' && payload.title.trim().length > 0
        ? payload.title.trim()
        : 'Flash.Ink';
    const body =
      typeof payload.body === 'string' && payload.body.trim().length > 0
        ? payload.body.trim()
        : typeof payload.message === 'string'
          ? payload.message.trim()
          : '';
    const category =
      typeof payload.category === 'string' ? payload.category.trim() : 'general';
    const appointmentId =
      typeof payload.appointmentId === 'string'
        ? payload.appointmentId.trim()
        : '';
    const threadId =
      typeof payload.threadId === 'string' ? payload.threadId.trim() : '';
    const artistId =
      typeof payload.artistId === 'string' ? payload.artistId.trim() : '';

    const userRef = db.collection('users').doc(recipientId);
    const userSnap = await userRef.get();
    const userData = userSnap.data() as Record<string, unknown> | undefined;

    const prefs =
      userData?.notificationPreferences &&
      typeof userData.notificationPreferences === 'object'
        ? (userData.notificationPreferences as Record<string, unknown>)
        : undefined;

    if (!isNotificationCategoryEnabled(category, prefs)) {
      await snap.ref.set(
        { deliveryStatus: 'skipped_preference' },
        { merge: true }
      );
      return;
    }

    const rawTokens = Array.isArray(userData?.fcmTokens)
      ? userData.fcmTokens
      : [];
    const tokens = rawTokens
      .filter((t): t is string => typeof t === 'string' && t.trim().length > 0)
      .map((t) => t.trim());

    if (tokens.length === 0) {
      await snap.ref.set({ deliveryStatus: 'no_tokens' }, { merge: true });
      return;
    }

    const response = await admin.messaging().sendEachForMulticast({
      tokens,
      notification: { title, body },
      data: {
        notificationId: event.params.notificationId,
        category,
        senderId,
        ...(appointmentId ? { appointmentId } : {}),
        ...(threadId ? { threadId } : {}),
        ...(artistId ? { artistId } : {}),
      },
      android: {
        priority: 'high',
        notification: {
          channelId: 'flash_ink_high_importance_channel',
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
          },
        },
      },
    });

    const invalidTokens: string[] = [];
    response.responses.forEach((res, idx) => {
      if (!res.success && res.error) {
        const code = res.error.code;
        if (
          code === 'messaging/registration-token-not-registered' ||
          code === 'messaging/invalid-registration-token'
        ) {
          invalidTokens.push(tokens[idx]);
        }
      }
    });

    if (invalidTokens.length > 0) {
      await userRef.update({
        fcmTokens: admin.firestore.FieldValue.arrayRemove(...invalidTokens),
      });
    }

    await snap.ref.set(
      {
        deliveryStatus: 'sent',
        successCount: response.successCount,
        failureCount: response.failureCount,
        deliveredAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  }
);

/**
 * 7. Firestore Trigger: Direct Message Push Producer
 *
 * Fires when a new message is written under `chats/{threadId}/messages/{messageId}`
 * and creates a `notifications` document for the other participant(s).
 */
export const onChatMessageCreated = onDocumentCreated(
  'chats/{threadId}/messages/{messageId}',
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const msgData = snap.data() as Record<string, unknown>;
    const senderId =
      typeof msgData.senderId === 'string' ? msgData.senderId.trim() : '';
    if (!senderId) return;

    const senderName =
      typeof msgData.senderName === 'string' ? msgData.senderName.trim() : '';
    const text = typeof msgData.text === 'string' ? msgData.text.trim() : '';
    const msgType = typeof msgData.type === 'string' ? msgData.type.trim() : 'text';
    const attachmentName =
      typeof msgData.attachmentName === 'string'
        ? msgData.attachmentName.trim()
        : '';

    const threadId = event.params.threadId;
    const threadSnap = await db.collection('chats').doc(threadId).get();
    if (!threadSnap.exists) return;

    const threadData = (threadSnap.data() || {}) as Record<string, unknown>;
    const artistId =
      typeof threadData.artistId === 'string' ? threadData.artistId.trim() : '';
    const clientId =
      typeof threadData.clientId === 'string' ? threadData.clientId.trim() : '';
    const artistName =
      typeof threadData.artistName === 'string'
        ? threadData.artistName.trim()
        : '';
    const clientName =
      typeof threadData.clientName === 'string'
        ? threadData.clientName.trim()
        : '';
    const bookingId =
      typeof threadData.bookingId === 'string'
        ? threadData.bookingId.trim()
        : '';

    const rawParticipants = Array.isArray(threadData.participants)
      ? threadData.participants
      : [];
    const recipientIds = new Set<string>();

    for (const p of rawParticipants) {
      if (typeof p === 'string' && p.trim().length > 0 && p.trim() !== senderId) {
        recipientIds.add(p.trim());
      }
    }

    if (recipientIds.size === 0) {
      const fallbackRecipient = senderId === artistId ? clientId : artistId;
      if (fallbackRecipient && fallbackRecipient !== senderId) {
        recipientIds.add(fallbackRecipient);
      }
    }

    if (recipientIds.size === 0) return;

    const nowIso = new Date().toISOString();
    const batch = db.batch();

    for (const recipientId of recipientIds) {
      const category =
        artistId && recipientId === artistId
          ? 'client_message'
          : 'artist_message';
      const displaySender =
        senderName ||
        (senderId === artistId ? artistName : clientName) ||
        'Flash.Ink';
      const attachmentFallback =
        msgType === 'image'
          ? 'Sent an image.'
          : msgType === 'file'
            ? attachmentName
              ? `Sent a file: ${attachmentName}`
              : 'Sent a file.'
            : 'Sent a new message.';
      const body = text || attachmentFallback;
      const notifId = `notif_msg_${event.params.messageId}_${recipientId}`;

      batch.set(
        db.collection('notifications').doc(notifId),
        {
          id: notifId,
          senderId,
          recipientId,
          category,
          type: category,
          title: `New message from ${displaySender}`,
          body,
          message: body,
          threadId,
          ...(bookingId ? { appointmentId: bookingId } : {}),
          createdAt: nowIso,
        },
        { merge: true }
      );
    }

    await batch.commit();
  }
);

/**
 * 8. Firestore Trigger: Flash Drop Follower & Waitlist Alerts
 *
 * Fires when an artist document updates, detects newly added unclaimed flash pieces,
 * and creates `flash_drop` notifications for followers and active waitlist contacts.
 */
export const onArtistFlashDrop = onDocumentUpdated(
  'artists/{artistId}',
  async (event) => {
    const change = event.data;
    if (!change) return;

    const beforeData = (change.before.data() || {}) as Record<string, unknown>;
    const afterData = (change.after.data() || {}) as Record<string, unknown>;

    const beforeFlash = Array.isArray(beforeData.flashArtworks)
      ? beforeData.flashArtworks
      : [];
    const afterFlash = Array.isArray(afterData.flashArtworks)
      ? afterData.flashArtworks
      : [];

    const beforeIds = new Set<string>();
    for (const item of beforeFlash) {
      if (item && typeof item === 'object') {
        const id = (item as Record<string, unknown>).id;
        if (typeof id === 'string' && id.trim().length > 0) {
          beforeIds.add(id.trim());
        }
      }
    }

    const newItems: Array<{ id: string; title: string }> = [];
    for (const item of afterFlash) {
      if (item && typeof item === 'object') {
        const record = item as Record<string, unknown>;
        const id = typeof record.id === 'string' ? record.id.trim() : '';
        const isClaimed = record.isClaimed === true;
        if (id && !beforeIds.has(id) && !isClaimed) {
          const title =
            typeof record.title === 'string' && record.title.trim().length > 0
              ? record.title.trim()
              : 'New Flash Piece';
          newItems.push({ id, title });
        }
      }
    }

    if (newItems.length === 0) return;

    const artistId = event.params.artistId;
    const recipientIds = new Set<string>();

    const followersSnap = await db
      .collection('users')
      .where('followedArtistIds', 'array-contains', artistId)
      .get();
    for (const doc of followersSnap.docs) {
      if (doc.id && doc.id !== artistId) {
        recipientIds.add(doc.id);
      }
    }

    const waitlistEntries = Array.isArray(afterData.waitlistEntries)
      ? afterData.waitlistEntries
      : [];
    for (const entry of waitlistEntries) {
      if (entry && typeof entry === 'object') {
        const record = entry as Record<string, unknown>;
        const flashUserId =
          typeof record.flashUserId === 'string'
            ? record.flashUserId.trim()
            : '';
        const status =
          typeof record.status === 'string'
            ? record.status.trim().toLowerCase()
            : 'waiting';
        if (
          flashUserId &&
          flashUserId !== artistId &&
          status !== 'booked' &&
          status !== 'archived'
        ) {
          recipientIds.add(flashUserId);
        }
      }
    }

    recipientIds.delete(artistId);
    if (recipientIds.size === 0) return;

    const artistName =
      typeof afterData.name === 'string' && afterData.name.trim().length > 0
        ? afterData.name.trim()
        : 'An artist you follow';
    const firstNew = newItems[0];
    const body =
      newItems.length > 1
        ? `${firstNew.title} and ${newItems.length - 1} more new flash pieces are available to claim.`
        : `${firstNew.title} is now available to claim.`;
    const nowIso = new Date().toISOString();

    const recipients = Array.from(recipientIds);
    const chunkSize = 450;
    for (let i = 0; i < recipients.length; i += chunkSize) {
      const chunk = recipients.slice(i, i + chunkSize);
      const batch = db.batch();
      for (const recipientId of chunk) {
        const notifId = `notif_flash_${artistId}_${firstNew.id}_${recipientId}`;
        batch.set(
          db.collection('notifications').doc(notifId),
          {
            id: notifId,
            senderId: artistId,
            recipientId,
            artistId,
            category: 'flash_drop',
            type: 'flash_drop',
            title: `New Flash Drop from ${artistName}`,
            body,
            message: body,
            createdAt: nowIso,
          },
          { merge: true }
        );
      }
      await batch.commit();
    }
  }
);

/**
 * 9. Scheduled Function: Automated 24h & 2h Appointment Reminders
 *
 * Runs every 30 minutes to scan confirmed upcoming appointments and enqueue
 * idempotent 24-hour and 2-hour reminder notifications for client & artist.
 */
export const dispatchAppointmentReminders = onSchedule(
  'every 30 minutes',
  async () => {
    const snap = await db
      .collection('appointments')
      .where('status', '==', 'confirmed')
      .get();

    if (snap.empty) return;

    const nowMs = Date.now();
    const nowIso = new Date(nowMs).toISOString();

    const pendingWrites: Array<{
      ref: admin.firestore.DocumentReference;
      data: Record<string, unknown>;
      merge: boolean;
    }> = [];

    for (const doc of snap.docs) {
      const data = doc.data() as Record<string, unknown>;
      const scheduledStr =
        typeof data.scheduledDate === 'string' ? data.scheduledDate.trim() : '';
      if (!scheduledStr) continue;

      const scheduledMs = Date.parse(scheduledStr);
      if (Number.isNaN(scheduledMs)) continue;

      const hoursUntil = (scheduledMs - nowMs) / (1000 * 60 * 60);
      if (hoursUntil <= 0 || hoursUntil > 24) continue;

      const clientId =
        typeof data.clientId === 'string' ? data.clientId.trim() : '';
      const artistId =
        typeof data.artistId === 'string' ? data.artistId.trim() : '';
      const clientName =
        typeof data.clientName === 'string' && data.clientName.trim().length > 0
          ? data.clientName.trim()
          : 'your client';
      const serviceType =
        typeof data.serviceType === 'string' && data.serviceType.trim().length > 0
          ? data.serviceType.trim()
          : 'tattoo session';
      const timeLabel =
        typeof data.time === 'string' && data.time.trim().length > 0
          ? ` at ${data.time.trim()}`
          : '';
      const dateLabel =
        typeof data.date === 'string' && data.date.trim().length > 0
          ? ` on ${data.date.trim()}`
          : '';

      const aptId = doc.id;

      if (hoursUntil > 2 && hoursUntil <= 24 && data.reminder24hSent !== true) {
        if (clientId) {
          const notifId = `notif_rem24_client_${aptId}`;
          const clientBody = `Your ${serviceType} session is coming up${dateLabel}${timeLabel}.`;
          pendingWrites.push({
            ref: db.collection('notifications').doc(notifId),
            data: {
              id: notifId,
              senderId: artistId || clientId,
              recipientId: clientId,
              category: 'client_reminder',
              type: 'client_reminder',
              title: 'Upcoming Session Tomorrow',
              body: clientBody,
              message: clientBody,
              appointmentId: aptId,
              createdAt: nowIso,
            },
            merge: true,
          });
        }
        if (artistId) {
          const notifId = `notif_rem24_artist_${aptId}`;
          const artistBody = `${serviceType} with ${clientName} is scheduled${dateLabel}${timeLabel}.`;
          pendingWrites.push({
            ref: db.collection('notifications').doc(notifId),
            data: {
              id: notifId,
              senderId: clientId || artistId,
              recipientId: artistId,
              category: 'artist_reminder',
              type: 'artist_reminder',
              title: 'Upcoming Session Tomorrow',
              body: artistBody,
              message: artistBody,
              appointmentId: aptId,
              createdAt: nowIso,
            },
            merge: true,
          });
        }
        pendingWrites.push({
          ref: doc.ref,
          data: { reminder24hSent: true },
          merge: true,
        });
      } else if (
        hoursUntil > 0 &&
        hoursUntil <= 2 &&
        data.reminder2hSent !== true
      ) {
        if (clientId) {
          const notifId = `notif_rem2_client_${aptId}`;
          const clientBody = `Your ${serviceType} session begins soon${timeLabel}.`;
          pendingWrites.push({
            ref: db.collection('notifications').doc(notifId),
            data: {
              id: notifId,
              senderId: artistId || clientId,
              recipientId: clientId,
              category: 'client_reminder',
              type: 'client_reminder',
              title: 'Session Starting in 2 Hours',
              body: clientBody,
              message: clientBody,
              appointmentId: aptId,
              createdAt: nowIso,
            },
            merge: true,
          });
        }
        if (artistId) {
          const notifId = `notif_rem2_artist_${aptId}`;
          const artistBody = `${serviceType} with ${clientName} begins soon${timeLabel}.`;
          pendingWrites.push({
            ref: db.collection('notifications').doc(notifId),
            data: {
              id: notifId,
              senderId: clientId || artistId,
              recipientId: artistId,
              category: 'artist_reminder',
              type: 'artist_reminder',
              title: 'Session Starting in 2 Hours',
              body: artistBody,
              message: artistBody,
              appointmentId: aptId,
              createdAt: nowIso,
            },
            merge: true,
          });
        }
        pendingWrites.push({
          ref: doc.ref,
          data: { reminder2hSent: true },
          merge: true,
        });
      }
    }

    const chunkSize = 450;
    for (let i = 0; i < pendingWrites.length; i += chunkSize) {
      const chunk = pendingWrites.slice(i, i + chunkSize);
      const batch = db.batch();
      for (const write of chunk) {
        batch.set(write.ref, write.data, { merge: write.merge });
      }
      await batch.commit();
    }
  }
);

interface AnonymizedSlotEntry {
  date: string;
  time: string;
}

const EXCLUDED_APPOINTMENT_STATUSES = new Set([
  'cancelled',
  'canceled',
  'declined',
  'passed',
]);

/**
 * Extracts `YYYY-MM-DD` directly from an ISO-8601 timestamp string or Firestore
 * Timestamp without timezone day-shift side effects.
 */
function extractDateKey(raw: unknown): string | null {
  if (typeof raw === 'string') {
    const match = raw.match(/^(\d{4}-\d{2}-\d{2})/);
    return match ? match[1] : null;
  }
  if (raw && typeof (raw as admin.firestore.Timestamp).toDate === 'function') {
    const dt = (raw as admin.firestore.Timestamp).toDate();
    return dt.toISOString().slice(0, 10);
  }
  return null;
}

function normalizeSlotLabel(raw: unknown): string {
  return String(raw || '').split('(')[0].trim().toUpperCase();
}

/**
 * Validates that the requested artist booking slot is still open and not
 * already booked, held, blocked, or closed before creating a PaymentIntent.
 */
async function assertSlotIsAvailable(
  artistIdRaw: unknown,
  selectedDateRaw: unknown,
  selectedTimeSlotRaw: unknown,
  currentBookingIdRaw?: unknown
): Promise<void> {
  const artistId = typeof artistIdRaw === 'string' ? artistIdRaw.trim() : '';
  const dateKey = extractDateKey(selectedDateRaw);
  const normalizedSlot = normalizeSlotLabel(selectedTimeSlotRaw);
  const currentBookingId =
    typeof currentBookingIdRaw === 'string' ? currentBookingIdRaw.trim() : '';

  if (!artistId || !dateKey || !normalizedSlot) {
    return;
  }

  const scheduleSnap = await db.collection('artist_schedules').doc(artistId).get();
  if (scheduleSnap.exists) {
    const schedule = (scheduleSnap.data() || {}) as Record<string, unknown>;
    if (schedule.isBooksOpen === false) {
      throw new HttpsError(
        'failed-precondition',
        "This artist's books are currently closed."
      );
    }

    const blockedDates = Array.isArray(schedule.blockedDates)
      ? schedule.blockedDates.map((d) => String(d).trim())
      : [];
    if (blockedDates.includes(dateKey)) {
      throw new HttpsError(
        'failed-precondition',
        'The selected date is unavailable.'
      );
    }

    const bookedSlots = Array.isArray(schedule.bookedSlots)
      ? schedule.bookedSlots
      : [];
    for (const rawEntry of bookedSlots) {
      if (rawEntry && typeof rawEntry === 'object') {
        const entry = rawEntry as Record<string, unknown>;
        const entryDate = extractDateKey(entry.date);
        const entryTime = normalizeSlotLabel(entry.time);
        if (entryDate === dateKey && entryTime === normalizedSlot) {
          throw new HttpsError(
            'already-exists',
            'This time slot has already been booked. Please select another time slot.'
          );
        }
      }
    }

    const nowMs = Date.now();
    const heldSlots = Array.isArray(schedule.heldSlots)
      ? schedule.heldSlots
      : [];
    for (const rawEntry of heldSlots) {
      if (rawEntry && typeof rawEntry === 'object') {
        const entry = rawEntry as Record<string, unknown>;
        const entryDate = extractDateKey(entry.date);
        const entryTime = normalizeSlotLabel(entry.time);
        const expiresAtMs = entry.expiresAt
          ? Date.parse(String(entry.expiresAt))
          : Number.POSITIVE_INFINITY;
        const isUnexpired = Number.isNaN(expiresAtMs) || expiresAtMs > nowMs;
        if (entryDate === dateKey && entryTime === normalizedSlot && isUnexpired) {
          throw new HttpsError(
            'already-exists',
            'This time slot is currently on a 24-hour hold. Please select another time slot.'
          );
        }
      }
    }
  }

  const [aptSnap, bookingSnap] = await Promise.all([
    db.collection('appointments').where('artistId', '==', artistId).get(),
    db.collection('bookings').where('artistId', '==', artistId).get(),
  ]);

  for (const doc of aptSnap.docs) {
    const docData = doc.data();
    const status = String(docData.status || 'confirmed').trim().toLowerCase();
    if (EXCLUDED_APPOINTMENT_STATUSES.has(status)) continue;
    const docDate = extractDateKey(docData.scheduledDate);
    const docTime = normalizeSlotLabel(docData.time);
    if (docDate === dateKey && docTime === normalizedSlot) {
      throw new HttpsError(
        'already-exists',
        'This time slot has already been booked. Please select another time slot.'
      );
    }
  }

  for (const doc of bookingSnap.docs) {
    if (currentBookingId && doc.id === currentBookingId) continue;
    const docData = doc.data();
    const status = String(docData.status || 'pending').trim().toLowerCase();
    if (EXCLUDED_APPOINTMENT_STATUSES.has(status)) continue;
    const docDate = extractDateKey(docData.selectedDate);
    const docTime = normalizeSlotLabel(docData.selectedTimeSlot);
    if (docDate === dateKey && docTime === normalizedSlot) {
      throw new HttpsError(
        'already-exists',
        'This time slot has already been booked. Please select another time slot.'
      );
    }
  }
}

/**
 * Recomputes anonymized `bookedSlots` (`[{date, time}]`) for an artist from
 * `/appointments` and `/bookings` so public booking clients can enforce slot
 * occupancy, empty-day lead time, and Sun–Sat weekly caps without reading private docs.
 */
async function recomputeArtistBookedSlots(artistId: string): Promise<void> {
  const cleanArtistId = artistId.trim();
  if (!cleanArtistId) return;

  // Keep the trailing 7 days so appointments earlier in the current Sun–Sat week
  // remain counted against maxWorkingDaysPerWeek.
  const cutoffDate = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
  const cutoffKey = cutoffDate.toISOString().slice(0, 10);

  const [aptSnap, bookingSnap] = await Promise.all([
    db.collection('appointments').where('artistId', '==', cleanArtistId).get(),
    db.collection('bookings').where('artistId', '==', cleanArtistId).get(),
  ]);

  const deduped = new Map<string, AnonymizedSlotEntry>();
  const addSlot = (
    dateRaw: unknown,
    timeRaw: unknown,
    statusRaw: unknown,
    defaultStatus: string
  ) => {
    const status = String(statusRaw || defaultStatus).trim().toLowerCase();
    if (EXCLUDED_APPOINTMENT_STATUSES.has(status)) return;

    const dateKey = extractDateKey(dateRaw);
    if (!dateKey || dateKey < cutoffKey) return;

    const rawTime = String(timeRaw || '').split('(')[0].trim();
    if (!rawTime) return;

    const mapKey = `${dateKey}__${rawTime.toUpperCase()}`;
    if (!deduped.has(mapKey)) {
      deduped.set(mapKey, { date: dateKey, time: rawTime });
    }
  };

  for (const doc of aptSnap.docs) {
    const data = doc.data();
    addSlot(data.scheduledDate, data.time, data.status, 'confirmed');
  }

  for (const doc of bookingSnap.docs) {
    const data = doc.data();
    addSlot(data.selectedDate, data.selectedTimeSlot, data.status, 'pending');
  }

  const bookedSlots = Array.from(deduped.values()).sort((a, b) =>
    a.date === b.date
      ? a.time.localeCompare(b.time)
      : a.date.localeCompare(b.date)
  );
  const nowIso = new Date().toISOString();

  await Promise.all([
    db.collection('artist_schedules').doc(cleanArtistId).set(
      {
        artistId: cleanArtistId,
        bookedSlots,
        updatedAt: nowIso,
      },
      { merge: true }
    ),
    db.collection('artists').doc(cleanArtistId).set(
      {
        booksSchedule: { bookedSlots },
        updatedAt: nowIso,
      },
      { merge: true }
    ),
  ]);
}

/**
 * 9. Firestore Trigger: Sync Anonymized Booked Slots on Appointment Write
 *
 * Keeps `artist_schedules/{artistId}.bookedSlots` up to date on create,
 * reschedule, cancel, or deletion without exposing private `/appointments` PII.
 */
export const syncArtistBookedSlotsOnAppointment = onDocumentWritten(
  'appointments/{appointmentId}',
  async (event) => {
    const beforeArtist = String(event.data?.before?.data()?.artistId || '').trim();
    const afterArtist = String(event.data?.after?.data()?.artistId || '').trim();
    const targetArtists = new Set<string>(
      [beforeArtist, afterArtist].filter((id) => id.length > 0)
    );
    if (targetArtists.size === 0) return;

    await Promise.all(
      Array.from(targetArtists).map((artistId) =>
        recomputeArtistBookedSlots(artistId)
      )
    );
  }
);

/**
 * 10. Firestore Trigger: Sync Anonymized Booked Slots on Booking Write
 *
 * Keeps `artist_schedules/{artistId}.bookedSlots` up to date whenever a client
 * creates or updates a flash booking document in `/bookings`.
 */
export const syncArtistBookedSlotsOnBooking = onDocumentWritten(
  'bookings/{bookingId}',
  async (event) => {
    const beforeArtist = String(event.data?.before?.data()?.artistId || '').trim();
    const afterArtist = String(event.data?.after?.data()?.artistId || '').trim();
    const targetArtists = new Set<string>(
      [beforeArtist, afterArtist].filter((id) => id.length > 0)
    );
    if (targetArtists.size === 0) return;

    await Promise.all(
      Array.from(targetArtists).map((artistId) =>
        recomputeArtistBookedSlots(artistId)
      )
    );
  }
);
