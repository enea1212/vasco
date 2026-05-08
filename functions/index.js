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

  const requestRef = db.collection("friend_requests").doc(`${callerUid}_${toUserId}`);
  await requestRef.set({
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
      if (filePath && filePath.startsWith(`posts/${callerUid}/`)) {
        await getStorage().bucket().file(filePath).delete();
      }
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

  const result = await db.runTransaction(async (tx) => {
    const postRef = db.collection(col).doc(postId);
    const likeRef = postRef.collection("likes").doc(callerUid);

    const [postDoc, likeDoc] = await Promise.all([tx.get(postRef), tx.get(likeRef)]);
    if (!postDoc.exists) throw new HttpsError("not-found", "Postarea nu există.");

    if (likeDoc.exists) {
      tx.delete(likeRef);
      tx.update(postRef, { likesCount: FieldValue.increment(-1) });
      return { liked: false };
    }

    tx.set(likeRef, { userId: callerUid, createdAt: Timestamp.now() });
    tx.update(postRef, { likesCount: FieldValue.increment(1) });
    return { liked: true };
  });

  return result;
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



// ─── MATCH DETECTION ──────────────────────────────────────────────────────────────

exports.recordSwipe = onCall(async (request) => {
  const uid = requireAuth(request.auth);
  const { toUserId, isLike } = request.data;

  if (!toUserId || typeof isLike !== 'boolean') {
    throw new HttpsError('invalid-argument', 'toUserId și isLike sunt necesare.');
  }
  if (uid === toUserId) return { matched: false };

  // ID determinist — nu mai avem nevoie de index compus
  const swipeId = `${uid}_${toUserId}`;
  const swipeRef = db.collection('swipes').doc(swipeId);
  const existingSwipe = await swipeRef.get();

  // Odată ce ai interacționat cu un profil, decizia e finală
  if (existingSwipe.exists) return { matched: false };

  await swipeRef.set({
    fromUserId: uid,
    toUserId,
    isLike,
    timestamp: Timestamp.now(),
  });

  if (!isLike) return { matched: false };

  // Verificăm like-ul reciproc printr-un simplu get() — fără index
  const mutualSnap = await db.collection('swipes').doc(`${toUserId}_${uid}`).get();
  const hasMutualLike = mutualSnap.exists && mutualSnap.data().isLike === true;

  if (!hasMutualLike) return { matched: false };

  // ID determinist pentru match — același pentru ambii useri, indiferent de ordine
  const matchId = [uid, toUserId].sort().join('_');
  const convId = matchId;

  const matchRef = db.collection('matches').doc(matchId);
  const matchSnap = await matchRef.get();

  // Match-ul există deja — nu mai afișăm dialogul din nou
  if (matchSnap.exists) return { matched: false };

  const batch = db.batch();

  batch.set(matchRef, {
    users: [uid, toUserId],
    timestamp: Timestamp.now(),
    lastMessage: null,
  });

  const convRef = db.collection('conversations').doc(convId);
  const convSnap = await convRef.get();
  if (!convSnap.exists) {
    batch.set(convRef, {
      participantIds: [uid, toUserId],
      lastMessage: '',
      lastMessageTime: null,
      lastMessageSenderId: '',
      unreadCount: { [uid]: 0, [toUserId]: 0 },
      createdAt: Timestamp.now(),
    });
  }

  await batch.commit();

  // Returnăm datele userului cu care s-a făcut match
  const matchedUserSnap = await db.collection('users').doc(toUserId).get();
  const matchedUser = matchedUserSnap.data() || {};

  return {
    matched: true,
    matchedUser: {
      id: toUserId,
      displayName: matchedUser.displayName ?? 'Utilizator',
      photoUrl: matchedUser.photoUrl ?? null,
    },
    conversationId: convId,
  };
});

// ─── TINDER LOGIC  ─────────────────────────────────────────────────────────────────
const geofire = require("geofire-common");

function calcAge(birthDate) {
  if (!birthDate) return null;
  const today = new Date();
  const birth = birthDate.toDate ? birthDate.toDate() : new Date(birthDate);
  let age = today.getFullYear() - birth.getFullYear();
  const m = today.getMonth() - birth.getMonth();
  if (m < 0 || (m === 0 && today.getDate() < birth.getDate())) age--;
  return age;
}

function approxDistance(km) {
  if (km < 5) return "< 5 km";
  if (km < 15) return "5-15 km";
  if (km < 30) return "15-30 km";
  return "30-50 km";
}

function genderMatch(interestedIn, gender) {
  if (!interestedIn || interestedIn === "both") return true;
  return interestedIn === gender;
}

exports.getRecommendations = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Trebuie să fii logat pentru a vedea recomandări.');
  }
  const uid = request.auth.uid;

  const userSnap = await db.collection('users').doc(uid).get();
  const userData = userSnap.data();

  if (!userData || !userData.location) {
    throw new HttpsError('failed-precondition', 'Nu ți-am putut găsi locația.');
  }

  const myGender = userData.gender || null;
  const myAge = calcAge(userData.birthDate);
  const interestedIn = userData.preferences?.interestedIn || "both";
  const minAge = userData.preferences?.minAge || 18;
  const maxAge = userData.preferences?.maxAge || 99;
  const maxDistanceKm = userData.preferences?.maxDistance || 50;
  const radiusInM = maxDistanceKm * 1000;

  // Extragem istoricul de swipe-uri pentru a exclude profilele deja văzute
  const swipesSnap = await db.collection('swipes').where('fromUserId', '==', uid).get();
  const interactedUserIds = new Set();
  swipesSnap.forEach(doc => interactedUserIds.add(doc.data().toUserId));

  const center = [userData.location.lat, userData.location.lng];
  const bounds = geofire.geohashQueryBounds(center, radiusInM);
  const snapshots = await Promise.all(
    bounds.map(b =>
      db.collection('users').orderBy('location.geohash').startAt(b[0]).endAt(b[1]).get()
    )
  );

  const recommendedUsers = [];

  for (const snap of snapshots) {
    for (const doc of snap.docs) {
      const p = doc.data();

      if (doc.id === uid) continue;
      if (interactedUserIds.has(doc.id)) continue;
      if (!p.location?.lat || !p.location?.lng) continue;

      // Filtru gen: eu vreau genul lui, el vrea genul meu
      if (!genderMatch(interestedIn, p.gender)) continue;
      if (!genderMatch(p.preferences?.interestedIn, myGender)) continue;

      // Filtru vârstă: vârsta lui să fie în intervalul meu preferat
      const theirAge = calcAge(p.birthDate);
      if (theirAge !== null && (theirAge < minAge || theirAge > maxAge)) continue;

      // Filtru vârstă inversă: vârsta mea să fie în intervalul lor preferat
      if (myAge !== null) {
        const theirMin = p.preferences?.minAge || 18;
        const theirMax = p.preferences?.maxAge || 99;
        if (myAge < theirMin || myAge > theirMax) continue;
      }

      const distanceInKm = geofire.distanceBetween([p.location.lat, p.location.lng], center);
      if (distanceInKm * 1000 > radiusInM) continue;

      recommendedUsers.push({
        id: doc.id,
        displayName: p.displayName,
        photoUrl: p.photoUrl,
        bio: p.bio,
        age: theirAge,
        distance: approxDistance(distanceInKm),
        interests: p.interests || [],
      });
    }
  }

  const top20 = recommendedUsers.slice(0, 20);

  // Fetch pozele postate de fiecare user recomandat
  const top20WithPhotos = await Promise.all(
    top20.map(async (user) => {
      const postsSnap = await db.collection('location_photos')
        .where('userId', '==', user.id)
        .get();

      const photos = postsSnap.docs
        .filter(d => d.data().imageUrl)
        .sort((a, b) => {
          const aT = a.data().createdAt?.toMillis() ?? 0;
          const bT = b.data().createdAt?.toMillis() ?? 0;
          return bT - aT;
        })
        .map(d => ({
          imageUrl: d.data().imageUrl,
          locationName: d.data().locationName ?? d.data().countryName ?? null,
        }))
        .slice(0, 6);

      return { ...user, photos };
    })
  );

  return top20WithPhotos;
});

// ─── MY MATCHES ───────────────────────────────────────────────────────────────

exports.getMyMatches = onCall(async (request) => {
  const uid = requireAuth(request.auth);

  const matchesSnap = await db
    .collection('matches')
    .where('users', 'array-contains', uid)
    .get();

  if (matchesSnap.empty) return { matches: [] };

  const results = await Promise.all(
    matchesSnap.docs.map(async (doc) => {
      const data = doc.data();
      const otherUserId = data.users.find((id) => id !== uid);

      const userSnap = await db.collection('users').doc(otherUserId).get();
      const user = userSnap.data() || {};

      return {
        matchId: doc.id,
        conversationId: doc.id,
        userId: otherUserId,
        displayName: user.displayName ?? 'Utilizator',
        photoUrl: user.photoUrl ?? null,
        bio: user.bio ?? null,
        age: calcAge(user.birthDate),
        timestamp: data.timestamp?.toMillis() ?? null,
      };
    })
  );

  results.sort((a, b) => (b.timestamp ?? 0) - (a.timestamp ?? 0));

  return { matches: results };
});
