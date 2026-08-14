import admin from "firebase-admin";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import * as v1 from "firebase-functions/v1";

admin.initializeApp();

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

export const cleanupDeletedUser = v1.auth.user().onDelete(async (user) => {
  const uid = user.uid;
  const db = admin.firestore();
  const storage = admin.storage();
  const batch = db.batch();

  try {
    const teamsSnap = await db
      .collection("teams")
      .where("memberIds", "array-contains", uid)
      .get();
    for (const doc of teamsSnap.docs) {
      const data = doc.data() || {};
      const update = { memberIds: admin.firestore.FieldValue.arrayRemove(uid) };
      if (data.leadUid === uid) update.leadUid = null;
      batch.update(doc.ref, update);
    }

    const leadTeamsSnap = await db
      .collection("teams")
      .where("leadUid", "==", uid)
      .get();
    for (const doc of leadTeamsSnap.docs) {
      batch.update(doc.ref, {
        leadUid: null,
        memberIds: admin.firestore.FieldValue.arrayRemove(uid),
      });
    }

    const unitsSnap = await db
      .collection("units")
      .where("memberUids", "array-contains", uid)
      .get();
    for (const doc of unitsSnap.docs) {
      const data = doc.data() || {};
      const update = { memberUids: admin.firestore.FieldValue.arrayRemove(uid) };
      if (data.unitLeadUid === uid) update.unitLeadUid = null;
      batch.update(doc.ref, update);
    }

    const leadUnitsSnap = await db
      .collection("units")
      .where("unitLeadUid", "==", uid)
      .get();
    for (const doc of leadUnitsSnap.docs) {
      batch.update(doc.ref, {
        unitLeadUid: null,
        memberUids: admin.firestore.FieldValue.arrayRemove(uid),
      });
    }

    const userRef = db.collection("users").doc(uid);
    const userSnap = await userRef.get();
    if (userSnap.exists) {
      batch.delete(userRef);
    }

    const tokenRef = db.collection("fcm_tokens").doc(uid);
    const tokenSnap = await tokenRef.get();
    if (tokenSnap.exists) {
      batch.delete(tokenRef);
    }

    await batch.commit();

    const targets = [
      `profile_photos/${uid}.jpg`,
      `cover_photos/${uid}.jpg`,
    ];
    for (const path of targets) {
      try {
        await storage.bucket().file(path).delete();
      } catch (err) {
        console.warn(`Storage cleanup skipped for ${path}:`, err.message);
      }
    }
  } catch (err) {
    console.error(`Account cleanup failed for ${uid}:`, err);
  }
});