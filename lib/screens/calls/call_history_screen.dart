import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../models/call_model.dart';
import '../../services/call_service.dart';
import '../../providers/auth_provider.dart';

class CallHistoryScreen extends StatefulWidget {
  const CallHistoryScreen({super.key});

  @override
  State<CallHistoryScreen> createState() => _CallHistoryScreenState();
}

class _CallHistoryScreenState extends State<CallHistoryScreen> {
  final CallService _callService = CallService();

  @override
  void initState() {
    super.initState();
    _markMissedCallsAsRead();
  }

  Future<void> _markMissedCallsAsRead() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.user?.uid;
    if (userId != null) {
      await _callService.markMissedCallsAsRead(userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final userId = authProvider.user?.uid;

    if (userId == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in to view call history')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Call History',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<List<CallModel>>(
        stream: _callService.getCallHistory(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFFF1493),
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading call history',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }

          final calls = snapshot.data ?? [];

          if (calls.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.phone_disabled,
                    size: 80,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No call history',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your calls will appear here',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            itemCount: calls.length,
            padding: const EdgeInsets.symmetric(vertical: 8),
            separatorBuilder: (context, index) => Divider(
              height: 1,
              indent: 80,
              color: Colors.grey[200],
            ),
            itemBuilder: (context, index) {
              final call = calls[index];
              return _buildCallItem(call, userId);
            },
          );
        },
      ),
    );
  }

  Widget _buildCallItem(CallModel call, String currentUserId) {
    final isIncoming = call.receiverId == currentUserId;
    final otherUserName = call.getOtherUserName(currentUserId);
    final otherUserPhoto = call.getOtherUserPhoto(currentUserId);
    final statusText = call.getStatusText(currentUserId);
    final isMissed = call.isMissedFor(currentUserId);

    // Get call icon and color
    IconData callIcon;
    Color iconColor;

    if (call.type == CallType.video) {
      callIcon = Icons.videocam;
      iconColor = const Color(0xFFFF1493);
    } else {
      callIcon = Icons.phone;
      iconColor = const Color(0xFFFF1493);
    }

    // Status icon
    IconData? statusIcon;
    if (call.status == CallStatus.missed && isIncoming) {
      statusIcon = Icons.phone_missed;
      iconColor = Colors.red;
    } else if (call.status == CallStatus.rejected) {
      statusIcon = Icons.phone_disabled;
      iconColor = Colors.red;
    } else if (call.status == CallStatus.cancelled) {
      statusIcon = Icons.call_end;
      iconColor = Colors.grey;
    } else if (isIncoming) {
      statusIcon = Icons.call_received;
    } else {
      statusIcon = Icons.call_made;
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Stack(
        children: [
          // User photo
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.grey[200],
            backgroundImage: otherUserPhoto != null && otherUserPhoto.isNotEmpty
                ? CachedNetworkImageProvider(otherUserPhoto)
                : null,
            child: otherUserPhoto == null || otherUserPhoto.isEmpty
                ? Icon(Icons.person, color: Colors.grey[400], size: 32)
                : null,
          ),
          // Call type badge
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Icon(
                callIcon,
                size: 14,
                color: iconColor,
              ),
            ),
          ),
        ],
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              otherUserName,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isMissed ? FontWeight.bold : FontWeight.w500,
                color: isMissed ? Colors.red : Colors.black,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isMissed)
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'MISSED',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      subtitle: Row(
        children: [
          Icon(
            statusIcon,
            size: 16,
            color: isMissed ? Colors.red : Colors.grey[600],
          ),
          const SizedBox(width: 4),
          Text(
            statusText,
            style: TextStyle(
              fontSize: 13,
              color: isMissed ? Colors.red : Colors.grey[600],
              fontWeight: isMissed ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '•',
            style: TextStyle(color: Colors.grey[400]),
          ),
          const SizedBox(width: 8),
          Text(
            _formatCallTime(call.createdAt),
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
      trailing: IconButton(
        icon: Icon(
          call.type == CallType.video ? Icons.videocam : Icons.phone,
          color: const Color(0xFFFF1493),
        ),
        onPressed: () {
          // TODO: Initiate call to this user
          _showCallBackDialog(call, currentUserId);
        },
      ),
    );
  }

  String _formatCallTime(dynamic timestamp) {
    if (timestamp == null) return '';

    DateTime callTime;
    if (timestamp is DateTime) {
      callTime = timestamp;
    } else {
      callTime = timestamp.toDate();
    }

    final now = DateTime.now();
    final difference = now.difference(callTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return DateFormat('h:mm a').format(callTime);
    } else if (difference.inDays < 7) {
      return DateFormat('EEE h:mm a').format(callTime);
    } else {
      return DateFormat('MMM d, h:mm a').format(callTime);
    }
  }

  void _showCallBackDialog(CallModel call, String currentUserId) {
    final otherUserName = call.getOtherUserName(currentUserId);
    final isVideoCall = call.type == CallType.video;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Call $otherUserName?'),
        content: Text(
          'Start a ${isVideoCall ? "video" : "voice"} call with $otherUserName?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Navigate to call screen with this user
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Calling $otherUserName...'),
                  backgroundColor: const Color(0xFFFF1493),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF1493),
              foregroundColor: Colors.white,
            ),
            child: const Text('Call'),
          ),
        ],
      ),
    );
  }
}
