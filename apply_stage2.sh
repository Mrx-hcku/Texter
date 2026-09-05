mkdir -p $(dirname pubspec.yaml)
cat > pubspec.yaml << 'FILEEOF'
name: texter
description: Texter - Flutter messaging app
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  appwrite: ^13.0.0
  google_fonts: ^6.2.1
  image_picker: ^1.1.2
  provider: ^6.1.2
  intl: ^0.19.0
  cached_network_image: ^3.4.1
  unity_ads_plugin: ^0.3.20
  uuid: ^4.5.1
  file_picker: ^8.1.2
  url_launcher: ^6.3.1
  record: ^5.1.2
  audioplayers: ^6.1.0
  path_provider: ^2.1.4

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0

flutter:
  uses-material-design: true
FILEEOF

mkdir -p $(dirname android_overrides/AndroidManifest.xml)
cat > android_overrides/AndroidManifest.xml << 'FILEEOF'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
    <uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32"/>
    <uses-permission android:name="android.permission.CAMERA"/>
    <uses-permission android:name="android.permission.RECORD_AUDIO"/>
    <uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS"/>

    <application
        android:label="Texter"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">
            <meta-data
              android:name="io.flutter.embedding.android.NormalTheme"
              android:resource="@style/NormalTheme"
              />
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
            <intent-filter android:autoVerify="false">
                <action android:name="android.intent.action.VIEW"/>
                <category android:name="android.intent.category.DEFAULT"/>
                <category android:name="android.intent.category.BROWSABLE"/>
                <data android:scheme="texter" android:host="verify"/>
            </intent-filter>
        </activity>
        <meta-data
            android:name="flutterEmbedding"
            android:value="2" />
    </application>
</manifest>
FILEEOF

mkdir -p $(dirname lib/services/appwrite_service.dart)
cat > lib/services/appwrite_service.dart << 'FILEEOF'
import 'dart:convert';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import '../config/app_config.dart';

class AppwriteService {
  AppwriteService._internal() {
    client = Client()
      ..setEndpoint(AppwriteConfig.endpoint)
      ..setProject(AppwriteConfig.projectId)
      ..setSelfSigned(status: false);
    account = Account(client);
    databases = Databases(client);
    storage = Storage(client);
    realtime = Realtime(client);
  }

  static final AppwriteService instance = AppwriteService._internal();

  late final Client client;
  late final Account account;
  late final Databases databases;
  late final Storage storage;
  late final Realtime realtime;

  // ---------------- AUTH ----------------
  Future<models.User> signUp(String email, String password, String name) async {
    await account.create(
      userId: ID.unique(),
      email: email,
      password: password,
      name: name,
    );
    await login(email, password);
    final user = await account.get();
    await databases.createDocument(
      databaseId: AppwriteConfig.databaseId,
      collectionId: AppwriteConfig.usersCollection,
      documentId: user.$id,
      data: {
        'name': name,
        'email': email,
        'avatarUrl': '',
        'status': 'Hey there! I am using Texter',
        'online': true,
      },
    );
    return user;
  }

  Future<models.Session> login(String email, String password) {
    return account.createEmailPasswordSession(email: email, password: password);
  }

  Future<void> logout() => account.deleteSession(sessionId: 'current');

  Future<models.User?> getCurrentUser() async {
    try {
      return await account.get();
    } catch (_) {
      return null;
    }
  }

  Future<void> sendVerificationEmail() {
    return account.createVerification(url: 'https://mrx-hcku.github.io/Texter/verify.html');
  }

  Future<void> confirmVerification({required String userId, required String secret}) {
    return account.updateVerification(userId: userId, secret: secret);
  }

  // ---------------- CHATS ----------------
  Future<List<models.Document>> getChats(String userId) async {
    final res = await databases.listDocuments(
      databaseId: AppwriteConfig.databaseId,
      collectionId: AppwriteConfig.chatsCollection,
      queries: [Query.search('participantIds', userId)],
    );
    return res.documents;
  }

  Future<models.Document> createChat({
    required String type,
    required String name,
    required List<String> participantIds,
  }) {
    return databases.createDocument(
      databaseId: AppwriteConfig.databaseId,
      collectionId: AppwriteConfig.chatsCollection,
      documentId: ID.unique(),
      data: {
        'isGroup': type == 'group',
        'chatName': name,
        'participantIds': participantIds.join(','),
        'lastMessage': '',
      },
    );
  }

  /// Finds an existing direct chat between two users, or creates one.
  /// [otherName] is used only as the chat's display name if a new chat
  /// document has to be created.
  Future<models.Document> findOrCreateDirectChat({
    required String myId,
    required String otherId,
    required String otherName,
  }) async {
    final existing = await getChats(myId);
    for (final doc in existing) {
      if (doc.data['isGroup'] == false) {
        final ids = (doc.data['participantIds'] as String? ?? '').split(',').where((e) => e.isNotEmpty).toList();
        if (ids.contains(otherId)) return doc;
      }
    }
    return createChat(type: 'direct', name: otherName, participantIds: [myId, otherId]);
  }

  // ---------------- USERS ----------------
  Future<List<models.Document>> searchUsers(String query, {String? excludeId}) async {
    final queries = <String>[Query.limit(50)];
    if (query.trim().isNotEmpty) queries.add(Query.search('name', query.trim()));
    final res = await databases.listDocuments(
      databaseId: AppwriteConfig.databaseId,
      collectionId: AppwriteConfig.usersCollection,
      queries: queries,
    );
    if (excludeId == null) return res.documents;
    return res.documents.where((d) => d.$id != excludeId).toList();
  }

  Future<models.Document?> getUserDoc(String userId) async {
    try {
      return await databases.getDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.usersCollection,
        documentId: userId,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> updateUserProfile({required String userId, String? name, String? status, String? avatarUrl}) {
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (status != null) data['status'] = status;
    if (avatarUrl != null) data['avatarUrl'] = avatarUrl;
    return databases.updateDocument(
      databaseId: AppwriteConfig.databaseId,
      collectionId: AppwriteConfig.usersCollection,
      documentId: userId,
      data: data,
    );
  }

  Future<void> updateNotificationPrefs(String userId, Map<String, bool> prefs) {
    return databases.updateDocument(
      databaseId: AppwriteConfig.databaseId,
      collectionId: AppwriteConfig.usersCollection,
      documentId: userId,
      data: {'notifPrefs': jsonEncode(prefs)},
    );
  }

  Map<String, bool> parseNotificationPrefs(String? raw) {
    const defaults = {'messages': true, 'groups': true, 'channels': true, 'sound': true};
    if (raw == null || raw.isEmpty) return defaults;
    try {
      final decoded = Map<String, dynamic>.from(jsonDecode(raw));
      return defaults.map((k, v) => MapEntry(k, decoded[k] ?? v));
    } catch (_) {
      return defaults;
    }
  }


  // ---------------- MESSAGES ----------------
  Future<List<models.Document>> getMessages(String chatId) async {
    final res = await databases.listDocuments(
      databaseId: AppwriteConfig.databaseId,
      collectionId: AppwriteConfig.messagesCollection,
      queries: [
        Query.equal('chatId', chatId),
        Query.orderAsc('\$createdAt'),
        Query.limit(200),
      ],
    );
    return res.documents;
  }

  Future<models.Document?> getMessageById(String messageId) async {
    try {
      return await databases.getDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.messagesCollection,
        documentId: messageId,
      );
    } catch (_) {
      return null;
    }
  }

  Future<models.Document> sendMessage({
    required String chatId,
    required String senderId,
    String text = '',
    String attachmentUrl = '',
    String attachmentType = '',
  }) async {
    final doc = await databases.createDocument(
      databaseId: AppwriteConfig.databaseId,
      collectionId: AppwriteConfig.messagesCollection,
      documentId: ID.unique(),
      data: {
        'chatId': chatId,
        'senderId': senderId,
        'message': text,
        'mediaUrl': attachmentUrl,
        'type': attachmentType.isNotEmpty ? attachmentType : 'text',
      },
    );
    // Best-effort: only relevant for direct chats stored in the `chats`
    // collection. Groups/channels use their own doc ID as chatId and
    // don't have a matching `chats` document, so this must not fail send.
    try {
      await databases.updateDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.chatsCollection,
        documentId: chatId,
        data: {
          'lastMessage': text.isNotEmpty ? text : 'Attachment',
        },
      );
    } catch (_) {}
    return doc;
  }

