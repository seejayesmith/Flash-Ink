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
    verifiedArtist: true,
  });

  const batch = db.batch();

  // 2. Update the user's own account record (server-authoritative role)
  const userRef = db.collection('users').doc(uid);
  batch.set(
    userRef,
    {
      uid,
      displayName: artistName,
      role: 'artist',
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
