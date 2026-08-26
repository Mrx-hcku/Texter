import 'package:flutter/material.dart';
import 'package:appwrite/models.dart' as models;
import '../config/theme.dart';
import '../services/appwrite_service.dart';
import 'group_chat_screen.dart';
import 'create_group_screen.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  List<models.Document> _groups = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final groups = await AppwriteService.instance.getGroups();
    setState(() {
      _groups = groups;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Groups'),
        actions: [IconButton(icon: const Icon(Icons.add), onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateGroupScreen()));
          _load();
        })],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                itemCount: _groups.length,
                itemBuilder: (context, i) {
                  final g = _groups[i];
                  final name = g.data['name'] ?? '';
                  final memberCount = (g.data['memberIds'] as List?)?.length ?? 0;
                  return ListTile(
                    leading: CircleAvatar(
                      radius: 26,
                      backgroundColor: AppTheme.primary,
                      child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white)),
                    ),
                    title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('$memberCount members'),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => GroupChatScreen(groupId: g.$id, groupName: name)),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
