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
  record: ^6.2.1
  sqflite: ^2.4.1
  path: ^1.9.0
  audioplayers: ^6.1.0
  path_provider: ^2.1.4

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0

flutter:
  uses-material-design: true
FILEEOF

mkdir -p $(dirname .github/workflows/build_apk.yml)
cat > .github/workflows/build_apk.yml << 'FILEEOF'
name: Build Texter APK

on:
  push:
    branches: [ main ]
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repo
        uses: actions/checkout@v4

      - name: Set up Java
        uses: actions/setup-java@v4
        with:
          distribution: 'temurin'
          java-version: '17'

      - name: Set up Flutter
        uses: subosito/flutter-action@v2
        with:
          channel: 'stable'
          flutter-version: '3.24.0'

      - name: Scaffold missing android/ platform folder
        run: |
          if [ ! -d "android" ]; then
            flutter create --platforms=android --org com.texter --project-name texter .
          fi

      - name: Apply custom AndroidManifest
        run: cp android_overrides/AndroidManifest.xml android/app/src/main/AndroidManifest.xml

      - name: Set minSdkVersion for plugins (record package needs 23+)
        run: |
          sed -i 's/minSdkVersion flutter.minSdkVersion/minSdkVersion 23/' android/app/build.gradle || true
          sed -i 's/minSdk = flutter.minSdkVersion/minSdk = 23/' android/app/build.gradle || true
          sed -i 's/minSdk = flutter.minSdkVersion/minSdk = 23/' android/app/build.gradle.kts || true

      - name: Set NDK version required by plugins
        run: |
          sed -i "/minSdkVersion 23/a\\        ndkVersion = \"25.1.8937393\"" android/app/build.gradle || true
          sed -i "/minSdk = 23/a\\        ndkVersion = \"25.1.8937393\"" android/app/build.gradle || true
          sed -i "/minSdk = 23/a\\        ndkVersion = \"25.1.8937393\"" android/app/build.gradle.kts || true
          # Also replace if flutter.ndkVersion is already present as a line
          sed -i 's/ndkVersion = flutter.ndkVersion/ndkVersion = "25.1.8937393"/' android/app/build.gradle || true
          sed -i 's/ndkVersion = flutter.ndkVersion/ndkVersion = "25.1.8937393"/' android/app/build.gradle.kts || true

      - name: Bump compileSdk to 35 (required by flutter_plugin_android_lifecycle)
        run: |
          sed -i 's/compileSdkVersion flutter.compileSdkVersion/compileSdkVersion 35/' android/app/build.gradle || true
          sed -i 's/compileSdk = flutter.compileSdkVersion/compileSdk = 35/' android/app/build.gradle || true
          sed -i 's/compileSdk = flutter.compileSdkVersion/compileSdk = 35/' android/app/build.gradle.kts || true

      - name: Verify SDK/NDK values took effect
        run: |
          echo "---- app/build.gradle relevant lines ----"
          grep -n "compileSdk\|ndkVersion\|minSdk" android/app/build.gradle || true
          if [ -f android/app/build.gradle.kts ]; then
            echo "---- app/build.gradle.kts relevant lines ----"
            grep -n "compileSdk\|ndkVersion\|minSdk" android/app/build.gradle.kts || true
          fi

      - name: Bump Kotlin Gradle plugin version (required by unity_ads_plugin)
        run: |
          sed -i "s/id \"org.jetbrains.kotlin.android\" version \"[^\"]*\"/id \"org.jetbrains.kotlin.android\" version \"2.1.0\"/" android/settings.gradle || true
          sed -i "s/id(\"org.jetbrains.kotlin.android\") version \"[^\"]*\"/id(\"org.jetbrains.kotlin.android\") version \"2.1.0\"/" android/settings.gradle.kts || true

      - name: Bump Android Gradle Plugin version (Kotlin 2.1.0 needs AGP 7.3.1+)
        run: |
          sed -i "s/id \"com.android.application\" version \"[^\"]*\"/id \"com.android.application\" version \"8.3.0\"/" android/settings.gradle || true
          sed -i "s/id(\"com.android.application\") version \"[^\"]*\"/id(\"com.android.application\") version \"8.3.0\"/" android/settings.gradle.kts || true
          sed -i "s/distributionUrl=.*/distributionUrl=https\\\\:\\/\\/services.gradle.org\\/distributions\\/gradle-8.4-all.zip/" android/gradle/wrapper/gradle-wrapper.properties || true

      - name: Get dependencies
        run: flutter pub get

      - name: Patch plugin packages that use flutter.compileSdkVersion/minSdkVersion
        run: |
          find "$HOME/.pub-cache" -path "*/android/build.gradle" 2>/dev/null | while read f; do
            sed -i 's/compileSdkVersion flutter.compileSdkVersion/compileSdkVersion 35/' "$f" || true
            sed -i 's/compileSdk = flutter.compileSdkVersion/compileSdk = 35/' "$f" || true
            sed -i 's/minSdkVersion flutter.minSdkVersion/minSdkVersion 23/' "$f" || true
            sed -i 's/minSdk = flutter.minSdkVersion/minSdk = 23/' "$f" || true
          done

      - name: Build APK (release)
        run: flutter build apk --release

      - name: Upload APK artifact
        uses: actions/upload-artifact@v4
        with:
          name: texter-release-apk
          path: build/app/outputs/flutter-apk/app-release.apk
