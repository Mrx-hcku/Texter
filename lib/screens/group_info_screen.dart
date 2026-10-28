import 'package:appwrite/models.dart' as models;
import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../config/theme.dart';
import '../models/models.dart';
import '../services/appwrite_service.dart';
import '../widgets/texter_ui.dart';
import 'user_picker_screen.dart';

/// Group info + admin controls (who can send / edit / add, join approval),
/// members list with make-admin / remove, join requests, leave / delete.
class GroupInfoScreen extends StatefulWidget {
  final String groupId;
  const GroupInfoScreen({super.key, required this.groupId});

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  GroupModel? _g;
  String? _myId;
  bool _loading = true;
  List<models.Document> _members = [];
  List<models.Document> _pending = [];
  final Map<String, bool> _flagOverride = {};

  bool get _isAdmin => _g?.isAdmin(_myId) ?? false;
  bool get _isOwner => _g != null && _g!.ownerId == _myId;
  bool get _canEdit => _isAdmin || !(_g?.onlyAdminsEdit ?? false);
  bool get _canAdd => _isAdmin || !(_g?.onlyAdminsAdd ?? false);

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  bool _flag(String key, bool server) => _flagOverride[key] ?? server;

  Future<void> _load() async {
    try {
      final me = await AppwriteService.instance.getCurrentUser();
      _myId = me?.$id;
      final doc = await AppwriteService.instance.databases.getDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.groupsCollection,
        documentId: widget.groupId,
      );
      final g = GroupModel.fromMap(doc.data..addAll({'\$id': doc.$id}));
      final members = await AppwriteService.instance.getUsersByIds(g.memberIds);
      final pending = g.pendingIds.isEmpty ? <models.Document>[] : await AppwriteService.instance.getUsersByIds(g.pendingIds);
      members.sort((a, b) {
        int rank(models.Document d) => d.$id == g.ownerId ? 0 : (g.adminIds.contains(d.$id) ? 1 : 2);
        final r = rank(a).compareTo(rank(b));
        if (r != 0) return r;
        return (a.data['name'] ?? '').toString().toLowerCase().compareTo((b.data['name'] ?? '').toString().toLowerCase());
      });
      if (mounted) {
        setState(() {
          _g = g;
          _members = members;
          _pending = pending;
          _flagOverride.clear();
        });
      }
    } catch (e) {
      _snack('Could not load group: ${friendlyError(e)}');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _update(Map<String, dynamic> data) async {
    try {
      await AppwriteService.instance.updateGroup(widget.groupId, data);
      await _load();
    } catch (e) {
      if (mounted) setState(_flagOverride.clear);
      _snack(friendlyError(e));
    }
  }

  Future<void> _setFlag(String key, bool value) async {
    setState(() => _flagOverride[key] = value);
    await _update({key: value});
  }

  Future<void> _changePhoto() async {
    final url = await pickAndUploadAvatar(context);
    if (url != null) await _update({'avatarUrl': url});
  }

  Future<void> _editDetails() async {
    final g = _g;
    if (g == null) return;
    final u = UiPalette.of(context);
    final nameCtl = TextEditingController(text: g.name);
    final descCtl = TextEditingController(text: g.description);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: u.card,
        title: Text('Edit group', style: AppTheme.heading(size: 18, color: u.text)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtl, style: AppTheme.body(color: u.text), decoration: const InputDecoration(labelText: 'Group name')),
            const SizedBox(height: 12),
            TextField(controller: descCtl, minLines: 2, maxLines: 4, style: AppTheme.body(color: u.text), decoration: const InputDecoration(labelText: 'Description')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: TextStyle(color: u.subtext))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Save', style: TextStyle(color: u.accent))),
        ],
      ),
    );
    if (ok == true && nameCtl.text.trim().isNotEmpty) {
      await _update({'name': nameCtl.text.trim(), 'description': descCtl.text.trim()});
    }
  }

  Future<void> _addMembers() async {
    final g = _g;
    if (g == null) return;
    final picked = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(
        builder: (_) => UserPickerScreen(
          title: 'Add members',
          emptyText: 'Everyone is already here',
          loader: () async {
            final all = await AppwriteService.instance.searchUsers('', excludeId: _myId);
            return all.where((d) => !g.memberIds.contains(d.$id)).toList();
          },
        ),
      ),
    );
    if (picked == null || picked.isEmpty) return;
    try {
      await AppwriteService.instance.addGroupMembers(widget.groupId, picked);
      await _load();
      _snack('${picked.length} added');
    } catch (e) {
      _snack(friendlyError(e));
    }
  }

  Future<void> _resolve(String userId, bool approve) async {
    try {
      await AppwriteService.instance.resolveJoinRequest(groupId: widget.groupId, userId: userId, approve: approve);
      await _load();
    } catch (e) {
      _snack(friendlyError(e));
    }
  }

  Future<void> _toggleAdmin(String userId) async {
    final g = _g;
    if (g == null) return;
    final admins = List<String>.from(g.adminIds);
    if (admins.contains(userId)) {
      admins.remove(userId);
    } else {
      admins.add(userId);
    }
    try {
      await AppwriteService.instance.setGroupAdmins(widget.groupId, admins);
      await _load();
    } catch (e) {
      _snack(friendlyError(e));
    }
  }

  Future<bool> _confirm(String title, String body, String action) async {
    final u = UiPalette.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: u.card,
        title: Text(title, style: AppTheme.heading(size: 17, color: u.text)),
        content: Text(body, style: AppTheme.body(color: u.subtext)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: TextStyle(color: u.subtext))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(action, style: const TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _removeMember(String userId, String name) async {
    if (!await _confirm('Remove $name?', 'They will be taken out of this group.', 'Remove')) return;
    try {
      await AppwriteService.instance.removeGroupMember(widget.groupId, userId);
      await _load();
    } catch (e) {
      _snack(friendlyError(e));
    }
  }

  Future<void> _leave() async {
    final g = _g;
    if (g == null || _myId == null) return;
    if (!await _confirm('Leave group?', 'You will no longer get messages from this group.', 'Leave')) return;
    try {
      final others = g.memberIds.where((m) => m != _myId).toList();
      if (others.isEmpty) {
        await AppwriteService.instance.deleteGroup(widget.groupId);
      } else {
        // never leave a group without an admin
        if (g.isAdmin(_myId) && g.adminIds.where((a) => a != _myId).isEmpty) {
          await AppwriteService.instance.setGroupAdmins(widget.groupId, [others.first]);
        }
        await AppwriteService.instance.removeGroupMember(widget.groupId, _myId!);
      }
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      _snack(friendlyError(e));
    }
  }

  Future<void> _deleteGroup() async {
    if (!await _confirm('Delete group?', 'The group and all its messages will be deleted for everyone. This cannot be undone.', 'Delete')) return;
    try {
      await AppwriteService.instance.deleteGroup(widget.groupId);
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      _snack(friendlyError(e));
    }
  }

  bool _canManage(String targetId) {
    final g = _g;
    if (g == null || !_isAdmin || targetId == _myId || targetId == g.ownerId) return false;
    if (g.adminIds.contains(targetId)) return _isOwner; // only the owner can touch other admins
    return true;
  }

  Widget _memberRow(models.Document d, UiPalette u) {
    final g = _g!;
    final name = (d.data['name'] ?? '').toString();
    final isOwner = d.$id == g.ownerId;
    final isAdm = g.adminIds.contains(d.$id) && !isOwner;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          TexterAvatar(name: name, url: (d.data['avatarUrl'] ?? '').toString(), size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(d.$id == _myId ? '$name (You)' : name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.body(size: 15, weight: FontWeight.w600, color: u.text)),
                ),
                const SizedBox(width: 8),
                if (isOwner) const TexterChip('Owner', color: AppTheme.pink) else if (isAdm) const TexterChip('Admin'),
              ],
            ),
          ),
          if (_canManage(d.$id))
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: u.subtext),
              onSelected: (v) {
                if (v == 'admin') _toggleAdmin(d.$id);
                if (v == 'remove') _removeMember(d.$id, name);
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'admin', child: Text(isAdm ? 'Remove as admin' : 'Make admin')),
                const PopupMenuItem(value: 'remove', child: Text('Remove from group', style: TextStyle(color: Colors.redAccent))),
              ],
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final u = UiPalette.of(context);
    final g = _g;
    return Scaffold(
      appBar: AppBar(title: const Text('Group info')),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: u.accent))
          : g == null
              ? Center(child: Text('Group not found', style: AppTheme.body(color: u.subtext)))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 32),
                  children: [
                    // ---- header ----
                    Center(
                      child: Stack(
                        children: [
                          TexterAvatar(name: g.name, url: g.avatarUrl, size: 112, ring: true),
                          if (_canEdit)
                            Positioned(
                              right: 0,
                              bottom: 2,
                              child: GestureDetector(
                                onTap: _changePhoto,
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: kTexterGradient)),
                                  child: const Icon(Icons.photo_camera_rounded, color: Colors.white, size: 19),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(child: Text(g.name, textAlign: TextAlign.center, style: AppTheme.heading(size: 23, color: u.text))),
                        if (_canEdit) IconButton(visualDensity: VisualDensity.compact, icon: Icon(Icons.edit_rounded, size: 19, color: u.subtext), onPressed: _editDetails),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Center(child: Text('Group · ${g.memberIds.length} members${g.isPublic ? '' : ' · Private'}', style: AppTheme.body(size: 13.5, color: u.subtext))),
                    if (g.description.trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Center(child: Text(g.description, textAlign: TextAlign.center, style: AppTheme.body(size: 14.5, color: u.text))),
                    ],
                    if (_canAdd) ...[
                      const SizedBox(height: 18),
                      Center(child: GradientButton(label: 'Add members', icon: Icons.person_add_alt_1_rounded, onTap: _addMembers)),
                    ],

                    // ---- admin controls ----
                    if (_isAdmin) ...[
                      const SectionLabel('Admin controls'),
                      TexterCard(children: [
                        TexterSwitchRow(
                          icon: Icons.lock_rounded,
                          title: 'Only admins can send',
                          subtitle: 'Members can read, but not write',
                          value: _flag('onlyAdminsSend', g.onlyAdminsSend),
                          onChanged: (v) => _setFlag('onlyAdminsSend', v),
                        ),
                        texterDivider(context),
                        TexterSwitchRow(
                          icon: Icons.edit_note_rounded,
                          title: 'Only admins can edit info',
                          subtitle: 'Name, photo and description',
                          value: _flag('onlyAdminsEdit', g.onlyAdminsEdit),
                          onChanged: (v) => _setFlag('onlyAdminsEdit', v),
                        ),
                        texterDivider(context),
                        TexterSwitchRow(
                          icon: Icons.person_add_alt_rounded,
                          title: 'Only admins can add members',
                          subtitle: 'Others cannot bring new people',
                          value: _flag('onlyAdminsAdd', g.onlyAdminsAdd),
                          onChanged: (v) => _setFlag('onlyAdminsAdd', v),
                        ),
                        texterDivider(context),
                        TexterSwitchRow(
                          icon: Icons.how_to_reg_rounded,
                          title: 'Approve new members',
                          subtitle: 'People who join need an admin\'s OK',
                          value: _flag('needApproval', g.needApproval),
                          onChanged: (v) => _setFlag('needApproval', v),
                        ),
                        texterDivider(context),
                        TexterSwitchRow(
                          icon: Icons.public_rounded,
                          title: 'Public group',
                          subtitle: 'Anyone can find it in Discover',
                          value: _flag('isPublic', g.isPublic),
                          onChanged: (v) => _setFlag('isPublic', v),
                        ),
                      ]),
                    ],

                    // ---- join requests ----
                    if (_isAdmin && _pending.isNotEmpty) ...[
                      SectionLabel('Join requests · ${_pending.length}'),
                      TexterCard(children: [
                        for (var i = 0; i < _pending.length; i++) ...[
                          if (i > 0) texterDivider(context),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            child: Row(
                              children: [
                                TexterAvatar(name: (_pending[i].data['name'] ?? '').toString(), url: (_pending[i].data['avatarUrl'] ?? '').toString(), size: 42),
                                const SizedBox(width: 12),
                                Expanded(child: Text((_pending[i].data['name'] ?? '').toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.body(size: 15, weight: FontWeight.w600, color: u.text))),
                                IconButton(icon: const Icon(Icons.close_rounded, color: Colors.redAccent), onPressed: () => _resolve(_pending[i].$id, false)),
                                IconButton(icon: Icon(Icons.check_circle_rounded, color: u.accent), onPressed: () => _resolve(_pending[i].$id, true)),
                              ],
                            ),
                          ),
                        ],
                      ]),
                    ],

                    // ---- members ----
                    SectionLabel('Members · ${g.memberIds.length}'),
                    TexterCard(children: [
                      for (var i = 0; i < _members.length; i++) ...[
                        if (i > 0) texterDivider(context),
                        _memberRow(_members[i], u),
                      ],
                    ]),

                    // ---- leave / delete ----
                    const SizedBox(height: 22),
                    TexterCard(children: [
                      if (g.memberIds.contains(_myId))
                        TexterRow(icon: Icons.logout_rounded, title: 'Leave group', color: Colors.redAccent, titleColor: Colors.redAccent, onTap: _leave),
                      if (_isOwner) ...[
                        if (g.memberIds.contains(_myId)) texterDivider(context),
                        TexterRow(
                          icon: Icons.delete_forever_rounded,
                          title: 'Delete group',
                          subtitle: 'Removes it for everyone',
                          color: Colors.redAccent,
                          titleColor: Colors.redAccent,
                          onTap: _deleteGroup,
                        ),
                      ],
                    ]),
                  ],
                ),
    );
  }
}
