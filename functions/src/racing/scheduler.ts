import * as admin from "firebase-admin";
import * as functions from "firebase-functions/v1";
import {RacingGameState} from "./types";

const db = admin.firestore();

/**
 * RACING GAME SCHEDULER (1st Gen - Classic Syntax)
 * Runs every 1 minute to manage game state transitions.
 * Explicitly set to us-central1 for stability.
 */
export const startRacingRound = functions.runWith({memory: "512MB", timeoutSeconds: 540}).region("us-central1").pubsub
  .schedule("every 1 minutes")
  .onRun(async (_context) => {
    functions.logger.info("🏁 ========== RACING GAME SCHEDULER WAKEUP ==========");
    const gameRef = db.collection("games").doc("racing");

    try {
      const gameDoc = await gameRef.get();
      if (!gameDoc.exists) {
        await initializeGameState(gameRef);
        return;
      }

      const gameState = gameDoc.data() as RacingGameState;
      const now = admin.firestore.Timestamp.now();
      const nextPhaseTime = gameState.next_phase_time;

      if (now.toMillis() >= nextPhaseTime.toMillis() - 2000) {
        functions.logger.info(`⚡ Phase Overdue (${gameState.status}) | Transitioning...`);

        if (gameState.status === "BETTING") {
          await transitionToRacing(gameRef, gameState);
        } else if (gameState.status === "RACING") {
          await transitionToResult(gameRef, gameState);
        } else if (gameState.status === "RESULT") {
          await transitionToBetting(gameRef);
        }
      } else {
        const remaining = (nextPhaseTime.toMillis() - now.toMillis()) / 1000;
        functions.logger.info(`😴 Waiting for ${gameState.status} to end. Remaining: ${remaining.toFixed(1)}s`);
      }
    } catch (error) {
      functions.logger.error("❌ ERROR IN SCHEDULER:", error);
    }

    functions.logger.info("✅ ========== RACING SCHEDULER WAKEUP COMPLETED ==========\n");
  });

/**
 * Initialize game state (first run)
 */
async function initializeGameState(gameRef: FirebaseFirestore.DocumentReference) {
  const now = admin.firestore.Timestamp.now();
  const nextPhase = new Date(now.toDate().getTime() + 30000);

  const vehicles = generateRandomVehiclesConfig();

  await gameRef.set({
    current_round_id: `round_${Date.now()}`,
    status: "BETTING",
    next_phase_time: admin.firestore.Timestamp.fromDate(nextPhase),
    winner_car_id: null,
    participating_cars: [],
    total_pool: 0,
    vehicles: vehicles,
    history: [],
    created_at: now,
    updated_at: now,
  });

  functions.logger.info("✅ Game state initialized");
}

function generateRandomVehiclesConfig(): Record<string, { odds: number, total_bets: number, speed_level: number }> {
  const availableCars = [
    "suv_purple",
    "jeep_green",
    "bike_red",
    "sport_pink",
    "truck_yellow",
    "cyber_blue",
  ];

  const vehicles: Record<string, { odds: number, total_bets: number, speed_level: number }> = {};

  availableCars.forEach((carId) => {
    const odds = (Math.random() * (15.0 - 1.5) + 1.5).toFixed(1);
    const initialBets = Math.floor(Math.random() * 450) + 50;
    const speedLevel = Math.floor(Math.random() * 5) + 1;

    vehicles[carId] = {
      odds: parseFloat(odds),
      total_bets: initialBets,
      speed_level: speedLevel,
    };
  });

  return vehicles;
}

async function transitionToRacing(
  gameRef: FirebaseFirestore.DocumentReference,
  currentState: RacingGameState
) {
  const availableCars = ["suv_purple", "jeep_green", "bike_red", "sport_pink", "truck_yellow", "cyber_blue"];
  const shuffled = availableCars.sort(() => Math.random() - 0.5);
  const racingCars = shuffled.slice(0, 3);

  const winnerCarId = await determineWinner(currentState.current_round_id, racingCars);

  const now = admin.firestore.Timestamp.now();
  const nextPhase = new Date(now.toDate().getTime() + 10000);

  await gameRef.update({
    status: "RACING",
    next_phase_time: admin.firestore.Timestamp.fromDate(nextPhase),
    winner_car_id: winnerCarId,
    participating_cars: racingCars,
    updated_at: now,
  });

  functions.logger.info(`🏆 Winner selected: ${winnerCarId}`);
}

