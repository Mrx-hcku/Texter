import 'package:flutter/material.dart';
import 'package:appwrite/models.dart' as models;
import '../config/theme.dart';
import '../services/appwrite_service.dart';
import 'group_chat_screen.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  List<models.Document> _users = [];
  final Set<String> _selected = {};
  String? _myId;
  bool _loading = true;
  bool _creating = false;
  bool _isPublic = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final me = await AppwriteService.instance.getCurrentUser();
    _myId = me?.$id;
    final users = await AppwriteService.instance.searchUsers('', excludeId: _myId);
    setState(() {
      _users = users;
      _loading = false;
    });
  }

  Future<void> _create() async {
    if (_nameCtrl.text.trim().isEmpty || _myId == null || _creating) return;
    setState(() => _creating = true);
    try {
      final members = [_myId!, ..._selected];
      final group = await AppwriteService.instance.createGroup(
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        memberIds: members,
        creatorId: _myId!,
        isPublic: _isPublic,
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => GroupChatScreen(groupId: group.$id, groupName: group.data['name'])),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to create group: $e')));
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Group'),
        actions: [
          TextButton(
            onPressed: _creating ? null : _create,
            child: Text('Create', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: _creating ? 0 : 16)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Group Name')),
                const SizedBox(height: 12),
                TextField(controller: _descCtrl, decoration: const InputDecoration(labelText: 'Description (optional)')),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeColor: AppTheme.primary,
                  value: _isPublic,
                  title: const Text('Public group'),
                  subtitle: Text(_isPublic
                      ? 'Anyone can find and join this group'
                      : 'Only people you add can join'),
                  onChanged: (v) => setState(() => _isPublic = v),
                ),
                const SizedBox(height: 12),
                Text('Add Members', style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ..._users.map((u) {
                  final name = u.data['name'] ?? '';
                  final selected = _selected.contains(u.$id);
                  return CheckboxListTile(
                    value: selected,
                    onChanged: (v) => setState(() {
                      if (v == true) {
                        _selected.add(u.$id);
                      } else {
                        _selected.remove(u.$id);
                      }
                    }),
                    activeColor: AppTheme.primary,
                    title: Text(name),
                    secondary: CircleAvatar(
                      backgroundColor: AppTheme.primary,
                      child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white)),
                    ),
                  );
                }),
              ],
            ),
    );
  }
}
