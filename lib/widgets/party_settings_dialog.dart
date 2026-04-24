import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class PartySettingsDialog extends StatefulWidget {
  final bool isChatVisible;
  final bool isMicOn;
  final bool isCameraOn;
  final double beautyFilterValue;
  final Function(bool) onChatVisibilityChanged;
  final Function(bool) onMicChanged;
  final Function(bool) onCameraChanged;
  final Function(double) onBeautyFilterChanged;
  final VoidCallback onBackgroundPressed;
  final VoidCallback onMusicPressed;
  final VoidCallback onTasksPressed;
  final VoidCallback onTopUpPressed;

  const PartySettingsDialog({
    super.key,
    required this.isChatVisible,
    required this.isMicOn,
    required this.isCameraOn,
    required this.beautyFilterValue,
    required this.onChatVisibilityChanged,
    required this.onMicChanged,
    required this.onCameraChanged,
    required this.onBeautyFilterChanged,
    required this.onBackgroundPressed,
    required this.onMusicPressed,
    required this.onTasksPressed,
    required this.onTopUpPressed,
  });

  @override
  State<PartySettingsDialog> createState() => _PartySettingsDialogState();
}

class _PartySettingsDialogState extends State<PartySettingsDialog> {
  late bool _isChatVisible;
  late bool _isMicOn;
  late bool _isCameraOn;
  late double _beautyFilterValue;

  @override
  void initState() {
    super.initState();
    _isChatVisible = widget.isChatVisible;
    _isMicOn = widget.isMicOn;
    _isCameraOn = widget.isCameraOn;
    _beautyFilterValue = widget.beautyFilterValue;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Text(
                  'Room Settings',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // Settings List
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildSectionTitle('Customization'),
                  _buildSettingTile(
                    icon: Icons.image,
                    iconColor: Colors.blue,
                    title: 'Change Background',
                    subtitle: 'Select room theme',
                    onTap: widget.onBackgroundPressed,
                  ),
                  _buildSettingTile(
                    icon: Icons.music_note,
                    iconColor: Colors.purple,
                    title: 'Play Music',
                    subtitle: 'Add background music',
                    onTap: widget.onMusicPressed,
                  ),

                  const Divider(height: 1),
                  _buildSectionTitle('Features'),

                  _buildToggleTile(
                    icon: Icons.message,
                    iconColor: Colors.green,
                    title: 'Message Box',
                    subtitle: 'Show/hide chat messages',
                    value: _isChatVisible,
                    onChanged: (value) {
                      setState(() => _isChatVisible = value);
                      widget.onChatVisibilityChanged(value);
                    },
                  ),

                  _buildSettingTile(
                    icon: Icons.task_alt,
                    iconColor: Colors.orange,
                    title: 'Tasks',
                    subtitle: 'View daily tasks',
                    onTap: widget.onTasksPressed,
                  ),

                  _buildSettingTile(
                    icon: Icons.attach_money,
                    iconColor: Colors.amber,
                    title: 'Top Up',
                    subtitle: 'Buy coins & diamonds',
                    onTap: widget.onTopUpPressed,
                  ),

                  const Divider(height: 1),
                  _buildSectionTitle('Audio & Video'),

                  _buildToggleTile(
                    icon: _isMicOn ? Icons.mic : Icons.mic_off,
                    iconColor: _isMicOn ? Colors.green : Colors.red,
                    title: 'Microphone',
                    subtitle: _isMicOn ? 'Mic is ON' : 'Mic is OFF',
                    value: _isMicOn,
                    onChanged: (value) {
                      setState(() => _isMicOn = value);
                      widget.onMicChanged(value);
                    },
                  ),

                  _buildToggleTile(
                    icon: _isCameraOn ? Icons.videocam : Icons.videocam_off,
                    iconColor: _isCameraOn ? Colors.green : Colors.red,
                    title: 'Camera',
                    subtitle: _isCameraOn ? 'Video is ON' : 'Video is OFF',
                    value: _isCameraOn,
                    onChanged: (value) {
                      setState(() => _isCameraOn = value);
                      widget.onCameraChanged(value);
                    },
                  ),

                  const Divider(height: 1),
                  _buildSectionTitle('Beauty'),

                  _buildSliderTile(
                    icon: Icons.face_retouching_natural,
                    iconColor: Colors.pink,
                    title: 'Beauty Filter',
                    subtitle: 'Adjust face enhancement',
                    value: _beautyFilterValue,
                    onChanged: (value) {
                      setState(() => _beautyFilterValue = value);
                      widget.onBeautyFilterChanged(value);
                    },
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      color: Colors.grey.shade100,
      child: Text(
        title,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 20, color: iconColor),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 9,
          color: Colors.grey.shade600,
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: 14,
        color: Colors.grey.shade400,
      ),
    );
  }

  Widget _buildToggleTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 20, color: iconColor),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 9,
          color: Colors.grey.shade600,
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: AppColors.primary,
      ),
    );
  }

  Widget _buildSliderTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required double value,
    required Function(double) onChanged,
  }) {
    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(
              fontSize: 9,
              color: Colors.grey.shade600,
            ),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${(value * 100).toInt()}%',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              const SizedBox(width: 48),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: AppColors.primary,
                    inactiveTrackColor: Colors.grey.shade300,
                    thumbColor: AppColors.primary,
                    overlayColor: AppColors.primary.withOpacity(0.2),
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                  ),
                  child: Slider(
                    value: value,
                    onChanged: onChanged,
                    min: 0.0,
                    max: 1.0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Helper function to show the dialog
void showPartySettingsDialog({
  required BuildContext context,
  required bool isChatVisible,
  required bool isMicOn,
  required bool isCameraOn,
  required double beautyFilterValue,
  required Function(bool) onChatVisibilityChanged,
  required Function(bool) onMicChanged,
  required Function(bool) onCameraChanged,
  required Function(double) onBeautyFilterChanged,
  required VoidCallback onBackgroundPressed,
  required VoidCallback onMusicPressed,
  required VoidCallback onTasksPressed,
  required VoidCallback onTopUpPressed,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => PartySettingsDialog(
      isChatVisible: isChatVisible,
      isMicOn: isMicOn,
      isCameraOn: isCameraOn,
      beautyFilterValue: beautyFilterValue,
      onChatVisibilityChanged: onChatVisibilityChanged,
      onMicChanged: onMicChanged,
      onCameraChanged: onCameraChanged,
      onBeautyFilterChanged: onBeautyFilterChanged,
      onBackgroundPressed: onBackgroundPressed,
      onMusicPressed: onMusicPressed,
      onTasksPressed: onTasksPressed,
      onTopUpPressed: onTopUpPressed,
    ),
  );
}