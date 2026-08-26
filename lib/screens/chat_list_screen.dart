import 'package:flutter/material.dart';
import 'package:appwrite/models.dart' as models;
import '../config/theme.dart';
import '../services/appwrite_service.dart';
import 'one_to_one_chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  List<models.Document> _chats = [];
  String _query = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = await AppwriteService.instance.getCurrentUser();
    if (user == null) return;
    final chats = await AppwriteService.instance.getChats(user.$id);
    setState(() {
      _chats = chats;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _chats.where((c) {
      final name = (c.data['name'] ?? '').toString().toLowerCase();
      return name.contains(_query.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        actions: [IconButton(icon: const Icon(Icons.edit_square), onPressed: () {})],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: const InputDecoration(
                  hintText: 'Search',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                      ? const Center(child: Text('No chats yet'))
                      : ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (context, i) {
                            final c = filtered[i];
                            final name = c.data['name'] ?? '';
                            return ListTile(
                              leading: CircleAvatar(
                                radius: 26,
                                backgroundColor: AppTheme.primary,
                                child: Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text(
                                c.data['lastMessage'] ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => OneToOneChatScreen(chatId: c.$id, chatName: name),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
