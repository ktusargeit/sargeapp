import * as admin from "firebase-admin";
import { onDocumentCreated } from "firebase-functions/v2/firestore";

admin.initializeApp();

/**
 * Sends an OS-level push notification (FCM) whenever a new notification
 * document is created in Firestore. This keeps the in-app notification bell and
 * the phone's notification tray in sync — without the client needing to poll.
 *
 * The client stores each device's FCM token under `fcm_tokens/{uid}`. This
 * function reads that token using the Admin SDK (bypassing the restrictive
 * client rules) and dispatches the message to the recipient only, so a
 * notification can never be routed to the wrong user.
 */
export const sendPushOnNotification = onDocumentCreated(
  "notifications/{notificationId}",
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const data = snap.data() || {};
    const recipientId = data.recipientId;
    const title = data.title || "SARGE";
    const body = data.body || "";
    const type = data.type || null;
    const relatedId = data.relatedId || null;

    if (!recipientId) return;

    // If the notification was already read/consumed before this trigger fired,
    // skip sending a push (avoids spamming an obsolete notification).
    if (data.isRead === true) return;

    const tokenDoc = await admin
      .firestore()
      .collection("fcm_tokens")
      .doc(recipientId)
      .get();

    if (!tokenDoc.exists) return;

    const token = tokenDoc.data()?.token;
    if (!token) return;

    const payload = {
      token,
      notification: { title, body },
      data: {
        ...(type ? { type } : {}),
        ...(relatedId ? { relatedId } : {}),
      },
      android: {
        priority: "high",
        notification: { channelId: "announcements" },
      },
      apns: {
        headers: { "apns-priority": "10" },
        payload: { aps: { sound: "default" } },
      },
    };

    try {
      await admin.messaging().send(payload);
    } catch (err) {
      // A stale/invalid token is expected after a user reinstalls or logs out.
      // Best effort: log it and clean up so it never blocks later deliveries.
      console.error(
        `FCM send failed for ${recipientId}:`,
        err.code || err.message
      );

      if (
        err.code === "messaging/registration-token-not-registered" ||
        err.code === "messaging/invalid-registration-token"
      ) {
        try {
          await admin
            .firestore()
            .collection("fcm_tokens")
            .doc(recipientId)
            .delete();
        } catch (cleanupErr) {
          console.error("FCM token cleanup failed:", cleanupErr);
        }
      }
    }
  }
);