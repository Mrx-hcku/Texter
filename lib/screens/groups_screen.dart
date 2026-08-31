import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import '../config/theme.dart';
import '../services/appwrite_service.dart';
import '../models/models.dart';
import 'group_chat_screen.dart';
import 'create_group_screen.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  List<GroupModel> _myGroups = [];
  List<GroupModel> _discoverGroups = [];
  bool _loading = true;
  String? _myId;
  final Set<String> _joining = {};
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
    setState(() => _loading = true);
    final me = await AppwriteService.instance.getCurrentUser();
    _myId = me?.$id;
    try {
      final docs = await AppwriteService.instance.getGroups();
      final all = docs.map((d) => GroupModel.fromMap(d.data..addAll({'\$id': d.$id}))).toList();
      setState(() {
        _myGroups = all.where((g) => g.memberIds.contains(_myId)).toList();
        _discoverGroups = all.where((g) => g.isPublic && !g.memberIds.contains(_myId)).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load groups: $e')));
    }
    _sub ??= AppwriteService.instance.subscribeToCollection('groups', (doc, events) {
      _load();
    });
  }

  Future<void> _join(GroupModel g) async {
    if (_myId == null || _joining.contains(g.id)) return;
    setState(() => _joining.add(g.id));
    try {
      await AppwriteService.instance.joinGroup(groupId: g.id, userId: _myId!);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => GroupChatScreen(groupId: g.id, groupName: g.name)),
      ).then((_) => _load());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not join: $e')));
    } finally {
      if (mounted) setState(() => _joining.remove(g.id));
    }
  }

  Widget _groupTile(GroupModel g, {required bool isMember}) {
    return ListTile(
      leading: CircleAvatar(
        radius: 26,
        backgroundColor: AppTheme.primary,
        child: Text(g.name.isNotEmpty ? g.name[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white)),
      ),
      title: Text(g.name, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text('${g.memberIds.length} members${g.isPublic ? '' : ' · Private'}'),
      trailing: isMember
          ? null
          : ElevatedButton(
              onPressed: _joining.contains(g.id) ? null : () => _join(g),
              style: ElevatedButton.styleFrom(minimumSize: const Size(70, 34), padding: EdgeInsets.zero),
              child: _joining.contains(g.id)
                  ? const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Join'),
            ),
      onTap: isMember
          ? () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => GroupChatScreen(groupId: g.id, groupName: g.name)),
              )
          : null,
    );
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
              child: ListView(
                children: [
                  if (_myGroups.isEmpty && _discoverGroups.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 60),
                      child: Center(child: Text('No groups yet — create one!')),
                    ),
                  if (_myGroups.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Text('My Groups', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                    ),
                    ..._myGroups.map((g) => _groupTile(g, isMember: true)),
                  ],
                  if (_discoverGroups.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Text('Discover Public Groups', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                    ),
                    ..._discoverGroups.map((g) => _groupTile(g, isMember: false)),
                  ],
                ],
              ),
            ),
    );
  }
}
