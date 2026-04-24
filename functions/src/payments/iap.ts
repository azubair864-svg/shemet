import * as admin from "firebase-admin";
import * as functions from "firebase-functions/v1";
import {createHash} from "crypto";

const db = admin.firestore();

interface VerifyPurchaseData {
  productId: string;
  purchaseId?: string;
  purchaseToken: string;
  source?: string;
  packageName?: string;
  priceValue?: number;
  priceLabel?: string;
  currencyCode?: string;
}

interface PlayVerifyResult {
  valid: boolean;
  raw?: unknown;
}

const PAYMENTS_LIVE_MODE = process.env.PAYMENTS_LIVE_MODE === "true";
const PAYMENTS_ALLOW_UNVERIFIED = process.env.PAYMENTS_ALLOW_UNVERIFIED === "true";

function diamondsFromProductId(productId: string): number {
  // New mappings based on Google Play Console updates (April 2026)
  switch (productId) {
    case "coins_5000": return 14000;
    case "coins_14200": return 49000;
    case "coins_55000": return 110000;
    case "coins_65000": return 156000; // Updated from 48000
    case "coins_150000": return 540000;
    case "coins_520000": return 1680000;
    default: {
      const match = /^diamonds?_(\d+)$|coins_(\d+)$/.exec(productId);
      if (!match) return 0;
      return Number.parseInt(match[1] || match[2], 10);
    }
  }
}

function purchaseDocId(userId: string, productId: string, token: string): string {
  const hash = createHash("sha256").update(token).digest("hex");
  return `${userId}_${productId}_${hash.slice(0, 24)}`;
}

async function verifyGooglePlayProductPurchase(
  productId: string,
  _purchaseToken: string,
): Promise<PlayVerifyResult> {
  if (!PAYMENTS_LIVE_MODE) {
    if (PAYMENTS_ALLOW_UNVERIFIED) {
      functions.logger.warn("Allowing unverified Google Play purchase because PAYMENTS_LIVE_MODE is disabled.", {productId});
      return {
        valid: true,
        raw: {verificationMode: "unverified_override"},
      };
    }

    functions.logger.error("Rejected Google Play purchase because PAYMENTS_LIVE_MODE is disabled.", {productId});
    return {
      valid: false,
      raw: {verificationMode: "disabled"},
    };
  }

  // Implementation for live mode verification (needs service account setup)
  return {valid: true, raw: {placeholder: true}};
}

/**
 * Verify and Grant Diamonds (1st Gen - Classic Syntax)
 * us-central1 region explicitly set for stability.
 */
export const verifyAndGrantDiamonds = functions.runWith({memory: "256MB", timeoutSeconds: 60}).region("us-central1").https.onCall(async (data: VerifyPurchaseData, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Authentication required.");
  }

  const userId = context.auth.uid;
  const {productId, purchaseToken} = data;

  if (!productId || !purchaseToken) {
    throw new functions.https.HttpsError("invalid-argument", "productId and purchaseToken are required.");
  }

  const diamonds = diamondsFromProductId(productId);
  if (diamonds <= 0) {
    throw new functions.https.HttpsError("invalid-argument", "Unsupported productId.");
  }

  functions.logger.info(`[IAP] Verifying purchase for ${userId}: ${productId}`);

  const verification = await verifyGooglePlayProductPurchase(productId, purchaseToken);
  if (!verification.valid) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "Purchase could not be verified.",
    );
  }

  const purchaseId = data.purchaseId || "unknown";
  const source = data.source || "unknown";
  const packageName = data.packageName || productId;
  const priceValue = Number.isFinite(Number(data.priceValue)) ? Number(data.priceValue) : 0;
  const priceLabel = data.priceLabel || null;
  const currencyCode = data.currencyCode || null;
  const docId = purchaseDocId(userId, productId, purchaseToken);

  const purchaseRef = db.collection("iap_purchases").doc(docId);
  const userRef = db.collection("users").doc(userId);
  const diamondTxnRef = db.collection("coin_transactions").doc(`iap_${docId}`);

  try {
    const transactionResult = await db.runTransaction(async (txn) => {
      const purchaseDoc = await txn.get(purchaseRef);

      if (purchaseDoc.exists && purchaseDoc.data()?.status === "granted") {
        return {alreadyGranted: true};
      }

      const userDoc = await txn.get(userRef);
      if (!userDoc.exists) {
        throw new functions.https.HttpsError("not-found", "User profile not found.");
      }

      txn.set(purchaseRef, {
        userId,
        productId,
        packageName,
        purchaseId,
        source,
        status: "granted",
        diamonds,
        priceValue,
        priceLabel,
        currencyCode,
        grantedAt: admin.firestore.FieldValue.serverTimestamp(),
        verifiedLive: PAYMENTS_LIVE_MODE,
        verificationPayload: verification.raw ?? null,
        tokenHash: createHash("sha256").update(purchaseToken).digest("hex"),
      }, {merge: true});

      txn.update(userRef, {
        diamonds: admin.firestore.FieldValue.increment(diamonds),
        totalDiamondsPurchased: admin.firestore.FieldValue.increment(diamonds),
        lastPurchaseAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Purchase logic continues normally below

      txn.set(diamondTxnRef, {
        userId,
        type: "purchase",
        amount: diamonds,
        price: priceValue,
        priceValue,
        priceLabel,
        currencyCode,
        packageName,
        status: "completed",
        paymentMethod: "google_play",
        transactionId: purchaseId,
        productId,
        source: `iap_${source}`,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});

      return {alreadyGranted: false};
    });

    functions.logger.info(`[IAP] Diamonds granted to ${userId}: ${diamonds} (Already granted: ${transactionResult.alreadyGranted})`);

    return {
      success: true,
      alreadyGranted: transactionResult.alreadyGranted,
      diamondsGranted: transactionResult.alreadyGranted ? 0 : diamonds,
    };
  } catch (error: unknown) {
    functions.logger.error(`[IAP] Transaction failed for ${userId}:`, error);
    throw new functions.https.HttpsError("internal", "Failed to process purchase.");
  }
});
