import { onDocumentWritten } from 'firebase-functions/v2/firestore';
import { admin, db } from './firebase';
import {
  assertIntervalIsAvailable,
  DEFAULT_FALLBACK_BUFFER_MINUTES,
  DEFAULT_FALLBACK_DURATION_MINUTES,
  extractDateKey,
  formatMinutesToTimeLabel,
  IntervalSlotRecord,
  intervalsOverlap,
  parseDurationStringMinutes,
  parseTimeLabelToMinutes,
  throwTimeSlotConflict,
} from './scheduling/intervalUtils';

export { extractDateKey };

const EXCLUDED_APPOINTMENT_STATUSES = new Set([
  'cancelled',
  'canceled',
  'declined',
  'passed',
  'pending_payment',
  'payment_failed',
  'expired',
  'refunded',
]);

export const CHECKOUT_LOCKS_COLLECTION = 'checkout_locks';
export const CHECKOUT_LOCK_TTL_MS = 10 * 60 * 1000; // 10-minute checkout lock

function sanitizeLockSegment(raw: string): string {
  return raw
    .trim()
    .toUpperCase()
    .replace(/[^A-Z0-9_-]+/g, '_')
    .replace(/^_+|_+$/g, '');
}

export function buildSlotLockId(
  artistId: string,
  dateKey: string,
  normalizedSlot: string
): string {
  return `slot_${sanitizeLockSegment(artistId)}_${sanitizeLockSegment(dateKey)}_${sanitizeLockSegment(normalizedSlot)}`;
}

export function buildFlashLockId(artistId: string, flashId: string): string {
  return `flash_${sanitizeLockSegment(artistId)}_${sanitizeLockSegment(flashId)}`;
}

export function normalizeSlotLabel(raw: unknown): string {
  return String(raw || '').split('(')[0].trim().toUpperCase();
}

export interface SlotValidationOptions {
  startMinutes?: number;
  durationMinutes?: number;
  bufferMinutes?: number;
  ignoreHoldId?: string;
}

/**
 * Validates that the requested artist booking interval `[startMinutes, endMinutes)`
 * is open and does not overlap any existing booking, 24h hold, or 10-min checkout lock.
 */
