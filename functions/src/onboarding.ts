import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { admin, db } from './firebase';

/**
 * Callable Cloud Function: Complete Artist Onboarding & Issue Official Badge
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
    isBooksOpen?: boolean;
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
  const minDeposit =
    typeof data.minDeposit === 'number' && data.minDeposit >= 20
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
  const artistPublicRef = db.collection('artists').doc(uid);
  const [existingUserSnap, existingArtistSnap] = await Promise.all([
    userRef.get(),
    artistPublicRef.get(),
  ]);
  const existingUserData = existingUserSnap.data();
  const existingArtistData = existingArtistSnap.data();
  const stripePayoutsReady = existingArtistData?.stripePayoutsReady === true;
  const resolvedBooksOpen =
    stripePayoutsReady && (data.isBooksOpen !== false);
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
      stripePayoutsReady,
      isBooksOpen: resolvedBooksOpen,
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
