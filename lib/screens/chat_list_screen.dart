import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:intl/intl.dart';
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

  Widget _storyAvatar(String name, {Color ring = AppTheme.cyan}) {
    return Container(
      margin: const EdgeInsets.only(right: 14),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: AppTheme.glowBorder(color: ring),
            child: CircleAvatar(
              radius: 24,
              backgroundColor: AppTheme.surfaceLight,
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: AppTheme.heading(size: 16, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 56,
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTheme.body(size: 10, color: AppTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(models.Document c) {
    final raw = c.$updatedAt;
    try {
      final dt = DateTime.parse(raw).toLocal();
      return DateFormat('HH:mm').format(dt);
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _chats.where((c) {
      final name = (c.data['chatName'] ?? '').toString().toLowerCase();
      return name.contains(_query.toLowerCase());
    }).toList();
    final ringColors = [AppTheme.cyan, AppTheme.pink, AppTheme.cyan, AppTheme.pink];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Texter'),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: () {}),
          IconButton(icon: const Icon(Icons.edit_square), onPressed: () async {
            await Navigator.push(context, MaterialPageRoute(builder: (_) => const NewChatScreen()));
            _load();
          }),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        backgroundColor: AppTheme.surface,
        color: AppTheme.cyan,
        child: Column(
          children: [
            if (_chats.isNotEmpty)
              SizedBox(
                height: 92,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _chats.length > 10 ? 10 : _chats.length,
                  itemBuilder: (context, i) {
                    final c = _chats[i];
                    return GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => OneToOneChatScreen(chatId: c.$id, chatName: c.data['chatName'] ?? ''),
                        ),
                      ),
                      child: _storyAvatar(c.data['chatName'] ?? '', ring: ringColors[i % ringColors.length]),
                    );
                  },
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                style: AppTheme.body(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Search',
                  prefixIcon: Icon(Icons.search, color: AppTheme.textSecondary),
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.cyan))
                  : filtered.isEmpty
                      ? Center(child: Text('No chats yet', style: AppTheme.body(color: AppTheme.textSecondary)))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: filtered.length,
                          itemBuilder: (context, i) {
                            final c = filtered[i];
                            final name = c.data['chatName'] ?? '';
                            final ring = ringColors[i % ringColors.length];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: AppTheme.surface,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: ListTile(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                leading: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: AppTheme.glowBorder(color: ring),
                                  child: CircleAvatar(
                                    radius: 22,
                                    backgroundColor: AppTheme.surfaceLight,
                                    child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: AppTheme.heading(size: 15, color: Colors.white)),
                                  ),
                                ),
                                title: Text(name, style: AppTheme.body(size: 15, weight: FontWeight.w600, color: Colors.white)),
                                subtitle: Text(
                                  c.data['lastMessage'] ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTheme.body(size: 12.5, color: AppTheme.textSecondary),
                                ),
                                trailing: Text(_formatTime(c), style: AppTheme.body(size: 11, color: AppTheme.textSecondary)),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => OneToOneChatScreen(chatId: c.$id, chatName: name)),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.pink,
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const NewChatScreen()));
          _load();
        },
        child: const Icon(Icons.chat_bubble, color: Colors.white),
      ),
    );
  }
}
