import 'package:flutter_test/flutter_test.dart';
import 'package:dating_live_app/config/payment_config.dart';

void main() {
  test('diamonds conversion is stable', () {
    expect(PaymentConfig.diamondsToUsd(1000), 10.0);
    expect(PaymentConfig.usdToDiamonds(2.5), 250);
  });
}
