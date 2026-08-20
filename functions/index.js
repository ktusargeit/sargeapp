import admin from "firebase-admin";
import { onDocumentCreated, onDocumentUpdated } from "firebase-functions/v2/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";
import * as v1 from "firebase-functions/v1";

admin.initializeApp();

// Conversation "thread" types. These notifications are grouped: one document
// per (recipient, thread) whose `count` increments with each new message.
const THREAD_TYPES = new Set([
  "task_comment",
  "announcement_comment",
  "report_reply",
]);

function threadKeyOf(data) {
  const type = data.type;
  const relatedId = data.relatedId || data.targetId;
  if (!type || !relatedId || !THREAD_TYPES.has(type)) return null;
  return `${type}:${relatedId}`;
}

// Presence: while a user has `activeThreadId` equal to the thread key of this
// notification, that user is actively viewing the conversation and must not be
// disturbed (neither in-app nor push).
async function recipientHasThreadOpen(db, recipientId, threadKey) {
  if (!threadKey) return false;
  try {
    const presenceSnap = await db.collection("presence").doc(recipientId).get();
    return (
      presenceSnap.exists &&
      presenceSnap.data()?.activeThreadId === threadKey
    );
  } catch (err) {
    console.error("presence read failed:", err.code || err.message);
    return false;
  }
}

function buildPushPayload(data, recipientId) {
  const title = data.title || "SARGE";
  const body = data.body || "";
  const type = data.type || null;
  const relatedId = data.relatedId || null;
  const count = Number(data.count) || 0;

  const key = threadKeyOf(data);
  // collapseKey (Android legacy / android config) + apns-collapse-id (iOS)
  // make subsequent pushes for the same thread REPLACE the existing OS
  // notification instead of stacking a new one.
  const collapseId = key ? `${recipientId}:${key}` : null;

  const displayBody = key && count > 1 ? `${body} (${count} yeni mesaj)` : body;

  const payload = {
    token: null,
    notification: { title, body: displayBody },
    data: {
      ...(type ? { type } : {}),
      ...(relatedId ? { relatedId } : {}),
      ...(relatedId ? { targetId: relatedId } : {}),
      ...(count ? { count: String(count) } : {}),
    },
    android: {
      priority: "high",
      notification: { channelId: "announcements" },
      ...(collapseId ? { collapseKey: collapseId } : {}),
    },
    apns: {
      headers: {
        "apns-priority": "10",
        ...(collapseId ? { "apns-collapse-id": collapseId } : {}),
      },
      payload: { aps: { sound: "default" } },
    },
  };

  if (collapseId) payload.collapseKey = collapseId;
  return payload;
}

async function sendPushForNotification(db, recipientId, data) {
  if (!recipientId) return;
  if (data.isRead === true) return;

  const key = threadKeyOf(data);
  if (await recipientHasThreadOpen(db, recipientId, key)) {
    console.log(`Skipping push for ${recipientId} (thread open): ${key}`);
    return;
  }

  const tokenDoc = await db.collection("fcm_tokens").doc(recipientId).get();
  if (!tokenDoc.exists) return;

  const token = tokenDoc.data()?.token;
  if (!token) return;

  const payload = buildPushPayload(data, recipientId);
  payload.token = token;

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
        await db.collection("fcm_tokens").doc(recipientId).delete();
      } catch (cleanupErr) {
        console.error("FCM token cleanup failed:", cleanupErr);
      }
    }
  }
}

// A newly created notification → send the first push for it.
export const sendPushOnNotification = onDocumentCreated(
  "notifications/{notificationId}",
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    await sendPushForNotification(
      admin.firestore(),
      snap.data()?.recipientId,
      snap.data() || {}
    );
  }
);

// A grouped thread's counter increment → re-push with the updated count, using
// the same collapse key so the OS replaces the previous notification.
export const sendPushOnNotificationUpdate = onDocumentUpdated(
  "notifications/{notificationId}",
  async (event) => {
    const after = event.data?.after;
    if (!after) return;
    const data = after.data() || {};
    // Only grouped threads with an open (unread) state get an update push.
    if (!threadKeyOf(data)) return;
    if (data.isRead === true) return;
    await sendPushForNotification(
      admin.firestore(),
      data.recipientId,
      data
    );
  }
);

// Deterministic notification document id for a (recipient, thread) pair. This
// is what turns "one notification per message" into "one per thread + counter".
function notificationDocId(recipientId, type, relatedId) {
  const safe = (type + "_" + relatedId).replace(/[^a-zA-Z0-9_-]/g, "_");
  return `${recipientId}_${safe}`;
}

