import 'dart:convert';

class UserModel {
  final String id;
  final String name;
  final String email;
  final String avatarUrl;
  final String status;
  final bool online;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.avatarUrl = '',
    this.status = '',
    this.online = false,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) => UserModel(
        id: map['\$id'] ?? '',
        name: map['name'] ?? '',
        email: map['email'] ?? '',
        avatarUrl: map['avatarUrl'] ?? '',
        status: map['status'] ?? '',
        online: map['online'] ?? false,
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'email': email,
        'avatarUrl': avatarUrl,
        'status': status,
        'online': online,
      };
}

class ChatModel {
  final String id;
  final String type;
  final String name;
  final String avatarUrl;
  final List<String> participantIds;
  final String lastMessage;
  final String? lastMessageTime;

  ChatModel({
    required this.id,
    required this.type,
    required this.name,
    this.avatarUrl = '',
    required this.participantIds,
    this.lastMessage = '',
    this.lastMessageTime,
  });

  factory ChatModel.fromMap(Map<String, dynamic> map) => ChatModel(
        id: map['\$id'] ?? '',
        type: map['type'] ?? 'direct',
        name: map['name'] ?? '',
        avatarUrl: map['avatarUrl'] ?? '',
        participantIds: List<String>.from(map['participantIds'] ?? []),
        lastMessage: map['lastMessage'] ?? '',
        lastMessageTime: map['lastMessageTime'],
      );

  Map<String, dynamic> toMap() => {
        'type': type,
        'name': name,
        'avatarUrl': avatarUrl,
        'participantIds': participantIds,
        'lastMessage': lastMessage,
        'lastMessageTime': lastMessageTime,
      };
}

class MessageModel {
  final String id;
  final String chatId;
  final String senderId;
  final String text;
  final String attachmentUrl;
  final String attachmentType;
  final String status;
  final DateTime createdAt;

  /// emoji -> list of userIds who reacted with it. Stored in Appwrite as a
  /// JSON-encoded string in the 'reactions' attribute.
  final Map<String, List<String>> reactions;

  /// Id of the message this one is replying to (empty if not a reply).
  final String replyToId;

  /// True once the sender has edited this message (shows "(edited)" like WA/TG).
  final bool isEdited;

  /// True if this message was forwarded from another chat (shows a
  /// "Forwarded" label like WhatsApp/Telegram).
  final bool isForwarded;

  MessageModel({
    required this.id,
    required this.chatId,
    required this.senderId,
    this.text = '',
    this.attachmentUrl = '',
    this.attachmentType = '',
    this.status = 'sent',
    required this.createdAt,
    this.reactions = const {},
    this.replyToId = '',
    this.isEdited = false,
    this.isForwarded = false,
  });

  static Map<String, List<String>> _parseReactions(dynamic raw) {
    if (raw == null || raw is! String || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return decoded.map((k, v) => MapEntry(k.toString(), List<String>.from(v)));
    } catch (_) {
      return {};
    }
  }

  factory MessageModel.fromMap(Map<String, dynamic> map) => MessageModel(
        id: map['\$id'] ?? '',
        chatId: map['chatId'] ?? '',
        senderId: map['senderId'] ?? '',
        text: map['message'] ?? map['text'] ?? '',
        attachmentUrl: map['mediaUrl'] ?? map['attachmentUrl'] ?? '',
        attachmentType: (map['type'] == null || map['type'] == 'text') ? '' : map['type'],
        status: map['status'] ?? 'sent',
        createdAt: DateTime.tryParse(map['\$createdAt'] ?? '') ?? DateTime.now(),
        reactions: _parseReactions(map['reactions']),
        replyToId: map['replyToId'] ?? '',
        isEdited: map['isEdited'] == true,
        isForwarded: map['isForwarded'] == true,
      );

  Map<String, dynamic> toMap() => {
        'chatId': chatId,
        'senderId': senderId,
        'text': text,
        'attachmentUrl': attachmentUrl,
        'attachmentType': attachmentType,
        'status': status,
      };
}

class GroupModel {
  final String id;
  final String name;
  final String description;
  final String avatarUrl;
  final List<String> memberIds;
  final List<String> adminIds;
  final bool isPublic;

  /// Admin controls (WhatsApp-style group permissions). All default to "off",
  /// so groups created before these existed behave exactly as before.
  final bool onlyAdminsSend; // members can read, only admins can write
  final bool onlyAdminsEdit; // only admins can change name / photo / description
  final bool onlyAdminsAdd; // only admins can add new members
  final bool needApproval; // joining needs an admin's OK
  final List<String> pendingIds; // people waiting for approval

