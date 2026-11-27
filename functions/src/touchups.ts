import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { admin, db } from './firebase';
import {
  assertSlotIsAvailable,
  buildSlotLockId,
  CHECKOUT_LOCKS_COLLECTION,
  extractDateKey,
  normalizeSlotLabel,
} from './schedule';
import {
  assertIntervalIsAvailable,
  parseTimeLabelToMinutes,
  throwTimeSlotConflict,
} from './scheduling/intervalUtils';

export const TOUCH_UP_MIN_HEALING_DAYS = 7;
export const DEFAULT_TOUCH_UP_DURATION_MINUTES = 30;
export const DEFAULT_TOUCH_UP_BUFFER_MINUTES = 30;
export const DEFAULT_TOUCH_UP_WINDOW_MONTHS = 6;

const CANCELLED_STATUSES = new Set([
  'cancelled',
  'canceled',
  'declined',
  'passed',
  'payment_failed',
  'expired',
  'refunded',
]);

function readTimestampMs(raw: unknown): number | null {
  if (raw instanceof admin.firestore.Timestamp) {
    return raw.toMillis();
  }
  if (typeof raw === 'string' && raw.trim().length > 0) {
    const parsed = Date.parse(raw);
    return Number.isNaN(parsed) ? null : parsed;
  }
  return null;
}

export function addMonthsUtc(base: Date, months: number): Date {
  const year = base.getUTCFullYear();
  const month = base.getUTCMonth() + months;
  const day = base.getUTCDate();
  const targetYear = year + Math.floor(month / 12);
  const targetMonth = ((month % 12) + 12) % 12;
  const maxDay = new Date(Date.UTC(targetYear, targetMonth + 1, 0)).getUTCDate();
  return new Date(
    Date.UTC(
      targetYear,
      targetMonth,
      Math.min(day, maxDay),
      base.getUTCHours(),
      base.getUTCMinutes(),
      base.getUTCSeconds()
    )
  );
}

export function formatDurationLabel(minutes: number): string {
  if (minutes < 60) {
    return `${minutes} min`;
  }
  const hrs = minutes / 60;
  return Number.isInteger(hrs)
    ? `${hrs} ${hrs === 1 ? 'hr' : 'hrs'}`
    : `${hrs.toFixed(1)} hrs`;
}

export interface TouchUpEligibilityValidated {
  parentAppointmentId: string;
  parentTitle: string;
  parentPlacement: string;
  parentImageUrl: string;
  durationMinutes: number;
  bufferMinutes: number;
  windowMonths: number;
  feeDollars: number;
  artistData: Record<string, unknown>;
  scheduleData: Record<string, unknown>;
}

/**
 * Authoritatively validates whether [clientUid] may self-book a touch-up for
 * [parentAppointmentId] with [targetArtistId].
 *
 * Enforces:
 * - Artist `acceptTouchUps !== false` (independent of `isBooksOpen`)
 * - Parent appointment belongs to client & artist, is not itself a touch-up, and is completed/past
 * - Minimum 7-day healing wait after the original tattoo session
 * - Within artist's configured `touchUpWindowMonths` (default 6 months)
 * - Max 1 touch-up per original tattoo AND max 1 active upcoming touch-up with this artist
 */
