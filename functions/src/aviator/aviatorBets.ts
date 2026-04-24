import * as admin from "firebase-admin";
import * as functions from "firebase-functions/v1";
import {validateEnvironmentConfiguration} from "../utils/license_service";

const db = admin.firestore();

/**
 * Place a bet on Aviator (1st Gen - Classic Syntax)
 * us-central1 region explicitly set for stability.
 */
export const placeAviatorBet = functions.runWith({memory: "256MB", timeoutSeconds: 60}).region("us-central1").https.onCall(async (data: { amount?: number }, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "User must be logged in.");
  }

  await validateEnvironmentConfiguration();

  const userId = context.auth.uid;
  const amount = Math.floor(data.amount || 0);

  if (amount < 10) {
    throw new functions.https.HttpsError("invalid-argument", "Minimum bet is 10 diamonds.");
  }

  functions.logger.info(`[AVIATOR] ${userId} placing bet: ${amount}`);

  try {
    const userRef = db.collection("users").doc(userId);

    return await db.runTransaction(async (transaction) => {
      const userDoc = await transaction.get(userRef);
      if (!userDoc.exists) throw new Error("User not found");

      const currentDiamonds = userDoc.data()?.diamonds || 0;
      if (currentDiamonds < amount) {
        throw new Error("Insufficient diamonds");
      }

      transaction.update(userRef, {
        diamonds: admin.firestore.FieldValue.increment(-amount),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return {success: true, message: "Bet placed successfully"};
    });
  } catch (error: unknown) {
    functions.logger.error(`[AVIATOR] ❌ Bet failed for ${userId}:`, error);
    return {success: false, message: error instanceof Error ? error.message : "Failed to place bet"};
  }
});

/**
 * Cash out from Aviator (1st Gen - Classic Syntax)
 */
export const cashOutAviator = functions.runWith({memory: "256MB", timeoutSeconds: 60}).region("us-central1").https.onCall(async (data: { multiplier?: string, bet_amount?: number }, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "User must be logged in.");
  }

  await validateEnvironmentConfiguration();

  const userId = context.auth.uid;
  const multiplier = parseFloat(data.multiplier || "0");
  const betAmount = Math.floor(data.bet_amount || 0);

  if (multiplier < 1.0) {
    throw new functions.https.HttpsError("invalid-argument", "Invalid multiplier.");
  }

  const winnings = Math.floor(betAmount * multiplier);
  functions.logger.info(`[AVIATOR] ${userId} cashing out: ${multiplier}x (${winnings} diamonds)`);

  try {
    const userRef = db.collection("users").doc(userId);
    await userRef.update({
      diamonds: admin.firestore.FieldValue.increment(winnings),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {success: true, winnings};
  } catch (error: unknown) {
    functions.logger.error(`[AVIATOR] ❌ Cashout failed for ${userId}:`, error);
    return {success: false, message: error instanceof Error ? error.message : "Failed to cash out"};
  }
});
