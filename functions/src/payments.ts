import { defineSecret } from 'firebase-functions/params';
import { onCall, HttpsError, onRequest } from 'firebase-functions/v2/https';
import Stripe from 'stripe';
import { admin, db } from './firebase';
import { assertSlotIsAvailable } from './schedule';

const stripeSecretKey = defineSecret('STRIPE_SECRET_KEY');

const getStripeClient = (): Stripe => {
  const secretKey = stripeSecretKey.value() || process.env.STRIPE_SECRET_KEY || '';
  return new Stripe(secretKey, {
    apiVersion: '2025-02-24.acacia',
  });
};

/**
 * Callable Cloud Function: Create Stripe PaymentIntent for Flash Deposit
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
 * Stripe Connect Webhook: Verify Artist Payout Account & Lock Deposit Escrow
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

        await db
          .collection('artists')
          .doc(uid)
          .collection('private')
          .doc('financials')
          .set(
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
  }
);
