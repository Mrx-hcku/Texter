import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:floaty_chatheads/floaty_chatheads.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config/theme.dart';
// ignore: unused_import
import 'chathead_overlay.dart'; // keeps the overlay entry point in the build

/// Telegram-style chat bubble: appears by itself when you leave the app
/// from an open chat, disappears when you come back. Tapping it opens
/// the app straight into that chat (see chathead_overlay.dart).
class ChatBubble {
  /// Chat currently open on screen (so a bubble tap doesn't open it twice).
  static String? activeChatId;

  /// True inside the Android notification-bubble window (BubbleActivity).
  /// That copy of the app must not create floating bubbles or duplicate
  /// notifications.
  static bool isBubbleEngine = false;

  /// Saves the chat partner's profile picture on the phone so bubbles
  /// (floating + notification) can show it, even when the app is closed.
  static Future<void> cacheAvatar(String chatId, Map<String, dynamic> userData) async {
    try {
      String? url;
      for (final key in const [
        'avatarUrl', 'avatar', 'photoUrl', 'photo', 'profilePic', 'profilePicture',
        'profileImage', 'profileUrl', 'profilePhoto', 'imageUrl', 'image', 'pic', 'dp',
      ]) {
        final v = userData[key];
        if (v is String && v.startsWith('http')) {
          url = v;
          break;
        }
      }
      if (url == null) {
        for (final e in userData.entries) {
          final k = e.key.toLowerCase();
          final v = e.value;
          if (v is String &&
              v.startsWith('http') &&
              (k.contains('avatar') || k.contains('photo') || k.contains('pic') || k.contains('image') || k.contains('profile'))) {
            url = v;
            break;
          }
        }
      }
      if (url == null) return;
      final prefs = await SharedPreferences.getInstance();
      final dir = await getApplicationSupportDirectory();
      final file = File('${dir.path}/avatar_$chatId.img');
      if (prefs.getString('avatar_src_$chatId') == url && await file.exists()) return;
      final res = await http.get(Uri.parse(url));
      if (res.statusCode != 200 || res.bodyBytes.isEmpty) return;
      await file.writeAsBytes(res.bodyBytes);
      await prefs.setString('avatar_src_$chatId', url);
      await prefs.setString('avatar_path_$chatId', file.path);
    } catch (e) {
      debugPrint('Avatar cache error: $e');
    }
  }

  static Future<void> show({
    required String chatId,
    required String kind,
    required String chatName,
  }) async {
    try {
      if (!await FloatyChatheads.checkPermission()) return;
      final info = {'chatId': chatId, 'kind': kind, 'chatName': chatName};
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('bubble_chat', jsonEncode(info));
      if (!await FloatyChatheads.isActive()) {
        Widget icon = CircleAvatar(
          backgroundColor: AppTheme.cyan,
          child: Text(
            chatName.isNotEmpty ? chatName[0].toUpperCase() : '?',
            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
        );
        // Chat partner's profile picture, if we have it saved.
        try {
          final path = prefs.getString('avatar_path_$chatId');
          final root = WidgetsBinding.instance.rootElement;
          if (path != null && File(path).existsSync() && root != null) {
            final provider = FileImage(File(path));
            await precacheImage(provider, root);
            icon = CircleAvatar(backgroundImage: provider);
          }
        } catch (_) {}
        await FloatyChatheads.showChatHead(
          entryPoint: 'chatHeadOverlayMain',
          iconWidget: icon,
          notification: const NotificationConfig(title: 'Texter bubble is active'),
          sizePreset: ContentSizePreset.compact,
          persistOnAppClose: true,
        );
      }
      await FloatyChatheads.shareData(info);
    } catch (e) {
      debugPrint('Bubble show error: $e');
    }
  }

  static Future<void> hide() async {
    try {
      if (await FloatyChatheads.isActive()) {
        await FloatyChatheads.closeChatHead();
      }
    } catch (e) {
      debugPrint('Bubble hide error: $e');
    }
  }

  /// Asks for "Display over other apps" only once, the first time a chat opens.
  static Future<void> askPermissionOnce(BuildContext context) async {
    try {
      if (await FloatyChatheads.checkPermission()) return;
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('bubble_permission_asked') == true) return;
      await prefs.setBool('bubble_permission_asked', true);
      if (!context.mounted) return;
      final allow = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Chat bubbles'),
          content: const Text(
            'Allow "Display over other apps" so your chat stays as a floating bubble when you leave the app.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Not now')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Allow')),
          ],
        ),
      );
      if (allow == true) await FloatyChatheads.requestPermission();
    } catch (_) {}
  }
}

/// Put one of these in a chat screen: bubble shows when the app goes to
/// background, hides when the app comes back.
class ChatBubbleWatcher with WidgetsBindingObserver {
  ChatBubbleWatcher({required this.chatId, required this.kind, required this.chatName});
  final String chatId;
  final String kind;
  final String chatName;

  void start(BuildContext context) {
    ChatBubble.activeChatId = chatId;
    if (ChatBubble.isBubbleEngine) return; // inside a notification bubble: no floating bubble
    WidgetsBinding.instance.addObserver(this);
    ChatBubble.hide();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) ChatBubble.askPermissionOnce(context);
    });
  }

  void stop() {
    if (ChatBubble.activeChatId == chatId) ChatBubble.activeChatId = null;
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      ChatBubble.show(chatId: chatId, kind: kind, chatName: chatName);
    } else if (state == AppLifecycleState.resumed) {
      ChatBubble.hide();
    }
  }
}