  RealtimeSubscription subscribeToMessages(String chatId, Function(models.Document) onMessage) {
    final sub = realtime.subscribe([
      'databases.${AppwriteConfig.databaseId}.collections.${AppwriteConfig.messagesCollection}.documents'
    ]);
    sub.stream.listen((event) {
      final data = event.payload;
      if (data['chatId'] == chatId && event.events.any((e) => e.contains('create'))) {
        onMessage(models.Document.fromMap(data));
      }
    });
    return sub;
  }

  /// Generic realtime listener for a whole collection — calls [onChange]
  /// with the changed document and its Appwrite event list (e.g.
  /// ["...documents.*.create"]) on every create/update/delete.
  RealtimeSubscription subscribeToCollection(
    String collectionId,
    void Function(models.Document doc, List<String> events) onChange,
  ) {
    final sub = realtime.subscribe([
      'databases.${AppwriteConfig.databaseId}.collections.$collectionId.documents'
    ]);
    sub.stream.listen((event) {
      onChange(models.Document.fromMap(event.payload), event.events);
    });
    return sub;
  }

  // ---------------- GROUPS ----------------
  Future<List<models.Document>> getGroups() async {
    final res = await databases.listDocuments(
      databaseId: AppwriteConfig.databaseId,
      collectionId: AppwriteConfig.groupsCollection,
    );
    return res.documents;
  }

  Future<models.Document> createGroup({
    required String name,
    required String description,
    required List<String> memberIds,
    required String creatorId,
    bool isPublic = true,
  }) {
    return databases.createDocument(
      databaseId: AppwriteConfig.databaseId,
      collectionId: AppwriteConfig.groupsCollection,
      documentId: ID.unique(),
      data: {
        'name': name,
        'description': description,
        'avatarUrl': '',
        'memberIds': memberIds,
        'adminIds': [creatorId],
        'isPublic': isPublic,
      },
    );
  }

  Future<void> joinGroup({required String groupId, required String userId}) async {
    final doc = await databases.getDocument(
      databaseId: AppwriteConfig.databaseId,
      collectionId: AppwriteConfig.groupsCollection,
      documentId: groupId,
    );
    final members = List<String>.from(doc.data['memberIds'] ?? []);
    if (!members.contains(userId)) members.add(userId);
    await databases.updateDocument(
      databaseId: AppwriteConfig.databaseId,
      collectionId: AppwriteConfig.groupsCollection,
      documentId: groupId,
      data: {'memberIds': members},
    );
  }

  Future<void> leaveGroup({required String groupId, required String userId}) async {
    final doc = await databases.getDocument(
      databaseId: AppwriteConfig.databaseId,
      collectionId: AppwriteConfig.groupsCollection,
      documentId: groupId,
    );
    final members = List<String>.from(doc.data['memberIds'] ?? []);
    members.remove(userId);
    await databases.updateDocument(
      databaseId: AppwriteConfig.databaseId,
      collectionId: AppwriteConfig.groupsCollection,
      documentId: groupId,
      data: {'memberIds': members},
    );
  }

      data: {'memberIds': members},
    );
  }

  Future<models.Document> getGroupDoc(String groupId) {
    return databases.getDocument(
      databaseId: AppwriteConfig.databaseId,
      collectionId: AppwriteConfig.groupsCollection,
      documentId: groupId,
    );
  }

  Future<void> pinMessage({required String groupId, required String messageId}) {
    return databases.updateDocument(
      databaseId: AppwriteConfig.databaseId,
      collectionId: AppwriteConfig.groupsCollection,
      documentId: groupId,
      data: {'pinnedMessageId': messageId},
    );
  }

  Future<void> unpinMessage(String groupId) {
    return databases.updateDocument(
      databaseId: AppwriteConfig.databaseId,
      collectionId: AppwriteConfig.groupsCollection,
      documentId: groupId,
      data: {'pinnedMessageId': ''},
    );
  }

  // ---------------- CHANNELS ----------------
  Future<List<models.Document>> getChannels() async {
    final res = await databases.listDocuments(
      databaseId: AppwriteConfig.databaseId,
      collectionId: AppwriteConfig.channelsCollection,
    );
    return res.documents;
  }

  Future<models.Document> createChannel({
    required String name,
    required String description,
    required String creatorId,
  }) {
    return databases.createDocument(
      databaseId: AppwriteConfig.databaseId,
      collectionId: AppwriteConfig.channelsCollection,
      documentId: ID.unique(),
      data: {
        'name': name,
        'description': description,
        'avatarUrl': '',
        'subscriberCount': 1,
        'subscriberIds': [creatorId],
      },
    );
  }

  Future<void> subscribeChannel({required String channelId, required String userId}) async {
    final doc = await databases.getDocument(
      databaseId: AppwriteConfig.databaseId,
      collectionId: AppwriteConfig.channelsCollection,
      documentId: channelId,
    );
    final subs = List<String>.from(doc.data['subscriberIds'] ?? []);
    if (!subs.contains(userId)) subs.add(userId);
    await databases.updateDocument(
      databaseId: AppwriteConfig.databaseId,
      collectionId: AppwriteConfig.channelsCollection,
      documentId: channelId,
      data: {'subscriberIds': subs, 'subscriberCount': subs.length},
    );
  }

  Future<void> unsubscribeChannel({required String channelId, required String userId}) async {
    final doc = await databases.getDocument(
      databaseId: AppwriteConfig.databaseId,
      collectionId: AppwriteConfig.channelsCollection,
      documentId: channelId,
    );
    final subs = List<String>.from(doc.data['subscriberIds'] ?? []);
    subs.remove(userId);
    await databases.updateDocument(
      databaseId: AppwriteConfig.databaseId,
      collectionId: AppwriteConfig.channelsCollection,
      documentId: channelId,
      data: {'subscriberIds': subs, 'subscriberCount': subs.length},
    );
  }

  // ---------------- ADS ----------------
  Future<List<models.Document>> getAds({String? targetType}) async {
    final queries = <String>[];
    if (targetType != null) queries.add(Query.equal('targetType', targetType));
    final res = await databases.listDocuments(
      databaseId: AppwriteConfig.databaseId,
      collectionId: AppwriteConfig.adsCollection,
      queries: queries,
    );
    return res.documents;
  }

  // ---------------- STORAGE ----------------
  Future<String> uploadFile(String path, String fileName) async {
    final file = await storage.createFile(
      bucketId: AppwriteConfig.bucketId,
      fileId: ID.unique(),
      file: InputFile.fromPath(path: path, filename: fileName),
    );
    return '${AppwriteConfig.endpoint}/storage/buckets/${AppwriteConfig.bucketId}/files/${file.$id}/view?project=${AppwriteConfig.projectId}';
  }
}
FILEEOF

