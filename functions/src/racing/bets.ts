import * as admin from "firebase-admin";
import * as functions from "firebase-functions/v1";
import {validateEnvironmentConfiguration} from "../utils/license_service";

const db = admin.firestore();

/**
 * Place a bet on Racing (1st Gen - Classic Syntax)
 * us-central1 region explicitly set for stability.
 */
export const placeBet = functions.runWith({memory: "256MB", timeoutSeconds: 60}).region("us-central1").https.onCall(async (data: { car_id: string; amount: number }, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "User must be logged in.");
  }

  await validateEnvironmentConfiguration();

  const userId = context.auth.uid;
  const carId = data.car_id;
  const amount = Math.floor(data.amount || 0);

  if (!carId || amount < 10) {
    throw new functions.https.HttpsError("invalid-argument", "Valid car ID and minimum bet of 10 diamonds required.");
  }

  functions.logger.info(`[RACING] ${userId} placing bet: ${amount} on ${carId}`);

  try {
    const gameRef = db.collection("games").doc("racing");
    const gameDoc = await gameRef.get();

    if (!gameDoc.exists || gameDoc.data()?.status !== "BETTING") {
      throw new Error("Betting is currently closed.");
    }

    const currentRoundId = gameDoc.data()?.current_round_id;
    const userRef = db.collection("users").doc(userId);

    return await db.runTransaction(async (transaction) => {
      const userDoc = await transaction.get(userRef);
      if (!userDoc.exists) throw new Error("User not found");

      const currentDiamonds = userDoc.data()?.diamonds || 0;
      if (currentDiamonds < amount) {
        throw new Error("Insufficient diamonds");
      }

      // Deduct diamonds
      transaction.update(userRef, {
        diamonds: admin.firestore.FieldValue.increment(-amount),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Record bet
      const betRef = gameRef.collection("rounds").doc(currentRoundId).collection("bets").doc();
      transaction.set(betRef, {
        user_id: userId,
        car_id: carId,
        amount: amount,
        status: "PENDING",
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Update total pool
      transaction.update(gameRef, {
        total_pool: admin.firestore.FieldValue.increment(amount),
        [`vehicles.${carId}.total_bets`]: admin.firestore.FieldValue.increment(amount),
      });

      return {success: true, message: "Bet placed successfully"};
    });
  } catch (error: unknown) {
    functions.logger.error(`[RACING] ❌ Bet failed for ${userId}:`, error);
    return {success: false, message: error instanceof Error ? error.message : "Failed to place bet"};
  }
});
