import { HttpsError } from 'firebase-functions/v2/https';
import { onDocumentWritten } from 'firebase-functions/v2/firestore';
import { admin, db } from './firebase';

interface AnonymizedSlotEntry {
  date: string;
  time: string;
}

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

/**
 * Extracts `YYYY-MM-DD` directly from an ISO-8601 timestamp string or Firestore
 * Timestamp without timezone day-shift side effects.
 */
export function extractDateKey(raw: unknown): string | null {
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

export function normalizeSlotLabel(raw: unknown): string {
  return String(raw || '').split('(')[0].trim().toUpperCase();
}

/**
 * Validates that the requested artist booking slot is still open and not
 * already booked, held, blocked, or closed before creating a PaymentIntent.
 */
export async function assertSlotIsAvailable(
  artistIdRaw: unknown,
  selectedDateRaw: unknown,
  selectedTimeSlotRaw: unknown,
  currentBookingIdRaw?: unknown,
  clientUidRaw?: unknown
): Promise<void> {
  const artistId = typeof artistIdRaw === 'string' ? artistIdRaw.trim() : '';
  const dateKey = extractDateKey(selectedDateRaw);
  const normalizedSlot = normalizeSlotLabel(selectedTimeSlotRaw);
  const currentBookingId =
    typeof currentBookingIdRaw === 'string' ? currentBookingIdRaw.trim() : '';
  const clientUid =
    typeof clientUidRaw === 'string' ? clientUidRaw.trim() : '';

  if (!artistId || !dateKey || !normalizedSlot) {
    return;
  }

  // Check active 10-minute checkout lock for this slot first.
  const slotLockId = buildSlotLockId(artistId, dateKey, normalizedSlot);
  const lockSnap = await db.collection(CHECKOUT_LOCKS_COLLECTION).doc(slotLockId).get();
  if (lockSnap.exists) {
    const lockData = (lockSnap.data() || {}) as Record<string, unknown>;
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
    if (expiresAtMs > Date.now() && !isSameHolder) {
      throw new HttpsError(
        'already-exists',
        'Another collector is currently checking out this time slot. Please try again in a few minutes or choose another slot.'
      );
    }
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
