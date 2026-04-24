
/// ⭐⭐⭐ PAYMENT CONFIGURATION ⭐⭐⭐
/// Google Play In-App Purchase Settings
///
library;

class PaymentConfig {
  // ============================================================
  // 🛒 GOOGLE PLAY IAP PRODUCT IDS
  // ============================================================

  /// Product IDs must match exactly what is in Google Play Console
  static const Set<String> productIds = {
    'coins_5000', // 5000 Diamonds
    'coins_14200', // 14200 Diamonds
    'coins_55000', // 55000 Diamonds
    'coins_65000', // 65000 Diamonds
    'coins_150000', // 150000 Diamonds
    'coins_520000', // 520000 Diamonds
  };

  /// Consumable Purchase? (Diamonds are consumable = true)
  static const bool isConsumable = true;

  // ============================================================
  // PAYMENT SETTINGS
  // ============================================================

  /// Merchant name
  static const String merchantDisplayName = 'Shemet';

  /// Whether the app is in Live Mode for payments
  static const bool isLiveMode = true;

  /// Refund window in days
  static const int refundWindowDays = 48;

  // ============================================================
  // PAYMENT LIMITS & CONVERSIONS
  // ============================================================

  /// Minimum withdrawal amount in diamonds
  static const int minimumWithdrawalDiamonds = 1000;

  /// Exchange rate: diamonds to USD (100 diamonds = $1)
  static const double diamondToUsdRate = 0.01;

  /// Convert diamonds to USD
  static double diamondsToUsd(int diamonds) {
    return diamonds * diamondToUsdRate;
  }

  /// Convert USD to diamonds
  static int usdToDiamonds(double usd) {
    return (usd / diamondToUsdRate).toInt();
  }
}
