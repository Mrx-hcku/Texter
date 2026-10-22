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
    return account.createEmailPasswordSession(email: email, password: password);
  }

  Future<void> logout() async {
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
          'lastMessage': text.isNotEmpty ? text : 'Attachment',
          'unreadFor': recipients.join(','),
        },
      );
    } catch (_) {}
    _notifyPush(chatId: chatId, senderId: senderId, text: text, type: attachmentType.isNotEmpty ? attachmentType : 'text');
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

  Future<models.Document> createGroup({
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

  Future<void> joinGroup({required String groupId, required String userId}) async {
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

  Future<void> leaveGroup({required String groupId, required String userId}) async {
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

  Future<void> pinMessage({required String groupId, required String messageId}) {
    return databases.updateDocument(
      databaseId: AppwriteConfig.databaseId,
      collectionId: AppwriteConfig.groupsCollection,
      documentId: groupId,
      data: {'pinnedMessageId': messageId},
    );
  }

  Future<void> unpinMessage(String groupId) {
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

  Future<models.Document> createChannel({
    required String name,
    required String description,
    required String creatorId,
  }) {
    return databases.createDocument(
      databaseId: AppwriteConfig.databaseId,
      collectionId: AppwriteConfig.channelsCollection,
      documentId: ID.unique(),
      data: {
        'name': name,
        'description': description,
        'avatarUrl': '',
        'subscriberCount': 1,
        'subscriberIds': [creatorId],
      },
    );
  }

  Future<void> subscribeChannel({required String channelId, required String userId}) async {
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

  Future<void> unsubscribeChannel({required String channelId, required String userId}) async {
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
