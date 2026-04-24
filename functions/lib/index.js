"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.cleanupInactiveRooms = exports.sendPushNotification = exports.onGenderChangePolicyEnforcement = exports.aggregateDailyPerformance = exports.processCallCharge = exports.generateAgoraToken = exports.sendGift = exports.cancelWithdrawal = exports.requestWithdrawal = exports.distributePlusDiamonds = exports.verifyAndGrantDiamonds = exports.onRandomMatchQueueUpdate = exports.cashOutAviator = exports.placeAviatorBet = exports.runDiceGameLoop = exports.processDicePayout = exports.placeDiceBet = exports.placeBet = exports.triggerRacingPhase = exports.startRacingRound = void 0;
const admin = __importStar(require("firebase-admin"));
const functions = __importStar(require("firebase-functions/v1"));
// Initialize Admin SDK (only once)
if (admin.apps.length === 0) {
    admin.initializeApp();
}
// Racing game functions (v1)
var scheduler_1 = require("./racing/scheduler");
Object.defineProperty(exports, "startRacingRound", { enumerable: true, get: function () { return scheduler_1.startRacingRound; } });
Object.defineProperty(exports, "triggerRacingPhase", { enumerable: true, get: function () { return scheduler_1.triggerRacingPhase; } });
var bets_1 = require("./racing/bets");
Object.defineProperty(exports, "placeBet", { enumerable: true, get: function () { return bets_1.placeBet; } });
// Dice game functions (v1)
var diceBets_1 = require("./dice/diceBets");
Object.defineProperty(exports, "placeDiceBet", { enumerable: true, get: function () { return diceBets_1.placeDiceBet; } });
Object.defineProperty(exports, "processDicePayout", { enumerable: true, get: function () { return diceBets_1.processDicePayout; } });
var diceEngine_1 = require("./dice/diceEngine");
Object.defineProperty(exports, "runDiceGameLoop", { enumerable: true, get: function () { return diceEngine_1.runDiceGameLoop; } });
// Aviator game functions (v1)
var aviatorBets_1 = require("./aviator/aviatorBets");
Object.defineProperty(exports, "placeAviatorBet", { enumerable: true, get: function () { return aviatorBets_1.placeAviatorBet; } });
Object.defineProperty(exports, "cashOutAviator", { enumerable: true, get: function () { return aviatorBets_1.cashOutAviator; } });
// Matchmaking functions (v1)
var matchmaker_1 = require("./matchmaking/matchmaker");
Object.defineProperty(exports, "onRandomMatchQueueUpdate", { enumerable: true, get: function () { return matchmaker_1.onRandomMatchQueueUpdate; } });
// Payment functions (v1)
var iap_1 = require("./payments/iap");
Object.defineProperty(exports, "verifyAndGrantDiamonds", { enumerable: true, get: function () { return iap_1.verifyAndGrantDiamonds; } });
var plus_distribution_1 = require("./payments/plus_distribution");
Object.defineProperty(exports, "distributePlusDiamonds", { enumerable: true, get: function () { return plus_distribution_1.distributePlusDiamonds; } });
// Wallet functions (v1)
var withdrawals_1 = require("./wallet/withdrawals");
Object.defineProperty(exports, "requestWithdrawal", { enumerable: true, get: function () { return withdrawals_1.requestWithdrawal; } });
Object.defineProperty(exports, "cancelWithdrawal", { enumerable: true, get: function () { return withdrawals_1.cancelWithdrawal; } });
var gifts_1 = require("./wallet/gifts");
Object.defineProperty(exports, "sendGift", { enumerable: true, get: function () { return gifts_1.sendGift; } });
// Call functions (v1)
var agora_1 = require("./calls/agora");
Object.defineProperty(exports, "generateAgoraToken", { enumerable: true, get: function () { return agora_1.generateAgoraToken; } });
var billing_1 = require("./calls/billing");
Object.defineProperty(exports, "processCallCharge", { enumerable: true, get: function () { return billing_1.processCallCharge; } });
// Agency functions (v1)
var aggregation_1 = require("./agency/aggregation");
Object.defineProperty(exports, "aggregateDailyPerformance", { enumerable: true, get: function () { return aggregation_1.aggregateDailyPerformance; } });
var policy_service_1 = require("./agency/policy_service");
Object.defineProperty(exports, "onGenderChangePolicyEnforcement", { enumerable: true, get: function () { return policy_service_1.onGenderChangePolicyEnforcement; } });
// Notification functions (v1)
var fcm_1 = require("./notifications/fcm");
Object.defineProperty(exports, "sendPushNotification", { enumerable: true, get: function () { return fcm_1.sendPushNotification; } });
// Cleanup functions (v1)
var roomCleanup_1 = require("./cleanup/roomCleanup");
Object.defineProperty(exports, "cleanupInactiveRooms", { enumerable: true, get: function () { return roomCleanup_1.cleanupInactiveRooms; } });
functions.logger.info("All Cloud Functions loaded on 1st Generation (v1) infrastructure.");
//# sourceMappingURL=index.js.map