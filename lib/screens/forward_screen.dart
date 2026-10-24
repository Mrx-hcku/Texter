import 'package:flutter/material.dart';
import 'package:appwrite/models.dart' as models;
import '../config/theme.dart';
import '../services/appwrite_service.dart';
import '../models/models.dart';

/// What's being forwarded — just the content, not tied to any one chat.
class ForwardPayload {
  final String text;
  final String attachmentUrl;
  final String attachmentType;
  const ForwardPayload({required this.text, this.attachmentUrl = '', this.attachmentType = ''});
}

/// WhatsApp/Telegram style "Forward to..." picker: lists the person's direct
/// chats, groups, and channels; tapping one immediately sends the message
/// there (marked as forwarded) and confirms.
class ForwardScreen extends StatefulWidget {
  final ForwardPayload payload;
  const ForwardScreen({super.key, required this.payload});

  @override
  State<ForwardScreen> createState() => _ForwardScreenState();
}

class _ForwardScreenState extends State<ForwardScreen> {
  bool _loading = true;
  String? _myId;
  List<models.Document> _chats = [];
  List<models.Document> _groups = [];
  List<models.Document> _channels = [];
  final Map<String, String> _otherNameCache = {};
  String? _sendingToId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = await AppwriteService.instance.getCurrentUser();
    _myId = user?.$id;
    if (_myId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final results = await Future.wait([
        AppwriteService.instance.getChats(_myId!),
        AppwriteService.instance.getGroups(),
        AppwriteService.instance.getChannels(),
      ]);
      _chats = results[0];
      _groups = results[1];
      _channels = results[2];

      // Resolve display names for direct chats (same fix as the main chat
      // list — never trust the chat doc's static chatName for 1:1s).
      for (final c in _chats) {
        if (c.data['isGroup'] == true) continue;
        final ids = (c.data['participantIds'] as String? ?? '').split(',').where((e) => e.isNotEmpty).toList();
        final otherId = ids.firstWhere((id) => id != _myId, orElse: () => '');
        if (otherId.isEmpty) continue;
        final doc = await AppwriteService.instance.getUserDoc(otherId);
        final name = doc?.data['name'] as String?;
        if (name != null && name.isNotEmpty) _otherNameCache[c.$id] = name;
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _forwardTo({required String chatId}) async {
    if (_myId == null || _sendingToId != null) return;
    setState(() => _sendingToId = chatId);
    try {
      await AppwriteService.instance.sendMessage(
        chatId: chatId,
        senderId: _myId!,
        text: widget.payload.text,
        attachmentUrl: widget.payload.attachmentUrl,
        attachmentType: widget.payload.attachmentType,
        isForwarded: true,
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Forwarded')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _sendingToId = null);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to forward: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Forward to...')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.cyan))
          : ListView(
              children: [
                if (_chats.isNotEmpty) _sectionHeader('Chats'),
                ..._chats.map((c) {
                  final isGroupFlag = c.data['isGroup'] == true;
                  final name = isGroupFlag ? (c.data['chatName'] ?? '') : (_otherNameCache[c.$id] ?? c.data['chatName'] ?? '');
                  return _tile(name: name, id: c.$id, icon: Icons.person);
                }),
                if (_groups.isNotEmpty) _sectionHeader('Groups'),
                ..._groups.map((g) => _tile(name: g.data['name'] ?? '', id: g.$id, icon: Icons.group)),
                if (_channels.isNotEmpty) _sectionHeader('Channels'),
                ..._channels.map((c) => _tile(name: c.data['name'] ?? '', id: c.$id, icon: Icons.campaign)),
                if (_chats.isEmpty && _groups.isEmpty && _channels.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(child: Text('Nothing to forward to yet', style: AppTheme.body(color: AppTheme.textSecondary))),
                  ),
              ],
            ),
    );
  }

  Widget _sectionHeader(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
        child: Text(title, style: AppTheme.body(color: UiPalette.of(context).accent, weight: FontWeight.w600, size: 13)),
      );

  Widget _tile({required String name, required String id, required IconData icon}) {
    final u = UiPalette.of(context);
    final sending = _sendingToId == id;
    return ListTile(
      leading: CircleAvatar(backgroundColor: u.cardAlt, child: Icon(icon, color: u.accent, size: 18)),
      title: Text(name.isEmpty ? 'Unnamed' : name, style: AppTheme.body(color: u.text)),
      trailing: sending ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: u.accent)) : null,
      onTap: sending ? null : () => _forwardTo(chatId: id),
    );
  }
}