mkdir -p $(dirname lib/screens/group_chat_screen.dart)
cat > lib/screens/group_chat_screen.dart << 'FILEEOF'
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import '../config/theme.dart';
import '../services/appwrite_service.dart';
import '../services/ads_service.dart';
import '../models/models.dart';
import '../widgets/sponsored_ad_card.dart';

class GroupChatScreen extends StatefulWidget {
  final String groupId;
  final String groupName;
  const GroupChatScreen({super.key, required this.groupId, required this.groupName});

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final _controller = TextEditingController();
  List<MessageModel> _messages = [];
  List<AdModel> _ads = [];
  String? _myId;
  bool _loading = true;
  bool _isAdmin = false;
  MessageModel? _pinnedMessage;
  final Map<String, String> _senderNames = {};
  RealtimeSubscription? _sub;
  bool _uploading = false;

  final _recorder = AudioRecorder();
  bool _recording = false;
  Duration _recordDuration = Duration.zero;
  String? _recordPath;

  final _player = AudioPlayer();
  String? _playingId;

  @override
  void initState() {
    super.initState();
    _init();
    AdsService.showInterstitial();
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playingId = null);
    });
  }

  @override
  void dispose() {
    _sub?.close();
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final user = await AppwriteService.instance.getCurrentUser();
    _myId = user?.$id;
    try {
      final groupDoc = await AppwriteService.instance.getGroupDoc(widget.groupId);
      final adminIds = List<String>.from(groupDoc.data['adminIds'] ?? []);
      _isAdmin = _myId != null && adminIds.contains(_myId);
      final pinnedId = groupDoc.data['pinnedMessageId'] as String?;
      if (pinnedId != null && pinnedId.isNotEmpty) {
        final pinnedDoc = await AppwriteService.instance.getMessageById(pinnedId);
        if (pinnedDoc != null) {
          _pinnedMessage = MessageModel.fromMap(pinnedDoc.data..addAll({'\$id': pinnedDoc.$id, '\$createdAt': pinnedDoc.$createdAt}));
        }
      }

      final msgDocs = await AppwriteService.instance.getMessages(widget.groupId);
      final adDocs = await AppwriteService.instance.getAds(targetType: 'group');
      final messages = msgDocs
          .map((d) => MessageModel.fromMap(d.data..addAll({'\$id': d.$id, '\$createdAt': d.$createdAt})))
          .toList();
      await _fetchSenderNames(messages);
      setState(() {
        _messages = messages;
        _ads = adDocs.map((d) => AdModel.fromMap(d.data..addAll({'\$id': d.$id}))).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load: $e')));
    }
    _sub ??= AppwriteService.instance.subscribeToMessages(widget.groupId, (doc) async {
      if (_messages.any((m) => m.id == doc.$id)) return;
      final msg = MessageModel.fromMap(doc.data..addAll({'\$id': doc.$id, '\$createdAt': doc.$createdAt}));
      if (msg.senderId != _myId && !_senderNames.containsKey(msg.senderId)) {
        final u = await AppwriteService.instance.getUserDoc(msg.senderId);
        _senderNames[msg.senderId] = u?.data['name'] ?? 'Unknown';
      }
      if (!mounted) return;
      setState(() => _messages.add(msg));
    });
  }

  Future<void> _fetchSenderNames(List<MessageModel> messages) async {
    final ids = messages.map((m) => m.senderId).toSet();
    ids.removeWhere((id) => id == _myId || _senderNames.containsKey(id));
    for (final id in ids) {
      final doc = await AppwriteService.instance.getUserDoc(id);
      _senderNames[id] = doc?.data['name'] ?? 'Unknown';
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _myId == null) return;
    _controller.clear();
    try {
      final doc = await AppwriteService.instance.sendMessage(chatId: widget.groupId, senderId: _myId!, text: text);
      if (!_messages.any((m) => m.id == doc.$id)) {
        setState(() {
          _messages.add(MessageModel.fromMap(doc.data..addAll({'\$id': doc.$id, '\$createdAt': doc.$createdAt})));
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send: $e')));
    }
  }

  Future<void> _sendMedia({required String path, required String fileName, required String type, String text = ''}) async {
    if (_myId == null) return;
    setState(() => _uploading = true);
    try {
      final url = await AppwriteService.instance.uploadFile(path, fileName);
      final doc = await AppwriteService.instance.sendMessage(
        chatId: widget.groupId,
        senderId: _myId!,
        text: text,
        attachmentUrl: url,
        attachmentType: type,
      );
      if (!_messages.any((m) => m.id == doc.$id)) {
        setState(() {
          _messages.add(MessageModel.fromMap(doc.data..addAll({'\$id': doc.$id, '\$createdAt': doc.$createdAt})));
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to upload: $e')));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: source);
    if (file == null) return;
    await _sendMedia(path: file.path, fileName: file.name, type: 'image');
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(withData: false);
    if (result == null || result.files.single.path == null) return;
    await _sendMedia(path: result.files.single.path!, fileName: result.files.single.name, type: 'file', text: result.files.single.name);
  }

  Future<void> _startRecording() async {
    if (!await _recorder.hasPermission()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Microphone permission denied')));
      return;
    }
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(const RecordConfig(), path: path);
    setState(() {
      _recording = true;
      _recordPath = path;
      _recordDuration = Duration.zero;
    });
    _tickRecording();
  }

  Future<void> _tickRecording() async {
    while (_recording && mounted) {
      await Future.delayed(const Duration(seconds: 1));
      if (_recording && mounted) {
        setState(() => _recordDuration += const Duration(seconds: 1));
      }
    }
  }

  Future<void> _stopRecording({bool send = true}) async {
    final path = await _recorder.stop();
    setState(() => _recording = false);
    if (!send || path == null) return;
    final duration = '${_recordDuration.inMinutes}:${(_recordDuration.inSeconds % 60).toString().padLeft(2, '0')}';
    await _sendMedia(path: path, fileName: 'voice.m4a', type: 'voice', text: duration);
  }

  Future<void> _togglePlay(MessageModel m) async {
    if (_playingId == m.id) {
      await _player.pause();
      setState(() => _playingId = null);
    } else {
      await _player.play(UrlSource(m.attachmentUrl));
      setState(() => _playingId = m.id);
    }
  }

  Future<void> _pinMessage(MessageModel m) async {
    try {
      await AppwriteService.instance.pinMessage(groupId: widget.groupId, messageId: m.id);
      setState(() => _pinnedMessage = m);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to pin: $e')));
    }
  }

  Future<void> _unpinMessage() async {
    try {
      await AppwriteService.instance.unpinMessage(widget.groupId);
      setState(() => _pinnedMessage = null);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to unpin: $e')));
    }
  }

  void _showMessageOptions(MessageModel m) {
    if (!_isAdmin) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.push_pin_outlined, color: AppTheme.cyan),
              title: Text('Pin this message', style: AppTheme.body(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _pinMessage(m);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _attachIcon(IconData icon, VoidCallback onTap) {
    return IconButton(icon: Icon(icon, color: AppTheme.textSecondary, size: 22), onPressed: _uploading ? null : onTap);
  }

  @override
  Widget build(BuildContext context) {
    final feed = <Widget>[];
    for (int i = 0; i < _messages.length; i++) {
      final m = _messages[i];
      final mine = m.senderId == _myId;
      final senderName = mine ? '' : (_senderNames[m.senderId] ?? '');
      Widget content;
      if (m.attachmentType == 'image' && m.attachmentUrl.isNotEmpty) {
        content = ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(m.attachmentUrl, width: 200, fit: BoxFit.cover));
      } else if (m.attachmentType == 'voice' && m.attachmentUrl.isNotEmpty) {
        content = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(_playingId == m.id ? Icons.pause_circle : Icons.play_circle, color: mine ? AppTheme.bg : AppTheme.cyan, size: 30),
              onPressed: () => _togglePlay(m),
              padding: EdgeInsets.zero,
            ),
            Text(m.text.isNotEmpty ? m.text : 'Voice', style: TextStyle(color: mine ? AppTheme.bg : Colors.white)),
          ],
        );
      } else if (m.attachmentType == 'file' && m.attachmentUrl.isNotEmpty) {
        content = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insert_drive_file, color: mine ? AppTheme.bg : AppTheme.cyan),
            const SizedBox(width: 6),
            Flexible(child: Text(m.text.isNotEmpty ? m.text : 'File', style: TextStyle(color: mine ? AppTheme.bg : Colors.white))),
          ],
        );
      } else {
        content = Text(m.text, style: TextStyle(color: mine ? AppTheme.bg : Colors.white));
      }

      feed.add(GestureDetector(
        onLongPress: () => _showMessageOptions(m),
        child: Align(
          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
            decoration: BoxDecoration(
              color: mine ? AppTheme.cyan : AppTheme.surface,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(mine ? 16 : 4),
                bottomRight: Radius.circular(mine ? 4 : 16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!mine && senderName.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(senderName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.pink)),
                  ),
                content,
              ],
            ),
          ),
        ),
      ));
      if (_ads.isNotEmpty && (i + 1) % 6 == 0) {
        feed.add(SponsoredAdCard(ad: _ads[(i ~/ 6) % _ads.length]));
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.groupName)),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.cyan))
          : Column(
              children: [
                if (_pinnedMessage != null)
                  Container(
                    width: double.infinity,
                    color: AppTheme.surfaceLight,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.push_pin, size: 16, color: AppTheme.cyan),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Pinned: ${_pinnedMessage!.text.isNotEmpty ? _pinnedMessage!.text : 'Attachment'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.body(size: 12.5, color: Colors.white),
                          ),
                        ),
                        if (_isAdmin)
                          GestureDetector(
                            onTap: _unpinMessage,
                            child: const Icon(Icons.close, size: 16, color: AppTheme.textSecondary),
                          ),
                      ],
                    ),
                  ),
                Expanded(
                  child: feed.isEmpty
                      ? Center(child: Text('No messages yet — say hi!', style: AppTheme.body(color: AppTheme.textSecondary)))
                      : ListView(padding: const EdgeInsets.all(12), children: feed),
                ),
                if (_uploading) LinearProgressIndicator(minHeight: 2, color: AppTheme.cyan, backgroundColor: AppTheme.surface),
                if (_recording)
                  Container(
                    color: AppTheme.surface,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        const Icon(Icons.fiber_manual_record, color: AppTheme.pink, size: 14),
                        const SizedBox(width: 8),
                        Text(
                          '${_recordDuration.inMinutes}:${(_recordDuration.inSeconds % 60).toString().padLeft(2, '0')}',
                          style: AppTheme.body(color: Colors.white),
                        ),
                        const Spacer(),
                        TextButton(onPressed: () => _stopRecording(send: false), child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondary))),
                        TextButton(onPressed: () => _stopRecording(send: true), child: const Text('Send', style: TextStyle(color: AppTheme.cyan))),
                      ],
                    ),
                  ),
                SafeArea(
                  child: Container(
                    color: AppTheme.surface,
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    child: Row(
                      children: [
                        _attachIcon(Icons.camera_alt_outlined, () => _pickImage(ImageSource.camera)),
                        _attachIcon(Icons.photo_outlined, () => _pickImage(ImageSource.gallery)),
                        _attachIcon(Icons.attach_file, _pickFile),
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            style: AppTheme.body(color: Colors.white),
                            decoration: const InputDecoration(hintText: 'Message', isDense: true),
                          ),
                        ),
                        _attachIcon(Icons.mic_none, _startRecording),
                        const SizedBox(width: 4),
                        Container(
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(colors: [AppTheme.cyan, AppTheme.pink]),
                          ),
                          child: IconButton(icon: const Icon(Icons.send, color: Colors.white, size: 20), onPressed: _send),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
FILEEOF

mkdir -p $(dirname lib/screens/one_to_one_chat_screen.dart)
cat > lib/screens/one_to_one_chat_screen.dart << 'FILEEOF'
import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import '../config/theme.dart';
import '../services/appwrite_service.dart';
import '../models/models.dart';

class OneToOneChatScreen extends StatefulWidget {
  final String chatId;
  final String chatName;
  const OneToOneChatScreen({super.key, required this.chatId, required this.chatName});

  @override
  State<OneToOneChatScreen> createState() => _OneToOneChatScreenState();
}

class _OneToOneChatScreenState extends State<OneToOneChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  List<MessageModel> _messages = [];
  String? _myId;
  RealtimeSubscription? _sub;
  bool _uploading = false;

  final _recorder = AudioRecorder();
  bool _recording = false;
  Duration _recordDuration = Duration.zero;

  final _player = AudioPlayer();
  String? _playingId;

  @override
  void initState() {
    super.initState();
    _init();
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playingId = null);
    });
  }

  Future<void> _init() async {
    final user = await AppwriteService.instance.getCurrentUser();
    _myId = user?.$id;
    final docs = await AppwriteService.instance.getMessages(widget.chatId);
    setState(() {
      _messages = docs.map((d) => MessageModel.fromMap(d.data..addAll({'\$id': d.$id, '\$createdAt': d.$createdAt}))).toList();
    });
    _sub = AppwriteService.instance.subscribeToMessages(widget.chatId, (doc) {
      if (_messages.any((m) => m.id == doc.$id)) return;
      setState(() {
        _messages.add(MessageModel.fromMap(doc.data..addAll({'\$id': doc.$id, '\$createdAt': doc.$createdAt})));
      });
    });
  }

  @override
  void dispose() {
    _sub?.close();
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _myId == null) return;
    _controller.clear();
    try {
      final doc = await AppwriteService.instance.sendMessage(chatId: widget.chatId, senderId: _myId!, text: text);
      if (!_messages.any((m) => m.id == doc.$id)) {
        setState(() {
          _messages.add(MessageModel.fromMap(doc.data..addAll({'\$id': doc.$id, '\$createdAt': doc.$createdAt})));
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send: $e')));
    }
  }

  Future<void> _sendMedia({required String path, required String fileName, required String type, String text = ''}) async {
    if (_myId == null) return;
    setState(() => _uploading = true);
    try {
      final url = await AppwriteService.instance.uploadFile(path, fileName);
      final doc = await AppwriteService.instance.sendMessage(
        chatId: widget.chatId,
        senderId: _myId!,
        text: text,
        attachmentUrl: url,
        attachmentType: type,
      );
      if (!_messages.any((m) => m.id == doc.$id)) {
        setState(() {
          _messages.add(MessageModel.fromMap(doc.data..addAll({'\$id': doc.$id, '\$createdAt': doc.$createdAt})));
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to upload: $e')));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: source);
    if (file == null) return;
    await _sendMedia(path: file.path, fileName: file.name, type: 'image');
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(withData: false);
    if (result == null || result.files.single.path == null) return;
    await _sendMedia(path: result.files.single.path!, fileName: result.files.single.name, type: 'file', text: result.files.single.name);
  }

  Future<void> _startRecording() async {
    if (!await _recorder.hasPermission()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Microphone permission denied')));
      return;
    }
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(const RecordConfig(), path: path);
    setState(() {
      _recording = true;
      _recordDuration = Duration.zero;
    });
    _tickRecording();
  }

  Future<void> _tickRecording() async {
    while (_recording && mounted) {
      await Future.delayed(const Duration(seconds: 1));
      if (_recording && mounted) {
        setState(() => _recordDuration += const Duration(seconds: 1));
      }
    }
  }

  Future<void> _stopRecording({bool send = true}) async {
    final path = await _recorder.stop();
    setState(() => _recording = false);
    if (!send || path == null) return;
    final duration = '${_recordDuration.inMinutes}:${(_recordDuration.inSeconds % 60).toString().padLeft(2, '0')}';
    await _sendMedia(path: path, fileName: 'voice.m4a', type: 'voice', text: duration);
  }

  Future<void> _togglePlay(MessageModel m) async {
    if (_playingId == m.id) {
      await _player.pause();
      setState(() => _playingId = null);
    } else {
      await _player.play(UrlSource(m.attachmentUrl));
      setState(() => _playingId = m.id);
    }
  }

  Future<void> _openFile(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open file')));
    }
  }

  Widget _attachIcon(IconData icon, VoidCallback onTap) {
    return IconButton(icon: Icon(icon, color: AppTheme.textSecondary, size: 22), onPressed: _uploading ? null : onTap);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.chatName),
        actions: [IconButton(icon: const Icon(Icons.more_vert), onPressed: () {})],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (context, i) {
                final m = _messages[i];
                final mine = m.senderId == _myId;
                Widget content;
                if (m.attachmentType == 'image' && m.attachmentUrl.isNotEmpty) {
                  content = ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(m.attachmentUrl, width: 200, fit: BoxFit.cover),
                  );
                } else if (m.attachmentType == 'voice' && m.attachmentUrl.isNotEmpty) {
                  content = Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(_playingId == m.id ? Icons.pause_circle : Icons.play_circle, color: mine ? AppTheme.bg : AppTheme.cyan, size: 30),
                        onPressed: () => _togglePlay(m),
                        padding: EdgeInsets.zero,
                      ),
                      Text(m.text.isNotEmpty ? m.text : 'Voice', style: TextStyle(color: mine ? AppTheme.bg : Colors.white)),
                    ],
                  );
                } else if (m.attachmentType == 'file' && m.attachmentUrl.isNotEmpty) {
                  content = InkWell(
                    onTap: () => _openFile(m.attachmentUrl),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.insert_drive_file, color: mine ? AppTheme.bg : AppTheme.cyan),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            m.text.isNotEmpty ? m.text : 'File',
                            style: TextStyle(color: mine ? AppTheme.bg : Colors.white, decoration: TextDecoration.underline),
                          ),
                        ),
                      ],
                    ),
                  );
                } else {
                  content = Text(m.text, style: TextStyle(color: mine ? AppTheme.bg : Colors.white));
                }
                return AnimatedAlign(
                  duration: const Duration(milliseconds: 200),
                  alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                    decoration: BoxDecoration(
                      color: mine ? AppTheme.cyan : AppTheme.surface,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(mine ? 16 : 4),
                        bottomRight: Radius.circular(mine ? 4 : 16),
                      ),
                    ),
                    child: content,
                  ),
                );
              },
            ),
          ),
          if (_uploading) LinearProgressIndicator(minHeight: 2, color: AppTheme.cyan, backgroundColor: AppTheme.surface),
          if (_recording)
            Container(
              color: AppTheme.surface,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.fiber_manual_record, color: AppTheme.pink, size: 14),
                  const SizedBox(width: 8),
                  Text(
                    '${_recordDuration.inMinutes}:${(_recordDuration.inSeconds % 60).toString().padLeft(2, '0')}',
                    style: AppTheme.body(color: Colors.white),
                  ),
                  const Spacer(),
                  TextButton(onPressed: () => _stopRecording(send: false), child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondary))),
                  TextButton(onPressed: () => _stopRecording(send: true), child: const Text('Send', style: TextStyle(color: AppTheme.cyan))),
                ],
              ),
            ),
          SafeArea(
            child: Container(
              color: AppTheme.surface,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Row(
                children: [
                  _attachIcon(Icons.camera_alt_outlined, () => _pickImage(ImageSource.camera)),
                  _attachIcon(Icons.photo_outlined, () => _pickImage(ImageSource.gallery)),
                  _attachIcon(Icons.attach_file, _pickFile),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      style: AppTheme.body(color: Colors.white),
                      decoration: const InputDecoration(hintText: 'Message', isDense: true),
                    ),
                  ),
                  _attachIcon(Icons.mic_none, _startRecording),
                  const SizedBox(width: 4),
                  Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: [AppTheme.cyan, AppTheme.pink]),
                    ),
                    child: IconButton(icon: const Icon(Icons.send, color: Colors.white, size: 20), onPressed: _send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
FILEEOF

mkdir -p $(dirname lib/screens/chat_list_screen.dart)
cat > lib/screens/chat_list_screen.dart << 'FILEEOF'
import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:intl/intl.dart';
import '../config/theme.dart';
import '../services/appwrite_service.dart';
import 'one_to_one_chat_screen.dart';
import 'new_chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  List<models.Document> _chats = [];
  String _query = '';
  bool _loading = true;
  String? _myId;
  RealtimeSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _sub?.close();
    super.dispose();
  }

  Future<void> _load() async {
    final user = await AppwriteService.instance.getCurrentUser();
    if (user == null) return;
    _myId = user.$id;
    try {
      final chats = await AppwriteService.instance.getChats(user.$id);
      setState(() {
        _chats = chats;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
    _sub ??= AppwriteService.instance.subscribeToCollection('chats', (doc, events) {
      final ids = (doc.data['participantIds'] as String? ?? '').split(',').where((e) => e.isNotEmpty).toList();
      if (_myId == null || !ids.contains(_myId)) return;
      if (!mounted) return;
      setState(() {
        final i = _chats.indexWhere((c) => c.$id == doc.$id);
        if (i >= 0) {
          _chats[i] = doc;
        } else {
          _chats.insert(0, doc);
        }
      });
    });
  }

  Widget _avatar(String name, {double radius = 22}) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppTheme.surfaceLight,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: AppTheme.heading(size: radius * 0.65, color: Colors.white70),
      ),
    );
  }

  String _formatTime(models.Document c) {
    final raw = c.$updatedAt;
    try {
      final dt = DateTime.parse(raw).toLocal();
      return DateFormat('HH:mm').format(dt);
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _chats.where((c) {
      final name = (c.data['chatName'] ?? '').toString().toLowerCase();
      return name.contains(_query.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Texter'),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: () {}),
          IconButton(icon: const Icon(Icons.edit_square), onPressed: () async {
            await Navigator.push(context, MaterialPageRoute(builder: (_) => const NewChatScreen()));
            _load();
          }),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        backgroundColor: AppTheme.surface,
        color: AppTheme.cyan,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                style: AppTheme.body(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Search',
                  prefixIcon: Icon(Icons.search, color: AppTheme.textSecondary),
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.cyan))
                  : filtered.isEmpty
                      ? Center(child: Text('No chats yet', style: AppTheme.body(color: AppTheme.textSecondary)))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: filtered.length,
                          itemBuilder: (context, i) {
                            final c = filtered[i];
                            final name = c.data['chatName'] ?? '';
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: AppTheme.surface,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: ListTile(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                leading: _avatar(name),
                                title: Text(name, style: AppTheme.body(size: 15, weight: FontWeight.w600, color: Colors.white)),
                                subtitle: Text(
                                  c.data['lastMessage'] ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTheme.body(size: 12.5, color: AppTheme.textSecondary),
                                ),
                                trailing: Text(_formatTime(c), style: AppTheme.body(size: 11, color: AppTheme.textSecondary)),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => OneToOneChatScreen(chatId: c.$id, chatName: name)),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.pink,
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const NewChatScreen()));
          _load();
        },
        child: const Icon(Icons.chat_bubble, color: Colors.white),
      ),
    );
  }
}
FILEEOF

