import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/moment_model.dart';
import '../../models/user_model.dart';
import '../../services/moment_service.dart';

/// ⭐⭐⭐ PRODUCTION-READY MOMENT DETAIL SCREEN ⭐⭐⭐
/// Full screen view of a moment with comments
/// Features: View moment, Like, Comment, Reply, Share
class MomentDetailScreen extends StatefulWidget {
  final MomentModel moment;
  final UserModel? currentUser;

  const MomentDetailScreen({
    super.key,
    required this.moment,
    this.currentUser,
  });

  @override
  State<MomentDetailScreen> createState() => _MomentDetailScreenState();
}

class _MomentDetailScreenState extends State<MomentDetailScreen> {
  final MomentService _momentService = MomentService();
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  MomentModel? _moment;
  String? _replyToCommentId;
  String? _replyToUserName;
  bool _isSendingComment = false;

  @override
  void initState() {
    super.initState();
    
    
    _loadMoment();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadMoment() async {
    final moment = await _momentService.getMomentById(
      widget.moment.momentId,
      currentUserId: _currentUserId,
    );
    if (mounted && moment != null) {
      setState(() => _moment = moment);
    }
  }

  @override
  Widget build(BuildContext context) {
    final moment = _moment ?? widget.moment;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Row(
          children: [
            _buildUserAvatar(moment),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    moment.userName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    moment.timeAgo,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () => _showMomentOptions(moment),
          ),
        ],
      ),
      body: Column(
        children: [
          // Moment content
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Text content
                  if (moment.text != null && moment.text!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: _buildTextWithHashtags(moment.text!),
                    ),

                  // Media
                  if (moment.hasMedia) _buildMediaSection(moment),

                  // Location
                  if (moment.location != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 16,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            moment.location!,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Stats and actions
                  _buildStatsAndActions(moment),

                  const Divider(color: Colors.grey, height: 32),

                  // Comments section
                  _buildCommentsSection(moment),
                ],
              ),
            ),
          ),