export async function validateTouchUpEligibility(params: {
  clientUid: string;
  targetArtistId: string;
  parentAppointmentId: string;
  nowMs?: number;
}): Promise<TouchUpEligibilityValidated> {
  const { clientUid, targetArtistId, parentAppointmentId, nowMs = Date.now() } =
    params;

  if (clientUid === targetArtistId) {
    throw new HttpsError(
      'failed-precondition',
      'Artists cannot book touch-ups with themselves.'
    );
  }

  const [artistSnap, scheduleSnap, aptSnap, bookingSnap] = await Promise.all([
    db.collection('artists').doc(targetArtistId).get(),
    db.collection('artist_schedules').doc(targetArtistId).get(),
    db.collection('appointments').doc(parentAppointmentId).get(),
    db.collection('bookings').doc(parentAppointmentId).get(),
  ]);

  if (!artistSnap.exists) {
    throw new HttpsError('not-found', 'Artist profile could not be found.');
  }

  const artistData = (artistSnap.data() || {}) as Record<string, unknown>;
  const scheduleData = (
    scheduleSnap.exists
      ? scheduleSnap.data()
      : (artistData.booksSchedule as Record<string, unknown> | undefined) || {}
  ) as Record<string, unknown>;

  if (scheduleData.acceptTouchUps === false) {
    throw new HttpsError(
      'failed-precondition',
      'This artist is not currently accepting self-booked touch-ups. Please message them in chat.'
    );
  }

  const parentDoc = aptSnap.exists
    ? (aptSnap.data() as Record<string, unknown>)
    : bookingSnap.exists
      ? (bookingSnap.data() as Record<string, unknown>)
      : null;

  if (!parentDoc) {
    throw new HttpsError(
      'not-found',
      'Original tattoo appointment could not be found.'
    );
  }

  if (
    String(parentDoc.clientId || '').trim() !== clientUid ||
    String(parentDoc.artistId || '').trim() !== targetArtistId
  ) {
    throw new HttpsError(
      'permission-denied',
      'You are not authorized to book a touch-up for this appointment.'
    );
  }

  const parentStatus = String(parentDoc.status || '').trim().toLowerCase();
  if (CANCELLED_STATUSES.has(parentStatus) || parentStatus === 'pending_payment') {
    throw new HttpsError(
      'failed-precondition',
      'Touch-ups can only be booked for completed tattoo appointments.'
    );
  }

  if (
    parentDoc.isTouchUp === true ||
    String(parentDoc.visitType || '').toLowerCase().includes('touch')
  ) {
    throw new HttpsError(
      'failed-precondition',
      'Self-booked touch-ups must be linked to an original tattoo session. Please message the artist in chat.'
    );
  }

  const parentDateMs =
    readTimestampMs(parentDoc.scheduledDate) ??
    readTimestampMs(parentDoc.selectedDate) ??
    readTimestampMs(parentDoc.date);
  if (parentDateMs === null) {
    throw new HttpsError(
      'failed-precondition',
      'Original tattoo session date could not be verified.'
    );
  }

  const minUnlockMs =
    parentDateMs + TOUCH_UP_MIN_HEALING_DAYS * 24 * 60 * 60 * 1000;
  if (nowMs < minUnlockMs) {
    throw new HttpsError(
      'failed-precondition',
      'Touch-up booking unlocks 7 days after your original tattoo session so initial healing can begin.'
    );
  }

  const windowMonths =
    typeof scheduleData.touchUpWindowMonths === 'number' &&
    scheduleData.touchUpWindowMonths >= 1
      ? Math.min(36, Math.floor(scheduleData.touchUpWindowMonths))
      : DEFAULT_TOUCH_UP_WINDOW_MONTHS;

  const windowEndMs = addMonthsUtc(
    new Date(parentDateMs),
    windowMonths
  ).getTime();
  if (nowMs > windowEndMs) {
    throw new HttpsError(
      'failed-precondition',
      `Your ${windowMonths}-month self-booking touch-up window has passed. Please message the artist in chat to arrange a touch-up.`
    );
  }

  // Enforce 1 touch-up per original tattoo AND max 1 active upcoming touch-up with this artist.
  const [clientAptsSnap, clientBookingsSnap] = await Promise.all([
    db.collection('appointments').where('clientId', '==', clientUid).get(),
    db.collection('bookings').where('clientId', '==', clientUid).get(),
  ]);

  const checkExistingRecord = (rec: Record<string, unknown>) => {
    const status = String(rec.status || 'confirmed').trim().toLowerCase();
    if (CANCELLED_STATUSES.has(status) || status === 'pending_payment') return;
    const isRecTouchUp =
      rec.isTouchUp === true ||
      String(rec.visitType || '').toLowerCase().includes('touch');
    if (!isRecTouchUp) return;

    const recParentId = String(rec.parentAppointmentId || '').trim();
    if (recParentId && recParentId === parentAppointmentId) {
      throw new HttpsError(
        'already-exists',
        'A touch-up has already been booked for this tattoo. Please message the artist in chat if you need another.'
      );
    }

    const recArtistId = String(rec.artistId || '').trim();
    const recDateMs =
      readTimestampMs(rec.scheduledDate) ?? readTimestampMs(rec.selectedDate);
    const isUpcoming =
      status !== 'completed' && (recDateMs === null || recDateMs >= nowMs - 24 * 60 * 60 * 1000);
    if (recArtistId === targetArtistId && isUpcoming) {
      throw new HttpsError(
        'failed-precondition',
        'You already have an upcoming touch-up scheduled with this artist.'
      );
    }
  };

  for (const doc of clientAptsSnap.docs) {
    checkExistingRecord((doc.data() || {}) as Record<string, unknown>);
  }
  for (const doc of clientBookingsSnap.docs) {
    checkExistingRecord((doc.data() || {}) as Record<string, unknown>);
  }

  const durationMinutes =
    typeof scheduleData.touchUpDurationMinutes === 'number' &&
    scheduleData.touchUpDurationMinutes >= 15
      ? Math.min(720, Math.floor(scheduleData.touchUpDurationMinutes))
      : DEFAULT_TOUCH_UP_DURATION_MINUTES;
  const bufferMinutes =
    typeof scheduleData.touchUpBufferMinutes === 'number' &&
    scheduleData.touchUpBufferMinutes >= 0
      ? Math.min(240, Math.floor(scheduleData.touchUpBufferMinutes))
      : DEFAULT_TOUCH_UP_BUFFER_MINUTES;
  const feeDollars =
    typeof scheduleData.touchUpFeeDollars === 'number' &&
    scheduleData.touchUpFeeDollars > 0
      ? Math.min(10000, Math.round(scheduleData.touchUpFeeDollars))
      : 0;

  const parentTitle = String(
    parentDoc.flashTitle || parentDoc.serviceType || 'Original Tattoo'
  ).trim();
  const parentPlacement = String(parentDoc.placement || 'Forearm').trim();
  const parentImageUrl = String(
    parentDoc.artworkImageUrl || parentDoc.flashImageUrl || ''
  ).trim();

  return {
    parentAppointmentId,
    parentTitle,
    parentPlacement,
    parentImageUrl,
    durationMinutes,
    bufferMinutes,
    windowMonths,
    feeDollars,
    artistData,
    scheduleData,
  };
}