// Creates (count=1) or increments (count+1) the single grouped notification for
// a recipient/thread, unless the recipient currently has that thread open.
async function upsertThreadedNotification(db, {
  recipientId,
  title,
  body,
  type,
  relatedId,
  senderUid,
  senderName,
}) {
  if (!recipientId || !senderUid) return;

  const threadKey = `${type}:${relatedId}`;

  // Suppress entirely when the recipient is actively viewing this thread.
  try {
    const presenceSnap = await db.collection("presence").doc(recipientId).get();
    if (
      presenceSnap.exists &&
      presenceSnap.data()?.activeThreadId === threadKey
    ) {
      console.log(`Skipping grouped notify for ${recipientId} (thread open): ${threadKey}`);
      return;
    }
  } catch (err) {
    console.error("presence read failed:", err.code || err.message);
  }

  const docId = notificationDocId(recipientId, type, relatedId);
  const ref = db.collection("notifications").doc(docId);
  const ts = admin.firestore.FieldValue.serverTimestamp();

  await db.runTransaction(async (txn) => {
    const existing = await txn.get(ref);
    if (!existing.exists) {
      txn.set(ref, {
        recipientId,
        senderUid,
        senderName: senderName || null,
        title,
        body,
        type,
        relatedId,
        count: 1,
        isRead: false,
        createdAt: ts,
        updatedAt: ts,
      });
    } else {
      txn.update(ref, {
        senderUid,
        senderName: senderName || null,
        body,
        count: admin.firestore.FieldValue.increment(1),
        isRead: false,
        updatedAt: ts,
      });
    }
  });
}

// Task comment → grouped notifications to assignee + creator + replied-to user
// + every assignee in the same bulk group (never the commenter).
export const notifyTaskComment = onDocumentCreated(
  "tasks/{taskId}/comments/{commentId}",
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const comment = snap.data() || {};
    const senderUid = comment.senderUid;
    const senderName = comment.senderName || "Kullanıcı";
    if (!senderUid) return;

    const taskId = event.params.taskId;
    const db = admin.firestore();

    const taskSnap = await db.collection("tasks").doc(taskId).get();
    const task = taskSnap.data() || {};
    const title = task.title || "Görev";

    const text = typeof comment.text === "string" ? comment.text : "";
    const snippet = text.length > 80 ? `${text.slice(0, 80)}...` : text;
    const body = snippet
      ? `${senderName}, "${title}" görevine yorum yaptı: "${snippet}"`
      : `${senderName}, "${title}" görevine yorum yaptı.`;

    const targets = new Set();
    if (task.assignedTo) targets.add(task.assignedTo);
    if (task.assignedBy) targets.add(task.assignedBy);
    if (comment.replyToUid) targets.add(comment.replyToUid);

    if (task.bulkGroupId) {
      const bulkSnap = await db
        .collection("tasks")
        .where("bulkGroupId", "==", task.bulkGroupId)
        .get();
      for (const doc of bulkSnap.docs) {
        const other = doc.data().assignedTo;
        if (other) targets.add(other);
      }
    }

    targets.delete(senderUid);
    for (const uid of targets) {
      if (!uid) continue;
      await upsertThreadedNotification(db, {
        recipientId: uid,
        title: `Görev yorumu: ${title}`,
        body,
        type: "task_comment",
        relatedId: taskId,
        senderUid,
        senderName,
      });
    }
  }
);

// Announcement comment → grouped notification to the announcement author only.
export const notifyAnnouncementComment = onDocumentCreated(
  "announcements/{announcementId}/comments/{commentId}",
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const comment = snap.data() || {};
    const senderUid = comment.senderUid;
    const senderName = comment.senderName || "Kullanıcı";
    if (!senderUid) return;

    const announcementId = event.params.announcementId;
    const db = admin.firestore();

    const annSnap = await db
      .collection("announcements")
      .doc(announcementId)
      .get();
    const ann = annSnap.data() || {};
    const creatorId = ann.createdBy;
    if (!creatorId || creatorId === senderUid) return;

    await upsertThreadedNotification(db, {
      recipientId: creatorId,
      title: `Duyuruya yorum: ${ann.title || "Duyuru"}`,
      body: typeof comment.text === "string" && comment.text
        ? comment.text
        : "Duyuruna bir yorum eklendi.",
      type: "announcement_comment",
      relatedId: announcementId,
      senderUid,
      senderName,
    });
  }
);

// Report reply (messages is an array field) → grouped notification to the
// submitter, or to admins/unit-leads when the submitter is the one replying.
export const notifyReportReply = onDocumentUpdated(
  "reports/{reportId}",
  async (event) => {
    const before = event.data?.before?.data() || {};
    const after = event.data?.after?.data() || {};
    const beforeMsgs = Array.isArray(before.messages) ? before.messages : [];
    const afterMsgs = Array.isArray(after.messages) ? after.messages : [];
    if (afterMsgs.length <= beforeMsgs.length) return; // no new message

    const reportId = event.params.reportId;
    const newMsg = afterMsgs[afterMsgs.length - 1] || {};
    const senderUid = newMsg.senderUid;
    const senderName = newMsg.senderName || "Kullanıcı";
    if (!senderUid) return;

    const db = admin.firestore();
    const title = (after.title || after.message || "Bildirim").toString();
    const body =
      (typeof newMsg.text === "string" && newMsg.text) ||
      "Bildirime bir yanıt eklendi.";

    if (senderUid !== after.submittedBy) {
      if (after.submittedBy) {
        await upsertThreadedNotification(db, {
          recipientId: after.submittedBy,
          title: `Bildiriminize yanıt: ${title}`,
          body,
          type: "report_reply",
          relatedId: reportId,
          senderUid,
          senderName,
        });
      }
    } else {
      const adminsSnap = await db
        .collection("users")
        .where("role", "in", ["admin", "unit_lead"])
        .get();
      for (const doc of adminsSnap.docs) {
        await upsertThreadedNotification(db, {
          recipientId: doc.id,
          title: `Yeni bildirim yanıtı: ${title}`,
          body,
          type: "report_reply",
          relatedId: reportId,
          senderUid,
          senderName,
        });
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