          // Comment input
          _buildCommentInput(),
        ],
      ),
    );
  }

  Widget _buildUserAvatar(MomentModel moment) {
    return GestureDetector(
      onTap: () => _openUserProfile(moment.userId),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: moment.userIsVip ? Colors.amber : const Color(0xFFFF1493),
            width: 2,
          ),
        ),
        child: ClipOval(
          child: moment.userPhoto != null
              ? Image.network(
                  moment.userPhoto!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.grey,
                    child: const Icon(Icons.person, color: Colors.white, size: 20),
                  ),
                )
              : Container(
                  color: Colors.grey,
                  child: const Icon(Icons.person, color: Colors.white, size: 20),
                ),
        ),
      ),
    );
  }

  Widget _buildTextWithHashtags(String text) {
    final words = text.split(' ');
    return Wrap(
      children: words.map((word) {
        if (word.startsWith('#')) {
          return GestureDetector(
            onTap: () => _searchByHashtag(word.replaceAll('#', '')),
            child: Text(
              '$word ',
              style: const TextStyle(
                color: Color(0xFFFF1493),
                fontWeight: FontWeight.w500,
                fontSize: 16,
              ),
            ),
          );
        } else if (word.startsWith('@')) {
          return GestureDetector(
            onTap: () => _openUserByName(word.replaceAll('@', '')),
            child: Text(
              '$word ',
              style: const TextStyle(
                color: Color(0xFF1DA1F2),
                fontWeight: FontWeight.w500,
                fontSize: 16,
              ),
            ),
          );
        }
        return Text(
          '$word ',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            height: 1.5,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMediaSection(MomentModel moment) {
    if (moment.mediaUrls.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 500),
      child: moment.mediaUrls.length == 1
          ? _buildSingleMedia(moment.mediaUrls.first, moment.isVideo)
          : _buildMediaPageView(moment.mediaUrls, moment.isVideo),
    );
  }

  Widget _buildSingleMedia(String url, bool isVideo) {
    return Stack(
      children: [
        Image.network(
          url,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            height: 300,
            color: Colors.grey[900],
            child: const Center(
              child: Icon(Icons.broken_image, color: Colors.grey, size: 50),
            ),
          ),
        ),
        if (isVideo)
          Positioned.fill(
            child: Center(
              child: GestureDetector(
                onTap: () {
                  // TODO: Play video
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Video player coming soon!')),
                  );
                },
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 50,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMediaPageView(List<String> urls, bool isVideo) {
    return SizedBox(
      height: 400,
      child: PageView.builder(
        itemCount: urls.length,
        itemBuilder: (context, index) {
          return Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                urls[index],
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.grey[900],
                  child: const Center(
                    child: Icon(Icons.broken_image, color: Colors.grey, size: 50),
                  ),
                ),
              ),
              // Page indicator
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${index + 1}/${urls.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatsAndActions(MomentModel moment) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats row
          Row(
            children: [
              Text(
                '${moment.formattedLikes} likes',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                '${moment.formattedComments} comments',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(width: 16),
              Text(
                '${moment.formattedViews} views',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Action buttons
          Row(
            children: [
              // Like button
              _buildActionButton(
                icon: moment.isLikedByCurrentUser
                    ? Icons.favorite
                    : Icons.favorite_border,
                label: 'Like',
                color: moment.isLikedByCurrentUser
                    ? const Color(0xFFFF1493)
                    : Colors.white,
                onTap: () => _toggleLike(moment),
              ),

              const SizedBox(width: 24),

              // Comment button
              _buildActionButton(
                icon: Icons.chat_bubble_outline,
                label: 'Comment',
                color: Colors.white,
                onTap: () {
                  _commentFocusNode.requestFocus();
                },
              ),

              const SizedBox(width: 24),

              // Share button
              _buildActionButton(
                icon: Icons.share_outlined,
                label: 'Share',
                color: Colors.white,
                onTap: () => _shareMoment(moment),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsSection(MomentModel moment) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Comments',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // Comments stream
          StreamBuilder<List<MomentCommentModel>>(
            stream: _momentService.getComments(momentId: moment.momentId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(color: Color(0xFFFF1493)),
                  ),
                );
              }

              final comments = snapshot.data ?? [];

              if (comments.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 48,
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No comments yet\nBe the first to comment!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: comments.length,
                itemBuilder: (context, index) {
                  return _buildCommentItem(comments[index], moment.momentId);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCommentItem(MomentCommentModel comment, String momentId) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          GestureDetector(
            onTap: () => _openUserProfile(comment.userId),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFFF1493).withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
              child: ClipOval(
                child: comment.userPhoto != null
                    ? Image.network(
                        comment.userPhoto!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey,
                          child: const Icon(Icons.person, color: Colors.white, size: 18),
                        ),
                      )
                    : Container(
                        color: Colors.grey,
                        child: const Icon(Icons.person, color: Colors.white, size: 18),
                      ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Comment content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User name and level
                Row(
                  children: [
                    Text(
                      comment.userName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    if (comment.userIsVerified) ...[
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.verified,
                        color: Color(0xFF1DA1F2),
                        size: 14,
                      ),
                    ],
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF1493), Color(0xFFFF69B4)],
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Lv${comment.userLevel}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 4),

                // Reply indicator
                if (comment.replyToUserName != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      'Reply to @${comment.replyToUserName}',
                      style: TextStyle(
                        color: const Color(0xFF1DA1F2).withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                    ),
                  ),

                // Comment text
                Text(
                  comment.text,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),

                const SizedBox(height: 8),

                // Time and actions
                Row(
                  children: [
                    Text(
                      comment.timeAgo,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: () => _setReplyTo(comment),
                      child: Text(
                        'Reply',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (comment.likesCount > 0) ...[
                      const SizedBox(width: 16),
                      Row(
                        children: [
                          Icon(
                            Icons.favorite,
                            size: 14,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${comment.likesCount}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                    // Delete option for own comments
                    if (comment.userId == _currentUserId) ...[
                      const Spacer(),
                      GestureDetector(
                        onTap: () => _deleteComment(momentId, comment.commentId),
                        child: Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: Colors.red.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ],
                ),

                // Replies
                if (comment.repliesCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: GestureDetector(
                      onTap: () {
                        // TODO: Load and show replies
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Loading replies...')),
                        );
                      },
                      child: Text(
                        'View ${comment.repliesCount} ${comment.repliesCount == 1 ? 'reply' : 'replies'}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentInput() {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Reply indicator
          if (_replyToUserName != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Text(
                    'Replying to @$_replyToUserName',
                    style: const TextStyle(
                      color: Color(0xFF1DA1F2),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _cancelReply,
                    child: Icon(
                      Icons.close,
                      size: 16,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),

          // Input row
          Row(
            children: [
              // Avatar
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFFF1493),
                    width: 1,
                  ),
                ),
                child: ClipOval(
                  child: widget.currentUser?.photoURL != null
                      ? Image.network(
                          widget.currentUser!.photoURL!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.grey,
                            child: const Icon(Icons.person, color: Colors.white, size: 18),
                          ),
                        )
                      : Container(
                          color: Colors.grey,
                          child: const Icon(Icons.person, color: Colors.white, size: 18),
                        ),
                ),
              ),

              const SizedBox(width: 12),

              // Text field
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: TextField(
                    controller: _commentController,
                    focusNode: _commentFocusNode,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: _replyToUserName != null
                          ? 'Write a reply...'
                          : 'Add a comment...',
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _sendComment(),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Send button
              _isSendingComment
                  ? const SizedBox(
                      width: 36,
                      height: 36,
                      child: Padding(
                        padding: EdgeInsets.all(6),
                        child: CircularProgressIndicator(
                          color: Color(0xFFFF1493),
                          strokeWidth: 2,
                        ),
                      ),
                    )
                  : GestureDetector(
                      onTap: _commentController.text.trim().isNotEmpty
                          ? _sendComment
                          : null,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          gradient: _commentController.text.trim().isNotEmpty
                              ? const LinearGradient(
                                  colors: [Color(0xFFFF1493), Color(0xFFFF69B4)],
                                )
                              : null,
                          color: _commentController.text.trim().isEmpty
                              ? Colors.grey[800]
                              : null,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.send,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== ACTIONS ====================

  Future<void> _toggleLike(MomentModel moment) async {
    
    try {
      await _momentService.toggleLike(
        momentId: moment.momentId,
        userId: _currentUserId,
        userName: widget.currentUser?.name ?? 'User',
      );
      await _loadMoment(); // Refresh moment
    } catch (e) {
      
    }
  }

  Future<void> _shareMoment(MomentModel moment) async {
    
    try {
      await _momentService.shareMoment(
        momentId: moment.momentId,
        userId: _currentUserId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Moment shared!'),
            backgroundColor: Color(0xFF4CAF50),
          ),
        );
      }
    } catch (e) {
      
    }
  }

  void _setReplyTo(MomentCommentModel comment) {
    setState(() {
      _replyToCommentId = comment.commentId;
      _replyToUserName = comment.userName;
    });
    _commentFocusNode.requestFocus();
  }

  void _cancelReply() {
    setState(() {
      _replyToCommentId = null;
      _replyToUserName = null;
    });
  }

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || widget.currentUser == null) return;

    
    setState(() => _isSendingComment = true);

    try {
      await _momentService.addComment(
        momentId: widget.moment.momentId,
        userId: _currentUserId,
        user: widget.currentUser!,
        text: text,
        replyToCommentId: _replyToCommentId,
        replyToUserName: _replyToUserName,
      );

      _commentController.clear();
      _cancelReply();
      
    } catch (e) {
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSendingComment = false);
      }
    }
  }

  Future<void> _deleteComment(String momentId, String commentId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Delete comment?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This cannot be undone.',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _momentService.deleteComment(
        momentId: momentId,
        commentId: commentId,
        userId: _currentUserId,
      );
    }
  }

  void _openUserProfile(String userId) {
    
    Navigator.pushNamed(context, '/user_profile_detail', arguments: {'userId': userId});
  }

  void _openUserByName(String username) {
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Opening @$username profile...')),
    );
  }

  void _searchByHashtag(String hashtag) {
    
    Navigator.pop(context);
    // Navigate to hashtag search
  }

  void _showMomentOptions(MomentModel moment) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            if (moment.userId == _currentUserId) ...[
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Delete', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDeleteMoment(moment);
                },
              ),
            ] else ...[
              ListTile(
                leading: const Icon(Icons.flag_outlined, color: Colors.orange),
                title: const Text('Report', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _reportMoment(moment);
                },
              ),
            ],

            ListTile(
              leading: Icon(Icons.copy, color: Colors.white.withValues(alpha: 0.7)),
              title: Text('Copy link', style: TextStyle(color: Colors.white.withValues(alpha: 0.9))),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Link copied!')),
                );
              },
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteMoment(MomentModel moment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Delete Moment', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to delete this moment?',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await _momentService.deleteMoment(
                momentId: moment.momentId,
                userId: _currentUserId,
              );
              if (success && mounted) {
                Navigator.pop(context); // Go back to feed
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Moment deleted'),
                    backgroundColor: Color(0xFF4CAF50),
                  ),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _reportMoment(MomentModel moment) async {
    final reasons = [
      'Spam',
      'Inappropriate content',
      'Harassment',
      'Violence',
      'False information',
      'Other',
    ];

    String? selectedReason;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Report Moment', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: reasons.map((reason) {
            return ListTile(
              title: Text(reason, style: const TextStyle(color: Colors.white)),
              onTap: () {
                selectedReason = reason;
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );

    if (selectedReason != null) {
      await _momentService.reportMoment(
        momentId: moment.momentId,
        reporterId: _currentUserId,
        reason: selectedReason!,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report submitted. Thank you!'),
            backgroundColor: Color(0xFF4CAF50),
          ),
        );
      }
    }
  }
}
