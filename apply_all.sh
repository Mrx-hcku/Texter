mkdir -p $(dirname pubspec.yaml)
cat > pubspec.yaml << 'FILEEOF'
name: texter
description: Texter - Flutter messaging app
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  appwrite: ^13.0.0
  google_fonts: ^6.2.1
  image_picker: ^1.1.2
  provider: ^6.1.2
  intl: ^0.19.0
  cached_network_image: ^3.4.1
  unity_ads_plugin: ^0.3.20
  uuid: ^4.5.1
  file_picker: ^8.1.2
  url_launcher: ^6.3.1
  record: ^6.2.1
  audioplayers: ^6.1.0
  path_provider: ^2.1.4
  sqflite: ^2.4.1
  path: ^1.9.0
  shared_preferences: ^2.3.2

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0

flutter:
  uses-material-design: true
FILEEOF

mkdir -p $(dirname lib/config/app_config.dart)
cat > lib/config/app_config.dart << 'FILEEOF'
class AppwriteConfig {
  static const String endpoint = "https://sgp.cloud.appwrite.io/v1";
  static const String projectId = "6a8e7ddd00107e2b7857";
  static const String databaseId = "messgram_db";
  static const String bucketId = "texter_media";

  static const String usersCollection = "users";
  static const String chatsCollection = "chats";
  static const String messagesCollection = "messages";
  static const String groupsCollection = "groups";
  static const String channelsCollection = "channels";
  static const String adsCollection = "ads";
}

class UnityAdsConfig {
  static const String androidGameId = "YOUR_UNITY_ANDROID_GAME_ID";
  static const String interstitialPlacementId = "Interstitial_Android";
  static const bool testMode = true;
}
FILEEOF

mkdir -p $(dirname lib/config/theme.dart)
cat > lib/config/theme.dart << 'FILEEOF'
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Cyberpunk dark palette (night mode)
  static const Color bg = Color(0xFF0B0F14);
  static const Color surface = Color(0xFF141B22);
  static const Color surfaceLight = Color(0xFF1C2530);
  static const Color cyan = Color(0xFF00E5D4);
  static const Color pink = Color(0xFFFF3D6E);
  static const Color primary = cyan;
  static const Color textPrimary = Color(0xFFF2F6F7);
  static const Color textSecondary = Color(0xFF8A96A3);

  // Day/light palette
  static const Color dayBg = Color(0xFFF5F7F8);
  static const Color daySurface = Color(0xFFFFFFFF);
  static const Color daySurfaceLight = Color(0xFFECEFF1);
  static const Color dayTextPrimary = Color(0xFF14181D);
  static const Color dayTextSecondary = Color(0xFF6B7480);

  static TextStyle heading({double size = 20, Color? color, FontWeight weight = FontWeight.w700}) =>
      GoogleFonts.orbitron(fontSize: size, fontWeight: weight, color: color ?? cyan, letterSpacing: 0.2);

  static TextStyle body({double size = 14, Color? color, FontWeight weight = FontWeight.w400}) =>
      GoogleFonts.inter(fontSize: size, fontWeight: weight, color: color ?? textPrimary);

  static BoxDecoration glowBorder({Color color = cyan, double radius = 100}) => BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
        boxShadow: [BoxShadow(color: color.withOpacity(0.6), blurRadius: 8, spreadRadius: 1)],
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: cyan,
          primary: cyan,
          secondary: pink,
          brightness: Brightness.dark,
          surface: surface,
        ),
        scaffoldBackgroundColor: bg,
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
          titleLarge: GoogleFonts.orbitron(fontWeight: FontWeight.w700, color: cyan),
          titleMedium: GoogleFonts.orbitron(fontWeight: FontWeight.w600, color: cyan),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: bg,
          foregroundColor: cyan,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: GoogleFonts.orbitron(fontSize: 20, fontWeight: FontWeight.w700, color: cyan),
          surfaceTintColor: Colors.transparent,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: cyan,
            foregroundColor: bg,
            minimumSize: const Size.fromHeight(52),
            elevation: 0,
            textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: surfaceLight),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: cyan, width: 1.6),
          ),
          hintStyle: GoogleFonts.inter(color: textSecondary, fontSize: 14),
          labelStyle: GoogleFonts.inter(color: textSecondary, fontSize: 13),
        ),
        cardTheme: CardThemeData(
          color: surface,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: surface,
          indicatorColor: cyan.withOpacity(0.15),
          labelTextStyle: WidgetStateProperty.all(GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: cyan)),
          iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
                color: states.contains(WidgetState.selected) ? cyan : textSecondary,
              )),
          elevation: 0,
        ),
        dividerColor: surfaceLight,
      );

  static ThemeData get dayTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: cyan,
          primary: cyan,
          secondary: pink,
          brightness: Brightness.light,
          surface: daySurface,
        ),
        scaffoldBackgroundColor: dayBg,
        textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme).copyWith(
          titleLarge: GoogleFonts.orbitron(fontWeight: FontWeight.w700, color: dayTextPrimary),
          titleMedium: GoogleFonts.orbitron(fontWeight: FontWeight.w600, color: dayTextPrimary),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: daySurface,
          foregroundColor: dayTextPrimary,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: GoogleFonts.orbitron(fontSize: 20, fontWeight: FontWeight.w700, color: dayTextPrimary),
          surfaceTintColor: Colors.transparent,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: cyan,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(52),
            elevation: 0,
            textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: daySurfaceLight,
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: daySurfaceLight),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: cyan, width: 1.6),
          ),
          hintStyle: GoogleFonts.inter(color: dayTextSecondary, fontSize: 14),
          labelStyle: GoogleFonts.inter(color: dayTextSecondary, fontSize: 13),
        ),
        cardTheme: CardThemeData(
          color: daySurface,
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: daySurface,
          indicatorColor: cyan.withOpacity(0.15),
          labelTextStyle: WidgetStateProperty.all(GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: dayTextPrimary)),
          iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
                color: states.contains(WidgetState.selected) ? cyan : dayTextSecondary,
              )),
          elevation: 0,
        ),
        dividerColor: daySurfaceLight,
      );
}
FILEEOF