mkdir -p $(dirname lib/screens/new_chat_screen.dart)
cat > lib/screens/new_chat_screen.dart << 'FILEEOF'
import 'package:flutter/material.dart';
import 'package:appwrite/models.dart' as models;
import '../config/theme.dart';
import '../services/appwrite_service.dart';
import 'one_to_one_chat_screen.dart';

class NewChatScreen extends StatefulWidget {
  const NewChatScreen({super.key});

  @override
  State<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  List<models.Document> _users = [];
  bool _loading = true;
  String? _myId;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load([String query = '']) async {
    setState(() => _loading = true);
    final me = await AppwriteService.instance.getCurrentUser();
    _myId = me?.$id;
    final users = await AppwriteService.instance.searchUsers(query, excludeId: _myId);
    setState(() {
      _users = users;
      _loading = false;
    });
  }

  Future<void> _startChat(models.Document user) async {
    if (_myId == null || _starting) return;
    setState(() => _starting = true);
    try {
      final chat = await AppwriteService.instance.findOrCreateDirectChat(
        myId: _myId!,
        otherId: user.$id,
        otherName: user.data['name'] ?? '',
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => OneToOneChatScreen(chatId: chat.$id, chatName: user.data['name'] ?? ''),
        ),
      );
    } catch (e) {
      setState(() => _starting = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not start chat: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Chat')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              onChanged: _load,
              style: AppTheme.body(color: Colors.white),
              decoration: const InputDecoration(hintText: 'Search by name', prefixIcon: Icon(Icons.search, color: AppTheme.textSecondary)),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.cyan))
                : _users.isEmpty
                    ? Center(child: Text('No users found', style: AppTheme.body(color: AppTheme.textSecondary)))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: _users.length,
                        itemBuilder: (context, i) {
                          final u = _users[i];
                          final name = u.data['name'] ?? '';
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(14)),
                            child: ListTile(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              leading: CircleAvatar(
                                backgroundColor: AppTheme.surfaceLight,
                                child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: AppTheme.heading(size: 14, color: Colors.white70)),
                              ),
                              title: Text(name, style: AppTheme.body(color: Colors.white, weight: FontWeight.w600)),
                              subtitle: Text(u.data['email'] ?? '', style: AppTheme.body(size: 12, color: AppTheme.textSecondary)),
                              onTap: () => _startChat(u),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
FILEEOF

mkdir -p $(dirname lib/screens/groups_screen.dart)
cat > lib/screens/groups_screen.dart << 'FILEEOF'
import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import '../config/theme.dart';
import '../services/appwrite_service.dart';
import '../models/models.dart';
import 'group_chat_screen.dart';
import 'create_group_screen.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  List<GroupModel> _myGroups = [];
  List<GroupModel> _discoverGroups = [];
  bool _loading = true;
  String? _myId;
  final Set<String> _joining = {};
  RealtimeSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _sub?.close();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final me = await AppwriteService.instance.getCurrentUser();
    _myId = me?.$id;
    try {
      final docs = await AppwriteService.instance.getGroups();
      final all = docs.map((d) => GroupModel.fromMap(d.data..addAll({'\$id': d.$id}))).toList();
      setState(() {
        _myGroups = all.where((g) => g.memberIds.contains(_myId)).toList();
        _discoverGroups = all.where((g) => g.isPublic && !g.memberIds.contains(_myId)).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load groups: $e')));
    }
    _sub ??= AppwriteService.instance.subscribeToCollection('groups', (doc, events) {
      _load();
    });
  }

  Future<void> _join(GroupModel g) async {
    if (_myId == null || _joining.contains(g.id)) return;
    setState(() => _joining.add(g.id));
    try {
      await AppwriteService.instance.joinGroup(groupId: g.id, userId: _myId!);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => GroupChatScreen(groupId: g.id, groupName: g.name)),
      ).then((_) => _load());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not join: $e')));
    } finally {
      if (mounted) setState(() => _joining.remove(g.id));
    }
  }

  Widget _groupTile(GroupModel g, {required bool isMember}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: AppTheme.surfaceLight,
          child: Text(g.name.isNotEmpty ? g.name[0].toUpperCase() : '?', style: AppTheme.heading(size: 15, color: Colors.white70)),
        ),
        title: Text(g.name, style: AppTheme.body(size: 15, weight: FontWeight.w600, color: Colors.white)),
        subtitle: Text(
          '${g.memberIds.length} members${g.isPublic ? '' : ' · Private'}',
          style: AppTheme.body(size: 12, color: AppTheme.textSecondary),
        ),
        trailing: isMember
            ? const Icon(Icons.chevron_right, color: AppTheme.textSecondary)
            : ElevatedButton(
                onPressed: _joining.contains(g.id) ? null : () => _join(g),
                style: ElevatedButton.styleFrom(minimumSize: const Size(70, 34), padding: EdgeInsets.zero),
                child: _joining.contains(g.id)
                    ? SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.bg))
                    : const Text('Join'),
              ),
        onTap: isMember
            ? () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => GroupChatScreen(groupId: g.id, groupName: g.name)),
                )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Groups'),
        actions: [IconButton(icon: const Icon(Icons.add), onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateGroupScreen()));
          _load();
        })],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.cyan))
          : RefreshIndicator(
              onRefresh: _load,
              backgroundColor: AppTheme.surface,
              color: AppTheme.cyan,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                children: [
                  if (_myGroups.isEmpty && _discoverGroups.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 60),
                      child: Center(child: Text('No groups yet — create one!', style: AppTheme.body(color: AppTheme.textSecondary))),
                    ),
                  if (_myGroups.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
                      child: Text('MY GROUPS', style: AppTheme.body(size: 12, weight: FontWeight.w700, color: AppTheme.cyan)),
                    ),
                    ..._myGroups.map((g) => _groupTile(g, isMember: true)),
                  ],
                  if (_discoverGroups.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
                      child: Text('DISCOVER PUBLIC GROUPS', style: AppTheme.body(size: 12, weight: FontWeight.w700, color: AppTheme.pink)),
                    ),
                    ..._discoverGroups.map((g) => _groupTile(g, isMember: false)),
                  ],
                ],
              ),
            ),
    );
  }
}
FILEEOF

