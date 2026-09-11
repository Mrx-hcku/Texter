import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:appwrite/models.dart' as models;
import '../models/models.dart';

/// Local SQLite cache for messages and chats — offline support:
/// data loads instantly from local disk, while fresh data syncs from server.
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
      version: 2, // Version increased to add chats table
      onCreate: (db, version) async {
        // 1. Messages Table (Supports text, images, videos via mediaUrl & type)
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

        // 2. Chats Table (For ChatListScreen offline caching)
        await db.execute('''
          CREATE TABLE chats (
            id TEXT PRIMARY KEY,
            myId TEXT,
            chatName TEXT,
            participantIds TEXT,
            lastMessage TEXT,
            unreadCount INTEGER,
            isPinned INTEGER,
            updatedAt TEXT
          )
        ''');
        await db.execute('CREATE INDEX idx_myId ON chats(myId)');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE chats (
              id TEXT PRIMARY KEY,
              myId TEXT,
              chatName TEXT,
              participantIds TEXT,
              lastMessage TEXT,
              unreadCount INTEGER,
              isPinned INTEGER,
              updatedAt TEXT
            )
          ''');
          await db.execute('CREATE INDEX idx_myId ON chats(myId)');
        }
      },
    );
  }

  // ==================== MESSAGES CACHING ====================

  Future<void> cacheMessages(String chatId, List<MessageModel> messages) async {
    final database = await db;
    final batch = database.batch();
    for (final m in messages) {
      batch.insert(
        'messages',
        _toMessageRow(chatId, m),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> cacheMessage(String chatId, MessageModel m) async {
    final database = await db;
    await database.insert(
      'messages',
      _toMessageRow(chatId, m),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Map<String, dynamic> _toMessageRow(String chatId, MessageModel m) => {
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
    final rows = await database.query(
      'messages',
      where: 'chatId = ?',
      whereArgs: [chatId],
      orderBy: 'createdAt ASC',
    );
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

  // ==================== CHATS CACHING ====================

  Future<void> cacheChats(List<models.Document> chats) async {
    final database = await db;
    final batch = database.batch();
    for (final c in chats) {
      batch.insert(
        'chats',
        _toChatRow(c),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> cacheChat(models.Document c) async {
    final database = await db;
    await database.insert(
      'chats',
      _toChatRow(c),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Map<String, dynamic> _toChatRow(models.Document c) => {
        'id': c.$id,
        'myId': '', // Optional tracking if needed
        'chatName': c.data['chatName'] ?? '',
        'participantIds': c.data['participantIds'] ?? '',
        'lastMessage': c.data['lastMessage'] ?? '',
        'unreadCount': c.data['unreadCount'] ?? 0,
        'isPinned': (c.data['isPinned'] == true) ? 1 : 0,
        'updatedAt': c.$updatedAt,
      };

  Future<List<models.Document>> getCachedChats(String myId) async {
    final database = await db;
    final rows = await database.query(
      'chats',
      orderBy: 'updatedAt DESC',
    );
    
    // Convert SQLite rows back to Appwrite-style Documents
    return rows.map((r) {
      final id = r['id'] as String;
      final data = {
        'chatName': r['chatName'],
        'participantIds': r['participantIds'],
        'lastMessage': r['lastMessage'],
        'unreadCount': r['unreadCount'],
        'isPinned': r['isPinned'] == 1,
      };
      return models.Document(
        $id: id,
        $collection: 'chats',
        $database: 'default',
        $createdAt: r['updatedAt'] as String,
        $updatedAt: r['updatedAt'] as String,
        $permissions: [],
        data: data,
      );
    }).toList();
  }
}
