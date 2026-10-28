import 'package:appwrite/models.dart' as models;
import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/models.dart';
import '../services/appwrite_service.dart';
import '../widgets/texter_ui.dart';
import 'user_picker_screen.dart';

/// Channel info + admin controls.
/// Everyone: photo, name, description, follower count, follow / unfollow.
/// Admins also get: edit channel, add / remove admins, see + remove followers.
/// Only the owner can delete the channel.
class ChannelInfoScreen extends StatefulWidget {
  final String channelId;
  const ChannelInfoScreen({super.key, required this.channelId});

  @override
  State<ChannelInfoScreen> createState() => _ChannelInfoScreenState();
}

class _ChannelInfoScreenState extends State<ChannelInfoScreen> {
  ChannelModel? _c;
  String? _myId;
  bool _loading = true;
  bool _busy = false;

  List<models.Document> _admins = [];
  List<models.Document> _followers = [];
  bool _showFollowers = false;
  bool _followersLoading = false;

  bool get _isAdmin => _c?.isAdmin(_myId) ?? false;
  bool get _isOwner => _c?.isOwner(_myId) ?? false;
  bool get _isFollowing => _c != null && _myId != null && _c!.subscriberIds.contains(_myId);

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

  Future<void> _load() async {
    try {
      final me = await AppwriteService.instance.getCurrentUser();
      _myId = me?.$id;
      final doc = await AppwriteService.instance.getChannelDoc(widget.channelId);
      final c = ChannelModel.fromMap(doc.data..addAll({'\$id': doc.$id}));
      final adminIds = <String>{if (c.ownerId.isNotEmpty) c.ownerId, ...c.adminIds}.toList();
      final admins = await AppwriteService.instance.getUsersByIds(adminIds);
      admins.sort((a, b) => (a.$id == c.ownerId ? 0 : 1).compareTo(b.$id == c.ownerId ? 0 : 1));
      if (mounted) {
        setState(() {
          _c = c;
          _admins = admins;
        });
      }
      if (_showFollowers) _loadFollowers();
    } catch (e) {
      _snack('Could not load channel: ${friendlyError(e)}');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadFollowers() async {
    final c = _c;
    if (c == null) return;
    setState(() => _followersLoading = true);
    final list = await AppwriteService.instance.getUsersByIds(c.subscriberIds);
    list.sort((a, b) => (a.data['name'] ?? '').toString().toLowerCase().compareTo((b.data['name'] ?? '').toString().toLowerCase()));
    if (mounted) {
      setState(() {
        _followers = list;
        _followersLoading = false;
      });
    }
  }

  Future<void> _update(Map<String, dynamic> data) async {
    try {
      await AppwriteService.instance.updateChannel(widget.channelId, data);
      await _load();
    } catch (e) {
      _snack(friendlyError(e));
    }
  }

  Future<void> _changePhoto() async {
    final url = await pickAndUploadAvatar(context);
    if (url != null) await _update({'avatarUrl': url});
  }

  Future<void> _editDetails() async {
    final c = _c;
    if (c == null) return;
    final u = UiPalette.of(context);
    final nameCtl = TextEditingController(text: c.name);
    final descCtl = TextEditingController(text: c.description);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: u.card,
        title: Text('Edit channel', style: AppTheme.heading(size: 18, color: u.text)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtl, style: AppTheme.body(color: u.text), decoration: const InputDecoration(labelText: 'Channel name')),
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

  Future<void> _toggleFollow() async {
    if (_myId == null || _busy) return;
    setState(() => _busy = true);
    try {
      if (_isFollowing) {
        await AppwriteService.instance.unsubscribeChannel(channelId: widget.channelId, userId: _myId!);
      } else {
        await AppwriteService.instance.subscribeChannel(channelId: widget.channelId, userId: _myId!);
      }
      await _load();
    } catch (e) {
      _snack(friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Saves the admin list (the owner always stays in it).
  Future<void> _saveAdmins(List<String> ids) async {
    final c = _c;
    if (c == null) return;
    final list = <String>{if (c.ownerId.isNotEmpty) c.ownerId, ...ids}.toList();
    try {
      await AppwriteService.instance.setChannelAdmins(widget.channelId, list);
      // channels made before owners were stored: remember the owner now
      if (c.creatorId.isEmpty && c.ownerId.isNotEmpty) {
        try {
          await AppwriteService.instance.updateChannel(widget.channelId, {'creatorId': c.ownerId});
        } catch (_) {}
      }
      await _load();
    } catch (e) {
      _snack(friendlyError(e));
    }
  }

  Future<void> _addAdmin() async {
    final c = _c;
    if (c == null) return;
    final picked = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(
        builder: (_) => UserPickerScreen(
          title: 'Add admins',
          emptyText: 'Only followers can be made admins',
          loader: () async {
            final ids = c.subscriberIds.where((id) => !c.isAdmin(id)).toList();
            return AppwriteService.instance.getUsersByIds(ids);
          },
        ),
      ),
    );
    if (picked == null || picked.isEmpty) return;
    await _saveAdmins([...c.adminIds, ...picked]);
  }

  Future<void> _removeAdmin(String userId) async {
    final c = _c;
    if (c == null) return;
    await _saveAdmins(c.adminIds.where((id) => id != userId).toList());
  }

  Future<void> _removeFollower(String userId, String name) async {
    final u = UiPalette.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: u.card,
        title: Text('Remove $name?', style: AppTheme.heading(size: 17, color: u.text)),
        content: Text('They will stop receiving this channel. They can follow again later.', style: AppTheme.body(color: u.subtext)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: TextStyle(color: u.subtext))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await AppwriteService.instance.unsubscribeChannel(channelId: widget.channelId, userId: userId);
      if (_c!.adminIds.contains(userId)) await _saveAdmins(_c!.adminIds.where((id) => id != userId).toList());
      await _load();
    } catch (e) {
      _snack(friendlyError(e));
    }
  }

  Future<void> _deleteChannel() async {
    final u = UiPalette.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: u.card,
        title: Text('Delete channel?', style: AppTheme.heading(size: 18, color: u.text)),
        content: Text('The channel and all its posts will be deleted for everyone. This cannot be undone.', style: AppTheme.body(color: u.subtext)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: TextStyle(color: u.subtext))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await AppwriteService.instance.deleteChannel(widget.channelId);
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      _snack(friendlyError(e));
    }
  }

  Widget _personRow(models.Document d, UiPalette u, {Widget? trailing, bool owner = false, bool admin = false}) {
    final name = (d.data['name'] ?? '').toString();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          TexterAvatar(name: name, url: (d.data['avatarUrl'] ?? '').toString(), size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                Flexible(child: Text(d.$id == _myId ? '$name (You)' : name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.body(size: 15, weight: FontWeight.w600, color: u.text))),
                const SizedBox(width: 8),
                if (owner) const TexterChip('Owner', color: AppTheme.pink) else if (admin) const TexterChip('Admin'),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final u = UiPalette.of(context);
    final c = _c;
    return Scaffold(
      appBar: AppBar(title: const Text('Channel info')),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: u.accent))
          : c == null
              ? Center(child: Text('Channel not found', style: AppTheme.body(color: u.subtext)))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 32),
                  children: [
                    // ---- header ----
                    Center(
                      child: Stack(
                        children: [
                          TexterAvatar(name: c.name, url: c.avatarUrl, size: 112, ring: true),
                          if (_isAdmin)
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
                    Center(child: Text(c.name, textAlign: TextAlign.center, style: AppTheme.heading(size: 23, color: u.text))),
                    const SizedBox(height: 4),
                    Center(child: Text('Channel · ${c.subscriberCount} followers', style: AppTheme.body(size: 13.5, color: u.subtext))),
                    if (c.description.trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Center(child: Text(c.description, textAlign: TextAlign.center, style: AppTheme.body(size: 14.5, color: u.text))),
                    ],
                    const SizedBox(height: 18),
                    if (!_isAdmin)
                      Center(
                        child: _isFollowing
                            ? OutlinedButton.icon(
                                onPressed: _busy ? null : _toggleFollow,
                                icon: const Icon(Icons.check_rounded),
                                label: const Text('Following'),
                              )
                            : GradientButton(label: 'Follow channel', icon: Icons.notifications_active_rounded, busy: _busy, onTap: _toggleFollow),
                      ),

                    // ---- admin tools ----
                    if (_isAdmin) ...[
                      const SectionLabel('Admin tools'),
                      TexterCard(children: [
                        TexterRow(
                          icon: Icons.edit_rounded,
                          title: 'Edit name & description',
                          trailing: Icon(Icons.chevron_right_rounded, color: u.subtext),
                          onTap: _editDetails,
                        ),
                        texterDivider(context),
                        TexterRow(
                          icon: Icons.add_a_photo_rounded,
                          title: 'Change channel photo',
                          color: AppTheme.pink,
                          trailing: Icon(Icons.chevron_right_rounded, color: u.subtext),
                          onTap: _changePhoto,
                        ),
                      ]),
                    ],

                    // ---- admins ----
                    const SectionLabel('Admins'),
                    TexterCard(children: [
                      for (var i = 0; i < _admins.length; i++) ...[
                        if (i > 0) texterDivider(context),
                        _personRow(
                          _admins[i],
                          u,
                          owner: _admins[i].$id == c.ownerId,
                          admin: _admins[i].$id != c.ownerId,
                          trailing: (_isOwner && _admins[i].$id != c.ownerId)
                              ? IconButton(
                                  tooltip: 'Remove admin',
                                  icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                                  onPressed: () => _removeAdmin(_admins[i].$id),
                                )
                              : null,
                        ),
                      ],
                      if (_isOwner) ...[
                        if (_admins.isNotEmpty) texterDivider(context),
                        TexterRow(icon: Icons.person_add_alt_1_rounded, title: 'Add admin', onTap: _addAdmin),
                      ],
                    ]),

                    // ---- followers (admins only, like WhatsApp: followers stay private from each other) ----
                    if (_isAdmin) ...[
                      SectionLabel('Followers · ${c.subscriberCount}'),
                      TexterCard(children: [
                        if (!_showFollowers)
                          TexterRow(
                            icon: Icons.groups_rounded,
                            title: 'Show followers',
                            subtitle: 'Only admins can see this list',
                            trailing: Icon(Icons.chevron_right_rounded, color: u.subtext),
                            onTap: () {
                              setState(() => _showFollowers = true);
                              _loadFollowers();
                            },
                          )
                        else if (_followersLoading)
                          Padding(padding: const EdgeInsets.all(18), child: Center(child: CircularProgressIndicator(color: u.accent)))
                        else if (_followers.isEmpty)
                          Padding(padding: const EdgeInsets.all(18), child: Text('No followers yet', style: AppTheme.body(color: u.subtext)))
                        else
                          for (var i = 0; i < _followers.length; i++) ...[
                            if (i > 0) texterDivider(context),
                            _personRow(
                              _followers[i],
                              u,
                              owner: _followers[i].$id == c.ownerId,
                              admin: c.adminIds.contains(_followers[i].$id) && _followers[i].$id != c.ownerId,
                              trailing: (_followers[i].$id != _myId && _followers[i].$id != c.ownerId)
                                  ? IconButton(
                                      tooltip: 'Remove follower',
                                      icon: Icon(Icons.person_remove_alt_1_rounded, color: u.subtext),
                                      onPressed: () => _removeFollower(_followers[i].$id, (_followers[i].data['name'] ?? '').toString()),
                                    )
                                  : null,
                            ),
                          ],
                      ]),
                    ],

                    // ---- leave / delete ----
                    const SizedBox(height: 22),
                    TexterCard(children: [
                      if (!_isOwner && _isFollowing)
                        TexterRow(
                          icon: Icons.logout_rounded,
                          title: 'Unfollow channel',
                          color: Colors.redAccent,
                          titleColor: Colors.redAccent,
                          onTap: _toggleFollow,
                        ),
                      if (_isOwner)
                        TexterRow(
                          icon: Icons.delete_forever_rounded,
                          title: 'Delete channel',
                          subtitle: 'Removes it for everyone',
                          color: Colors.redAccent,
                          titleColor: Colors.redAccent,
                          onTap: _deleteChannel,
                        ),
                    ]),
                  ],
                ),
    );
  }
}