export async function assertSlotIsAvailable(
  artistIdRaw: unknown,
  selectedDateRaw: unknown,
  selectedTimeSlotRaw: unknown,
  currentBookingIdRaw?: unknown,
  clientUidRaw?: unknown,
  options?: SlotValidationOptions
): Promise<void> {
  const artistId = typeof artistIdRaw === 'string' ? artistIdRaw.trim() : '';
  const dateKey = extractDateKey(selectedDateRaw);
  const normalizedSlot = normalizeSlotLabel(selectedTimeSlotRaw);
  const currentBookingId =
    typeof currentBookingIdRaw === 'string' ? currentBookingIdRaw.trim() : '';
  const clientUid =
    typeof clientUidRaw === 'string' ? clientUidRaw.trim() : '';

  if (!artistId || !dateKey || (!normalizedSlot && typeof options?.startMinutes !== 'number')) {
    return;
  }

  const scheduleSnap = await db.collection('artist_schedules').doc(artistId).get();
  const scheduleData = scheduleSnap.exists
    ? ((scheduleSnap.data() || {}) as Record<string, unknown>)
    : undefined;

  const defaultDuration =
    scheduleData &&
    typeof scheduleData.slotDurationMinutes === 'number' &&
    scheduleData.slotDurationMinutes > 0
      ? Math.floor(scheduleData.slotDurationMinutes)
      : DEFAULT_FALLBACK_DURATION_MINUTES;
  const defaultBuffer =
    scheduleData &&
    typeof scheduleData.bufferDurationMinutes === 'number' &&
    scheduleData.bufferDurationMinutes >= 0
      ? Math.floor(scheduleData.bufferDurationMinutes)
      : DEFAULT_FALLBACK_BUFFER_MINUTES;

  const candidateStart =
    typeof options?.startMinutes === 'number' && Number.isFinite(options.startMinutes)
      ? Math.floor(options.startMinutes)
      : parseTimeLabelToMinutes(normalizedSlot);
  if (candidateStart === null) {
    return;
  }

  const durationMinutes =
    typeof options?.durationMinutes === 'number' && options.durationMinutes > 0
      ? Math.floor(options.durationMinutes)
      : defaultDuration;
  const bufferMinutes =
    typeof options?.bufferMinutes === 'number' && options.bufferMinutes >= 0
      ? Math.floor(options.bufferMinutes)
      : defaultBuffer;
  const candidateEnd = candidateStart + durationMinutes + bufferMinutes;
  const nowMs = Date.now();

  // 1. Validate against `artist_schedules/{artistId}` (working hours, blockedDates, bookedSlots, heldSlots).
  assertIntervalIsAvailable({
    scheduleData,
    dateKey,
    candidateStartMinutes: candidateStart,
    durationMinutes,
    bufferMinutes,
    nowMs,
    ignoreHoldId: options?.ignoreHoldId,
  });

  // 2. Check active 10-minute checkout locks on the same artist + date for interval overlap.
  const locksSnap = await db
    .collection(CHECKOUT_LOCKS_COLLECTION)
    .where('artistId', '==', artistId)
    .get();
  for (const lockDoc of locksSnap.docs) {
    const lockData = lockDoc.data() as Record<string, unknown>;
    if (String(lockData.lockType || '') !== 'slot') continue;
    if (String(lockData.dateKey || '').trim() !== dateKey) continue;

    const expiresAtMs =
      lockData.expiresAt instanceof admin.firestore.Timestamp
        ? lockData.expiresAt.toMillis()
        : typeof lockData.expiresAt === 'string'
          ? Date.parse(lockData.expiresAt)
          : 0;
    const holderUid = String(lockData.holderClientId || '').trim();
    const lockBookingId = String(lockData.bookingId || '').trim();
    const isSameHolder =
      (clientUid.length > 0 && holderUid === clientUid) ||
      (currentBookingId.length > 0 && lockBookingId === currentBookingId);
    if (expiresAtMs <= nowMs || isSameHolder) continue;

    const lockStart =
      typeof lockData.startMinutes === 'number'
        ? Math.floor(lockData.startMinutes)
        : parseTimeLabelToMinutes(lockData.timeSlot);
    if (lockStart === null) continue;
    const lockDuration =
      typeof lockData.durationMinutes === 'number' && lockData.durationMinutes > 0
        ? Math.floor(lockData.durationMinutes)
        : defaultDuration;
    const lockBuffer =
      typeof lockData.bufferMinutes === 'number' && lockData.bufferMinutes >= 0
        ? Math.floor(lockData.bufferMinutes)
        : defaultBuffer;
    const lockEnd =
      typeof lockData.endMinutes === 'number' && lockData.endMinutes > lockStart
        ? Math.floor(lockData.endMinutes)
        : lockStart + lockDuration + lockBuffer;

    if (intervalsOverlap(candidateStart, candidateEnd, lockStart, lockEnd)) {
      throwTimeSlotConflict(
        'TIME_SLOT_CONFLICT: Another collector is currently checking out an overlapping time slot. Please try again in a few minutes or choose another slot.'
      );
    }
  }

  // 3. Cross-check `/appointments` and `/bookings` directly for interval overlaps.
  const [aptSnap, bookingSnap] = await Promise.all([
    db.collection('appointments').where('artistId', '==', artistId).get(),
    db.collection('bookings').where('artistId', '==', artistId).get(),
  ]);

  for (const doc of aptSnap.docs) {
    const docData = doc.data();
    const status = String(docData.status || 'confirmed').trim().toLowerCase();
    if (EXCLUDED_APPOINTMENT_STATUSES.has(status)) continue;
    const docDate = extractDateKey(docData.scheduledDate);
    if (docDate !== dateKey) continue;

    const docStart =
      typeof docData.startMinutes === 'number'
        ? Math.floor(docData.startMinutes)
        : parseTimeLabelToMinutes(docData.time);
    if (docStart === null) continue;
    const docDuration =
      typeof docData.durationMinutes === 'number' && docData.durationMinutes > 0
        ? Math.floor(docData.durationMinutes)
        : parseDurationStringMinutes(docData.duration, defaultDuration);
    const docBuffer =
      typeof docData.bufferMinutes === 'number' && docData.bufferMinutes >= 0
        ? Math.floor(docData.bufferMinutes)
        : defaultBuffer;
    const docEnd =
      typeof docData.endMinutes === 'number' && docData.endMinutes > docStart
        ? Math.floor(docData.endMinutes)
        : docStart + docDuration + docBuffer;

    if (intervalsOverlap(candidateStart, candidateEnd, docStart, docEnd)) {
      throwTimeSlotConflict(
        'TIME_SLOT_CONFLICT: This time slot overlaps an existing booking. Please select another time slot.'
      );
    }
  }

  for (const doc of bookingSnap.docs) {
    if (currentBookingId && doc.id === currentBookingId) continue;
    const docData = doc.data();
    const status = String(docData.status || 'pending').trim().toLowerCase();
    if (EXCLUDED_APPOINTMENT_STATUSES.has(status)) continue;
    const docDate = extractDateKey(docData.selectedDate);
    if (docDate !== dateKey) continue;

    const docStart =
      typeof docData.startMinutes === 'number'
        ? Math.floor(docData.startMinutes)
        : parseTimeLabelToMinutes(docData.selectedTimeSlot);
    if (docStart === null) continue;
    const docDuration =
      typeof docData.durationMinutes === 'number' && docData.durationMinutes > 0
        ? Math.floor(docData.durationMinutes)
        : parseDurationStringMinutes(
            docData.duration ?? docData.estimatedTime,
            defaultDuration
          );
    const docBuffer =
      typeof docData.bufferMinutes === 'number' && docData.bufferMinutes >= 0
        ? Math.floor(docData.bufferMinutes)
        : defaultBuffer;
    const docEnd =
      typeof docData.endMinutes === 'number' && docData.endMinutes > docStart
        ? Math.floor(docData.endMinutes)
        : docStart + docDuration + docBuffer;

    if (intervalsOverlap(candidateStart, candidateEnd, docStart, docEnd)) {
      throwTimeSlotConflict(
        'TIME_SLOT_CONFLICT: This time slot overlaps an existing booking. Please select another time slot.'
      );
    }
  }
}

