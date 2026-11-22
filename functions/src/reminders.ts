import { onSchedule } from 'firebase-functions/v2/scheduler';
import { admin, db } from './firebase';

interface PendingWrite {
  ref: admin.firestore.DocumentReference;
  data: Record<string, unknown>;
  merge: boolean;
}

function enqueueReminderPair(
  pendingWrites: PendingWrite[],
  params: {
    aptId: string;
    aptRef: admin.firestore.DocumentReference;
    clientId: string;
    artistId: string;
    prefix: 'notif_rem24' | 'notif_rem2';
    title: string;
    clientBody: string;
    artistBody: string;
    sentFlagField: 'reminder24hSent' | 'reminder2hSent';
    nowIso: string;
  }
): void {
  const {
    aptId,
    aptRef,
    clientId,
    artistId,
    prefix,
    title,
    clientBody,
    artistBody,
    sentFlagField,
    nowIso,
  } = params;

  if (clientId) {
    const notifId = `${prefix}_client_${aptId}`;
    pendingWrites.push({
      ref: db.collection('notifications').doc(notifId),
      data: {
        id: notifId,
        senderId: artistId || clientId,
        recipientId: clientId,
        category: 'client_reminder',
        type: 'client_reminder',
        title,
        body: clientBody,
        message: clientBody,
        appointmentId: aptId,
        createdAt: nowIso,
      },
      merge: true,
    });
  }

  if (artistId) {
    const notifId = `${prefix}_artist_${aptId}`;
    pendingWrites.push({
      ref: db.collection('notifications').doc(notifId),
      data: {
        id: notifId,
        senderId: clientId || artistId,
        recipientId: artistId,
        category: 'artist_reminder',
        type: 'artist_reminder',
        title,
        body: artistBody,
        message: artistBody,
        appointmentId: aptId,
        createdAt: nowIso,
      },
      merge: true,
    });
  }

  pendingWrites.push({
    ref: aptRef,
    data: { [sentFlagField]: true },
    merge: true,
  });
}

/**
 * Scheduled Function: Automated 24h & 2h Appointment Reminders
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
    const pendingWrites: PendingWrite[] = [];

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

      if (hoursUntil > 2 && hoursUntil <= 24 && data.reminder24hSent !== true) {
        enqueueReminderPair(pendingWrites, {
          aptId: doc.id,
          aptRef: doc.ref,
          clientId,
          artistId,
          prefix: 'notif_rem24',
          title: 'Upcoming Session Tomorrow',
          clientBody: `Your ${serviceType} session is coming up${dateLabel}${timeLabel}.`,
          artistBody: `${serviceType} with ${clientName} is scheduled${dateLabel}${timeLabel}.`,
          sentFlagField: 'reminder24hSent',
          nowIso,
        });
      } else if (
        hoursUntil > 0 &&
        hoursUntil <= 2 &&
        data.reminder2hSent !== true
      ) {
        enqueueReminderPair(pendingWrites, {
          aptId: doc.id,
          aptRef: doc.ref,
          clientId,
          artistId,
          prefix: 'notif_rem2',
          title: 'Session Starting in 2 Hours',
          clientBody: `Your ${serviceType} session begins soon${timeLabel}.`,
          artistBody: `${serviceType} with ${clientName} begins soon${timeLabel}.`,
          sentFlagField: 'reminder2hSent',
          nowIso,
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
