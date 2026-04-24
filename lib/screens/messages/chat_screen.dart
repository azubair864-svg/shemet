import 'package:flutter/material.dart';
import 'package:flutter_windowmanager_plus/flutter_windowmanager_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../services/database_service.dart';
import '../../services/audio_service.dart';
import '../../models/user_model.dart';
import '../../models/gift_model.dart';
import '../../models/call_model.dart';
import '../../services/call_service.dart';
import '../../core/constants/app_colors.dart';
import '../../widgets/chat/chat_input_enhanced.dart';
import '../../widgets/chat/voice_message_player.dart';
import '../../widgets/chat/chat_gift_selector_sheet.dart';
import '../../widgets/chat/chat_gift_animation.dart';
import '../../widgets/chat/message_reaction_picker.dart';
import '../../widgets/chat/message_options_menu.dart';
import '../../widgets/chat/typing_indicator_widget.dart';
import '../../services/translation_service.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final UserModel otherUser;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.otherUser,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final DatabaseService _databaseService = DatabaseService();
  final AudioService _audioService = AudioService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  bool _isUploading = false;
  bool _isTyping = false;
  bool _showTranslation = false;
  final Map<String, String> _translations = {};
  final TranslationService _translationService = TranslationService();

  @override
  void initState() {
    super.initState();
    _enableScreenshotProtection();
    _markMessagesAsRead();
    _messageController.addListener(_onTextChanged);
  }

  Future<void> _enableScreenshotProtection() async {
    await FlutterWindowManagerPlus.addFlags(FlutterWindowManagerPlus.FLAG_SECURE);
  }

  @override
  void dispose() {
    _disableScreenshotProtection();
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _scrollController.dispose();
    _audioService.dispose();
    _updateTypingStatus(false);
    super.dispose();
  }

  Future<void> _disableScreenshotProtection() async {
    await FlutterWindowManagerPlus.clearFlags(FlutterWindowManagerPlus.FLAG_SECURE);
  }

  void _onTextChanged() {
    final text = _messageController.text;
    _updateTypingStatus(text.trim().isNotEmpty);
  }

  void _updateTypingStatus(bool isTyping) {
    if (_isTyping != isTyping) {
      _isTyping = isTyping;
      _databaseService.updateTypingStatus(
        chatId: widget.chatId,
        userId: _currentUserId,
        isTyping: isTyping,
      );
    }
  }

  Future<void> _markMessagesAsRead() async {
    await _databaseService.markMessagesAsRead(
      chatId: widget.chatId,
      userId: _currentUserId,
    );
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();
    _updateTypingStatus(false);

    await _databaseService.sendMessage(
      chatId: widget.chatId,
      senderId: _currentUserId,
      text: text,
      type: 'text',
    );

    _scrollToBottom();
  }

  // Compress Chat Image
  Future<String?> _compressChatImage(String imagePath) async {
    
    

    try {
      final originalFile = File(imagePath);
      final originalSize = await originalFile.length();
      

      final compressedBytes = await FlutterImageCompress.compressWithFile(
        imagePath,
        quality: 70,
        minWidth: 1080,
        minHeight: 1080,
      );

      if (compressedBytes == null) {
        
        return imagePath;
      }

      
      final reduction = ((1 - (compressedBytes.length / originalSize)) * 100).toStringAsFixed(1);
      

      // Write compressed bytes to new file
      final compressedPath = imagePath.replaceAll('.jpg', '_compressed.jpg');
      final compressedFile = File(compressedPath);
      await compressedFile.writeAsBytes(compressedBytes);

      
      

      return compressedPath;
    } catch (e) {
      
      
      
      
      return imagePath;
    }
  }

  Future<void> _pickImage() async {
    
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1080,
      maxHeight: 1080,
      imageQuality: 85,
    );

    if (image != null) {
      
      setState(() => _isUploading = true);

      try {
        // Compress image first
        
        final compressedPath = await _compressChatImage(image.path);

        if (compressedPath == null) {
          
          setState(() => _isUploading = false);
          return;
        }

        
        final imageUrl = await _databaseService.uploadChatImage(
          widget.chatId,
          compressedPath,
        );

        if (imageUrl != null) {
          
          await _databaseService.sendMessage(
            chatId: widget.chatId,
            senderId: _currentUserId,
            text: '',
            type: 'image',
            imageUrl: imageUrl,
          );
          

          // Clean up compressed file if different from original
          try {
            if (compressedPath != image.path) {
              await File(compressedPath).delete();
              
            }
          } catch (e) {
            
          }
        } else {
          
        }
      } catch (e) {
        
        
        
      }

      setState(() => _isUploading = false);
      _scrollToBottom();
      
    } else {
      
    }
  }

  Future<void> _sendVoiceMessage(String path, int duration) async {
    setState(() => _isUploading = true);

    final result = await _audioService.uploadVoiceMessage(
      filePath: path,
      chatId: widget.chatId,
    );

    if (result != null) {
      await _databaseService.sendVoiceMessage(
        chatId: widget.chatId,
        senderId: _currentUserId,
        voiceUrl: result['url'],
        duration: result['duration'],
      );
    }

    setState(() => _isUploading = false);
    _scrollToBottom();
  }

  void _showGiftSelector() {
    final userProvider = context.read<UserProvider>();
    final userDiamonds = userProvider.currentUser?.diamonds ?? 0;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ChatGiftSelectorSheet(
        userDiamonds: userDiamonds,
        onSendGift: _sendGiftMessage,
      ),
    );
  }

  Future<void> _sendGiftMessage(GiftModel gift) async {
    await _databaseService.sendGiftInChat(
      chatId: widget.chatId,
      senderId: _currentUserId,
      giftId: gift.id,
      giftName: gift.name,
      giftEmoji: gift.emoji,
      giftValue: gift.price,
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ChatGiftAnimation(
        giftEmoji: gift.emoji,
        senderName: 'You',
        onComplete: () => Navigator.pop(context),
      ),
    );

    _scrollToBottom();
  }

  void _showReactionPicker(String messageId) {
    MessageReactionPicker.show(
      context: context,
      onReactionSelected: (emoji) {
        _addReaction(messageId, emoji);
      },
    );
  }

  Future<void> _addReaction(String messageId, String emoji) async {
    await _databaseService.addReaction(
      chatId: widget.chatId,
      messageId: messageId,
      userId: _currentUserId,
      emoji: emoji,
    );
  }

  void _showMessageOptions(Map<String, dynamic> message) {
    MessageOptionsMenu.show(
      context: context,
      messageId: message['messageId'],
      messageText: message['text'] ?? '',
      isMe: message['senderId'] == _currentUserId,
      onReact: () => _showReactionPicker(message['messageId']),
      onDelete: () => _deleteMessage(message['messageId']),
      onReply: () => _replyToMessage(message),
      onForward: () => _forwardMessage(message),
    );
  }

  Future<void> _deleteMessage(String messageId) async {
    await _databaseService.deleteMessage(
      chatId: widget.chatId,
      messageId: messageId,
    );
  }

  void _replyToMessage(Map<String, dynamic> message) {
    
  }

  void _forwardMessage(Map<String, dynamic> message) {
    
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.purple.shade900.withOpacity(0.2),
                  Colors.black,
                ],
              ),
            ),
          ),

          // Content
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(),
                Expanded(
                  child: StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _databaseService.getChatMessages(widget.chatId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(color: AppColors.primary),
                        );
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            'Error: ${snapshot.error}',
                            style: const TextStyle(color: Colors.white),
                          ),
                        );
                      }

                      final messages = snapshot.data ?? [];

                      if (messages.isEmpty) {
                        return _buildEmptyState();
                      }

                      return Column(
                        children: [
                          StreamBuilder<bool>(
                            stream: _databaseService.getTypingStatus(
                              widget.chatId,
                              widget.otherUser.uid,
                            ),
                            builder: (context, typingSnapshot) {
                              if (typingSnapshot.data == true) {
                                return TypingIndicatorWidget(
                                  userName: widget.otherUser.name,
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                          Expanded(
                            child: ListView.builder(
                              controller: _scrollController,
                              reverse: true,
                              padding: const EdgeInsets.all(16),
                              itemCount: messages.length,
                              itemBuilder: (context, index) {
                                final message = messages[index];
                                return _buildMessageBubble(message);
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                ChatInputEnhanced(
                  messageController: _messageController,
                  audioService: _audioService,
                  onSendText: _sendMessage,
                  onPickImage: _pickImage,
                  onSendGift: _showGiftSelector,
                  onSendVoice: _sendVoiceMessage,
                  onTypingChanged: (text) => _updateTypingStatus(text.isNotEmpty),
                  isUploading: _isUploading,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.black.withOpacity(0.8),
            Colors.transparent,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
            ),
          ),
          const SizedBox(width: 12),
          Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, Color(0xFFFF69B4)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 10,
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(2),
                child: CircleAvatar(
                  radius: 22,
                  backgroundImage: widget.otherUser.photos.isNotEmpty
                      ? CachedNetworkImageProvider(widget.otherUser.photos[0])
                      : null,
                  child: widget.otherUser.photos.isEmpty
                      ? Text(
                    widget.otherUser.name[0].toUpperCase(),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                      : null,
                ),
              ),
              if (widget.otherUser.isOnline ?? false)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.otherUser.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  widget.otherUser.isOnline ?? false ? 'Online' : 'Offline',
                  style: TextStyle(
                    color: widget.otherUser.isOnline ?? false
                        ? Colors.green
                        : Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () async {
              final currentUserId = FirebaseAuth.instance.currentUser?.uid;
              if (currentUserId == null) return;

              try {
                final callId = await CallService().initiateCall(
                  callerId: currentUserId,
                  callerName: FirebaseAuth.instance.currentUser?.displayName ?? 'User',
                  callerPhoto: FirebaseAuth.instance.currentUser?.photoURL,
                  receiverId: widget.otherUser.uid,
                  receiverName: widget.otherUser.name,
                  receiverPhoto: widget.otherUser.photos.isNotEmpty ? widget.otherUser.photos[0] : null,
                  type: CallType.video,
                );

                if (!mounted) return;
                Navigator.pushNamed(
                  context,
                  '/video_call',
                  arguments: {
                    'callId': callId,
                    'otherUser': widget.otherUser,
                    'isOutgoing': true,
                  },
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to start video call: $e')),
                );
              }
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.videocam, color: AppColors.primary, size: 22),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              setState(() {
                _showTranslation = !_showTranslation;
              });
              if (_showTranslation) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Translation Enabled (to Sinhala for demo)'),
                    duration: Duration(seconds: 1),
                  ),
                );
              }
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _showTranslation 
                    ? AppColors.primary.withOpacity(0.5) 
                    : Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: _showTranslation 
                    ? Border.all(color: AppColors.primary, width: 1) 
                    : null,
              ),
              child: const Icon(Icons.translate, color: Colors.white, size: 22),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _showMoreOptions,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.more_vert, color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message) {
    final type = message['type'] as String? ?? 'text';
    final isMe = message['senderId'] == _currentUserId;

    Widget messageWidget;

    if (type == 'voice') {
      messageWidget = VoiceMessagePlayer(
        voiceUrl: message['voiceUrl'] ?? '',
        duration: message['voiceDuration'] ?? 0,
        isMe: isMe,
        audioService: _audioService,
      );
    } else if (type == 'gift') {
      messageWidget = _buildGiftBubble(message, isMe);
    } else if (type == 'image') {
      messageWidget = _buildImageBubble(message, isMe);
    } else {
      messageWidget = _buildTextBubble(message, isMe);
    }

    return GestureDetector(
      onLongPress: () => _showMessageOptions(message),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Align(
            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.7,
              ),
              child: messageWidget,
            ),
          ),
          if (message['reactions'] != null &&
              (message['reactions'] as Map).isNotEmpty)
            _buildReactions(message['reactions'] as Map),
        ],
      ),
    );
  }

  Widget _buildTextBubble(Map<String, dynamic> message, bool isMe) {
    final timestamp = message['timestamp'] as Timestamp?;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: isMe
            ? const LinearGradient(
                colors: [AppColors.primary, Color(0xFFFF69B4)],
              )
            : null,
        color: isMe ? null : Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(20),
          topRight: const Radius.circular(20),
          bottomLeft: isMe ? const Radius.circular(20) : Radius.zero,
          bottomRight: isMe ? Radius.zero : const Radius.circular(20),
        ),
        border: Border.all(
          color: isMe ? Colors.transparent : Colors.white.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isMe
                ? AppColors.primary.withOpacity(0.3)
                : Colors.black.withOpacity(0.3),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message['text'] ?? '',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
            ),
          ),
          if (timestamp != null) ...[
            const SizedBox(height: 6),
            Text(
              _formatMessageTime(timestamp),
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 11,
              ),
            ),
          ],
          if (_showTranslation && !isMe) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: FutureBuilder<String>(
                future: _translations.containsKey(message['messageId'])
                    ? Future.value(_translations[message['messageId']])
                    : _translationService
                        .translate(
                            text: message['text'] ?? '',
                            targetLanguage: 'si' // Demo language
                            )
                        .then((value) {
                        _translations[message['messageId']] = value;
                        return value;
                      }),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                          strokeWidth: 1, color: Colors.white54),
                    );
                  }
                  return Text(
                    snapshot.data ?? '...',
                    style: TextStyle(
                      color: Colors.amber.shade300,
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildImageBubble(Map<String, dynamic> message, bool isMe) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 10,
            ),
          ],
        ),
        child: CachedNetworkImage(
          imageUrl: message['imageUrl'] ?? '',
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            height: 200,
            alignment: Alignment.center,
            child: const CircularProgressIndicator(color: AppColors.primary),
          ),
          errorWidget: (context, url, error) => Container(
            height: 200,
            alignment: Alignment.center,
            child: const Icon(Icons.error, color: Colors.red),
          ),
        ),
      ),
    );
  }

  Widget _buildGiftBubble(Map<String, dynamic> message, bool isMe) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.purple.withOpacity(0.3),
            Colors.pink.withOpacity(0.3),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.pink.withOpacity(0.5),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.pink.withOpacity(0.5),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            message['giftEmoji'] ?? '🎁',
            style: const TextStyle(fontSize: 56),
          ),
          const SizedBox(height: 12),
          Text(
            message['giftName'] ?? 'Gift',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.amber, Colors.orange],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${message['giftValue'] ?? 0} 💎',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReactions(Map reactions) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, top: 4, bottom: 8),
      child: Wrap(
        spacing: 6,
        children: reactions.entries.map((entry) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.2),
                  Colors.white.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Text(
              entry.value as String,
              style: const TextStyle(fontSize: 18),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  Colors.purple.shade700.withOpacity(0.2),
                  Colors.pink.shade700.withOpacity(0.2),
                ],
              ),
            ),
            child: Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: Colors.white.withOpacity(0.3),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No messages yet',
            style: TextStyle(
              fontSize: 18,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Say hi to ${widget.otherUser.name}!',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  String _formatMessageTime(Timestamp timestamp) {
    final dateTime = timestamp.toDate();
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<void> _handleBlock() async {
    final success = await _databaseService.blockUser(
      blockerId: _currentUserId,
      blockedId: widget.otherUser.uid,
    );

    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.otherUser.name} has been blocked'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.pop(context); // Exit chat after block
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to block user. Please try again.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  void _showBlockConfirm() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text('Block User', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to block ${widget.otherUser.name}? They will no longer be able to message you.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _handleBlock();
            },
            child: const Text('Block', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showReportDialog() {
    final reasons = [
      'Spam or Scam',
      'Inappropriate Content',
      'Harassment or Bullying',
      'Fake Profile',
      'Underage User',
      'Other',
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Report User', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: reasons.map((reason) => ListTile(
            title: Text(reason, style: const TextStyle(color: Colors.white70)),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () async {
              Navigator.pop(context);
              final success = await _databaseService.reportUser(
                reporterId: _currentUserId,
                reportedUserId: widget.otherUser.uid,
                reason: reason,
                description: 'Reported via Chat Screen',
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success 
                      ? 'Report submitted. Thank you for keeping us safe.' 
                      : 'Failed to submit report.'),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
              }
            },
          )).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.grey.shade900, Colors.black],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, Color(0xFFFF69B4)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.person, color: Colors.white, size: 20),
              ),
              title: const Text('View Profile', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(
                  context,
                  '/user_profile_detail',
                  arguments: widget.otherUser,
                );
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.photo_library, color: AppColors.primary, size: 20),
              ),
              title: const Text('Shared Media', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.block, color: Colors.red, size: 20),
              ),
              title: const Text('Block User', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _showBlockConfirm();
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.report, color: Colors.orange, size: 20),
              ),
              title: const Text('Report', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _showReportDialog();
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.delete, color: Colors.red, size: 20),
              ),
              title: const Text('Delete Chat', style: TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(context);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: Colors.grey.shade900,
                    title: const Text('Delete Chat', style: TextStyle(color: Colors.white)),
                    content: const Text(
                      'Are you sure you want to delete this chat?',
                      style: TextStyle(color: Colors.white70),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Delete', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  await _databaseService.deleteChat(widget.chatId);
                  if (mounted) Navigator.pop(context);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}