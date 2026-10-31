import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:floaty_chatheads/floaty_chatheads.dart' show FloatyChatheads;
import 'chat_bubble.dart';
import 'package:texter_bubble/texter_bubble.dart';
import 'package:http/http.dart' as http;
import 'config/theme.dart';
import 'config/app_config.dart';
import 'services/appwrite_service.dart';
import 'services/ads_service.dart';
import 'services/theme_notifier.dart';
import 'services/net_utils.dart';
import 'screens/login_screen.dart';
import 'screens/main_nav_screen.dart';
import 'screens/verify_email_screen.dart';
import 'screens/one_to_one_chat_screen.dart';
import 'screens/group_chat_screen.dart';
import 'screens/channel_view_screen.dart';

/// Lets code outside the widget tree (notification-tap handlers) push a
/// screen without needing a BuildContext.
final navigatorKey = GlobalKey<NavigatorState>();

const String _notifyChannelId = 'texter_messages';
final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

/// Opens the exact chat/group/channel a push notification was about, the
/// moment someone taps it — whether the app was in the background or fully
/// killed. Reads the `chatId`/`kind`/`chatName` the Render push server put
/// in the notification's data payload.
void _openChatFromNotificationData(Map<String, dynamic> data) {
  final chatId = data['chatId'] as String?;
  final kind = data['kind'] as String?;
  final chatName = data['chatName'] as String? ?? '';
  if (chatId == null || chatId.isEmpty) return;

  final nav = navigatorKey.currentState;
  if (nav == null) return;

  Widget screen;
  switch (kind) {
    case 'group':
      screen = GroupChatScreen(groupId: chatId, groupName: chatName);
      break;
    case 'channel':
      screen = ChannelViewScreen(channelId: chatId);
      break;
    default:
      screen = OneToOneChatScreen(chatId: chatId, chatName: chatName);
  }
  nav.push(MaterialPageRoute(builder: (_) => screen));
}

