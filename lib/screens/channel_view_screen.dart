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
      
      final fetchedChannel = ChannelModel.fromMap(doc.data..addAll({'\$id': doc.$id}));
      
      if (mounted) {
        setState(() {
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
          _posts = freshPosts;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
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
