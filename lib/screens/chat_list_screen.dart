import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../config/theme.dart';
import '../services/appwrite_service.dart';
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

  // Selection Mode State (Telegram Style)
  final Set<String> _selectedChatIds = {};
  bool get _isSelectionMode => _selectedChatIds.isNotEmpty;

  // Day/Night mode animation state
  bool _isDayMode = false;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _load();
  }

  @override
  void dispose() {
    _sub?.close();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final user = await AppwriteService.instance.getCurrentUser();
    if (user == null) return;
    _myId = user.$id;
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
      final doc = await AppwriteService.instance.getUserDoc(otherId);
      final url = doc?.data['avatarUrl'] ?? '';
      if (!mounted) return;
      setState(() => _avatarCache[c.$id] = url);
    }
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

  void _deleteSelectedChats() {
    setState(() {
      _chats.removeWhere((c) => _selectedChatIds.contains(c.$id));
      _selectedChatIds.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Selected chats deleted'), backgroundColor: AppTheme.surfaceLight),
    );
  }

  void _toggleDayNightMode() {
    setState(() {
      _isDayMode = !_isDayMode;
      if (_isDayMode) {
        _animController.forward();
      } else {
        _animController.reverse();
      }
    });
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
        backgroundColor: AppTheme.surface,
        title: Text('About Texter', style: AppTheme.heading(size: 18, color: Colors.white)),
        content: Text(
          'Texter is a secure, real-time messaging application designed for seamless communication.\n\nVersion: 1.0.0',
          style: AppTheme.body(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: AppTheme.cyan)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _chats.where((c) {
      final name = (c.data['chatName'] ?? '').toString().toLowerCase();
      return name.contains(_query.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: _isSelectionMode
          ? AppBar(
              backgroundColor: AppTheme.surface,
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _selectedChatIds.clear()),
              ),
              title: Text('${_selectedChatIds.length}', style: AppTheme.heading(size: 18, color: Colors.white)),
              actions: [
                IconButton(
                  icon: const Icon(Icons.push_pin_outlined),
                  onPressed: () => setState(() => _selectedChatIds.clear()),
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
                  color: AppTheme.surface,
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
                            style: AppTheme.body(color: Colors.white, size: 14),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'profile',
                      child: Row(
                        children: [
                          const Icon(Icons.person_outline, color: Colors.white70, size: 20),
                          const SizedBox(width: 12),
                          Text('Profile', style: AppTheme.body(color: Colors.white, size: 14)),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'about',
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.white70, size: 20),
                          const SizedBox(width: 12),
                          Text('About', style: AppTheme.body(color: Colors.white, size: 14)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
      body: RefreshIndicator(
        onRefresh: _load,
        backgroundColor: AppTheme.surface,
        color: AppTheme.cyan,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                style: AppTheme.body(color: Colors.white),
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
                              Text('No chats yet', style: AppTheme.body(size: 15, color: AppTheme.textSecondary)),
                              const SizedBox(height: 20),
                              GestureDetector(
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
                      : ListView.separated(
                          padding: EdgeInsets.zero,
                          itemCount: filtered.length,
                          separatorBuilder: (context, index) => const Divider(
                            color: Color(0xFF1E222B),
                            height: 1,
                            indent: 76, // Telegram style: divider starts after the avatar
                            endIndent: 16,
                          ),
                          itemBuilder: (context, i) {
                            final c = filtered[i];
                            final name = c.data['chatName'] ?? '';
                            final avatarUrl = _avatarCache[c.$id] ?? '';
                            final isSelected = _selectedChatIds.contains(c.$id);

                            final bool isPinned = c.data['isPinned'] ?? false;
                            final int unreadCount = c.data['unreadCount'] ?? 0;

                            return Dismissible(
                              key: Key(c.$id),
                              confirmDismiss: (direction) async {
                                if (direction == DismissDirection.startToEnd) {
                                  setState(() {
                                    _chats.removeWhere((item) => item.$id == c.$id);
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Chat archived'), backgroundColor: AppTheme.surfaceLight),
                                  );
                                  return false;
                                } else {
                                  return true;
                                }
                              },
                              background: Container(
                                alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.only(left: 20),
                                color: AppTheme.cyan,
                                child: const Icon(Icons.archive, color: Colors.black),
                              ),
                              secondaryBackground: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                color: Colors.redAccent,
                                child: const Icon(Icons.delete, color: Colors.white),
                              ),
                              onDismissed: (direction) {
                                setState(() {
                                  _chats.removeWhere((item) => item.$id == c.$id);
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Chat deleted'), backgroundColor: AppTheme.surfaceLight),
                                );
                              },
                              child: Container(
                                color: isSelected ? AppTheme.surfaceLight.withOpacity(0.5) : Colors.transparent,
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                  leading: Stack(
                                    children: [
                                      CircleAvatar(
                                        radius: 24,
                                        backgroundColor: AppTheme.surfaceLight,
                                        backgroundImage: avatarUrl.isNotEmpty ? CachedNetworkImageProvider(avatarUrl) : null,
                                        child: avatarUrl.isEmpty
                                            ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: AppTheme.heading(size: 16, color: Colors.white70))
                                            : null,
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
                                  title: Text(name, style: AppTheme.body(size: 16, weight: FontWeight.w600, color: Colors.white)),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 3),
                                    child: Text(
                                      c.data['lastMessage'] ?? '',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTheme.body(size: 13.5, color: AppTheme.textSecondary),
                                    ),
                                  ),
                                  trailing: Column(
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
                                          Text(_formatTime(c), style: AppTheme.body(size: 11.5, color: AppTheme.textSecondary)),
                                        ],
                                      ),
                                      const SizedBox(height: 5),
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
      floatingActionButton: _isSelectionMode
          ? null
          : FloatingActionButton(
              backgroundColor: AppTheme.pink,
              onPressed: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => const NewChatScreen()));
                _load();
              },
              child: const Icon(Icons.chat_bubble, color: Colors.white),
            ),
    );
  }
}
