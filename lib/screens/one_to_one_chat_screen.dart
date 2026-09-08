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
