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
      final dt = DateTime.parse(raw).toLocal();
      return DateFormat('HH:mm').format(dt);
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
    if (!mounted) return;
    setState(() {
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

  List<models.Document> get _mainChats =>
      _chats.where((c) => !_archivedIds.contains(c.$id) && !_isHiddenByDelete(c)).toList();

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
    final filtered = baseList.where((c) {
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

                            final bool isPinned = c.data['isPinned'] ?? false;
                            final unreadForList = (c.data['unreadFor'] as String? ?? '').split(',').where((e) => e.isNotEmpty).toList();
                            final bool hasUnread = _myId != null && unreadForList.contains(_myId);
                            final int unreadCount = hasUnread ? 1 : 0;
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
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color: isSelected ? u.cardAlt.withOpacity(0.7) : u.card,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: u.border),
                                ),
                                child: ListTile(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  leading: Stack(
                                    children: [
                                      CircleAvatar(
                                        radius: 22,
                                        backgroundColor: u.cardAlt,
                                        backgroundImage: avatarUrl.isNotEmpty ? CachedNetworkImageProvider(avatarUrl) : null,
                                        // Avatar file storage se delete/404 ho to bhi crash na ho,
                                        // silently ignore karke initial-letter fallback dikhta rahe.
                                        onBackgroundImageError: avatarUrl.isNotEmpty ? (_, __) {} : null,
                                        child: avatarUrl.isEmpty
                                            ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: AppTheme.heading(size: 15, color: u.subtext))
                                            : null,
                                      ),
                                      if (isOnline)
                                        Positioned(
                                          top: 0,
                                          right: 0,
                                          child: Container(
                                            width: 12,
                                            height: 12,
                                            decoration: BoxDecoration(
                                              color: Colors.greenAccent,
                                              shape: BoxShape.circle,
                                              border: Border.all(color: u.card, width: 2),
                                            ),
                                          ),
                                        ),
                                      if (unreadCount > 0 && !isSelected)
                                        Positioned(
                                          bottom: 0,
                                          right: 0,
                                          child: Container(
                                            width: 13,
                                            height: 13,
                                            decoration: BoxDecoration(
                                              color: AppTheme.cyan,
                                              shape: BoxShape.circle,
                                              border: Border.all(color: u.card, width: 2),
                                            ),
                                          ),
                                        ),
                                      if (isSelected)
                                        Positioned(
                                          bottom: 0,
                                          right: 0,
                                          child: Container(
                                            decoration: const BoxDecoration(
                                              color: AppTheme.cyan,
                                              shape: BoxShape.circle,
                                            ),
                                            padding: const EdgeInsets.all(2),
                                            child: const Icon(Icons.check, size: 14, color: Colors.black),
                                          ),
                                        ),
                                    ],
                                  ),
                                  title: Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTheme.body(size: 15, weight: FontWeight.w600, color: u.text),
                                  ),
                                  subtitle: Text(
                                    c.data['lastMessage'] ?? '',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTheme.body(size: 12.5, color: AppTheme.textSecondary),
                                  ),
                                  trailing: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (isPinned)
                                            const Padding(
                                              padding: EdgeInsets.only(right: 4),
                                              child: Icon(Icons.push_pin, size: 12, color: AppTheme.textSecondary),
                                            ),
                                          Text(_formatTime(c), style: AppTheme.body(size: 11, color: AppTheme.textSecondary)),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      if (unreadCount > 0)
                                        Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: const BoxDecoration(
                                            color: AppTheme.cyan,
                                            shape: BoxShape.circle,
                                          ),
                                          constraints: const BoxConstraints(
                                            minWidth: 20,
                                            minHeight: 20,
                                          ),
                                          child: Center(
                                            child: Text(
                                              unreadCount > 99 ? '99+' : '$unreadCount',
                                              style: const TextStyle(
                                                color: Colors.black,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  onTap: () {
                                    if (_isSelectionMode) {
                                      _toggleSelect(c.$id);
                                    } else {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => OneToOneChatScreen(chatId: c.$id, chatName: name)),
                                      );
                                    }
                                  },
                                  onLongPress: () => _toggleSelect(c.$id),
                                ),
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
