import * as admin from "firebase-admin";
import * as functions from "firebase-functions/v1";

const db = admin.firestore();

interface HostStats {
  userId: string;
  totalGiftsReceived: number;
}

interface AgencyStats {
  agencyId: string;
  totalGiftsReceived: number;
  hostsCount: number;
  activeHosts: string[];
}

/**
 * DAILY AGENCY PERFORMANCE AGGREGATION (1st Gen - Classic Syntax)
 * Runs at midnight every day to summarize performance.
 * Explicitly set to us-central1 for stability.
 */
export const aggregateDailyPerformance = functions.runWith({memory: "512MB", timeoutSeconds: 540}).region("us-central1").pubsub
  .schedule("every 24 hours")
  .onRun(async (_context) => {
    functions.logger.info("📊 ========== AGENCY AGGREGATION STARTED ==========");
    const yesterday = new Date();
    yesterday.setDate(yesterday.getDate() - 1);
    const dateStr = yesterday.toISOString().split("T")[0];

    try {
      const agenciesSnapshot = await db.collection("agencies").get();
      const batch = db.batch();

      for (const agencyDoc of agenciesSnapshot.docs) {
        const agencyId = agencyDoc.id;
        functions.logger.info(`Processing Agency: ${agencyId}`);

        const hostsSnapshot = await db.collection("users")
          .where("agencyId", "==", agencyId)
          .where("isHost", "==", true)
          .get();

        const agencyStats: AgencyStats = {
          agencyId,
          totalGiftsReceived: 0,
          hostsCount: hostsSnapshot.size,
          activeHosts: [],
        };

        const hostStatsList: HostStats[] = [];

        for (const hostDoc of hostsSnapshot.docs) {
          const hostData = hostDoc.data();
          const hostStats: HostStats = {
            userId: hostDoc.id,
            totalGiftsReceived: hostData.dailyGifts || 0,
          };

          agencyStats.totalGiftsReceived += hostStats.totalGiftsReceived;
          if (hostStats.totalGiftsReceived > 0) {
            agencyStats.activeHosts.push(hostDoc.id);
          }
          hostStatsList.push(hostStats);

          // Reset daily stats for host
          batch.update(hostDoc.ref, {
            dailyGifts: 0,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }

        // Save Daily Report
        const reportRef = db.collection("agency_reports").doc(`${agencyId}_${dateStr}`);
        batch.set(reportRef, {
          ...agencyStats,
          hosts: hostStatsList,
          reportDate: dateStr,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      functions.logger.info("✅ ========== AGENCY AGGREGATION COMPLETED ==========");
    } catch (error: unknown) {
      functions.logger.error("❌ ERROR IN AGENCY AGGREGATION:", error);
    }
  });
