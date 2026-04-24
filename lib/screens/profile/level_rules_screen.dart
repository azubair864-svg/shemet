import 'package:flutter/material.dart';

class LevelRulesScreen extends StatelessWidget {
  const LevelRulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Level Rules',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [const Color(0xFF9B6FD7), const Color(0xFFE91E63)],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Level Rule',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'The level is based on historical top-up or consumption, taking the maximum of top-up or consumption.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                      height: 1.5,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Consumption includes gift sending, video call spending, and group packet spending.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Level Table
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Level Requirements',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildLevelTable(),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Note
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Colors.orange.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'When your balance is ≤ 2000 diamonds, Level will become Lv0.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.orange.shade700,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelTable() {
    final levels = [
      {'level': 'Lv0', 'diamonds': '0', 'color': Colors.grey},
      {'level': 'Lv1', 'diamonds': '10,000', 'color': const Color(0xFF9B6FD7)},
      {'level': 'Lv2', 'diamonds': '30,000', 'color': Colors.blue},
      {'level': 'Lv3', 'diamonds': '100,000', 'color': Colors.cyan},
      {'level': 'Lv4', 'diamonds': '300,000', 'color': Colors.green},
      {'level': 'Lv5', 'diamonds': '1,000,000', 'color': Colors.orange},
      {'level': 'Lv6', 'diamonds': '3,000,000', 'color': Colors.deepOrange},
      {'level': 'Lv7', 'diamonds': '10,000,000', 'color': Colors.red},
      {'level': 'Lv8', 'diamonds': '30,000,000', 'color': Colors.purple},
      {'level': 'Lv9', 'diamonds': '100,000,000', 'color': Colors.pink},
      {'level': 'Lv10', 'diamonds': '300,000,000', 'color': Colors.indigo},
      {
        'level': 'Lv20',
        'diamonds': '1,000,000,000',
        'color': Colors.deepPurple,
      },
      {'level': 'Lv30', 'diamonds': '3,000,000,000', 'color': Colors.teal},
      {'level': 'Lv40', 'diamonds': '10,000,000,000', 'color': Colors.amber},
      {'level': 'Lv50', 'diamonds': '30,000,000,000', 'color': Colors.brown},
    ];

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              children: const [
                Expanded(
                  child: Text(
                    'Level',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Top-up/Consumption',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
          // Rows
          ...levels.map(
            (level) => _buildLevelRow(
              level['level'] as String,
              level['diamonds'] as String,
              level['color'] as Color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelRow(String level, String diamonds, Color color) {
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero, // ← FIXED: Removed const
          title: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          level,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Text(
                    diamonds,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: Colors.grey.shade200),
      ],
    );
  }
}
