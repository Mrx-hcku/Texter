import 'dart:io';
import 'package:appwrite/models.dart' as models;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../chat_bubble.dart';
import '../config/theme.dart';
import '../services/appwrite_service.dart';
import '../widgets/texter_ui.dart';
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
  String? _photoPath;
  bool _loading = true;
  bool _creating = false;
  bool _isPublic = true;
  bool _onlyAdminsSend = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final me = await AppwriteService.instance.getCurrentUser();
    _myId = me?.$id;
    final users = await AppwriteService.instance.searchUsers('', excludeId: _myId);
    if (!mounted) return;
    setState(() {
      _users = users;
      _loading = false;
    });
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final x = await ChatBubble.guard(
      () => picker.pickImage(source: ImageSource.gallery, maxWidth: 640, maxHeight: 640, imageQuality: 80),
    );
    if (x != null && mounted) setState(() => _photoPath = x.path);
  }

  Future<void> _create() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Give your group a name')));
      return;
    }
    if (_myId == null || _creating) return;
    setState(() => _creating = true);
    try {
      final group = await AppwriteService.instance.createGroup(
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        memberIds: [_myId!, ..._selected],
        creatorId: _myId!,
        isPublic: _isPublic,
      );
      // optional extras — a failure here must not undo the group
      final extra = <String, dynamic>{};
      if (_onlyAdminsSend) extra['onlyAdminsSend'] = true;
      if (_photoPath != null) {
        try {
          extra['avatarUrl'] = await AppwriteService.instance.uploadFile(_photoPath!, 'group_${DateTime.now().millisecondsSinceEpoch}.jpg');
        } catch (_) {}
      }
      if (extra.isNotEmpty) {
        try {
          await AppwriteService.instance.updateGroup(group.$id, extra);
        } catch (e) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
        }
      }
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => GroupChatScreen(groupId: group.$id, groupName: group.data['name'])),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to create group: ${friendlyError(e)}')));
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = UiPalette.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('New group')),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: u.accent))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
              children: [
                Center(
                  child: GestureDetector(
                    onTap: _pickPhoto,
                    child: Stack(
                      children: [
                        Container(
                          width: 104,
                          height: 104,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: u.cardAlt,
                            border: Border.all(color: u.border),
                            image: _photoPath == null ? null : DecorationImage(image: FileImage(File(_photoPath!)), fit: BoxFit.cover),
                          ),
                          child: _photoPath == null ? Icon(Icons.groups_rounded, size: 44, color: u.subtext) : null,
                        ),
                        Positioned(
                          right: 0,
                          bottom: 2,
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: kTexterGradient)),
                            child: const Icon(Icons.photo_camera_rounded, color: Colors.white, size: 18),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  style: AppTheme.body(color: u.text),
                  decoration: const InputDecoration(labelText: 'Group name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descCtrl,
                  minLines: 1,
                  maxLines: 3,
                  style: AppTheme.body(color: u.text),
                  decoration: const InputDecoration(labelText: 'Description (optional)'),
                ),
                const SectionLabel('Settings'),
                TexterCard(children: [
                  TexterSwitchRow(
                    icon: Icons.public_rounded,
                    title: 'Public group',
                    subtitle: _isPublic ? 'Anyone can find and join' : 'Only people you add can join',
                    value: _isPublic,
                    onChanged: (v) => setState(() => _isPublic = v),
                  ),
                  texterDivider(context),
                  TexterSwitchRow(
                    icon: Icons.lock_rounded,
                    title: 'Only admins can send',
                    subtitle: 'Members can read, but not write',
                    value: _onlyAdminsSend,
                    onChanged: (v) => setState(() => _onlyAdminsSend = v),
                  ),
                ]),
                SectionLabel('Add members${_selected.isEmpty ? '' : ' · ${_selected.length}'}'),
                if (_users.isEmpty)
                  Padding(padding: const EdgeInsets.all(16), child: Text('No other users yet', style: AppTheme.body(color: u.subtext)))
                else
                  for (final d in _users)
                    Builder(builder: (_) {
                      final name = (d.data['name'] ?? '').toString();
                      final picked = _selected.contains(d.$id);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: picked ? u.accent.withOpacity(0.10) : u.card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: picked ? u.accent : u.border),
                        ),
                        child: ListTile(
                          onTap: () => setState(() => picked ? _selected.remove(d.$id) : _selected.add(d.$id)),
                          leading: TexterAvatar(name: name, url: (d.data['avatarUrl'] ?? '').toString(), size: 42),
                          title: Text(name, style: AppTheme.body(size: 15, weight: FontWeight.w600, color: u.text)),
                          trailing: Icon(picked ? Icons.check_circle_rounded : Icons.radio_button_unchecked, color: picked ? u.accent : u.subtext),
                        ),
                      );
                    }),
                const SizedBox(height: 22),
                Center(child: GradientButton(label: 'Create group', icon: Icons.group_add_rounded, busy: _creating, onTap: _create, height: 52)),
              ],
            ),
    );
  }
}
