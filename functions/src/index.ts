import * as crypto from 'crypto';
import * as admin from 'firebase-admin';
import { onCall, HttpsError, onRequest } from 'firebase-functions/v2/https';
import Stripe from 'stripe';

admin.initializeApp();
const db = admin.firestore();

const getStripeClient = (): Stripe => {
  const secretKey = process.env.STRIPE_SECRET_KEY || '';
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
 * 2. Stripe Connect Webhook: Verify Artist Payout Account & Lock Deposit Escrow
 *
 * Handles:
 * - `account.updated`: Confirms Stripe Connect onboarding and records `stripeAccountId`
 *   inside the isolated `artists/{uid}/private/financials` subcollection.
 * - `payment_intent.succeeded`: Transitions booking status to `deposit_confirmed`
 *   and provisions the deposit-gated direct message thread (`chats/{threadId}`).
 */
export const stripeConnectWebhook = onRequest(async (req, res) => {
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
