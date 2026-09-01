import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import '../config/theme.dart';
import '../services/appwrite_service.dart';
import 'one_to_one_chat_screen.dart';
import 'new_chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  List<models.Document> _chats = [];
  String _query = '';
  bool _loading = true;
  String? _myId;
  RealtimeSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _sub?.close();
    super.dispose();
  }

  Future<void> _load() async {
    final user = await AppwriteService.instance.getCurrentUser();
    if (user == null) return;
    _myId = user.$id;
    try {
      final chats = await AppwriteService.instance.getChats(user.$id);
      setState(() {
        _chats = chats;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
    _sub ??= AppwriteService.instance.subscribeToCollection('chats', (doc, events) {
      final ids = (doc.data['participantIds'] as String? ?? '').split(',').where((e) => e.isNotEmpty).toList();
      if (_myId == null || !ids.contains(_myId)) return;
      if (!mounted) return;
      setState(() {
        final i = _chats.indexWhere((c) => c.$id == doc.$id);
        if (i >= 0) {
          _chats[i] = doc;
        } else {
          _chats.insert(0, doc);
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _chats.where((c) {
      final name = (c.data['chatName'] ?? '').toString().toLowerCase();
      return name.contains(_query.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF05070B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF05070B),
        elevation: 0,
        title: const Text(
          'Texter',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_square, color: Color(0xFF00F0FF)),
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const NewChatScreen()));
              _load();
            },
          )
        ],
      ),
      body: RefreshIndicator(
        color: const Color(0xFF00F0FF),
        backgroundColor: const Color(0xFF0E131F),
        onRefresh: _load,
        child: Column(
          children: [
            SizedBox(
              height: 90,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: 6,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: index == 0 ? const Color(0xFFFF007F) : const Color(0xFF00F0FF),
                              width: 2,
                            ),
                          ),
                          child: const CircleAvatar(
                            radius: 24,
                            backgroundColor: Color(0xFF1E222B),
                            child: Icon(Icons.person, color: Colors.white70),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Agent',
                          style: TextStyle(color: Colors.white54, fontSize: 10),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search secure channels...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF00F0FF)),
                  filled: true,
                  fillColor: const Color(0xFF0E131F),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF00F0FF)))
                  : filtered.isEmpty
                      ? const Center(child: Text('No secure chats yet', style: TextStyle(color: Colors.white54)))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: filtered.length,
                          itemBuilder: (context, i) {
                            final c = filtered[i];
                            final name = c.data['chatName'] ?? '';
                            return Container(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0E131F),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                leading: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: const Color(0xFF00F0FF), width: 1.5),
                                  ),
                                  child: CircleAvatar(
                                    radius: 24,
                                    backgroundColor: const Color(0xFF1E222B),
                                    child: Text(
                                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                                      style: const TextStyle(color: Color(0xFF00F0FF), fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                                title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                                subtitle: Text(
                                  c.data['lastMessage'] ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white54, fontFamily: 'monospace'),
                                ),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF007F).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    'Active',
                                    style: TextStyle(color: Color(0xFFFF007F), fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => OneToOneChatScreen(chatId: c.$id, chatName: name),
                                  ),
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