mkdir -p $(dirname lib/screens/channels_screen.dart)
cat > lib/screens/channels_screen.dart << 'FILEEOF'
import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import '../config/theme.dart';
import '../services/appwrite_service.dart';
import '../models/models.dart';
import '../widgets/sponsored_ad_card.dart';
import 'create_channel_screen.dart';
import 'channel_view_screen.dart';

class ChannelsScreen extends StatefulWidget {
  const ChannelsScreen({super.key});

  @override
  State<ChannelsScreen> createState() => _ChannelsScreenState();
}

class _ChannelsScreenState extends State<ChannelsScreen> {
  List<ChannelModel> _channels = [];
  List<AdModel> _ads = [];
  bool _loading = true;
  RealtimeSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _sub?.close();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final chDocs = await AppwriteService.instance.getChannels();
      final adDocs = await AppwriteService.instance.getAds(targetType: 'channel');
      setState(() {
        _channels = chDocs.map((d) => ChannelModel.fromMap(d.data..addAll({'\$id': d.$id}))).toList();
        _ads = adDocs.map((d) => AdModel.fromMap(d.data..addAll({'\$id': d.$id}))).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load channels: $e')));
    }
    _sub ??= AppwriteService.instance.subscribeToCollection('channels', (doc, events) {
      _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final feed = <Widget>[];
    for (int i = 0; i < _channels.length; i++) {
      final c = _channels[i];
      feed.add(Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: AppTheme.surfaceLight,
              child: Text(c.name.isNotEmpty ? c.name[0].toUpperCase() : '?', style: AppTheme.heading(size: 15, color: Colors.white70)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.name, style: AppTheme.body(size: 15, weight: FontWeight.w600, color: Colors.white)),
                  const SizedBox(height: 2),
                  Text('${c.subscriberCount} subscribers', style: AppTheme.body(size: 12, color: AppTheme.textSecondary)),
                ],
              ),
            ),
            TextButton(
              onPressed: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => ChannelViewScreen(channelId: c.id)));
                _load();
              },
              child: const Text('View', style: TextStyle(color: AppTheme.cyan, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ));
      if (_ads.isNotEmpty && (i + 1) % 3 == 0) {
        feed.add(SponsoredAdCard(ad: _ads[(i ~/ 3) % _ads.length]));
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Channels'),
        actions: [IconButton(icon: const Icon(Icons.add), onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateChannelScreen()));
          _load();
        })],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.cyan))
          : RefreshIndicator(
              onRefresh: _load,
              backgroundColor: AppTheme.surface,
              color: AppTheme.cyan,
              child: feed.isEmpty
                  ? ListView(children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 80),
                        child: Center(child: Text('No channels yet', style: AppTheme.body(color: AppTheme.textSecondary))),
                      ),
                    ])
                  : ListView(padding: const EdgeInsets.all(12), children: feed),
            ),
    );
  }
}
FILEEOF

