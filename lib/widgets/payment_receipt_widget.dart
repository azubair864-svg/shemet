import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../config/payment_config.dart';

/// ⭐⭐⭐ PRODUCTION-READY PAYMENT RECEIPT WIDGET ⭐⭐⭐
/// Displays payment receipt and generates PDF for download/share
/// Features: Receipt display, PDF generation, print/share options
class PaymentReceiptWidget extends StatelessWidget {
  final String paymentId;
  final String? packageName;
  final int diamonds;
  final int bonusDiamonds;
  final double amount;
  final String status;
  final DateTime date;
  final String? paymentMethod;
  final String? transactionId;

  const PaymentReceiptWidget({
    super.key,
    required this.paymentId,
    this.packageName,
    required this.diamonds,
    this.bonusDiamonds = 0,
    required this.amount,
    required this.status,
    required this.date,
    this.paymentMethod,
    this.transactionId,
  });

  @override
  Widget build(BuildContext context) {
    
    
    
    
    

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Receipt header
          _buildHeader(),

          // Dotted divider
          _buildDottedDivider(),

          // Transaction details
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildDetailRow('Transaction ID', _truncateId(paymentId)),
                _buildDetailRow('Date', _formatDate(date)),
                _buildDetailRow('Status', _formatStatus(status),
                    valueColor: _getStatusColor(status)),
                _buildDetailRow('Payment Method', paymentMethod ?? 'Card'),
                if (transactionId != null)
                  _buildDetailRow('Transaction ID', _truncateId(transactionId!)),
              ],
            ),
          ),

          // Dotted divider
          _buildDottedDivider(),

          // Purchase breakdown
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Purchase Details',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                _buildDetailRow('Package', packageName ?? 'Diamond Package'),
                _buildDetailRow('Base Diamonds', '$diamonds'),
                if (bonusDiamonds > 0)
                  _buildDetailRow('Bonus Diamonds', '+$bonusDiamonds',
                      valueColor: Colors.green),
                const SizedBox(height: 8),
                _buildDetailRow('Total Diamonds', '${diamonds + bonusDiamonds}',
                    valueColor: Colors.amber, isBold: true),
              ],
            ),
          ),

          // Dotted divider
          _buildDottedDivider(),

          // Total amount
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'TOTAL PAID',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '\$${amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.amber,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2D2D44), Color(0xFF1E1E32)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Column(
        children: [
          // Logo
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.receipt_long, color: Colors.amber, size: 32),
          ),
          const SizedBox(height: 12),

          // App name
          const Text(
            PaymentConfig.merchantDisplayName,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Payment Receipt',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 14,
            ),
          ),

          // Environment badge
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: PaymentConfig.isLiveMode
                  ? Colors.red.withValues(alpha: 0.2)
                  : Colors.green.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              PaymentConfig.isLiveMode ? 'LIVE TRANSACTION' : 'TEST TRANSACTION',
              style: TextStyle(
                color: PaymentConfig.isLiveMode ? Colors.red : Colors.green,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDottedDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: List.generate(
          30,
          (index) => Expanded(
            child: Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              color: index.isEven ? Colors.white24 : Colors.transparent,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value,
      {Color? valueColor, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 14,
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? Colors.white,
                fontSize: 14,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              ),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _truncateId(String id) {
    if (id.length <= 12) return id;
    return '${id.substring(0, 8)}...${id.substring(id.length - 4)}';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatStatus(String status) {
    return status
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'failed':
        return Colors.red;
      case 'refunded':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  /// Generate PDF receipt
  Future<pw.Document> generatePdf() async {
    
    

    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(40),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Text(
                        PaymentConfig.merchantDisplayName,
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        'Payment Receipt',
                        style: const pw.TextStyle(
                          fontSize: 16,
                          color: PdfColors.grey700,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: pw.BoxDecoration(
                          color: PaymentConfig.isLiveMode
                              ? PdfColors.red100
                              : PdfColors.green100,
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        child: pw.Text(
                          PaymentConfig.isLiveMode
                              ? 'LIVE TRANSACTION'
                              : 'TEST TRANSACTION',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: PaymentConfig.isLiveMode
                                ? PdfColors.red
                                : PdfColors.green,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 40),

                // Divider
                pw.Divider(color: PdfColors.grey300),
                pw.SizedBox(height: 20),

                // Transaction Details
                pw.Text(
                  'Transaction Details',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.SizedBox(height: 12),
                _pdfDetailRow('Transaction ID', paymentId),
                _pdfDetailRow('Date', _formatDate(date)),
                _pdfDetailRow('Status', _formatStatus(status)),
                _pdfDetailRow('Payment Method', paymentMethod ?? 'Card'),
                if (transactionId != null)
                  _pdfDetailRow('Transaction ID', transactionId!),
                pw.SizedBox(height: 20),

                // Divider
                pw.Divider(color: PdfColors.grey300),
                pw.SizedBox(height: 20),

                // Purchase Details
                pw.Text(
                  'Purchase Details',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.SizedBox(height: 12),
                _pdfDetailRow('Package', packageName ?? 'Diamond Package'),
                _pdfDetailRow('Base Diamonds', '$diamonds'),
                if (bonusDiamonds > 0)
                  _pdfDetailRow('Bonus Diamonds', '+$bonusDiamonds'),
                _pdfDetailRow('Total Diamonds', '${diamonds + bonusDiamonds}',
                    isBold: true),
                pw.SizedBox(height: 20),

                // Divider
                pw.Divider(color: PdfColors.grey300),
                pw.SizedBox(height: 20),

                // Total
                pw.Container(
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.amber50,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'TOTAL PAID',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        '\$${amount.toStringAsFixed(2)}',
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.amber800,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 40),

                // Footer
                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Text(
                        'Thank you for your purchase!',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        'For support, contact: support@datingliveapp.com',
                        style: const pw.TextStyle(
                          fontSize: 12,
                          color: PdfColors.grey600,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Refund available within ${PaymentConfig.refundWindowDays} days if diamonds are unused.',
                        style: const pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    
    

    return pdf;
  }

  pw.Widget _pdfDetailRow(String label, String value, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(
              fontSize: 12,
              color: PdfColors.grey700,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  /// Show print/share dialog
  static Future<void> showReceiptActions(
    BuildContext context, {
    required String paymentId,
    String? packageName,
    required int diamonds,
    int bonusDiamonds = 0,
    required double amount,
    required String status,
    required DateTime date,
    String? paymentMethod,
    String? transactionId,
  }) async {
    

    final receipt = PaymentReceiptWidget(
      paymentId: paymentId,
      packageName: packageName,
      diamonds: diamonds,
      bonusDiamonds: bonusDiamonds,
      amount: amount,
      status: status,
      date: date,
      paymentMethod: paymentMethod,
      transactionId: transactionId,
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A2E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              'Receipt Options',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),

            // View receipt
            _actionButton(
              context,
              icon: Icons.visibility,
              label: 'View Receipt',
              onTap: () {
                Navigator.pop(context);
                _showReceiptPreview(context, receipt);
              },
            ),
            const SizedBox(height: 12),

            // Print receipt
            _actionButton(
              context,
              icon: Icons.print,
              label: 'Print Receipt',
              onTap: () async {
                Navigator.pop(context);
                final pdf = await receipt.generatePdf();
                await Printing.layoutPdf(
                  onLayout: (format) async => pdf.save(),
                );
              },
            ),
            const SizedBox(height: 12),

            // Share receipt
            _actionButton(
              context,
              icon: Icons.share,
              label: 'Share Receipt',
              onTap: () async {
                Navigator.pop(context);
                final pdf = await receipt.generatePdf();
                await Printing.sharePdf(
                  bytes: await pdf.save(),
                  filename: 'receipt_$paymentId.pdf',
                );
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );

    
  }

  static Widget _actionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF16213E),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Colors.white12),
          ),
        ),
      ),
    );
  }

  static void _showReceiptPreview(
      BuildContext context, PaymentReceiptWidget receipt) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Close button
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            // Receipt
            SingleChildScrollView(
              child: receipt,
            ),
          ],
        ),
      ),
    );
  }
}
