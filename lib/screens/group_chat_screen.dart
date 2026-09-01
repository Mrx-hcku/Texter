import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
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
  bool _isAdmin = false;
  bool _loading = true;
  bool _uploading = false;
  String? _pinnedMessageText;
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
      // Fetch group details to check admin status and current pinned message
      final groupDoc = await AppwriteService.instance.getGroupDoc(widget.groupId);
      if (groupDoc != null) {
        final adminId = groupDoc.data['adminId'] ?? '';
        _isAdmin = (adminId == _myId);
        _pinnedMessageText = groupDoc.data['pinnedMessage'];
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

  Future<void> _pinMessage(String text) async {
    if (!_isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Only admin can pin messages')));
      return;
    }
    try {
      await AppwriteService.instance.updateGroupPinnedMessage(widget.groupId, text);
      setState(() {
        _pinnedMessageText = text;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Message pinned successfully')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to pin message: $e')));
    }
  }

  Future<void> _unpinMessage() async {
    if (!_isAdmin) return;
    try {
      await AppwriteService.instance.updateGroupPinnedMessage(widget.groupId, '');
      setState(() {
        _pinnedMessageText = null;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Message unpinned')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to unpin: $e')));
    }
  }

  Future<void> _attachImage() async {
    if (_myId == null) return;
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;
    setState(() => _uploading = true);
    try {
      final url = await AppwriteService.instance.uploadFile(file.path, file.name);
      final doc = await AppwriteService.instance.sendMessage(
        chatId: widget.groupId,
        senderId: _myId!,
        attachmentUrl: url,
        attachmentType: 'image',
      );
      if (!_messages.any((m) => m.id == doc.$id)) {
        setState(() {
          _messages.add(MessageModel.fromMap(doc.data..addAll({'\$id': doc.$id, '\$createdAt': doc.$createdAt})));
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to upload image: $e')));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _attachFile() async {
    if (_myId == null || _uploading) return;
    final result = await FilePicker.platform.pickFiles(withData: false);
    if (result == null || result.files.single.path == null) return;
    final path = result.files.single.path!;
    final fileName = result.files.single.name;
    setState(() => _uploading = true);
    try {
      final url = await AppwriteService.instance.uploadFile(path, fileName);
      final doc = await AppwriteService.instance.sendMessage(
        chatId: widget.groupId,
        senderId: _myId!,
        text: fileName,
        attachmentUrl: url,
        attachmentType: 'file',
      );
      if (!_messages.any((m) => m.id == doc.$id)) {
        setState(() {
          _messages.add(MessageModel.fromMap(doc.data..addAll({'\$id': doc.$id, '\$createdAt': doc.$createdAt})));
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to upload file: $e')));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final feed = <Widget>[];
    for (int i = 0; i < _messages.length; i++) {
      final m = _messages[i];
      final mine = m.senderId == _myId;
      final senderName = mine ? '' : (_senderNames[m.senderId] ?? 'Member');
      
      Widget content;
      if (m.attachmentType == 'image' && m.attachmentUrl.isNotEmpty) {
        content = ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(m.attachmentUrl, width: 200, fit: BoxFit.cover),
        );
      } else {
        content = Text(
          m.text, 
          style: TextStyle(color: mine ? Colors.white : Colors.white70, fontSize: 14),
        );
      }

      feed.add(GestureDetector(
        onLongPress: () {
          if (_isAdmin && m.text.isNotEmpty) {
            showModalBottomSheet(
              context: context,
              backgroundColor: const Color(0xFF0E131F),
              builder: (ctx) => SafeArea(
                child: Wrap(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.push_pin, color: Color(0xFF00F0FF)),
                      title: const Text('Pin this message', style: TextStyle(color: Colors.white)),
                      onTap: () {
                        Navigator.pop(ctx);
                        _pinMessage(m.text);
                      },
                    ),
                  ],
                ),
              ),
            );
          }
        },
        child: Align(
          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            decoration: BoxDecoration(
              color: const Color(0xFF0E131F),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: mine ? const Color(0xFFFF007F).withOpacity(0.6) : const Color(0xFF00F0FF).withOpacity(0.4),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!mine && senderName.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      senderName,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFFF007F)),
                    ),
                  ),
                content,
              ],
            ),
          ),
        ),
      ));

      if (_ads.isNotEmpty && (i + 1) % 6 == 0) {
        final ad = _ads[(i ~/ 6) % _ads.length];
        feed.add(SponsoredAdCard(ad: ad));
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFF05070B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF05070B),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF00F0FF)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.groupName,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const Text(
              '145 Members',
              style: TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_pinnedMessageText != null && _pinnedMessageText!.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFF0E131F).withOpacity(0.9),
              child: Row(
                children: [
                  const Icon(Icons.push_pin, color: Color(0xFF00F0FF), size: 14),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Pinned: $_pinnedMessageText',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_isAdmin)
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54, size: 14),
                      onPressed: _unpinMessage,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF00F0FF)))
                : feed.isEmpty
                    ? const Center(child: Text('No messages yet — say hi!', style: TextStyle(color: Colors.white54)))
                    : ListView(padding: const EdgeInsets.all(12), children: feed),
          ),
          if (_uploading) const LinearProgressIndicator(minHeight: 2, color: Color(0xFF00F0FF), backgroundColor: Color(0xFF0E131F)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            color: const Color(0xFF05070B),
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.camera_alt_outlined, color: Color(0xFF00F0FF), size: 20),
                    onPressed: _uploading ? null : _attachImage,
                  ),
                  IconButton(
                    icon: const Icon(Icons.attach_file, color: Color(0xFF00F0FF), size: 20),
                    onPressed: _uploading ? null : _attachFile,
                  ),
                  IconButton(
                    icon: const Icon(Icons.mic_none, color: Color(0xFF00F0FF), size: 20),
                    onPressed: () {},
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Secure message...',
                        hintStyle: const TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: const Color(0xFF0E131F),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFFF007F),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white, size: 18),
                      onPressed: _send,
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
