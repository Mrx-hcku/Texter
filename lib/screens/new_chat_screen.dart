import 'package:flutter/material.dart';
import 'package:appwrite/models.dart' as models;
import '../config/theme.dart';
import '../services/appwrite_service.dart';
import 'one_to_one_chat_screen.dart';

class NewChatScreen extends StatefulWidget {
  const NewChatScreen({super.key});

  @override
  State<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  List<models.Document> _users = [];
  bool _loading = true;
  String? _myId;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load([String query = '']) async {
    setState(() => _loading = true);
    final me = await AppwriteService.instance.getCurrentUser();
    _myId = me?.$id;
    final users = await AppwriteService.instance.searchUsers(query, excludeId: _myId);
    setState(() {
      _users = users;
      _loading = false;
    });
  }

  Future<void> _startChat(models.Document user) async {
    if (_myId == null || _starting) return;
    setState(() => _starting = true);
    try {
      final chat = await AppwriteService.instance.findOrCreateDirectChat(
        myId: _myId!,
        otherId: user.$id,
        otherName: user.data['name'] ?? '',
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => OneToOneChatScreen(chatId: chat.$id, chatName: user.data['name'] ?? ''),
        ),
      );
    } catch (e) {
      setState(() => _starting = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not start chat: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Chat')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              onChanged: _load,
              style: AppTheme.body(color: Colors.white),
              decoration: const InputDecoration(hintText: 'Search by name', prefixIcon: Icon(Icons.search, color: AppTheme.textSecondary)),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.cyan))
                : _users.isEmpty
                    ? Center(child: Text('No users found', style: AppTheme.body(color: AppTheme.textSecondary)))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: _users.length,
                        itemBuilder: (context, i) {
                          final u = _users[i];
                          final name = u.data['name'] ?? '';
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(14)),
                            child: ListTile(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              leading: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: AppTheme.glowBorder(),
                                child: CircleAvatar(
                                  backgroundColor: AppTheme.surfaceLight,
                                  child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: AppTheme.heading(size: 14, color: Colors.white)),
                                ),
                              ),
                              title: Text(name, style: AppTheme.body(color: Colors.white, weight: FontWeight.w600)),
                              subtitle: Text(u.data['email'] ?? '', style: AppTheme.body(size: 12, color: AppTheme.textSecondary)),
                              onTap: () => _startChat(u),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
