import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import '../config/theme.dart';
import '../services/appwrite_service.dart';
import '../models/models.dart';
import 'group_chat_screen.dart';
import 'create_group_screen.dart';
import '../widgets/texter_ui.dart';

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
  int _tab = 0; // 0 = my groups, 1 = discover
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
      final result = await AppwriteService.instance.joinOrRequestGroup(groupId: g.id, userId: _myId!);
      if (!mounted) return;
      if (result == 'requested') {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request sent — an admin will approve you')));
        _load();
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => GroupChatScreen(groupId: g.id, groupName: g.name)),
      ).then((_) => _load());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not join: ${friendlyError(e)}')));
    } finally {
      if (mounted) setState(() => _joining.remove(g.id));
    }
  }

  void _openGroup(GroupModel g) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GroupChatScreen(groupId: g.id, groupName: g.name)),
    );
  }

  /// Pill switch: "My groups" | "Discover".
  Widget _switcher(UiPalette u, bool dark) {
    Widget chip(int i, String label, int count) {
      final sel = _tab == i;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _tab = i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: sel ? u.accent : Colors.transparent,
              borderRadius: BorderRadius.circular(26),
            ),
            child: Center(
              child: Text(
                '$label · $count',
                style: AppTheme.body(
                  size: 13,
                  weight: FontWeight.w700,
                  color: sel ? (dark ? Colors.black : Colors.white) : u.subtext,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(4, 8, 4, 14),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: u.cardAlt,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: u.border),
      ),
      child: Row(children: [
        chip(0, 'My groups', _myGroups.length),
        chip(1, 'Discover', _discoverGroups.length),
      ]),
    );
  }

  /// Every group gets its own colour family, a big watermark letter,
  /// member count and (for public groups you haven't joined) a Join button.
  Widget _groupCard(GroupModel g, {required bool isMember, required bool dark}) {
    final colors = NameTint.gradient(g.name, dark);
    final ink = dark ? Colors.white : const Color(0xFF1C262B);
    final inkSoft = ink.withOpacity(0.7);
    final joining = _joining.contains(g.id);
    final requested = _myId != null && g.pendingIds.contains(_myId);
    final btnText = dark ? Colors.black : Colors.white;
    return GestureDetector(
      onTap: isMember ? () => _openGroup(g) : null,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: dark ? Colors.white10 : Colors.black12),
        ),
        child: Stack(
          children: [

            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      TexterAvatar(name: g.name, url: g.avatarUrl, size: 40),
                      const Spacer(),
                      if (!g.isPublic) Icon(Icons.lock_rounded, size: 16, color: inkSoft),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    g.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.body(size: 16, weight: FontWeight.w700, color: ink),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.people_alt_rounded, size: 14, color: inkSoft),
                      const SizedBox(width: 4),
                      Text('${g.memberIds.length} members', style: AppTheme.body(size: 12, color: inkSoft)),
                    ],
                  ),
                  if (!isMember) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 34,
                      child: ElevatedButton(
                        onPressed: (joining || requested) ? null : () => _join(g),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(0, 34),
                          padding: EdgeInsets.zero,
                          backgroundColor: ink,
                          foregroundColor: btnText,
                        ),
                        child: joining
                            ? SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2, color: btnText))
                            : Text(requested ? 'Requested' : 'Join'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _createCard(UiPalette u) {
    return GestureDetector(
      onTap: () async {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateGroupScreen()));
        _load();
      },
      child: Container(
        decoration: BoxDecoration(
          color: u.accent.withOpacity(0.07),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: u.accent.withOpacity(0.5), width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline_rounded, size: 36, color: u.accent),
            const SizedBox(height: 8),
            Text('New group', style: AppTheme.body(size: 14, weight: FontWeight.w700, color: u.accent)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final u = UiPalette.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final showMine = _tab == 0;
    final list = showMine ? _myGroups : _discoverGroups;
    final cards = <Widget>[
      if (showMine) _createCard(u),
      ...list.map((g) => _groupCard(g, isMember: showMine, dark: dark)),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Groups'),
        actions: [IconButton(icon: const Icon(Icons.add), onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateGroupScreen()));
          _load();
        })],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: u.accent))
          : RefreshIndicator(
              onRefresh: _load,
              backgroundColor: u.card,
              color: u.accent,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                children: [
                  _switcher(u, dark),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.78,
                    padding: const EdgeInsets.fromLTRB(4, 0, 4, 24),
                    children: cards,
                  ),
                  if (!showMine && list.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: Center(child: Text('No public groups to discover right now', style: AppTheme.body(color: u.subtext))),
                    ),
                ],
              ),
            ),
    );
  }
}
