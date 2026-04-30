"use strict";

const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, Timestamp, FieldValue } = require("firebase-admin/firestore");
const { getStorage } = require("firebase-admin/storage");

initializeApp();

const db = getFirestore();
const ALLOWED = ["location_photos", "posts"];

function requireAuth(auth) {
  if (!auth || !auth.uid) {
    throw new HttpsError("unauthenticated", "Autentificare necesară.");
  }
  return auth.uid;
}

function extractStoragePath(downloadUrl) {
  try {
    const url = new URL(downloadUrl);
    const match = url.pathname.match(/\/v0\/b\/[^/]+\/o\/(.+)/);
    if (match) return decodeURIComponent(match[1]);
  } catch (_) {}
  return null;
}

// ─── FRIEND REQUESTS ─────────────────────────────────────────────────────────

exports.sendFriendRequest = onCall(async (request) => {
  const callerUid = requireAuth(request.auth);
  const { toUserId } = request.data;

  if (!toUserId || typeof toUserId !== "string") {
    throw new HttpsError("invalid-argument", "toUserId este necesar.");
  }
  if (callerUid === toUserId) {
    throw new HttpsError("invalid-argument", "Nu poți trimite cerere ție însuți.");
  }

  const existing = await db
    .collection("friend_requests")
    .where("fromUserId", "==", callerUid)
    .where("toUserId", "==", toUserId)
    .where("status", "==", "pending")
    .limit(1)
    .get();
  if (!existing.empty) return { success: true };

  const reverse = await db
    .collection("friend_requests")
    .where("fromUserId", "==", toUserId)
    .where("toUserId", "==", callerUid)
    .where("status", "==", "pending")
    .limit(1)
    .get();
  if (!reverse.empty) {
    throw new HttpsError("failed-precondition", "Ai deja o cerere de la acest utilizator.");
  }

  const friendDoc = await db
    .collection("users").doc(callerUid).collection("friends").doc(toUserId).get();
  if (friendDoc.exists) {
    throw new HttpsError("failed-precondition", "Sunteți deja prieteni.");
  }

  await db.collection("friend_requests").add({
    fromUserId: callerUid,
    toUserId,
    status: "pending",
    createdAt: Timestamp.now(),
  });
  return { success: true };
});

exports.cancelFriendRequest = onCall(async (request) => {
  const callerUid = requireAuth(request.auth);
  const { toUserId } = request.data;
  if (!toUserId) throw new HttpsError("invalid-argument", "toUserId este necesar.");

  const snapshot = await db
    .collection("friend_requests")
    .where("fromUserId", "==", callerUid)
    .where("toUserId", "==", toUserId)
    .where("status", "==", "pending")
    .get();

  const batch = db.batch();
  snapshot.docs.forEach((doc) => batch.delete(doc.ref));
  await batch.commit();
  return { success: true };
});

exports.acceptFriendRequest = onCall(async (request) => {
  const callerUid = requireAuth(request.auth);
  const { requestId } = request.data;
  if (!requestId) throw new HttpsError("invalid-argument", "requestId este necesar.");

  const reqDoc = await db.collection("friend_requests").doc(requestId).get();
  if (!reqDoc.exists) throw new HttpsError("not-found", "Cererea nu există.");

  const { fromUserId, toUserId, status } = reqDoc.data();
  if (toUserId !== callerUid) throw new HttpsError("permission-denied", "Nu ești destinatarul.");
  if (status !== "pending") throw new HttpsError("failed-precondition", "Cererea nu mai e în așteptare.");

  const batch = db.batch();
  const now = Timestamp.now();
  batch.delete(reqDoc.ref);
  batch.set(db.collection("users").doc(toUserId).collection("friends").doc(fromUserId), { userId: fromUserId, addedAt: now });
  batch.set(db.collection("users").doc(fromUserId).collection("friends").doc(toUserId), { userId: toUserId, addedAt: now });
  await batch.commit();
  return { success: true };
});

exports.declineFriendRequest = onCall(async (request) => {
  const callerUid = requireAuth(request.auth);
  const { requestId } = request.data;
  if (!requestId) throw new HttpsError("invalid-argument", "requestId este necesar.");

  const reqDoc = await db.collection("friend_requests").doc(requestId).get();
  if (!reqDoc.exists) throw new HttpsError("not-found", "Cererea nu există.");
  if (reqDoc.data().toUserId !== callerUid) {
    throw new HttpsError("permission-denied", "Nu ești destinatarul.");
  }
  await reqDoc.ref.delete();
  return { success: true };
});

