/**
 * Firebase Cloud Functions v2 — Student Hub Backend
 *
 * OPTIMIZATIONS APPLIED:
 *  1. Removed high-traffic 'users/{uid}' trigger (onTeacherApproved). Notifications are now handled by the app repository.
 *  2. Optimized 'onNewMessage' to send push notifications directly to recipients instead of creating
 *     persistent 'notification' documents for every message, significantly reducing Firestore writes and clutter.
 *  3. Removed redundant 'onNewMessage' Firestore writes (chat preview update) as the app already handles this.
 *  4. Optimized 'onNewBulletin' query to filter by role server-side, reducing memory usage and execution time.
 *  5. Centralized push delivery logic with presence awareness to reduce duplication.
 */

"use strict";

const admin = require("firebase-admin");
const logger = require("firebase-functions/logger");
const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");

admin.initializeApp();

const db = admin.firestore();

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const RECENT_ACTIVE_WINDOW_MS = 2 * 60 * 1000; // 2 minutes

// ---------------------------------------------------------------------------
// Utility helpers
// ---------------------------------------------------------------------------

function timestampToMillis(value) {
  if (!value) return 0;
  try {
    if (typeof value.toMillis === "function") return value.toMillis();
    if (typeof value.toDate === "function") return value.toDate().getTime();
    const d = new Date(value);
    if (!isNaN(d.getTime())) return d.getTime();
  } catch (_) {
    // ignore
  }
  return 0;
}

function toStringData(data) {
  const source = data || {};
  const output = {};
  for (const [key, value] of Object.entries(source)) {
    if (value === undefined || value === null) continue;
    output[key] = typeof value === "string" ? value : JSON.stringify(value);
  }
  return output;
}

/**
 * Returns true when any of the listed field names differ between before and after.
 */
function fieldsChanged(before, after, fields) {
  return fields.some((f) => JSON.stringify(before[f]) !== JSON.stringify(after[f]));
}

/**
 * Atomically claims a processed flag on a Firestore document to prevent duplicate triggers.
 */
async function claimProcessedFlag(docRef, flagName) {
  try {
    const claimed = await db.runTransaction(async (txn) => {
      const snap = await txn.get(docRef);
      if (!snap.exists) return false;
      if (snap.data()[flagName] === true) return false;
      txn.update(docRef, { [flagName]: true });
      return true;
    });
    return claimed;
  } catch (err) {
    logger.error("claimProcessedFlag failed", { path: docRef.path, flagName, error: err });
    return false;
  }
}

// ---------------------------------------------------------------------------
// User & Push helpers
// ---------------------------------------------------------------------------

async function getUserByUid(uid) {
  if (!uid || typeof uid !== "string") return null;
  const doc = await db.collection("users").doc(uid).get();
  if (!doc.exists) return null;
  return { uid: doc.id, ...doc.data() };
}

async function getUsersByIds(uids) {
  if (!uids || !uids.length) return [];
  const results = [];
  for (let i = 0; i < uids.length; i += 30) {
    const chunk = uids.slice(i, i + 30);
    const snap = await db.collection("users").where(admin.firestore.FieldPath.documentId(), "in", chunk).get();
    snap.docs.forEach(doc => results.push({ uid: doc.id, ...doc.data() }));
  }
  return results;
}

async function createNotificationDoc({ recipientUid, title, body, type, targetRoute, data }) {
  const ref = db.collection("notifications").doc();
  const payload = {
    notifId: ref.id,
    recipientUid,
    title,
    body,
    type,
    targetRoute,
    isRead: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    data: data || {},
  };
  await ref.set(payload);
  return payload;
}

async function sendPush({ token, title, body, type, targetRoute, data }) {
  if (!token || typeof token !== "string" || !token.trim()) return;

  const message = {
    token,
    notification: { title: title || "", body: body || "" },
    data: toStringData({ ...(data || {}), type, targetRoute }),
    android: { priority: "high", notification: { sound: "default" } },
    apns: {
      headers: { "apns-priority": "10" },
      payload: { aps: { alert: { title: title || "", body: body || "" }, sound: "default" } },
    },
  };

  try {
    return await admin.messaging().send(message);
  } catch (err) {
    const snip = (t) => (t && t.length > 12 ? `${t.substring(0, 8)}...${t.slice(-4)}` : t);
    logger.error("FCM push send failed", { token: snip(token), type, targetRoute, error: err });
    throw err;
  }
}

