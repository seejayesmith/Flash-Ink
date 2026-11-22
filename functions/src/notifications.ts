import {
  onDocumentCreated,
  onDocumentUpdated,
} from 'firebase-functions/v2/firestore';
import { admin, db } from './firebase';

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
 * Firestore Trigger: Dispatch Push Notifications via FCM
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
 * Firestore Trigger: Direct Message Push Producer
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
 * Firestore Trigger: Flash Drop Follower & Waitlist Alerts
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