/// Builds and shows the actual notification ourselves (title/body/grouping/
/// Reply+Mark-as-read buttons), from the data-only FCM payload the Render
/// server sends. Called for both foreground and background/killed states.
/// Multiple messages from the same chat share one `groupKey` (the chatId),
/// so Android stacks them into one expandable notification — WhatsApp/
/// Telegram style — instead of showing a separate one for each.
Future<void> _showChatNotification(Map<String, dynamic> data, {RemoteNotification? system}) async {
  final chatId = data['chatId'] as String? ?? '';
  final kind = data['kind'] as String? ?? 'direct';
  final senderId = data['senderId'] as String? ?? '';
  final senderName = data['senderName'] as String? ?? '';
  var title = (data['title'] as String?)?.trim() ?? '';
  if (title.isEmpty) title = senderName.trim();
  if (title.isEmpty) title = (system?.title ?? '').trim();
  var body = (data['body'] as String?)?.trim() ?? '';
  if (body.isEmpty) body = ((data['text'] as String?) ?? '').trim();
  if (body.isEmpty) body = (system?.body ?? '').trim();
  if (body.isEmpty) body = AppwriteService.previewFor((data['type'] as String?) ?? '', ''); // photo / video / file
  if (chatId.isEmpty) return;
  if (title.isEmpty && body.isEmpty) return; // nothing to show — never post a blank notification
  if (title.isEmpty) title = 'New message';
  if (body.isEmpty) body = 'New message';
  final chatName = (data['chatName'] as String?)?.trim().isNotEmpty == true ? data['chatName'] as String : title;

  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();

  // The same push can reach us twice (two registered devices / two isolates): show it once.
  final sig = '$chatId|$title|$body';
  final nowMs = DateTime.now().millisecondsSinceEpoch;
  if (prefs.getString('last_push_sig') == sig && nowMs - (prefs.getInt('last_push_at') ?? 0) < 4000) return;
  await prefs.setString('last_push_sig', sig);
  await prefs.setInt('last_push_at', nowMs);
  final countKey = 'unread_count_$chatId';
  final newCount = (prefs.getInt(countKey) ?? 0) + 1;
  await prefs.setInt(countKey, newCount);

  final payload = jsonEncode({'chatId': chatId, 'kind': kind, 'chatName': chatName, 'senderId': senderId});

  // Android 11+: WhatsApp-style — one conversation notification per chat
  // (with its recent messages), all chats grouped under one "Texter" summary.
  // Older Android keeps the per-chat grouping + summary as before.
  final bubblesOk = await TexterBubble.isSupported();

  var history = <Map<String, dynamic>>[];
  if (bubblesOk) {
    try {
      final raw = prefs.getString('msg_history_$chatId');
      if (raw != null) {
        history = (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (_) {}
    history.add({
      'text': body,
      'time': DateTime.now().millisecondsSinceEpoch,
      'sender': senderName.isNotEmpty ? senderName : title,
    });
    if (history.length > 8) history = history.sublist(history.length - 8);
    await prefs.setString('msg_history_$chatId', jsonEncode(history));
    final chats = prefs.getStringList('unread_chats') ?? <String>[];
    if (!chats.contains(chatId)) {
      chats.add(chatId);
      await prefs.setStringList('unread_chats', chats);
    }
  }

  final messageDetails = AndroidNotificationDetails(
    _notifyChannelId,
    'Messages',
    channelDescription: 'New message notifications',
    importance: Importance.high,
    priority: Priority.high,
    groupKey: bubblesOk ? _messagesGroupKey : chatId,
    actions: [
      const AndroidNotificationAction(
        'reply',
        'Reply',
        inputs: [AndroidNotificationActionInput(label: 'Type a message')],
      ),
      const AndroidNotificationAction('mark_read', 'Mark as read'),
    ],
  );
  final notifId = bubblesOk ? chatId.hashCode : DateTime.now().millisecondsSinceEpoch.remainder(100000);
  await _localNotifications.show(
    notifId,
    title,
    body,
    NotificationDetails(android: messageDetails),
    payload: payload,
  );

  if (!bubblesOk) {
    // Summary notification — required for Android to actually group the
    // individual ones together into one collapsed entry per chat.
    final summaryDetails = AndroidNotificationDetails(
      _notifyChannelId,
      'Messages',
      channelDescription: 'New message notifications',
      importance: Importance.high,
      priority: Priority.high,
      groupKey: chatId,
      setAsGroupSummary: true,
      styleInformation: const DefaultStyleInformation(true, true),
    );
    await _localNotifications.show(
      chatId.hashCode,
      chatName,
      newCount > 1 ? '$newCount new messages' : body,
      NotificationDetails(android: summaryDetails),
      payload: payload,
    );
    TexterBubble.dismissFcm();
    return;
  }

  // Real conversation notification: Bubble button, profile pic, message history.
  await TexterBubble.attach(
    id: notifId,
    chatId: chatId,
    kind: kind,
    chatName: chatName,
    senderName: senderName.isNotEmpty ? senderName : title,
    body: body,
    messages: history,
    avatarPath: prefs.getString('avatar_path_$chatId'),
  );
  await _refreshSummary(prefs);
  TexterBubble.dismissFcm();
}

const String _messagesGroupKey = 'texter_messages';
const int _summaryNotifId = 1;

/// The single "Texter — N new messages from M chats" entry that all chat
/// notifications collapse under (like WhatsApp). Silent: only the chat
/// notifications themselves make a sound.
Future<void> _refreshSummary(SharedPreferences prefs) async {
  final chats = prefs.getStringList('unread_chats') ?? <String>[];
  if (chats.isEmpty) {
    await _localNotifications.cancel(_summaryNotifId);
    return;
  }
  var total = 0;
  for (final c in chats) {
    total += prefs.getInt('unread_count_$c') ?? 0;
  }
  final details = AndroidNotificationDetails(
    _notifyChannelId,
    'Messages',
    channelDescription: 'New message notifications',
    importance: Importance.high,
    priority: Priority.high,
    groupKey: _messagesGroupKey,
    setAsGroupSummary: true,
    groupAlertBehavior: GroupAlertBehavior.children,
    onlyAlertOnce: true,
    styleInformation: const DefaultStyleInformation(true, true),
  );
  await _localNotifications.show(
    _summaryNotifId,
    'Texter',
    chats.length > 1 ? '$total new messages from ${chats.length} chats' : '$total new messages',
    NotificationDetails(android: details),
  );
}

/// Clears the unread-count used for the "N new messages" summary once the
/// chat has actually been opened or marked read.
Future<void> _clearChatNotificationState(String chatId) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  await prefs.remove('unread_count_$chatId');
  await prefs.remove('msg_history_$chatId');
  final chats = prefs.getStringList('unread_chats') ?? <String>[];
  if (chats.remove(chatId)) await prefs.setStringList('unread_chats', chats);
  await _localNotifications.cancel(chatId.hashCode);
  if (await TexterBubble.isSupported()) await _refreshSummary(prefs);
}

/// Authenticated REST call using the JWT AppwriteService.refreshJwt() keeps
/// in SharedPreferences — works from a background isolate with no Flutter
/// engine / no logged-in Dart session needed.
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

/// Sends a reply typed directly from the notification, without opening the
/// app. Falls back silently (notification just stays as-is) if the JWT has
/// expired — the person can still tap the notification itself to open the
/// chat and reply normally.
Future<void> _sendReplyFromNotification(String chatId, String text) async {
  if (text.trim().isEmpty) return;
  final headers = await _authHeaders();
  final prefs = await SharedPreferences.getInstance();
  final myId = prefs.getString('appwrite_user_id');
  if (headers == null || myId == null) return;
  try {
    await http.post(
      Uri.parse('${AppwriteConfig.endpoint}/databases/${AppwriteConfig.databaseId}/collections/${AppwriteConfig.messagesCollection}/documents'),
      headers: headers,
      body: jsonEncode({
        'documentId': 'unique()',
        'data': {'chatId': chatId, 'senderId': myId, 'message': text.trim(), 'mediaUrl': '', 'type': 'text'},
      }),
    );
  } catch (_) {}
}

/// Marks the chat read directly from the notification (removes this
/// device's user id from the chat document's `unreadFor` list).
Future<void> _markReadFromNotification(String chatId, String kind) async {
  if (kind != 'direct') return; // only 1:1 chats track unreadFor today
  final headers = await _authHeaders();
  final prefs = await SharedPreferences.getInstance();
  final myId = prefs.getString('appwrite_user_id');
  if (headers == null || myId == null) return;
  try {
    final getRes = await http.get(
      Uri.parse('${AppwriteConfig.endpoint}/databases/${AppwriteConfig.databaseId}/collections/${AppwriteConfig.chatsCollection}/documents/$chatId'),
      headers: headers,
    );
    if (getRes.statusCode != 200) return;
    final doc = jsonDecode(getRes.body) as Map<String, dynamic>;
    final current = (doc['unreadFor'] as String? ?? '').split(',').where((e) => e.isNotEmpty && e != myId).join(',');
    await http.patch(
      Uri.parse('${AppwriteConfig.endpoint}/databases/${AppwriteConfig.databaseId}/collections/${AppwriteConfig.chatsCollection}/documents/$chatId'),
      headers: headers,
      body: jsonEncode({'data': {'unreadFor': current}}),
    );
  } catch (_) {}
}

/// Handles a tap on the notification itself, or on one of its action
/// buttons (Reply / Mark as read) — including when the app is fully
/// killed, which is why this must be a top-level function.
@pragma('vm:entry-point')
void _notificationTapBackground(NotificationResponse response) {
  _handleNotificationResponse(response);
}

void _handleNotificationResponse(NotificationResponse response) {
  final raw = response.payload;
  if (raw == null || raw.isEmpty) return;
  Map<String, dynamic> data;
  try {
    data = jsonDecode(raw) as Map<String, dynamic>;
  } catch (_) {
    return;
  }
  final chatId = data['chatId'] as String? ?? '';
  final kind = data['kind'] as String? ?? 'direct';
  if (chatId.isEmpty) return;

  if (response.actionId == 'reply') {
    // Remove the notification once the reply is sent, otherwise Android keeps
    // showing the "sending" spinner on it forever.
    _sendReplyFromNotification(chatId, response.input ?? '').whenComplete(() {
      if (response.id != null) _localNotifications.cancel(response.id!);
      _clearChatNotificationState(chatId);
    });
    return;
  }
  if (response.actionId == 'mark_read') {
    _markReadFromNotification(chatId, kind);
    if (response.id != null) _localNotifications.cancel(response.id!);
    _clearChatNotificationState(chatId);
    return;
  }
  // Plain tap on the notification body — open the chat.
  _clearChatNotificationState(chatId);
  _openChatFromNotificationData(data);
}

/// Must be a top-level (or static) function — Firebase calls this in a
/// separate isolate when a push notification arrives while the app is fully
/// closed or in the background. Our pushes are data-only, so we build and
/// show the notification ourselves here (title/body/grouping/actions).
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await _showChatNotification(message.data, system: message.notification);
}

/// Errors that are harmless background noise (third-party SDK quirks and
/// "no internet" failures). They are ignored instead of replacing the whole
/// app with a red crash screen. Add a new pattern here if another appears.
bool _isKnownHarmlessError(Object error) {
  if (NetErr.isNetwork(error)) return true; // offline -> app keeps working from cache
  final message = error.toString();
  const knownPatterns = [
    'RealtimeResponse', // Appwrite realtime "pong" heartbeat parse bug
    'Map<dynamic, dynamic>',
    'Failed to load font',
    'fonts.gstatic.com',
    'HTTP request failed, statusCode: 404', // deleted image in storage
  ];
  return knownPatterns.any(message.contains);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // GoogleFonts wali line yahan se hata di gayi hai

  // 1. UI / Framework errors ko pakad kar screen par dikhane ke liye
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.dumpErrorToConsole(details);
    if (_isKnownHarmlessError(details.exception)) {
      debugPrint('Ignored known harmless UI error: ${details.exception}');
      return;
    }
    runApp(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: SingleChildScrollView(
                child: Text(
                  'CRASH ERROR (UI):\n${details.exception}\n\nStack Trace:\n${details.stack}',
                  style: const TextStyle(color: Colors.redAccent, fontSize: 14),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  };

  // 2. Asynchronous / Background errors ko pakad kar screen par dikhane ke liye
  runZonedGuarded(() async {
    try {
      ChatBubble.isBubbleEngine =
          (await const MethodChannel('texter/chat_intent').invokeMethod<bool>('isBubble')) ?? false;
    } catch (_) {}
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      // Our pushes are data-only (so we can show our own notification with
      // grouping + Reply/Mark-as-read), which means they never auto-display
      // in the foreground either — show them ourselves here too.
      if (!ChatBubble.isBubbleEngine) {
        FirebaseMessaging.onMessage.listen((message) {
          _showChatNotification(message.data, system: message.notification);
        });
      }

      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      await _localNotifications.initialize(
        const InitializationSettings(android: androidInit),
        onDidReceiveNotificationResponse: _handleNotificationResponse,
        onDidReceiveBackgroundNotificationResponse: _notificationTapBackground,
      );
      const channel = AndroidNotificationChannel(
        _notifyChannelId,
        'Messages',
        description: 'New message notifications',
        importance: Importance.high,
      );
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    } catch (e) {
      debugPrint("Firebase init error: $e");
    }

    try {
      await ThemeNotifier.load();
    } catch (e) {
      debugPrint("Theme load error: $e");
    }

    try {
      await AdsService.init();
    } catch (e) {
      debugPrint("Ads init error: $e");
    }

    runApp(const TexterApp());
  }, (error, stack) {
    if (_isKnownHarmlessError(error)) {
      debugPrint('Ignored known harmless async error: $error');
      return;
    }
    runApp(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: SingleChildScrollView(
                child: Text(
                  'CRASH ERROR (Async):\n$error\n\nStack Trace:\n$stack',
                  style: const TextStyle(color: Colors.redAccent, fontSize: 14),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  });
}

class TexterApp extends StatefulWidget {
  const TexterApp({super.key});

  @override
  State<TexterApp> createState() => _TexterAppState();
}

class _TexterAppState extends State<TexterApp> with WidgetsBindingObserver {
  Timer? _jwtTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setOnline(true);
    _checkInitialNotification();
    _setupChatIntent();
  }

  /// App was fully closed and opened by tapping a notification (our own,
  /// built via flutter_local_notifications). Checked once at startup —
  /// waits for login to resolve first (via _AuthGate) so the chat screen
  /// opens on top of the real home screen, not a loading spinner.
  Future<void> _checkInitialNotification() async {
    try {
      final details = await _localNotifications.getNotificationAppLaunchDetails();
      if (details == null || !details.didNotificationLaunchApp) return;
      final response = details.notificationResponse;
      if (response == null) return;
      final user = await AppwriteService.instance.getCurrentUser();
      if (user == null) return; // not logged in — nothing to open
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleNotificationResponse(response);
      });
    } catch (_) {}
  }

  static const MethodChannel _chatChannel = MethodChannel('texter/chat_intent');
  StreamSubscription? _bubbleSub;

  /// Opens a chat the person picked by tapping the floating bubble.
  void _openChatFromBubble(Map<String, dynamic> data) {
    final chatId = data['chatId'] as String?;
    if (chatId == null || chatId.isEmpty) return;
    ChatBubble.hide();
    if (ChatBubble.activeChatId == chatId) return; // already on screen
    _openChatFromNotificationData(data);
  }

  Future<void> _setupChatIntent() async {
    _chatChannel.setMethodCallHandler((call) async {
      if (call.method == 'openChat' && call.arguments is Map) {
        _openChatFromBubble(Map<String, dynamic>.from(call.arguments as Map));
      }
    });
    try {
      _bubbleSub = FloatyChatheads.onData.listen((data) {
        if (data is Map && data['action'] == 'openChat') {
          _chatChannel.invokeMethod('bringToFront');
          _openChatFromBubble(Map<String, dynamic>.from(data));
        }
      });
    } catch (_) {}
    try {
      // App was closed and got started by tapping the bubble.
      final pending = await _chatChannel.invokeMethod('getPendingChat');
      if (pending is Map) {
        final user = await AppwriteService.instance.getCurrentUser();
        if (user == null) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _openChatFromBubble(Map<String, dynamic>.from(pending));
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _bubbleSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _setOnline(false);
    _jwtTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (ChatBubble.isBubbleEngine) return; // bubble window must not flip online/offline
    // Like Telegram: online only while the app is open on screen.
    // `inactive` (notification shade, dialogs) is ignored; leaving the app = offline.
    if (state == AppLifecycleState.resumed) {
      _setOnline(true);
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _setOnline(false);
    }
  }

  Future<void> _setOnline(bool online) async {
    try {
      final user = await AppwriteService.instance.getCurrentUser();
      if (user != null) {
        try {
          await AppwriteService.instance.updateOnlineStatus(user.$id, online);
        } catch (_) {
          // one quick retry — the phone may be switching networks while it goes to background
          await Future.delayed(const Duration(seconds: 1));
          await AppwriteService.instance.updateOnlineStatus(user.$id, online);
        }
        if (online) {
          AppwriteService.instance.registerPushTarget();
          AppwriteService.instance.listenForTokenRefresh();
          AppwriteService.instance.refreshJwt();
          // JWT expires every 15 min — keep it fresh while the app is open
          // so notification Reply/Mark-as-read keep working.
          _jwtTimer ??= Timer.periodic(const Duration(minutes: 10), (_) => AppwriteService.instance.refreshJwt());
        }
      }
    } catch (e) {
      debugPrint("Online status error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeNotifier.mode,
      builder: (context, mode, _) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          title: 'Texter',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dayTheme,
          darkTheme: AppTheme.dark,
          themeMode: mode,
          home: const _AuthGate(),
        );
      },
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: AppwriteService.instance.getCurrentUser(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Agar FutureBuilder ke andar koi error aaye toh use bhi screen par dikhayein
        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: Colors.black,
            body: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: SingleChildScrollView(
                  child: Text(
                    'AuthGate Error:\n${snapshot.error}',
                    style: const TextStyle(color: Colors.redAccent, fontSize: 14),
                  ),
                ),
              ),
            ),
          );
        }

        final user = snapshot.data;
        if (user == null) return const LoginScreen();
        if (!user.emailVerification) return const VerifyEmailScreen();
        return const MainNavScreen();
      },
    );
  }
}
