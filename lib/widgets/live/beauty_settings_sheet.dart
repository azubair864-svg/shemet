import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import '../../services/agora_service.dart';

class BeautySettingsSheet extends StatefulWidget {
  const BeautySettingsSheet({super.key});

  @override
  State<BeautySettingsSheet> createState() => _BeautySettingsSheetState();
}

class _BeautySettingsSheetState extends State<BeautySettingsSheet> {
  final AgoraService _agoraService = AgoraService();
  bool _isEnabled = true;
  double _smoothness = 0.5;
  double _lightening = 0.5;
  double _redness = 0.1;
  double _sharpness = 0.1;

  void _updateBeautyEffect() {
    _agoraService.setBeautyEffectOptions(
      enabled: _isEnabled,
      options: BeautyOptions(
        lighteningLevel: _lightening,
        smoothnessLevel: _smoothness,
        rednessLevel: _redness,
        sharpnessLevel: _sharpness,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Beauty Effects',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Switch(
                value: _isEnabled,
                activeThumbColor: const Color(0xFFFF1493),
                onChanged: (val) {
                  setState(() => _isEnabled = val);
                  _updateBeautyEffect();
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildSlider('Smoothness', _smoothness, (val) => _smoothness = val),
          _buildSlider('Whitening', _lightening, (val) => _lightening = val),
          _buildSlider('Rosy', _redness, (val) => _redness = val),
          _buildSlider('Sharpness', _sharpness, (val) => _sharpness = val),
        ],
      ),
    );
  }

  Widget _buildSlider(String label, double value, Function(double) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.white70)),
            Text((value * 100).toInt().toString(), style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: const Color(0xFFFF1493),
            inactiveTrackColor: Colors.grey[800],
            thumbColor: Colors.white,
            overlayColor: const Color(0xFFFF1493).withOpacity(0.2),
          ),
          child: Slider(
            value: value,
            min: 0.0,
            max: 1.0,
            onChanged: _isEnabled ? (val) {
              setState(() => onChanged(val));
              _updateBeautyEffect();
            } : null,
          ),
        ),
      ],
    );
  }
}
