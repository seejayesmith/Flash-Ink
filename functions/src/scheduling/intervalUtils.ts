import { HttpsError } from 'firebase-functions/v2/https';
import { admin } from '../firebase';

export const DEFAULT_FALLBACK_DURATION_MINUTES = 120;
export const DEFAULT_FALLBACK_BUFFER_MINUTES = 60;

export interface IntervalSlotRecord {
  date: string;
  time: string;
  startMinutes: number;
  durationMinutes: number;
  bufferMinutes: number;
  endMinutes: number;
  holdId?: string;
  expiresAt?: string;
}

/**
 * Half-open interval overlap check: `[aStart, aEnd)` overlaps `[bStart, bEnd)`
 * iff `aStart < bEnd && bStart < aEnd`.
 */
export function intervalsOverlap(
  aStart: number,
  aEnd: number,
  bStart: number,
  bEnd: number
): boolean {
  return aStart < bEnd && bStart < aEnd;
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

/**
 * Parses labels like `"10:00 AM"`, `"1:30 PM"`, or `"14:00"` into minutes since midnight.
 */
export function parseTimeLabelToMinutes(raw: unknown): number | null {
  const cleaned = String(raw || '').split('(')[0].trim().toUpperCase();
  if (!cleaned) return null;

  const amPmMatch = cleaned.match(/^(\d{1,2}):(\d{2})\s*(AM|PM)$/);
  if (amPmMatch) {
    let hour = parseInt(amPmMatch[1], 10);
    const minute = parseInt(amPmMatch[2], 10);
    const period = amPmMatch[3];
    if (Number.isNaN(hour) || Number.isNaN(minute)) return null;
    if (period === 'PM' && hour !== 12) hour += 12;
    if (period === 'AM' && hour === 12) hour = 0;
    return Math.max(0, Math.min(1439, hour * 60 + minute));
  }

  const twentyFourMatch = cleaned.match(/^(\d{1,2}):(\d{2})$/);
  if (twentyFourMatch) {
    const hour = parseInt(twentyFourMatch[1], 10);
    const minute = parseInt(twentyFourMatch[2], 10);
    if (Number.isNaN(hour) || Number.isNaN(minute)) return null;
    return Math.max(0, Math.min(1439, hour * 60 + minute));
  }

  return null;
}

/**
 * Formats minutes since midnight (e.g., `600`) into `"10:00 AM"`.
 */
export function formatMinutesToTimeLabel(totalMinutes: number): string {
  const clamped = Math.max(0, Math.min(1439, Math.floor(totalMinutes)));
  const hour24 = Math.floor(clamped / 60);
  const minute = clamped % 60;
  const period = hour24 >= 12 ? 'PM' : 'AM';
  const hour12 = hour24 % 12 === 0 ? 12 : hour24 % 12;
  const minuteStr = String(minute).padStart(2, '0');
  return `${hour12}:${minuteStr} ${period}`;
}

/**
 * Parses human duration strings like `"1.5 hrs"`, `"3 hrs"`, `"90 mins"` into minutes.
 */
export function parseDurationStringMinutes(
  raw: unknown,
  fallbackMinutes: number = DEFAULT_FALLBACK_DURATION_MINUTES
): number {
  if (typeof raw === 'number' && Number.isFinite(raw) && raw > 0) {
    return Math.max(15, Math.min(720, Math.round(raw)));
  }
  const lower = String(raw || '').trim().toLowerCase();
  if (!lower) return fallbackMinutes;
  const match = lower.match(/(\d+(?:\.\d+)?)/);
  if (!match) return fallbackMinutes;
  const val = parseFloat(match[1]);
  if (Number.isNaN(val) || val <= 0) return fallbackMinutes;
  if (lower.includes('min')) {
    return Math.max(15, Math.min(720, Math.round(val)));
  }
  return Math.max(15, Math.min(720, Math.round(val * 60)));
}

/**
 * Converts a Firestore `bookedSlots` or `heldSlots` item (including legacy `{date, time}`
 * entries) into a normalized half-open `[startMinutes, endMinutes)` interval record.
 */
export function toIntervalSlotRecord(
  raw: unknown,
  fallbackDuration: number = DEFAULT_FALLBACK_DURATION_MINUTES,
  fallbackBuffer: number = DEFAULT_FALLBACK_BUFFER_MINUTES
): IntervalSlotRecord | null {
  if (!raw || typeof raw !== 'object') return null;
  const rec = raw as Record<string, unknown>;
  const date = extractDateKey(rec.date ?? rec.dateKey);
  if (!date) return null;

  const rawTime = String(rec.time ?? rec.timeSlot ?? '').split('(')[0].trim();
  const parsedStart =
    typeof rec.startMinutes === 'number' && Number.isFinite(rec.startMinutes)
      ? Math.floor(rec.startMinutes)
      : parseTimeLabelToMinutes(rawTime);
  if (parsedStart === null) return null;

  const durationMinutes =
    typeof rec.durationMinutes === 'number' && rec.durationMinutes > 0
      ? Math.floor(rec.durationMinutes)
      : fallbackDuration;
  const bufferMinutes =
    typeof rec.bufferMinutes === 'number' && rec.bufferMinutes >= 0
      ? Math.floor(rec.bufferMinutes)
      : fallbackBuffer;
  const endMinutes =
    typeof rec.endMinutes === 'number' && rec.endMinutes > parsedStart
      ? Math.floor(rec.endMinutes)
      : parsedStart + durationMinutes + bufferMinutes;

  const holdId =
    typeof rec.holdId === 'string' && rec.holdId.trim().length > 0
      ? rec.holdId.trim()
      : undefined;
  const expiresAt =
    typeof rec.expiresAt === 'string' && rec.expiresAt.trim().length > 0
      ? rec.expiresAt.trim()
      : undefined;

  return {
    date,
    time: rawTime || formatMinutesToTimeLabel(parsedStart),
    startMinutes: parsedStart,
    durationMinutes,
    bufferMinutes,
    endMinutes,
    ...(holdId ? { holdId } : {}),
    ...(expiresAt ? { expiresAt } : {}),
  };
}

export function throwTimeSlotConflict(message: string): never {
  throw new HttpsError('already-exists', message, {
    code: 'TIME_SLOT_CONFLICT',
  });
}

/**
 * Asserts that `[candidateStartMinutes, candidateStartMinutes + durationMinutes + bufferMinutes)`
 * fits within the artist's open schedule and does not overlap any `bookedSlots`
 * or unexpired `heldSlots` (ignoring `ignoreHoldId` when supplied).
 */
export function assertIntervalIsAvailable(params: {
  scheduleData?: Record<string, unknown>;
  dateKey: string;
  candidateStartMinutes: number;
  durationMinutes: number;
  bufferMinutes: number;
  nowMs?: number;
  ignoreHoldId?: string;
  requireBufferBeforeClose?: boolean;
  isTouchUp?: boolean;
}): void {
  const {
    scheduleData,
    dateKey,
    candidateStartMinutes,
    durationMinutes,
    bufferMinutes,
    nowMs = Date.now(),
    ignoreHoldId,
    requireBufferBeforeClose = false,
    isTouchUp = false,
  } = params;

  if (!scheduleData) return;

  if (isTouchUp) {
    if (scheduleData.acceptTouchUps === false) {
      throw new HttpsError(
        'failed-precondition',
        'This artist is not currently accepting self-booked touch-ups.'
      );
    }
  } else if (scheduleData.isBooksOpen === false) {
    throw new HttpsError(
      'failed-precondition',
      "This artist's books are currently closed."
    );
  }

  const blockedDates = Array.isArray(scheduleData.blockedDates)
    ? scheduleData.blockedDates.map((d) => String(d).trim())
    : [];
  if (blockedDates.includes(dateKey)) {
    throw new HttpsError(
      'failed-precondition',
      'The selected date is unavailable.'
    );
  }

  const sessionEnd = candidateStartMinutes + durationMinutes;
  const blockedEnd = sessionEnd + bufferMinutes;

  if (
    typeof scheduleData.startHour === 'number' &&
    typeof scheduleData.endHour === 'number'
  ) {
    const dayStart =
      Math.floor(scheduleData.startHour) * 60 +
      (typeof scheduleData.startMinute === 'number'
        ? Math.floor(scheduleData.startMinute)
        : 0);
    const dayEnd =
      Math.floor(scheduleData.endHour) * 60 +
      (typeof scheduleData.endMinute === 'number'
        ? Math.floor(scheduleData.endMinute)
        : 0);
    const requiredEnd = requireBufferBeforeClose ? blockedEnd : sessionEnd;
    if (dayEnd > dayStart && (candidateStartMinutes < dayStart || requiredEnd > dayEnd)) {
      throw new HttpsError(
        'failed-precondition',
        'Selected appointment duration extends past the artist’s closing time.'
      );
    }
  }

  const fallbackDuration =
    typeof scheduleData.slotDurationMinutes === 'number' &&
    scheduleData.slotDurationMinutes > 0
      ? Math.floor(scheduleData.slotDurationMinutes)
      : DEFAULT_FALLBACK_DURATION_MINUTES;
  const fallbackBuffer =
    typeof scheduleData.bufferDurationMinutes === 'number' &&
    scheduleData.bufferDurationMinutes >= 0
      ? Math.floor(scheduleData.bufferDurationMinutes)
      : DEFAULT_FALLBACK_BUFFER_MINUTES;

  const bookedSlots = Array.isArray(scheduleData.bookedSlots)
    ? scheduleData.bookedSlots
    : [];
  for (const rawEntry of bookedSlots) {
    const rec = toIntervalSlotRecord(rawEntry, fallbackDuration, fallbackBuffer);
    if (!rec || rec.date !== dateKey) continue;
    if (intervalsOverlap(candidateStartMinutes, blockedEnd, rec.startMinutes, rec.endMinutes)) {
      throwTimeSlotConflict(
        'TIME_SLOT_CONFLICT: This time slot overlaps an existing booking. Please select another available time.'
      );
    }
  }

  const cleanIgnoreHold = (ignoreHoldId || '').trim();
  const heldSlots = Array.isArray(scheduleData.heldSlots)
    ? scheduleData.heldSlots
    : [];
  for (const rawEntry of heldSlots) {
    const rec = toIntervalSlotRecord(rawEntry, fallbackDuration, fallbackBuffer);
    if (!rec || rec.date !== dateKey) continue;
    if (cleanIgnoreHold && rec.holdId === cleanIgnoreHold) continue;
    const expMs = rec.expiresAt
      ? Date.parse(rec.expiresAt)
      : Number.POSITIVE_INFINITY;
    const isUnexpired = Number.isNaN(expMs) || expMs > nowMs;
    if (!isUnexpired) continue;
    if (intervalsOverlap(candidateStartMinutes, blockedEnd, rec.startMinutes, rec.endMinutes)) {
      throwTimeSlotConflict(
        'TIME_SLOT_CONFLICT: This time slot overlaps an active 24-hour hold. Please select another available time.'
      );
    }
  }
}