mkdir -p $(dirname lib/screens/profile_screen.dart)
cat > lib/screens/profile_screen.dart << 'FILEEOF'
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/theme.dart';
import '../services/appwrite_service.dart';
import 'login_screen.dart';
import 'account_screen.dart';
import 'notifications_screen.dart';
import 'privacy_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _name = '';
  String _email = '';
  String _avatarUrl = '';
  String _status = '';
  int _groupCount = 0;
  int _channelCount = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = await AppwriteService.instance.getCurrentUser();
    if (user == null) return;
    setState(() {
      _name = user.name;
      _email = user.email;
    });
    try {
      final doc = await AppwriteService.instance.getUserDoc(user.$id);
      final groups = await AppwriteService.instance.getGroups();
      final channels = await AppwriteService.instance.getChannels();
      if (!mounted) return;
      setState(() {
        _avatarUrl = doc?.data['avatarUrl'] ?? '';
        _status = doc?.data['status'] ?? '';
        _groupCount = groups.where((g) => List<String>.from(g.data['memberIds'] ?? []).contains(user.$id)).length;
        _channelCount = channels.where((c) => List<String>.from(c.data['subscriberIds'] ?? []).contains(user.$id)).length;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    await AppwriteService.instance.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Widget _statCard(String value, String label) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.surfaceLight),
        ),
        child: Column(
          children: [
            Text(value, style: AppTheme.heading(size: 20, color: AppTheme.cyan)),
            const SizedBox(height: 2),
            Text(label, style: AppTheme.body(size: 11, color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _tile(IconData icon, String label, {VoidCallback? onTap, Color? color}) {
    return ListTile(
      leading: Icon(icon, color: color ?? AppTheme.cyan),
      title: Text(label, style: AppTheme.body(color: color ?? Colors.white, weight: FontWeight.w500)),
      trailing: const Icon(Icons.chevron_right, size: 18, color: AppTheme.textSecondary),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.cyan))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 44,
                        backgroundColor: AppTheme.surfaceLight,
                        backgroundImage: _avatarUrl.isNotEmpty ? CachedNetworkImageProvider(_avatarUrl) : null,
                        child: _avatarUrl.isEmpty
                            ? Text(
                                _name.isNotEmpty ? _name[0].toUpperCase() : '?',
                                style: AppTheme.heading(size: 32, color: Colors.white70),
                              )
                            : null,
                      ),
                      const SizedBox(height: 12),
                      Text('@$_name', style: AppTheme.heading(size: 18)),
                      const SizedBox(height: 4),
                      Text(
                        _status.isNotEmpty ? _status : _email,
                        style: AppTheme.body(size: 12.5, color: AppTheme.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    _statCard('$_groupCount', 'Groups'),
                    _statCard('$_channelCount', 'Channels'),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    children: [
                      _tile(Icons.account_circle_outlined, 'Account', onTap: () async {
                        await Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountScreen()));
                        _load();
                      }),
                      Divider(height: 1, color: AppTheme.surfaceLight),
                      _tile(Icons.notifications_outlined, 'Notifications', onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
                      }),
                      Divider(height: 1, color: AppTheme.surfaceLight),
                      _tile(Icons.lock_outline, 'Privacy', onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyScreen()));
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(16)),
                  child: _tile(Icons.logout, 'Logout', color: AppTheme.pink, onTap: _logout),
                ),
              ],
            ),
    );
  }
}
FILEEOF

