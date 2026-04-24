import * as admin from "firebase-admin";
import * as functions from "firebase-functions/v1";

/**
 * Listens for new notifications created in a user's subcollection (1st Gen - Classic Syntax)
 * us-central1 region explicitly set for stability.
 */
export const sendPushNotification = functions.runWith({memory: "256MB", timeoutSeconds: 60}).region("us-central1").firestore
  .document("users/{userId}/notifications/{notificationId}")
  .onCreate(async (snapshot, context) => {
    const notificationData = snapshot.data();
    const userId = context.params.userId;
    const notificationId = context.params.notificationId;

    if (!notificationData) {
      functions.logger.info(`[FCM] 🔍 No data for notification ${notificationId}`);
      return;
    }

    functions.logger.info(`[FCM] 🔔 Processing notification for user: ${userId}`);

    try {
      const userDoc = await admin.firestore().collection("users").doc(userId).get();
      if (!userDoc.exists) {
        functions.logger.info(`[FCM] 🚫 User ${userId} does not exist. Cannot send notification.`);
        return;
      }

      const userData = userDoc.data();
      const fcmToken = userData?.fcmToken;

      if (!fcmToken) {
        functions.logger.info(`[FCM] 🚫 User ${userId} does not have an FCM token registered.`);
        return;
      }

      const payload: admin.messaging.Message = {
        token: fcmToken,
        notification: {
          title: notificationData.title || "New Notification",
          body: notificationData.body || "You have a new alert",
        },
        data: {
          ...flattenDataForFCM(notificationData.data || {}),
          notificationId: notificationId,
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
        android: {
          priority: "high",
          notification: {
            sound: "default",
            clickAction: "FLUTTER_NOTIFICATION_CLICK",
          },
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
              badge: 1,
            },
          },
        },
      };

      const response = await admin.messaging().send(payload);
      functions.logger.info(`[FCM] ✅ Successfully sent notification to ${userId}. Message ID: ${response}`);
      await snapshot.ref.update({status: "sent", messageId: response});
    } catch (error: unknown) {
      functions.logger.error(`[FCM] ❌ Error sending push notification to user ${userId}:`, error);
      await snapshot.ref.update({status: "failed", error: String(error)});
    }
  });

function flattenDataForFCM(data: Record<string, unknown>): Record<string, string> {
  const flat: Record<string, string> = {};
  for (const [key, value] of Object.entries(data)) {
    if (value !== null && value !== undefined) {
      flat[key] = typeof value === "object" ? JSON.stringify(value) : String(value);
    }
  }
  return flat;
}