  GroupModel({
    required this.id,
    required this.name,
    this.description = '',
    this.avatarUrl = '',
    this.memberIds = const [],
    this.adminIds = const [],
    this.isPublic = true,
    this.onlyAdminsSend = false,
    this.onlyAdminsEdit = false,
    this.onlyAdminsAdd = false,
    this.needApproval = false,
    this.pendingIds = const [],
  });

  factory GroupModel.fromMap(Map<String, dynamic> map) => GroupModel(
        id: map['\$id'] ?? '',
        name: map['name'] ?? '',
        description: map['description'] ?? '',
        avatarUrl: map['avatarUrl'] ?? '',
        memberIds: List<String>.from(map['memberIds'] ?? []),
        adminIds: List<String>.from(map['adminIds'] ?? []),
        isPublic: map['isPublic'] ?? true,
        onlyAdminsSend: map['onlyAdminsSend'] == true,
        onlyAdminsEdit: map['onlyAdminsEdit'] == true,
        onlyAdminsAdd: map['onlyAdminsAdd'] == true,
        needApproval: map['needApproval'] == true,
        pendingIds: List<String>.from(map['pendingIds'] ?? []),
      );

  bool isAdmin(String? userId) => userId != null && adminIds.contains(userId);

  /// The person who made the group (first admin).
  String get ownerId => adminIds.isNotEmpty ? adminIds.first : '';
}

class ChannelModel {
  final String id;
  final String name;
  final String description;
  final String avatarUrl;
  final String creatorId;
  final int subscriberCount;
  final List<String> subscriberIds;

  /// People allowed to post (WhatsApp-channel style: only admins post).
  final List<String> adminIds;

  /// Preview of the newest post, shown in the channel list.
  final String lastMessage;
  final String lastMessageAt; // ISO time string, '' if none
  final String pinnedMessageId;

  ChannelModel({
    required this.id,
    required this.name,
    this.description = '',
    this.avatarUrl = '',
    this.creatorId = '',
    this.subscriberCount = 0,
    this.subscriberIds = const [],
    this.adminIds = const [],
    this.lastMessage = '',
    this.lastMessageAt = '',
    this.pinnedMessageId = '',
  });

  factory ChannelModel.fromMap(Map<String, dynamic> map) {
    final subs = List<String>.from(map['subscriberIds'] ?? []);
    return ChannelModel(
      id: map['\$id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      avatarUrl: map['avatarUrl'] ?? '',
      creatorId: map['creatorId'] ?? '',
      subscriberCount: (map['subscriberCount'] as num?)?.toInt() ?? subs.length,
      subscriberIds: subs,
      adminIds: List<String>.from(map['adminIds'] ?? []),
      lastMessage: (map['lastMessage'] ?? '').toString(),
      lastMessageAt: (map['lastMessageAt'] ?? '').toString(),
      pinnedMessageId: (map['pinnedMessageId'] ?? '').toString(),
    );
  }

  /// The channel's owner. Channels made before admin roles existed have no
  /// creator saved — for those, the first subscriber is the one who made it.
  String get ownerId {
    if (creatorId.isNotEmpty) return creatorId;
    if (adminIds.isNotEmpty) return adminIds.first;
    return subscriberIds.isNotEmpty ? subscriberIds.first : '';
  }

  bool isOwner(String? userId) => userId != null && userId.isNotEmpty && ownerId == userId;

  bool isAdmin(String? userId) {
    if (userId == null || userId.isEmpty) return false;
    return isOwner(userId) || adminIds.contains(userId);
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'description': description,
        'avatarUrl': avatarUrl,
        'creatorId': creatorId,
        'subscriberCount': subscriberCount,
        'subscriberIds': subscriberIds,
      };
}

class AdModel {
  final String id;
  final String title;
  final String description;
  final String imageUrl;
  final String actionText;
  final String actionUrl;
  final String targetType;

  AdModel({
    required this.id,
    required this.title,
    this.description = '',
    this.imageUrl = '',
    this.actionText = 'Learn More',
    this.actionUrl = '',
    this.targetType = 'group',
  });

  factory AdModel.fromMap(Map<String, dynamic> map) => AdModel(
        id: map['\$id'] ?? '',
        title: map['title'] ?? '',
        description: map['description'] ?? '',
        imageUrl: map['bannerUrl'] ?? map['imageUrl'] ?? '',
        actionText: map['buttonText'] ?? map['actionText'] ?? 'Learn More',
        actionUrl: map['actionUrl'] ?? '',
        targetType: map['targetType'] ?? 'group',
      );
}
