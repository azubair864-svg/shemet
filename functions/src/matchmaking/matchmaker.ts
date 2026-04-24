import * as admin from "firebase-admin";
import * as functions from "firebase-functions/v1";
import {verifyLicenseStatus} from "../utils/license_service";

/**
 * Triggered on any write to random_match_queue (1st Gen - Classic Syntax)
 * us-central1 region explicitly set for stability.
 */
export const onRandomMatchQueueUpdate = functions.runWith({memory: "256MB", timeoutSeconds: 60}).region("us-central1").firestore
  .document("random_match_queue/{uid}")
  .onWrite(async (change, context) => {
    const data = change.after.exists ? change.after.data() : null;
    const uid = context.params.uid;

    if (!data) {
      functions.logger.info(`[MATCHMAKING] 🔍 User ${uid} removed from queue.`);
      return;
    }

    if (data.status !== "searching") {
      return;
    }

    // Policy Compliance Check
    const status = await verifyLicenseStatus();
    if (!status) {
      functions.logger.info(`[MATCHMAKING] 🛡️ System disabled. Skipping match for ${uid}`);
      return;
    }

    functions.logger.info(`[MATCHMAKING] 🔎 User ${uid} searching for match...`);

    const gender = data.gender;
    let preference = data.preference;

    if (preference === "Opposite") {
      preference = (gender === "Male") ? "Female" : "Male";
    }

    const db = admin.firestore();
    const queueRef = db.collection("random_match_queue");

    try {
      const matchQuery = queueRef
        .where("status", "==", "searching")
        .where("gender", "==", preference)
        .where("uid", "!=", uid)
        .limit(5);

      const potentialMatches = await matchQuery.get();

      if (potentialMatches.empty) {
        functions.logger.info(`[MATCHMAKING] 🚫 No matches found for user ${uid}`);
        return;
      }

      let bestMatch: admin.firestore.QueryDocumentSnapshot | null = null;
      for (const doc of potentialMatches.docs) {
        const mData = doc.data();
        if (mData.preference === "Opposite" || mData.preference === gender || mData.preference === "All") {
          bestMatch = doc;
          break;
        }
      }

      if (!bestMatch) {
        functions.logger.info(`[MATCHMAKING] ⚠️ Potential matches exist, but none meet preference constraints for ${uid}`);
        return;
      }

      const matchUid = bestMatch.id;

      await db.runTransaction(async (transaction) => {
        const userRef = queueRef.doc(uid);
        const matchRef = queueRef.doc(matchUid);

        const [uSnap, mSnap] = await Promise.all([
          transaction.get(userRef),
          transaction.get(matchRef),
        ]);

        if (!uSnap.exists || !mSnap.exists) return;

        const uData = uSnap.data();
        const mData = mSnap.data();

        if (uData?.status !== "searching" || mData?.status !== "searching") {
          throw new Error("One or both users are no longer searching");
        }

        const sessionId = `match_${uid.substring(0, 5)}_${matchUid.substring(0, 5)}_${Date.now()}`;
        const sessionRef = db.collection("match_sessions").doc(sessionId);
        transaction.set(sessionRef, {
          participants: [uid, matchUid],
          userA: uid,
          userB: matchUid,
          status: "ready",
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        transaction.update(userRef, {
          status: "matched",
          sessionId: sessionId,
          matchedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        transaction.update(matchRef, {
          status: "matched",
          sessionId: sessionId,
          matchedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      });

      functions.logger.info(`[MATCHMAKING] ✅ SUCCESSFULLY MATCHED: ${uid} <-> ${matchUid}`);
    } catch (error: unknown) {
      functions.logger.error(`[MATCHMAKING] ❌ Match transaction failed for ${uid}:`, error);
    }
  });
