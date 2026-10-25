import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import '../config/theme.dart';
import '../config/app_config.dart';
import '../services/appwrite_service.dart';
import '../services/local_db_service.dart';
import '../services/ads_service.dart';
import '../models/models.dart';
import '../widgets/sponsored_ad_card.dart';
import '../widgets/message_action_sheet.dart';
import '../widgets/reaction_bar.dart';
import '../widgets/reply_widgets.dart';
import '../services/net_utils.dart';
import '../widgets/media_compose_sheet.dart';
import 'media_viewer_screen.dart';
import 'forward_screen.dart';
import '../chat_bubble.dart';
import 'package:texter_video/texter_video.dart';
import '../widgets/media_expiry.dart';

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
  final Set<String> _activeUploads = {};
  final Set<String> _cancelledUploads = {};
  final Set<String> _compressing = {}; // videos being shrunk before upload
  bool get _uploading => _activeUploads.isNotEmpty;

  final _recorder = AudioRecorder();
  bool _recording = false;
  Duration _recordDuration = Duration.zero;

  final _player = AudioPlayer();
  String? _playingId;

  // Selection mode (long-press a message -> Select -> multi-pick -> delete)
  final Set<String> _selectedIds = {};
  bool get _isSelectionMode => _selectedIds.isNotEmpty;

  // Touch position tracking for Telegram-style reaction sheet popup
  TapDownDetails? _lastTapDownDetails;

  // Reply state (message currently being replied to)
  MessageModel? _replyingTo;

  // Edit state (WhatsApp/Telegram style)
  MessageModel? _editingMessage;

  // Offline outbox: messages typed while offline are sent automatically later
  Timer? _outboxTimer;
  bool _flushing = false;

  // Auto-scroll to latest + scroll-up pagination (unlimited history)
  final _scrollController = ScrollController();
  bool _loadingOlder = false;
  bool _noMoreOlder = false;

  late final ChatBubbleWatcher _bubbleWatcher;

  @override
  void initState() {
    super.initState();
    _bubbleWatcher = ChatBubbleWatcher(chatId: widget.groupId, kind: 'group', chatName: widget.groupName)..start(context);
    _init();
    AdsService.showInterstitial();
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playingId = null);
    });
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _bubbleWatcher.stop();
    _outboxTimer?.cancel();
    _sub?.close();
    _recorder.dispose();
    _player.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  // List ab reverse: true hai — maxScrollExtent = sabse purana loaded
  // message (screen ka top).
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 80 && !_loadingOlder && !_noMoreOlder) {
      _loadOlderMessages();
    }
  }

  Future<void> _loadOlderMessages() async {
    if (_messages.isEmpty || _loadingOlder) return;
    setState(() => _loadingOlder = true);
    try {
      final oldestRealId = _messages.firstWhere((m) => !m.id.startsWith('local_'), orElse: () => _messages.first).id;
      if (oldestRealId.startsWith('local_')) {
        setState(() => _loadingOlder = false);
        return;
      }
      final docs = await AppwriteService.instance.getMessages(widget.groupId, beforeMessageId: oldestRealId);
      if (docs.isEmpty) {
        _noMoreOlder = true;
      } else {
        final older = docs.map((d) => MessageModel.fromMap(d.data..addAll({'\$id': d.$id, '\$createdAt': d.$createdAt}))).toList();
        await _fetchSenderNames(older);
        // Reverse list me purane messages render-index ke FAR end (jahan
        // user already hai) pe map hote hain — scroll-position compensate
        // karne ki zaroorat nahi.
        if (mounted) setState(() => _messages.insertAll(0, older));
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingOlder = false);
    }
  }

  /// Sirf apna khud ka naya message bhejte waqt call karo. Reverse:true
  /// list me bottom = offset 0.
  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      if (animated) {
        _scrollController.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      } else {
        _scrollController.jumpTo(0);
      }
    });
  }

  Future<void> _init() async {
    final user = await AppwriteService.instance.getCurrentUser();
    _myId = user?.$id;
    // 1) Show cached messages immediately (works with no internet)
    try {
      final cached = await LocalDbService.instance.getCachedMessages(widget.groupId);
      final pending = await _pendingFromOutbox();
      if ((cached.isNotEmpty || pending.isNotEmpty) && mounted) {
        await _fetchSenderNames(cached);
        setState(() {
          _messages = [...cached, ...pending];
          _loading = false;
        });
      }
    } catch (_) {}

    // 2) Group info (admin / pinned). The cached copy is used when offline.
    try {
      final groupDoc = await AppwriteService.instance.getGroupDoc(widget.groupId);
      final adminIds = List<String>.from(groupDoc.data['adminIds'] ?? []);
      _isAdmin = _myId != null && adminIds.contains(_myId);
      final pinnedId = groupDoc.data['pinnedMessageId'] as String?;
      if (pinnedId != null && pinnedId.isNotEmpty) {
        final pinnedDoc = await AppwriteService.instance.getMessageById(pinnedId);
        if (pinnedDoc != null) {
          try {
            _pinnedMessage = MessageModel.fromMap(pinnedDoc.data..addAll({'\$id': pinnedDoc.$id, '\$createdAt': pinnedDoc.$createdAt}));
          } catch (_) {
            _pinnedMessage = MessageModel(
              id: pinnedDoc.$id,
              chatId: widget.groupId,
              senderId: pinnedDoc.data['senderId'] ?? '',
              text: '[Pinned message unavailable]',
              createdAt: DateTime.tryParse(pinnedDoc.$createdAt) ?? DateTime.now(),
            );
          }
        }
      }
      if (mounted) setState(() {});
    } catch (_) {}

    // 3) Sponsored ads (cached copy when offline)
    try {
      final adDocs = await AppwriteService.instance.getAds(targetType: 'group');
      if (mounted) {
        setState(() => _ads = adDocs.map((d) => AdModel.fromMap(d.data..addAll({'\$id': d.$id}))).toList());
      }
    } catch (_) {}

    // 4) Fresh messages from the server (silently skipped when offline)
    try {
      final msgDocs = await AppwriteService.instance.getMessages(widget.groupId);

      final List<MessageModel> messages = msgDocs.map<MessageModel>((d) {
        try {
          return MessageModel.fromMap(d.data..addAll({'\$id': d.$id, '\$createdAt': d.$createdAt}));
        } catch (_) {
          return MessageModel(
            id: d.$id,
            chatId: widget.groupId,
            senderId: d.data['senderId'] ?? '',
            text: '[Message unavailable or deleted]',
            createdAt: DateTime.tryParse(d.$createdAt) ?? DateTime.now(),
          );
        }
      }).toList();

      await _fetchSenderNames(messages);
      await LocalDbService.instance.cacheMessages(widget.groupId, messages);
      final stillPending = await _pendingFromOutbox();
      if (mounted) {
        setState(() {
          _messages = [...messages, ...stillPending];
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      if (!mounted) return;
      if (!NetErr.isNetwork(e)) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load: ${NetErr.friendly(e)}')));
      }
    }

    _outboxTimer ??= Timer.periodic(const Duration(seconds: 6), (_) => _flushOutbox());
    _flushOutbox();

    _sub ??= AppwriteService.instance.subscribeToMessages(
      widget.groupId,
      (doc) async {
        if (_messages.any((m) => m.id == doc.$id)) return;
        MessageModel msg;
        try {
          msg = MessageModel.fromMap(doc.data..addAll({'\$id': doc.$id, '\$createdAt': doc.$createdAt}));
        } catch (_) {
          msg = MessageModel(
            id: doc.$id,
            chatId: widget.groupId,
            senderId: doc.data['senderId'] ?? '',
            text: '[Message unavailable or deleted]',
            createdAt: DateTime.tryParse(doc.$createdAt) ?? DateTime.now(),
          );
        }

        if (msg.senderId != _myId && !_senderNames.containsKey(msg.senderId)) {
          final u = await AppwriteService.instance.getUserDoc(msg.senderId);
          _senderNames[msg.senderId] = u?.data['name'] ?? 'Unknown';
        }
        if (!mounted) return;
        setState(() => _messages.add(msg));
        LocalDbService.instance.cacheMessage(widget.groupId, msg);
        // Dusre member ka message — force-scroll nahi karte.
      },
      onUpdate: (doc) {
        if (!mounted) return;
        MessageModel updated;
        try {
          updated = MessageModel.fromMap(doc.data..addAll({'\$id': doc.$id, '\$createdAt': doc.$createdAt}));
        } catch (_) {
          return;
        }
        setState(() {
          final i = _messages.indexWhere((m) => m.id == doc.$id);
          if (i >= 0) _messages[i] = updated;
        });
        LocalDbService.instance.cacheMessage(widget.groupId, updated);
      },
      onDelete: (id) {
        LocalDbService.instance.deleteCachedMessage(id);
        if (!mounted) return;
        setState(() {
          _messages.removeWhere((m) => m.id == id);
          _selectedIds.remove(id);
        });
      },
    );
  }

  Future<void> _fetchSenderNames(List<MessageModel> messages) async {
    final ids = messages.map((m) => m.senderId).toSet();
    ids.removeWhere((id) => id == _myId || _senderNames.containsKey(id));
    for (final id in ids) {
      final doc = await AppwriteService.instance.getUserDoc(id);
      _senderNames[id] = doc?.data['name'] ?? 'Unknown';
    }
  }

  Future<List<MessageModel>> _pendingFromOutbox() async {
    final rows = await LocalDbService.instance.getOutbox(widget.groupId);
    return rows
        .map((r) => MessageModel(
              id: r['localId'] as String,
              chatId: widget.groupId,
              senderId: r['senderId'] as String,
              text: (r['message'] as String?) ?? '',
              createdAt: DateTime.tryParse((r['createdAt'] as String?) ?? '') ?? DateTime.now(),
              status: 'pending',
              replyToId: (r['replyToId'] as String?) ?? '',
            ))
        .toList();
  }

  /// Sends every message that was written while offline. Stops at the first
  /// network failure and tries again on the next timer tick.
  Future<void> _flushOutbox() async {
    if (_flushing || _myId == null) return;
    _flushing = true;
    try {
      final rows = await LocalDbService.instance.getOutbox(widget.groupId);
      for (final r in rows) {
        final localId = r['localId'] as String;
        try {
          final doc = await AppwriteService.instance.sendMessage(
            chatId: widget.groupId,
            senderId: r['senderId'] as String,
            text: (r['message'] as String?) ?? '',
            replyToId: (r['replyToId'] as String?) ?? '',
          );
          await LocalDbService.instance.removeOutbox(localId);
          final real = MessageModel.fromMap(doc.data..addAll({'\$id': doc.$id, '\$createdAt': doc.$createdAt}));
          LocalDbService.instance.cacheMessage(widget.groupId, real);
          if (!mounted) continue;
          setState(() {
            _messages.removeWhere((m) => m.id == localId);
            if (!_messages.any((m) => m.id == real.id)) _messages.add(real);
          });
        } catch (e) {
          if (NetErr.isNetwork(e)) break; // still offline
          await LocalDbService.instance.removeOutbox(localId); // permanent failure, drop it
          if (mounted) setState(() => _messages.removeWhere((m) => m.id == localId));
        }
      }
    } finally {
      _flushing = false;
    }
  }

  Future<void> _saveEdit() async {
    final text = _controller.text.trim();
    final editing = _editingMessage;
    if (text.isEmpty || editing == null) return;
    _controller.clear();
    setState(() => _editingMessage = null);
    try {
      final doc = await AppwriteService.instance.editMessage(
        messageId: editing.id,
        newText: text,
        chatId: widget.groupId,
        collectionId: AppwriteConfig.groupsCollection,
      );
      final updated = MessageModel.fromMap(doc.data..addAll({'\$id': doc.$id, '\$createdAt': doc.$createdAt}));
      LocalDbService.instance.cacheMessage(widget.groupId, updated);
      if (mounted) {
        setState(() {
          final i = _messages.indexWhere((m) => m.id == editing.id);
          if (i >= 0) _messages[i] = updated;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to edit: ${NetErr.friendly(e)}')));
    }
  }

  Future<void> _send() async {
    if (_editingMessage != null) {
      await _saveEdit();
      return;
    }
    final text = _controller.text.trim();
    if (text.isEmpty || _myId == null) return;
    _controller.clear();
    final replyId = _replyingTo?.id ?? '';
    final localId = 'local_${DateTime.now().microsecondsSinceEpoch}';
    final pending = MessageModel(
      id: localId,
      chatId: widget.groupId,
      senderId: _myId!,
      text: text,
      createdAt: DateTime.now(),
      status: 'pending',
      replyToId: replyId,
    );
    if (mounted) {
      setState(() {
        _replyingTo = null;
        _messages.add(pending);
      });
      _scrollToBottom();
    }
    try {
      final doc = await AppwriteService.instance.sendMessage(chatId: widget.groupId, senderId: _myId!, text: text, replyToId: replyId);
      final real = MessageModel.fromMap(doc.data..addAll({'\$id': doc.$id, '\$createdAt': doc.$createdAt}));
      LocalDbService.instance.cacheMessage(widget.groupId, real);
      if (mounted) {
        setState(() {
          _messages.removeWhere((m) => m.id == localId);
          if (!_messages.any((m) => m.id == real.id)) _messages.add(real);
        });
      }
    } catch (e) {
      if (NetErr.isNetwork(e)) {
        // Offline: keep it as a pending message, it will be sent automatically.
        await LocalDbService.instance.enqueueOutbox(
          localId: localId,
          chatId: widget.groupId,
          senderId: _myId!,
          text: text,
          replyToId: replyId,
          createdAt: pending.createdAt,
        );
      } else {
        if (!mounted) return;
        setState(() => _messages.removeWhere((m) => m.id == localId));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send: ${NetErr.friendly(e)}')));
      }
    }
  }

  // ---------- sending photos / files (Telegram style) ----------
  // The photo or file shows up in the chat right away with a round
  // progress + X badge. Tap it -> "Cancel sending".

  String _addPendingMedia({required String path, required String type, required String text, required String replyId}) {
    final localId = 'local_media_${DateTime.now().microsecondsSinceEpoch}';
    final pending = MessageModel(
      id: localId,
      chatId: widget.groupId,
      senderId: _myId!,
      text: text,
      createdAt: DateTime.now(),
      status: 'pending',
      replyToId: replyId,
      attachmentUrl: path,
      attachmentType: type,
    );
    if (mounted) setState(() => _messages.add(pending));
    _scrollToBottom();
    return localId;
  }

  Future<void> _uploadPendingMedia({
    required String localId,
    required String path,
    required String fileName,
    required String type,
    required String text,
    required String replyId,
  }) async {
    if (_cancelledUploads.contains(localId)) {
      _cancelledUploads.remove(localId);
      return;
    }
    if (mounted) setState(() => _activeUploads.add(localId));
    String? tempPath;
    try {
      var uploadPath = path;
      var uploadName = fileName;
      if (type == 'file' && await File(path).length() > kMaxFileBytes) {
        _rejectMedia(localId, 'File is too big (max 50 MB).');
        return;
      }
      if (type == 'video') {
        // Shrink the video first (like WhatsApp / Telegram); falls back to the original.
        if (mounted) setState(() => _compressing.add(localId));
        final small = await TexterVideo.compress(path, jobId: localId);
        if (mounted) setState(() => _compressing.remove(localId));
        if (_cancelledUploads.contains(localId)) return;
        if (small != null) {
          tempPath = small;
          uploadPath = small;
          final dot = fileName.lastIndexOf('.');
          uploadName = '${dot > 0 ? fileName.substring(0, dot) : fileName}.mp4';
        } else if (await File(path).length() > kMaxUncompressedVideoBytes) {
          _rejectMedia(localId, 'Could not compress this video and it is too large (over 50 MB). Pick a shorter one.');
          return;
        }
      }
      final url = await AppwriteService.instance.uploadFile(uploadPath, uploadName);
      if (_cancelledUploads.contains(localId)) return;
      final doc = await AppwriteService.instance.sendMessage(
        chatId: widget.groupId,
        senderId: _myId!,
        text: text,
        attachmentUrl: url,
        attachmentType: type,
        replyToId: replyId,
      );
      if (_cancelledUploads.contains(localId)) return;
      final real = MessageModel.fromMap(doc.data..addAll({'\$id': doc.$id, '\$createdAt': doc.$createdAt}));
      LocalDbService.instance.cacheMessage(widget.groupId, real);
      if (mounted) {
        setState(() {
          _messages.removeWhere((m) => m.id == localId);
          if (!_messages.any((m) => m.id == real.id)) _messages.add(real);
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (_cancelledUploads.contains(localId) || !mounted) return;
      setState(() => _messages.removeWhere((m) => m.id == localId));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to upload: ${NetErr.friendly(e)}')));
    } finally {
      _activeUploads.remove(localId);
      _cancelledUploads.remove(localId);
      _compressing.remove(localId);
      final tp = tempPath;
      if (tp != null) {
        try {
          File(tp).delete();
        } catch (_) {}
      }
      if (mounted) setState(() {});
    }
  }

  Future<void> _sendMedia({required String path, required String fileName, required String type, String text = ''}) async {
    if (_myId == null) return;
    final replyId = _replyingTo?.id ?? '';
    if (replyId.isNotEmpty && mounted) setState(() => _replyingTo = null);
    final localId = _addPendingMedia(path: path, type: type, text: text, replyId: replyId);
    await _uploadPendingMedia(localId: localId, path: path, fileName: fileName, type: type, text: text, replyId: replyId);
  }

  void _rejectMedia(String localId, String message) {
    if (!mounted) return;
    setState(() => _messages.removeWhere((m) => m.id == localId));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _cancelUpload(String localId) {
    _cancelledUploads.add(localId);
    TexterVideo.cancel(localId);
    _activeUploads.remove(localId);
    if (!mounted) return;
    setState(() => _messages.removeWhere((m) => m.id == localId));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Sending cancelled'), duration: Duration(seconds: 2)));
  }

  void _showCancelSending(MessageModel m) {
    final pal = ChatPalette.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: pal.sheet,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) => SafeArea(
        child: ListTile(
          leading: Icon(Icons.delete_outline, color: pal.sheetText),
          title: Text('Cancel sending', style: TextStyle(color: pal.sheetText, fontSize: 16)),
          onTap: () {
            Navigator.pop(ctx);
            _cancelUpload(m.id);
          },
        ),
      ),
    );
  }

  Widget _pendingMediaView(MessageModel m, ChatPalette p) {
    final Widget base;
    if (m.attachmentType == 'image') {
      base = Image.file(
        File(m.attachmentUrl),
        width: 200,
        height: 150,
        fit: BoxFit.cover,
        cacheWidth: 400,
        errorBuilder: (_, __, ___) => Container(width: 200, height: 150, color: p.panel),
      );
    } else {
      final icon = m.attachmentType == 'video'
          ? Icons.videocam_rounded
          : m.attachmentType == 'voice'
              ? Icons.mic_rounded
              : Icons.insert_drive_file_rounded;
      base = Container(width: 200, height: 150, color: p.panel, child: Center(child: Icon(icon, size: 42, color: p.accent)));
    }
    return GestureDetector(
      onTap: () => _showCancelSending(m),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 200,
          height: 150,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(child: base),
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                child: const Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(width: 46, height: 46, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)),
                    Icon(Icons.close_rounded, color: Colors.white, size: 24),
                  ],
                ),
              ),
              if (_compressing.contains(m.id))
                Positioned(
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10)),
                    child: const Text('Compressing…', style: TextStyle(color: Colors.white, fontSize: 11)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Camera: take a photo, add a caption, send.
  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final file = await ChatBubble.guard(() => picker.pickImage(source: source, maxWidth: kImageMaxSide, maxHeight: kImageMaxSide, imageQuality: kImageQuality));
    if (file == null || !mounted) return;
    final result = await showMediaComposeSheet(context, [PickedMedia(File(file.path), false)]);
    if (result == null) return;
    await _sendMultipleMedia(result);
  }

  /// Documents: pick, optional caption, send.
  Future<void> _pickFile() async {
    final result = await ChatBubble.guard(() => FilePicker.platform.pickFiles(withData: false));
    if (result == null || result.files.single.path == null || !mounted) return;
    final f = result.files.single;
    final caption = await showFileCaptionDialog(context, f.name);
    if (caption == null) return;
    final text = caption.isEmpty ? f.name : '${f.name}\n$caption';
    await _sendMedia(path: f.path!, fileName: f.name, type: 'file', text: text);
  }

  /// Gallery button: pick up to 5 photos/videos together, preview them
  /// WhatsApp/Telegram style, then upload + send one message per file.
  Future<void> _pickMultipleMedia() async {
    final picker = ImagePicker();
    final picked = await ChatBubble.guard(
      () => picker.pickMultipleMedia(limit: kMaxMediaFiles, maxWidth: kImageMaxSide, maxHeight: kImageMaxSide, imageQuality: kImageQuality),
    );
    if (picked.isEmpty || !mounted) return;
    final files = picked.map((x) => PickedMedia(File(x.path), _looksLikeVideo(x.path))).toList();
    final result = await showMediaComposeSheet(context, files);
    if (result == null) return;
    await _sendMultipleMedia(result);
  }

  /// All selected files appear in the chat immediately, then upload one by one.
  Future<void> _sendMultipleMedia(MediaComposeResult result) async {
    if (_myId == null) return;
    final replyId = _replyingTo?.id ?? '';
    if (replyId.isNotEmpty && mounted) setState(() => _replyingTo = null);
    final jobs = <Map<String, String>>[];
    for (var i = 0; i < result.files.length; i++) {
      final f = result.files[i];
      final type = f.isVideo ? 'video' : 'image';
      final text = i == 0 ? result.caption : '';
      final reply = i == 0 ? replyId : '';
      final id = _addPendingMedia(path: f.file.path, type: type, text: text, replyId: reply);
      jobs.add({'id': id, 'path': f.file.path, 'type': type, 'text': text, 'reply': reply});
    }
    for (final j in jobs) {
      await _uploadPendingMedia(
        localId: j['id']!,
        path: j['path']!,
        fileName: j['path']!.split('/').last,
        type: j['type']!,
        text: j['text']!,
        replyId: j['reply']!,
      );
    }
  }

  static const _videoExtensions = ['.mp4', '.mov', '.3gp', '.mkv', '.webm', '.avi', '.m4v'];
  bool _looksLikeVideo(String path) => _videoExtensions.any((ext) => path.toLowerCase().endsWith(ext));

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

  Future<void> _pinMessage(MessageModel m) async {
    try {
      await AppwriteService.instance.pinMessage(groupId: widget.groupId, messageId: m.id);
      setState(() => _pinnedMessage = m);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to pin: ${NetErr.friendly(e)}')));
    }
  }

  Future<void> _unpinMessage() async {
    try {
      await AppwriteService.instance.unpinMessage(widget.groupId);
      setState(() => _pinnedMessage = null);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to unpin: ${NetErr.friendly(e)}')));
    }
  }

  // ---------------- Selection / Delete / Reactions ----------------

  void _toggleSelect(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _deleteSingle(String id) async {
    final confirmed = await confirmDeleteMessages(context, 1);
    if (!confirmed) return;
    try {
      await AppwriteService.instance.deleteMessage(id, chatId: widget.groupId, collectionId: AppwriteConfig.groupsCollection);
      LocalDbService.instance.deleteCachedMessage(id);
      if (mounted) setState(() => _messages.removeWhere((m) => m.id == id));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete: ${NetErr.friendly(e)}')));
    }
  }

  Future<void> _deleteSelected() async {
    final ids = List<String>.from(_selectedIds);
    if (ids.isEmpty) return;
    final confirmed = await confirmDeleteMessages(context, ids.length);
    if (!confirmed) return;
    setState(() => _selectedIds.clear());
    for (final id in ids) {
      try {
        await AppwriteService.instance.deleteMessage(id, chatId: widget.groupId, collectionId: AppwriteConfig.groupsCollection);
        LocalDbService.instance.deleteCachedMessage(id);
        if (mounted) setState(() => _messages.removeWhere((m) => m.id == id));
      } catch (_) {}
    }
  }

  Future<void> _reactTo(MessageModel m, String emoji) async {
    if (_myId == null) return;
    try {
      final updatedDoc = await AppwriteService.instance.toggleReaction(messageId: m.id, userId: _myId!, emoji: emoji);
      final updated = MessageModel.fromMap(updatedDoc.data..addAll({'\$id': updatedDoc.$id, '\$createdAt': updatedDoc.$createdAt}));
      LocalDbService.instance.cacheMessage(widget.groupId, updated);
      if (!mounted) return;
      setState(() {
        final i = _messages.indexWhere((mm) => mm.id == m.id);
        if (i >= 0) _messages[i] = updated;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(NetErr.friendly(e))));
    }
  }

  void _showMessageOptions(MessageModel m, Offset tapPosition) {
    if (m.id.startsWith('local_')) return; // still sending / waiting for internet
    // Admins can delete anyone's message and pin; regular members only
    // their own message (and never pin). Editing is always sender-only,
    // even for admins (WhatsApp/Telegram never let anyone edit someone
    // else's words).
    final canDelete = m.senderId == _myId || _isAdmin;
    final isMine = m.senderId == _myId;
    showMessageActionSheet(
      context,
      tapPosition: tapPosition,
      canDelete: canDelete,
      messageText: m.text,
      onReact: (emoji) => _reactTo(m, emoji),
      onMoreEmojis: () async {
        final emoji = await showFullEmojiPicker(context);
        if (emoji != null) _reactTo(m, emoji);
      },
      onSelect: () => _toggleSelect(m.id),
      onDelete: canDelete ? () => _deleteSingle(m.id) : null,
      onPin: _isAdmin ? () => _pinMessage(m) : null,
      onReply: () => setState(() {
        _replyingTo = m;
        _editingMessage = null;
      }),
      onEdit: (isMine && m.attachmentType.isEmpty) ? () => _startEdit(m) : null,
      onForward: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => ForwardScreen(payload: ForwardPayload(text: m.text, attachmentUrl: m.attachmentUrl, attachmentType: m.attachmentType)),
      )),
    );
  }

  void _startEdit(MessageModel m) {
    setState(() {
      _editingMessage = m;
      _replyingTo = null;
      _controller.text = m.text;
      _controller.selection = TextSelection.collapsed(offset: m.text.length);
    });
  }

  String _nameOf(String senderId) => senderId == _myId ? 'You' : (_senderNames[senderId] ?? 'Member');

  Widget _buildReplyQuote(MessageModel m) {
    MessageModel? original;
    for (final x in _messages) {
      if (x.id == m.replyToId) {
        original = x;
        break;
      }
    }
    return ReplyQuote(senderName: original == null ? '' : _nameOf(original.senderId), original: original);
  }

  Widget _attachIcon(IconData icon, VoidCallback onTap, {Color? color}) {
    return IconButton(
      icon: Icon(icon, color: color ?? AppTheme.textSecondary, size: 22),
      onPressed: _uploading ? null : onTap,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = ChatPalette.of(context);
    final feed = <Widget>[];
    for (int i = 0; i < _messages.length; i++) {
      final m = _messages[i];
      final mine = m.senderId == _myId;
      final senderName = mine ? '' : (_senderNames[m.senderId] ?? '');
      final isUnavailable = m.text.contains('[Message unavailable');

      Widget content;
      if (isUnavailable) {
        content = Text(m.text, style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic));
      } else if (m.id.startsWith('local_media_')) {
        content = _pendingMediaView(m, p);
      } else if (isMediaExpired(type: m.attachmentType, url: m.attachmentUrl, createdAt: m.createdAt)) {
        content = expiredMediaView(p, mine);
      } else if (m.attachmentType == 'image' && m.attachmentUrl.isNotEmpty) {
        content = GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => MediaViewerScreen(url: m.attachmentUrl, isVideo: false, caption: m.text),
          )),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: m.attachmentUrl,
                        memCacheWidth: 500,
              width: 200,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                height: 150,
                width: 200,
                color: p.panel,
                child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.cyan)),
              ),
              errorWidget: (context, url, error) => Container(
                height: 150,
                width: 200,
                padding: const EdgeInsets.all(12),
                color: p.panel,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.broken_image_outlined, color: Colors.grey.shade500, size: 20),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text('Image unavailable', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      } else if (m.attachmentType == 'video' && m.attachmentUrl.isNotEmpty) {
        content = GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => MediaViewerScreen(url: m.attachmentUrl, isVideo: true, caption: m.text),
          )),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 200,
              height: 150,
              color: p.panel,
              child: const Center(child: Icon(Icons.play_circle_fill, color: Colors.white, size: 44)),
            ),
          ),
        );
      } else if (m.attachmentType == 'voice' && m.attachmentUrl.isNotEmpty) {
        content = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(_playingId == m.id ? Icons.pause_circle : Icons.play_circle, color: mine ? p.mineText : p.accent, size: 30),
              onPressed: () => _togglePlay(m),
              padding: EdgeInsets.zero,
            ),
            Text(m.text.isNotEmpty ? m.text : 'Voice', style: TextStyle(color: mine ? p.mineText : p.otherText)),
          ],
        );
      } else if (m.attachmentType == 'file' && m.attachmentUrl.isNotEmpty) {
        content = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insert_drive_file, color: mine ? p.mineText.withOpacity(0.7) : p.accent),
            const SizedBox(width: 6),
            Flexible(child: Text(m.text.isNotEmpty ? m.text : 'File', style: TextStyle(color: mine ? p.mineText : p.otherText))),
          ],
        );
      } else {
        content = Text(m.text, style: TextStyle(color: mine ? p.mineText : p.otherText));
      }
      if ((m.attachmentType == 'video' || m.attachmentType == 'file') &&
          !m.id.startsWith('local_') &&
          !isMediaExpired(type: m.attachmentType, url: m.attachmentUrl, createdAt: m.createdAt)) {
        content = withExpiryNote(content, p, mine, m.createdAt);
      }

      final isSelected = _selectedIds.contains(m.id);

      feed.add(Dismissible(
        key: Key(m.id),
        direction: _isSelectionMode ? DismissDirection.none : DismissDirection.horizontal,
        background: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 20),
          color: Colors.transparent,
          child: const Icon(Icons.reply, color: AppTheme.cyan),
        ),
        secondaryBackground: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          color: Colors.transparent,
          child: const Icon(Icons.reply, color: AppTheme.cyan),
        ),
        confirmDismiss: (direction) async {
          setState(() => _replyingTo = m);
          return false;
        },
        child: GestureDetector(
          onTapDown: (details) => _lastTapDownDetails = details,
          onTap: () {
            if (_isSelectionMode) {
              _toggleSelect(m.id);
            } else if (_lastTapDownDetails != null) {
              _showMessageOptions(m, _lastTapDownDetails!.globalPosition);
            }
          },
          onLongPress: () => _toggleSelect(m.id),
          child: Align(
            alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.cyan.withOpacity(0.18) : (mine ? p.mineBubble : p.otherBubble),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(mine ? 16 : 4),
                bottomRight: Radius.circular(mine ? 4 : 16),
              ),
              border: Border.all(color: isSelected ? AppTheme.cyan : (mine ? p.mineBorder : p.otherBorder), width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!mine && senderName.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(senderName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.pink)),
                  ),
                if (m.isForwarded && !isUnavailable)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.near_me_outlined, size: 12, color: AppTheme.textSecondary.withOpacity(0.7)),
                        const SizedBox(width: 4),
                        Text('Forwarded', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary.withOpacity(0.7), fontStyle: FontStyle.italic)),
                      ],
                    ),
                  ),
                if (m.replyToId.isNotEmpty && !isUnavailable) _buildReplyQuote(m),
                content,
                if (m.isEdited)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text('edited', style: TextStyle(fontSize: 10.5, color: AppTheme.textSecondary.withOpacity(0.7), fontStyle: FontStyle.italic)),
                  ),
                if (!isUnavailable)
                  ReactionBar(reactions: m.reactions, currentUserId: _myId, onTapReaction: (emoji) => _reactTo(m, emoji)),
                if (m.status == 'pending')
                  const Padding(
                    padding: EdgeInsets.only(top: 3),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Icon(Icons.schedule, size: 12, color: AppTheme.textSecondary),
                    ),
                  ),
              ],
            ),
          ),
        ),
      )));
      if (_ads.isNotEmpty && (i + 1) % 6 == 0) {
        feed.add(SponsoredAdCard(ad: _ads[(i ~/ 6) % _ads.length]));
      }
    }

    return Scaffold(
      backgroundColor: p.chatBg,
      appBar: _isSelectionMode
          ? AppBar(
              backgroundColor: p.panel,
              leading: IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _selectedIds.clear())),
              title: Text('${_selectedIds.length}'),
              actions: [IconButton(icon: const Icon(Icons.delete_outline), onPressed: _deleteSelected)],
            )
          : AppBar(
              title: Text(widget.groupName),
              actions: [
              ],
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.cyan))
          : Column(
              children: [
                if (_pinnedMessage != null)
                  Container(
                    width: double.infinity,
                    color: p.panel,
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
                            style: AppTheme.body(size: 12.5, color: p.inputText),
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
                      : ListView(
                          controller: _scrollController,
                          reverse: true, // WhatsApp/Telegram style: khulte hi bottom (naya message) pe
                          padding: const EdgeInsets.all(12),
                          children: [
                            // feed chronological (oldest-first) order me bana hai; reverse
                            // list me children[0] = bottom (naya), isliye poori list ulti
                            // karni padti hai.
                            ...feed.reversed,
                            if (_loadingOlder)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.cyan))),
                              ),
                          ],
                        ),
                ),
                if (_uploading) LinearProgressIndicator(minHeight: 2, color: AppTheme.cyan, backgroundColor: p.panel),
                if (_recording)
                  Container(
                    color: p.panel,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        const Icon(Icons.fiber_manual_record, color: Colors.red, size: 14),
                        const SizedBox(width: 8),
                        Text(
                          '${_recordDuration.inMinutes}:${(_recordDuration.inSeconds % 60).toString().padLeft(2, '0')}',
                          style: AppTheme.body(color: p.inputText),
                        ),
                        const Spacer(),
                        TextButton(onPressed: () => _stopRecording(send: false), child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondary))),
                        TextButton(onPressed: () => _stopRecording(send: true), child: const Text('Send', style: TextStyle(color: AppTheme.cyan))),
                      ],
                    ),
                  ),
                if (_editingMessage != null)
                  EditComposerBar(onCancel: () {
                    setState(() => _editingMessage = null);
                    _controller.clear();
                  })
                else if (_replyingTo != null)
                  ReplyComposerBar(
                    senderName: _nameOf(_replyingTo!.senderId),
                    snippet: messageSnippet(_replyingTo!),
                    onCancel: () => setState(() => _replyingTo = null),
                  ),
                SafeArea(
                  child: Container(
                    color: Colors.transparent,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: p.inputBar,
                              borderRadius: BorderRadius.circular(28),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            child: Row(
                              children: [
                                _attachIcon(Icons.camera_alt_outlined, () => _pickImage(ImageSource.camera)),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: TextField(
                                    controller: _controller,
                                    style: AppTheme.body(color: p.inputText),
                                    decoration: InputDecoration(
                                      hintText: 'Message',
                                      hintStyle: TextStyle(color: p.inputHint),
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(vertical: 10),
                                    ),
                                  ),
                                ),
                                _attachIcon(Icons.photo_library, _pickMultipleMedia),
                                _attachIcon(Icons.attach_file, _pickFile),
                                _attachIcon(Icons.mic, _startRecording, color: p.accent),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 46,
                          height: 46,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFE91E63),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.send, color: Colors.white, size: 20),
                            onPressed: _send,
                            padding: EdgeInsets.zero,
                          ),
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
