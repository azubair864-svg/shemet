import 'package:flutter/material.dart';

class VideoSettingsSheet extends StatefulWidget {
  const VideoSettingsSheet({super.key});

  @override
  State<VideoSettingsSheet> createState() => _VideoSettingsSheetState();
}

class _VideoSettingsSheetState extends State<VideoSettingsSheet> {
  bool _voiceToText = false;
  bool _mirrorMode = false;
  bool _switchCamera = true;
  bool _microphone = true;
  final String _selectedLanguage = 'Kannada';

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: ListView(
        shrinkWrap: true,
        children: [
          const SizedBox(height: 16),

          // Voice to Text
          _buildToggleItem(
            icon: Icons.mic,
            title: 'Voice to Text',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.diamond, color: Colors.orange, size: 16),
                const SizedBox(width: 4),
                const Text(
                  '200/min',
                  style: TextStyle(color: Colors.orange, fontSize: 12),
                ),
                const SizedBox(width: 8),
                Switch(
                  value: _voiceToText,
                  onChanged: (value) {
                    setState(() {
                      _voiceToText = value;
                    });
                  },
                  activeThumbColor: const Color(0xFF9B6FD7),
                ),
              ],
            ),
          ),

          const Divider(),

          // Voice Language
          _buildNavigationItem(
            icon: Icons.language,
            title: 'Voice Language',
            trailing: Text(
              _selectedLanguage,
              style: const TextStyle(color: Colors.grey),
            ),
            onTap: () {
              // Show language selector
            },
          ),

          const Divider(),

          // Sticker
          _buildNavigationItem(
            icon: Icons.emoji_emotions_outlined,
            title: 'Sticker',
            onTap: () {
              // Show stickers
            },
          ),

          const Divider(),

          // Beauty
          _buildNavigationItem(
            icon: Icons.face_retouching_natural,
            title: 'Beauty',
            onTap: () {
              // Show beauty filters
            },
          ),

          const Divider(),

          // Mirror Mode
          _buildToggleItem(
            icon: Icons.flip,
            title: 'Mirror Mode',
            trailing: Switch(
              value: _mirrorMode,
              onChanged: (value) {
                setState(() {
                  _mirrorMode = value;
                });
              },
              activeThumbColor: const Color(0xFF9B6FD7),
            ),
          ),

          const Divider(),

          // Switch the Camera
          _buildToggleItem(
            icon: Icons.cameraswitch,
            title: 'Switch the Camera',
            trailing: Switch(
              value: _switchCamera,
              onChanged: (value) {
                setState(() {
                  _switchCamera = value;
                });
              },
              activeThumbColor: const Color(0xFF9B6FD7),
            ),
          ),

          const Divider(),

          // Microphone
          _buildToggleItem(
            icon: Icons.mic,
            title: 'Microphone',
            trailing: Switch(
              value: _microphone,
              onChanged: (value) {
                setState(() {
                  _microphone = value;
                });
              },
              activeThumbColor: const Color(0xFF9B6FD7),
            ),
          ),

          const Divider(),

          // Report
          _buildNavigationItem(
            icon: Icons.report_outlined,
            title: 'Report',
            onTap: () {
              // Show report dialog
            },
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildToggleItem({
    required IconData icon,
    required String title,
    required Widget trailing,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey.shade700),
      title: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      ),
      trailing: trailing,
    );
  }

  Widget _buildNavigationItem({
    required IconData icon,
    required String title,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey.shade700),
      title: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      ),
      trailing: trailing ?? const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const VideoSettingsSheet(),
    );
  }
}
