import 'package:flutter/material.dart';

/// Network Quality Indicator Widget
/// Displays connection quality during calls
/// Quality levels: 0=unknown, 1=excellent, 2=good, 3=poor, 4=bad, 5=very bad, 6=down
class NetworkQualityIndicator extends StatelessWidget {
  final int quality; // 0-6
  final bool showLabel;

  const NetworkQualityIndicator({
    super.key,
    required this.quality,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    final qualityData = _getQualityData(quality);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Signal bars
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(4, (index) {
              final barHeight = 4.0 + (index * 3.0);
              final isActive = index < qualityData.bars;

              return Container(
                width: 3,
                height: barHeight,
                margin: const EdgeInsets.only(right: 2),
                decoration: BoxDecoration(
                  color: isActive ? qualityData.color : Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(1),
                ),
              );
            }),
          ),
          if (showLabel) ...[
            const SizedBox(width: 8),
            Text(
              qualityData.label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  _QualityData _getQualityData(int quality) {
    switch (quality) {
      case 1: // Excellent
        return _QualityData(
          bars: 4,
          color: Colors.green,
          label: 'Excellent',
        );
      case 2: // Good
        return _QualityData(
          bars: 3,
          color: Colors.lightGreen,
          label: 'Good',
        );
      case 3: // Poor
        return _QualityData(
          bars: 2,
          color: Colors.orange,
          label: 'Poor',
        );
      case 4: // Bad
        return _QualityData(
          bars: 1,
          color: Colors.red,
          label: 'Bad',
        );
      case 5: // Very Bad
        return _QualityData(
          bars: 1,
          color: Colors.red,
          label: 'Very Bad',
        );
      case 6: // Down
        return _QualityData(
          bars: 0,
          color: Colors.grey,
          label: 'No Connection',
        );
      default: // Unknown
        return _QualityData(
          bars: 4,
          color: Colors.grey,
          label: 'Connecting...',
        );
    }
  }
}

class _QualityData {
  final int bars;
  final Color color;
  final String label;

  _QualityData({
    required this.bars,
    required this.color,
    required this.label,
  });
}

/// Compact version for small spaces
class NetworkQualityBadge extends StatelessWidget {
  final int quality;

  const NetworkQualityBadge({
    super.key,
    required this.quality,
  });

  @override
  Widget build(BuildContext context) {
    final color = _getQualityColor(quality);

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        shape: BoxShape.circle,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(3, (index) {
          final barHeight = 3.0 + (index * 2.0);
          final bars = _getQualityBars(quality);
          final isActive = index < bars;

          return Container(
            width: 2,
            height: barHeight,
            margin: const EdgeInsets.only(right: 1.5),
            decoration: BoxDecoration(
              color: isActive ? color : Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(1),
            ),
          );
        }),
      ),
    );
  }

  int _getQualityBars(int quality) {
    switch (quality) {
      case 1:
        return 3; // Excellent
      case 2:
        return 2; // Good
      case 3:
      case 4:
        return 1; // Poor/Bad
      default:
        return 0; // Very Bad/Down/Unknown
    }
  }

  Color _getQualityColor(int quality) {
    switch (quality) {
      case 1:
        return Colors.green;
      case 2:
        return Colors.lightGreen;
      case 3:
        return Colors.orange;
      case 4:
      case 5:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