mkdir -p $(dirname lib/services/ads_service.dart)
cat > lib/services/ads_service.dart << 'FILEEOF'
import 'package:unity_ads_plugin/unity_ads_plugin.dart';
import '../config/app_config.dart';

class AdsService {
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    await UnityAds.init(
      gameId: UnityAdsConfig.androidGameId,
      testMode: UnityAdsConfig.testMode,
      onComplete: () {
        _initialized = true;
        UnityAds.load(placementId: UnityAdsConfig.interstitialPlacementId);
      },
      onFailed: (error, message) {},
    );
  }

  static void showInterstitial() {
    if (!_initialized) return;
    UnityAds.showVideoAd(
      placementId: UnityAdsConfig.interstitialPlacementId,
      onComplete: (placementId) => UnityAds.load(placementId: UnityAdsConfig.interstitialPlacementId),
      onFailed: (placementId, error, message) {},
    );
  }
}
FILEEOF

mkdir -p $(dirname lib/services/local_db_service.dart)
cat > lib/services/local_db_service.dart << 'FILEEOF'
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/models.dart';

class LocalDbService {
  LocalDbService._internal();
  static final LocalDbService instance = LocalDbService._internal();

  Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = join(await getDatabasesPath(), 'texter_cache.db');
    return openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE messages (
            id TEXT PRIMARY KEY,
            chatId TEXT,
            senderId TEXT,
            message TEXT,
            mediaUrl TEXT,
            type TEXT,
            createdAt TEXT
          )
        ''');
        await db.execute('CREATE INDEX idx_chatId ON messages(chatId)');
      },
    );
  }

  Future<void> cacheMessages(String chatId, List<MessageModel> messages) async {
    final database = await db;
    final batch = database.batch();
    for (final m in messages) {
      batch.insert('messages', _toRow(chatId, m), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> cacheMessage(String chatId, MessageModel m) async {
    final database = await db;
    await database.insert('messages', _toRow(chatId, m), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Map<String, dynamic> _toRow(String chatId, MessageModel m) => {
        'id': m.id,
        'chatId': chatId,
        'senderId': m.senderId,
        'message': m.text,
        'mediaUrl': m.attachmentUrl,
        'type': m.attachmentType.isNotEmpty ? m.attachmentType : 'text',
        'createdAt': m.createdAt.toIso8601String(),
      };

  Future<List<MessageModel>> getCachedMessages(String chatId) async {
    final database = await db;
    final rows = await database.query('messages', where: 'chatId = ?', whereArgs: [chatId], orderBy: 'createdAt ASC');
    return rows.map((r) {
      final type = (r['type'] as String?) ?? 'text';
      return MessageModel(
        id: r['id'] as String,
        chatId: r['chatId'] as String,
        senderId: r['senderId'] as String,
        text: (r['message'] as String?) ?? '',
        attachmentUrl: (r['mediaUrl'] as String?) ?? '',
        attachmentType: type == 'text' ? '' : type,
        createdAt: DateTime.tryParse((r['createdAt'] as String?) ?? '') ?? DateTime.now(),
      );
    }).toList();
  }
}
FILEEOF

mkdir -p $(dirname lib/services/theme_notifier.dart)
cat > lib/services/theme_notifier.dart << 'FILEEOF'
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Global, persisted light/dark mode switch. MaterialApp listens to
/// [mode] and rebuilds its ThemeData whenever it changes, so toggling
/// this actually switches the app's theme app-wide (not just a
/// decorative icon).
class ThemeNotifier {
  static final ValueNotifier<ThemeMode> mode = ValueNotifier(ThemeMode.dark);

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isDay = prefs.getBool('isDayMode') ?? false;
      mode.value = isDay ? ThemeMode.light : ThemeMode.dark;
    } catch (_) {}
  }

  static Future<void> toggle() async {
    final goingToDay = mode.value == ThemeMode.dark;
    mode.value = goingToDay ? ThemeMode.light : ThemeMode.dark;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isDayMode', goingToDay);
    } catch (_) {}
  }

  static bool get isDay => mode.value == ThemeMode.light;
}
FILEEOF

mkdir -p $(dirname lib/models/models.dart)
cat > lib/models/models.dart << 'FILEEOF'
class UserModel {
  final String id;
  final String name;
  final String email;
  final String avatarUrl;
  final String status;
  final bool online;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.avatarUrl = '',
    this.status = '',
    this.online = false,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) => UserModel(
        id: map['\$id'] ?? '',
        name: map['name'] ?? '',
        email: map['email'] ?? '',
        avatarUrl: map['avatarUrl'] ?? '',
        status: map['status'] ?? '',
        online: map['online'] ?? false,
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'email': email,
        'avatarUrl': avatarUrl,
        'status': status,
        'online': online,
      };
}

class ChatModel {
  final String id;
  final String type;
  final String name;
  final String avatarUrl;
  final List<String> participantIds;
  final String lastMessage;
  final String? lastMessageTime;

  ChatModel({
    required this.id,
    required this.type,
    required this.name,
    this.avatarUrl = '',
    required this.participantIds,
    this.lastMessage = '',
    this.lastMessageTime,
  });

  factory ChatModel.fromMap(Map<String, dynamic> map) => ChatModel(
        id: map['\$id'] ?? '',
        type: map['type'] ?? 'direct',
        name: map['name'] ?? '',
        avatarUrl: map['avatarUrl'] ?? '',
        participantIds: List<String>.from(map['participantIds'] ?? []),
        lastMessage: map['lastMessage'] ?? '',
        lastMessageTime: map['lastMessageTime'],
      );

  Map<String, dynamic> toMap() => {
        'type': type,
        'name': name,
        'avatarUrl': avatarUrl,
        'participantIds': participantIds,
        'lastMessage': lastMessage,
        'lastMessageTime': lastMessageTime,
      };
}

class MessageModel {
  final String id;
  final String chatId;
  final String senderId;
  final String text;
  final String attachmentUrl;
  final String attachmentType;
  final String status;
  final DateTime createdAt;

  MessageModel({
    required this.id,
    required this.chatId,
    required this.senderId,
    this.text = '',
    this.attachmentUrl = '',
    this.attachmentType = '',
    this.status = 'sent',
    required this.createdAt,
  });

  factory MessageModel.fromMap(Map<String, dynamic> map) => MessageModel(
        id: map['\$id'] ?? '',
        chatId: map['chatId'] ?? '',
        senderId: map['senderId'] ?? '',
        text: map['message'] ?? map['text'] ?? '',
        attachmentUrl: map['mediaUrl'] ?? map['attachmentUrl'] ?? '',
        attachmentType: (map['type'] == null || map['type'] == 'text') ? '' : map['type'],
        status: map['status'] ?? 'sent',
        createdAt: DateTime.tryParse(map['\$createdAt'] ?? '') ?? DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'chatId': chatId,
        'senderId': senderId,
        'text': text,
        'attachmentUrl': attachmentUrl,
        'attachmentType': attachmentType,
        'status': status,
      };
}

class GroupModel {
  final String id;
  final String name;
  final String description;
  final String avatarUrl;
  final List<String> memberIds;
  final List<String> adminIds;
  final bool isPublic;

  GroupModel({
    required this.id,
    required this.name,
    this.description = '',
    this.avatarUrl = '',
    this.memberIds = const [],
    this.adminIds = const [],
    this.isPublic = true,
  });

  factory GroupModel.fromMap(Map<String, dynamic> map) => GroupModel(
        id: map['\$id'] ?? '',
        name: map['name'] ?? '',
        description: map['description'] ?? '',
        avatarUrl: map['avatarUrl'] ?? '',
        memberIds: List<String>.from(map['memberIds'] ?? []),
        adminIds: List<String>.from(map['adminIds'] ?? []),
        isPublic: map['isPublic'] ?? true,
      );
}

class ChannelModel {
  final String id;
  final String name;
  final String description;
  final String avatarUrl;
  final int subscriberCount;
  final List<String> subscriberIds;

  ChannelModel({
    required this.id,
    required this.name,
    this.description = '',
    this.avatarUrl = '',
    this.subscriberCount = 0,
    this.subscriberIds = const [],
  });

  factory ChannelModel.fromMap(Map<String, dynamic> map) => ChannelModel(
        id: map['\$id'] ?? '',
        name: map['name'] ?? '',
        description: map['description'] ?? '',
        avatarUrl: map['avatarUrl'] ?? '',
        subscriberCount: map['subscriberCount'] ?? 0,
        subscriberIds: List<String>.from(map['subscriberIds'] ?? []),
      );
}

class AdModel {
  final String id;
  final String title;
  final String description;
  final String imageUrl;
  final String actionText;
  final String actionUrl;
  final String targetType;

  AdModel({
    required this.id,
    required this.title,
    this.description = '',
    this.imageUrl = '',
    this.actionText = 'Learn More',
    this.actionUrl = '',
    this.targetType = 'group',
  });

  factory AdModel.fromMap(Map<String, dynamic> map) => AdModel(
        id: map['\$id'] ?? '',
        title: map['title'] ?? '',
        description: map['description'] ?? '',
        imageUrl: map['bannerUrl'] ?? map['imageUrl'] ?? '',
        actionText: map['buttonText'] ?? map['actionText'] ?? 'Learn More',
        actionUrl: map['actionUrl'] ?? '',
        targetType: map['targetType'] ?? 'group',
      );
}
FILEEOF

mkdir -p $(dirname lib/widgets/sponsored_ad_card.dart)
cat > lib/widgets/sponsored_ad_card.dart << 'FILEEOF'
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/theme.dart';
import '../models/models.dart';

class SponsoredAdCard extends StatelessWidget {
  final AdModel ad;
  const SponsoredAdCard({super.key, required this.ad});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.pink.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(
              children: [
                const Icon(Icons.campaign, size: 14, color: AppTheme.pink),
                const SizedBox(width: 4),
                Text('SPONSORED', style: AppTheme.body(size: 11, weight: FontWeight.w700, color: AppTheme.pink)),
              ],
            ),
          ),
          if (ad.imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: CachedNetworkImage(
                  imageUrl: ad.imageUrl,
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(height: 150, color: AppTheme.surfaceLight),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ad.title, style: AppTheme.body(size: 15, weight: FontWeight.w700, color: Colors.white)),
                if (ad.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(ad.description, style: AppTheme.body(size: 12.5, color: AppTheme.textSecondary)),
                ],
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.pink, minimumSize: const Size.fromHeight(42)),
                    child: Text(ad.actionText),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
FILEEOF

mkdir -p $(dirname lib/main.dart)
cat > lib/main.dart << 'FILEEOF'
import 'package:flutter/material.dart';
import 'config/theme.dart';
import 'services/appwrite_service.dart';
import 'services/ads_service.dart';
import 'services/theme_notifier.dart';
import 'screens/login_screen.dart';
import 'screens/main_nav_screen.dart';
import 'screens/verify_email_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeNotifier.load();
  AdsService.init();
  runApp(const TexterApp());
}

class TexterApp extends StatefulWidget {
  const TexterApp({super.key});

  @override
  State<TexterApp> createState() => _TexterAppState();
}

class _TexterAppState extends State<TexterApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setOnline(true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _setOnline(false);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _setOnline(state == AppLifecycleState.resumed);
  }

  Future<void> _setOnline(bool online) async {
    final user = await AppwriteService.instance.getCurrentUser();
    if (user != null) {
      AppwriteService.instance.updateOnlineStatus(user.$id, online);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeNotifier.mode,
      builder: (context, mode, _) {
        return MaterialApp(
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
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final user = snapshot.data;
        if (user == null) return const LoginScreen();
        if (!user.emailVerification) return const VerifyEmailScreen();
        return const MainNavScreen();
      },
    );
  }
}
FILEEOF

mkdir -p $(dirname lib/screens/chat_list_screen.dart)
cat > lib/screens/chat_list_screen.dart << 'FILEEOF'
import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../config/theme.dart';
import '../services/appwrite_service.dart';
import '../services/theme_notifier.dart';
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
  final Map<String, String> _otherUserIdByChat = {};
  RealtimeSubscription? _userSub;

  // Selection Mode State (Telegram Style)
  final Set<String> _selectedChatIds = {};
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
      final doc = await AppwriteService.instance.getUserDoc(otherId);
      final url = doc?.data['avatarUrl'] ?? '';
      final online = doc?.data['online'] ?? false;
      if (!mounted) return;
      setState(() {
        _avatarCache[c.$id] = url;
        _onlineCache[c.$id] = online;
      });
    }
    _userSub ??= AppwriteService.instance.subscribeToCollection('users', (doc, events) {
      final entry = _otherUserIdByChat.entries.firstWhere(
        (e) => e.value == doc.$id,
        orElse: () => const MapEntry('', ''),
      );
      if (entry.key.isEmpty || !mounted) return;
      setState(() => _onlineCache[entry.key] = doc.data['online'] ?? false);
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

  void _deleteSelectedChats() {
    setState(() {
      _chats.removeWhere((c) => _selectedChatIds.contains(c.$id));
      _selectedChatIds.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Selected chats deleted'), backgroundColor: AppTheme.surfaceLight),
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
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: filtered.length,
                          itemBuilder: (context, i) {
                            final c = filtered[i];
                            final name = c.data['chatName'] ?? '';
                            final avatarUrl = _avatarCache[c.$id] ?? '';
                            final isSelected = _selectedChatIds.contains(c.$id);

                            final bool isPinned = c.data['isPinned'] ?? false;
                            final unreadForList = (c.data['unreadFor'] as String? ?? '').split(',').where((e) => e.isNotEmpty).toList();
                            final bool hasUnread = _myId != null && unreadForList.contains(_myId);
                            final int unreadCount = hasUnread ? 1 : 0;
                            final bool isOnline = _onlineCache[c.$id] == true;

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
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color: AppTheme.cyan,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(Icons.archive, color: Colors.black),
                              ),
                              secondaryBackground: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent,
                                  borderRadius: BorderRadius.circular(16),
                                ),
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
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color: isSelected ? AppTheme.surfaceLight.withOpacity(0.5) : AppTheme.surface,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: ListTile(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  leading: Stack(
                                    children: [
                                      CircleAvatar(
                                        radius: 22,
                                        backgroundColor: AppTheme.surfaceLight,
                                        backgroundImage: avatarUrl.isNotEmpty ? CachedNetworkImageProvider(avatarUrl) : null,
                                        child: avatarUrl.isEmpty
                                            ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: AppTheme.heading(size: 15, color: Colors.white70))
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
                                              border: Border.all(color: AppTheme.surface, width: 2),
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
                                              border: Border.all(color: AppTheme.surface, width: 2),
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
                                  title: Text(name, style: AppTheme.body(size: 15, weight: FontWeight.w600, color: Colors.white)),
                                  subtitle: Text(
                                    c.data['lastMessage'] ?? '',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTheme.body(size: 12.5, color: AppTheme.textSecondary),
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
FILEEOF

mkdir -p $(dirname lib/screens/one_to_one_chat_screen.dart)
cat > lib/screens/one_to_one_chat_screen.dart << 'FILEEOF'
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import '../config/theme.dart';
import '../services/appwrite_service.dart';
import '../services/local_db_service.dart';
import '../models/models.dart';

class OneToOneChatScreen extends StatefulWidget {
  final String chatId;
  final String chatName;
  const OneToOneChatScreen({super.key, required this.chatId, required this.chatName});

  @override
  State<OneToOneChatScreen> createState() => _OneToOneChatScreenState();
}

class _OneToOneChatScreenState extends State<OneToOneChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  List<MessageModel> _messages = [];
  String? _myId;
  RealtimeSubscription? _sub;
  bool _uploading = false;

  final _recorder = AudioRecorder();
  bool _recording = false;
  Duration _recordDuration = Duration.zero;

  final _player = AudioPlayer();
  String? _playingId;

  String? _otherUserId;
  bool _otherOnline = false;
  bool _otherTyping = false;
  RealtimeSubscription? _userSub;
  RealtimeSubscription? _typingSub;
  Timer? _typingDebounce;

  @override
  void initState() {
    super.initState();
    _init();
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playingId = null);
    });
  }

  Future<void> _init() async {
    final user = await AppwriteService.instance.getCurrentUser();
    _myId = user?.$id;

    if (_myId != null) {
      AppwriteService.instance.markChatRead(chatId: widget.chatId, userId: _myId!);
    }

    final cached = await LocalDbService.instance.getCachedMessages(widget.chatId);
    if (cached.isNotEmpty && mounted) {
      setState(() => _messages = cached);
    }

    try {
      final docs = await AppwriteService.instance.getMessages(widget.chatId);
      final fresh = docs.map((d) => MessageModel.fromMap(d.data..addAll({'\$id': d.$id, '\$createdAt': d.$createdAt}))).toList();
      await LocalDbService.instance.cacheMessages(widget.chatId, fresh);
      if (mounted) setState(() => _messages = fresh);
    } catch (_) {}

    _sub = AppwriteService.instance.subscribeToMessages(widget.chatId, (doc) {
      if (_messages.any((m) => m.id == doc.$id)) return;
      setState(() {
        final msg = MessageModel.fromMap(doc.data..addAll({'\$id': doc.$id, '\$createdAt': doc.$createdAt}));
        _messages.add(msg);
        LocalDbService.instance.cacheMessage(widget.chatId, msg);
      });
    });

    _resolveOtherUser();
  }

  Future<void> _resolveOtherUser() async {
    try {
      final chatDoc = await AppwriteService.instance.databases.getDocument(
        databaseId: 'messgram_db',
        collectionId: 'chats',
        documentId: widget.chatId,
      );
      final ids = (chatDoc.data['participantIds'] as String? ?? '').split(',').where((e) => e.isNotEmpty).toList();
      _otherUserId = ids.firstWhere((id) => id != _myId, orElse: () => '');
      if (_otherUserId != null && _otherUserId!.isNotEmpty) {
        final userDoc = await AppwriteService.instance.getUserDoc(_otherUserId!);
        if (mounted) setState(() => _otherOnline = userDoc?.data['online'] ?? false);

        _userSub = AppwriteService.instance.subscribeToCollection('users', (doc, events) {
          if (doc.$id != _otherUserId) return;
          if (!mounted) return;
          setState(() => _otherOnline = doc.data['online'] ?? false);
        });
      }

      _typingSub = AppwriteService.instance.subscribeToCollection('chats', (doc, events) {
        if (doc.$id != widget.chatId) return;
        final typingUsers = (doc.data['typingUsers'] as String? ?? '').split(',').where((e) => e.isNotEmpty).toList();
        final isTyping = _otherUserId != null && typingUsers.contains(_otherUserId);
        if (!mounted) return;
        setState(() => _otherTyping = isTyping);
      });
    } catch (_) {}
  }

  void _onTextChanged(String value) {
    if (_myId == null) return;
    AppwriteService.instance.setTyping(chatId: widget.chatId, userId: _myId!, isTyping: value.isNotEmpty);
    _typingDebounce?.cancel();
    _typingDebounce = Timer(const Duration(seconds: 3), () {
      AppwriteService.instance.setTyping(chatId: widget.chatId, userId: _myId!, isTyping: false);
    });
  }

  @override
  void dispose() {
    _sub?.close();
    _userSub?.close();
    _typingSub?.close();
    _typingDebounce?.cancel();
    if (_myId != null) {
      AppwriteService.instance.setTyping(chatId: widget.chatId, userId: _myId!, isTyping: false);
    }
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _myId == null) return;
    _controller.clear();
    try {
      final doc = await AppwriteService.instance.sendMessage(chatId: widget.chatId, senderId: _myId!, text: text);
      if (!_messages.any((m) => m.id == doc.$id)) {
        final msg = MessageModel.fromMap(doc.data..addAll({'\$id': doc.$id, '\$createdAt': doc.$createdAt}));
        setState(() => _messages.add(msg));
        LocalDbService.instance.cacheMessage(widget.chatId, msg);
      }
      _typingDebounce?.cancel();
      AppwriteService.instance.setTyping(chatId: widget.chatId, userId: _myId!, isTyping: false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send: $e')));
    }
  }

  Future<void> _sendMedia({required String path, required String fileName, required String type, String text = ''}) async {
    if (_myId == null) return;
    setState(() => _uploading = true);
    try {
      final url = await AppwriteService.instance.uploadFile(path, fileName);
      final doc = await AppwriteService.instance.sendMessage(
        chatId: widget.chatId,
        senderId: _myId!,
        text: text,
        attachmentUrl: url,
        attachmentType: type,
      );
      if (!_messages.any((m) => m.id == doc.$id)) {
        final msg = MessageModel.fromMap(doc.data..addAll({'\$id': doc.$id, '\$createdAt': doc.$createdAt}));
        setState(() => _messages.add(msg));
        LocalDbService.instance.cacheMessage(widget.chatId, msg);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to upload: $e')));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: source);
    if (file == null) return;
    await _sendMedia(path: file.path, fileName: file.name, type: 'image');
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(withData: false);
    if (result == null || result.files.single.path == null) return;
    await _sendMedia(path: result.files.single.path!, fileName: result.files.single.name, type: 'file', text: result.files.single.name);
  }

  Future<void> _startRecording() async {
    if (!await _recorder.hasPermission()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Microphone permission denied')));
      return;
    }
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(const RecordConfig(), path: path);
    setState(() {
      _recording = true;
      _recordDuration = Duration.zero;
    });
    _tickRecording();
  }

  Future<void> _tickRecording() async {
    while (_recording && mounted) {
      await Future.delayed(const Duration(seconds: 1));
      if (_recording && mounted) {
        setState(() => _recordDuration += const Duration(seconds: 1));
      }
    }
  }

  Future<void> _stopRecording({bool send = true}) async {
    final path = await _recorder.stop();
    setState(() => _recording = false);
    if (!send || path == null) return;
    final duration = '${_recordDuration.inMinutes}:${(_recordDuration.inSeconds % 60).toString().padLeft(2, '0')}';
    await _sendMedia(path: path, fileName: 'voice.m4a', type: 'voice', text: duration);
  }

  Future<void> _togglePlay(MessageModel m) async {
    if (_playingId == m.id) {
      await _player.pause();
      setState(() => _playingId = null);
    } else {
      await _player.play(UrlSource(m.attachmentUrl));
      setState(() => _playingId = m.id);
    }
  }

  Future<void> _openFile(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open file')));
    }
  }

  Widget _attachIcon(IconData icon, VoidCallback onTap, {Color? color}) {
    return IconButton(
      icon: Icon(icon, color: color ?? AppTheme.textSecondary, size: 22),
      onPressed: _uploading ? null : onTap,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.chatName),
            Text(
              _otherTyping ? 'typing...' : (_otherOnline ? 'online' : 'offline'),
              style: TextStyle(
                fontSize: 12,
                color: _otherTyping ? AppTheme.cyan : (_otherOnline ? Colors.greenAccent : AppTheme.textSecondary),
                fontWeight: _otherTyping ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [IconButton(icon: const Icon(Icons.more_vert), onPressed: () {})],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (context, i) {
                final m = _messages[i];
                final mine = m.senderId == _myId;
                Widget content;
                if (m.attachmentType == 'image' && m.attachmentUrl.isNotEmpty) {
                  content = ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(m.attachmentUrl, width: 200, fit: BoxFit.cover),
                  );
                } else if (m.attachmentType == 'voice' && m.attachmentUrl.isNotEmpty) {
                  content = Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(_playingId == m.id ? Icons.pause_circle : Icons.play_circle, color: mine ? Colors.white : AppTheme.cyan, size: 30),
                        onPressed: () => _togglePlay(m),
                        padding: EdgeInsets.zero,
                      ),
                      Text(m.text.isNotEmpty ? m.text : 'Voice', style: const TextStyle(color: Colors.white)),
                    ],
                  );
                } else if (m.attachmentType == 'file' && m.attachmentUrl.isNotEmpty) {
                  content = InkWell(
                    onTap: () => _openFile(m.attachmentUrl),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.insert_drive_file, color: mine ? Colors.white70 : AppTheme.cyan),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            m.text.isNotEmpty ? m.text : 'File',
                            style: const TextStyle(color: Colors.white, decoration: TextDecoration.underline),
                          ),
                        ),
                      ],
                    ),
                  );
                } else {
                  content = Text(m.text, style: const TextStyle(color: Colors.white));
                }
                return AnimatedAlign(
                  duration: const Duration(milliseconds: 200),
                  alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                    decoration: BoxDecoration(
                      color: mine ? const Color(0xFF1E222B) : AppTheme.surface,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(mine ? 16 : 4),
                        bottomRight: Radius.circular(mine ? 4 : 16),
                      ),
                      border: Border.all(color: const Color(0xFF2A2E39), width: 1),
                    ),
                    child: content,
                  ),
                );
              },
            ),
          ),
          if (_uploading) LinearProgressIndicator(minHeight: 2, color: AppTheme.cyan, backgroundColor: AppTheme.surface),
          if (_recording)
            Container(
              color: AppTheme.surface,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.fiber_manual_record, color: Colors.red, size: 14),
                  const SizedBox(width: 8),
                  Text(
                    '${_recordDuration.inMinutes}:${(_recordDuration.inSeconds % 60).toString().padLeft(2, '0')}',
                    style: AppTheme.body(color: Colors.white),
                  ),
                  const Spacer(),
                  TextButton(onPressed: () => _stopRecording(send: false), child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondary))),
                  TextButton(onPressed: () => _stopRecording(send: true), child: const Text('Send', style: TextStyle(color: AppTheme.cyan))),
                ],
              ),
            ),
          SafeArea(
            child: Container(
              color: Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E222B),
                        borderRadius: BorderRadius.circular(28),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: Row(
                        children: [
                          _attachIcon(Icons.camera_alt_outlined, () => _pickImage(ImageSource.camera)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              onChanged: _onTextChanged,
                              style: AppTheme.body(color: Colors.white),
                              decoration: const InputDecoration(
                                hintText: 'Message',
                                hintStyle: TextStyle(color: Colors.grey),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(vertical: 10),
                              ),
                            ),
                          ),
                          _attachIcon(Icons.camera_alt, () => _pickImage(ImageSource.gallery)),
                          _attachIcon(Icons.attach_file, _pickFile),
                          _attachIcon(Icons.mic, _startRecording, color: const Color(0xFF00E5FF)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 46,
                    height: 46,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFE91E63),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white, size: 20),
                      onPressed: _send,
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
FILEEOF

mkdir -p $(dirname lib/screens/group_chat_screen.dart)
cat > lib/screens/group_chat_screen.dart << 'FILEEOF'
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import '../config/theme.dart';
import '../services/appwrite_service.dart';
import '../services/local_db_service.dart';
import '../services/ads_service.dart';
import '../models/models.dart';
import '../widgets/sponsored_ad_card.dart';

class GroupChatScreen extends StatefulWidget {
  final String groupId;
  final String groupName;
  const GroupChatScreen({super.key, required this.groupId, required this.groupName});

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final _controller = TextEditingController();
  List<MessageModel> _messages = [];
  List<AdModel> _ads = [];
  String? _myId;
  bool _loading = true;
  bool _isAdmin = false;
  MessageModel? _pinnedMessage;
  final Map<String, String> _senderNames = {};
  RealtimeSubscription? _sub;
  bool _uploading = false;

  final _recorder = AudioRecorder();
  bool _recording = false;
  Duration _recordDuration = Duration.zero;
  String? _recordPath;

  final _player = AudioPlayer();
  String? _playingId;

  @override
  void initState() {
    super.initState();
    _init();
    AdsService.showInterstitial();
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playingId = null);
    });
  }

  @override
  void dispose() {
    _sub?.close();
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final user = await AppwriteService.instance.getCurrentUser();
    _myId = user?.$id;
    try {
      final groupDoc = await AppwriteService.instance.getGroupDoc(widget.groupId);
      final adminIds = List<String>.from(groupDoc.data['adminIds'] ?? []);
      _isAdmin = _myId != null && adminIds.contains(_myId);
      final pinnedId = groupDoc.data['pinnedMessageId'] as String?;
      if (pinnedId != null && pinnedId.isNotEmpty) {
        final pinnedDoc = await AppwriteService.instance.getMessageById(pinnedId);
        if (pinnedDoc != null) {
          _pinnedMessage = MessageModel.fromMap(pinnedDoc.data..addAll({'\$id': pinnedDoc.$id, '\$createdAt': pinnedDoc.$createdAt}));
        }
      }

      final cached = await LocalDbService.instance.getCachedMessages(widget.groupId);
      if (cached.isNotEmpty && mounted) {
        await _fetchSenderNames(cached);
        setState(() {
          _messages = cached;
          _loading = false;
        });
      }

      final msgDocs = await AppwriteService.instance.getMessages(widget.groupId);
      final adDocs = await AppwriteService.instance.getAds(targetType: 'group');
      final messages = msgDocs
          .map((d) => MessageModel.fromMap(d.data..addAll({'\$id': d.$id, '\$createdAt': d.$createdAt})))
          .toList();
      await _fetchSenderNames(messages);
      await LocalDbService.instance.cacheMessages(widget.groupId, messages);
      setState(() {
        _messages = messages;
        _ads = adDocs.map((d) => AdModel.fromMap(d.data..addAll({'\$id': d.$id}))).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load: $e')));
    }
    _sub ??= AppwriteService.instance.subscribeToMessages(widget.groupId, (doc) async {
      if (_messages.any((m) => m.id == doc.$id)) return;
      final msg = MessageModel.fromMap(doc.data..addAll({'\$id': doc.$id, '\$createdAt': doc.$createdAt}));
      if (msg.senderId != _myId && !_senderNames.containsKey(msg.senderId)) {
        final u = await AppwriteService.instance.getUserDoc(msg.senderId);
        _senderNames[msg.senderId] = u?.data['name'] ?? 'Unknown';
      }
      if (!mounted) return;
      setState(() => _messages.add(msg));
      LocalDbService.instance.cacheMessage(widget.groupId, msg);
    });
  }

  Future<void> _fetchSenderNames(List<MessageModel> messages) async {
    final ids = messages.map((m) => m.senderId).toSet();
    ids.removeWhere((id) => id == _myId || _senderNames.containsKey(id));
    for (final id in ids) {
      final doc = await AppwriteService.instance.getUserDoc(id);
      _senderNames[id] = doc?.data['name'] ?? 'Unknown';
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _myId == null) return;
    _controller.clear();
    try {
      final doc = await AppwriteService.instance.sendMessage(chatId: widget.groupId, senderId: _myId!, text: text);
      if (!_messages.any((m) => m.id == doc.$id)) {
        final msg = MessageModel.fromMap(doc.data..addAll({'\$id': doc.$id, '\$createdAt': doc.$createdAt}));
        setState(() => _messages.add(msg));
        LocalDbService.instance.cacheMessage(widget.groupId, msg);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send: $e')));
    }
  }

  Future<void> _sendMedia({required String path, required String fileName, required String type, String text = ''}) async {
    if (_myId == null) return;
    setState(() => _uploading = true);
    try {
      final url = await AppwriteService.instance.uploadFile(path, fileName);
      final doc = await AppwriteService.instance.sendMessage(
        chatId: widget.groupId,
        senderId: _myId!,
        text: text,
        attachmentUrl: url,
        attachmentType: type,
      );
      if (!_messages.any((m) => m.id == doc.$id)) {
        final msg = MessageModel.fromMap(doc.data..addAll({'\$id': doc.$id, '\$createdAt': doc.$createdAt}));
        setState(() => _messages.add(msg));
        LocalDbService.instance.cacheMessage(widget.groupId, msg);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to upload: $e')));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: source);
    if (file == null) return;
    await _sendMedia(path: file.path, fileName: file.name, type: 'image');
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(withData: false);
    if (result == null || result.files.single.path == null) return;
    await _sendMedia(path: result.files.single.path!, fileName: result.files.single.name, type: 'file', text: result.files.single.name);
  }

  Future<void> _startRecording() async {
    if (!await _recorder.hasPermission()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Microphone permission denied')));
      return;
    }
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(const RecordConfig(), path: path);
    setState(() {
      _recording = true;
      _recordPath = path;
      _recordDuration = Duration.zero;
    });
    _tickRecording();
  }

  Future<void> _tickRecording() async {
    while (_recording && mounted) {
      await Future.delayed(const Duration(seconds: 1));
      if (_recording && mounted) {
        setState(() => _recordDuration += const Duration(seconds: 1));
      }
    }
  }

  Future<void> _stopRecording({bool send = true}) async {
    final path = await _recorder.stop();
    setState(() => _recording = false);
    if (!send || path == null) return;
    final duration = '${_recordDuration.inMinutes}:${(_recordDuration.inSeconds % 60).toString().padLeft(2, '0')}';
    await _sendMedia(path: path, fileName: 'voice.m4a', type: 'voice', text: duration);
  }

  Future<void> _togglePlay(MessageModel m) async {
    if (_playingId == m.id) {
      await _player.pause();
      setState(() => _playingId = null);
    } else {
      await _player.play(UrlSource(m.attachmentUrl));
      setState(() => _playingId = m.id);
    }
  }

  Future<void> _pinMessage(MessageModel m) async {
    try {
      await AppwriteService.instance.pinMessage(groupId: widget.groupId, messageId: m.id);
      setState(() => _pinnedMessage = m);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to pin: $e')));
    }
  }

  Future<void> _unpinMessage() async {
    try {
      await AppwriteService.instance.unpinMessage(widget.groupId);
      setState(() => _pinnedMessage = null);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to unpin: $e')));
    }
  }

  void _showMessageOptions(MessageModel m) {
    if (!_isAdmin) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.push_pin_outlined, color: AppTheme.cyan),
              title: Text('Pin this message', style: AppTheme.body(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _pinMessage(m);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _attachIcon(IconData icon, VoidCallback onTap, {Color? color}) {
    return IconButton(
      icon: Icon(icon, color: color ?? AppTheme.textSecondary, size: 22),
      onPressed: _uploading ? null : onTap,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
    );
  }

  @override
  Widget build(BuildContext context) {
    final feed = <Widget>[];
    for (int i = 0; i < _messages.length; i++) {
      final m = _messages[i];
      final mine = m.senderId == _myId;
      final senderName = mine ? '' : (_senderNames[m.senderId] ?? '');
      Widget content;
      if (m.attachmentType == 'image' && m.attachmentUrl.isNotEmpty) {
        content = ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(m.attachmentUrl, width: 200, fit: BoxFit.cover));
      } else if (m.attachmentType == 'voice' && m.attachmentUrl.isNotEmpty) {
        content = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(_playingId == m.id ? Icons.pause_circle : Icons.play_circle, color: mine ? Colors.white : AppTheme.cyan, size: 30),
              onPressed: () => _togglePlay(m),
              padding: EdgeInsets.zero,
            ),
            Text(m.text.isNotEmpty ? m.text : 'Voice', style: const TextStyle(color: Colors.white)),
          ],
        );
      } else if (m.attachmentType == 'file' && m.attachmentUrl.isNotEmpty) {
        content = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insert_drive_file, color: mine ? Colors.white70 : AppTheme.cyan),
            const SizedBox(width: 6),
            Flexible(child: Text(m.text.isNotEmpty ? m.text : 'File', style: const TextStyle(color: Colors.white))),
          ],
        );
      } else {
        content = Text(m.text, style: const TextStyle(color: Colors.white));
      }

      feed.add(GestureDetector(
        onLongPress: () => _showMessageOptions(m),
        child: Align(
          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
            decoration: BoxDecoration(
              color: mine ? const Color(0xFF1E222B) : AppTheme.surface,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(mine ? 16 : 4),
                bottomRight: Radius.circular(mine ? 4 : 16),
              ),
              border: Border.all(color: const Color(0xFF2A2E39), width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!mine && senderName.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(senderName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.pink)),
                  ),
                content,
              ],
            ),
          ),
        ),
      ));
      if (_ads.isNotEmpty && (i + 1) % 6 == 0) {
        feed.add(SponsoredAdCard(ad: _ads[(i ~/ 6) % _ads.length]));
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.groupName)),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.cyan))
          : Column(
              children: [
                if (_pinnedMessage != null)
                  Container(
                    width: double.infinity,
                    color: AppTheme.surfaceLight,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.push_pin, size: 16, color: AppTheme.cyan),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Pinned: ${_pinnedMessage!.text.isNotEmpty ? _pinnedMessage!.text : 'Attachment'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.body(size: 12.5, color: Colors.white),
                          ),
                        ),
                        if (_isAdmin)
                          GestureDetector(
                            onTap: _unpinMessage,
                            child: const Icon(Icons.close, size: 16, color: AppTheme.textSecondary),
                          ),
                      ],
                    ),
                  ),
                Expanded(
                  child: feed.isEmpty
                      ? Center(child: Text('No messages yet — say hi!', style: AppTheme.body(color: AppTheme.textSecondary)))
                      : ListView(padding: const EdgeInsets.all(12), children: feed),
                ),
                if (_uploading) LinearProgressIndicator(minHeight: 2, color: AppTheme.cyan, backgroundColor: AppTheme.surface),
                if (_recording)
                  Container(
                    color: AppTheme.surface,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        const Icon(Icons.fiber_manual_record, color: Colors.red, size: 14),
                        const SizedBox(width: 8),
                        Text(
                          '${_recordDuration.inMinutes}:${(_recordDuration.inSeconds % 60).toString().padLeft(2, '0')}',
                          style: AppTheme.body(color: Colors.white),
                        ),
                        const Spacer(),
                        TextButton(onPressed: () => _stopRecording(send: false), child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondary))),
                        TextButton(onPressed: () => _stopRecording(send: true), child: const Text('Send', style: TextStyle(color: AppTheme.cyan))),
                      ],
                    ),
                  ),
                SafeArea(
                  child: Container(
                    color: Colors.transparent,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E222B),
                              borderRadius: BorderRadius.circular(28),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            child: Row(
                              children: [
                                _attachIcon(Icons.camera_alt_outlined, () => _pickImage(ImageSource.camera)),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: TextField(
                                    controller: _controller,
                                    style: AppTheme.body(color: Colors.white),
                                    decoration: const InputDecoration(
                                      hintText: 'Message',
                                      hintStyle: TextStyle(color: Colors.grey),
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(vertical: 10),
                                    ),
                                  ),
                                ),
                                _attachIcon(Icons.camera_alt, () => _pickImage(ImageSource.gallery)),
                                _attachIcon(Icons.attach_file, _pickFile),
                                _attachIcon(Icons.mic, _startRecording, color: const Color(0xFF00E5FF)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 46,
                          height: 46,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFE91E63),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.send, color: Colors.white, size: 20),
                            onPressed: _send,
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
FILEEOF

