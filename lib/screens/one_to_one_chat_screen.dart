import 'dart:async';
import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/theme.dart';
import '../services/appwrite_service.dart';
import '../services/local_db_service.dart';
import '../models/models.dart';
import '../widgets/message_action_sheet.dart';
import '../widgets/reaction_bar.dart';
import '../widgets/reply_widgets.dart';
import '../services/net_utils.dart';

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

  String? _otherUserId;
  bool _otherOnline = false;
  bool _otherTyping = false;
  RealtimeSubscription? _userSub;
  RealtimeSubscription? _typingSub;
  Timer? _typingDebounce;

  // Selection mode (long-press a message -> Select -> multi-pick -> delete)
  final Set<String> _selectedIds = {};
  bool get _isSelectionMode => _selectedIds.isNotEmpty;

  // Reply state (message currently being replied to)
  MessageModel? _replyingTo;

  // Offline outbox: messages typed while offline are sent automatically later
  Timer? _outboxTimer;
  bool _flushing = false;

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

    if (_myId != null) {
      AppwriteService.instance.markChatRead(chatId: widget.chatId, userId: _myId!);
    }

    final cached = await LocalDbService.instance.getCachedMessages(widget.chatId);
    final pending = await _pendingFromOutbox();
    if ((cached.isNotEmpty || pending.isNotEmpty) && mounted) {
      setState(() => _messages = [...cached, ...pending]);
    }

    try {
      final docs = await AppwriteService.instance.getMessages(widget.chatId);
      final fresh = docs.map((d) => MessageModel.fromMap(d.data..addAll({'\$id': d.$id, '\$createdAt': d.$createdAt}))).toList();
      await LocalDbService.instance.cacheMessages(widget.chatId, fresh);
      final stillPending = await _pendingFromOutbox();
      if (mounted) setState(() => _messages = [...fresh, ...stillPending]);
    } catch (_) {
      // Offline (or server error): keep showing the cached messages silently.
    }

    _outboxTimer ??= Timer.periodic(const Duration(seconds: 6), (_) => _flushOutbox());
    _flushOutbox();

    _sub = AppwriteService.instance.subscribeToMessages(
      widget.chatId,
      (doc) {
        if (_messages.any((m) => m.id == doc.$id)) return;
        if (!mounted) return;
        setState(() {
          final msg = MessageModel.fromMap(doc.data..addAll({'\$id': doc.$id, '\$createdAt': doc.$createdAt}));
          _messages.add(msg);
          LocalDbService.instance.cacheMessage(widget.chatId, msg);
        });
      },
      onUpdate: (doc) {
        if (!mounted) return;
        final updated = MessageModel.fromMap(doc.data..addAll({'\$id': doc.$id, '\$createdAt': doc.$createdAt}));
        setState(() {
          final i = _messages.indexWhere((m) => m.id == doc.$id);
          if (i >= 0) _messages[i] = updated;
        });
        LocalDbService.instance.cacheMessage(widget.chatId, updated);
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

    _resolveOtherUser();
  }

  Future<void> _resolveOtherUser() async {
    try {
      final chatDoc = await AppwriteService.instance.databases.getDocument(
        databaseId: 'messgram_db',
        collectionId: 'chats',
        documentId: widget.chatId,
      );
      final ids = (chatDoc.data['participantIds'] as String? ?? '').split(',').where((e) => e.isNotEmpty).toList();
      _otherUserId = ids.firstWhere((id) => id != _myId, orElse: () => '');
      if (_otherUserId != null && _otherUserId!.isNotEmpty) {
        final userDoc = await AppwriteService.instance.getUserDoc(_otherUserId!);
        if (mounted) setState(() => _otherOnline = userDoc?.data['online'] ?? false);

        _userSub = AppwriteService.instance.subscribeToCollection('users', (doc, events) {
          if (doc.$id != _otherUserId) return;
          if (!mounted) return;
          setState(() => _otherOnline = doc.data['online'] ?? false);
        });
      }

      _typingSub = AppwriteService.instance.subscribeToCollection('chats', (doc, events) {
        if (doc.$id != widget.chatId) return;
        final typingUsers = (doc.data['typingUsers'] as String? ?? '').split(',').where((e) => e.isNotEmpty).toList();
        final isTyping = _otherUserId != null && typingUsers.contains(_otherUserId);
        if (!mounted) return;
        setState(() => _otherTyping = isTyping);
      });
    } catch (_) {}
  }

  void _onTextChanged(String value) {
    if (_myId == null) return;
    AppwriteService.instance.setTyping(chatId: widget.chatId, userId: _myId!, isTyping: value.isNotEmpty);
    _typingDebounce?.cancel();
    _typingDebounce = Timer(const Duration(seconds: 3), () {
      AppwriteService.instance.setTyping(chatId: widget.chatId, userId: _myId!, isTyping: false);
    });
  }

  @override
  void dispose() {
    _sub?.close();
    _userSub?.close();
    _typingSub?.close();
    _typingDebounce?.cancel();
    _outboxTimer?.cancel();
    if (_myId != null) {
      AppwriteService.instance.setTyping(chatId: widget.chatId, userId: _myId!, isTyping: false);
    }
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<List<MessageModel>> _pendingFromOutbox() async {
    final rows = await LocalDbService.instance.getOutbox(widget.chatId);
    return rows
        .map((r) => MessageModel(
              id: r['localId'] as String,
              chatId: widget.chatId,
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
      final rows = await LocalDbService.instance.getOutbox(widget.chatId);
      for (final r in rows) {
        final localId = r['localId'] as String;
        try {
          final doc = await AppwriteService.instance.sendMessage(
            chatId: widget.chatId,
            senderId: r['senderId'] as String,
            text: (r['message'] as String?) ?? '',
            replyToId: (r['replyToId'] as String?) ?? '',
          );
          await LocalDbService.instance.removeOutbox(localId);
          final real = MessageModel.fromMap(doc.data..addAll({'\$id': doc.$id, '\$createdAt': doc.$createdAt}));
          LocalDbService.instance.cacheMessage(widget.chatId, real);
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

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _myId == null) return;
    _controller.clear();
    final replyId = _replyingTo?.id ?? '';
    final localId = 'local_${DateTime.now().microsecondsSinceEpoch}';
    final pending = MessageModel(
      id: localId,
      chatId: widget.chatId,
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
    }
    try {
      final doc = await AppwriteService.instance.sendMessage(chatId: widget.chatId, senderId: _myId!, text: text, replyToId: replyId);
      final real = MessageModel.fromMap(doc.data..addAll({'\$id': doc.$id, '\$createdAt': doc.$createdAt}));
      LocalDbService.instance.cacheMessage(widget.chatId, real);
      if (mounted) {
        setState(() {
          _messages.removeWhere((m) => m.id == localId);
          if (!_messages.any((m) => m.id == real.id)) _messages.add(real);
        });
      }
      _typingDebounce?.cancel();
      AppwriteService.instance.setTyping(chatId: widget.chatId, userId: _myId!, isTyping: false);
    } catch (e) {
      if (NetErr.isNetwork(e)) {
        // Offline: keep it as a pending message, it will be sent automatically.
        await LocalDbService.instance.enqueueOutbox(
          localId: localId,
          chatId: widget.chatId,
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
        replyToId: _replyingTo?.id ?? '',
      );
      if (mounted) setState(() => _replyingTo = null);
      if (!_messages.any((m) => m.id == doc.$id)) {
        final msg = MessageModel.fromMap(doc.data..addAll({'\$id': doc.$id, '\$createdAt': doc.$createdAt}));
        if (mounted) {
          setState(() => _messages.add(msg));
        }
        LocalDbService.instance.cacheMessage(widget.chatId, msg);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to upload: ${NetErr.friendly(e)}')));
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
      if (mounted) setState(() => _playingId = null);
    } else {
      await _player.play(UrlSource(m.attachmentUrl));
      if (mounted) setState(() => _playingId = m.id);
    }
  }

  Future<void> _openFile(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open file')));
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
      await AppwriteService.instance.deleteMessage(id);
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
        await AppwriteService.instance.deleteMessage(id);
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
      LocalDbService.instance.cacheMessage(widget.chatId, updated);
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

  void _openActionsFor(MessageModel m) {
    if (m.id.startsWith('local_')) return; // still sending / waiting for internet
    final canDelete = m.senderId == _myId;
    showMessageActionSheet(
      context,
      canDelete: canDelete,
      onReact: (emoji) => _reactTo(m, emoji),
      onMoreEmojis: () async {
        final emoji = await showFullEmojiPicker(context);
        if (emoji != null) _reactTo(m, emoji);
      },
      onSelect: () => _toggleSelect(m.id),
      onDelete: canDelete ? () => _deleteSingle(m.id) : null,
      onReply: () => setState(() => _replyingTo = m),
    );
  }

  Widget _buildReplyQuote(MessageModel m) {
    MessageModel? original;
    for (final x in _messages) {
      if (x.id == m.replyToId) {
        original = x;
        break;
      }
    }
    final name = original == null ? '' : (original.senderId == _myId ? 'You' : widget.chatName);
    return ReplyQuote(senderName: name, original: original);
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
    return Scaffold(
      appBar: _isSelectionMode
          ? AppBar(
              backgroundColor: AppTheme.surface,
              leading: IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _selectedIds.clear())),
              title: Text('${_selectedIds.length}'),
              actions: [IconButton(icon: const Icon(Icons.delete_outline), onPressed: _deleteSelected)],
            )
          : AppBar(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(widget.chatName),
                  Text(
                    _otherTyping ? 'typing...' : (_otherOnline ? 'online' : 'offline'),
                    style: TextStyle(
                      fontSize: 12,
                      color: _otherTyping ? AppTheme.cyan : (_otherOnline ? Colors.greenAccent : AppTheme.textSecondary),
                      fontWeight: _otherTyping ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
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
                    child: CachedNetworkImage(
                      imageUrl: m.attachmentUrl,
                      width: 200,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        height: 150,
                        color: AppTheme.surfaceLight,
                        child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.cyan)),
                      ),
                      errorWidget: (context, url, error) => Container(
                        padding: const EdgeInsets.all(12),
                        color: AppTheme.surfaceLight,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.broken_image, color: AppTheme.textSecondary),
                            SizedBox(width: 8),
                            Text('Image not found', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  );
                } else if (m.attachmentType == 'voice' && m.attachmentUrl.isNotEmpty) {
                  content = Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(_playingId == m.id ? Icons.pause_circle : Icons.play_circle, color: mine ? Colors.white : AppTheme.cyan, size: 30),
                        onPressed: () => _togglePlay(m),
                        padding: EdgeInsets.zero,
                      ),
                      Text(m.text.isNotEmpty ? m.text : 'Voice', style: const TextStyle(color: Colors.white)),
                    ],
                  );
                } else if (m.attachmentType == 'file' && m.attachmentUrl.isNotEmpty) {
                  content = InkWell(
                    onTap: () => _openFile(m.attachmentUrl),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.insert_drive_file, color: mine ? Colors.white70 : AppTheme.cyan),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            m.text.isNotEmpty ? m.text : 'File',
                            style: const TextStyle(color: Colors.white, decoration: TextDecoration.underline),
                          ),
                        ),
                      ],
                    ),
                  );
                } else {
                  content = Text(m.text, style: const TextStyle(color: Colors.white));
                }
                final isSelected = _selectedIds.contains(m.id);
                return GestureDetector(
                  onTap: _isSelectionMode ? () => _toggleSelect(m.id) : null,
                  onLongPress: _isSelectionMode ? () => _toggleSelect(m.id) : () => _openActionsFor(m),
                  child: AnimatedAlign(
                    duration: const Duration(milliseconds: 200),
                    alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.cyan.withOpacity(0.18) : (mine ? const Color(0xFF1E222B) : AppTheme.surface),
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(16),
                          topRight: const Radius.circular(16),
                          bottomLeft: Radius.circular(mine ? 16 : 4),
                          bottomRight: Radius.circular(mine ? 4 : 16),
                        ),
                        border: Border.all(color: isSelected ? AppTheme.cyan : const Color(0xFF2A2E39), width: 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (m.replyToId.isNotEmpty) _buildReplyQuote(m),
                          content,
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
                  const Icon(Icons.fiber_manual_record, color: Colors.red, size: 14),
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
          if (_replyingTo != null)
            ReplyComposerBar(
              senderName: _replyingTo!.senderId == _myId ? 'yourself' : widget.chatName,
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
                        color: const Color(0xFF1E222B),
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
                              onChanged: _onTextChanged,
                              style: AppTheme.body(color: Colors.white),
                              decoration: const InputDecoration(
                                hintText: 'Message',
                                hintStyle: TextStyle(color: Colors.grey),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(vertical: 10),
                              ),
                            ),
                          ),
                          _attachIcon(Icons.camera_alt, () => _pickImage(ImageSource.gallery)),
                          _attachIcon(Icons.attach_file, _pickFile),
                          _attachIcon(Icons.mic, _startRecording, color: const Color(0xFF00E5FF)),
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
