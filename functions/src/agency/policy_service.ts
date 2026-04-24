import * as admin from "firebase-admin";
import * as functions from "firebase-functions/v1";

const db = admin.firestore();

/**
 * TRIGGER: Policy Enforcement for Gender Changes (1st Gen - Classic Syntax)
 * Monitoring user gender changes to ensure agency compliance.
 * Explicitly set to us-central1 for stability.
 */
export const onGenderChangePolicyEnforcement = functions.runWith({memory: "256MB", timeoutSeconds: 60}).region("us-central1").firestore
  .document("users/{userId}")
  .onUpdate(async (change, context) => {
    const beforeData = change.before.data();
    const afterData = change.after.data();
    const userId = context.params.userId;

    if (!beforeData || !afterData) return;

    if (beforeData.gender !== afterData.gender) {
      functions.logger.info(`[POLICY] 🛡️ Gender change detected for user ${userId}: ${beforeData.gender} -> ${afterData.gender}`);

      if (afterData.isHost && afterData.agencyId) {
        functions.logger.warn(`[POLICY] ⚠️ User ${userId} is a Host and changed gender. Flags might be needed.`);

        try {
          await db.collection("agencies").doc(afterData.agencyId).collection("alerts").add({
            userId,
            oldGender: beforeData.gender,
            newGender: afterData.gender,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            type: "GENDER_STABILITY_ALERT",
            status: "PENDING_REVIEW",
          });
          functions.logger.info(`[POLICY] ✅ Alert created for Agency ${afterData.agencyId}`);
        } catch (error: unknown) {
          functions.logger.error("[POLICY] ❌ Failed to create agency alert:", error);
        }
      }
    }
  });
