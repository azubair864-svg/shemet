import * as admin from "firebase-admin";
import * as functions from "firebase-functions/v1";
import {validateEnvironmentConfiguration} from "../utils/license_service";

const db = admin.firestore();
const MIN_WITHDRAW_AMOUNT_USD = 10;
const USD_TO_BEANS_RATE = 100; // 1 USD = 100 beans (Host Earnings)

interface WithdrawalRequestData {
  amount: number;
  method: string;
  methodDetails: Record<string, unknown>;
}

interface CancelWithdrawalData {
  requestId: string;
}

/**
 * Request a withdrawal (1st Gen - Classic Syntax)
 * us-central1 region explicitly set for stability.
 */
export const requestWithdrawal = functions.runWith({memory: "256MB", timeoutSeconds: 60}).region("us-central1").https.onCall(async (data: WithdrawalRequestData, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Authentication required.");
  }

  await validateEnvironmentConfiguration();

  const userId = context.auth.uid;
  const amount = Number(data.amount);

  if (!Number.isFinite(amount) || amount < MIN_WITHDRAW_AMOUNT_USD) {
    throw new functions.https.HttpsError("invalid-argument", `Minimum withdrawal is $${MIN_WITHDRAW_AMOUNT_USD.toFixed(2)}.`);
  }

  const requiredBeans = Math.ceil(amount * USD_TO_BEANS_RATE);
  const requestRef = db.collection("withdraw_requests").doc();
  const userRef = db.collection("users").doc(userId);

  functions.logger.info(`[WITHDRAWAL] Request from ${userId} for $${amount} (${requiredBeans} beans)`);

  try {
    await db.runTransaction(async (txn) => {
      const userDoc = await txn.get(userRef);
      if (!userDoc.exists) throw new Error("User profile not found.");

      const currentBeans = Number(userDoc.data()?.earningsBeans || 0);
      if (currentBeans < requiredBeans) throw new Error("Insufficient earnings balance.");

      txn.update(userRef, {
        earningsBeans: admin.firestore.FieldValue.increment(-requiredBeans),
        pendingWithdrawalBeans: admin.firestore.FieldValue.increment(requiredBeans),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      txn.set(requestRef, {
        userId,
        amount,
        amountBeans: requiredBeans, // Standardized to Beans
        method: data.method,
        methodDetails: data.methodDetails ?? {},
        status: "pending",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Transaction record for audit
      txn.set(db.collection("coin_transactions").doc(`withdraw_${requestRef.id}`), {
        userId,
        type: "withdrawal",
        amount: -requiredBeans,
        withdrawalAmount: amount,
        currency: "beans",
        status: "pending",
        requestId: requestRef.id,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    return {success: true, requestId: requestRef.id};
  } catch (error: unknown) {
    functions.logger.error(`[WITHDRAWAL] ❌ Request failed for ${userId}:`, error);
    throw new functions.https.HttpsError("internal", error instanceof Error ? error.message : "Failed to process withdrawal.");
  }
});

/**
 * Cancel a withdrawal request (1st Gen - Classic Syntax)
 */
export const cancelWithdrawal = functions.runWith({memory: "256MB", timeoutSeconds: 60}).region("us-central1").https.onCall(async (data: CancelWithdrawalData, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Authentication required.");
  }

  await validateEnvironmentConfiguration();

  const userId = context.auth.uid;
  const {requestId} = data;

  if (!requestId) {
    throw new functions.https.HttpsError("invalid-argument", "requestId is required.");
  }

  const withdrawalRef = db.collection("withdraw_requests").doc(requestId);
  const userRef = db.collection("users").doc(userId);

  functions.logger.info(`[WITHDRAWAL] Cancellation request from ${userId} for ${requestId}`);

  try {
    await db.runTransaction(async (txn) => {
      const reqDoc = await txn.get(withdrawalRef);
      if (!reqDoc.exists) throw new Error("Request not found.");

      const reqData = reqDoc.data() || {};
      if (reqData.userId !== userId) throw new Error("Permission denied.");
      if (reqData.status !== "pending") throw new Error("Only pending withdrawals can be canceled.");

      const amountBeans = Number(reqData.amountBeans || 0);

      txn.update(withdrawalRef, {
        status: "canceled",
        canceledAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      txn.update(userRef, {
        earningsBeans: admin.firestore.FieldValue.increment(amountBeans),
        pendingWithdrawalBeans: admin.firestore.FieldValue.increment(-amountBeans),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      txn.set(db.collection("coin_transactions").doc(`withdraw_cancel_${requestId}`), {
        userId,
        type: "withdrawal_refund",
        amount: amountBeans,
        currency: "beans",
        requestId: requestId,
        status: "completed",
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    return {success: true};
  } catch (error: unknown) {
    functions.logger.error(`[WITHDRAWAL] ❌ Cancellation failed for ${userId}:`, error);
    throw new functions.https.HttpsError("internal", error instanceof Error ? error.message : "Failed to cancel withdrawal.");
  }
});
