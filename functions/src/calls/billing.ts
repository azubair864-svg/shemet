import * as admin from "firebase-admin";
import * as functions from "firebase-functions/v1";
import {validateEnvironmentConfiguration} from "../utils/license_service";

const db = admin.firestore();

interface CallChargeData {
  hostId: string;
  callId: string;
  amount: number;
}

/**
 * Process a periodic call charge (60/40 Split)
 * Us-central1 region explicitly set for stability.
 */
export const processCallCharge = functions.runWith({memory: "256MB", timeoutSeconds: 60}).region("us-central1").https.onCall(async (data: CallChargeData, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "User must be logged in.");
  }

  await validateEnvironmentConfiguration();

  const userId = context.auth.uid;
  const {hostId, callId, amount} = data;

  if (!hostId || !callId || !amount || amount <= 0) {
    throw new functions.https.HttpsError("invalid-argument", "Invalid charge data provided.");
  }

  functions.logger.info(`[BILLING] ${userId} paying ${amount} diamonds for call ${callId} to host ${hostId}`);

  try {
    const userRef = db.collection("users").doc(userId);
    const hostRef = db.collection("users").doc(hostId);
    const platformRef = db.collection("platform_stats").doc("earnings");

    return await db.runTransaction(async (transaction) => {
      const [userDoc, hostDoc] = await Promise.all([
        transaction.get(userRef),
        transaction.get(hostRef),
      ]);

      if (!userDoc.exists || !hostDoc.exists) {
        throw new Error("User or Host not found.");
      }

      const userData = userDoc.data();
      const currentDiamonds = userData?.diamonds || 0;

      if (currentDiamonds < amount) {
        throw new Error("Insufficient diamonds.");
      }

      // Calculate Split (60% Host, 40% Platform)
      const hostEarnings = Math.floor(amount * 0.6);
      const platformEarnings = amount - hostEarnings; // Ceiling for platform to avoid lost decimals

      // 1. Deduct from User
      transaction.update(userRef, {
        diamonds: admin.firestore.FieldValue.increment(-amount),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // 2. Add to Host (Earnings field)
      transaction.update(hostRef, {
        earningsBeans: admin.firestore.FieldValue.increment(hostEarnings),
        totalBeansReceived: admin.firestore.FieldValue.increment(hostEarnings),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // 3. Increment Platform Earnings
      transaction.set(platformRef, {
        totalEarnings: admin.firestore.FieldValue.increment(platformEarnings),
        lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});

      // 4. Record Transaction Log
      const txnRef = db.collection("coin_transactions").doc();
      transaction.set(txnRef, {
        userId,
        hostId,
        callId,
        amount,
        hostEarning: hostEarnings,
        platformEarning: platformEarnings,
        type: "call_billing",
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });

      return {
        success: true, 
        message: "Charge processed",
        remainingDiamonds: currentDiamonds - amount,
        hostEarned: hostEarnings
      };
    });
  } catch (error: unknown) {
    functions.logger.error(`[BILLING] ❌ Charge failed for ${userId}:`, error);
    return {
      success: false, 
      message: error instanceof Error ? error.message : "Failed to process charge"
    };
  }
});