function shouldSendPushToUser(user, type, data) {
  if (!user || !user.fcmToken) return false;

  try {
    const isOnline = Boolean(user.isOnline);
    const lastActiveRaw = user.lastActiveAt || user.lastSeenAt || user.activeSessionUpdatedAt;
    const lastActiveMs = timestampToMillis(lastActiveRaw);
    const recentlyActive = lastActiveMs > 0 && (Date.now() - lastActiveMs) <= RECENT_ACTIVE_WINDOW_MS;

    const activeChatId = (user.activeChatId || "").toString();
    const notifChatId = (data?.chatId || "").toString();

    if (notifChatId && activeChatId === notifChatId) return false;
    if (isOnline && recentlyActive) return false;
  } catch (err) {
    logger.warn("Error evaluating presence", { uid: user.uid, error: err });
  }

  return true;
}

function previewMessage(message) {
  const kind = (message.type || "text").toString().toLowerCase();
  const content = (message.content || "").toString().trim();
  if (kind === "image") return "Sent an image";
  if (kind === "file") {
    const fileName = (message.fileName || "").toString().trim();
    return fileName ? `Sent file: ${fileName}` : "Sent a file";
  }
  return content || "New message";
}

// ---------------------------------------------------------------------------
// Triggers
// ---------------------------------------------------------------------------

exports.onNewReferralRequest = onDocumentCreated(
  "referrals/{requestId}",
  async (event) => {
    const referral = event.data?.data();
    if (!referral) return;

    const requestId = (event.params.requestId || "").toString();
    const alumniUid = (referral.alumniUid || "").toString().trim();
    if (!alumniUid) return;

    await createNotificationDoc({
      recipientUid: alumniUid,
      title: "New Referral Request",
      body: `${(referral.studentName || "A student").trim()} requested referral for ${(referral.targetCompany || "").trim()}`,
      type: "referral_request",
      targetRoute: "/alumni-dashboard",
      data: {
        requestId,
        studentUid: (referral.studentUid || "").toString(),
      },
    });
  }
);

exports.onReferralStatusChange = onDocumentUpdated(
  "referrals/{requestId}",
  async (event) => {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    if (!before || !after) return;

    if (!fieldsChanged(before, after, ["status"])) return;

    const currentStatus = (after.status || "").toString().toLowerCase();
    if (currentStatus !== "accepted" && currentStatus !== "rejected") return;

    const requestId = (event.params.requestId || "").toString();
    const studentUid = (after.studentUid || "").toString().trim();
    if (!requestId || !studentUid) return;

    const docRef = db.collection("referrals").doc(requestId);
    if (!(await claimProcessedFlag(docRef, "statusProcessed"))) return;

    const isAccepted = currentStatus === "accepted";
    await createNotificationDoc({
      recipientUid: studentUid,
      title: isAccepted ? "Referral Accepted" : "Referral Rejected",
      body: isAccepted
        ? `${(after.alumniName || "Alumni").trim()} accepted your referral request.`
        : `${(after.alumniName || "Alumni").trim()} rejected your referral request.`,
      type: isAccepted ? "referral_accepted" : "referral_rejected",
      targetRoute: "/my-referrals",
      data: {
        requestId,
        status: currentStatus,
        chatId: (after.chatId || "").toString(),
      },
    });
  }
);

exports.onNewMessage = onDocumentCreated(
  "chats/{chatId}/messages/{messageId}",
  async (event) => {
    const message = event.data?.data();
    if (!message) return;

    const chatId = (event.params.chatId || "").toString();
    const senderId = (message.senderId || "").toString().trim();
    if (!chatId || !senderId) return;

    const chatDoc = await db.collection("chats").doc(chatId).get();
    const chatData = chatDoc.data();
    if (!chatData) return;

    const recipientsUids = (chatData.participants || []).filter(uid => uid !== senderId);
    if (!recipientsUids.length) return;

    const recipients = await getUsersByIds(recipientsUids);
    const preview = previewMessage(message);
    const isGroup = (chatData.type || "").toLowerCase() === "group";
    const senderName = (message.senderName || "New message").trim();

    const title = isGroup ? (chatData.groupName || senderName) : senderName;
    const body = isGroup ? `${senderName}: ${preview}` : preview;
    const type = "new_message";
    const targetRoute = `/chat/${chatId}`;

    for (const user of recipients) {
      if (shouldSendPushToUser(user, type, { chatId })) {
        try {
          await sendPush({
            token: user.fcmToken,
            title,
            body,
            type,
            targetRoute,
            data: { chatId, senderId, messageId: event.params.messageId },
          });
        } catch (err) {
          logger.error("Chat push failed", { chatId, recipient: user.uid, error: err });
        }
      }
    }
  }
);

