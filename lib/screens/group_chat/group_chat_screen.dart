import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/group_chat_service.dart';

class GroupChatScreen extends StatefulWidget {
  final String groupId;
  final String currentUserId;
  final String currentUserName;
  final String? currentUserAvatar;

  const GroupChatScreen({
    super.key,
    required this.groupId,
    required this.currentUserId,
    required this.currentUserName,
    this.currentUserAvatar,
  });

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final GroupChatService _groupService = GroupChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  GroupChat? _group;
  List<GroupMessage> _messages = [];
  Map<String, dynamic>? _replyTo;
  bool _isLoading = true;
  bool _isSending = false;
  bool _showScrollToBottom = false;

  @override
  void initState() {
    super.initState();
    _loadGroup();
    _scrollController.addListener(_onScroll);
    
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onScroll() {
    final showButton = _scrollController.offset > 500;
    if (showButton != _showScrollToBottom) {
      setState(() => _showScrollToBottom = showButton);
    }
  }

  Future<void> _loadGroup() async {
    final group = await _groupService.getGroup(widget.groupId);
    if (mounted) {
      setState(() {
        _group = group;
        _isLoading = false;
      });
    }
  }

  void _scrollToBottom() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _messageController.clear();

    try {
      // Extract mentions from content
      final mentionRegex = RegExp(r'@(\w+)');
      final mentions = mentionRegex
          .allMatches(content)
          .map((m) => m.group(1)!)
          .toList();

      await _groupService.sendMessage(
        groupId: widget.groupId,
        senderId: widget.currentUserId,
        senderName: widget.currentUserName,
        senderAvatar: widget.currentUserAvatar,
        content: content,
        replyTo: _replyTo,
        mentions: mentions,
      );

      setState(() {
        _replyTo = null;
        _isSending = false;
      });

      _scrollToBottom();
      
    } catch (e) {
      
      setState(() => _isSending = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e')),
        );
      }
    }
  }

  void _setReplyTo(GroupMessage message) {
    setState(() {
      _replyTo = {
        'id': message.id,
        'senderId': message.senderId,
        'senderName': message.senderName,
        'content': message.content,
      };
    });
    _focusNode.requestFocus();
  }

  void _cancelReply() {
    setState(() => _replyTo = null);
  }

  void _showMessageOptions(GroupMessage message) {
    final isMyMessage = message.senderId == widget.currentUserId;
    final isAdmin = _group?.isAdmin(widget.currentUserId) ?? false;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildOptionTile(
              icon: Icons.reply,
              label: 'Reply',
              onTap: () {
                Navigator.pop(context);
                _setReplyTo(message);
              },
            ),
            _buildOptionTile(
              icon: Icons.copy,
              label: 'Copy',
              onTap: () {
                Clipboard.setData(ClipboardData(text: message.content));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Message copied')),
                );
              },
            ),
            if (isAdmin && !message.isPinned)
              _buildOptionTile(
                icon: Icons.push_pin,
                label: 'Pin Message',
                onTap: () async {
                  Navigator.pop(context);
                  await _groupService.pinMessage(widget.groupId, message.id);
                },
              ),
            if (isAdmin && message.isPinned)
              _buildOptionTile(
                icon: Icons.push_pin_outlined,
                label: 'Unpin Message',
                onTap: () async {
                  Navigator.pop(context);
                  await _groupService.unpinMessage(widget.groupId, message.id);
                },
              ),
            if (isMyMessage || isAdmin)
              _buildOptionTile(
                icon: Icons.delete,
                label: 'Delete',
                color: Colors.red,
                onTap: () async {
                  Navigator.pop(context);
                  await _groupService.deleteMessage(widget.groupId, message.id);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return ListTile(
      leading: Icon(icon, color: color ?? Colors.white70),
      title: Text(
        label,
        style: TextStyle(color: color ?? Colors.white),
      ),
      onTap: onTap,
    );
  }

  void _showGroupInfo() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GroupInfoScreen(
          groupId: widget.groupId,
          currentUserId: widget.currentUserId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF1A1A2E),
        appBar: AppBar(
          backgroundColor: const Color(0xFF16213E),
          title: const Text('Loading...'),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFFE94057)),
        ),
      );
    }

    if (_group == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF1A1A2E),
        appBar: AppBar(
          backgroundColor: const Color(0xFF16213E),
          title: const Text('Group Not Found'),
        ),
        body: const Center(
          child: Text(
            'This group no longer exists',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                _buildMessageList(),
                if (_showScrollToBottom) _buildScrollToBottomButton(),
              ],
            ),
          ),
          if (_replyTo != null) _buildReplyPreview(),
          _buildMessageInput(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF16213E),
      elevation: 0,
      titleSpacing: 0,
      title: InkWell(
        onTap: _showGroupInfo,
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xFFE94057),
              backgroundImage: _group!.avatar != null
                  ? NetworkImage(_group!.avatar!)
                  : null,
              child: _group!.avatar == null
                  ? Text(
                      _group!.name[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _group!.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${_group!.memberIds.length} members',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.videocam),
          onPressed: () {
            // TODO: Start group video call
          },
        ),
        IconButton(
          icon: const Icon(Icons.more_vert),
          onPressed: _showGroupInfo,
        ),
      ],
    );
  }

  Widget _buildMessageList() {
    return StreamBuilder<List<GroupMessage>>(
      stream: _groupService.getMessages(widget.groupId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            _messages.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFE94057)),
          );
        }

        if (snapshot.hasData) {
          _messages = snapshot.data!;
        }

        if (_messages.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  size: 64,
                  color: Colors.white.withOpacity(0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  'No messages yet',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Be the first to say hello!',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.3),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          controller: _scrollController,
          reverse: true,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: _messages.length,
          itemBuilder: (context, index) {
            final message = _messages[index];
            final previousMessage =
                index < _messages.length - 1 ? _messages[index + 1] : null;
            final showAvatar = previousMessage == null ||
                previousMessage.senderId != message.senderId ||
                message.createdAt.difference(previousMessage.createdAt).inMinutes >
                    5;

            return _buildMessageBubble(message, showAvatar);
          },
        );
      },
    );
  }

  Widget _buildMessageBubble(GroupMessage message, bool showAvatar) {
    final isMyMessage = message.senderId == widget.currentUserId;
    final isSystemMessage = message.type == MessageType.system;

    if (isSystemMessage) {
      return _buildSystemMessage(message);
    }

    return GestureDetector(
      onLongPress: () => _showMessageOptions(message),
      child: Padding(
        padding: EdgeInsets.only(
          top: showAvatar ? 12 : 2,
          bottom: 2,
        ),
        child: Row(
          mainAxisAlignment:
              isMyMessage ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMyMessage && showAvatar)
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.purple.shade300,
                backgroundImage: message.senderAvatar != null
                    ? NetworkImage(message.senderAvatar!)
                    : null,
                child: message.senderAvatar == null
                    ? Text(
                        message.senderName[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      )
                    : null,
              )
            else if (!isMyMessage)
              const SizedBox(width: 32),
            if (!isMyMessage) const SizedBox(width: 8),
            Flexible(
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isMyMessage
                      ? const Color(0xFFE94057)
                      : const Color(0xFF16213E),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft:
                        isMyMessage ? const Radius.circular(16) : Radius.zero,
                    bottomRight:
                        isMyMessage ? Radius.zero : const Radius.circular(16),
                  ),
                  border: isMyMessage
                      ? null
                      : Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isMyMessage && showAvatar)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          message.senderName,
                          style: TextStyle(
                            color: _getSenderColor(message.senderId),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    if (message.replyTo != null) _buildReplyBubble(message),
                    if (message.isPinned)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.push_pin,
                              size: 12,
                              color: Colors.white.withOpacity(0.7),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Pinned',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.white.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Text(
                      message.content,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatTime(message.createdAt),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReplyBubble(GroupMessage message) {
    final reply = message.replyTo!;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: _getSenderColor(reply['senderId']),
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            reply['senderName'],
            style: TextStyle(
              color: _getSenderColor(reply['senderId']),
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
          Text(
            reply['content'],
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 12,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSystemMessage(GroupMessage message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            message.content,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Color _getSenderColor(String oderId) {
    final colors = [
      Colors.pink,
      Colors.purple,
      Colors.blue,
      Colors.cyan,
      Colors.teal,
      Colors.green,
      Colors.orange,
      Colors.deepOrange,
    ];
    final hash = oderId.hashCode;
    return colors[hash.abs() % colors.length];
  }

  Widget _buildScrollToBottomButton() {
    return Positioned(
      bottom: 16,
      right: 16,
      child: FloatingActionButton.small(
        backgroundColor: const Color(0xFF16213E),
        onPressed: _scrollToBottom,
        child: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
      ),
    );
  }

  Widget _buildReplyPreview() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: const Color(0xFF16213E),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: _getSenderColor(_replyTo!['senderId']),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Replying to ${_replyTo!['senderName']}',
                  style: TextStyle(
                    color: _getSenderColor(_replyTo!['senderId']),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                Text(
                  _replyTo!['content'],
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white54),
            onPressed: _cancelReply,
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    final canPost = !(_group!.settings.onlyAdminsCanPost &&
        !_group!.isAdmin(widget.currentUserId));

    if (!canPost) {
      return Container(
        padding: const EdgeInsets.all(16),
        color: const Color(0xFF16213E),
        child: const Text(
          'Only admins can post in this group',
          style: TextStyle(color: Colors.white54),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      color: const Color(0xFF16213E),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.add_circle_outline, color: Colors.white54),
              onPressed: () {
                // TODO: Show media options
              },
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _messageController,
                  focusNode: _focusNode,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 4,
                  minLines: 1,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFE94057), Color(0xFFF27121)],
                ),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: _isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send, color: Colors.white),
                onPressed: _isSending ? null : _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final time = '$hour:$minute';

    if (messageDate == today) {
      return time;
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday $time';
    } else {
      return '${dateTime.day}/${dateTime.month} $time';
    }
  }
}

// ============ GROUP INFO SCREEN ============

class GroupInfoScreen extends StatefulWidget {
  final String groupId;
  final String currentUserId;

  const GroupInfoScreen({
    super.key,
    required this.groupId,
    required this.currentUserId,
  });

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  final GroupChatService _groupService = GroupChatService();

  GroupChat? _group;
  List<GroupMember> _members = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final group = await _groupService.getGroup(widget.groupId);
    final members = await _groupService.getGroupMembers(widget.groupId);

    if (mounted) {
      setState(() {
        _group = group;
        _members = members;
        _isLoading = false;
      });
    }
  }

  bool get _isAdmin => _group?.isAdmin(widget.currentUserId) ?? false;
  bool get _isCreator => _group?.isCreator(widget.currentUserId) ?? false;

  void _showMemberOptions(GroupMember member) {
    if (!_isAdmin || member.oderId == widget.currentUserId) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person, color: Colors.white70),
              title: const Text('View Profile',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/profile',
                    arguments: {'userId': member.oderId});
              },
            ),
            if (_isCreator && member.role != GroupRole.admin)
              ListTile(
                leading:
                    const Icon(Icons.admin_panel_settings, color: Colors.blue),
                title: const Text('Make Admin',
                    style: TextStyle(color: Colors.white)),
                onTap: () async {
                  Navigator.pop(context);
                  await _groupService.addAdmin(widget.groupId, member.oderId);
                  await _loadData();
                },
              ),
            if (_isCreator && member.role == GroupRole.admin)
              ListTile(
                leading: const Icon(Icons.remove_moderator, color: Colors.orange),
                title: const Text('Remove Admin',
                    style: TextStyle(color: Colors.white)),
                onTap: () async {
                  Navigator.pop(context);
                  await _groupService.removeAdmin(widget.groupId, member.oderId);
                  await _loadData();
                },
              ),
            ListTile(
              leading: const Icon(Icons.remove_circle, color: Colors.red),
              title: const Text('Remove from Group',
                  style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(context);
                await _groupService.removeMember(
                  groupId: widget.groupId,
                  memberId: member.oderId,
                  memberName: member.name,
                  removedBy: widget.currentUserId,
                );
                await _loadData();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF1A1A2E),
        appBar: AppBar(
          backgroundColor: const Color(0xFF16213E),
          title: const Text('Group Info'),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFFE94057)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: CustomScrollView(
        slivers: [
          _buildHeader(),
          SliverToBoxAdapter(child: _buildGroupDetails()),
          SliverToBoxAdapter(child: _buildMembersSection()),
          SliverToBoxAdapter(child: _buildActionsSection()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: const Color(0xFF16213E),
      flexibleSpace: FlexibleSpaceBar(
        title: Text(_group!.name),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFFE94057),
                const Color(0xFF16213E),
              ],
            ),
          ),
          child: Center(
            child: CircleAvatar(
              radius: 50,
              backgroundColor: Colors.white.withOpacity(0.2),
              backgroundImage: _group!.avatar != null
                  ? NetworkImage(_group!.avatar!)
                  : null,
              child: _group!.avatar == null
                  ? Text(
                      _group!.name[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 40,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
          ),
        ),
      ),
      actions: [
        if (_isAdmin)
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              // TODO: Edit group
            },
          ),
      ],
    );
  }

  Widget _buildGroupDetails() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_group!.description != null) ...[
            const Text(
              'Description',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _group!.description!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
          ],
          Row(
            children: [
              _buildInfoChip(
                icon: Icons.people,
                label: '${_group!.memberIds.length} members',
              ),
              const SizedBox(width: 12),
              _buildInfoChip(
                icon: _group!.type == GroupType.public
                    ? Icons.public
                    : Icons.lock,
                label: _group!.type.name.toUpperCase(),
              ),
            ],
          ),
          if (_group!.inviteCode != null && _isAdmin) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF16213E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.link, color: Colors.white54),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Invite Code',
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                        Text(
                          _group!.inviteCode!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, color: Colors.white54),
                    onPressed: () {
                      Clipboard.setData(
                          ClipboardData(text: _group!.inviteCode!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Invite code copied')),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white54, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildMembersSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Members (${_members.length})',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              if (_isAdmin)
                TextButton.icon(
                  onPressed: () {
                    // TODO: Add members
                  },
                  icon: const Icon(Icons.add, color: Color(0xFFE94057)),
                  label: const Text(
                    'Add',
                    style: TextStyle(color: Color(0xFFE94057)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _members.length,
            itemBuilder: (context, index) {
              final member = _members[index];
              return _buildMemberTile(member);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMemberTile(GroupMember member) {
    return ListTile(
      onTap: () => _showMemberOptions(member),
      contentPadding: EdgeInsets.zero,
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.purple.shade300,
            backgroundImage:
                member.avatar != null ? NetworkImage(member.avatar!) : null,
            child: member.avatar == null
                ? Text(
                    member.name[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white),
                  )
                : null,
          ),
          if (member.isOnline)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF1A1A2E), width: 2),
                ),
              ),
            ),
        ],
      ),
      title: Text(
        member.name,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        member.role == GroupRole.creator
            ? 'Creator'
            : member.role == GroupRole.admin
                ? 'Admin'
                : 'Member',
        style: TextStyle(
          color: member.role == GroupRole.creator
              ? Colors.amber
              : member.role == GroupRole.admin
                  ? Colors.blue
                  : Colors.white54,
          fontSize: 12,
        ),
      ),
      trailing: member.role == GroupRole.creator
          ? const Icon(Icons.star, color: Colors.amber, size: 20)
          : member.role == GroupRole.admin
              ? const Icon(Icons.admin_panel_settings,
                  color: Colors.blue, size: 20)
              : null,
    );
  }

  Widget _buildActionsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildActionTile(
            icon: Icons.notifications_off,
            label: _group!.isMuted(widget.currentUserId)
                ? 'Unmute Notifications'
                : 'Mute Notifications',
            onTap: () async {
              if (_group!.isMuted(widget.currentUserId)) {
                await _groupService.unmuteGroup(
                    widget.groupId, widget.currentUserId);
              } else {
                await _groupService.muteGroup(
                    widget.groupId, widget.currentUserId);
              }
              await _loadData();
            },
          ),
          _buildActionTile(
            icon: Icons.push_pin,
            label: 'Pinned Messages',
            onTap: () {
              // TODO: Show pinned messages
            },
          ),
          const SizedBox(height: 16),
          _buildActionTile(
            icon: Icons.exit_to_app,
            label: 'Leave Group',
            color: Colors.red,
            onTap: () {
              _showLeaveConfirmation();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color ?? Colors.white54),
      title: Text(
        label,
        style: TextStyle(color: color ?? Colors.white),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: color ?? Colors.white54,
      ),
    );
  }

  void _showLeaveConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text(
          'Leave Group',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          _isCreator
              ? 'As the creator, you must transfer ownership before leaving.'
              : 'Are you sure you want to leave this group?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          if (!_isCreator)
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                // Leave group logic
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              child: const Text(
                'Leave',
                style: TextStyle(color: Colors.red),
              ),
            ),
        ],
      ),
    );
  }
}
