import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Group Chat Message Model
class GroupMessage {
  final String id;
  final String groupId;
  final String senderId;
  final String senderName;
  final String? senderAvatar;
  final String content;
  final MessageType type;
  final String? mediaUrl;
  final String? mediaThumbnail;
  final Map<String, dynamic>? replyTo;
  final List<String> mentions;
  final Map<String, bool> readBy;
  final DateTime createdAt;
  final bool isDeleted;
  final bool isPinned;

  GroupMessage({
    required this.id,
    required this.groupId,
    required this.senderId,
    required this.senderName,
    this.senderAvatar,
    required this.content,
    this.type = MessageType.text,
    this.mediaUrl,
    this.mediaThumbnail,
    this.replyTo,
    this.mentions = const [],
    this.readBy = const {},
    required this.createdAt,
    this.isDeleted = false,
    this.isPinned = false,
  });

  factory GroupMessage.fromMap(Map<String, dynamic> map, String id) {
    return GroupMessage(
      id: id,
      groupId: map['groupId'] ?? '',
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? 'Unknown',
      senderAvatar: map['senderAvatar'],
      content: map['content'] ?? '',
      type: MessageType.values.firstWhere(
        (t) => t.name == map['type'],
        orElse: () => MessageType.text,
      ),
      mediaUrl: map['mediaUrl'],
      mediaThumbnail: map['mediaThumbnail'],
      replyTo: map['replyTo'],
      mentions: List<String>.from(map['mentions'] ?? []),
      readBy: Map<String, bool>.from(map['readBy'] ?? {}),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isDeleted: map['isDeleted'] ?? false,
      isPinned: map['isPinned'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'groupId': groupId,
      'senderId': senderId,
      'senderName': senderName,
      'senderAvatar': senderAvatar,
      'content': content,
      'type': type.name,
      'mediaUrl': mediaUrl,
      'mediaThumbnail': mediaThumbnail,
      'replyTo': replyTo,
      'mentions': mentions,
      'readBy': readBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'isDeleted': isDeleted,
      'isPinned': isPinned,
    };
  }
}

enum MessageType { text, image, video, audio, gif, sticker, system }

/// Group Chat Model
class GroupChat {
  final String id;
  final String name;
  final String? description;
  final String? avatar;
  final String creatorId;
  final List<String> adminIds;
  final List<String> memberIds;
  final List<String> mutedBy;
  final Map<String, DateTime> memberJoinDates;
  final GroupSettings settings;
  final String? lastMessage;
  final String? lastMessageSenderId;
  final DateTime? lastMessageAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;
  final int maxMembers;
  final String? inviteCode;
  final GroupType type;

  GroupChat({
    required this.id,
    required this.name,
    this.description,
    this.avatar,
    required this.creatorId,
    required this.adminIds,
    required this.memberIds,
    this.mutedBy = const [],
    this.memberJoinDates = const {},
    this.settings = const GroupSettings(),
    this.lastMessage,
    this.lastMessageSenderId,
    this.lastMessageAt,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
    this.maxMembers = 200,
    this.inviteCode,
    this.type = GroupType.public,
  });

