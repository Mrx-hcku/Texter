import 'dart:convert';
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

  Future<void> _createV2Tables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS kv_cache (
        key TEXT PRIMARY KEY,
        value TEXT,
        updatedAt TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS outbox (
        localId TEXT PRIMARY KEY,
        chatId TEXT,
        senderId TEXT,
        message TEXT,
        replyToId TEXT,
        createdAt TEXT
      )
    ''');
  }

  Future<Database> _initDb() async {
    final dbPath = join(await getDatabasesPath(), 'texter_cache.db');
    return openDatabase(
      dbPath,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE messages (
            id TEXT PRIMARY KEY,
            chatId TEXT,
            senderId TEXT,
            message TEXT,
            mediaUrl TEXT,
            type TEXT,
            createdAt TEXT,
            reactions TEXT,
            replyToId TEXT
          )
        ''');
        await db.execute('CREATE INDEX idx_chatId ON messages(chatId)');
        await _createV2Tables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE messages ADD COLUMN reactions TEXT');
          await db.execute('ALTER TABLE messages ADD COLUMN replyToId TEXT');
          await _createV2Tables(db);
        }
      },
    );
  }

  // ---------------------------------------------------------------------------
  // MESSAGES
  // ---------------------------------------------------------------------------

  /// Replaces the cached copy of [chatId] with [messages] (so messages that
  /// were deleted on the server disappear from the offline copy too).
  Future<void> cacheMessages(String chatId, List<MessageModel> messages) async {
    final database = await db;
    await database.transaction((txn) async {
      await txn.delete('messages', where: 'chatId = ?', whereArgs: [chatId]);
      final batch = txn.batch();
      for (final m in messages) {
        if (m.id.startsWith('local_')) continue;
        batch.insert('messages', _toRow(chatId, m), conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> cacheMessage(String chatId, MessageModel m) async {
    if (m.id.startsWith('local_')) return;
    final database = await db;
    await database.insert('messages', _toRow(chatId, m), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteCachedMessage(String messageId) async {
    final database = await db;
    await database.delete('messages', where: 'id = ?', whereArgs: [messageId]);
  }

  Map<String, dynamic> _toRow(String chatId, MessageModel m) => {
        'id': m.id,
        'chatId': chatId,
        'senderId': m.senderId,
        'message': m.text,
        'mediaUrl': m.attachmentUrl,
        'type': m.attachmentType.isNotEmpty ? m.attachmentType : 'text',
        'createdAt': m.createdAt.toIso8601String(),
        'reactions': jsonEncode(m.reactions),
        'replyToId': m.replyToId,
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
        reactions: _decodeReactions(r['reactions'] as String?),
        replyToId: (r['replyToId'] as String?) ?? '',
      );
    }).toList();
  }

  Map<String, List<String>> _decodeReactions(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return decoded.map((k, v) => MapEntry(k.toString(), List<String>.from(v)));
    } catch (_) {
      return {};
    }
  }

  // ---------------------------------------------------------------------------
  // GENERIC JSON CACHE (chats list, groups, channels, users, current user...)
  // ---------------------------------------------------------------------------

  Future<void> cacheJson(String key, dynamic value) async {
    try {
      final database = await db;
      await database.insert(
        'kv_cache',
        {'key': key, 'value': jsonEncode(value), 'updatedAt': DateTime.now().toIso8601String()},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {}
  }

  Future<dynamic> getCachedJson(String key) async {
    try {
      final database = await db;
      final rows = await database.query('kv_cache', where: 'key = ?', whereArgs: [key], limit: 1);
      if (rows.isEmpty) return null;
      return jsonDecode(rows.first['value'] as String);
    } catch (_) {
      return null;
    }
  }

  Future<void> removeCachedJson(String key) async {
    try {
      final database = await db;
      await database.delete('kv_cache', where: 'key = ?', whereArgs: [key]);
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // OUTBOX — messages written while offline, sent automatically later
  // ---------------------------------------------------------------------------

  Future<void> enqueueOutbox({
    required String localId,
    required String chatId,
    required String senderId,
    required String text,
    String replyToId = '',
    DateTime? createdAt,
  }) async {
    final database = await db;
    await database.insert(
      'outbox',
      {
        'localId': localId,
        'chatId': chatId,
        'senderId': senderId,
        'message': text,
        'replyToId': replyToId,
        'createdAt': (createdAt ?? DateTime.now()).toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getOutbox(String chatId) async {
    final database = await db;
    final rows = await database.query('outbox', where: 'chatId = ?', whereArgs: [chatId], orderBy: 'createdAt ASC');
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  Future<void> removeOutbox(String localId) async {
    final database = await db;
    await database.delete('outbox', where: 'localId = ?', whereArgs: [localId]);
  }
}
