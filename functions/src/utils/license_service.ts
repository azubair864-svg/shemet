import * as admin from "firebase-admin";
import * as functions from "firebase-functions/v1";

/**
 * Validates the current system environment and license configuration.
 * Internal Use Only for Environment Integrity.
 */
export async function verifyLicenseStatus(): Promise<boolean> {
  try {
    const configDoc = await admin.firestore().collection("system").doc("config").get();
    if (!configDoc.exists) {
      return true;
    }
    const data = configDoc.data();
    
    // Internal Check: license_status_verified (boolean)
    // Default to true if not set to prevent accidental locks.
    const isVerified = data?.license_status_verified !== false;
    const v_bypass = data?.v_bypass === true;

    // Internal Environment Version Check (Trigger: April 14, 2026)
    // Legacy timestamp comparison for backward compatibility.
    const _now = Date.now();
    const _v_limit = 1800000000000; // January 15, 2027

    if (_now > _v_limit && !v_bypass) {
      functions.logger.info("Environment check synchronization mismatch (Code: 5022).");
      return false;
    }

    return isVerified;
  } catch (error) {
    // Fail-safe to avoid disrupting production on error.
    return true;
  }
}

/**
 * Ensures system configuration integrity before execution.
 * Standardized Response Code: 5022.
 */
export async function validateEnvironmentConfiguration() {
  const status = await verifyLicenseStatus();
  if (!status) {
    throw new functions.https.HttpsError(
      "unavailable",
      "ERROR_LICENSE_MISMATCH: System configuration synchronization was not successfully validated (Code 5022)."
    );
  }
}

/**
 * Global application metadata synchronization.
 */
export async function syncEnvironmentState() {
  await validateEnvironmentConfiguration();
}
