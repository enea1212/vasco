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

// ─── LOCATION GROUPS ─────────────────────────────────────────────────────────

exports.createLocationGroup = onCall(async (request) => {
  const uid = requireAuth(request.auth);
  const { name, memberIds = [] } = request.data;

  if (!name?.trim()) throw new HttpsError("invalid-argument", "Numele grupului este necesar.");
  if (name.trim().length > 50) throw new HttpsError("invalid-argument", "Numele este prea lung (max 50 caractere).");
  if (!Array.isArray(memberIds) || memberIds.length > 100) {
    throw new HttpsError("invalid-argument", "Lista de membri este invalidă.");
  }

  const friendDocs = await Promise.all(
    memberIds.map((id) =>
      db.collection("users").doc(uid).collection("friends").doc(id).get()
    )
  );
  if (friendDocs.some((d) => !d.exists)) {
    throw new HttpsError("invalid-argument", "Unii utilizatori nu sunt prieteni.");
  }

  const groupRef = db.collection("users").doc(uid).collection("location_groups").doc();
  const batch = db.batch();
  batch.set(groupRef, { name: name.trim(), createdAt: Timestamp.now() });
  for (const memberId of memberIds) {
    batch.set(groupRef.collection("members").doc(memberId), {
      userId: memberId,
      addedAt: Timestamp.now(),
    });
  }
  await batch.commit();
  return { groupId: groupRef.id };
});

exports.deleteLocationGroup = onCall(async (request) => {
  const uid = requireAuth(request.auth);
  const { groupId } = request.data;
  if (!groupId) throw new HttpsError("invalid-argument", "groupId este necesar.");

  const groupRef = db.collection("users").doc(uid).collection("location_groups").doc(groupId);
  const groupDoc = await groupRef.get();
  if (!groupDoc.exists) throw new HttpsError("not-found", "Grupul nu există.");

  const membersSnap = await groupRef.collection("members").get();
  const batch = db.batch();
  membersSnap.docs.forEach((d) => batch.delete(d.ref));
  batch.delete(groupRef);
  await batch.commit();
  return { success: true };
});

exports.addGroupMember = onCall(async (request) => {
  const uid = requireAuth(request.auth);
  const { groupId, memberId } = request.data;
  if (!groupId || !memberId) {
    throw new HttpsError("invalid-argument", "groupId și memberId sunt necesare.");
  }

  const [groupDoc, friendDoc] = await Promise.all([
    db.collection("users").doc(uid).collection("location_groups").doc(groupId).get(),
    db.collection("users").doc(uid).collection("friends").doc(memberId).get(),
  ]);
  if (!groupDoc.exists) throw new HttpsError("not-found", "Grupul nu există.");
  if (!friendDoc.exists) throw new HttpsError("failed-precondition", "Utilizatorul nu este prieten.");

  await groupDoc.ref.collection("members").doc(memberId).set({
    userId: memberId,
    addedAt: Timestamp.now(),
  });
  return { success: true };
});

exports.removeGroupMember = onCall(async (request) => {
  const uid = requireAuth(request.auth);
  const { groupId, memberId } = request.data;
  if (!groupId || !memberId) {
    throw new HttpsError("invalid-argument", "groupId și memberId sunt necesare.");
  }

  const groupDoc = await db
    .collection("users").doc(uid).collection("location_groups").doc(groupId).get();
  if (!groupDoc.exists) throw new HttpsError("not-found", "Grupul nu există.");

  await groupDoc.ref.collection("members").doc(memberId).delete();
  return { success: true };
});

// ─── COMMENTS ─────────────────────────────────────────────────────────────────

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
