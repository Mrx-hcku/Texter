import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
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
  final Map<String, String> _senderNames = {};
  RealtimeSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _init();
    AdsService.showInterstitial();
  }

  @override
  void dispose() {
    _sub?.close();
    super.dispose();
  }

  Future<void> _init() async {
    final user = await AppwriteService.instance.getCurrentUser();
    _myId = user?.$id;
    try {
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
    _sub = AppwriteService.instance.subscribeToMessages(widget.groupId, (doc) async {
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

  @override
  Widget build(BuildContext context) {
    final feed = <Widget>[];
    for (int i = 0; i < _messages.length; i++) {
      final m = _messages[i];
      final mine = m.senderId == _myId;
      final senderName = mine ? '' : (_senderNames[m.senderId] ?? '');
      feed.add(Align(
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
                  child: Text(
                    senderName,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.pink),
                  ),
                ),
              Text(m.text, style: TextStyle(color: mine ? AppTheme.bg : Colors.white)),
            ],
          ),
        ),
      ));
      if (_ads.isNotEmpty && (i + 1) % 6 == 0) {
        final ad = _ads[(i ~/ 6) % _ads.length];
        feed.add(SponsoredAdCard(ad: ad));
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.groupName)),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.cyan))
          : Column(
              children: [
                Expanded(
                  child: feed.isEmpty
                      ? Center(child: Text('No messages yet — say hi!', style: AppTheme.body(color: AppTheme.textSecondary)))
                      : ListView(padding: const EdgeInsets.all(12), children: feed),
                ),
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
                            decoration: const InputDecoration(hintText: 'Message'),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(colors: [AppTheme.cyan, AppTheme.pink]),
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
