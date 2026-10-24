import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:floaty_chatheads/floaty_chatheads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// Telegram-style bubble: this overlay shows nothing of its own. Tapping the
/// bubble opens the Texter app straight into that chat, and the bubble goes
/// away. (Runs in its own Flutter engine, separate from the main app.)
@pragma('vm:entry-point')
void chatHeadOverlayMain() => FloatyOverlayApp.run(const _BubbleTapHandler());

class _BubbleTapHandler extends StatefulWidget {
  const _BubbleTapHandler();
  @override
  State<_BubbleTapHandler> createState() => _BubbleTapHandlerState();
}

class _BubbleTapHandlerState extends State<_BubbleTapHandler> {
  Map<String, dynamic>? _chat;
  bool _busy = false;
  final List<StreamSubscription> _subs = [];

  @override
  void initState() {
    super.initState();
    FloatyOverlay.setUp();
    _subs.add(FloatyOverlay.onData.listen((data) {
      if (data is Map && data['chatId'] != null) {
        _chat = Map<String, dynamic>.from(data);
      }
    }));
    _subs.add(FloatyOverlay.onTapped.listen((_) => _openChat()));
    _subs.add(FloatyOverlay.onExpanded.listen((_) => _openChat()));
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  Future<void> _openChat() async {
    if (_busy) return;
    _busy = true;
    Future.delayed(const Duration(seconds: 2), () => _busy = false);
    try {
      var chat = _chat;
      if (chat == null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.reload();
        final raw = prefs.getString('bubble_chat');
        if (raw != null) chat = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      }
      if (chat == null || chat['chatId'] == null) {
        await FloatyOverlay.closeOverlay();
        return;
      }
      final payload = {
        'action': 'openChat',
        'chatId': chat['chatId'],
        'kind': chat['kind'] ?? 'direct',
        'chatName': chat['chatName'] ?? '',
      };
      var opened = false;
      if (FloatyConnectionState.isMainAppConnected) {
        // App is still alive in the background — hand over directly.
        await FloatyOverlay.shareData(payload);
        opened = true;
      } else {
        // App was closed — start it through a deep link.
        final uri = Uri(scheme: 'texter', host: 'chat', queryParameters: {
          'chatId': '${payload['chatId']}',
          'kind': '${payload['kind']}',
          'chatName': '${payload['chatName']}',
        });
        try {
          opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
        } catch (_) {}
      }
      if (opened) {
        await Future.delayed(const Duration(milliseconds: 400));
        await FloatyOverlay.closeOverlay();
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
