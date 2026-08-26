import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _init();
    // Show a real Unity Ads interstitial occasionally when entering a group.
    AdsService.showInterstitial();
  }

  Future<void> _init() async {
    final user = await AppwriteService.instance.getCurrentUser();
    _myId = user?.$id;
    final msgDocs = await AppwriteService.instance.getMessages(widget.groupId);
    final adDocs = await AppwriteService.instance.getAds(targetType: 'group');
    setState(() {
      _messages = msgDocs
          .map((d) => MessageModel.fromMap(d.data..addAll({'\$id': d.$id, '\$createdAt': d.$createdAt})))
          .toList();
      _ads = adDocs.map((d) => AdModel.fromMap(d.data..addAll({'\$id': d.$id}))).toList();
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _myId == null) return;
    _controller.clear();
    final doc = await AppwriteService.instance.sendMessage(chatId: widget.groupId, senderId: _myId!, text: text);
    setState(() {
      _messages.add(MessageModel.fromMap(doc.data..addAll({'\$id': doc.$id, '\$createdAt': doc.$createdAt})));
    });
  }

  @override
  Widget build(BuildContext context) {
    // Insert one sponsored card after every 6 messages.
    final feed = <Widget>[];
    for (int i = 0; i < _messages.length; i++) {
      final m = _messages[i];
      final mine = m.senderId == _myId;
      feed.add(Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
          decoration: BoxDecoration(
            color: mine ? AppTheme.primary : Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(m.text, style: TextStyle(color: mine ? Colors.white : Colors.black87)),
        ),
      ));
      if (_ads.isNotEmpty && (i + 1) % 6 == 0) {
        final ad = _ads[(i ~/ 6) % _ads.length];
        feed.add(SponsoredAdCard(ad: ad));
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.groupName)),
      body: Column(
        children: [
          Expanded(child: ListView(padding: const EdgeInsets.all(12), children: feed)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(hintText: 'Message'),
                    ),
                  ),
                  const SizedBox(width: 6),
                  CircleAvatar(
                    backgroundColor: AppTheme.primary,
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