/**
 * Callable Cloud Function: Instant self-booking for a complimentary ($0) touch-up.
 *
 * Atomically verifies eligibility, checks interval availability (gating on
 * `acceptTouchUps` rather than `isBooksOpen`), creates `/bookings` and
 * `/appointments` records linked to `parentAppointmentId`, posts a receipt in
 * chat, and sends artist/client notifications.
 */
export const bookFreeTouchUp = onCall(async (request) => {
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError(
      'unauthenticated',
      'Please sign in to book a touch-up.'
    );
  }
  const signInProvider = request.auth.token?.firebase?.sign_in_provider;
  if (signInProvider === 'anonymous') {
    throw new HttpsError(
      'unauthenticated',
      'Please create or sign in to an account before booking a touch-up.'
    );
  }

  const clientUid = request.auth.uid;
  const data = (request.data || {}) as {
    artistId?: string;
    parentAppointmentId?: string;
    selectedDate?: string;
    selectedTimeSlot?: string;
    startMinutes?: number;
    clientNotes?: string;
    healedPhotoUrl?: string;
    threadId?: string;
    bookingId?: string;
  };

  const targetArtistId =
    typeof data.artistId === 'string' ? data.artistId.trim() : '';
  const parentAppointmentId =
    typeof data.parentAppointmentId === 'string'
      ? data.parentAppointmentId.trim()
      : '';
  if (!targetArtistId || !parentAppointmentId) {
    throw new HttpsError(
      'invalid-argument',
      'Both artistId and parentAppointmentId are required to book a touch-up.'
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
      'A valid touch-up date and time slot are required.'
    );
  }

  const nowMs = Date.now();
  const validated = await validateTouchUpEligibility({
    clientUid,
    targetArtistId,
    parentAppointmentId,
    nowMs,
  });

  if (validated.feeDollars > 0) {
    throw new HttpsError(
      'failed-precondition',
      `This artist requires a $${validated.feeDollars} touch-up fee. Please complete checkout to confirm.`
    );
  }

  const rawBookingId =
    typeof data.bookingId === 'string' ? data.bookingId.trim() : '';
  const bookingId = /^[A-Za-z0-9_-]{4,64}$/.test(rawBookingId)
    ? rawBookingId
    : `TU-${nowMs}`;

  const durationMinutes = validated.durationMinutes;
  const bufferMinutes = validated.bufferMinutes;
  const endMinutes = parsedStartMinutes + durationMinutes + bufferMinutes;
  const durationLabel = formatDurationLabel(durationMinutes);

  // Pre-check across schedule, locks, appointments, and bookings.
  await assertSlotIsAvailable(
    targetArtistId,
    dateKey,
    normalizedSlot,
    bookingId,
    clientUid,
    {
      startMinutes: parsedStartMinutes,
      durationMinutes,
      bufferMinutes,
      isTouchUp: true,
    }
  );

  const userSnap = await db.collection('users').doc(clientUid).get();
  const userData = (userSnap.exists ? userSnap.data() : {}) as Record<
    string,
    unknown
  >;

  const clientName = String(
    userData.displayName || userData.username || 'Client'
  ).trim();
  const clientAvatar = String(
    userData.photoUrl || userData.photoURL || userData.avatarUrl || ''
  ).trim();
  const artistName = String(
    validated.artistData.name || validated.artistData.displayName || 'Artist'
  ).trim();
  const artistAvatar = String(
    validated.artistData.avatarUrl || validated.artistData.photoUrl || ''
  ).trim();
  const studioName = String(
    validated.artistData.studioName ||
      validated.artistData.studioType ||
      'Studio'
  ).trim();
  const studioAddress = String(
    validated.scheduleData.locationNote || validated.artistData.location || ''
  ).trim();

  const healedPhotoUrl =
    typeof data.healedPhotoUrl === 'string' ? data.healedPhotoUrl.trim() : '';
  const clientNotes =
    typeof data.clientNotes === 'string' ? data.clientNotes.trim() : '';
  const touchUpTitle = `Touch-up: ${validated.parentTitle}`;
  const cleanThreadId =
    typeof data.threadId === 'string' && data.threadId.trim().length > 0
      ? data.threadId.trim()
      : `thread_booking_${bookingId}`;

  const slotLockId = buildSlotLockId(targetArtistId, dateKey, normalizedSlot);
  const scheduleRef = db.collection('artist_schedules').doc(targetArtistId);
  const slotLockRef = db.collection(CHECKOUT_LOCKS_COLLECTION).doc(slotLockId);
  const bookingRef = db.collection('bookings').doc(bookingId);
  const appointmentId = `cal_${bookingId}`;
  const appointmentRef = db.collection('appointments').doc(appointmentId);
  const threadRef = db.collection('chats').doc(cleanThreadId);
  const nowIso = new Date(nowMs).toISOString();
  const nowTimestamp = admin.firestore.Timestamp.fromMillis(nowMs);

  await db.runTransaction(async (tx) => {
    const [schedTxSnap, slotLockSnap] = await Promise.all([
      tx.get(scheduleRef),
      tx.get(slotLockRef),
    ]);

    if (schedTxSnap.exists) {
      assertIntervalIsAvailable({
        scheduleData: (schedTxSnap.data() || {}) as Record<string, unknown>,
        dateKey,
        candidateStartMinutes: parsedStartMinutes,
        durationMinutes,
        bufferMinutes,
        nowMs,
        isTouchUp: true,
      });
    }

    if (slotLockSnap.exists) {
      const lockData = (slotLockSnap.data() || {}) as Record<string, unknown>;
      const lockExp = readTimestampMs(lockData.expiresAt) ?? 0;
      const holder = String(lockData.holderClientId || '').trim();
      if (lockExp > nowMs && holder && holder !== clientUid) {
        throwTimeSlotConflict(
          'TIME_SLOT_CONFLICT: Another collector is currently checking out this time slot. Please pick another time.'
        );
      }
    }

    tx.set(
      bookingRef,
      {
        id: bookingId,
        bookingId,
        clientId: clientUid,
        artistId: targetArtistId,
        artistName,
        ...(artistAvatar ? { artistAvatar } : {}),
        studioName,
        studioLocation: studioAddress,
        isTouchUp: true,
        parentAppointmentId,
        parentTattooTitle: validated.parentTitle,
        flashTitle: touchUpTitle,
        flashImageUrl: healedPhotoUrl || validated.parentImageUrl,
        artworkImageUrl: validated.parentImageUrl,
        ...(healedPhotoUrl ? { healedPhotoUrl } : {}),
        estimatedTime: durationLabel,
        selectedDate: data.selectedDate || dateKey,
        selectedDateKey: dateKey,
        selectedTimeSlot: String(data.selectedTimeSlot || normalizedSlot).trim(),
        startMinutes: parsedStartMinutes,
        durationMinutes,
        bufferMinutes,
        endMinutes,
        placement: validated.parentPlacement,
        clientName,
        ...(clientAvatar ? { clientAvatar } : {}),
        ...(clientNotes ? { clientNotes } : {}),
        depositAmount: 0,
        totalAmount: 0,
        depositAmountCents: 0,
        totalPriceCents: 0,
        platformFeeCents: 0,
        totalChargeCents: 0,
        status: 'confirmed',
        escrowStatus: 'not_applicable',
        threadId: cleanThreadId,
        confirmedAt: nowTimestamp,
        createdAt: nowTimestamp,
        updatedAt: nowTimestamp,
      },
      { merge: true }
    );

    tx.set(
      appointmentRef,
      {
        id: appointmentId,
        bookingId,
        clientId: clientUid,
        artistId: targetArtistId,
        clientName,
        ...(clientAvatar ? { clientAvatar } : {}),
        artistName,
        ...(artistAvatar ? { artistAvatar } : {}),
        studioName,
        studioAddress,
        serviceType: touchUpTitle,
        flashTitle: touchUpTitle,
        visitType: 'Touch-up',
        isTouchUp: true,
        parentAppointmentId,
        parentTattooTitle: validated.parentTitle,
        duration: durationLabel,
        startMinutes: parsedStartMinutes,
        durationMinutes,
        bufferMinutes,
        endMinutes,
        time: String(data.selectedTimeSlot || normalizedSlot).trim(),
        scheduledDate: data.selectedDate || dateKey,
        date: dateKey,
        placement: validated.parentPlacement,
        notes: clientNotes,
        depositPaid: 0,
        fullPrice: 0,
        balanceDue: 0,
        artworkImageUrl: validated.parentImageUrl,
        ...(healedPhotoUrl ? { healedPhotoUrl } : {}),
        status: 'confirmed',
        escrowStatus: 'not_applicable',
        updatedAt: nowIso,
      },
      { merge: true }
    );

    tx.set(
      threadRef,
      {
        id: cleanThreadId,
        artistId: targetArtistId,
        clientId: clientUid,
        clientName,
        artistName,
        ...(clientAvatar ? { clientAvatar } : {}),
        ...(artistAvatar ? { artistAvatar } : {}),
        studioName,
        flashTitleContext: validated.parentTitle,
        participants: [clientUid, targetArtistId],
        depositConfirmed: true,
        status: 'active',
        lastMessage: `Touch-up booked for ${dateKey} at ${String(data.selectedTimeSlot || normalizedSlot).trim()} (Free)`,
        lastMessageTime: nowIso,
        updatedAt: nowTimestamp,
      },
      { merge: true }
    );

    const msgId = `msg_touchup_${bookingId}`;
    tx.set(threadRef.collection('messages').doc(msgId), {
      id: msgId,
      senderId: clientUid,
      senderName: clientName,
      text: `Complimentary touch-up booked for "${validated.parentTitle}" on ${dateKey} at ${String(data.selectedTimeSlot || normalizedSlot).trim()} (${durationLabel}).${clientNotes ? ` Note: ${clientNotes}` : ''}`,
      timestamp: nowIso,
      isFromArtist: false,
      type: 'receipt',
      receiptAmount: 0,
      appointmentDate: data.selectedDate || dateKey,
      flashImageUrl: healedPhotoUrl || validated.parentImageUrl,
    });

    const artistNotifId = `notif_touchup_artist_${bookingId}`;
    tx.set(
      db.collection('notifications').doc(artistNotifId),
      {
        id: artistNotifId,
        senderId: clientUid,
        recipientId: targetArtistId,
        category: 'touchup_booked',
        type: 'touchup_booked',
        title: 'Touch-up Session Booked',
        body: `${clientName} booked a complimentary touch-up for "${validated.parentTitle}" on ${dateKey} at ${String(data.selectedTimeSlot || normalizedSlot).trim()}.`,
        message: `${clientName} booked a touch-up for "${validated.parentTitle}".`,
        appointmentId,
        threadId: cleanThreadId,
        createdAt: nowIso,
      },
      { merge: true }
    );

    const clientNotifId = `notif_touchup_client_${bookingId}`;
    tx.set(
      db.collection('notifications').doc(clientNotifId),
      {
        id: clientNotifId,
        senderId: targetArtistId,
        recipientId: clientUid,
        category: 'touchup_booked',
        type: 'touchup_booked',
        title: 'Touch-up Confirmed!',
        body: `Your free touch-up for "${validated.parentTitle}" with ${artistName} is confirmed for ${dateKey} at ${String(data.selectedTimeSlot || normalizedSlot).trim()}.`,
        message: `Your touch-up for "${validated.parentTitle}" is confirmed.`,
        appointmentId,
        threadId: cleanThreadId,
        createdAt: nowIso,
      },
      { merge: true }
    );
  });

  return {
    bookingId,
    appointmentId,
    threadId: cleanThreadId,
    durationMinutes,
    bufferMinutes,
    status: 'confirmed',
  };
});