async function transitionToResult(
  gameRef: FirebaseFirestore.DocumentReference,
  currentState: RacingGameState
) {
  await processBetsAndPayouts(currentState);

  const now = admin.firestore.Timestamp.now();
  const nextPhase = new Date(now.toDate().getTime() + 6000);

  await gameRef.update({
    status: "RESULT",
    next_phase_time: admin.firestore.Timestamp.fromDate(nextPhase),
    updated_at: now,
  });

  functions.logger.info("✅ Bets processed, showing results");
}

async function transitionToBetting(gameRef: FirebaseFirestore.DocumentReference) {
  const now = admin.firestore.Timestamp.now();
  const nextPhase = new Date(now.toDate().getTime() + 30000);

  const vehicles = generateRandomVehiclesConfig();

  await gameRef.update({
    current_round_id: `round_${Date.now()}`,
    status: "BETTING",
    next_phase_time: admin.firestore.Timestamp.fromDate(nextPhase),
    winner_car_id: null,
    participating_cars: [],
    total_pool: 0,
    vehicles: vehicles,
    updated_at: now,
  });

  functions.logger.info("✅ New betting round started");
}

async function determineWinner(_roundId: string, cars: string[]): Promise<string> {
  return cars[Math.floor(Math.random() * cars.length)];
}

async function processBetsAndPayouts(gameState: RacingGameState) {
  const betsSnapshot = await db
    .collection("games")
    .doc("racing")
    .collection("rounds")
    .doc(gameState.current_round_id)
    .collection("bets")
    .get();

  if (betsSnapshot.empty) {
    functions.logger.info("⚠️ No bets placed this round");
    return;
  }

  const batch = db.batch();
  const winningCarOdds = gameState.vehicles?.[gameState.winner_car_id ?? ""]?.odds || 2.0;

  for (const betDoc of betsSnapshot.docs) {
    const bet = betDoc.data();
    const userId = bet.user_id;

    if (bet.car_id === gameState.winner_car_id) {
      const payout = Math.floor(bet.amount * winningCarOdds);
      const userRef = db.collection("users").doc(userId);
      batch.update(userRef, {
        coins: admin.firestore.FieldValue.increment(payout),
      });
      batch.update(betDoc.ref, {
        status: "WON",
        payout: payout,
      });

      const historyRef = db.collection("users").doc(userId).collection("racing_history").doc(gameState.current_round_id);
      batch.set(historyRef, {
        round_id: gameState.current_round_id,
        car_id: bet.car_id,
        bet_amount: bet.amount,
        result: "WON",
        payout: payout,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });
    } else {
      batch.update(betDoc.ref, {
        status: "LOST",
        payout: 0,
      });

      const historyRef = db.collection("users").doc(userId).collection("racing_history").doc(gameState.current_round_id);
      batch.set(historyRef, {
        round_id: gameState.current_round_id,
        car_id: bet.car_id,
        bet_amount: bet.amount,
        result: "LOST",
        payout: 0,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  }

  await batch.commit();
}

export const triggerRacingPhase = functions.runWith({memory: "256MB", timeoutSeconds: 60}).region("us-central1").https.onCall(async (data: { phase: string }, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "User must be logged in to trigger a phase.");
  }

  const gameRef = db.collection("games").doc("racing");

  try {
    const gameDoc = await gameRef.get();
    if (!gameDoc.exists) return {success: false, message: "Game not initialized"};

    const gameState = gameDoc.data() as RacingGameState;
    const now = admin.firestore.Timestamp.now();
    const nextPhaseTime = gameState.next_phase_time;

    if (now.toMillis() >= nextPhaseTime.toMillis() - 1000) {
      functions.logger.info(`⚡ CLIENT TRIGGERED: Phase Overdue (${gameState.status})`);

      if (gameState.status === "BETTING") {
        await transitionToRacing(gameRef, gameState);
      } else if (gameState.status === "RACING") {
        await transitionToResult(gameRef, gameState);
      } else if (gameState.status === "RESULT") {
        await transitionToBetting(gameRef);
      }
      return {success: true, message: "Transitioned to next phase"};
    } else {
      return {success: false, message: "Phase not overdue yet"};
    }
  } catch (error) {
    functions.logger.error("❌ Manual Trigger Error:", error);
    throw new functions.https.HttpsError("internal", "Failed to trigger phase");
  }
});

// trackActivePlayers RTDB trigger removed — requires Firebase Realtime Database namespace
// which is not configured in this project (causes HTTP 400 on deploy).
// Active player count can be tracked client-side using Firestore presence pattern instead.
