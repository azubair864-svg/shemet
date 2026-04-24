import * as admin from "firebase-admin";
import * as functions from "firebase-functions/v1";

const db = admin.firestore();

/**
 * DICE GAME SCHEDULER (1st Gen - Classic Syntax)
 * Runs every 1 minute to manage game state transitions
 * us-central1 region explicitly set for stability.
 */
export const runDiceGameLoop = functions.runWith({memory: "512MB", timeoutSeconds: 540}).region("us-central1").pubsub
  .schedule("every 1 minutes")
  .onRun(async (_context) => {
    functions.logger.info("🎲 ========== DICE GAME SCHEDULER WAKEUP ==========");
    const gameRef = db.collection("games").doc("dice");

    try {
      const gameDoc = await gameRef.get();
      if (!gameDoc.exists) {
        functions.logger.info("Initializing dice game state...");
        await gameRef.set({
          status: "betting",
          roundId: Date.now().toString(),
          diceResult: [1, 1, 1],
          countdown: 20,
          expiresAt: Date.now() + 20000,
          history: [],
        });
        return;
      }

      const gameState = gameDoc.data();
      if (!gameState) return;

      const now = Date.now();
      const expiresAt = gameState.expiresAt || now;

      if (now >= expiresAt - 2000) {
        functions.logger.info(`⚡ Phase Overdue (${gameState.status}) | Transitioning...`);

        if (gameState.status === "betting") {
          const result = [
            Math.floor(Math.random() * 6) + 1,
            Math.floor(Math.random() * 6) + 1,
            Math.floor(Math.random() * 6) + 1,
          ];
          await gameRef.update({
            status: "rolling",
            diceResult: result,
            expiresAt: now + 5000,
            roundId: now.toString(),
          });
          functions.logger.info("🎲 Transition: Betting -> Rolling");
        } else if (gameState.status === "rolling") {
          await gameRef.update({
            status: "result",
            expiresAt: now + 10000,
          });
          functions.logger.info("🏆 Transition: Rolling -> Result");
        } else if (gameState.status === "result") {
          await gameRef.update({
            status: "betting",
            expiresAt: now + 20000,
            roundId: now.toString(),
          });
          functions.logger.info("🔄 Transition: Result -> Betting");
        }
      } else {
        const remaining = (expiresAt - now) / 1000;
        functions.logger.info(`😴 Waiting for ${gameState.status} to end. Remaining: ${remaining.toFixed(1)}s`);
      }
    } catch (error: unknown) {
      functions.logger.error("❌ ERROR IN DICE SCHEDULER:", error);
    }
  });
