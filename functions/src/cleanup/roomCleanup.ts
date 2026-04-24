import * as admin from "firebase-admin";
import * as functions from "firebase-functions/v1";

const db = admin.firestore();

/**
 * Cleanup inactive rooms (1st Gen - Classic Syntax)
 * us-central1 region explicitly set for stability.
 */
export const cleanupInactiveRooms = functions.runWith({memory: "256MB", timeoutSeconds: 540}).region("us-central1").pubsub
  .schedule("every 30 minutes")
  .onRun(async (_context) => {
    functions.logger.info("[CLEANUP] Starting room cleanup...");

    try {
      const cutoff = new Date(Date.now() - 3600 * 1000); // 1 hour ago
      const roomsSnapshot = await db.collection("rooms")
        .where("status", "==", "active")
        .where("last_activity", "<", admin.firestore.Timestamp.fromDate(cutoff))
        .get();

      if (roomsSnapshot.empty) {
        functions.logger.info("[CLEANUP] No inactive rooms found.");
        return {success: true, count: 0};
      }

      const batch = db.batch();
      roomsSnapshot.docs.forEach((doc) => {
        batch.update(doc.ref, {
          status: "closed",
          closed_at: admin.firestore.FieldValue.serverTimestamp(),
        });
      });

      await batch.commit();
      functions.logger.info(`[CLEANUP] Closed ${roomsSnapshot.size} inactive rooms.`);
      return {success: true, count: roomsSnapshot.size};
    } catch (error: unknown) {
      functions.logger.error("[CLEANUP] ❌ Cleanup failed:", error);
      throw new functions.https.HttpsError("internal", "Failed to cleanup rooms.");
    }
  });
