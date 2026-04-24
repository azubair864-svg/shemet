import * as admin from "firebase-admin";
import * as functions from "firebase-functions/v1";

// Initialize Admin SDK (only once)
if (admin.apps.length === 0) {
  admin.initializeApp();
}

// Racing game functions (v1)
export {startRacingRound, triggerRacingPhase} from "./racing/scheduler";
export {placeBet} from "./racing/bets";

// Dice game functions (v1)
export {placeDiceBet, processDicePayout} from "./dice/diceBets";
export {runDiceGameLoop} from "./dice/diceEngine";

// Aviator game functions (v1)
export {placeAviatorBet, cashOutAviator} from "./aviator/aviatorBets";

// Matchmaking functions (v1)
export {onRandomMatchQueueUpdate} from "./matchmaking/matchmaker";

// Payment functions (v1)
export {verifyAndGrantDiamonds} from "./payments/iap";
export {distributePlusDiamonds} from "./payments/plus_distribution";

// Wallet functions (v1)
export {requestWithdrawal, cancelWithdrawal} from "./wallet/withdrawals";
export {sendGift} from "./wallet/gifts";

// Call functions (v1)
export {generateAgoraToken} from "./calls/agora";
export {processCallCharge} from "./calls/billing";

// Agency functions (v1)
export {aggregateDailyPerformance} from "./agency/aggregation";
export {onGenderChangePolicyEnforcement} from "./agency/policy_service";

// Notification functions (v1)
export {sendPushNotification} from "./notifications/fcm";

// Cleanup functions (v1)
export {cleanupInactiveRooms} from "./cleanup/roomCleanup";

functions.logger.info("All Cloud Functions loaded on 1st Generation (v1) infrastructure.");