exports.onNewBulletin = onDocumentCreated(
  "bulletins/{bulletinId}",
  async (event) => {
    const bulletin = event.data?.data();
    if (!bulletin) return;

    const bulletinId = (event.params.bulletinId || "").toString();
    const collegeId = (bulletin.collegeId || "").trim();
    if (!bulletinId || !collegeId) return;

    const targetSemester = bulletin.targetSemester === null || bulletin.targetSemester === undefined ? null : Number(bulletin.targetSemester);
    const targetCourse = (bulletin.targetCourse || "").trim().toLowerCase();
    const postedBy = (bulletin.postedBy || "").trim();

    // Optimization: Filter by role server-side to reduce processing overhead
    const usersSnap = await db.collection("users")
      .where("collegeId", "==", collegeId)
      .where("role", "==", "student")
      .get();

    const targetUsers = usersSnap.docs
      .map(doc => ({ uid: doc.id, ...doc.data() }))
      .filter(u => u.uid !== postedBy)
      .filter(u => {
        const semOk = targetSemester === null || Number(u.semester) === targetSemester;
        const courseOk = !targetCourse || (u.course || "").trim().toLowerCase() === targetCourse;
        return semOk && courseOk;
      });

    if (!targetUsers.length) return;

    const BATCH_SIZE = 400;
    for (let i = 0; i < targetUsers.length; i += BATCH_SIZE) {
      const batch = db.batch();
      const chunk = targetUsers.slice(i, i + BATCH_SIZE);
      for (const user of chunk) {
        const ref = db.collection("notifications").doc();
        batch.set(ref, {
          notifId: ref.id,
          recipientUid: user.uid,
          title: "New Bulletin Posted",
          body: (bulletin.title || "").trim() || "Check latest bulletin updates.",
          type: "new_bulletin",
          targetRoute: `/bulletin/${bulletinId}`,
          isRead: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          data: { bulletinId, category: bulletin.category },
        });
      }
      await batch.commit();
    }
  }
);

exports.onNoteVerified = onDocumentUpdated(
  "notes/{noteId}",
  async (event) => {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    if (!before || !after) return;

    if (!fieldsChanged(before, after, ["isVerified", "isRejected"])) return;

    const noteId = (event.params.noteId || "").toString();
    const uploaderUid = (after.uploadedBy || "").trim();
    if (!noteId || !uploaderUid) return;

    let type, title, body;
    if (!before.isVerified && after.isVerified) {
      type = "note_verified";
      title = "Note Verified";
      body = "Your note has been verified by admin.";
    } else if (!before.isRejected && after.isRejected) {
      type = "note_rejected";
      title = "Note Rejected";
      body = (after.rejectionReason || "").trim() ? `Note rejected: ${after.rejectionReason}` : "Your note was rejected by admin.";
    } else return;

    const docRef = db.collection("notes").doc(noteId);
    if (!(await claimProcessedFlag(docRef, "verificationProcessed"))) return;

    await createNotificationDoc({
      recipientUid: uploaderUid,
      title,
      body,
      type,
      targetRoute: `/note-detail/${noteId}`,
      data: { noteId },
    });
  }
);

exports.onNotificationCreated = onDocumentCreated(
  "notifications/{notifId}",
  async (event) => {
    const notification = event.data?.data();
    if (!notification) return;

    const recipientUid = (notification.recipientUid || "").trim();
    const user = await getUserByUid(recipientUid);

    if (shouldSendPushToUser(user, notification.type, notification.data)) {
      await sendPush({
        token: user.fcmToken,
        title: notification.title,
        body: notification.body,
        type: notification.type,
        targetRoute: notification.targetRoute,
        data: { ...notification.data, notifId: event.params.notifId },
      });
    }
  }
);

exports.onNewAlumniQuestion = onDocumentCreated(
  "alumni_qa/{threadId}",
  async (event) => {
    const thread = event.data?.data();
    if (!thread) return;

    const threadId = (event.params.threadId || "").toString();
    const alumniUid = (thread.alumniUid || "").toString().trim();
    if (!threadId || !alumniUid) return;

    await createNotificationDoc({
      recipientUid: alumniUid,
      title: "New Question",
      body: "You have a new student question.",
      type: "alumni_reply",
      targetRoute: "/alumni-dashboard",
      data: {
        threadId,
        studentUid: (thread.studentUid || "").toString(),
      },
    });
  }
);

exports.onAlumniAnswerPosted = onDocumentUpdated(
  "alumni_qa/{threadId}",
  async (event) => {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    if (!before || !after) return;

    if (!fieldsChanged(before, after, ["answer"])) return;
    if ((before.answer || "").trim() || !(after.answer || "").trim()) return;

    const threadId = (event.params.threadId || "").toString();
    const studentUid = (after.studentUid || "").trim();

    const docRef = db.collection("alumni_qa").doc(threadId);
    if (!(await claimProcessedFlag(docRef, "answerProcessed"))) return;

    await createNotificationDoc({
      recipientUid: studentUid,
      title: "Question Answered",
      body: "Your question has been answered by alumni.",
      type: "new_qa_answer",
      targetRoute: "/alumni",
      data: { threadId },
    });
  }
);