FILEEOF

mkdir -p $(dirname lib/services/local_db_service.dart)
cat > lib/services/local_db_service.dart << 'FILEEOF'
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/models.dart';

/// Local SQLite cache for messages — same approach WhatsApp/Telegram use:
/// messages are shown instantly from local disk on app open, while fresh
/// data syncs from the server in the background.
class LocalDbService {
  LocalDbService._internal();
  static final LocalDbService instance = LocalDbService._internal();

  Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = join(await getDatabasesPath(), 'texter_cache.db');
    return openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE messages (
            id TEXT PRIMARY KEY,
            chatId TEXT,
            senderId TEXT,
            message TEXT,
            mediaUrl TEXT,
            type TEXT,
            createdAt TEXT
          )
        ''');
        await db.execute('CREATE INDEX idx_chatId ON messages(chatId)');
      },
    );
  }

  Future<void> cacheMessages(String chatId, List<MessageModel> messages) async {
    final database = await db;
    final batch = database.batch();
    for (final m in messages) {
      batch.insert(
        'messages',
        _toRow(chatId, m),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> cacheMessage(String chatId, MessageModel m) async {
    final database = await db;
    await database.insert(
      'messages',
      _toRow(chatId, m),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Map<String, dynamic> _toRow(String chatId, MessageModel m) => {
        'id': m.id,
        'chatId': chatId,
        'senderId': m.senderId,
        'message': m.text,
        'mediaUrl': m.attachmentUrl,
        'type': m.attachmentType.isNotEmpty ? m.attachmentType : 'text',
        'createdAt': m.createdAt.toIso8601String(),
      };

  Future<List<MessageModel>> getCachedMessages(String chatId) async {
    final database = await db;
    final rows = await database.query(
      'messages',
      where: 'chatId = ?',
      whereArgs: [chatId],
      orderBy: 'createdAt ASC',
    );
    return rows.map((r) {
      final type = (r['type'] as String?) ?? 'text';
      return MessageModel(
        id: r['id'] as String,
        chatId: r['chatId'] as String,
        senderId: r['senderId'] as String,
        text: (r['message'] as String?) ?? '',
        attachmentUrl: (r['mediaUrl'] as String?) ?? '',
        attachmentType: type == 'text' ? '' : type,
        createdAt: DateTime.tryParse((r['createdAt'] as String?) ?? '') ?? DateTime.now(),
      );
    }).toList();
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
import '../services/local_db_service.dart';
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

    // Show cached messages instantly (WhatsApp/Telegram-style)
    final cached = await LocalDbService.instance.getCachedMessages(widget.chatId);
    if (cached.isNotEmpty && mounted) {
      setState(() => _messages = cached);
    }

    // Sync fresh data from server in the background
    try {
      final docs = await AppwriteService.instance.getMessages(widget.chatId);
      final fresh = docs.map((d) => MessageModel.fromMap(d.data..addAll({'\$id': d.$id, '\$createdAt': d.$createdAt}))).toList();
      await LocalDbService.instance.cacheMessages(widget.chatId, fresh);
      if (mounted) setState(() => _messages = fresh);
    } catch (_) {}

    _sub = AppwriteService.instance.subscribeToMessages(widget.chatId, (doc) {
      if (_messages.any((m) => m.id == doc.$id)) return;
      setState(() {
        final msg = MessageModel.fromMap(doc.data..addAll({'\$id': doc.$id, '\$createdAt': doc.$createdAt}));
        _messages.add(msg);
        LocalDbService.instance.cacheMessage(widget.chatId, msg);
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
        final msg = MessageModel.fromMap(doc.data..addAll({'\$id': doc.$id, '\$createdAt': doc.$createdAt}));
        setState(() => _messages.add(msg));
        LocalDbService.instance.cacheMessage(widget.chatId, msg);
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
        final msg = MessageModel.fromMap(doc.data..addAll({'\$id': doc.$id, '\$createdAt': doc.$createdAt}));
        setState(() => _messages.add(msg));
        LocalDbService.instance.cacheMessage(widget.chatId, msg);
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
import '../services/local_db_service.dart';
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

      // Show cached messages instantly (WhatsApp/Telegram-style)
      final cached = await LocalDbService.instance.getCachedMessages(widget.groupId);
      if (cached.isNotEmpty && mounted) {
        await _fetchSenderNames(cached);
        setState(() {
          _messages = cached;
          _loading = false;
        });
      }

      final msgDocs = await AppwriteService.instance.getMessages(widget.groupId);
      final adDocs = await AppwriteService.instance.getAds(targetType: 'group');
      final messages = msgDocs
          .map((d) => MessageModel.fromMap(d.data..addAll({'\$id': d.$id, '\$createdAt': d.$createdAt})))
          .toList();
      await _fetchSenderNames(messages);
      await LocalDbService.instance.cacheMessages(widget.groupId, messages);
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
      LocalDbService.instance.cacheMessage(widget.groupId, msg);
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
        final msg = MessageModel.fromMap(doc.data..addAll({'\$id': doc.$id, '\$createdAt': doc.$createdAt}));
        setState(() => _messages.add(msg));
        LocalDbService.instance.cacheMessage(widget.groupId, msg);
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
        final msg = MessageModel.fromMap(doc.data..addAll({'\$id': doc.$id, '\$createdAt': doc.$createdAt}));
        setState(() => _messages.add(msg));
        LocalDbService.instance.cacheMessage(widget.groupId, msg);
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

mkdir -p $(dirname lib/screens/channel_view_screen.dart)
cat > lib/screens/channel_view_screen.dart << 'FILEEOF'
import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import '../config/theme.dart';
import '../services/appwrite_service.dart';
import '../services/local_db_service.dart';
import '../models/models.dart';

class ChannelViewScreen extends StatefulWidget {
  final String channelId;
  const ChannelViewScreen({super.key, required this.channelId});

  @override
  State<ChannelViewScreen> createState() => _ChannelViewScreenState();
}

class _ChannelViewScreenState extends State<ChannelViewScreen> {
  final _controller = TextEditingController();
  List<MessageModel> _posts = [];
  ChannelModel? _channel;
  String? _myId;
  bool _loading = true;
  bool _busy = false;
  RealtimeSubscription? _sub;

  bool get _isSubscribed => _channel != null && _myId != null && _channel!.subscriberIds.contains(_myId);

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _sub?.close();
    super.dispose();
  }

  Future<void> _init() async {
    final user = await AppwriteService.instance.getCurrentUser();
    _myId = user?.$id;
    // Show cached posts instantly (WhatsApp/Telegram-style)
    final cached = await LocalDbService.instance.getCachedMessages(widget.channelId);
    if (cached.isNotEmpty && mounted) {
      setState(() {
        _posts = cached;
        _loading = false;
      });
    }

    try {
      final doc = await AppwriteService.instance.databases.getDocument(
        databaseId: 'messgram_db',
        collectionId: 'channels',
        documentId: widget.channelId,
      );
      final posts = await AppwriteService.instance.getMessages(widget.channelId);
      final freshPosts = posts
          .map((d) => MessageModel.fromMap(d.data..addAll({'\$id': d.$id, '\$createdAt': d.$createdAt})))
          .toList();
      await LocalDbService.instance.cacheMessages(widget.channelId, freshPosts);
      setState(() {
        _channel = ChannelModel.fromMap(doc.data..addAll({'\$id': doc.$id}));
        _posts = freshPosts;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load channel: $e')));
    }
    _sub ??= AppwriteService.instance.subscribeToMessages(widget.channelId, (doc) {
      if (_posts.any((p) => p.id == doc.$id)) return;
      if (!mounted) return;
      final msg = MessageModel.fromMap(doc.data..addAll({'\$id': doc.$id, '\$createdAt': doc.$createdAt}));
      setState(() => _posts.add(msg));
      LocalDbService.instance.cacheMessage(widget.channelId, msg);
    });
  }

  Future<void> _toggleSubscribe() async {
    if (_myId == null || _channel == null || _busy) return;
    setState(() => _busy = true);
    try {
      if (_isSubscribed) {
        await AppwriteService.instance.unsubscribeChannel(channelId: widget.channelId, userId: _myId!);
      } else {
        await AppwriteService.instance.subscribeChannel(channelId: widget.channelId, userId: _myId!);
      }
      await _init();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _post() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _myId == null || !_isSubscribed) return;
    _controller.clear();
    try {
      final doc = await AppwriteService.instance.sendMessage(chatId: widget.channelId, senderId: _myId!, text: text);
      if (!_posts.any((p) => p.id == doc.$id)) {
        final msg = MessageModel.fromMap(doc.data..addAll({'\$id': doc.$id, '\$createdAt': doc.$createdAt}));
        setState(() => _posts.add(msg));
        LocalDbService.instance.cacheMessage(widget.channelId, msg);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to post: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_channel?.name ?? 'Channel')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.cyan))
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  color: AppTheme.surface,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if ((_channel?.description ?? '').isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(_channel!.description, style: AppTheme.body(color: AppTheme.textSecondary)),
                        ),
                      Row(
                        children: [
                          Text('${_channel?.subscriberCount ?? 0} subscribers', style: AppTheme.body(size: 12.5, color: AppTheme.textSecondary)),
                          const Spacer(),
                          ElevatedButton(
                            onPressed: _busy ? null : _toggleSubscribe,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isSubscribed ? AppTheme.surfaceLight : AppTheme.cyan,
                              foregroundColor: _isSubscribed ? Colors.white : AppTheme.bg,
                              minimumSize: const Size(120, 40),
                            ),
                            child: Text(_isSubscribed ? 'Subscribed' : 'Subscribe'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _posts.isEmpty
                      ? Center(child: Text('No posts yet', style: AppTheme.body(color: AppTheme.textSecondary)))
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _posts.length,
                          itemBuilder: (context, i) {
                            final p = _posts[i];
                            return Container(
                              width: double.infinity,
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(14)),
                              child: Text(p.text, style: AppTheme.body(color: Colors.white)),
                            );
                          },
                        ),
                ),
                if (_isSubscribed)
                  SafeArea(
                    child: Container(
                      color: AppTheme.surface,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              style: AppTheme.body(color: Colors.white),
                              decoration: const InputDecoration(hintText: 'Post to channel'),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(colors: [AppTheme.cyan, AppTheme.pink]),
                            ),
                            child: IconButton(icon: const Icon(Icons.send, color: Colors.white, size: 20), onPressed: _post),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text('Subscribe to post in this channel', style: AppTheme.body(color: AppTheme.textSecondary)),
                    ),
                  ),
              ],
            ),
    );
  }
}
FILEEOF