/**
 * Recomputes anonymized `bookedSlots` (`[{date, time, startMinutes, durationMinutes, bufferMinutes, endMinutes}]`)
 * for an artist from `/appointments` and `/bookings` without exposing any client PII.
 */
async function recomputeArtistBookedSlots(artistId: string): Promise<void> {
  const cleanArtistId = artistId.trim();
  if (!cleanArtistId) return;

  // Keep the trailing 7 days so appointments earlier in the current Sun–Sat week
  // remain counted against maxWorkingDaysPerWeek.
  const cutoffDate = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
  const cutoffKey = cutoffDate.toISOString().slice(0, 10);

  const [scheduleSnap, aptSnap, bookingSnap] = await Promise.all([
    db.collection('artist_schedules').doc(cleanArtistId).get(),
    db.collection('appointments').where('artistId', '==', cleanArtistId).get(),
    db.collection('bookings').where('artistId', '==', cleanArtistId).get(),
  ]);

  const scheduleData = scheduleSnap.exists
    ? ((scheduleSnap.data() || {}) as Record<string, unknown>)
    : undefined;
  const fallbackDuration =
    scheduleData &&
    typeof scheduleData.slotDurationMinutes === 'number' &&
    scheduleData.slotDurationMinutes > 0
      ? Math.floor(scheduleData.slotDurationMinutes)
      : DEFAULT_FALLBACK_DURATION_MINUTES;
  const fallbackBuffer =
    scheduleData &&
    typeof scheduleData.bufferDurationMinutes === 'number' &&
    scheduleData.bufferDurationMinutes >= 0
      ? Math.floor(scheduleData.bufferDurationMinutes)
      : DEFAULT_FALLBACK_BUFFER_MINUTES;

  const deduped = new Map<string, IntervalSlotRecord>();
  const addSlot = (params: {
    dateRaw: unknown;
    timeRaw: unknown;
    statusRaw: unknown;
    defaultStatus: string;
    startMinutesRaw?: unknown;
    durationMinutesRaw?: unknown;
    durationLabelRaw?: unknown;
    bufferMinutesRaw?: unknown;
  }) => {
    const status = String(params.statusRaw || params.defaultStatus)
      .trim()
      .toLowerCase();
    if (EXCLUDED_APPOINTMENT_STATUSES.has(status)) return;

    const dateKey = extractDateKey(params.dateRaw);
    if (!dateKey || dateKey < cutoffKey) return;

    const rawTime = String(params.timeRaw || '').split('(')[0].trim();
    const startMinutes =
      typeof params.startMinutesRaw === 'number' &&
      Number.isFinite(params.startMinutesRaw)
        ? Math.floor(params.startMinutesRaw)
        : parseTimeLabelToMinutes(rawTime);
    if (startMinutes === null) return;

    const durationMinutes =
      typeof params.durationMinutesRaw === 'number' &&
      params.durationMinutesRaw > 0
        ? Math.floor(params.durationMinutesRaw)
        : parseDurationStringMinutes(params.durationLabelRaw, fallbackDuration);
    const bufferMinutes =
      typeof params.bufferMinutesRaw === 'number' && params.bufferMinutesRaw >= 0
        ? Math.floor(params.bufferMinutesRaw)
        : fallbackBuffer;
    const endMinutes = startMinutes + durationMinutes + bufferMinutes;
    const formattedTime = rawTime || formatMinutesToTimeLabel(startMinutes);

    const mapKey = `${dateKey}__${startMinutes}__${endMinutes}`;
    if (!deduped.has(mapKey)) {
      deduped.set(mapKey, {
        date: dateKey,
        time: formattedTime,
        startMinutes,
        durationMinutes,
        bufferMinutes,
        endMinutes,
      });
    }
  };

  for (const doc of aptSnap.docs) {
    const data = doc.data();
    addSlot({
      dateRaw: data.scheduledDate,
      timeRaw: data.time,
      statusRaw: data.status,
      defaultStatus: 'confirmed',
      startMinutesRaw: data.startMinutes,
      durationMinutesRaw: data.durationMinutes,
      durationLabelRaw: data.duration,
      bufferMinutesRaw: data.bufferMinutes,
    });
  }

  for (const doc of bookingSnap.docs) {
    const data = doc.data();
    addSlot({
      dateRaw: data.selectedDate,
      timeRaw: data.selectedTimeSlot,
      statusRaw: data.status,
      defaultStatus: 'pending',
      startMinutesRaw: data.startMinutes,
      durationMinutesRaw: data.durationMinutes,
      durationLabelRaw: data.duration ?? data.estimatedTime,
      bufferMinutesRaw: data.bufferMinutes,
    });
  }

  const bookedSlots = Array.from(deduped.values()).sort((a, b) =>
    a.date === b.date
      ? a.startMinutes - b.startMinutes
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

async function syncBookedSlotsForChangedArtists(
  beforeData?: admin.firestore.DocumentData,
  afterData?: admin.firestore.DocumentData
): Promise<void> {
  const beforeArtist = String(beforeData?.artistId || '').trim();
  const afterArtist = String(afterData?.artistId || '').trim();
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

/**
 * Firestore Trigger: Sync Anonymized Booked Slots on Appointment Write
 *
 * Keeps `artist_schedules/{artistId}.bookedSlots` up to date on create,
 * reschedule, cancel, or deletion without exposing private `/appointments` PII.
 */
export const syncArtistBookedSlotsOnAppointment = onDocumentWritten(
  'appointments/{appointmentId}',
  async (event) => {
    await syncBookedSlotsForChangedArtists(
      event.data?.before?.data(),
      event.data?.after?.data()
    );
  }
);

/**
 * Firestore Trigger: Sync Anonymized Booked Slots on Booking Write
 *
 * Keeps `artist_schedules/{artistId}.bookedSlots` up to date whenever a client
 * creates or updates a flash booking document in `/bookings`.
 */
export const syncArtistBookedSlotsOnBooking = onDocumentWritten(
  'bookings/{bookingId}',
  async (event) => {
    await syncBookedSlotsForChangedArtists(
      event.data?.before?.data(),
      event.data?.after?.data()
    );
  }
);
