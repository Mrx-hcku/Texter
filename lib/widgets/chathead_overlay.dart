import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:floaty_chatheads/floaty_chatheads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'config/theme.dart';
import 'config/app_config.dart';

/// Minimal floating chat window shown inside the chat-head overlay bubble.
/// This runs in its OWN Flutter engine (see floaty_chatheads docs) — it
/// cannot see any state from the main app's widget tree, so it re-reads
/// the JWT/user id the main app keeps refreshed in SharedPreferences and
/// talks to Appwrite directly over REST (no realtime subscription here,
/// kept deliberately simple — messages refresh when the bubble is opened).
@pragma('vm:entry-point')
void chatHeadOverlayMain() => FloatyOverlayApp.run(const _ChatHeadOverlay());

class _ChatHeadOverlay extends StatefulWidget {
  const _ChatHeadOverlay();
  @override
  State<_ChatHeadOverlay> createState() => _ChatHeadOverlayState();
}

class _ChatHeadOverlayState extends State<_ChatHeadOverlay> {
  String? _chatId;
  String _chatName = '';
  String? _myUserId;
  final List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    FloatyOverlay.setUp();
    _myId().then((id) {
      if (mounted) setState(() => _myUserId = id);
    });
    // Main app sends chatId/kind/chatName right after showChatHead().
    FloatyOverlay.onData.listen((data) {
      if (data is Map && data['chatId'] != null) {
        setState(() {
          _chatId = data['chatId'] as String?;
          _chatName = data['chatName'] as String? ?? '';
        });
        _loadMessages();
      }
    });
  }

  Future<Map<String, String>?> _authHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final jwt = prefs.getString('appwrite_jwt');
    if (jwt == null || jwt.isEmpty) return null;
    return {
      'X-Appwrite-Project': AppwriteConfig.projectId,
      'X-Appwrite-JWT': jwt,
      'Content-Type': 'application/json',
    };
  }

  Future<String?> _myId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('appwrite_user_id');
  }

  Future<void> _loadMessages() async {
    final chatId = _chatId;
    if (chatId == null) return;
    setState(() => _loading = true);
    final headers = await _authHeaders();
    if (headers == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      // Appwrite's REST API expects each query as a JSON-encoded object
      // (the same shape the SDK's Query.equal()/orderDesc()/limit()
      // helpers build internally) — not a function-call-style string.
      final queries = [
        jsonEncode({'method': 'equal', 'attribute': 'chatId', 'values': [chatId]}),
        jsonEncode({'method': 'orderDesc', 'attribute': '\$createdAt'}),
        jsonEncode({'method': 'limit', 'values': [20]}),
      ];
      final uri = Uri.parse(
        '${AppwriteConfig.endpoint}/databases/${AppwriteConfig.databaseId}/collections/${AppwriteConfig.messagesCollection}/documents',
      ).replace(queryParameters: {'queries[]': queries});
      final res = await http.get(uri, headers: headers);
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final docs = (body['documents'] as List).cast<Map<String, dynamic>>();
        setState(() {
          _messages
            ..clear()
            ..addAll(docs.reversed.map((d) => d));
        });
      }
    } catch (_) {
      // Offline, or JWT expired — the bubble just shows whatever it has
      // (nothing, the first time); person can still tap it to open the app.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    final chatId = _chatId;
    if (text.isEmpty || chatId == null) return;
    _controller.clear();
    final headers = await _authHeaders();
    final myId = await _myId();
    if (headers == null || myId == null) return;
    setState(() {
      _messages.add({'message': text, 'senderId': myId, '\$createdAt': DateTime.now().toIso8601String()});
    });
    try {
      await http.post(
        Uri.parse('${AppwriteConfig.endpoint}/databases/${AppwriteConfig.databaseId}/collections/${AppwriteConfig.messagesCollection}/documents'),
        headers: headers,
        body: jsonEncode({
          'documentId': 'unique()',
          'data': {'chatId': chatId, 'senderId': myId, 'message': text, 'mediaUrl': '', 'type': 'text'},
        }),
      );
    } catch (_) {
      // Reply failed to send (offline/expired JWT) — stays in the bubble's
      // local list but won't sync; person can open the app to retry.
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Material(
        color: AppTheme.surface,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              color: AppTheme.surfaceLight,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _chatName.isEmpty ? 'Chat' : _chatName,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 18),
                    onPressed: FloatyOverlay.closeOverlay,
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.cyan))
                  : ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: _messages.length,
                      itemBuilder: (context, i) {
                        final m = _messages[i];
                        final mine = _myUserId != null && m['senderId'] == _myUserId;
                        return Align(
                          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 2),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: mine ? AppTheme.cyan.withOpacity(0.25) : AppTheme.surfaceLight,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(m['message'] as String? ?? '', style: const TextStyle(color: Colors.white, fontSize: 13)),
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: const InputDecoration(
                        hintText: 'Message...',
                        hintStyle: TextStyle(color: AppTheme.textSecondary),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.send, color: AppTheme.cyan, size: 20), onPressed: _send),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