mkdir -p $(dirname lib/screens/account_screen.dart)
cat > lib/screens/account_screen.dart << 'FILEEOF'
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/theme.dart';
import '../services/appwrite_service.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _nameCtrl = TextEditingController();
  final _statusCtrl = TextEditingController();
  String _email = '';
  String? _userId;
  String _avatarUrl = '';
  bool _loading = true;
  bool _saving = false;
  bool _uploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = await AppwriteService.instance.getCurrentUser();
    if (user == null) return;
    _userId = user.$id;
    _email = user.email;
    _nameCtrl.text = user.name;
    try {
      final doc = await AppwriteService.instance.getUserDoc(user.$id);
      _statusCtrl.text = doc?.data['status'] ?? '';
      _avatarUrl = doc?.data['avatarUrl'] ?? '';
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _pickPhoto() async {
    if (_userId == null || _uploadingPhoto) return;
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, maxWidth: 800, imageQuality: 85);
    if (file == null) return;
    setState(() => _uploadingPhoto = true);
    try {
      final url = await AppwriteService.instance.uploadFile(file.path, file.name);
      await AppwriteService.instance.updateUserProfile(userId: _userId!, avatarUrl: url);
      setState(() => _avatarUrl = url);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile photo updated')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to upload photo: $e')));
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _save() async {
    if (_userId == null || _saving) return;
    setState(() => _saving = true);
    try {
      await AppwriteService.instance.account.updateName(name: _nameCtrl.text.trim());
      await AppwriteService.instance.updateUserProfile(
        userId: _userId!,
        name: _nameCtrl.text.trim(),
        status: _statusCtrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated')));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Account'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text('Save', style: TextStyle(color: AppTheme.cyan, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.cyan))
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: GestureDetector(
                      onTap: _pickPhoto,
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: AppTheme.surfaceLight,
                            backgroundImage: _avatarUrl.isNotEmpty ? CachedNetworkImageProvider(_avatarUrl) : null,
                            child: _avatarUrl.isEmpty
                                ? Text(
                                    _nameCtrl.text.isNotEmpty ? _nameCtrl.text[0].toUpperCase() : '?',
                                    style: AppTheme.heading(size: 36, color: Colors.white70),
                                  )
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(color: AppTheme.cyan, shape: BoxShape.circle),
                              child: _uploadingPhoto
                                  ? SizedBox(
                                      height: 16,
                                      width: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.bg),
                                    )
                                  : Icon(Icons.camera_alt, size: 16, color: AppTheme.bg),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _nameCtrl,
                    style: AppTheme.body(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Full Name'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _statusCtrl,
                    style: AppTheme.body(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Status / About'),
                  ),
                  const SizedBox(height: 12),
                  Text('Email: $_email', style: AppTheme.body(color: AppTheme.textSecondary)),
                ],
              ),
            ),
    );
  }
}
FILEEOF

