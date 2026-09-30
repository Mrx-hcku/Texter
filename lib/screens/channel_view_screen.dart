import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import '../config/theme.dart';
import '../services/appwrite_service.dart';
import '../services/local_db_service.dart';
import '../models/models.dart';
import '../widgets/message_action_sheet.dart';
import '../widgets/reaction_bar.dart';
import '../services/net_utils.dart';

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

  // Selection mode (long-press a post -> Select -> multi-pick -> delete)
  final Set<String> _selectedIds = {};
  bool get _isSelectionMode => _selectedIds.isNotEmpty;

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
    final cached = await LocalDbService.instance.getCachedMessages(widget.channelId);
    if (cached.isNotEmpty && mounted) {
      setState(() {
        _posts = cached;
        _loading = false;
      });
    }

    // Channel info (cached copy is used when offline)
    ChannelModel? fetchedChannel;
    try {
      final doc = await AppwriteService.instance.getChannelDoc(widget.channelId);
      fetchedChannel = ChannelModel.fromMap(doc.data..addAll({'\$id': doc.$id}));
    } catch (_) {}

    // Fresh posts (silently skipped when offline - cached posts stay visible)
    List<MessageModel>? freshPosts;
    try {
      final posts = await AppwriteService.instance.getMessages(widget.channelId);
      freshPosts = posts
          .map((d) => MessageModel.fromMap(d.data..addAll({'\$id': d.$id, '\$createdAt': d.$createdAt})))
          .toList();
      await LocalDbService.instance.cacheMessages(widget.channelId, freshPosts);
    } catch (e) {
      if (mounted && !NetErr.isNetwork(e)) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load channel: ${NetErr.friendly(e)}')));
      }
    }

    if (mounted) {
      setState(() {
        if (fetchedChannel != null) {
          // Agar local user ne abhi-abhi subscribe/unsubscribe kiya hai toh server ke purane data se race condition na ho,
          // iske liye agar local state already set thi toh use prioritize karenge jab tak fresh data proper na aaye.
          if (_channel != null && _myId != null) {
            final localSubscribed = _channel!.subscriberIds.contains(_myId);
            final serverSubscribed = fetchedChannel.subscriberIds.contains(_myId);
            if (localSubscribed != serverSubscribed) {
              // Keep local subscriberIds array override if sync is pending
              _channel = ChannelModel(
                id: fetchedChannel.id,
                name: fetchedChannel.name,
                description: fetchedChannel.description,
                creatorId: fetchedChannel.creatorId,
                subscriberIds: fetchedChannel.subscriberIds,
              );
            } else {
              _channel = fetchedChannel;
            }
          } else {
            _channel = fetchedChannel;
          }
        }
        if (freshPosts != null) _posts = freshPosts;
        _loading = false;
      });
    }

    _sub ??= AppwriteService.instance.subscribeToMessages(
      widget.channelId,
      (doc) {
        if (_posts.any((p) => p.id == doc.$id)) return;
        if (!mounted) return;
        final msg = MessageModel.fromMap(doc.data..addAll({'\$id': doc.$id, '\$createdAt': doc.$createdAt}));
        setState(() => _posts.add(msg));
        LocalDbService.instance.cacheMessage(widget.channelId, msg);
      },
      onUpdate: (doc) {
        if (!mounted) return;
        final updated = MessageModel.fromMap(doc.data..addAll({'\$id': doc.$id, '\$createdAt': doc.$createdAt}));
        setState(() {
          final i = _posts.indexWhere((p) => p.id == doc.$id);
          if (i >= 0) _posts[i] = updated;
        });
        LocalDbService.instance.cacheMessage(widget.channelId, updated);
      },
      onDelete: (id) {
        LocalDbService.instance.deleteCachedMessage(id);
        if (!mounted) return;
        setState(() {
          _posts.removeWhere((p) => p.id == id);
          _selectedIds.remove(id);
        });
      },
    );
  }

  Future<void> _toggleSubscribe() async {
    if (_myId == null || _channel == null || _busy) return;
    setState(() => _busy = true);

    final currentlySubscribed = _isSubscribed;
    final updatedSubscriberIds = List<String>.from(_channel!.subscriberIds);
    if (currentlySubscribed) {
      updatedSubscriberIds.remove(_myId);
    } else {
      updatedSubscriberIds.add(_myId!);
    }
    
    // Turant UI update (Optimistic Update)
    setState(() {
      _channel = ChannelModel(
        id: _channel!.id,
        name: _channel!.name,
        description: _channel!.description,
        creatorId: _channel!.creatorId,
        subscriberIds: updatedSubscriberIds,
      );
    });

    try {
      if (currentlySubscribed) {
        await AppwriteService.instance.unsubscribeChannel(channelId: widget.channelId, userId: _myId!);
      } else {
        await AppwriteService.instance.subscribeChannel(channelId: widget.channelId, userId: _myId!);
      }
      
      // Server se latest confirmed document fetch karke state synchronize karna
      final doc = await AppwriteService.instance.databases.getDocument(
        databaseId: 'messgram_db',
        collectionId: 'channels',
        documentId: widget.channelId,
      );
      if (mounted) {
        setState(() {
          _channel = ChannelModel.fromMap(doc.data..addAll({'\$id': doc.$id}));
        });
      }
    } catch (e) {
      // Error aane par wapas purani state par revert karna
      await _init();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: ${NetErr.friendly(e)}')));
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to post: ${NetErr.friendly(e)}')));
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
      if (mounted) setState(() => _posts.removeWhere((p) => p.id == id));
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
        if (mounted) setState(() => _posts.removeWhere((p) => p.id == id));
      } catch (_) {}
    }
  }

  Future<void> _reactTo(MessageModel m, String emoji) async {
    if (_myId == null) return;
    try {
      final updatedDoc = await AppwriteService.instance.toggleReaction(messageId: m.id, userId: _myId!, emoji: emoji);
      final updated = MessageModel.fromMap(updatedDoc.data..addAll({'\$id': updatedDoc.$id, '\$createdAt': updatedDoc.$createdAt}));
      LocalDbService.instance.cacheMessage(widget.channelId, updated);
      if (!mounted) return;
      setState(() {
        final i = _posts.indexWhere((p) => p.id == m.id);
        if (i >= 0) _posts[i] = updated;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(NetErr.friendly(e))));
    }
  }

  void _openActionsFor(MessageModel m) {
    // The channel creator can delete anyone's post; others only their own.
    final canDelete = m.senderId == _myId || (_channel?.creatorId != null && _channel!.creatorId == _myId);
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
          : AppBar(title: Text(_channel?.name ?? 'Channel')),
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
                            final isSelected = _selectedIds.contains(p.id);
                            return GestureDetector(
                              onTap: _isSelectionMode ? () => _toggleSelect(p.id) : null,
                              onLongPress: _isSelectionMode ? () => _toggleSelect(p.id) : () => _openActionsFor(p),
                              child: Container(
                                width: double.infinity,
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: isSelected ? AppTheme.cyan.withOpacity(0.18) : AppTheme.surface,
                                  borderRadius: BorderRadius.circular(14),
                                  border: isSelected ? Border.all(color: AppTheme.cyan, width: 1) : null,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(p.text, style: AppTheme.body(color: Colors.white)),
                                    ReactionBar(reactions: p.reactions, currentUserId: _myId, onTapReaction: (emoji) => _reactTo(p, emoji)),
                                  ],
                                ),
                              ),
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