  factory GroupChat.fromMap(Map<String, dynamic> map, String id) {
    return GroupChat(
      id: id,
      name: map['name'] ?? 'Group',
      description: map['description'],
      avatar: map['avatar'],
      creatorId: map['creatorId'] ?? '',
      adminIds: List<String>.from(map['adminIds'] ?? []),
      memberIds: List<String>.from(map['memberIds'] ?? []),
      mutedBy: List<String>.from(map['mutedBy'] ?? []),
      memberJoinDates: (map['memberJoinDates'] as Map<String, dynamic>?)?.map(
            (key, value) =>
                MapEntry(key, (value as Timestamp).toDate()),
          ) ??
          {},
      settings: GroupSettings.fromMap(map['settings'] ?? {}),
      lastMessage: map['lastMessage'],
      lastMessageSenderId: map['lastMessageSenderId'],
      lastMessageAt: (map['lastMessageAt'] as Timestamp?)?.toDate(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: map['isActive'] ?? true,
      maxMembers: map['maxMembers'] ?? 200,
      inviteCode: map['inviteCode'],
      type: GroupType.values.firstWhere(
        (t) => t.name == map['type'],
        orElse: () => GroupType.public,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'avatar': avatar,
      'creatorId': creatorId,
      'adminIds': adminIds,
      'memberIds': memberIds,
      'mutedBy': mutedBy,
      'memberJoinDates': memberJoinDates.map(
        (key, value) => MapEntry(key, Timestamp.fromDate(value)),
      ),
      'settings': settings.toMap(),
      'lastMessage': lastMessage,
      'lastMessageSenderId': lastMessageSenderId,
      'lastMessageAt':
          lastMessageAt != null ? Timestamp.fromDate(lastMessageAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isActive': isActive,
      'maxMembers': maxMembers,
      'inviteCode': inviteCode,
      'type': type.name,
    };
  }

  bool isAdmin(String userId) => adminIds.contains(userId);
  bool isMember(String userId) => memberIds.contains(userId);
  bool isCreator(String userId) => creatorId == userId;
  bool isMuted(String userId) => mutedBy.contains(userId);
}

enum GroupType { public, private, secret }

class GroupSettings {
  final bool onlyAdminsCanPost;
  final bool onlyAdminsCanAddMembers;
  final bool onlyAdminsCanEditInfo;
  final bool approvalRequired;
  final bool allowMediaSharing;
  final bool allowLinks;
  final int slowModeSeconds;

  const GroupSettings({
    this.onlyAdminsCanPost = false,
    this.onlyAdminsCanAddMembers = false,
    this.onlyAdminsCanEditInfo = true,
    this.approvalRequired = false,
    this.allowMediaSharing = true,
    this.allowLinks = true,
    this.slowModeSeconds = 0,
  });

  factory GroupSettings.fromMap(Map<String, dynamic> map) {
    return GroupSettings(
      onlyAdminsCanPost: map['onlyAdminsCanPost'] ?? false,
      onlyAdminsCanAddMembers: map['onlyAdminsCanAddMembers'] ?? false,
      onlyAdminsCanEditInfo: map['onlyAdminsCanEditInfo'] ?? true,
      approvalRequired: map['approvalRequired'] ?? false,
      allowMediaSharing: map['allowMediaSharing'] ?? true,
      allowLinks: map['allowLinks'] ?? true,
      slowModeSeconds: map['slowModeSeconds'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'onlyAdminsCanPost': onlyAdminsCanPost,
      'onlyAdminsCanAddMembers': onlyAdminsCanAddMembers,
      'onlyAdminsCanEditInfo': onlyAdminsCanEditInfo,
      'approvalRequired': approvalRequired,
      'allowMediaSharing': allowMediaSharing,
      'allowLinks': allowLinks,
      'slowModeSeconds': slowModeSeconds,
    };
  }

  GroupSettings copyWith({
    bool? onlyAdminsCanPost,
    bool? onlyAdminsCanAddMembers,
    bool? onlyAdminsCanEditInfo,
    bool? approvalRequired,
    bool? allowMediaSharing,
    bool? allowLinks,
    int? slowModeSeconds,
  }) {
    return GroupSettings(
      onlyAdminsCanPost: onlyAdminsCanPost ?? this.onlyAdminsCanPost,
      onlyAdminsCanAddMembers:
          onlyAdminsCanAddMembers ?? this.onlyAdminsCanAddMembers,
      onlyAdminsCanEditInfo:
          onlyAdminsCanEditInfo ?? this.onlyAdminsCanEditInfo,
      approvalRequired: approvalRequired ?? this.approvalRequired,
      allowMediaSharing: allowMediaSharing ?? this.allowMediaSharing,
      allowLinks: allowLinks ?? this.allowLinks,
      slowModeSeconds: slowModeSeconds ?? this.slowModeSeconds,
    );
  }
}

/// Group Member Model
class GroupMember {
  final String oderId;
  final String name;
  final String? avatar;
  final GroupRole role;
  final DateTime joinedAt;
  final bool isMuted;
  final bool isOnline;

  GroupMember({
    required this.oderId,
    required this.name,
    this.avatar,
    this.role = GroupRole.member,
    required this.joinedAt,
    this.isMuted = false,
    this.isOnline = false,
  });
}

enum GroupRole { creator, admin, moderator, member }

/// Join Request Model
class JoinRequest {
  final String id;
  final String groupId;
  final String userId;
  final String userName;
  final String? userAvatar;
  final String? message;
  final DateTime requestedAt;
  final JoinRequestStatus status;

  JoinRequest({
    required this.id,
    required this.groupId,
    required this.userId,
    required this.userName,
    this.userAvatar,
    this.message,
    required this.requestedAt,
    this.status = JoinRequestStatus.pending,
  });

  factory JoinRequest.fromMap(Map<String, dynamic> map, String id) {
    return JoinRequest(
      id: id,
      groupId: map['groupId'] ?? '',
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? 'Unknown',
      userAvatar: map['userAvatar'],
      message: map['message'],
      requestedAt:
          (map['requestedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: JoinRequestStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => JoinRequestStatus.pending,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'groupId': groupId,
      'userId': userId,
      'userName': userName,
      'userAvatar': userAvatar,
      'message': message,
      'requestedAt': Timestamp.fromDate(requestedAt),
      'status': status.name,
    };
  }
}

enum JoinRequestStatus { pending, approved, rejected }

/// Group Chat Service
class GroupChatService {
  static final GroupChatService _instance = GroupChatService._internal();
  factory GroupChatService() => _instance;
  GroupChatService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collection references
  CollectionReference get _groupsCollection => _firestore.collection('groups');
  CollectionReference get _joinRequestsCollection =>
      _firestore.collection('group_join_requests');

  CollectionReference _messagesCollection(String groupId) =>
      _groupsCollection.doc(groupId).collection('messages');

  // ============ GROUP CRUD OPERATIONS ============

  /// Create a new group
  Future<GroupChat> createGroup({
    required String creatorId,
    required String creatorName,
    required String name,
    String? description,
    String? avatar,
    List<String> initialMembers = const [],
    GroupType type = GroupType.public,
    GroupSettings? settings,
  }) async {
    

    final now = DateTime.now();
    final allMembers = [creatorId, ...initialMembers];
    final memberJoinDates = <String, DateTime>{};

    for (final memberId in allMembers) {
      memberJoinDates[memberId] = now;
    }

    // Generate invite code for private groups
    final inviteCode = type == GroupType.private
        ? _generateInviteCode()
        : null;

    final groupData = {
      'name': name,
      'description': description,
      'avatar': avatar,
      'creatorId': creatorId,
      'adminIds': [creatorId],
      'memberIds': allMembers,
      'mutedBy': <String>[],
      'memberJoinDates': memberJoinDates.map(
        (key, value) => MapEntry(key, Timestamp.fromDate(value)),
      ),
      'settings': (settings ?? const GroupSettings()).toMap(),
      'lastMessage': null,
      'lastMessageSenderId': null,
      'lastMessageAt': null,
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
      'isActive': true,
      'maxMembers': 200,
      'inviteCode': inviteCode,
      'type': type.name,
    };

    final docRef = await _groupsCollection.add(groupData);

    // Add system message about group creation
    await _addSystemMessage(
      docRef.id,
      '$creatorName created this group',
    );

    

    return GroupChat.fromMap(groupData, docRef.id);
  }

  /// Get group by ID
  Future<GroupChat?> getGroup(String groupId) async {
    

    final doc = await _groupsCollection.doc(groupId).get();
    if (!doc.exists) {
      
      return null;
    }

    return GroupChat.fromMap(doc.data() as Map<String, dynamic>, doc.id);
  }

  /// Get group by invite code
  Future<GroupChat?> getGroupByInviteCode(String inviteCode) async {
    

    final query = await _groupsCollection
        .where('inviteCode', isEqualTo: inviteCode)
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      
      return null;
    }

    final doc = query.docs.first;
    return GroupChat.fromMap(doc.data() as Map<String, dynamic>, doc.id);
  }

  /// Update group info
  Future<void> updateGroup({
    required String groupId,
    String? name,
    String? description,
    String? avatar,
    GroupSettings? settings,
  }) async {
    

    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (name != null) updates['name'] = name;
    if (description != null) updates['description'] = description;
    if (avatar != null) updates['avatar'] = avatar;
    if (settings != null) updates['settings'] = settings.toMap();

    await _groupsCollection.doc(groupId).update(updates);
    
  }

  /// Delete group (soft delete)
  Future<void> deleteGroup(String groupId) async {
    

    await _groupsCollection.doc(groupId).update({
      'isActive': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    
  }

  /// Get user's groups
  Stream<List<GroupChat>> getUserGroups(String userId) {
    

    return _groupsCollection
        .where('memberIds', arrayContains: userId)
        .where('isActive', isEqualTo: true)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map((snapshot) {
      
      return snapshot.docs
          .map((doc) =>
              GroupChat.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    });
  }

  /// Search public groups
  Future<List<GroupChat>> searchGroups(String query, {int limit = 20}) async {
    

    // Firestore doesn't support full-text search, so we use prefix matching
    final queryLower = query.toLowerCase();

    final snapshot = await _groupsCollection
        .where('type', isEqualTo: GroupType.public.name)
        .where('isActive', isEqualTo: true)
        .limit(100)
        .get();

    final groups = snapshot.docs
        .map((doc) =>
            GroupChat.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .where((group) =>
            group.name.toLowerCase().contains(queryLower) ||
            (group.description?.toLowerCase().contains(queryLower) ?? false))
        .take(limit)
        .toList();

    
    return groups;
  }

  /// Get popular groups
  Future<List<GroupChat>> getPopularGroups({int limit = 20}) async {
    

    final snapshot = await _groupsCollection
        .where('type', isEqualTo: GroupType.public.name)
        .where('isActive', isEqualTo: true)
        .orderBy('memberIds')
        .limit(limit)
        .get();

    final groups = snapshot.docs
        .map((doc) =>
            GroupChat.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();

    // Sort by member count descending
    groups.sort((a, b) => b.memberIds.length.compareTo(a.memberIds.length));

    
    return groups;
  }

  // ============ MEMBER MANAGEMENT ============

  /// Join a group
  Future<bool> joinGroup({
    required String groupId,
    required String userId,
    required String userName,
    String? userAvatar,
    String? message,
  }) async {
    

    final group = await getGroup(groupId);
    if (group == null) {
      
      return false;
    }

    if (group.memberIds.contains(userId)) {
      
      return true;
    }

    if (group.memberIds.length >= group.maxMembers) {
      
      return false;
    }

    // Check if approval is required
    if (group.settings.approvalRequired || group.type == GroupType.private) {
      await _createJoinRequest(
        groupId: groupId,
        userId: userId,
        userName: userName,
        userAvatar: userAvatar,
        message: message,
      );
      
      return false;
    }

    // Direct join
    await _groupsCollection.doc(groupId).update({
      'memberIds': FieldValue.arrayUnion([userId]),
      'memberJoinDates.$userId': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _addSystemMessage(groupId, '$userName joined the group');
    
    return true;
  }

  /// Leave a group
  Future<void> leaveGroup({
    required String groupId,
    required String userId,
    required String userName,
  }) async {
    

    final group = await getGroup(groupId);
    if (group == null) return;

    // Creator cannot leave, must transfer ownership first
    if (group.creatorId == userId) {
      
      throw Exception('Creator must transfer ownership before leaving');
    }

    await _groupsCollection.doc(groupId).update({
      'memberIds': FieldValue.arrayRemove([userId]),
      'adminIds': FieldValue.arrayRemove([userId]),
      'mutedBy': FieldValue.arrayRemove([userId]),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _addSystemMessage(groupId, '$userName left the group');
    
  }

  /// Remove member from group
  Future<void> removeMember({
    required String groupId,
    required String memberId,
    required String memberName,
    required String removedBy,
  }) async {
    

    await _groupsCollection.doc(groupId).update({
      'memberIds': FieldValue.arrayRemove([memberId]),
      'adminIds': FieldValue.arrayRemove([memberId]),
      'mutedBy': FieldValue.arrayRemove([memberId]),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _addSystemMessage(groupId, '$memberName was removed from the group');
    
  }

  /// Add admin
  Future<void> addAdmin(String groupId, String userId) async {
    

    await _groupsCollection.doc(groupId).update({
      'adminIds': FieldValue.arrayUnion([userId]),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    
  }

  /// Remove admin
  Future<void> removeAdmin(String groupId, String userId) async {
    

    final group = await getGroup(groupId);
    if (group?.creatorId == userId) {
      throw Exception('Cannot remove creator from admin');
    }

    await _groupsCollection.doc(groupId).update({
      'adminIds': FieldValue.arrayRemove([userId]),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    
  }

  /// Transfer ownership
  Future<void> transferOwnership({
    required String groupId,
    required String currentOwnerId,
    required String newOwnerId,
  }) async {
    

    await _groupsCollection.doc(groupId).update({
      'creatorId': newOwnerId,
      'adminIds': FieldValue.arrayUnion([newOwnerId]),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    
  }

  /// Get group members
  Future<List<GroupMember>> getGroupMembers(String groupId) async {
    

    final group = await getGroup(groupId);
    if (group == null) return [];

    final members = <GroupMember>[];

    // Fetch user details for each member
    for (final memberId in group.memberIds) {
      final userDoc = await _firestore.collection('users').doc(memberId).get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final role = group.creatorId == memberId
            ? GroupRole.creator
            : group.adminIds.contains(memberId)
                ? GroupRole.admin
                : GroupRole.member;

        members.add(GroupMember(
          oderId: memberId,
          name: userData['name'] ?? 'Unknown',
          avatar: userData['profileImage'],
          role: role,
          joinedAt: group.memberJoinDates[memberId] ?? group.createdAt,
          isMuted: group.mutedBy.contains(memberId),
          isOnline: userData['isOnline'] ?? false,
        ));
      }
    }

    // Sort: creator first, then admins, then members
    members.sort((a, b) {
      final roleOrder = {
        GroupRole.creator: 0,
        GroupRole.admin: 1,
        GroupRole.moderator: 2,
        GroupRole.member: 3,
      };
      return roleOrder[a.role]!.compareTo(roleOrder[b.role]!);
    });

    
    return members;
  }

  // ============ JOIN REQUESTS ============

  Future<void> _createJoinRequest({
    required String groupId,
    required String userId,
    required String userName,
    String? userAvatar,
    String? message,
  }) async {
    await _joinRequestsCollection.add({
      'groupId': groupId,
      'userId': userId,
      'userName': userName,
      'userAvatar': userAvatar,
      'message': message,
      'requestedAt': FieldValue.serverTimestamp(),
      'status': JoinRequestStatus.pending.name,
    });
  }

  /// Get pending join requests for a group
  Stream<List<JoinRequest>> getJoinRequests(String groupId) {
    return _joinRequestsCollection
        .where('groupId', isEqualTo: groupId)
        .where('status', isEqualTo: JoinRequestStatus.pending.name)
        .orderBy('requestedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) =>
                JoinRequest.fromMap(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  /// Approve join request
  Future<void> approveJoinRequest(JoinRequest request) async {
    

    // Update request status
    await _joinRequestsCollection.doc(request.id).update({
      'status': JoinRequestStatus.approved.name,
    });

    // Add member to group
    await _groupsCollection.doc(request.groupId).update({
      'memberIds': FieldValue.arrayUnion([request.userId]),
      'memberJoinDates.${request.userId}': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _addSystemMessage(
      request.groupId,
      '${request.userName} joined the group',
    );

    
  }

  /// Reject join request
  Future<void> rejectJoinRequest(String requestId) async {
    

    await _joinRequestsCollection.doc(requestId).update({
      'status': JoinRequestStatus.rejected.name,
    });

    
  }

  // ============ MESSAGING ============

  /// Send a message
  Future<GroupMessage> sendMessage({
    required String groupId,
    required String senderId,
    required String senderName,
    String? senderAvatar,
    required String content,
    MessageType type = MessageType.text,
    String? mediaUrl,
    String? mediaThumbnail,
    Map<String, dynamic>? replyTo,
    List<String> mentions = const [],
  }) async {
    

    final messageData = {
      'groupId': groupId,
      'senderId': senderId,
      'senderName': senderName,
      'senderAvatar': senderAvatar,
      'content': content,
      'type': type.name,
      'mediaUrl': mediaUrl,
      'mediaThumbnail': mediaThumbnail,
      'replyTo': replyTo,
      'mentions': mentions,
      'readBy': {senderId: true},
      'createdAt': FieldValue.serverTimestamp(),
      'isDeleted': false,
      'isPinned': false,
    };

    final docRef = await _messagesCollection(groupId).add(messageData);

    // Update group's last message
    await _groupsCollection.doc(groupId).update({
      'lastMessage': content,
      'lastMessageSenderId': senderId,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    

    return GroupMessage(
      id: docRef.id,
      groupId: groupId,
      senderId: senderId,
      senderName: senderName,
      senderAvatar: senderAvatar,
      content: content,
      type: type,
      mediaUrl: mediaUrl,
      mediaThumbnail: mediaThumbnail,
      replyTo: replyTo,
      mentions: mentions,
      readBy: {senderId: true},
      createdAt: DateTime.now(),
    );
  }

  /// Get messages stream
  Stream<List<GroupMessage>> getMessages(String groupId, {int limit = 50}) {
    

    return _messagesCollection(groupId)
        .where('isDeleted', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      
      return snapshot.docs
          .map((doc) =>
              GroupMessage.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    });
  }

  /// Get more messages (pagination)
  Future<List<GroupMessage>> getMoreMessages(
    String groupId, {
    required DateTime before,
    int limit = 50,
  }) async {
    

    final snapshot = await _messagesCollection(groupId)
        .where('isDeleted', isEqualTo: false)
        .where('createdAt', isLessThan: Timestamp.fromDate(before))
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs
        .map((doc) =>
            GroupMessage.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  }

  /// Delete message
  Future<void> deleteMessage(String groupId, String messageId) async {
    

    await _messagesCollection(groupId).doc(messageId).update({
      'isDeleted': true,
      'content': 'This message was deleted',
    });

    
  }

  /// Pin message
  Future<void> pinMessage(String groupId, String messageId) async {
    

    await _messagesCollection(groupId).doc(messageId).update({
      'isPinned': true,
    });

    
  }

  /// Unpin message
  Future<void> unpinMessage(String groupId, String messageId) async {
    

    await _messagesCollection(groupId).doc(messageId).update({
      'isPinned': false,
    });

    
  }

  /// Get pinned messages
  Future<List<GroupMessage>> getPinnedMessages(String groupId) async {
    

    final snapshot = await _messagesCollection(groupId)
        .where('isPinned', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) =>
            GroupMessage.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  }

  /// Mark messages as read
  Future<void> markAsRead(String groupId, String oderId) async {
    // This could be optimized with batch writes for multiple messages
    // For now, we'll update the most recent unread messages
    final snapshot = await _messagesCollection(groupId)
        .where('readBy.$oderId', isNull: true)
        .limit(100)
        .get();

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {'readBy.$oderId': true});
    }
    await batch.commit();
  }

  /// Add system message
  Future<void> _addSystemMessage(String groupId, String content) async {
    await _messagesCollection(groupId).add({
      'groupId': groupId,
      'senderId': 'system',
      'senderName': 'System',
      'content': content,
      'type': MessageType.system.name,
      'readBy': <String, bool>{},
      'createdAt': FieldValue.serverTimestamp(),
      'isDeleted': false,
      'isPinned': false,
      'mentions': <String>[],
    });
  }

  // ============ MUTE/UNMUTE ============

  /// Mute group notifications
  Future<void> muteGroup(String groupId, String userId) async {
    

    await _groupsCollection.doc(groupId).update({
      'mutedBy': FieldValue.arrayUnion([userId]),
    });

    
  }

  /// Unmute group notifications
  Future<void> unmuteGroup(String groupId, String userId) async {
    

    await _groupsCollection.doc(groupId).update({
      'mutedBy': FieldValue.arrayRemove([userId]),
    });

    
  }

  // ============ UTILITIES ============

  String _generateInviteCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    var code = '';
    for (var i = 0; i < 8; i++) {
      code += chars[(random + i * 7) % chars.length];
    }
    return code;
  }

  /// Regenerate invite code
  Future<String> regenerateInviteCode(String groupId) async {
    final newCode = _generateInviteCode();

    await _groupsCollection.doc(groupId).update({
      'inviteCode': newCode,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    
    return newCode;
  }

  /// Get unread count for a group
  Future<int> getUnreadCount(String groupId, String userId) async {
    final snapshot = await _messagesCollection(groupId)
        .where('readBy.$userId', isNull: true)
        .where('senderId', isNotEqualTo: userId)
        .get();

    return snapshot.docs.length;
  }

  /// Get total unread count across all groups
  Future<int> getTotalUnreadCount(String userId) async {
    final groupsSnapshot = await _groupsCollection
        .where('memberIds', arrayContains: userId)
        .where('isActive', isEqualTo: true)
        .get();

    int total = 0;
    for (final groupDoc in groupsSnapshot.docs) {
      final count = await getUnreadCount(groupDoc.id, userId);
      total += count;
    }

    return total;
  }
}