mkdir -p $(dirname cleanup_users.js)
cat > cleanup_users.js << 'FILEEOF'
// cleanup_users.js
// Deletes documents in the "users" collection whose Auth account no
// longer exists (i.e. was deleted from Auth without cleaning up the
// matching database document).
// Run with: node cleanup_users.js

const ENDPOINT = "https://sgp.cloud.appwrite.io/v1";
const PROJECT_ID = "6a8e7ddd00107e2b7857";
const API_KEY = "YAHAN_APNI_API_KEY_DAALO";
const DB_ID = "messgram_db";

const headers = {
  "X-Appwrite-Project": PROJECT_ID,
  "X-Appwrite-Key": API_KEY,
  "Content-Type": "application/json",
};

async function listAuthUsers() {
  const res = await fetch(`${ENDPOINT}/users?queries[]=limit(100)`, { headers });
  const data = await res.json();
  if (!data.users) {
    console.error("Failed to list Auth users:", JSON.stringify(data));
    return [];
  }
  return data.users;
}

async function listUserDocs() {
  const res = await fetch(`${ENDPOINT}/databases/${DB_ID}/collections/users/documents?queries[]=limit(100)`, { headers });
  const data = await res.json();
  if (!data.documents) {
    console.error("Failed to list user documents:", JSON.stringify(data));
    return [];
  }
  return data.documents;
}

async function deleteDoc(id) {
  const res = await fetch(`${ENDPOINT}/databases/${DB_ID}/collections/users/documents/${id}`, {
    method: "DELETE",
    headers,
  });
  if (res.status === 204) {
    console.log(`  Deleted orphaned doc: ${id}`);
  } else {
    const out = await res.json().catch(() => ({}));
    console.error(`  ! Failed to delete ${id}:`, out.message || res.status);
  }
}

async function main() {
  console.log("Fetching Auth users...");
  const authUsers = await listAuthUsers();
  const authIds = new Set(authUsers.map((u) => u.$id));
  console.log(`Found ${authIds.size} real Auth accounts.`);

  console.log("Fetching user documents...");
  const docs = await listUserDocs();
  console.log(`Found ${docs.length} documents in the users collection.`);

  const orphans = docs.filter((d) => !authIds.has(d.$id));
  console.log(`Found ${orphans.length} orphaned documents (no matching Auth account).`);

  for (const doc of orphans) {
    console.log(`Deleting orphan: ${doc.name || doc.email || doc.$id}`);
    await deleteDoc(doc.$id);
  }

  console.log("\nDone! Remaining real accounts:");
  const remaining = docs.filter((d) => authIds.has(d.$id));
  remaining.forEach((d) => console.log(`  - ${d.name} (${d.email})`));
}

main().catch((e) => console.error(e));
FILEEOF

