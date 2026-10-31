import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Per-account, on-device state for the chat list: which chats are archived
/// and which were deleted "for me". Nothing here touches the server, so the
/// other person's chat is never affected.
class ChatStateService {
  ChatStateService._();
  static final ChatStateService instance = ChatStateService._();

  String _archKey(String userId) => 'archived_chats_$userId';
  String _delKey(String userId) => 'deleted_chats_$userId';

  // ---------- archive ----------
  Future<Set<String>> archived(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return (prefs.getStringList(_archKey(userId)) ?? <String>[]).toSet();
  }

  Future<void> setArchived(String userId, String chatId, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final set = (prefs.getStringList(_archKey(userId)) ?? <String>[]).toSet();
    if (value) {
      set.add(chatId);
    } else {
      set.remove(chatId);
    }
    await prefs.setStringList(_archKey(userId), set.toList());
  }

  // ---------- pinned chats (stay on top of the list) ----------
  String _pinKey(String userId) => 'pinned_chats_$userId';

  /// Pinned chat ids in the order they were pinned.
  Future<List<String>> pinned(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return List<String>.from(prefs.getStringList(_pinKey(userId)) ?? <String>[]);
  }

  Future<void> setPinned(String userId, String chatId, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final list = List<String>.from(prefs.getStringList(_pinKey(userId)) ?? <String>[]);
    list.remove(chatId);
    if (value) list.add(chatId);
    await prefs.setStringList(_pinKey(userId), list);
  }

  // ---------- delete for me ----------
  Map<String, dynamic> _readDeleted(SharedPreferences prefs, String userId) {
    try {
      final raw = prefs.getString(_delKey(userId));
      if (raw != null) return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {}
    return <String, dynamic>{};
  }

  /// chatId -> the last message that was showing when the chat was deleted.
  Future<Map<String, String>> deleted(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final map = _readDeleted(prefs, userId);
    return map.map((k, v) => MapEntry(k, ((v as Map)['m'] ?? '').toString()));
  }

  Future<void> markDeleted(String userId, String chatId, String lastMessage) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final map = _readDeleted(prefs, userId);
    map[chatId] = {'t': DateTime.now().toUtc().toIso8601String(), 'm': lastMessage};
    await prefs.setString(_delKey(userId), jsonEncode(map));
  }

  Future<void> undoDelete(String userId, String chatId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final map = _readDeleted(prefs, userId);
    map.remove(chatId);
    await prefs.setString(_delKey(userId), jsonEncode(map));
  }

  /// When this user cleared the chat (messages before this are hidden), or null.
  Future<DateTime?> clearedAt(String userId, String chatId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final entry = _readDeleted(prefs, userId)[chatId];
    if (entry is Map && entry['t'] is String) return DateTime.tryParse(entry['t'] as String);
    return null;
  }

  /// True if [createdAtIso] is newer than [cutoff] (or there is no cutoff).
  static bool isAfter(String createdAtIso, DateTime? cutoff) {
    if (cutoff == null) return true;
    final dt = DateTime.tryParse(createdAtIso);
    return dt == null || dt.isAfter(cutoff);
  }
}
