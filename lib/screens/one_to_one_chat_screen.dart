import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import 'package:image_picker/image_picker.dart';
import '../config/theme.dart';
import '../services/appwrite_service.dart';
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

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final user = await AppwriteService.instance.getCurrentUser();
    _myId = user?.$id;
    final docs = await AppwriteService.instance.getMessages(widget.chatId);
    setState(() {
      _messages = docs.map((d) => MessageModel.fromMap(d.data..addAll({'\$id': d.$id, '\$createdAt': d.$createdAt}))).toList();
    });
    _sub = AppwriteService.instance.subscribeToMessages(widget.chatId, (doc) {
      setState(() {
        _messages.add(MessageModel.fromMap(doc.data..addAll({'\$id': doc.$id, '\$createdAt': doc.$createdAt})));
      });
    });
  }

  @override
  void dispose() {
    _sub?.close();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _myId == null) return;
    _controller.clear();
    await AppwriteService.instance.sendMessage(chatId: widget.chatId, senderId: _myId!, text: text);
  }

  Future<void> _attachImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null || _myId == null) return;
    final url = await AppwriteService.instance.uploadFile(file.path, file.name);
    await AppwriteService.instance.sendMessage(
      chatId: widget.chatId,
      senderId: _myId!,
      attachmentUrl: url,
      attachmentType: 'image',
    );
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
                return Align(
                  alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                    decoration: BoxDecoration(
                      color: mine ? AppTheme.primary : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: m.attachmentType == 'image' && m.attachmentUrl.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(m.attachmentUrl, width: 200, fit: BoxFit.cover),
                          )
                        : Text(
                            m.text,
                            style: TextStyle(color: mine ? Colors.white : Colors.black87),
                          ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  IconButton(icon: const Icon(Icons.image_outlined), onPressed: _attachImage),
                  IconButton(icon: const Icon(Icons.attach_file), onPressed: () {}),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: 'Message',
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
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
