import admin from "firebase-admin";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";
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

// Returns the Monday (YYYY-MM-DD) of the ISO week containing `date`, in the
// configured timezone (Europe/Istanbul).
function weekKeyOf(date, timeZone = "Europe/Istanbul") {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    weekday: "short",
  }).format(date);
  // en-US format is like "Mon, 08/14/2026"
  const [, mm, dd, yyyy] = parts.match(/(\d{2})\/(\d{2})\/(\d{4})/) || [];
  const year = Number(yyyy);
  const month = Number(mm);
  const day = Number(dd);
  // Build a local-date Monday without timezone drift: compute the day-of-week
  // and subtract from the date's day-of-month.
  const weekday = new Date(year, month - 1, day).getDay(); // 0=Sun..6=Sat
  const offset = (weekday + 6) % 7; // Monday = 0
  const monday = new Date(year, month - 1, day - offset);
  const py = monday.getFullYear();
  const pm = String(monday.getMonth() + 1).padStart(2, "0");
  const pd = String(monday.getDate()).padStart(2, "0");
  return `${py}-${pm}-${pd}`;
}

// Resolves a cleaning assignment (type + targetIds [+ override]) into a set of
// responsible user ids. Team/unit assignments resolve their CURRENT members so
// notifications always reach whoever is a member this week.
async function resolveResponsibleUids(db, scheduleData) {
  const isOverridden =
    scheduleData.overrideAssignmentType != null &&
    scheduleData.overrideAssignmentType !== "";
  const type = isOverridden
    ? scheduleData.overrideAssignmentType
    : scheduleData.assignmentType;
  const targetIds =
    isOverridden && Array.isArray(scheduleData.overrideTargetIds) &&
    scheduleData.overrideTargetIds.length > 0
      ? scheduleData.overrideTargetIds
      : scheduleData.targetIds || [];

  if (!Array.isArray(targetIds) || targetIds.length === 0) return [];

  if (type === "team") {
    const doc = await db.collection("teams").doc(targetIds[0]).get();
    const data = doc.data() || {};
    return (data.memberIds || []).filter((id) => typeof id === "string");
  }

  if (type === "unit") {
    const doc = await db.collection("units").doc(targetIds[0]).get();
    const data = doc.data() || {};
    return (data.memberUids || []).filter((id) => typeof id === "string");
  }

  // individual / custom_group: targetIds are user ids directly.
  return targetIds.filter((id) => typeof id === "string");
}

// Every Monday at 09:00 Europe/Istanbul, notify this week's cleaning
// responsible person(s). The notification doc triggers `sendPushOnNotification`
// (Firestore onDocumentCreated), so each assignment also receives a push.
export const notifyCleaningWeek = onSchedule(
  {
    schedule: "0 9 * * 1",
    timeZone: "Europe/Istanbul",
  },
  async () => {
    const db = admin.firestore();
    const weekKey = weekKeyOf(new Date());

    const snap = await db
      .collection("cleaning_schedule")
      .doc(weekKey)
      .get();

    if (!snap.exists) {
      console.log(`No cleaning schedule realized for week ${weekKey}`);
      return;
    }

    const data = snap.data() || {};
    if (data.notifiedAt) {
      console.log(`Week ${weekKey} already notified`);
      return;
    }
    if (data.completed === true) {
      console.log(`Week ${weekKey} already completed; skipping notification`);
      return;
    }

    let uids;
    try {
      uids = await resolveResponsibleUids(db, data);
    } catch (err) {
      console.error("Failed to resolve responsible users:", err);
      return;
    }

    const unique = [...new Set(uids)].filter(Boolean);

    const batch = db.batch();
    const createdAt = admin.firestore.FieldValue.serverTimestamp();
    for (const uid of unique) {
      batch.set(db.collection("notifications").doc(), {
        recipientId: uid,
        senderUid: null,
        title: "Temizlik sırası sizde",
        body: "Bu hafta temizlik/malzeme alma sırası sizde.",
        type: "cleaning",
        relatedId: weekKey,
        isRead: false,
        createdAt,
      });
    }
    batch.update(db.collection("cleaning_schedule").doc(weekKey), {
      notifiedAt: createdAt,
    });

    await batch.commit();
    console.log(
      `Notified ${unique.length} responsible user(s) for week ${weekKey}`
    );
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