import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/database_service.dart';
import '../../core/constants/app_colors.dart';

class ChatSettingsScreen extends StatefulWidget {
  final String chatId;
  final UserModel otherUser;

  const ChatSettingsScreen({
    super.key,
    required this.chatId,
    required this.otherUser,
  });

  @override
  State<ChatSettingsScreen> createState() => _ChatSettingsScreenState();
}

class _ChatSettingsScreenState extends State<ChatSettingsScreen> {
  final DatabaseService _databaseService = DatabaseService();
  bool _isMuted = false;
  bool _isBlocked = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Chat Settings',
          style: TextStyle(color: Colors.black),
        ),
      ),
      body: ListView(
        children: [
          // User Info
          Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundImage: widget.otherUser.photos.isNotEmpty
                      ? NetworkImage(widget.otherUser.photos[0])
                      : null,
                  child: widget.otherUser.photos.isEmpty
                      ? Text(
                    widget.otherUser.name[0].toUpperCase(),
                    style: const TextStyle(fontSize: 32),
                  )
                      : null,
                ),
                const SizedBox(height: 12),
                Text(
                  widget.otherUser.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  widget.otherUser.isOnline ?? false ? 'Online' : 'Offline',
                  style: TextStyle(
                    color: widget.otherUser.isOnline ?? false
                        ? Colors.green
                        : Colors.grey,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // View Profile
          ListTile(
            leading: const Icon(Icons.person, color: AppColors.primary),
            title: const Text('View Profile'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.pushNamed(
                context,
                '/user_profile_detail',
                arguments: widget.otherUser,
              );
            },
          ),

          // Shared Media
          ListTile(
            leading: const Icon(Icons.photo_library, color: AppColors.primary),
            title: const Text('Shared Media'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.pushNamed(
                context,
                '/chat_media',
                arguments: widget.chatId,
              );
            },
          ),

          const Divider(height: 1),
          const SizedBox(height: 8),

          // Mute Notifications
          SwitchListTile(
            secondary: const Icon(Icons.notifications_off, color: Colors.orange),
            title: const Text('Mute Notifications'),
            subtitle: const Text('Stop receiving notifications'),
            value: _isMuted,
            activeThumbColor: AppColors.primary,
            onChanged: (value) {
              setState(() => _isMuted = value);
              // TODO: Save mute preference
            },
          ),

          // Custom Wallpaper
          ListTile(
            leading: const Icon(Icons.wallpaper, color: Colors.blue),
            title: const Text('Custom Wallpaper'),
            subtitle: const Text('Set chat background'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Open wallpaper selector
            },
          ),

          const Divider(height: 1),
          const SizedBox(height: 8),

          // Clear Chat
          ListTile(
            leading: const Icon(Icons.cleaning_services, color: Colors.grey),
            title: const Text('Clear Chat History'),
            onTap: () => _confirmClearChat(),
          ),

          // Block User
          ListTile(
            leading: const Icon(Icons.block, color: Colors.red),
            title: Text(_isBlocked ? 'Unblock User' : 'Block User'),
            onTap: () => _confirmBlockUser(),
          ),

          // Report
          ListTile(
            leading: const Icon(Icons.report, color: Colors.red),
            title: const Text('Report User'),
            onTap: () => _confirmReportUser(),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _confirmClearChat() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Chat History'),
        content: const Text(
          'Are you sure you want to clear all messages? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              // TODO: Clear chat history
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Chat history cleared')),
              );
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _confirmBlockUser() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_isBlocked ? 'Unblock User' : 'Block User'),
        content: Text(
          _isBlocked
              ? 'Are you sure you want to unblock ${widget.otherUser.name}?'
              : 'Are you sure you want to block ${widget.otherUser.name}? You will no longer receive messages from them.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() => _isBlocked = !_isBlocked);
              Navigator.pop(context);
              // TODO: Block/Unblock user
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_isBlocked ? 'User blocked' : 'User unblocked'),
                ),
              );
            },
            child: Text(
              _isBlocked ? 'Unblock' : 'Block',
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmReportUser() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report User'),
        content: const Text('Why are you reporting this user?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Show report reasons
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('User reported')),
              );
            },
            child: const Text('Report', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}