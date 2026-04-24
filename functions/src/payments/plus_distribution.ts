import * as admin from "firebase-admin";
import * as functions from "firebase-functions/v1";

const db = admin.firestore();

/**
 * DAILY DIAMOND PLUS DISTRIBUTION
 * Runs every day at 00:00 UTC to distribute 300 diamonds to active Plus members.
 * Region: us-central1 (Matching existing functions)
 */
export const distributePlusDiamonds = functions.runWith({
  memory: "512MB",
  timeoutSeconds: 540,
}).region("us-central1").pubsub
  .schedule("0 0 * * *") // Runs at 00:00 UTC daily
  .timeZone("UTC")
  .onRun(async (context) => {
    functions.logger.info("💎 [PLUS] Starting daily diamond distribution...");

    const now = admin.firestore.Timestamp.now();
    const cutoffDate = new Date(now.toDate().getTime() - 20 * 60 * 60 * 1000); // 20 hours ago
    const cutoffTimestamp = admin.firestore.Timestamp.fromDate(cutoffDate);

    // 1. Get all active memberships that haven't been granted today
    const membershipsSnapshot = await db.collection("plus_memberships")
      .where("isActive", "==", true)
      .where("endDate", ">", now)
      .where("lastGrantAt", "<", cutoffTimestamp)
      .limit(500) // Process in batches if necessary
      .get();

    if (membershipsSnapshot.empty) {
      functions.logger.info("💎 [PLUS] No eligible members for today's distribution.");
      return null;
    }

    functions.logger.info(`💎 [PLUS] Processing ${membershipsSnapshot.size} eligible members.`);

    let successCount = 0;
    let failCount = 0;

    for (const membershipDoc of membershipsSnapshot.docs) {
      const data = membershipDoc.data();
      const userId = data.userId;

      try {
        await db.runTransaction(async (txn) => {
          const userRef = db.collection("users").doc(userId);
          const membershipRef = membershipDoc.ref;
          const txnId = `plus_daily_${userId}_${now.toDate().toISOString().split("T")[0]}`;
          const diamondTxnRef = db.collection("coin_transactions").doc(txnId);

          // Double check membership state inside transaction
          const mDoc = await txn.get(membershipRef);
          const mData = mDoc.data();
          if (!mData || !mData.isActive || mData.lastGrantAt.toMillis() >= cutoffTimestamp.toMillis()) {
            return;
          }

          // Grant 566 diamonds
          txn.update(userRef, {
            diamonds: admin.firestore.FieldValue.increment(566),
            totalDiamondsGranted: admin.firestore.FieldValue.increment(566),
          });

          // Update membership
          txn.update(membershipRef, {
            lastGrantAt: now,
            totalDailyGranted: admin.firestore.FieldValue.increment(566),
            updatedAt: now,
          });

          // Log transaction
          txn.set(diamondTxnRef, {
            userId,
            type: "plus_daily_grant",
            amount: 566,
            status: "completed",
            packageName: "Diamond Plus Daily",
            timestamp: now,
            description: "Daily distribution for Diamond Plus membership",
          });
        });
        successCount++;
      } catch (err) {
        functions.logger.error(`💎 [PLUS] Failed to process distribution for user ${userId}:`, err);
        failCount++;
      }
    }

    functions.logger.info(`💎 [PLUS] Distribution completed. Success: ${successCount}, Failed: ${failCount}`);
    return null;
  });
