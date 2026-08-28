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

  MessageModel({
    required this.id,
    required this.chatId,
    required this.senderId,
    this.text = '',
    this.attachmentUrl = '',
    this.attachmentType = '',
    this.status = 'sent',
    required this.createdAt,
  });

  factory MessageModel.fromMap(Map<String, dynamic> map) => MessageModel(
        id: map['\$id'] ?? '',
        chatId: map['chatId'] ?? '',
        senderId: map['senderId'] ?? '',
        text: map['message'] ?? map['text'] ?? '',
        attachmentUrl: map['mediaUrl'] ?? map['attachmentUrl'] ?? '',
        attachmentType: (map['type'] == null || map['type'] == 'text') ? '' : map['type'],
        status: map['status'] ?? 'sent',
        createdAt: DateTime.tryParse(map['\$createdAt'] ?? '') ?? DateTime.now(),
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

  GroupModel({
    required this.id,
    required this.name,
    this.description = '',
    this.avatarUrl = '',
    this.memberIds = const [],
    this.adminIds = const [],
    this.isPublic = true,
  });

  factory GroupModel.fromMap(Map<String, dynamic> map) => GroupModel(
        id: map['\$id'] ?? '',
        name: map['name'] ?? '',
        description: map['description'] ?? '',
        avatarUrl: map['avatarUrl'] ?? '',
        memberIds: List<String>.from(map['memberIds'] ?? []),
        adminIds: List<String>.from(map['adminIds'] ?? []),
        isPublic: map['isPublic'] ?? true,
      );
}

class ChannelModel {
  final String id;
  final String name;
  final String description;
  final String avatarUrl;
  final int subscriberCount;
  final List<String> subscriberIds;

  ChannelModel({
    required this.id,
    required this.name,
    this.description = '',
    this.avatarUrl = '',
    this.subscriberCount = 0,
    this.subscriberIds = const [],
  });

  factory ChannelModel.fromMap(Map<String, dynamic> map) => ChannelModel(
        id: map['\$id'] ?? '',
        name: map['name'] ?? '',
        description: map['description'] ?? '',
        avatarUrl: map['avatarUrl'] ?? '',
        subscriberCount: map['subscriberCount'] ?? 0,
        subscriberIds: List<String>.from(map['subscriberIds'] ?? []),
      );
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
