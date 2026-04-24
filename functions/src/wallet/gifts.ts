import * as admin from "firebase-admin";
import * as functions from "firebase-functions/v1";
import {validateEnvironmentConfiguration} from "../utils/license_service";

const db = admin.firestore();

interface SendGiftData {
  receiverId?: string;
  giftId?: string;
  amount?: number;
  contextId?: string;
  contextType?: string; // 'party_room' or 'live_stream'
  seatIndex?: number; // Optional seat index for direct update
  senderName?: string;
  receiverName?: string;
  giftName?: string;
}

/**
 * Send a gift from one user to another (1st Gen - Classic Syntax)
 */
export const sendGift = functions.runWith({memory: "256MB", timeoutSeconds: 60}).region("us-central1").https.onCall(async (data: SendGiftData, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "User must be logged in.");
  }

  await validateEnvironmentConfiguration();

  const senderId = context.auth.uid;
  const {receiverId, giftId, amount, contextId, contextType, seatIndex, senderName, receiverName, giftName} = data;

  if (!receiverId || !giftId || !amount || amount <= 0) {
    throw new functions.https.HttpsError("invalid-argument", "Invalid gift data provided.");
  }

  functions.logger.info(`[GIFT] ${senderId} sending ${amount} coins to ${receiverId} in ${contextType}:${contextId} (Seat: ${seatIndex})`);

  try {
    const senderRef = db.collection("users").doc(senderId);
    const receiverRef = db.collection("users").doc(receiverId);

    return await db.runTransaction(async (transaction) => {
      const [senderDoc, receiverDoc] = await Promise.all([
        transaction.get(senderRef),
        transaction.get(receiverRef),
      ]);

      if (!senderDoc.exists || !receiverDoc.exists) {
        throw new Error("One or more users not found.");
      }

      const senderData = senderDoc.data();
      const currentDiamonds = senderData?.diamonds || 0;

      if (currentDiamonds < amount) {
        throw new Error("Insufficient diamonds.");
      }

      // Calculate Split (60% Host, 40% Platform)
      const hostEarnings = Math.floor(amount * 0.6);
      const platformEarnings = amount - hostEarnings;

      const platformRef = db.collection("platform_stats").doc("earnings");

      // 1. Deduct from sender
      transaction.update(senderRef, {
        diamonds: admin.firestore.FieldValue.increment(-amount),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // 2. Add to receiver (Host) as Beans/Earnings
      transaction.update(receiverRef, {
        earningsBeans: admin.firestore.FieldValue.increment(hostEarnings),
        totalBeansReceived: admin.firestore.FieldValue.increment(hostEarnings),
        dailyGifts: admin.firestore.FieldValue.increment(amount),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // 3. Update Context (Room/Stream) if applicable
      functions.logger.info(`[GIFT_DEBUG] Checking context. Type: ${contextType}, ID: ${contextId}`);
      
      if (contextId && contextType && (contextType === "party_room" || contextType === "live_stream")) {
        const contextRef = db.collection(contextType === "party_room" ? "party_rooms" : "live_streams").doc(contextId);
        
        if (contextType === "party_room") {
          functions.logger.info(`[GIFT_DEBUG] Updating Party Room: ${contextId}`);
          const updateData: any = {
            earnings: admin.firestore.FieldValue.increment(amount),
          };

          // Update seat contribution if seatIndex is provided
          if (seatIndex !== undefined && seatIndex !== null) {
            functions.logger.info(`[GIFT_DEBUG] Updating seat contribution for index: ${seatIndex}`);
            updateData[`seats.${seatIndex}.contributionDiamonds`] = admin.firestore.FieldValue.increment(amount);
          }

          transaction.update(contextRef, updateData);
        } else if (contextType === "live_stream") {
          functions.logger.info(`[GIFT_DEBUG] Updating Live Stream: ${contextId}`);
          transaction.update(contextRef, {
            totalDiamondsReceived: admin.firestore.FieldValue.increment(amount),
            totalGiftsReceived: admin.firestore.FieldValue.increment(1),
          });
        }

        // 4. Create Event for Animation/Broadcast (Only for rooms/streams)
        functions.logger.info(`[GIFT_DEBUG] Creating animation event in: ${contextId}/events`);
        const eventRef = contextRef.collection("events").doc();
        transaction.set(eventRef, {
          type: "GIFT",
          giftId,
          senderId,
          senderName: senderName || "User",
          receiverId,
          receiverName: receiverName || "Host",
          giftName: giftName || "Gift",
          giftPrice: amount,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
        });
      } else {
        functions.logger.info(`[GIFT_DEBUG] Skipping room/stream update. Context is likely 'profile' or null.`);
      }

      // 5. Increment Platform Earnings
      transaction.set(platformRef, {
        totalEarnings: admin.firestore.FieldValue.increment(platformEarnings),
        lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});

      // 6. Record transaction
      const txnRef = db.collection("coin_transactions").doc();
      transaction.set(txnRef, {
        senderId,
        receiverId,
        giftId,
        amount,
        hostEarning: hostEarnings,
        platformEarning: platformEarnings,
        type: "gift",
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });

      return {success: true, message: "Gift sent successfully", hostEarned: hostEarnings};
    });
  } catch (error: unknown) {
    functions.logger.error(`[GIFT] ❌ Gift failed for ${senderId}:`, error);
    return {success: false, message: error instanceof Error ? error.message : "Failed to send gift"};
  }
});
