import * as functions from "firebase-functions/v1";
import {RtcTokenBuilder, RtcRole} from "agora-access-token";
import {validateEnvironmentConfiguration} from "../utils/license_service";


/**
 * Generate Agora RTC Token (1st Gen - Classic Syntax)
 * us-central1 region explicitly set for stability.
 */
export const generateAgoraToken = functions.runWith({memory: "256MB", timeoutSeconds: 60}).region("us-central1").https.onCall(async (data: { channelName: string; uid: number }, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Authentication required.");
  }

  await validateEnvironmentConfiguration();

  if (!data || !data.channelName || typeof data.uid !== "number") {
    throw new functions.https.HttpsError("invalid-argument", "channelName and uid are required.");
  }

  const appId = process.env.AGORA_APP_ID || "6692816e28064f469df219a95ca2bb72";
  const appCertificate = process.env.AGORA_APP_CERTIFICATE || "594a1a2d5ca04e1f8100611e916c00c0";

  functions.logger.info(`[AGORA] Token request for Channel: ${data.channelName}, UID: ${data.uid}`);

  const role = RtcRole.PUBLISHER;
  const expirationTimeInSeconds = 3600 * 24;
  const currentTimestamp = Math.floor(Date.now() / 1000);
  const privilegeExpiredTs = currentTimestamp + expirationTimeInSeconds;

  try {
    const token = RtcTokenBuilder.buildTokenWithUid(
      appId,
      appCertificate,
      data.channelName,
      data.uid,
      role,
      privilegeExpiredTs
    );

    functions.logger.info(`[AGORA] Successfully generated token (Length: ${token.length})`);

    return {
      token: token,
      expiresIn: expirationTimeInSeconds,
    };
  } catch (err: unknown) {
    functions.logger.error("[AGORA] Token building failed:", err);
    throw new functions.https.HttpsError("internal", "Failed to build Agora token");
  }
});
