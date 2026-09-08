import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/models.dart';

/// Local SQLite cache for messages — same approach WhatsApp/Telegram use:
/// messages are shown instantly from local disk on app open, while fresh
/// data syncs from the server in the background.
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
      batch.insert(
        'messages',
        _toRow(chatId, m),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> cacheMessage(String chatId, MessageModel m) async {
    final database = await db;
    await database.insert(
      'messages',
      _toRow(chatId, m),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
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
}
