import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class RefundRequestScreen extends StatelessWidget {
  const RefundRequestScreen({super.key, this.paymentId});
  final String? paymentId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Request Refund')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.info_outline, size: 80, color: Colors.blue),
            const SizedBox(height: 20),
            const Text(
              'Refunds are managed by Google Play',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              'To request a refund for an In-App Purchase, please visit your Order History in the Google Play Store.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                launchUrl(Uri.parse('https://play.google.com/store/account/orderhistory'));
              },
              child: const Text('Open Google Play Order History'),
            ),
          ],
        ),
      ),
    );
  }
}
