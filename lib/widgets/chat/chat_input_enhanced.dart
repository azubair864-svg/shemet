import 'package:flutter/material.dart';
import '../../services/audio_service.dart';
import '../../core/constants/app_colors.dart';
import 'voice_message_recorder.dart';

class ChatInputEnhanced extends StatefulWidget {
  final TextEditingController messageController;
  final VoidCallback onSendText;
  final VoidCallback onPickImage;
  final VoidCallback onSendGift;
  final Function(String path, int duration) onSendVoice;
  final Function(String text) onTypingChanged;
  final bool isUploading;
  final AudioService audioService;

  const ChatInputEnhanced({
    super.key,
    required this.messageController,
    required this.onSendText,
    required this.onPickImage,
    required this.onSendGift,
    required this.onSendVoice,
    required this.onTypingChanged,
    required this.audioService,
    this.isUploading = false,
  });

  @override
  State<ChatInputEnhanced> createState() => _ChatInputEnhancedState();
}

class _ChatInputEnhancedState extends State<ChatInputEnhanced> {
  bool _showVoiceButton = true;
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    widget.messageController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.messageController.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final text = widget.messageController.text;
    setState(() {
      _showVoiceButton = text.trim().isEmpty;
    });
    widget.onTypingChanged(text);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Upload indicator
            if (widget.isUploading)
              Container(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Uploading...',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),

            // Input Row
            Row(
              children: [
                // Additional options button
                IconButton(
                  icon: Icon(Icons.add_circle_outline, color: Colors.grey.shade600),
                  onPressed: _showAdditionalOptions,
                ),

                // Text input field
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Row(
                      children: [
                        // Camera button
                        IconButton(
                          icon: Icon(Icons.camera_alt, color: Colors.grey.shade600, size: 20),
                          onPressed: widget.isUploading ? null : widget.onPickImage,
                        ),

                        // Text field
                        Expanded(
                          child: TextField(
                            controller: widget.messageController,
                            decoration: InputDecoration(
                              hintText: 'Type a message...',
                              hintStyle: TextStyle(color: Colors.grey.shade400),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 10,
                              ),
                            ),
                            maxLines: null,
                            textCapitalization: TextCapitalization.sentences,
                          ),
                        ),

                        // Gift button
                        IconButton(
                          icon: Icon(Icons.card_giftcard, color: Colors.pink.shade300, size: 20),
                          onPressed: widget.onSendGift,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Send button or Voice recorder
                if (_showVoiceButton && !_isRecording)
                  VoiceMessageRecorder(
                    audioService: widget.audioService,
                    onRecordingComplete: (path, duration) {
                      widget.onSendVoice(path, duration);
                      setState(() => _isRecording = false);
                    },
                  )
                else
                  GestureDetector(
                    onTap: widget.onSendText,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.primary, Color(0xFFFF1493)],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.send, color: Colors.white, size: 20),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAdditionalOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              // Gallery
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.photo_library, color: Colors.purple),
                ),
                title: const Text('Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  widget.onPickImage();
                },
              ),

              // Gift
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.pink.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.card_giftcard, color: Colors.pink),
                ),
                title: const Text('Send Gift'),
                onTap: () {
                  Navigator.pop(context);
                  widget.onSendGift();
                },
              ),

              // Voice Message
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.mic, color: Colors.red),
                ),
                title: const Text('Voice Message'),
                subtitle: const Text('Hold to record'),
                onTap: () {
                  Navigator.pop(context);
                },
              ),

              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}