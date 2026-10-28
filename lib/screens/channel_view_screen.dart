import 'dart:async';
import 'dart:io';
import 'package:appwrite/appwrite.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:texter_video/texter_video.dart';
import 'package:url_launcher/url_launcher.dart';
import '../chat_bubble.dart';
import '../config/app_config.dart';
import '../config/theme.dart';
import '../models/models.dart';
import '../services/appwrite_service.dart';
import '../services/local_db_service.dart';
import '../services/net_utils.dart';
import '../widgets/media_compose_sheet.dart';
import '../widgets/media_expiry.dart';
import '../widgets/message_action_sheet.dart';
import '../widgets/reaction_bar.dart';
import '../widgets/reply_widgets.dart';
import '../widgets/texter_ui.dart';
import 'channel_info_screen.dart';
import 'forward_screen.dart';
import 'media_viewer_screen.dart';

/// A channel is a one-way feed: only admins post, everyone else reads and
/// reacts. Texter style: every post is a card with a cyan -> pink edge.
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
  MessageModel? _pinned;
  String? _myId;
  bool _loading = true;
  bool _busy = false;
  RealtimeSubscription? _sub;
  RealtimeSubscription? _channelSub;

  final Set<String> _selectedIds = {};
  bool get _isSelectionMode => _selectedIds.isNotEmpty;
  TapDownDetails? _lastTapDown;
  MessageModel? _editing;

  bool get _isSubscribed => _channel != null && _myId != null && _channel!.subscriberIds.contains(_myId);
  bool get _isAdmin => _channel?.isAdmin(_myId) ?? false;

  final _scrollController = ScrollController();
  bool _loadingOlder = false;
  bool _noMoreOlder = false;

  // uploading media posts
  bool _uploading = false;
  bool _cancelUpload = false;
  String _uploadLabel = '';
  String? _jobId;

  static const _videoExt = {'mp4', 'mov', 'mkv', 'webm', '3gp', 'avi', 'm4v'};

  @override
  void initState() {
    super.initState();
    _init();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _sub?.close();
    _channelSub?.close();
    _controller.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  MessageModel _toMsg(dynamic d) => MessageModel.fromMap(d.data..addAll({'\$id': d.$id, '\$createdAt': d.$createdAt}));

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 80 && !_loadingOlder && !_noMoreOlder) {
      _loadOlderPosts();
    }
  }

  Future<void> _loadOlderPosts() async {
    if (_posts.isEmpty || _loadingOlder) return;
    setState(() => _loadingOlder = true);
    try {
      final docs = await AppwriteService.instance.getMessages(widget.channelId, beforeMessageId: _posts.first.id);
      if (docs.isEmpty) {
        _noMoreOlder = true;
      } else {
        final older = docs.map(_toMsg).toList();
        if (mounted) setState(() => _posts.insertAll(0, older));
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingOlder = false);
    }
  }

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

  Future<void> _loadPinned(ChannelModel? c) async {
    final id = c?.pinnedMessageId ?? '';
    if (id.isEmpty) {
      if (mounted) setState(() => _pinned = null);
      return;
    }
    try {
      final doc = await AppwriteService.instance.getMessageById(id);
      if (mounted) setState(() => _pinned = doc == null ? null : _toMsg(doc));
    } catch (_) {}
  }

  Future<void> _refreshChannel() async {
    try {
      final doc = await AppwriteService.instance.getChannelDoc(widget.channelId);
      final c = ChannelModel.fromMap(doc.data..addAll({'\$id': doc.$id}));
      if (mounted) setState(() => _channel = c);
      _loadPinned(c);
    } catch (_) {}
  }

  Future<void> _init() async {
    final user = await AppwriteService.instance.getCurrentUser();
    _myId = user?.$id;
    final cached = await LocalDbService.instance.getCachedMessages(widget.channelId);
    if (cached.isNotEmpty && mounted) {
      setState(() {
        _posts = cached;
        _loading = false;
      });
    }

    ChannelModel? fetched;
    try {
      final doc = await AppwriteService.instance.getChannelDoc(widget.channelId);
      fetched = ChannelModel.fromMap(doc.data..addAll({'\$id': doc.$id}));
    } catch (_) {}

    List<MessageModel>? fresh;
    try {
      final docs = await AppwriteService.instance.getMessages(widget.channelId);
      fresh = docs.map(_toMsg).toList();
      await LocalDbService.instance.cacheMessages(widget.channelId, fresh);
    } catch (e) {
      if (mounted && !NetErr.isNetwork(e)) _snack('Failed to load channel: ${NetErr.friendly(e)}');
    }

    if (mounted) {
      setState(() {
        if (fetched != null) _channel = fetched;
        if (fresh != null) _posts = fresh;
        _loading = false;
      });
    }
    _loadPinned(fetched);

    _sub ??= AppwriteService.instance.subscribeToMessages(
      widget.channelId,
      (doc) {
        if (_posts.any((p) => p.id == doc.$id) || !mounted) return;
        final msg = _toMsg(doc);
        setState(() => _posts.add(msg));
        LocalDbService.instance.cacheMessage(widget.channelId, msg);
      },
      onUpdate: (doc) {
        if (!mounted) return;
        final updated = _toMsg(doc);
        setState(() {
          final i = _posts.indexWhere((p) => p.id == doc.$id);
          if (i >= 0) _posts[i] = updated;
          if (_pinned?.id == doc.$id) _pinned = updated;
        });
        LocalDbService.instance.cacheMessage(widget.channelId, updated);
      },
      onDelete: (id) {
        LocalDbService.instance.deleteCachedMessage(id);
        if (!mounted) return;
        setState(() {
          _posts.removeWhere((p) => p.id == id);
          _selectedIds.remove(id);
          if (_pinned?.id == id) _pinned = null;
        });
      },
    );

    // channel changes (new admin, new photo, pinned post, follower count ...)
    _channelSub ??= AppwriteService.instance.subscribeToCollection(AppwriteConfig.channelsCollection, (doc, events) {
      if (doc.$id != widget.channelId || !mounted) return;
      if (events.any((e) => e.contains('delete'))) {
        Navigator.maybePop(context);
        return;
      }
      final c = ChannelModel.fromMap(doc.data..addAll({'\$id': doc.$id}));
      setState(() => _channel = c);
      _loadPinned(c);
    });
  }

  // ---------------- follow / unfollow ----------------
  Future<void> _toggleSubscribe() async {
    if (_myId == null || _channel == null || _busy) return;
    setState(() => _busy = true);
    try {
      if (_isSubscribed) {
        await AppwriteService.instance.unsubscribeChannel(channelId: widget.channelId, userId: _myId!);
      } else {
        await AppwriteService.instance.subscribeChannel(channelId: widget.channelId, userId: _myId!);
      }
      await _refreshChannel();
    } catch (e) {
      _snack('Failed: ${NetErr.friendly(e)}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ---------------- posting (admins only) ----------------
  Future<void> _sendText() async {
    if (_editing != null) {
      await _saveEdit();
      return;
    }
    final text = _controller.text.trim();
    if (text.isEmpty || _myId == null || !_isAdmin) return;
    _controller.clear();
    try {
      await _publish(text: text);
    } catch (e) {
      _snack('Failed to post: ${NetErr.friendly(e)}');
    }
  }

  Future<void> _publish({String text = '', String url = '', String type = ''}) async {
    final doc = await AppwriteService.instance.sendMessage(
      chatId: widget.channelId,
      senderId: _myId!,
      text: text,
      attachmentUrl: url,
      attachmentType: type,
    );
    if (!_posts.any((p) => p.id == doc.$id)) {
      final msg = _toMsg(doc);
      if (mounted) setState(() => _posts.add(msg));
      LocalDbService.instance.cacheMessage(widget.channelId, msg);
    }
    _scrollToBottom();
    AppwriteService.instance.touchChannelLastPost(widget.channelId, AppwriteService.previewFor(type, text));
  }

  Future<void> _saveEdit() async {
    final text = _controller.text.trim();
    final editing = _editing;
    if (text.isEmpty || editing == null) return;
    _controller.clear();
    setState(() => _editing = null);
    try {
      final doc = await AppwriteService.instance.editMessage(
        messageId: editing.id,
        newText: text,
        chatId: widget.channelId,
        collectionId: AppwriteConfig.channelsCollection,
      );
      final updated = _toMsg(doc);
      LocalDbService.instance.cacheMessage(widget.channelId, updated);
      if (mounted) {
        setState(() {
          final i = _posts.indexWhere((p) => p.id == editing.id);
          if (i >= 0) _posts[i] = updated;
        });
      }
    } catch (e) {
      _snack('Failed to edit: ${friendlyError(e)}');
    }
  }

  bool _looksLikeVideo(String path) {
    final dot = path.lastIndexOf('.');
    return dot >= 0 && _videoExt.contains(path.substring(dot + 1).toLowerCase());
  }

  void _attachSheet() {
    final u = UiPalette.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: u.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _attachOption(ctx, Icons.photo_library_rounded, 'Photos & videos', const Color(0xFF7C4DFF), _pickGallery),
              _attachOption(ctx, Icons.photo_camera_rounded, 'Camera', AppTheme.pink, _pickCamera),
              _attachOption(ctx, Icons.insert_drive_file_rounded, 'File', const Color(0xFFFFA726), _pickFile),
            ],
          ),
        ),
      ),
    );
  }

  Widget _attachOption(BuildContext ctx, IconData icon, String label, Color color, VoidCallback onTap) {
    final u = UiPalette.of(context);
    return GestureDetector(
      onTap: () {
        Navigator.pop(ctx);
        onTap();
      },
      child: SizedBox(
        width: 96,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 8),
            Text(label, textAlign: TextAlign.center, style: AppTheme.body(size: 12.5, color: u.text)),
          ],
        ),
      ),
    );
  }

  Future<void> _pickGallery() async {
    final picker = ImagePicker();
    final picked = await ChatBubble.guard(
      () => picker.pickMultipleMedia(limit: kMaxMediaFiles, maxWidth: kImageMaxSide, maxHeight: kImageMaxSide, imageQuality: kImageQuality),
    );
    if (picked.isEmpty || !mounted) return;
    final files = picked.map((x) => PickedMedia(File(x.path), _looksLikeVideo(x.path))).toList();
    final result = await showMediaComposeSheet(context, files);
    if (result == null) return;
    await _uploadPosts(result);
  }

  Future<void> _pickCamera() async {
    final picker = ImagePicker();
    final x = await ChatBubble.guard(
      () => picker.pickImage(source: ImageSource.camera, maxWidth: kImageMaxSide, maxHeight: kImageMaxSide, imageQuality: kImageQuality),
    );
    if (x == null || !mounted) return;
    final result = await showMediaComposeSheet(context, [PickedMedia(File(x.path), false)]);
    if (result == null) return;
    await _uploadPosts(result);
  }

  Future<void> _pickFile() async {
    final res = await ChatBubble.guard(() => FilePicker.platform.pickFiles(withData: false));
    if (res == null || res.files.single.path == null || !mounted) return;
    final f = res.files.single;
    if (await File(f.path!).length() > kMaxFileBytes) {
      _snack('File is too big (max 50 MB).');
      return;
    }
    final caption = await showFileCaptionDialog(context, f.name);
    if (caption == null) return;
    setState(() {
      _uploading = true;
      _cancelUpload = false;
      _uploadLabel = 'Sending file…';
    });
    try {
      final url = await AppwriteService.instance.uploadFile(f.path!, f.name);
      if (!_cancelUpload) {
        await _publish(text: caption.isEmpty ? f.name : '${f.name}\n$caption', url: url, type: 'file');
      }
    } catch (e) {
      _snack('Failed to send: ${NetErr.friendly(e)}');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  /// Uploads the chosen photos / videos one after another as separate posts.
  Future<void> _uploadPosts(MediaComposeResult r) async {
    if (_myId == null || !_isAdmin) return;
    setState(() {
      _uploading = true;
      _cancelUpload = false;
    });
    try {
      final n = r.files.length;
      for (var i = 0; i < n; i++) {
        if (_cancelUpload) break;
        final f = r.files[i];
        var path = f.file.path;
        var name = path.split('/').last;
        final type = f.isVideo ? 'video' : 'image';
        String? temp;
        if (f.isVideo) {
          if (mounted) setState(() => _uploadLabel = 'Compressing video ${i + 1} of $n…');
          _jobId = 'chv_${DateTime.now().microsecondsSinceEpoch}';
          final small = await TexterVideo.compress(path, jobId: _jobId!);
          if (_cancelUpload) break;
          if (small != null) {
            temp = small;
            path = small;
            final dot = name.lastIndexOf('.');
            name = '${dot > 0 ? name.substring(0, dot) : name}.mp4';
          } else if (await File(path).length() > kMaxUncompressedVideoBytes) {
            _snack('Could not compress a video and it is too large (over 50 MB). Skipped.');
            continue;
          }
        }
        if (mounted) setState(() => _uploadLabel = 'Sending ${i + 1} of $n…');
        try {
          final url = await AppwriteService.instance.uploadFile(path, name);
          if (_cancelUpload) break;
          await _publish(text: i == 0 ? r.caption : '', url: url, type: type);
        } finally {
          if (temp != null) {
            try {
              File(temp).delete();
            } catch (_) {}
          }
        }
      }
    } catch (e) {
      _snack('Failed to send: ${NetErr.friendly(e)}');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _cancelUploading() {
    setState(() => _cancelUpload = true);
    if (_jobId != null) TexterVideo.cancel(_jobId!);
  }

  // ---------------- select / delete / react / pin ----------------
  void _toggleSelect(String id) {
    setState(() => _selectedIds.contains(id) ? _selectedIds.remove(id) : _selectedIds.add(id));
  }

  Future<void> _deleteSingle(String id) async {
    if (!await confirmDeleteMessages(context, 1)) return;
    try {
      await AppwriteService.instance.deleteMessage(id, chatId: widget.channelId, collectionId: AppwriteConfig.channelsCollection);
      LocalDbService.instance.deleteCachedMessage(id);
      if (mounted) setState(() => _posts.removeWhere((p) => p.id == id));
    } catch (e) {
      _snack('Failed to delete: ${NetErr.friendly(e)}');
    }
  }

  Future<void> _deleteSelected() async {
    final ids = List<String>.from(_selectedIds);
    if (ids.isEmpty || !await confirmDeleteMessages(context, ids.length)) return;
    setState(() => _selectedIds.clear());
    for (final id in ids) {
      try {
        await AppwriteService.instance.deleteMessage(id, chatId: widget.channelId, collectionId: AppwriteConfig.channelsCollection);
        LocalDbService.instance.deleteCachedMessage(id);
        if (mounted) setState(() => _posts.removeWhere((p) => p.id == id));
      } catch (_) {}
    }
  }

  Future<void> _reactTo(MessageModel m, String emoji) async {
    if (_myId == null) return;
    try {
      final doc = await AppwriteService.instance.toggleReaction(messageId: m.id, userId: _myId!, emoji: emoji);
      final updated = _toMsg(doc);
      LocalDbService.instance.cacheMessage(widget.channelId, updated);
      if (!mounted) return;
      setState(() {
        final i = _posts.indexWhere((p) => p.id == m.id);
        if (i >= 0) _posts[i] = updated;
      });
    } catch (e) {
      _snack(NetErr.friendly(e));
    }
  }

  Future<void> _pin(MessageModel m) async {
    try {
      await AppwriteService.instance.pinChannelPost(widget.channelId, m.id);
      setState(() => _pinned = m);
      _snack('Post pinned');
    } catch (e) {
      _snack(friendlyError(e));
    }
  }

  Future<void> _unpin() async {
    try {
      await AppwriteService.instance.updateChannel(widget.channelId, {'pinnedMessageId': ''});
      setState(() => _pinned = null);
    } catch (e) {
      _snack(friendlyError(e));
    }
  }

  void _openActionsFor(MessageModel m, Offset tapPosition) {
    showMessageActionSheet(
      context,
      tapPosition: tapPosition,
      canDelete: _isAdmin,
      messageText: m.text,
      onReact: (emoji) => _reactTo(m, emoji),
      onMoreEmojis: () async {
        final emoji = await showFullEmojiPicker(context);
        if (emoji != null) _reactTo(m, emoji);
      },
      onSelect: () => _toggleSelect(m.id),
      onDelete: _isAdmin ? () => _deleteSingle(m.id) : null,
      onEdit: (_isAdmin && m.attachmentType.isEmpty) ? () => _startEdit(m) : null,
      onPin: _isAdmin ? () => _pin(m) : null,
      onForward: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ForwardScreen(
            payload: ForwardPayload(text: m.text, attachmentUrl: m.attachmentUrl, attachmentType: m.attachmentType),
          ),
        ),
      ),
    );
  }

  void _startEdit(MessageModel m) {
    setState(() {
      _editing = m;
      _controller.text = m.text;
      _controller.selection = TextSelection.collapsed(offset: m.text.length);
    });
  }

  void _openViewer(MessageModel m) {
    final list = _posts
        .where((x) =>
            (x.attachmentType == 'image' || x.attachmentType == 'video') &&
            x.attachmentUrl.isNotEmpty &&
            !isMediaExpired(type: x.attachmentType, url: x.attachmentUrl, createdAt: x.createdAt))
        .toList();
    final idx = list.indexWhere((x) => x.id == m.id);
    if (idx < 0) return;
    final items = list
        .map((x) => MediaViewerItem(
              url: x.attachmentUrl,
              isVideo: x.attachmentType == 'video',
              caption: x.text,
              title: _channel?.name ?? 'Channel',
              time: x.createdAt,
            ))
        .toList();
    Navigator.push(context, MaterialPageRoute(builder: (_) => MediaViewerScreen(items: items, initialIndex: idx)));
  }

  Future<void> _openInfo() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => ChannelInfoScreen(channelId: widget.channelId)));
    _refreshChannel();
  }

  // ---------------- UI ----------------
  Widget _dayChip(DateTime t, UiPalette u) {
    final now = DateTime.now();
    final l = t.toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(DateTime(l.year, l.month, l.day)).inDays;
    final label = diff == 0 ? 'Today' : (diff == 1 ? 'Yesterday' : DateFormat('d MMMM yyyy').format(l));
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 14, bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(color: u.cardAlt, borderRadius: BorderRadius.circular(12)),
        child: Text(label, style: AppTheme.body(size: 11.5, weight: FontWeight.w600, color: u.subtext)),
      ),
    );
  }

  Widget _postCard(MessageModel m, UiPalette u, ChatPalette p) {
    final selected = _selectedIds.contains(m.id);
    final pinned = _channel?.pinnedMessageId == m.id;
    final expired = isMediaExpired(type: m.attachmentType, url: m.attachmentUrl, createdAt: m.createdAt);
    final name = _channel?.name ?? 'Channel';

    Widget? media;
    var caption = m.text;
    if (expired) {
      media = expiredMediaView(p, false);
      caption = '';
    } else if (m.attachmentType == 'image' && m.attachmentUrl.isNotEmpty) {
      media = GestureDetector(
        onTap: () => _openViewer(m),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            height: 220,
            width: double.infinity,
            child: CachedNetworkImage(
              imageUrl: m.attachmentUrl,
              fit: BoxFit.cover,
              memCacheWidth: 800,
              placeholder: (_, __) => Container(color: u.cardAlt),
              errorWidget: (_, __, ___) => Container(color: u.cardAlt, child: Icon(Icons.broken_image, color: u.subtext)),
            ),
          ),
        ),
      );
    } else if (m.attachmentType == 'video' && m.attachmentUrl.isNotEmpty) {
      media = GestureDetector(
        onTap: () => _openViewer(m),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: 190,
            width: double.infinity,
            color: const Color(0xFF263238),
            child: const Center(
              child: CircleAvatar(radius: 28, backgroundColor: Colors.black54, child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 38)),
            ),
          ),
        ),
      );
    } else if (m.attachmentType == 'file' && m.attachmentUrl.isNotEmpty) {
      final lines = m.text.split('\n');
      final fileName = lines.first;
      caption = lines.length > 1 ? lines.sublist(1).join('\n') : '';
      media = GestureDetector(
        onTap: () => launchUrl(Uri.parse(m.attachmentUrl), mode: LaunchMode.externalApplication),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: u.cardAlt, borderRadius: BorderRadius.circular(14)),
          child: Row(
            children: [
              const IconBadge(Icons.insert_drive_file_rounded, color: Color(0xFFFFA726)),
              const SizedBox(width: 12),
              Expanded(child: Text(fileName, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTheme.body(size: 14, weight: FontWeight.w600, color: u.text))),
              Icon(Icons.download_rounded, color: u.subtext),
            ],
          ),
        ),
      );
    } else if (m.attachmentType == 'voice' && m.attachmentUrl.isNotEmpty) {
      media = Row(children: [
        const IconBadge(Icons.mic_rounded),
        const SizedBox(width: 10),
        Text('Voice message', style: AppTheme.body(color: u.text)),
      ]);
    }
    if (media != null && !expired && (m.attachmentType == 'video' || m.attachmentType == 'file')) {
      media = withExpiryNote(media, p, false, m.createdAt);
    }

    return GestureDetector(
      onTapDown: (d) => _lastTapDown = d,
      onTap: () => _isSelectionMode ? _toggleSelect(m.id) : _openActionsFor(m, _lastTapDown?.globalPosition ?? Offset.zero),
      onLongPress: _isAdmin ? () => _toggleSelect(m.id) : null,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: u.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppTheme.cyan : u.border, width: selected ? 1.8 : 1),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(19),
          child: Stack(
            children: [
              const Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 4,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: kTexterGradient),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 14, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        TexterAvatar(name: name, url: _channel?.avatarUrl ?? '', size: 24),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.body(size: 13, weight: FontWeight.w700, color: u.accent)),
                        ),
                        if (pinned) Padding(padding: const EdgeInsets.only(right: 6), child: Icon(Icons.push_pin_rounded, size: 14, color: u.subtext)),
                        Text(shortTime(m.createdAt), style: AppTheme.body(size: 11.5, color: u.subtext)),
                      ],
                    ),
                    if (media != null) ...[const SizedBox(height: 10), media],
                    if (caption.trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(caption, style: AppTheme.body(size: 15, color: u.text)),
                    ],
                    if (m.reactions.isNotEmpty || m.isEdited) ...[
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: ReactionBar(reactions: m.reactions, currentUserId: _myId, onTapReaction: (e) => _reactTo(m, e)),
                          ),
                          if (m.isEdited) Text('edited', style: AppTheme.body(size: 11, color: u.subtext)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _adminComposer(UiPalette u, ChatPalette p) {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_uploading)
            Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
              padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
              decoration: BoxDecoration(color: u.cardAlt, borderRadius: BorderRadius.circular(16)),
              child: Row(
                children: [
                  SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: u.accent)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_uploadLabel.isEmpty ? 'Sending…' : _uploadLabel, style: AppTheme.body(size: 13, color: u.text))),
                  TextButton(onPressed: _cancelUploading, child: Text('Cancel', style: TextStyle(color: u.accent))),
                ],
              ),
            ),
          if (_editing != null)
            EditComposerBar(onCancel: () {
              setState(() => _editing = null);
              _controller.clear();
            }),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (_editing == null)
                  GestureDetector(
                    onTap: _uploading ? null : _attachSheet,
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: u.card, border: Border.all(color: u.border)),
                      child: Icon(Icons.add_rounded, color: u.accent, size: 26),
                    ),
                  ),
                if (_editing == null) const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(color: p.inputBar, borderRadius: BorderRadius.circular(24), border: Border.all(color: u.border)),
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                      style: AppTheme.body(color: p.inputText),
                      decoration: InputDecoration(
                        hintText: 'Broadcast to ${_channel?.subscriberCount ?? 0} followers…',
                        hintStyle: TextStyle(color: p.inputHint),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _sendText,
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: kTexterGradient)),
                    child: Icon(_editing != null ? Icons.check_rounded : Icons.campaign_rounded, color: Colors.white, size: 22),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _readOnlyBar(UiPalette u) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 6, 14, 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(color: u.cardAlt, borderRadius: BorderRadius.circular(30), border: Border.all(color: u.border)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.campaign_rounded, size: 18, color: u.accent),
            const SizedBox(width: 8),
            Text('Only admins can post in this channel', style: AppTheme.body(size: 13, color: u.subtext)),
          ],
        ),
      ),
    );
  }

  Widget _followBar() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
        child: Center(
          child: GradientButton(label: 'Follow channel', icon: Icons.notifications_active_rounded, busy: _busy, onTap: _toggleSubscribe, height: 50),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final u = UiPalette.of(context);
    final p = ChatPalette.of(context);
    final c = _channel;
    return Scaffold(
      appBar: _isSelectionMode
          ? AppBar(
              leading: IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _selectedIds.clear())),
              title: Text('${_selectedIds.length} selected'),
              actions: [IconButton(icon: const Icon(Icons.delete_outline), onPressed: _deleteSelected)],
            )
          : AppBar(
              titleSpacing: 0,
              title: InkWell(
                onTap: _openInfo,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      TexterAvatar(name: c?.name ?? 'C', url: c?.avatarUrl ?? '', size: 40, ring: true),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(c?.name ?? 'Channel', maxLines: 1, overflow: TextOverflow.ellipsis),
                            Text(
                              '${c?.subscriberCount ?? 0} followers${_isAdmin ? ' · You are admin' : ''}',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: u.subtext),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'info') _openInfo();
                    if (v == 'unfollow') _toggleSubscribe();
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'info', child: Text('Channel info')),
                    if (_isSubscribed && !(c?.isOwner(_myId) ?? false)) const PopupMenuItem(value: 'unfollow', child: Text('Unfollow')),
                  ],
                ),
              ],
            ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: u.accent))
          : Column(
              children: [
                if (_pinned != null)
                  Container(
                    margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                    decoration: BoxDecoration(color: u.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: u.border)),
                    child: Row(
                      children: [
                        Icon(Icons.push_pin_rounded, size: 16, color: u.accent),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _pinned!.text.isNotEmpty ? _pinned!.text.split('\n').first : AppwriteService.previewFor(_pinned!.attachmentType, ''),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.body(size: 13, color: u.text),
                          ),
                        ),
                        if (_isAdmin) IconButton(visualDensity: VisualDensity.compact, icon: Icon(Icons.close, size: 18, color: u.subtext), onPressed: _unpin),
                      ],
                    ),
                  ),
                Expanded(
                  child: _posts.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.campaign_outlined, size: 56, color: u.subtext),
                              const SizedBox(height: 10),
                              Text('No posts yet', style: AppTheme.body(size: 15, color: u.subtext)),
                              if (_isAdmin) Text('Write the first broadcast below', style: AppTheme.body(size: 12.5, color: u.subtext)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          reverse: true,
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                          itemCount: _posts.length + (_loadingOlder ? 1 : 0),
                          itemBuilder: (context, i) {
                            if (i >= _posts.length) {
                              return const Padding(
                                padding: EdgeInsets.all(12),
                                child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                              );
                            }
                            final idx = _posts.length - 1 - i;
                            final m = _posts[idx];
                            final newDay = idx == 0 ||
                                DateUtils.dateOnly(_posts[idx - 1].createdAt.toLocal()) != DateUtils.dateOnly(m.createdAt.toLocal());
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (newDay) _dayChip(m.createdAt, u),
                                _postCard(m, u, p),
                              ],
                            );
                          },
                        ),
                ),
                if (_isAdmin)
                  _adminComposer(u, p)
                else if (_isSubscribed)
                  _readOnlyBar(u)
                else
                  _followBar(),
              ],
            ),
    );
  }
}
