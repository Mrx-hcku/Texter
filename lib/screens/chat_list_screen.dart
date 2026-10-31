import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../config/theme.dart';
import '../services/appwrite_service.dart';
import '../services/theme_notifier.dart';
import '../services/local_db_service.dart';
import '../services/chat_state_service.dart';
import '../widgets/texter_ui.dart';
import 'one_to_one_chat_screen.dart';
import 'new_chat_screen.dart';
import 'privacy_screen.dart';
import 'profile_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> with SingleTickerProviderStateMixin {
  List<models.Document> _chats = [];
  String _query = '';
  bool _loading = true;
  String? _myId;
  RealtimeSubscription? _sub;
  final Map<String, String> _avatarCache = {};
  final Map<String, bool> _onlineCache = {};
  // 1:1 chat ka naam DB me ek hi static field (chatName) me save hota hai —
  // jisne bhi chat shuru ki thi, uske perspective se. Isliye dusra user jab
  // apni list kholta hai to usko apna hi naam dikh jata tha. Fix: har user
  // ke liye "doosre participant" ka naam live users-collection se nikalte
  // hain, group chats ke liye static chatName hi sahi hai (unchanged).
  final Map<String, String> _otherNameCache = {};
  final Map<String, String> _otherUserIdByChat = {};
  RealtimeSubscription? _userSub;

  // Selection Mode State (Telegram Style)
  final Set<String> _selectedChatIds = {};

  // Archive / delete-for-me (kept on this device, per account)
  final Set<String> _archivedIds = {};
  final Map<String, String> _deletedSnap = {};
  bool _viewArchived = false;
  List<String> _pinnedIds = [];
  int _filter = 0; // 0 = all, 1 = unread only
  bool get _isSelectionMode => _selectedChatIds.isNotEmpty;

  // Day/Night mode animation state
  bool _isDayMode = false;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _isDayMode = ThemeNotifier.isDay;
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: _isDayMode ? 1 : 0,
    );
    _load();
  }

  @override
  void dispose() {
    _sub?.close();
    _userSub?.close();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final user = await AppwriteService.instance.getCurrentUser();
    if (user == null) return;
    _myId = user.$id;
    await _loadLocalState();
    try {
      final chats = await AppwriteService.instance.getChats(user.$id);
      setState(() {
        _chats = chats;
        _loading = false;
      });
      _fetchAvatars(chats);
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
      _fetchAvatars([doc]);
    });
  }

  Future<void> _fetchAvatars(List<models.Document> chats) async {
    for (final c in chats) {
      if (_avatarCache.containsKey(c.$id) || _myId == null) continue;
      final ids = (c.data['participantIds'] as String? ?? '').split(',').where((e) => e.isNotEmpty).toList();
      final otherId = ids.firstWhere((id) => id != _myId, orElse: () => '');
      if (otherId.isEmpty) continue;
      _otherUserIdByChat[c.$id] = otherId;

      // 1) Cache se TURANT dikhao (koi network wait nahi) — WhatsApp/
      // Telegram isi tarah karte hain: pehle jo pata hai wo turant dikhao,
      // baad me silently sahi karo agar kuch badla ho. Isi se "1.5 second
      // baad sahi naam aana" wala flicker khatam hota hai.
      try {
        final cachedJson = await LocalDbService.instance.getCachedJson('user:$otherId');
        if (cachedJson != null && mounted) {
          final cachedMap = Map<String, dynamic>.from(cachedJson as Map);
          final cachedName = cachedMap['name'] as String?;
          setState(() {
            _avatarCache[c.$id] = cachedMap['avatarUrl'] ?? '';
            _onlineCache[c.$id] = cachedMap['online'] ?? false;
            if (cachedName != null && cachedName.isNotEmpty) {
              _otherNameCache[c.$id] = cachedName;
            }
          });
        }
      } catch (_) {}

      // 2) Background me network se refresh karo — silently update karo
      // agar kuch badla ho, bina kisi "flash"/flicker ke.
      AppwriteService.instance.getUserDoc(otherId).then((doc) {
        if (doc == null || !mounted) return;
        final url = doc.data['avatarUrl'] ?? '';
        final online = doc.data['online'] ?? false;
        final otherName = doc.data['name'] as String?;
        setState(() {
          _avatarCache[c.$id] = url;
          _onlineCache[c.$id] = online;
          if (otherName != null && otherName.isNotEmpty) {
            _otherNameCache[c.$id] = otherName;
          }
        });
      });
    }
    _userSub ??= AppwriteService.instance.subscribeToCollection('users', (doc, events) {
      final entry = _otherUserIdByChat.entries.firstWhere(
        (e) => e.value == doc.$id,
        orElse: () => const MapEntry('', ''),
      );
      if (entry.key.isEmpty || !mounted) return;
      setState(() {
        _onlineCache[entry.key] = doc.data['online'] ?? false;
        final newName = doc.data['name'] as String?;
        if (newName != null && newName.isNotEmpty) {
          _otherNameCache[entry.key] = newName;
        }
      });
    });
  }

  String _formatTime(models.Document c) {
    final raw = c.$updatedAt;
    try {
      return shortTime(DateTime.parse(raw));
    } catch (_) {
      return '';
    }
  }

  void _toggleSelect(String chatId) {
    setState(() {
      if (_selectedChatIds.contains(chatId)) {
        _selectedChatIds.remove(chatId);
      } else {
        _selectedChatIds.add(chatId);
      }
    });
  }

  Future<void> _loadLocalState() async {
    if (_myId == null) return;
    final a = await ChatStateService.instance.archived(_myId!);
    final d = await ChatStateService.instance.deleted(_myId!);
    final pins = await ChatStateService.instance.pinned(_myId!);
    if (!mounted) return;
    setState(() {
      _pinnedIds = pins;
      _archivedIds
        ..clear()
        ..addAll(a);
      _deletedSnap
        ..clear()
        ..addAll(d);
    });
  }

  /// A deleted chat stays hidden until something new arrives in it.
  bool _isHiddenByDelete(models.Document c) {
    final snap = _deletedSnap[c.$id];
    if (snap == null) return false;
    final unread = (c.data['unreadFor'] as String? ?? '').split(',').contains(_myId);
    return !unread && (c.data['lastMessage'] ?? '').toString() == snap;
  }

  List<models.Document> get _mainChats {
    final visible = _chats.where((c) => !_archivedIds.contains(c.$id) && !_isHiddenByDelete(c)).toList();
    final pinned = <models.Document>[];
    for (final id in _pinnedIds) {
      final i = visible.indexWhere((c) => c.$id == id);
      if (i >= 0) pinned.add(visible.removeAt(i));
    }
    return [...pinned, ...visible];
  }

  bool _hasUnread(models.Document c) =>
      _myId != null && (c.data['unreadFor'] as String? ?? '').split(',').contains(_myId);

  Future<void> _pinSelected() async {
    if (_myId == null || _selectedChatIds.isEmpty) return;
    final ids = _selectedChatIds.toList();
    final allPinned = ids.every(_pinnedIds.contains);
    if (!allPinned) {
      final fresh = ids.where((i) => !_pinnedIds.contains(i)).length;
      if (_pinnedIds.length + fresh > 5) {
        _snack('You can pin up to 5 chats');
        return;
      }
    }
    for (final id in ids) {
      await ChatStateService.instance.setPinned(_myId!, id, !allPinned);
    }
    if (!mounted) return;
    setState(() {
      if (allPinned) {
        _pinnedIds.removeWhere(ids.contains);
      } else {
        for (final id in ids) {
          if (!_pinnedIds.contains(id)) _pinnedIds.add(id);
        }
      }
      _selectedChatIds.clear();
    });
    _snack(allPinned ? 'Unpinned' : 'Pinned to top');
  }

  List<models.Document> get _archivedChats =>
      _chats.where((c) => _archivedIds.contains(c.$id) && !_isHiddenByDelete(c)).toList();

  void _snack(String msg, {VoidCallback? onUndo}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: AppTheme.surfaceLight,
        action: onUndo == null ? null : SnackBarAction(label: 'Undo', textColor: AppTheme.cyan, onPressed: onUndo),
      ));
  }

  Future<void> _setArchived(List<String> ids, bool archived, {bool withUndo = true}) async {
    if (_myId == null || ids.isEmpty) return;
    for (final id in ids) {
      await ChatStateService.instance.setArchived(_myId!, id, archived);
    }
    if (!mounted) return;
    setState(() {
      if (archived) {
        _archivedIds.addAll(ids);
      } else {
        _archivedIds.removeAll(ids);
      }
      _selectedChatIds.clear();
    });
    final n = ids.length;
    _snack(
      archived ? (n > 1 ? '$n chats archived' : 'Chat archived') : (n > 1 ? '$n chats unarchived' : 'Chat unarchived'),
      onUndo: withUndo ? () => _setArchived(ids, !archived, withUndo: false) : null,
    );
  }

  Future<bool> _confirmDelete(int count) async {
    final u = UiPalette.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: u.card,
        title: Text(count > 1 ? 'Delete $count chats?' : 'Delete chat?', style: AppTheme.heading(size: 18, color: u.text)),
        content: Text(
          'Messages are cleared from your side only — the other person keeps their copy. The chat comes back if someone sends a new message.',
          style: AppTheme.body(color: u.subtext),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: TextStyle(color: u.subtext))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _deleteChats(List<String> ids) async {
    if (_myId == null || ids.isEmpty) return;
    for (final id in ids) {
      final i = _chats.indexWhere((c) => c.$id == id);
      final last = i >= 0 ? (_chats[i].data['lastMessage'] ?? '').toString() : '';
      await ChatStateService.instance.markDeleted(_myId!, id, last);
      await ChatStateService.instance.setArchived(_myId!, id, false);
      _deletedSnap[id] = last;
      try {
        await LocalDbService.instance.cacheMessages(id, const []);
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _archivedIds.removeAll(ids);
      _selectedChatIds.clear();
    });
    final n = ids.length;
    _snack(
      n > 1 ? '$n chats deleted' : 'Chat deleted',
      onUndo: () async {
        for (final id in ids) {
          await ChatStateService.instance.undoDelete(_myId!, id);
          _deletedSnap.remove(id);
        }
        if (mounted) setState(() {});
      },
    );
  }

  Future<void> _deleteSelectedChats() async {
    final ids = _selectedChatIds.toList();
    if (ids.isEmpty) return;
    if (await _confirmDelete(ids.length)) {
      await _deleteChats(ids);
    }
  }

  Widget _filterChip(String label, int count, int idx, UiPalette u) {
    final sel = _filter == idx;
    return GestureDetector(
      onTap: () => setState(() => _filter = idx),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: sel ? u.accent : u.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: sel ? u.accent : u.border),
        ),
        child: Text(
          count > 0 ? '$label · $count' : label,
          style: AppTheme.body(
            size: 13,
            weight: FontWeight.w700,
            color: sel ? (Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.white) : u.subtext,
          ),
        ),
      ),
    );
  }

  /// One chat row: photo (gradient ring when there is something new), name,
  /// last message, time, pin and a gradient "new" pill.
  Widget _chatTile({
    required models.Document c,
    required String name,
    required String avatarUrl,
    required bool selected,
    required bool pinned,
    required bool unread,
    required bool online,
    required UiPalette u,
  }) {
    final shownName = name.isEmpty ? 'Chat' : name;
    var last = (c.data['lastMessage'] ?? '').toString().trim().replaceAll('\n', ' ');
    if (last.isEmpty) last = c.$updatedAt != c.$createdAt ? '📎 Attachment' : 'Say hi 👋';
    final t = DateTime.tryParse(c.$updatedAt);
    return GestureDetector(
      onTap: () {
        if (_isSelectionMode) {
          _toggleSelect(c.$id);
        } else {
          Navigator.push(context, MaterialPageRoute(builder: (_) => OneToOneChatScreen(chatId: c.$id, chatName: shownName)));
        }
      },
      onLongPress: () => _toggleSelect(c.$id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
        decoration: BoxDecoration(
          color: selected ? u.accent.withOpacity(0.12) : u.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? u.accent : (unread ? u.accent.withOpacity(0.55) : u.border),
            width: (selected || unread) ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            Stack(
              children: [
                TexterAvatar(name: shownName, url: avatarUrl, size: 54, ring: unread),
                if (online)
                  Positioned(
                    right: 1,
                    bottom: 1,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(color: const Color(0xFF2ECC71), shape: BoxShape.circle, border: Border.all(color: u.card, width: 2.5)),
                    ),
                  ),
                if (selected)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(color: u.accent, shape: BoxShape.circle, border: Border.all(color: u.card, width: 2)),
                      child: const Icon(Icons.check, size: 13, color: Colors.white),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    shownName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.body(size: 16, weight: unread ? FontWeight.w800 : FontWeight.w600, color: u.text),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    last,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.body(
                      size: 13.5,
                      weight: unread ? FontWeight.w600 : FontWeight.w400,
                      color: unread ? u.text.withOpacity(0.85) : u.subtext,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  t == null ? '' : shortTime(t),
                  style: AppTheme.body(size: 11.5, weight: unread ? FontWeight.w700 : FontWeight.w400, color: unread ? u.accent : u.subtext),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (pinned)
                      Padding(
                        padding: EdgeInsets.only(right: unread ? 6 : 0),
                        child: Transform.rotate(angle: 0.785398, child: Icon(Icons.push_pin_rounded, size: 16, color: u.subtext)),
                      ),
                    if (unread)
                      Container(
                        constraints: const BoxConstraints(minWidth: 22),
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(11),
                          gradient: const LinearGradient(colors: kTexterGradient),
                        ),
                        child: const Text('1', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800)),
                      )
                    else if (!pinned)
                      const SizedBox(height: 18),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleDayNightMode() async {
    await ThemeNotifier.toggle();
    setState(() {
      _isDayMode = ThemeNotifier.isDay;
      if (_isDayMode) {
        _animController.forward();
      } else {
        _animController.reverse();
      }
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isDayMode ? 'Switched to Day Mode' : 'Switched to Night Mode'),
        duration: const Duration(milliseconds: 1200),
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: UiPalette.of(context).card,
        title: Text('About Texter', style: AppTheme.heading(size: 18, color: UiPalette.of(context).text)),
        content: Text(
          'Texter is a secure, real-time messaging application designed for seamless communication.\n\nVersion: 1.0.0',
          style: AppTheme.body(color: UiPalette.of(context).subtext),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: TextStyle(color: UiPalette.of(context).accent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final u = UiPalette.of(context);
    final archivedCount = _archivedChats.length;
    final baseList = _viewArchived ? _archivedChats : _mainChats;
    final unreadCount0 = _mainChats.where(_hasUnread).length;
    final filtered = baseList.where((c) {
      if (_filter == 1 && !_viewArchived && !_hasUnread(c)) return false;
      final name = (c.data['chatName'] ?? '').toString().toLowerCase();
      return name.contains(_query.toLowerCase());
    }).toList();

    return PopScope(
      canPop: !_viewArchived && !_isSelectionMode,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        setState(() {
          if (_isSelectionMode) {
            _selectedChatIds.clear();
          } else {
            _viewArchived = false;
          }
        });
      },
      child: Scaffold(
      appBar: _isSelectionMode
          ? AppBar(
              backgroundColor: u.card,
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _selectedChatIds.clear()),
              ),
              title: Text('${_selectedChatIds.length}', style: AppTheme.heading(size: 18, color: u.text)),
              actions: [
                if (!_viewArchived)
                  IconButton(
                    tooltip: _selectedChatIds.every(_pinnedIds.contains) ? 'Unpin' : 'Pin to top',
                    icon: Icon(_selectedChatIds.every(_pinnedIds.contains) ? Icons.push_pin : Icons.push_pin_outlined),
                    onPressed: _pinSelected,
                  ),
                IconButton(
                  tooltip: _viewArchived ? 'Unarchive' : 'Archive',
                  icon: Icon(_viewArchived ? Icons.unarchive_outlined : Icons.archive_outlined),
                  onPressed: () => _setArchived(_selectedChatIds.toList(), !_viewArchived),
                ),
                IconButton(
                  icon: const Icon(Icons.notifications_off_outlined),
                  onPressed: () => setState(() => _selectedChatIds.clear()),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _deleteSelectedChats,
                ),
              ],
            )
          : _viewArchived
              ? AppBar(
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => setState(() {
                      _viewArchived = false;
                      _query = '';
                    }),
                  ),
                  title: const Text('Archived chats'),
                )
              : AppBar(
              title: const Text('Texter'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PrivacyScreen()),
                  ),
                ),
                PopupMenuButton<String>(
                  color: u.card,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) {
                    if (value == 'theme') {
                      _toggleDayNightMode();
                    } else if (value == 'profile') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ProfileScreen()),
                      );
                    } else if (value == 'archived') {
                      setState(() {
                        _viewArchived = true;
                        _query = '';
                        _selectedChatIds.clear();
                      });
                    } else if (value == 'about') {
                      _showAboutDialog();
                    }
                  },
                  itemBuilder: (BuildContext context) => [
                    PopupMenuItem<String>(
                      value: 'theme',
                      child: Row(
                        children: [
                          RotationTransition(
                            turns: Tween(begin: 0.0, end: 1.0).animate(_animController),
                            child: Icon(
                              _isDayMode ? Icons.wb_sunny_outlined : Icons.nightlight_round,
                              color: AppTheme.cyan,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _isDayMode ? 'Switch to Night Mode' : 'Switch to Day Mode',
                            style: AppTheme.body(color: u.text, size: 14),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'profile',
                      child: Row(
                        children: [
                          Icon(Icons.person_outline, color: u.subtext, size: 20),
                          const SizedBox(width: 12),
                          Text('Profile', style: AppTheme.body(color: u.text, size: 14)),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'archived',
                      child: Row(
                        children: [
                          Icon(Icons.archive_outlined, color: u.subtext, size: 20),
                          const SizedBox(width: 12),
                          Text(
                            archivedCount > 0 ? 'Archived chats ($archivedCount)' : 'Archived chats',
                            style: AppTheme.body(color: u.text, size: 14),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'about',
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: u.subtext, size: 20),
                          const SizedBox(width: 12),
                          Text('About', style: AppTheme.body(color: u.text, size: 14)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
      body: RefreshIndicator(
        onRefresh: _load,
        backgroundColor: u.card,
        color: AppTheme.cyan,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                style: AppTheme.body(color: u.text),
                decoration: const InputDecoration(
                  hintText: 'Search',
                  prefixIcon: Icon(Icons.search, color: AppTheme.textSecondary),
                ),
              ),
            ),
            if (!_viewArchived)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    _filterChip('All', _mainChats.length, 0, u),
                    const SizedBox(width: 8),
                    _filterChip('Unread', unreadCount0, 1, u),
                  ],
                ),
              ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.cyan))
                  : filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.chat_bubble_outline, size: 56, color: AppTheme.textSecondary),
                              const SizedBox(height: 12),
                              Text(_viewArchived ? 'No archived chats' : 'No chats yet', style: AppTheme.body(size: 15, color: AppTheme.textSecondary)),
                              if (!_viewArchived) const SizedBox(height: 20),
                              if (!_viewArchived) GestureDetector(
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const NewChatScreen()),
                                  );
                                  _load();
                                },
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: AppTheme.pink,
                                    shape: BoxShape.circle,
                                  ),
                                  padding: const EdgeInsets.all(16),
                                  child: const Icon(Icons.add, color: Colors.white, size: 24),
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: filtered.length,
                          itemBuilder: (context, i) {
                            final c = filtered[i];
                            final bool isGroupChat = c.data['isGroup'] == true;
                            final name = isGroupChat
                                ? (c.data['chatName'] ?? '')
                                : (_otherNameCache[c.$id] ?? c.data['chatName'] ?? '');
                            final avatarUrl = _avatarCache[c.$id] ?? '';
                            final isSelected = _selectedChatIds.contains(c.$id);

                            final bool isPinned = _pinnedIds.contains(c.$id);
                            final unreadForList = (c.data['unreadFor'] as String? ?? '').split(',').where((e) => e.isNotEmpty).toList();
                            final bool hasUnread = _myId != null && unreadForList.contains(_myId);
                            final bool isOnline = _onlineCache[c.$id] == true;

                            return Dismissible(
                              key: Key(c.$id),
                              // Swipe right = archive / unarchive, swipe left = delete.
                              // Both are done by us (state + storage), so the row
                              // is never "dismissed" by the widget itself.
                              confirmDismiss: (direction) async {
                                if (direction == DismissDirection.startToEnd) {
                                  await _setArchived([c.$id], !_viewArchived);
                                } else {
                                  if (await _confirmDelete(1)) await _deleteChats([c.$id]);
                                }
                                return false;
                              },
                              background: Container(
                                alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.only(left: 20),
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color: u.accent,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(_viewArchived ? Icons.unarchive_outlined : Icons.archive_outlined, color: Colors.black),
                                    const SizedBox(width: 8),
                                    Text(_viewArchived ? 'Unarchive' : 'Archive',
                                        style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                              secondaryBackground: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                                    SizedBox(width: 8),
                                    Icon(Icons.delete_outline, color: Colors.white),
                                  ],
                                ),
                              ),
                              child: _chatTile(
                                c: c,
                                name: name.toString(),
                                avatarUrl: avatarUrl,
                                selected: isSelected,
                                pinned: isPinned,
                                unread: hasUnread,
                                online: isOnline,
                                u: u,
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: (_isSelectionMode || _viewArchived)
          ? null
          : FloatingActionButton(
              backgroundColor: AppTheme.pink,
              onPressed: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => const NewChatScreen()));
                _load();
              },
              child: const Icon(Icons.chat_bubble, color: Colors.white),
            ),
      ),
    );
  }
}
