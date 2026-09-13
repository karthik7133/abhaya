import admin from 'firebase-admin';
import path from 'path';
import fs from 'fs';
import dotenv from 'dotenv';

dotenv.config();

let isFirebaseConfigured = false;

export function isFirebaseReady(): boolean {
  return isFirebaseConfigured;
}

export function initFirebase(): void {
  if (admin.apps.length > 0) return;

  const serviceAccountJson = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
  const serviceAccountPath = process.env.FIREBASE_SERVICE_ACCOUNT_PATH;

  if (serviceAccountJson && serviceAccountJson.trim().length > 0) {
    try {
      const serviceAccount = JSON.parse(serviceAccountJson.trim()) as admin.ServiceAccount;
      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
        projectId: serviceAccount.projectId || 'abhaya-safety-app',
      });
      isFirebaseConfigured = true;
      console.log('[Firebase] ✅ Initialized with service account from FIREBASE_SERVICE_ACCOUNT_JSON env var');
      return;
    } catch (e) {
      console.error('[Firebase] ❌ Failed to parse FIREBASE_SERVICE_ACCOUNT_JSON:', e);
    }
  }

  if (serviceAccountPath && fs.existsSync(path.resolve(serviceAccountPath))) {
    try {
      const serviceAccount = JSON.parse(
        fs.readFileSync(path.resolve(serviceAccountPath), 'utf8')
      ) as admin.ServiceAccount;
      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
        projectId: serviceAccount.projectId || 'abhaya-safety-app',
      });
      isFirebaseConfigured = true;
      console.log('[Firebase] ✅ Initialized with service account from file');
      return;
    } catch (e) {
      console.error('[Firebase] ❌ Failed to read service account file:', e);
    }
  }

  // Safe fallback without throwing metadata.google.internal error
  try {
    admin.initializeApp({
      projectId: process.env.FIREBASE_PROJECT_ID || 'abhaya-safety-app',
    });
  } catch (e) {
    // Ignore if already initialized
  }
  isFirebaseConfigured = false;
  console.warn('[Firebase] ⚠️  No service account provided. Admin Auth sync and FCM will be disabled until FIREBASE_SERVICE_ACCOUNT_JSON is set in Render environment variables.');
}

export function getFirebaseAdmin() {
  return admin;
}

/**
 * Verify a Firebase ID token and return the decoded token.
 * Throws if the token is invalid or expired.
 */
export async function verifyIdToken(idToken: string): Promise<admin.auth.DecodedIdToken> {
  return admin.auth().verifyIdToken(idToken);
}

/**
 * Send a push notification to a single FCM token.
 */
export async function sendPushNotification(params: {
  fcmToken: string;
  title: string;
  body: string;
  data?: Record<string, string>;
}): Promise<void> {
  const { fcmToken, title, body, data } = params;
  try {
    await admin.messaging().send({
      token: fcmToken,
      notification: { title, body },
      data: data ?? {},
      android: {
        priority: 'high',
        notification: {
          channelId: 'abhaya_alerts',
          sound: 'default',
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
  } catch (err) {
    console.error('[FCM] Failed to send push to', fcmToken.substring(0, 20) + '...', err);
  }
}

/**
 * Broadcast to multiple FCM tokens (guardian group alert).
 */
export async function broadcastPush(params: {
  fcmTokens: string[];
  title: string;
  body: string;
  data?: Record<string, string>;
}): Promise<void> {
  const { fcmTokens, title, body, data } = params;
  if (!fcmTokens.length) return;

  const messages = fcmTokens.map(token => ({
    token,
    notification: { title, body },
    data: data ?? {},
    android: { priority: 'high' as const, notification: { channelId: 'abhaya_alerts', sound: 'default' } },
    apns: { payload: { aps: { sound: 'default', badge: 1 } } },
  }));

  try {
    const response = await admin.messaging().sendEach(messages);
    console.log(`[FCM] Broadcast: ${response.successCount}/${fcmTokens.length} delivered`);
  } catch (err) {
    console.error('[FCM] Broadcast error:', err);
  }
}