exports.removeFriend = onCall(async (request) => {
  const callerUid = requireAuth(request.auth);
  const { friendId } = request.data;
  if (!friendId) throw new HttpsError("invalid-argument", "friendId este necesar.");

  const batch = db.batch();
  batch.delete(db.collection("users").doc(callerUid).collection("friends").doc(friendId));
  batch.delete(db.collection("users").doc(friendId).collection("friends").doc(callerUid));
  await batch.commit();
  return { success: true };
});

// ─── POSTS ────────────────────────────────────────────────────────────────────

exports.deletePost = onCall(async (request) => {
  const callerUid = requireAuth(request.auth);
  const { postId } = request.data;
  if (!postId) throw new HttpsError("invalid-argument", "postId este necesar.");

  const postDoc = await db.collection("posts").doc(postId).get();
  if (!postDoc.exists) throw new HttpsError("not-found", "Postarea nu există.");

  const { userId, imageUrl } = postDoc.data();
  if (userId !== callerUid) throw new HttpsError("permission-denied", "Nu ești proprietarul.");

  if (imageUrl) {
    try {
      const filePath = extractStoragePath(imageUrl);
      if (filePath) await getStorage().bucket().file(filePath).delete();
    } catch (err) {
      console.error("Eroare Storage:", err);
    }
  }
  await postDoc.ref.delete();
  return { success: true };
});

// ─── LIKES ────────────────────────────────────────────────────────────────────

exports.toggleLike = onCall(async (request) => {
  const callerUid = requireAuth(request.auth);
  const { postId, collection: col = "location_photos" } = request.data;

  if (!postId) throw new HttpsError("invalid-argument", "postId este necesar.");
  if (!ALLOWED.includes(col)) throw new HttpsError("invalid-argument", "Collection invalidă.");

  const postRef = db.collection(col).doc(postId);
  const likeRef = postRef.collection("likes").doc(callerUid);

  const [postDoc, likeDoc] = await Promise.all([postRef.get(), likeRef.get()]);
  if (!postDoc.exists) throw new HttpsError("not-found", "Postarea nu există.");

  const batch = db.batch();
  if (likeDoc.exists) {
    batch.delete(likeRef);
    batch.update(postRef, { likesCount: FieldValue.increment(-1) });
    await batch.commit();
    return { liked: false };
  } else {
    batch.set(likeRef, { userId: callerUid, createdAt: Timestamp.now() });
    batch.update(postRef, { likesCount: FieldValue.increment(1) });
    await batch.commit();
    return { liked: true };
  }
});

// ─── COMMENTS ─────────────────────────────────────────────────────────────────

exports.addComment = onCall(async (request) => {
  const callerUid = requireAuth(request.auth);
  const { postId, text, collection: col = "location_photos" } = request.data;

  if (!postId) throw new HttpsError("invalid-argument", "postId este necesar.");
  if (!text?.trim()) throw new HttpsError("invalid-argument", "Textul comentariului este necesar.");
  if (text.trim().length > 500) throw new HttpsError("invalid-argument", "Comentariul este prea lung (max 500 caractere).");
  if (!ALLOWED.includes(col)) throw new HttpsError("invalid-argument", "Collection invalidă.");

  const postRef = db.collection(col).doc(postId);
  const postDoc = await postRef.get();
  if (!postDoc.exists) throw new HttpsError("not-found", "Postarea nu există.");

  const userDoc = await db.collection("users").doc(callerUid).get();
  const userData = userDoc.data() || {};

  const commentRef = postRef.collection("comments").doc();
  const batch = db.batch();
  batch.set(commentRef, {
    userId: callerUid,
    text: text.trim(),
    userName: userData.displayName || "Utilizator",
    userPhotoUrl: userData.photoUrl || "",
    createdAt: Timestamp.now(),
  });
  batch.update(postRef, { commentsCount: FieldValue.increment(1) });
  await batch.commit();

  return { commentId: commentRef.id };
});

exports.deleteComment = onCall(async (request) => {
  const callerUid = requireAuth(request.auth);
  const { postId, commentId, collection: col = "location_photos" } = request.data;

  if (!postId || !commentId) {
    throw new HttpsError("invalid-argument", "postId și commentId sunt necesare.");
  }
  if (!ALLOWED.includes(col)) throw new HttpsError("invalid-argument", "Collection invalidă.");

  const commentRef = db.collection(col).doc(postId).collection("comments").doc(commentId);
  const commentDoc = await commentRef.get();

  if (!commentDoc.exists) throw new HttpsError("not-found", "Comentariul nu există.");
  if (commentDoc.data().userId !== callerUid) {
    throw new HttpsError("permission-denied", "Nu poți șterge comentariul altei persoane.");
  }

  const batch = db.batch();
  batch.delete(commentRef);
  batch.update(db.collection(col).doc(postId), { commentsCount: FieldValue.increment(-1) });
  await batch.commit();
  return { success: true };
});
