import 'dart:convert';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import 'local_db_service.dart';
import 'net_utils.dart';

class AppwriteService {
  AppwriteService._internal() {
    client = Client()
      ..setEndpoint(AppwriteConfig.endpoint)
      ..setProject(AppwriteConfig.projectId)
      ..setSelfSigned(status: false);
    account = Account(client);
    databases = Databases(client);
    storage = Storage(client);
    realtime = Realtime(client);
  }

  static final AppwriteService instance = AppwriteService._internal();

  late final Client client;
  late final Account account;
  late final Databases databases;
  late final Storage storage;
  late final Realtime realtime;
  String? _adminJwt; // login token sent to the Texter server
  DateTime? _adminJwtAt;

  /// Id of the FCM provider created in the Appwrite console (Messaging).
  static const String fcmProviderId = 'fcm-texter';

  // ---------------- PUSH NOTIFICATIONS ----------------
  /// Registers this device with Appwrite for push notifications (via the
  /// FCM provider). Call once after login/signup, and again at app start if
  /// a session already exists. Safe to call repeatedly — Appwrite just
  /// updates the existing target for this device.
  Future<void> registerPushTarget() async {
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(alert: true, badge: true, sound: true);
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      final token = await messaging.getToken();
      if (token == null) return;
      await _upsertPushTarget(token);
    } catch (_) {
      // Offline, permission dialog dismissed, Play Services missing, etc.
      // Non-fatal — the app just won't get push notifications this session.
    }
  }

  /// Call once (e.g. in main()) so a rotated FCM token gets re-registered
  /// automatically without the person having to reopen the app.
  void listenForTokenRefresh() {
    FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      _upsertPushTarget(token);
    });
  }

  // ---------------- JWT FOR NATIVE NOTIFICATION ACTIONS ----------------
  /// Appwrite JWTs expire after 15 minutes. Refreshing and storing one in
  /// SharedPreferences lets the native Android side (notification Reply /
  /// Mark-as-read buttons) make authenticated API calls on its own,
  /// without needing the Flutter engine running. Call this after
  /// login/signup and periodically while the app is open.
  ///
  /// Note: Flutter's shared_preferences plugin stores keys on Android
  /// under a "flutter." prefix (e.g. this writes to the native key
  /// "flutter.appwrite_jwt") — the Kotlin side reads it with that prefix.
  Future<void> refreshJwt() async {
    try {
      final jwt = await account.createJWT();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('appwrite_jwt', jwt.jwt);
      final user = await getCurrentUser();
      if (user != null) await prefs.setString('appwrite_user_id', user.$id);
    } catch (_) {
      // Offline, or not logged in — notification action buttons will just
      // fall back to opening the app instead of acting directly.
    }
  }

  Future<void> clearJwt() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('appwrite_jwt');
      await prefs.remove('appwrite_user_id');
    } catch (_) {}
  }

  Future<void> _upsertPushTarget(String token) async {
    try {
      final targetId = ID.unique();
      await account.createPushTarget(targetId: targetId, identifier: token, providerId: fcmProviderId);
      await LocalDbService.instance.cacheJson('pushTargetId', targetId);
    } on AppwriteException catch (e) {
      // 409 = a target for this token/device already exists — that's fine.
      if (e.code != 409) rethrow;
    }
  }

  /// Removes this device's push target on logout so it stops receiving
  /// notifications meant for whoever logs in on this device next.
  Future<void> unregisterPushTarget() async {
    try {
      final targetId = await LocalDbService.instance.getCachedJson('pushTargetId');
      if (targetId == null) return;
      await account.deletePushTarget(targetId: targetId as String);
      await LocalDbService.instance.removeCachedJson('pushTargetId');
    } catch (_) {
      // Offline or already removed — fine, it'll just get overwritten next
      // time someone logs in and registers a new target on this device.
    }
  }

  // ---------------- OFFLINE CACHE HELPERS ----------------
  /// Runs [fetch]; on success stores the result in the local cache. When the
  /// device is offline (network error) it returns the last cached copy
  /// instead (or [fallback] if nothing was cached yet).
  Future<T> _cached<T>({
    required String key,
    required Future<T> Function() fetch,
    required dynamic Function(T) encode,
    required T Function(dynamic) decode,
    T? fallback,
  }) async {
    try {
      final result = await fetch();
      LocalDbService.instance.cacheJson(key, encode(result));
      return result;
    } catch (e) {
      if (!NetErr.isNetwork(e)) rethrow;
      final cached = await LocalDbService.instance.getCachedJson(key);
      if (cached != null) {
        try {
          return decode(cached);
        } catch (_) {}
      }
      if (fallback != null) return fallback;
      rethrow;
    }
  }

  // Appwrite ka Document.toMap()/fromMap() reliably round-trip nahi karta
  // (custom fields kho jaate the cache se wapas padhte waqt — isi se Groups/
  // Channels/Profile/chat-avatars offline par khaali/placeholder dikh rahe
  // the). Isliye yahan khud document ko ek FLAT map me convert karte hain
  // (vahi pattern jo poore app me already use ho raha hai: doc.data ke
  // andar $id/$createdAt merge karna), jo guaranteed sahi se round-trip
  // karta hai.
  static Map<String, dynamic> _docToJson(models.Document d) =>
      Map<String, dynamic>.from(d.data)
        ..['\$id'] = d.$id
        ..['\$createdAt'] = d.$createdAt
        ..['\$updatedAt'] = d.$updatedAt;

  static models.Document _docFromJson(dynamic j) => models.Document.fromMap(Map<String, dynamic>.from(j as Map));

  static List<models.Document> _decodeDocs(dynamic j) => (j as List).map(_docFromJson).toList();
  static List<Map<String, dynamic>> _encodeDocs(List<models.Document> d) => d.map(_docToJson).toList();

  // ---------------- AUTH ----------------
  Future<models.User> signUp(String email, String password, String name) async {
    await account.create(
      userId: ID.unique(),
      email: email,
      password: password,
      name: name,
    );
    await login(email, password);
    final user = await account.get();
    await databases.createDocument(
      databaseId: AppwriteConfig.databaseId,
      collectionId: AppwriteConfig.usersCollection,
      documentId: user.$id,
      data: {
        'name': name,
        'email': email,
        'avatarUrl': '',
        'status': 'Hey there! I am using Texter',
        'online': true,
      },
    );
    return user;
  }

  Future<models.Session> login(String email, String password) {
    _resetAdminJwt();
    return account.createEmailPasswordSession(email: email, password: password);
  }

  Future<void> logout() async {
    _resetAdminJwt();
    await unregisterPushTarget();
    await clearJwt();
    await account.deleteSession(sessionId: 'current');
    await LocalDbService.instance.removeCachedJson('currentUser');
  }

  /// Returns the logged-in user. Works offline too: the last known user is
  /// cached, so the app stays logged in (WhatsApp-style) with no internet.
  /// Only a real 401 (session expired / logged out) returns null.
  Future<models.User?> getCurrentUser() async {
    try {
      final user = await account.get();
      LocalDbService.instance.cacheJson('currentUser', user.toMap());
      return user;
    } catch (e) {
      if (e is AppwriteException && e.code == 401) {
        await LocalDbService.instance.removeCachedJson('currentUser');
        return null;
      }
      if (NetErr.isNetwork(e)) {
        final cached = await LocalDbService.instance.getCachedJson('currentUser');
        if (cached != null) {
          try {
            return models.User.fromMap(Map<String, dynamic>.from(cached as Map));
          } catch (_) {}
        }
      }
      return null;
    }
  }

  Future<void> sendVerificationEmail() {
    return account.createVerification(url: 'https://mrx-hcku.github.io/Texter/verify.html');
  }

  Future<void> confirmVerification({required String userId, required String secret}) {
    return account.updateVerification(userId: userId, secret: secret);
  }

  // ---------------- CHATS ----------------
  Future<List<models.Document>> getChats(String userId) {
    return _cached<List<models.Document>>(
      key: 'chats:$userId',
      fetch: () async {
        final res = await databases.listDocuments(
          databaseId: AppwriteConfig.databaseId,
          collectionId: AppwriteConfig.chatsCollection,
          queries: [Query.search('participantIds', userId)],
        );
        return res.documents;
      },
      encode: _encodeDocs,
      decode: _decodeDocs,
      fallback: <models.Document>[],
    );
  }

  Future<models.Document> createChat({
    required String type,
    required String name,
    required List<String> participantIds,
  }) {
    return databases.createDocument(
      databaseId: AppwriteConfig.databaseId,
      collectionId: AppwriteConfig.chatsCollection,
      documentId: ID.unique(),
      data: {
        'isGroup': type == 'group',
        'chatName': name,
        'participantIds': participantIds.join(','),
        'lastMessage': '',
      },
    );
  }

  /// Finds an existing direct chat between two users, or creates one.
  Future<models.Document> findOrCreateDirectChat({
    required String myId,
    required String otherId,
    required String otherName,
  }) async {
    final existing = await getChats(myId);
    for (final doc in existing) {
      if (doc.data['isGroup'] == false) {
        final ids = (doc.data['participantIds'] as String? ?? '').split(',').where((e) => e.isNotEmpty).toList();
        if (ids.contains(otherId)) return doc;
      }
    }
    return createChat(type: 'direct', name: otherName, participantIds: [myId, otherId]);
  }

  /// Marks a direct chat as read for [userId] — removes them from the
  /// `unreadFor` list so the unread dot in the chat list disappears.
  Future<void> markChatRead({required String chatId, required String userId}) async {
    try {
      final chatDoc = await databases.getDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.chatsCollection,
        documentId: chatId,
      );
      final unread = (chatDoc.data['unreadFor'] as String? ?? '')
          .split(',')
          .where((e) => e.isNotEmpty && e != userId)
          .toList();
      await databases.updateDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.chatsCollection,
        documentId: chatId,
        data: {'unreadFor': unread.join(',')},
      );
    } catch (_) {}
  }

  // ---------------- PRESENCE / TYPING ----------------
  Future<void> updateOnlineStatus(String userId, bool isOnline) async {
    try {
      await databases.updateDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.usersCollection,
        documentId: userId,
        data: {'online': isOnline},
      );
    } catch (_) {}
  }

  /// Adds/removes [userId] from a chat's `typingUsers` list so the other
  /// participant sees a live "typing..." indicator.
  Future<void> setTyping({required String chatId, required String userId, required bool isTyping}) async {
    try {
      final chatDoc = await databases.getDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.chatsCollection,
        documentId: chatId,
      );
      final typing = (chatDoc.data['typingUsers'] as String? ?? '')
          .split(',')
          .where((e) => e.isNotEmpty && e != userId)
          .toList();
      if (isTyping) typing.add(userId);
      await databases.updateDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.chatsCollection,
        documentId: chatId,
        data: {'typingUsers': typing.join(',')},
      );
    } catch (_) {}
  }

  // ---------------- USERS ----------------
  Future<List<models.Document>> searchUsers(String query, {String? excludeId}) async {
    final q = query.trim();
    List<models.Document> docs;
    try {
      final queries = <String>[Query.limit(50)];
      if (q.isNotEmpty) queries.add(Query.search('name', q));
      final res = await databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.usersCollection,
        queries: queries,
      );
      docs = res.documents;
      LocalDbService.instance.cacheJson('users:${q.toLowerCase()}', _encodeDocs(docs));
    } catch (e) {
      if (!NetErr.isNetwork(e)) rethrow;
      // Offline: use the cached result for this query, else filter the
      // cached "all users" list locally, else just show nothing.
      var cached = await LocalDbService.instance.getCachedJson('users:${q.toLowerCase()}');
      if (cached != null) {
        docs = _decodeDocs(cached);
      } else {
        final all = await LocalDbService.instance.getCachedJson('users:');
        docs = all == null
            ? <models.Document>[]
            : _decodeDocs(all).where((d) => (d.data['name'] ?? '').toString().toLowerCase().contains(q.toLowerCase())).toList();
      }
    }
    if (excludeId == null) return docs;
    return docs.where((d) => d.$id != excludeId).toList();
  }

  Future<models.Document?> getUserDoc(String userId) async {
    try {
      final doc = await databases.getDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.usersCollection,
        documentId: userId,
      );
      LocalDbService.instance.cacheJson('user:$userId', _docToJson(doc));
      return doc;
    } catch (e) {
      if (NetErr.isNetwork(e)) {
        final cached = await LocalDbService.instance.getCachedJson('user:$userId');
        if (cached != null) {
          try {
            return _docFromJson(cached);
          } catch (_) {}
        }
      }
      return null;
    }
  }

  Future<void> updateUserProfile({required String userId, String? name, String? status, String? avatarUrl}) {
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (status != null) data['status'] = status;
    if (avatarUrl != null) data['avatarUrl'] = avatarUrl;
    return databases.updateDocument(
      databaseId: AppwriteConfig.databaseId,
      collectionId: AppwriteConfig.usersCollection,
      documentId: userId,
      data: data,
    );
  }

  Future<void> updateNotificationPrefs(String userId, Map<String, bool> prefs) {
    return databases.updateDocument(
      databaseId: AppwriteConfig.databaseId,
      collectionId: AppwriteConfig.usersCollection,
      documentId: userId,
      data: {'notifPrefs': jsonEncode(prefs)},
    );
  }

  Map<String, bool> parseNotificationPrefs(String? raw) {
    const defaults = {'messages': true, 'groups': true, 'channels': true, 'sound': true};
    if (raw == null || raw.isEmpty) return defaults;
    try {
      final decoded = Map<String, dynamic>.from(jsonDecode(raw));
      return defaults.map((k, v) => MapEntry(k, decoded[k] ?? v));
    } catch (_) {
      return defaults;
    }
  }

  // ---------------- MESSAGES ----------------
  /// Latest messages for [chatId], newest-first internally but returned in
  /// chronological (oldest-first) order ready to render. Pehle "orderAsc +
  /// limit(200)" use ho raha tha, jo hamesha sabse PURANE 200 messages
  /// laata tha — agar chat 200 se aage badh jaye to naye messages kabhi
  /// load hi nahi hote the (isiliye chat "atak" jaati thi). Ab hamesha
  /// sabse NAYE messages aate hain.
  ///
  /// [beforeMessageId] diya jaye to usse PURANE messages laata hai (scroll-
  /// up pagination ke liye) — isse chat history practically unlimited ho
  /// jaati hai.
  Future<List<models.Document>> getMessages(String chatId, {String? beforeMessageId, int limit = 60}) async {
    final queries = [
      Query.equal('chatId', chatId),
      Query.orderDesc('\$createdAt'),
      Query.limit(limit),
    ];
    if (beforeMessageId != null) {
      queries.add(Query.cursorAfter(beforeMessageId));
    }
    final res = await databases.listDocuments(
      databaseId: AppwriteConfig.databaseId,
      collectionId: AppwriteConfig.messagesCollection,
      queries: queries,
    );
    // Query ne newest-first diya, screen ko oldest-first chahiye.
    return res.documents.reversed.toList();
  }

  Future<models.Document?> getMessageById(String messageId) async {
    try {
      return await databases.getDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.messagesCollection,
        documentId: messageId,
      );
    } catch (_) {
      return null;
    }
  }

  Future<models.Document> sendMessage({
    required String chatId,
    required String senderId,
    String text = '',
    String attachmentUrl = '',
    String attachmentType = '',
    String replyToId = '',
    bool isForwarded = false,
  }) async {
    final doc = await databases.createDocument(
      databaseId: AppwriteConfig.databaseId,
      collectionId: AppwriteConfig.messagesCollection,
      documentId: ID.unique(),
      data: {
        'chatId': chatId,
        'senderId': senderId,
        'message': text,
        'mediaUrl': attachmentUrl,
        'type': attachmentType.isNotEmpty ? attachmentType : 'text',
        if (replyToId.isNotEmpty) 'replyToId': replyToId,
        if (isForwarded) 'isForwarded': true,
      },
    );
    try {
      final chatDoc = await databases.getDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.chatsCollection,
        documentId: chatId,
      );
      final participantIds = (chatDoc.data['participantIds'] as String? ?? '')
          .split(',')
          .where((e) => e.isNotEmpty)
          .toList();
      final recipients = participantIds.where((id) => id != senderId).toList();
      await databases.updateDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.chatsCollection,
        documentId: chatId,
        data: {
          'lastMessage': previewFor(attachmentType, text).isNotEmpty ? previewFor(attachmentType, text) : 'Attachment',
          'unreadFor': recipients.join(','),
        },
      );
    } catch (_) {}
    // Photos / videos have no text — send a readable preview so the push is never blank.
    final pushText = previewFor(attachmentType, text);
    _notifyPush(chatId: chatId, senderId: senderId, text: pushText.isNotEmpty ? pushText : text, type: attachmentType.isNotEmpty ? attachmentType : 'text');
    return doc;
  }

  /// Tells the Render push server to notify the other participant(s).
  /// Fire-and-forget: a failure here (server asleep, offline, wrong URL)
  /// must NEVER stop the message itself from sending, so every error is
  /// swallowed silently.
  void _notifyPush({required String chatId, required String senderId, required String text, required String type}) {
    if (PushServerConfig.notifyUrl.contains('YOUR-RENDER-APP')) return; // not configured yet
    http
        .post(
          Uri.parse(PushServerConfig.notifyUrl),
          headers: {
            'Content-Type': 'application/json',
            'x-notify-secret': PushServerConfig.secret,
          },
          body: jsonEncode({'chatId': chatId, 'senderId': senderId, 'text': text, 'type': type}),
        )
        .timeout(const Duration(seconds: 10))
        .catchError((_) {});
  }

  /// Permanently deletes a message document. Deleting removes it for
  /// everyone (DB level) — realtime `.delete` event notifies other
  /// participants so it disappears from their screen too.
  /// Edits a message's text (sender-only, like WhatsApp/Telegram). Marks
  /// `isEdited: true` so the UI can show the "(edited)" label. If [chatId]
  /// is given and this was the chat's latest message, also refreshes the
  /// parent document's `lastMessage` preview to the newly edited text.
  Future<models.Document> editMessage({
    required String messageId,
    required String newText,
    String? chatId,
    String? collectionId,
  }) async {
    final doc = await databases.updateDocument(
      databaseId: AppwriteConfig.databaseId,
      collectionId: AppwriteConfig.messagesCollection,
      documentId: messageId,
      data: {'message': newText, 'isEdited': true},
    );
    if (chatId != null) {
      try {
        final res = await databases.listDocuments(
          databaseId: AppwriteConfig.databaseId,
          collectionId: AppwriteConfig.messagesCollection,
          queries: [
            Query.equal('chatId', chatId),
            Query.orderDesc('\$createdAt'),
            Query.limit(1),
          ],
        );
        if (res.documents.isNotEmpty && res.documents.first.$id == messageId) {
          await databases.updateDocument(
            databaseId: AppwriteConfig.databaseId,
            collectionId: collectionId ?? AppwriteConfig.chatsCollection,
            documentId: chatId,
            data: {'lastMessage': newText},
          );
        }
      } catch (_) {
        // Offline, ya us collection me 'lastMessage' field nahi hai — skip.
      }
    }
    return doc;
  }

  /// Deletes a message. If [chatId] is given, also refreshes the parent
  /// chat/group/channel document's `lastMessage` preview field — otherwise
  /// the chat list keeps showing the deleted text (WhatsApp/Telegram always
  /// update the preview the moment a message is removed).
  Future<void> deleteMessage(String messageId, {String? chatId, String? collectionId}) async {
    await databases.deleteDocument(
      databaseId: AppwriteConfig.databaseId,
      collectionId: AppwriteConfig.messagesCollection,
      documentId: messageId,
    );
    if (chatId == null) return;
    try {
      final res = await databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.messagesCollection,
        queries: [
          Query.equal('chatId', chatId),
          Query.orderDesc('\$createdAt'),
          Query.limit(1),
        ],
      );
      String preview = '';
      if (res.documents.isNotEmpty) {
        final d = res.documents.first;
        final type = d.data['type'] ?? 'text';
        final text = d.data['message'] ?? '';
        if (type == 'image') {
          preview = '📷 Photo';
        } else if (type == 'voice') {
          preview = '🎤 Voice message';
        } else if (type == 'file') {
          preview = text.isNotEmpty ? '📎 $text' : '📎 File';
        } else {
          preview = text;
        }
      }
      await databases.updateDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: collectionId ?? AppwriteConfig.chatsCollection,
        documentId: chatId,
        data: {'lastMessage': preview},
      );
    } catch (_) {
      // Offline, ya us collection me 'lastMessage' field hi nahi hai (jaise
      // channels) — chup-chaap skip karo, kuch tootega nahi.
    }
  }

  /// Toggles [emoji] as [userId]'s reaction on message [messageId].
  /// WhatsApp-style: each user can have only ONE active reaction per
  /// message — picking a new emoji replaces their previous one; tapping
  /// the same emoji again removes it. Persisted DB-side as a JSON string
  /// in the message's `reactions` attribute.
  Future<models.Document> toggleReaction({
    required String messageId,
    required String userId,
    required String emoji,
  }) async {
    final doc = await databases.getDocument(
      databaseId: AppwriteConfig.databaseId,
      collectionId: AppwriteConfig.messagesCollection,
      documentId: messageId,
    );
    final raw = doc.data['reactions'] as String? ?? '';
    Map<String, dynamic> decoded = {};
    if (raw.isNotEmpty) {
      try {
        decoded = Map<String, dynamic>.from(jsonDecode(raw));
      } catch (_) {}
    }
    final current = decoded.map((k, v) => MapEntry(k, List<String>.from(v)));

    final hadThisEmoji = current[emoji]?.contains(userId) ?? false;
    for (final key in current.keys.toList()) {
      current[key]!.remove(userId);
      if (current[key]!.isEmpty) current.remove(key);
    }
    if (!hadThisEmoji) {
      current.putIfAbsent(emoji, () => []).add(userId);
    }

    return databases.updateDocument(
      databaseId: AppwriteConfig.databaseId,
      collectionId: AppwriteConfig.messagesCollection,
      documentId: messageId,
      data: {'reactions': jsonEncode(current)},
    );
  }

  /// [onMessage] fires for new messages in [chatId] (unchanged behaviour).
  /// [onUpdate] fires when a message is edited/reacted-to (any participant's
  /// device). [onDelete] fires with the deleted message's id when someone
  /// deletes a message.
  RealtimeSubscription subscribeToMessages(
    String chatId,
    Function(models.Document) onMessage, {
    Function(models.Document)? onUpdate,
    Function(String messageId)? onDelete,
  }) {
    final sub = realtime.subscribe([
      'databases.${AppwriteConfig.databaseId}.collections.${AppwriteConfig.messagesCollection}.documents'
    ]);
    sub.stream.listen((event) {
      final data = event.payload;
      if (data == null || data is! Map) return;
      final map = Map<String, dynamic>.from(data);
      if (map['chatId'] != chatId) return;
      if (event.events.any((e) => e.contains('create'))) {
        onMessage(models.Document.fromMap(map));
      } else if (event.events.any((e) => e.contains('update'))) {
        onUpdate?.call(models.Document.fromMap(map));
      } else if (event.events.any((e) => e.contains('delete'))) {
        onDelete?.call(map['\$id'] ?? '');
      }
    });
    return sub;
  }

  RealtimeSubscription subscribeToCollection(
    String collectionId,
    void Function(models.Document doc, List<String> events) onChange,
  ) {
    final sub = realtime.subscribe([
      'databases.${AppwriteConfig.databaseId}.collections.$collectionId.documents'
    ]);
    sub.stream.listen((event) {
      final data = event.payload;
      if (data != null && data is Map) {
        onChange(models.Document.fromMap(Map<String, dynamic>.from(data)), event.events);
      }
    });
    return sub;
  }

  // ---------------- GROUPS ----------------
  Future<List<models.Document>> getGroups() {
    return _cached<List<models.Document>>(
      key: 'groups',
      fetch: () async {
        final res = await databases.listDocuments(
          databaseId: AppwriteConfig.databaseId,
          collectionId: AppwriteConfig.groupsCollection,
        );
        return res.documents;
      },
      encode: _encodeDocs,
      decode: _decodeDocs,
      fallback: <models.Document>[],
    );
  }

  Future<models.Document> _createGroupDirect({
    required String name,
    required String description,
    required List<String> memberIds,
    required String creatorId,
    bool isPublic = true,
  }) {
    return databases.createDocument(
      databaseId: AppwriteConfig.databaseId,
      collectionId: AppwriteConfig.groupsCollection,
      documentId: ID.unique(),
      data: {
        'name': name,
        'description': description,
        'avatarUrl': '',
        'memberIds': memberIds,
        'adminIds': [creatorId],
        'isPublic': isPublic,
      },
    );
  }

  Future<void> _joinGroupDirect({required String groupId, required String userId}) async {
    final doc = await databases.getDocument(
      databaseId: AppwriteConfig.databaseId,
      collectionId: AppwriteConfig.groupsCollection,
      documentId: groupId,
    );
    final members = List<String>.from(doc.data['memberIds'] ?? []);
    if (!members.contains(userId)) members.add(userId);
    await databases.updateDocument(
      databaseId: AppwriteConfig.databaseId,
      collectionId: AppwriteConfig.groupsCollection,
      documentId: groupId,
      data: {'memberIds': members},
    );
  }

  Future<void> _leaveGroupDirect({required String groupId, required String userId}) async {
    final doc = await databases.getDocument(
      databaseId: AppwriteConfig.databaseId,
      collectionId: AppwriteConfig.groupsCollection,
      documentId: groupId,
    );
    final members = List<String>.from(doc.data['memberIds'] ?? []);
    members.remove(userId);
    await databases.updateDocument(
      databaseId: AppwriteConfig.databaseId,
      collectionId: AppwriteConfig.groupsCollection,
      documentId: groupId,
      data: {'memberIds': members},
    );
  }

  Future<models.Document> getGroupDoc(String groupId) {
    return _cached<models.Document>(
      key: 'group:$groupId',
      fetch: () => databases.getDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.groupsCollection,
        documentId: groupId,
      ),
      encode: (d) => _docToJson(d),
      decode: (j) => _docFromJson(j),
    );
  }

  Future<void> _pinMessageDirect({required String groupId, required String messageId}) {
    return databases.updateDocument(
      databaseId: AppwriteConfig.databaseId,
      collectionId: AppwriteConfig.groupsCollection,
      documentId: groupId,
      data: {'pinnedMessageId': messageId},
    );
  }

  Future<void> _unpinMessageDirect(String groupId) {
    return databases.updateDocument(
      databaseId: AppwriteConfig.databaseId,
      collectionId: AppwriteConfig.groupsCollection,
      documentId: groupId,
      data: {'pinnedMessageId': ''},
    );
  }

  // ---------------- CHANNELS ----------------
  Future<List<models.Document>> getChannels() {
    return _cached<List<models.Document>>(
      key: 'channels',
      fetch: () async {
        final res = await databases.listDocuments(
          databaseId: AppwriteConfig.databaseId,
          collectionId: AppwriteConfig.channelsCollection,
        );
        return res.documents;
      },
      encode: _encodeDocs,
      decode: _decodeDocs,
      fallback: <models.Document>[],
    );
  }

  Future<models.Document> getChannelDoc(String channelId) {
    return _cached<models.Document>(
      key: 'channel:$channelId',
      fetch: () => databases.getDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.channelsCollection,
        documentId: channelId,
      ),
      encode: (d) => _docToJson(d),
      decode: (j) => _docFromJson(j),
    );
  }

  Future<models.Document> _createChannelDirect({
    required String name,
    required String description,
    required String creatorId,
    String avatarUrl = '',
  }) async {
    final base = <String, dynamic>{
      'name': name,
      'description': description,
      'avatarUrl': avatarUrl,
      'subscriberCount': 1,
      'subscriberIds': [creatorId],
    };
    Future<models.Document> create(Map<String, dynamic> data) => databases.createDocument(
          databaseId: AppwriteConfig.databaseId,
          collectionId: AppwriteConfig.channelsCollection,
          documentId: ID.unique(),
          data: data,
        );
    try {
      return await create({...base, 'creatorId': creatorId, 'adminIds': [creatorId]});
    } catch (e) {
      // Old database without creatorId / adminIds yet: still create the channel
      // (the first subscriber is then treated as its owner).
      if (missingAttribute(e) != null) return create(base);
      rethrow;
    }
  }

  Future<void> _subscribeChannelDirect({required String channelId, required String userId}) async {
    final doc = await databases.getDocument(
      databaseId: AppwriteConfig.databaseId,
      collectionId: AppwriteConfig.channelsCollection,
      documentId: channelId,
    );
    final subs = List<String>.from(doc.data['subscriberIds'] ?? []);
    if (!subs.contains(userId)) subs.add(userId);
    await databases.updateDocument(
      databaseId: AppwriteConfig.databaseId,
      collectionId: AppwriteConfig.channelsCollection,
      documentId: channelId,
      data: {'subscriberIds': subs, 'subscriberCount': subs.length},
    );
  }

  Future<void> _unsubscribeChannelDirect({required String channelId, required String userId}) async {
    final doc = await databases.getDocument(
      databaseId: AppwriteConfig.databaseId,
      collectionId: AppwriteConfig.channelsCollection,
      documentId: channelId,
    );
    final subs = List<String>.from(doc.data['subscriberIds'] ?? []);
    subs.remove(userId);
    await databases.updateDocument(
      databaseId: AppwriteConfig.databaseId,
      collectionId: AppwriteConfig.channelsCollection,
      documentId: channelId,
      data: {'subscriberIds': subs, 'subscriberCount': subs.length},
    );
  }


  // ======================================================================
  // SERVER-SIDE ADMIN RULES (Texter server on Render: POST /admin)
  // Channels / Groups changes go through the server, which checks who is
  // really allowed. Until adminServerUrl is filled in, the app falls back to
  // writing directly so nothing breaks while you set it up.
  // ======================================================================
  /// Public address of your Render service (no trailing slash), e.g.
  /// https://threedayexpireserver.onrender.com
  /// While it still says YOUR-SERVICE the app writes directly (old behaviour).
  static const String adminServerUrl = 'https://threedayexpireserver.onrender.com';

  Future<String> _getAdminJwt() async {
    final at = _adminJwtAt;
    if (_adminJwt != null && at != null && DateTime.now().difference(at).inMinutes < 12) return _adminJwt!;
    final jwt = await account.createJWT();
    _adminJwt = jwt.jwt;
    _adminJwtAt = DateTime.now();
    return _adminJwt!;
  }

  /// Forget the token when someone logs in / out (it belongs to one person).
  void _resetAdminJwt() {
    _adminJwt = null;
    _adminJwtAt = null;
  }

  Future<Map<String, dynamic>> _admin(
    String action,
    Map<String, dynamic> payload, {
    required Future<Map<String, dynamic>> Function() direct,
  }) async {
    if (adminServerUrl.contains('YOUR-SERVICE')) return direct();
    final jwt = await _getAdminJwt();
    final res = await http
        .post(
          Uri.parse('$adminServerUrl/admin'),
          headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $jwt'},
          body: jsonEncode({'action': action, ...payload}),
        )
        .timeout(const Duration(seconds: 75)); // a sleeping free Render service needs up to ~1 min to wake
    Map<String, dynamic> out = {};
    try {
      out = Map<String, dynamic>.from(jsonDecode(res.body) as Map);
    } catch (_) {}
    if (res.statusCode >= 400 || out['ok'] == false) {
      throw Exception((out['error'] ?? 'Server error (${res.statusCode})').toString());
    }
    return out;
  }

  models.Document _docOf(Map<String, dynamic> out) => models.Document.fromMap(Map<String, dynamic>.from(out['doc'] as Map));

  Future<models.Document> createGroup({
    required String name,
    required String description,
    required List<String> memberIds,
    required String creatorId,
    bool isPublic = true,
  }) async {
    final out = await _admin(
      'group.create',
      {'name': name, 'description': description, 'memberIds': memberIds, 'isPublic': isPublic},
      direct: () async {
        final d = await _createGroupDirect(name: name, description: description, memberIds: memberIds, creatorId: creatorId, isPublic: isPublic);
        return {'ok': true, 'doc': d.toMap()};
      },
    );
    return _docOf(out);
  }

  Future<void> joinGroup({required String groupId, required String userId}) async {
    await joinOrRequestGroup(groupId: groupId, userId: userId);
  }

  /// 'joined' or 'requested' (when the group needs an admin's approval).
  Future<String> joinOrRequestGroup({required String groupId, required String userId}) async {
    final out = await _admin(
      'group.join',
      {'groupId': groupId},
      direct: () async => {'ok': true, 'status': await _joinOrRequestGroupDirect(groupId: groupId, userId: userId)},
    );
    return (out['status'] ?? 'joined').toString();
  }

  Future<void> leaveGroup({required String groupId, required String userId}) async {
    await _admin('group.leave', {'groupId': groupId}, direct: () async {
      await _leaveGroupDirect(groupId: groupId, userId: userId);
      return {'ok': true};
    });
  }

  Future<void> pinMessage({required String groupId, required String messageId}) async {
    await updateGroup(groupId, {'pinnedMessageId': messageId});
  }

  Future<void> unpinMessage(String groupId) async {
    await updateGroup(groupId, {'pinnedMessageId': ''});
  }

  Future<models.Document> updateGroup(String groupId, Map<String, dynamic> data) async {
    final out = await _admin('group.update', {'groupId': groupId, 'data': data}, direct: () async {
      final d = await _updateGroupDirect(groupId, data);
      return {'ok': true, 'doc': d.toMap()};
    });
    return _docOf(out);
  }

  Future<void> addGroupMembers(String groupId, List<String> userIds) async {
    await _admin('group.addMembers', {'groupId': groupId, 'userIds': userIds}, direct: () async {
      await _addGroupMembersDirect(groupId, userIds);
      return {'ok': true};
    });
  }

  Future<void> removeGroupMember(String groupId, String userId) async {
    await _admin('group.removeMember', {'groupId': groupId, 'userId': userId}, direct: () async {
      await _removeGroupMemberDirect(groupId, userId);
      return {'ok': true};
    });
  }

  Future<void> setGroupAdmins(String groupId, List<String> adminIds) async {
    await _admin('group.setAdmins', {'groupId': groupId, 'adminIds': adminIds}, direct: () async {
      await _setGroupAdminsDirect(groupId, adminIds);
      return {'ok': true};
    });
  }

  Future<void> resolveJoinRequest({required String groupId, required String userId, required bool approve}) async {
    await _admin('group.resolveRequest', {'groupId': groupId, 'userId': userId, 'approve': approve}, direct: () async {
      await _resolveJoinRequestDirect(groupId: groupId, userId: userId, approve: approve);
      return {'ok': true};
    });
  }

  Future<void> deleteGroup(String groupId) async {
    await _admin('group.delete', {'groupId': groupId}, direct: () async {
      await _deleteGroupDirect(groupId);
      return {'ok': true};
    });
  }

  Future<models.Document> createChannel({
    required String name,
    required String description,
    required String creatorId,
    String avatarUrl = '',
  }) async {
    final out = await _admin(
      'channel.create',
      {'name': name, 'description': description, 'avatarUrl': avatarUrl},
      direct: () async {
        final d = await _createChannelDirect(name: name, description: description, creatorId: creatorId, avatarUrl: avatarUrl);
        return {'ok': true, 'doc': d.toMap()};
      },
    );
    return _docOf(out);
  }

  Future<void> subscribeChannel({required String channelId, required String userId}) async {
    await _admin('channel.subscribe', {'channelId': channelId}, direct: () async {
      await _subscribeChannelDirect(channelId: channelId, userId: userId);
      return {'ok': true};
    });
  }

  /// Unfollow yourself, or (admins) remove a follower.
  Future<void> unsubscribeChannel({required String channelId, required String userId}) async {
    await _admin('channel.unsubscribe', {'channelId': channelId, 'userId': userId}, direct: () async {
      await _unsubscribeChannelDirect(channelId: channelId, userId: userId);
      return {'ok': true};
    });
  }

  Future<models.Document> updateChannel(String channelId, Map<String, dynamic> data) async {
    final out = await _admin('channel.update', {'channelId': channelId, 'data': data}, direct: () async {
      final d = await _updateChannelDirect(channelId, data);
      return {'ok': true, 'doc': d.toMap()};
    });
    return _docOf(out);
  }

  Future<void> setChannelAdmins(String channelId, List<String> adminIds) async {
    await _admin('channel.setAdmins', {'channelId': channelId, 'adminIds': adminIds}, direct: () async {
      await _setChannelAdminsDirect(channelId, adminIds);
      return {'ok': true};
    });
  }

  Future<void> pinChannelPost(String channelId, String messageId) async {
    await updateChannel(channelId, {'pinnedMessageId': messageId});
  }

  Future<void> deleteChannel(String channelId) async {
    await _admin('channel.delete', {'channelId': channelId}, direct: () async {
      await _deleteChannelDirect(channelId);
      return {'ok': true};
    });
  }

  // ---------------- SHARED HELPERS ----------------
  /// If an Appwrite error says "Unknown attribute: x", returns "x" — so the UI
  /// can tell the developer exactly which attribute to add in the console.
  static String? missingAttribute(Object e) {
    final msg = e is AppwriteException ? (e.message ?? '') : e.toString();
    final m = RegExp(r'Unknown attribute: "([^"]+)"').firstMatch(msg);
    return m?.group(1);
  }

  /// Short text for the newest-post / newest-message preview.
  static String previewFor(String type, String text) {
    switch (type) {
      case 'image':
        return text.isNotEmpty ? '📷 $text' : '📷 Photo';
      case 'video':
        return text.isNotEmpty ? '🎥 $text' : '🎥 Video';
      case 'voice':
        return '🎤 Voice message';
      case 'file':
        return '📎 ${text.split('\n').first}';
      default:
        return text;
    }
  }

  /// Several users at once (member / follower lists).
  Future<List<models.Document>> getUsersByIds(List<String> ids) async {
    final out = <models.Document>[];
    for (var i = 0; i < ids.length; i += 50) {
      final chunk = ids.sublist(i, i + 50 > ids.length ? ids.length : i + 50);
      try {
        final res = await databases.listDocuments(
          databaseId: AppwriteConfig.databaseId,
          collectionId: AppwriteConfig.usersCollection,
          queries: [Query.equal('\$id', chunk), Query.limit(50)],
        );
        out.addAll(res.documents);
      } catch (_) {}
    }
    return out;
  }

  // ---------------- CHANNEL ADMIN ----------------
  Future<models.Document> _updateChannelDirect(String channelId, Map<String, dynamic> data) {
    return databases.updateDocument(
      databaseId: AppwriteConfig.databaseId,
      collectionId: AppwriteConfig.channelsCollection,
      documentId: channelId,
      data: data,
    );
  }

  Future<void> _setChannelAdminsDirect(String channelId, List<String> adminIds) async {
    await _updateChannelDirect(channelId, {'adminIds': adminIds});
  }

  /// Keeps the channel list preview ("last post + time") up to date.
  /// Silent if the channels collection has no lastMessage / lastMessageAt yet.
  Future<void> touchChannelLastPost(String channelId, String preview) async {
    try {
      await _updateChannelDirect(channelId, {
        'lastMessage': preview,
        'lastMessageAt': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (_) {}
  }

  Future<void> _pinChannelPostDirect(String channelId, String messageId) async {
    await _updateChannelDirect(channelId, {'pinnedMessageId': messageId});
  }

  /// Deletes the channel and (best effort) all its posts.
  Future<void> _deleteChannelDirect(String channelId) async {
    await databases.deleteDocument(
      databaseId: AppwriteConfig.databaseId,
      collectionId: AppwriteConfig.channelsCollection,
      documentId: channelId,
    );
    await _deleteAllMessages(channelId);
  }

  Future<void> _deleteAllMessages(String chatId) async {
    try {
      for (var round = 0; round < 10; round++) {
        final res = await databases.listDocuments(
          databaseId: AppwriteConfig.databaseId,
          collectionId: AppwriteConfig.messagesCollection,
          queries: [Query.equal('chatId', chatId), Query.limit(100)],
        );
        if (res.documents.isEmpty) break;
        for (final d in res.documents) {
          try {
            await databases.deleteDocument(
              databaseId: AppwriteConfig.databaseId,
              collectionId: AppwriteConfig.messagesCollection,
              documentId: d.$id,
            );
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  // ---------------- GROUP ADMIN ----------------
  Future<models.Document> _updateGroupDirect(String groupId, Map<String, dynamic> data) {
    return databases.updateDocument(
      databaseId: AppwriteConfig.databaseId,
      collectionId: AppwriteConfig.groupsCollection,
      documentId: groupId,
      data: data,
    );
  }

  Future<models.Document> _rawGroup(String groupId) => databases.getDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.groupsCollection,
        documentId: groupId,
      );

  Future<void> _addGroupMembersDirect(String groupId, List<String> userIds) async {
    final doc = await _rawGroup(groupId);
    final members = List<String>.from(doc.data['memberIds'] ?? []);
    for (final id in userIds) {
      if (!members.contains(id)) members.add(id);
    }
    await _updateGroupDirect(groupId, {'memberIds': members});
  }

  /// Removes a person from the group (also from admins / waiting list).
  Future<void> _removeGroupMemberDirect(String groupId, String userId) async {
    final doc = await _rawGroup(groupId);
    final members = List<String>.from(doc.data['memberIds'] ?? [])..remove(userId);
    final admins = List<String>.from(doc.data['adminIds'] ?? [])..remove(userId);
    await _updateGroupDirect(groupId, {'memberIds': members, 'adminIds': admins});
  }

  Future<void> _setGroupAdminsDirect(String groupId, List<String> adminIds) async {
    await _updateGroupDirect(groupId, {'adminIds': adminIds});
  }

  /// Joins right away, or — if the group needs admin approval — sends a
  /// request. Returns 'joined' or 'requested'.
  Future<String> _joinOrRequestGroupDirect({required String groupId, required String userId}) async {
    final doc = await _rawGroup(groupId);
    final needApproval = doc.data['needApproval'] == true;
    final admins = List<String>.from(doc.data['adminIds'] ?? []);
    if (needApproval && !admins.contains(userId)) {
      final pending = List<String>.from(doc.data['pendingIds'] ?? []);
      if (!pending.contains(userId)) pending.add(userId);
      await _updateGroupDirect(groupId, {'pendingIds': pending});
      return 'requested';
    }
    await _joinGroupDirect(groupId: groupId, userId: userId);
    return 'joined';
  }

  Future<void> _resolveJoinRequestDirect({required String groupId, required String userId, required bool approve}) async {
    final doc = await _rawGroup(groupId);
    final pending = List<String>.from(doc.data['pendingIds'] ?? [])..remove(userId);
    final members = List<String>.from(doc.data['memberIds'] ?? []);
    if (approve && !members.contains(userId)) members.add(userId);
    await _updateGroupDirect(groupId, {'pendingIds': pending, 'memberIds': members});
  }

  Future<void> _deleteGroupDirect(String groupId) async {
    await databases.deleteDocument(
      databaseId: AppwriteConfig.databaseId,
      collectionId: AppwriteConfig.groupsCollection,
      documentId: groupId,
    );
    await _deleteAllMessages(groupId);
  }

  // ---------------- ADS ----------------
  Future<List<models.Document>> getAds({String? targetType}) {
    return _cached<List<models.Document>>(
      key: 'ads:${targetType ?? 'all'}',
      fetch: () async {
        final queries = <String>[];
        if (targetType != null) queries.add(Query.equal('targetType', targetType));
        final res = await databases.listDocuments(
          databaseId: AppwriteConfig.databaseId,
          collectionId: AppwriteConfig.adsCollection,
          queries: queries,
        );
        return res.documents;
      },
      encode: _encodeDocs,
      decode: _decodeDocs,
      fallback: <models.Document>[],
    );
  }

  // ---------------- STORAGE ----------------
  Future<String> uploadFile(String path, String fileName) async {
    final file = await storage.createFile(
      bucketId: AppwriteConfig.bucketId,
      fileId: ID.unique(),
      file: InputFile.fromPath(path: path, filename: fileName),
    );
    return '${AppwriteConfig.endpoint}/storage/buckets/${AppwriteConfig.bucketId}/files/${file.$id}/view?project=${AppwriteConfig.projectId}';
  }
}
