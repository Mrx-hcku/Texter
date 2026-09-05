cat > lib/config/theme.dart << 'FILEEOF'
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Cyberpunk dark palette matching reference design
  static const Color bg = Color(0xFF0B0F14);
  static const Color surface = Color(0xFF141B22);
  static const Color surfaceLight = Color(0xFF1C2530);
  static const Color cyan = Color(0xFF00E5D4);
  static const Color pink = Color(0xFFFF3D6E);
  static const Color primary = cyan;
  static const Color textPrimary = Color(0xFFF2F6F7);
  static const Color textSecondary = Color(0xFF8A96A3);

  static TextStyle heading({double size = 20, Color? color, FontWeight weight = FontWeight.w700}) =>
      GoogleFonts.orbitron(fontSize: size, fontWeight: weight, color: color ?? cyan, letterSpacing: 0.2);

  static TextStyle body({double size = 14, Color? color, FontWeight weight = FontWeight.w400}) =>
      GoogleFonts.inter(fontSize: size, fontWeight: weight, color: color ?? textPrimary);

  static BoxDecoration glowBorder({Color color = cyan, double radius = 100}) => BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
        boxShadow: [BoxShadow(color: color.withOpacity(0.6), blurRadius: 8, spreadRadius: 1)],
      );

  static ThemeData get light => ThemeData(
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
}
FILEEOF

cat > lib/screens/main_nav_screen.dart << 'FILEEOF'
import 'package:flutter/material.dart';
import '../config/theme.dart';
import 'chat_list_screen.dart';
import 'groups_screen.dart';
import 'channels_screen.dart';
import 'profile_screen.dart';

class MainNavScreen extends StatefulWidget {
  const MainNavScreen({super.key});

  @override
  State<MainNavScreen> createState() => _MainNavScreenState();
}

class _MainNavScreenState extends State<MainNavScreen> {
  int _index = 0;

  final _screens = const [
    ChatListScreen(),
    ChannelsScreen(),
    GroupsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: AppTheme.surface,
        indicatorColor: AppTheme.cyan.withOpacity(0.15),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble, color: AppTheme.cyan),
            label: 'Chats',
          ),
          NavigationDestination(
            icon: const Icon(Icons.campaign_outlined),
            selectedIcon: Icon(Icons.campaign, color: AppTheme.cyan),
            label: 'Channels',
          ),
          NavigationDestination(
            icon: const Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups, color: AppTheme.cyan),
            label: 'Groups',
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: AppTheme.cyan),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
FILEEOF

cat > lib/screens/chat_list_screen.dart << 'FILEEOF'
import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:intl/intl.dart';
import '../config/theme.dart';
import '../services/appwrite_service.dart';
import 'one_to_one_chat_screen.dart';
import 'new_chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  List<models.Document> _chats = [];
  String _query = '';
  bool _loading = true;
  String? _myId;
  RealtimeSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _sub?.close();
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
    });
  }

  Widget _storyAvatar(String name, {Color ring = AppTheme.cyan}) {
    return Container(
      margin: const EdgeInsets.only(right: 14),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: AppTheme.glowBorder(color: ring),
            child: CircleAvatar(
              radius: 24,
              backgroundColor: AppTheme.surfaceLight,
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: AppTheme.heading(size: 16, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 56,
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTheme.body(size: 10, color: AppTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    final filtered = _chats.where((c) {
      final name = (c.data['chatName'] ?? '').toString().toLowerCase();
      return name.contains(_query.toLowerCase());
    }).toList();
    final ringColors = [AppTheme.cyan, AppTheme.pink, AppTheme.cyan, AppTheme.pink];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Texter'),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: () {}),
          IconButton(icon: const Icon(Icons.edit_square), onPressed: () async {
            await Navigator.push(context, MaterialPageRoute(builder: (_) => const NewChatScreen()));
            _load();
          }),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        backgroundColor: AppTheme.surface,
        color: AppTheme.cyan,
        child: Column(
          children: [
            if (_chats.isNotEmpty)
              SizedBox(
                height: 92,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _chats.length > 10 ? 10 : _chats.length,
                  itemBuilder: (context, i) {
                    final c = _chats[i];
                    return GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => OneToOneChatScreen(chatId: c.$id, chatName: c.data['chatName'] ?? ''),
                        ),
                      ),
                      child: _storyAvatar(c.data['chatName'] ?? '', ring: ringColors[i % ringColors.length]),
                    );
                  },
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
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
                      ? Center(child: Text('No chats yet', style: AppTheme.body(color: AppTheme.textSecondary)))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: filtered.length,
                          itemBuilder: (context, i) {
                            final c = filtered[i];
                            final name = c.data['chatName'] ?? '';
                            final ring = ringColors[i % ringColors.length];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: AppTheme.surface,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: ListTile(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                leading: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: AppTheme.glowBorder(color: ring),
                                  child: CircleAvatar(
                                    radius: 22,
                                    backgroundColor: AppTheme.surfaceLight,
                                    child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: AppTheme.heading(size: 15, color: Colors.white)),
                                  ),
                                ),
                                title: Text(name, style: AppTheme.body(size: 15, weight: FontWeight.w600, color: Colors.white)),
                                subtitle: Text(
                                  c.data['lastMessage'] ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTheme.body(size: 12.5, color: AppTheme.textSecondary),
                                ),
                                trailing: Text(_formatTime(c), style: AppTheme.body(size: 11, color: AppTheme.textSecondary)),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => OneToOneChatScreen(chatId: c.$id, chatName: name)),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
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

cat > lib/screens/login_screen.dart << 'FILEEOF'
import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/appwrite_service.dart';
import 'main_nav_screen.dart';
import 'verify_email_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _isSignUp = false;
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim().toLowerCase();
    if (!email.endsWith('@gmail.com')) {
      setState(() => _error = 'Only Gmail addresses are allowed (e.g. name@gmail.com)');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_isSignUp) {
        await AppwriteService.instance.signUp(email, _passCtrl.text.trim(), _nameCtrl.text.trim());
        await AppwriteService.instance.sendVerificationEmail();
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const VerifyEmailScreen()),
        );
        return;
      } else {
        await AppwriteService.instance.login(email, _passCtrl.text.trim());
      }
      final user = await AppwriteService.instance.getCurrentUser();
      if (!mounted) return;
      if (user != null && !user.emailVerification) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const VerifyEmailScreen()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainNavScreen()),
        );
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: AppTheme.glowBorder(),
                child: const CircleAvatar(
                  radius: 34,
                  backgroundColor: AppTheme.surfaceLight,
                  child: Icon(Icons.bolt, color: AppTheme.cyan, size: 34),
                ),
              ),
              const SizedBox(height: 16),
              Text('TEXTER', style: AppTheme.heading(size: 36)),
              const SizedBox(height: 6),
              Text(
                _isSignUp ? 'Create your account' : 'Welcome back',
                style: AppTheme.body(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 32),
              if (_isSignUp) ...[
                TextField(
                  controller: _nameCtrl,
                  style: AppTheme.body(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Full Name'),
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                style: AppTheme.body(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Gmail Address'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passCtrl,
                obscureText: _obscure,
                style: AppTheme.body(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Password',
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: AppTheme.textSecondary),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: AppTheme.pink, fontSize: 13)),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.bg),
                      )
                    : Text(_isSignUp ? 'Sign Up' : 'Log In'),
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: () => setState(() => _isSignUp = !_isSignUp),
                  child: Text(
                    _isSignUp ? 'Already have an account? Log In' : "Don't have an account? Sign Up",
                    style: const TextStyle(color: AppTheme.cyan),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
FILEEOF

cat > lib/screens/one_to_one_chat_screen.dart << 'FILEEOF'
import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/theme.dart';
import '../services/appwrite_service.dart';
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

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final user = await AppwriteService.instance.getCurrentUser();
    _myId = user?.$id;
    final docs = await AppwriteService.instance.getMessages(widget.chatId);
    setState(() {
      _messages = docs.map((d) => MessageModel.fromMap(d.data..addAll({'\$id': d.$id, '\$createdAt': d.$createdAt}))).toList();
    });
    _sub = AppwriteService.instance.subscribeToMessages(widget.chatId, (doc) {
      if (_messages.any((m) => m.id == doc.$id)) return;
      setState(() {
        _messages.add(MessageModel.fromMap(doc.data..addAll({'\$id': doc.$id, '\$createdAt': doc.$createdAt})));
      });
    });
  }

  @override
  void dispose() {
    _sub?.close();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _myId == null) return;
    _controller.clear();
    try {
      final doc = await AppwriteService.instance.sendMessage(chatId: widget.chatId, senderId: _myId!, text: text);
      if (!_messages.any((m) => m.id == doc.$id)) {
        setState(() {
          _messages.add(MessageModel.fromMap(doc.data..addAll({'\$id': doc.$id, '\$createdAt': doc.$createdAt})));
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send: $e')));
    }
  }

  Future<void> _attachImage() async {
    if (_myId == null) return;
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;
    setState(() => _uploading = true);
    try {
      final url = await AppwriteService.instance.uploadFile(file.path, file.name);
      final doc = await AppwriteService.instance.sendMessage(
        chatId: widget.chatId,
        senderId: _myId!,
        attachmentUrl: url,
        attachmentType: 'image',
      );
      if (!_messages.any((m) => m.id == doc.$id)) {
        setState(() {
          _messages.add(MessageModel.fromMap(doc.data..addAll({'\$id': doc.$id, '\$createdAt': doc.$createdAt})));
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to upload image: $e')));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _attachFile() async {
    if (_myId == null || _uploading) return;
    final result = await FilePicker.platform.pickFiles(withData: false);
    if (result == null || result.files.single.path == null) return;
    final path = result.files.single.path!;
    final fileName = result.files.single.name;
    setState(() => _uploading = true);
    try {
      final url = await AppwriteService.instance.uploadFile(path, fileName);
      final doc = await AppwriteService.instance.sendMessage(
        chatId: widget.chatId,
        senderId: _myId!,
        text: fileName,
        attachmentUrl: url,
        attachmentType: 'file',
      );
      if (!_messages.any((m) => m.id == doc.$id)) {
        setState(() {
          _messages.add(MessageModel.fromMap(doc.data..addAll({'\$id': doc.$id, '\$createdAt': doc.$createdAt})));
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to upload file: $e')));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _openFile(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open file')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.chatName),
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
                } else if (m.attachmentType == 'file' && m.attachmentUrl.isNotEmpty) {
                  content = InkWell(
                    onTap: () => _openFile(m.attachmentUrl),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.insert_drive_file, color: mine ? AppTheme.bg : AppTheme.cyan),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            m.text.isNotEmpty ? m.text : 'File',
                            style: TextStyle(
                              color: mine ? AppTheme.bg : Colors.white,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                } else {
                  content = Text(m.text, style: TextStyle(color: mine ? AppTheme.bg : Colors.white));
                }
                return AnimatedAlign(
                  duration: const Duration(milliseconds: 200),
                  alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                    decoration: BoxDecoration(
                      color: mine ? AppTheme.cyan : AppTheme.surface,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(mine ? 16 : 4),
                        bottomRight: Radius.circular(mine ? 4 : 16),
                      ),
                      boxShadow: mine
                          ? [BoxShadow(color: AppTheme.cyan.withOpacity(0.25), blurRadius: 8, offset: const Offset(0, 2))]
                          : null,
                    ),
                    child: content,
                  ),
                );
              },
            ),
          ),
          if (_uploading) LinearProgressIndicator(minHeight: 2, color: AppTheme.cyan, backgroundColor: AppTheme.surface),
          SafeArea(
            child: Container(
              color: AppTheme.surface,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  IconButton(icon: const Icon(Icons.image_outlined, color: AppTheme.textSecondary), onPressed: _uploading ? null : _attachImage),
                  IconButton(icon: const Icon(Icons.attach_file, color: AppTheme.textSecondary), onPressed: _uploading ? null : _attachFile),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      style: AppTheme.body(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Message',
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(colors: [AppTheme.cyan, AppTheme.pink]),
                      boxShadow: [BoxShadow(color: AppTheme.cyan.withOpacity(0.4), blurRadius: 8)],
                    ),
                    child: IconButton(icon: const Icon(Icons.send, color: Colors.white, size: 20), onPressed: _send),
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

cat > lib/screens/group_chat_screen.dart << 'FILEEOF'
import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import '../config/theme.dart';
import '../services/appwrite_service.dart';
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
  final Map<String, String> _senderNames = {};
  RealtimeSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _init();
    AdsService.showInterstitial();
  }

  @override
  void dispose() {
    _sub?.close();
    super.dispose();
  }

  Future<void> _init() async {
    final user = await AppwriteService.instance.getCurrentUser();
    _myId = user?.$id;
    try {
      final msgDocs = await AppwriteService.instance.getMessages(widget.groupId);
      final adDocs = await AppwriteService.instance.getAds(targetType: 'group');
      final messages = msgDocs
          .map((d) => MessageModel.fromMap(d.data..addAll({'\$id': d.$id, '\$createdAt': d.$createdAt})))
          .toList();
      await _fetchSenderNames(messages);
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
    _sub = AppwriteService.instance.subscribeToMessages(widget.groupId, (doc) async {
      if (_messages.any((m) => m.id == doc.$id)) return;
      final msg = MessageModel.fromMap(doc.data..addAll({'\$id': doc.$id, '\$createdAt': doc.$createdAt}));
      if (msg.senderId != _myId && !_senderNames.containsKey(msg.senderId)) {
        final u = await AppwriteService.instance.getUserDoc(msg.senderId);
        _senderNames[msg.senderId] = u?.data['name'] ?? 'Unknown';
      }
      if (!mounted) return;
      setState(() => _messages.add(msg));
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
        setState(() {
          _messages.add(MessageModel.fromMap(doc.data..addAll({'\$id': doc.$id, '\$createdAt': doc.$createdAt})));
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final feed = <Widget>[];
    for (int i = 0; i < _messages.length; i++) {
      final m = _messages[i];
      final mine = m.senderId == _myId;
      final senderName = mine ? '' : (_senderNames[m.senderId] ?? '');
      feed.add(Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
          decoration: BoxDecoration(
            color: mine ? AppTheme.cyan : AppTheme.surface,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(mine ? 16 : 4),
              bottomRight: Radius.circular(mine ? 4 : 16),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!mine && senderName.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    senderName,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.pink),
                  ),
                ),
              Text(m.text, style: TextStyle(color: mine ? AppTheme.bg : Colors.white)),
            ],
          ),
        ),
      ));
      if (_ads.isNotEmpty && (i + 1) % 6 == 0) {
        final ad = _ads[(i ~/ 6) % _ads.length];
        feed.add(SponsoredAdCard(ad: ad));
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.groupName)),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.cyan))
          : Column(
              children: [
                Expanded(
                  child: feed.isEmpty
                      ? Center(child: Text('No messages yet — say hi!', style: AppTheme.body(color: AppTheme.textSecondary)))
                      : ListView(padding: const EdgeInsets.all(12), children: feed),
                ),
                SafeArea(
                  child: Container(
                    color: AppTheme.surface,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            style: AppTheme.body(color: Colors.white),
                            decoration: const InputDecoration(hintText: 'Message'),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(colors: [AppTheme.cyan, AppTheme.pink]),
                          ),
                          child: IconButton(icon: const Icon(Icons.send, color: Colors.white, size: 20), onPressed: _send),
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

cat > lib/screens/groups_screen.dart << 'FILEEOF'
import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import '../config/theme.dart';
import '../services/appwrite_service.dart';
import '../models/models.dart';
import 'group_chat_screen.dart';
import 'create_group_screen.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  List<GroupModel> _myGroups = [];
  List<GroupModel> _discoverGroups = [];
  bool _loading = true;
  String? _myId;
  final Set<String> _joining = {};
  RealtimeSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _sub?.close();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final me = await AppwriteService.instance.getCurrentUser();
    _myId = me?.$id;
    try {
      final docs = await AppwriteService.instance.getGroups();
      final all = docs.map((d) => GroupModel.fromMap(d.data..addAll({'\$id': d.$id}))).toList();
      setState(() {
        _myGroups = all.where((g) => g.memberIds.contains(_myId)).toList();
        _discoverGroups = all.where((g) => g.isPublic && !g.memberIds.contains(_myId)).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load groups: $e')));
    }
    _sub ??= AppwriteService.instance.subscribeToCollection('groups', (doc, events) {
      _load();
    });
  }

  Future<void> _join(GroupModel g) async {
    if (_myId == null || _joining.contains(g.id)) return;
    setState(() => _joining.add(g.id));
    try {
      await AppwriteService.instance.joinGroup(groupId: g.id, userId: _myId!);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => GroupChatScreen(groupId: g.id, groupName: g.name)),
      ).then((_) => _load());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not join: $e')));
    } finally {
      if (mounted) setState(() => _joining.remove(g.id));
    }
  }

  Widget _groupTile(GroupModel g, {required bool isMember}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Container(
          padding: const EdgeInsets.all(2),
          decoration: AppTheme.glowBorder(color: AppTheme.cyan),
          child: CircleAvatar(
            radius: 22,
            backgroundColor: AppTheme.surfaceLight,
            child: Text(g.name.isNotEmpty ? g.name[0].toUpperCase() : '?', style: AppTheme.heading(size: 15, color: Colors.white)),
          ),
        ),
        title: Text(g.name, style: AppTheme.body(size: 15, weight: FontWeight.w600, color: Colors.white)),
        subtitle: Text(
          '${g.memberIds.length} members${g.isPublic ? '' : ' · Private'}',
          style: AppTheme.body(size: 12, color: AppTheme.textSecondary),
        ),
        trailing: isMember
            ? const Icon(Icons.chevron_right, color: AppTheme.textSecondary)
            : ElevatedButton(
                onPressed: _joining.contains(g.id) ? null : () => _join(g),
                style: ElevatedButton.styleFrom(minimumSize: const Size(70, 34), padding: EdgeInsets.zero),
                child: _joining.contains(g.id)
                    ? SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.bg))
                    : const Text('Join'),
              ),
        onTap: isMember
            ? () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => GroupChatScreen(groupId: g.id, groupName: g.name)),
                )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Groups'),
        actions: [IconButton(icon: const Icon(Icons.add), onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateGroupScreen()));
          _load();
        })],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.cyan))
          : RefreshIndicator(
              onRefresh: _load,
              backgroundColor: AppTheme.surface,
              color: AppTheme.cyan,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                children: [
                  if (_myGroups.isEmpty && _discoverGroups.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 60),
                      child: Center(child: Text('No groups yet — create one!', style: AppTheme.body(color: AppTheme.textSecondary))),
                    ),
                  if (_myGroups.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
                      child: Text('MY GROUPS', style: AppTheme.body(size: 12, weight: FontWeight.w700, color: AppTheme.cyan)),
                    ),
                    ..._myGroups.map((g) => _groupTile(g, isMember: true)),
                  ],
                  if (_discoverGroups.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
                      child: Text('DISCOVER PUBLIC GROUPS', style: AppTheme.body(size: 12, weight: FontWeight.w700, color: AppTheme.pink)),
                    ),
                    ..._discoverGroups.map((g) => _groupTile(g, isMember: false)),
                  ],
                ],
              ),
            ),
    );
  }
}
FILEEOF

cat > lib/screens/channels_screen.dart << 'FILEEOF'
import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import '../config/theme.dart';
import '../services/appwrite_service.dart';
import '../models/models.dart';
import '../widgets/sponsored_ad_card.dart';
import 'create_channel_screen.dart';
import 'channel_view_screen.dart';

class ChannelsScreen extends StatefulWidget {
  const ChannelsScreen({super.key});

  @override
  State<ChannelsScreen> createState() => _ChannelsScreenState();
}

class _ChannelsScreenState extends State<ChannelsScreen> {
  List<ChannelModel> _channels = [];
  List<AdModel> _ads = [];
  bool _loading = true;
  RealtimeSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _sub?.close();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final chDocs = await AppwriteService.instance.getChannels();
      final adDocs = await AppwriteService.instance.getAds(targetType: 'channel');
      setState(() {
        _channels = chDocs.map((d) => ChannelModel.fromMap(d.data..addAll({'\$id': d.$id}))).toList();
        _ads = adDocs.map((d) => AdModel.fromMap(d.data..addAll({'\$id': d.$id}))).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load channels: $e')));
    }
    _sub ??= AppwriteService.instance.subscribeToCollection('channels', (doc, events) {
      _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final feed = <Widget>[];
    for (int i = 0; i < _channels.length; i++) {
      final c = _channels[i];
      feed.add(Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: AppTheme.glowBorder(color: AppTheme.pink),
              child: CircleAvatar(
                radius: 22,
                backgroundColor: AppTheme.surfaceLight,
                child: Text(c.name.isNotEmpty ? c.name[0].toUpperCase() : '?', style: AppTheme.heading(size: 15, color: Colors.white)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.name, style: AppTheme.body(size: 15, weight: FontWeight.w600, color: Colors.white)),
                  const SizedBox(height: 2),
                  Text('${c.subscriberCount} subscribers', style: AppTheme.body(size: 12, color: AppTheme.textSecondary)),
                ],
              ),
            ),
            TextButton(
              onPressed: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => ChannelViewScreen(channelId: c.id)));
                _load();
              },
              child: const Text('View', style: TextStyle(color: AppTheme.cyan, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ));
      if (_ads.isNotEmpty && (i + 1) % 3 == 0) {
        feed.add(SponsoredAdCard(ad: _ads[(i ~/ 3) % _ads.length]));
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Channels'),
        actions: [IconButton(icon: const Icon(Icons.add), onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateChannelScreen()));
          _load();
        })],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.cyan))
          : RefreshIndicator(
              onRefresh: _load,
              backgroundColor: AppTheme.surface,
              color: AppTheme.cyan,
              child: feed.isEmpty
                  ? ListView(children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 80),
                        child: Center(child: Text('No channels yet', style: AppTheme.body(color: AppTheme.textSecondary))),
                      ),
                    ])
                  : ListView(padding: const EdgeInsets.all(12), children: feed),
            ),
    );
  }
}
FILEEOF

cat > lib/screens/channel_view_screen.dart << 'FILEEOF'
import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import '../config/theme.dart';
import '../services/appwrite_service.dart';
import '../models/models.dart';

class ChannelViewScreen extends StatefulWidget {
  final String channelId;
  const ChannelViewScreen({super.key, required this.channelId});

  @override
  State<ChannelViewScreen> createState() => _ChannelViewScreenState();
}

class _ChannelViewScreenState extends State<ChannelViewScreen> {
  final _controller = TextEditingController();
  List<MessageModel> _posts = [];
  ChannelModel? _channel;
  String? _myId;
  bool _loading = true;
  bool _busy = false;
  RealtimeSubscription? _sub;

  bool get _isSubscribed => _channel != null && _myId != null && _channel!.subscriberIds.contains(_myId);

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _sub?.close();
    super.dispose();
  }

  Future<void> _init() async {
    final user = await AppwriteService.instance.getCurrentUser();
    _myId = user?.$id;
    try {
      final doc = await AppwriteService.instance.databases.getDocument(
        databaseId: 'messgram_db',
        collectionId: 'channels',
        documentId: widget.channelId,
      );
      final posts = await AppwriteService.instance.getMessages(widget.channelId);
      setState(() {
        _channel = ChannelModel.fromMap(doc.data..addAll({'\$id': doc.$id}));
        _posts = posts
            .map((d) => MessageModel.fromMap(d.data..addAll({'\$id': d.$id, '\$createdAt': d.$createdAt})))
            .toList();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load channel: $e')));
    }
    _sub ??= AppwriteService.instance.subscribeToMessages(widget.channelId, (doc) {
      if (_posts.any((p) => p.id == doc.$id)) return;
      if (!mounted) return;
      setState(() {
        _posts.add(MessageModel.fromMap(doc.data..addAll({'\$id': doc.$id, '\$createdAt': doc.$createdAt})));
      });
    });
  }

  Future<void> _toggleSubscribe() async {
    if (_myId == null || _channel == null || _busy) return;
    setState(() => _busy = true);
    try {
      if (_isSubscribed) {
        await AppwriteService.instance.unsubscribeChannel(channelId: widget.channelId, userId: _myId!);
      } else {
        await AppwriteService.instance.subscribeChannel(channelId: widget.channelId, userId: _myId!);
      }
      await _init();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _post() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _myId == null || !_isSubscribed) return;
    _controller.clear();
    try {
      final doc = await AppwriteService.instance.sendMessage(chatId: widget.channelId, senderId: _myId!, text: text);
      if (!_posts.any((p) => p.id == doc.$id)) {
        setState(() {
          _posts.add(MessageModel.fromMap(doc.data..addAll({'\$id': doc.$id, '\$createdAt': doc.$createdAt})));
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to post: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_channel?.name ?? 'Channel')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.cyan))
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  color: AppTheme.surface,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if ((_channel?.description ?? '').isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(_channel!.description, style: AppTheme.body(color: AppTheme.textSecondary)),
                        ),
                      Row(
                        children: [
                          Text('${_channel?.subscriberCount ?? 0} subscribers', style: AppTheme.body(size: 12.5, color: AppTheme.textSecondary)),
                          const Spacer(),
                          ElevatedButton(
                            onPressed: _busy ? null : _toggleSubscribe,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isSubscribed ? AppTheme.surfaceLight : AppTheme.cyan,
                              foregroundColor: _isSubscribed ? Colors.white : AppTheme.bg,
                              minimumSize: const Size(120, 40),
                            ),
                            child: Text(_isSubscribed ? 'Subscribed' : 'Subscribe'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _posts.isEmpty
                      ? Center(child: Text('No posts yet', style: AppTheme.body(color: AppTheme.textSecondary)))
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _posts.length,
                          itemBuilder: (context, i) {
                            final p = _posts[i];
                            return Container(
                              width: double.infinity,
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(14)),
                              child: Text(p.text, style: AppTheme.body(color: Colors.white)),
                            );
                          },
                        ),
                ),
                if (_isSubscribed)
                  SafeArea(
                    child: Container(
                      color: AppTheme.surface,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              style: AppTheme.body(color: Colors.white),
                              decoration: const InputDecoration(hintText: 'Post to channel'),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(colors: [AppTheme.cyan, AppTheme.pink]),
                            ),
                            child: IconButton(icon: const Icon(Icons.send, color: Colors.white, size: 20), onPressed: _post),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text('Subscribe to post in this channel', style: AppTheme.body(color: AppTheme.textSecondary)),
                    ),
                  ),
              ],
            ),
    );
  }
}
FILEEOF

cat > lib/screens/profile_screen.dart << 'FILEEOF'
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/theme.dart';
import '../services/appwrite_service.dart';
import 'login_screen.dart';
import 'account_screen.dart';
import 'notifications_screen.dart';
import 'privacy_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _name = '';
  String _email = '';
  String _avatarUrl = '';
  String _status = '';
  int _groupCount = 0;
  int _channelCount = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = await AppwriteService.instance.getCurrentUser();
    if (user == null) return;
    setState(() {
      _name = user.name;
      _email = user.email;
    });
    try {
      final doc = await AppwriteService.instance.getUserDoc(user.$id);
      final groups = await AppwriteService.instance.getGroups();
      final channels = await AppwriteService.instance.getChannels();
      if (!mounted) return;
      setState(() {
        _avatarUrl = doc?.data['avatarUrl'] ?? '';
        _status = doc?.data['status'] ?? '';
        _groupCount = groups.where((g) => List<String>.from(g.data['memberIds'] ?? []).contains(user.$id)).length;
        _channelCount = channels.where((c) => List<String>.from(c.data['subscriberIds'] ?? []).contains(user.$id)).length;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    await AppwriteService.instance.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Widget _statCard(String value, String label) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.surfaceLight),
        ),
        child: Column(
          children: [
            Text(value, style: AppTheme.heading(size: 20, color: AppTheme.cyan)),
            const SizedBox(height: 2),
            Text(label, style: AppTheme.body(size: 11, color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _tile(IconData icon, String label, {VoidCallback? onTap, Color? color}) {
    return ListTile(
      leading: Icon(icon, color: color ?? AppTheme.cyan),
      title: Text(label, style: AppTheme.body(color: color ?? Colors.white, weight: FontWeight.w500)),
      trailing: const Icon(Icons.chevron_right, size: 18, color: AppTheme.textSecondary),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.cyan))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Center(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: AppTheme.glowBorder(),
                        child: CircleAvatar(
                          radius: 44,
                          backgroundColor: AppTheme.surfaceLight,
                          backgroundImage: _avatarUrl.isNotEmpty ? CachedNetworkImageProvider(_avatarUrl) : null,
                          child: _avatarUrl.isEmpty
                              ? Text(
                                  _name.isNotEmpty ? _name[0].toUpperCase() : '?',
                                  style: AppTheme.heading(size: 32, color: Colors.white),
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text('@$_name', style: AppTheme.heading(size: 18)),
                      const SizedBox(height: 4),
                      Text(
                        _status.isNotEmpty ? _status : _email,
                        style: AppTheme.body(size: 12.5, color: AppTheme.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    _statCard('$_groupCount', 'Groups'),
                    _statCard('$_channelCount', 'Channels'),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    children: [
                      _tile(Icons.account_circle_outlined, 'Account', onTap: () async {
                        await Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountScreen()));
                        _load();
                      }),
                      Divider(height: 1, color: AppTheme.surfaceLight),
                      _tile(Icons.notifications_outlined, 'Notifications', onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
                      }),
                      Divider(height: 1, color: AppTheme.surfaceLight),
                      _tile(Icons.lock_outline, 'Privacy', onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyScreen()));
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(16)),
                  child: _tile(Icons.logout, 'Logout', color: AppTheme.pink, onTap: _logout),
                ),
              ],
            ),
    );
  }
}
FILEEOF

cat > lib/screens/account_screen.dart << 'FILEEOF'
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/theme.dart';
import '../services/appwrite_service.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _nameCtrl = TextEditingController();
  final _statusCtrl = TextEditingController();
  String _email = '';
  String? _userId;
  String _avatarUrl = '';
  bool _loading = true;
  bool _saving = false;
  bool _uploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = await AppwriteService.instance.getCurrentUser();
    if (user == null) return;
    _userId = user.$id;
    _email = user.email;
    _nameCtrl.text = user.name;
    try {
      final doc = await AppwriteService.instance.getUserDoc(user.$id);
      _statusCtrl.text = doc?.data['status'] ?? '';
      _avatarUrl = doc?.data['avatarUrl'] ?? '';
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _pickPhoto() async {
    if (_userId == null || _uploadingPhoto) return;
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, maxWidth: 800, imageQuality: 85);
    if (file == null) return;
    setState(() => _uploadingPhoto = true);
    try {
      final url = await AppwriteService.instance.uploadFile(file.path, file.name);
      await AppwriteService.instance.updateUserProfile(userId: _userId!, avatarUrl: url);
      setState(() => _avatarUrl = url);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile photo updated')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to upload photo: $e')));
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _save() async {
    if (_userId == null || _saving) return;
    setState(() => _saving = true);
    try {
      await AppwriteService.instance.account.updateName(name: _nameCtrl.text.trim());
      await AppwriteService.instance.updateUserProfile(
        userId: _userId!,
        name: _nameCtrl.text.trim(),
        status: _statusCtrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated')));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Account'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text('Save', style: TextStyle(color: AppTheme.cyan, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.cyan))
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: GestureDetector(
                      onTap: _pickPhoto,
                      child: Stack(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: AppTheme.glowBorder(),
                            child: CircleAvatar(
                              radius: 50,
                              backgroundColor: AppTheme.surfaceLight,
                              backgroundImage: _avatarUrl.isNotEmpty ? CachedNetworkImageProvider(_avatarUrl) : null,
                              child: _avatarUrl.isEmpty
                                  ? Text(
                                      _nameCtrl.text.isNotEmpty ? _nameCtrl.text[0].toUpperCase() : '?',
                                      style: AppTheme.heading(size: 36, color: Colors.white),
                                    )
                                  : null,
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(color: AppTheme.cyan, shape: BoxShape.circle),
                              child: _uploadingPhoto
                                  ? SizedBox(
                                      height: 16,
                                      width: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.bg),
                                    )
                                  : Icon(Icons.camera_alt, size: 16, color: AppTheme.bg),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _nameCtrl,
                    style: AppTheme.body(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Full Name'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _statusCtrl,
                    style: AppTheme.body(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Status / About'),
                  ),
                  const SizedBox(height: 12),
                  Text('Email: $_email', style: AppTheme.body(color: AppTheme.textSecondary)),
                ],
              ),
            ),
    );
  }
}
FILEEOF

cat > lib/screens/notifications_screen.dart << 'FILEEOF'
import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/appwrite_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  Map<String, bool> _prefs = {'messages': true, 'groups': true, 'channels': true, 'sound': true};
  String? _userId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = await AppwriteService.instance.getCurrentUser();
    if (user == null) return;
    _userId = user.$id;
    try {
      final doc = await AppwriteService.instance.getUserDoc(user.$id);
      setState(() {
        _prefs = AppwriteService.instance.parseNotificationPrefs(doc?.data['notifPrefs']);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _set(String key, bool value) async {
    setState(() => _prefs[key] = value);
    if (_userId == null) return;
    try {
      await AppwriteService.instance.updateNotificationPrefs(_userId!, _prefs);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
    }
  }

  Widget _switchTile(String key, String label) {
    return SwitchListTile(
      activeColor: AppTheme.cyan,
      title: Text(label, style: AppTheme.body(color: Colors.white)),
      value: _prefs[key] ?? true,
      onChanged: (v) => _set(key, v),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.cyan))
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Container(
                  decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    children: [
                      _switchTile('messages', 'Message notifications'),
                      Divider(height: 1, color: AppTheme.surfaceLight),
                      _switchTile('groups', 'Group notifications'),
                      Divider(height: 1, color: AppTheme.surfaceLight),
                      _switchTile('channels', 'Channel notifications'),
                      Divider(height: 1, color: AppTheme.surfaceLight),
                      _switchTile('sound', 'Sound'),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'These preferences are saved to your account. Actual push delivery requires notification setup, which is not yet enabled for this app.',
                    style: AppTheme.body(size: 12, color: AppTheme.textSecondary),
                  ),
                ),
              ],
            ),
    );
  }
}
FILEEOF

cat > lib/screens/privacy_screen.dart << 'FILEEOF'
import 'package:flutter/material.dart';
import '../config/theme.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.chat_bubble_outline, color: AppTheme.cyan),
                  title: Text('Last Seen & Online', style: AppTheme.body(color: Colors.white)),
                  subtitle: Text('Everyone can see when you were last online', style: AppTheme.body(size: 12, color: AppTheme.textSecondary)),
                ),
                Divider(height: 1, color: AppTheme.surfaceLight),
                ListTile(
                  leading: const Icon(Icons.photo_outlined, color: AppTheme.cyan),
                  title: Text('Profile Photo', style: AppTheme.body(color: Colors.white)),
                  subtitle: Text('Everyone can see your profile photo', style: AppTheme.body(size: 12, color: AppTheme.textSecondary)),
                ),
                Divider(height: 1, color: AppTheme.surfaceLight),
                ListTile(
                  leading: const Icon(Icons.groups_outlined, color: AppTheme.cyan),
                  title: Text('Groups', style: AppTheme.body(color: Colors.white)),
                  subtitle: Text('Anyone can add you to public groups', style: AppTheme.body(size: 12, color: AppTheme.textSecondary)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Your account data is stored securely with Appwrite. Messages are only visible to chat participants.',
              style: AppTheme.body(size: 12, color: AppTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
FILEEOF

cat > lib/screens/new_chat_screen.dart << 'FILEEOF'
import 'package:flutter/material.dart';
import 'package:appwrite/models.dart' as models;
import '../config/theme.dart';
import '../services/appwrite_service.dart';
import 'one_to_one_chat_screen.dart';

class NewChatScreen extends StatefulWidget {
  const NewChatScreen({super.key});

  @override
  State<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  List<models.Document> _users = [];
  bool _loading = true;
  String? _myId;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load([String query = '']) async {
    setState(() => _loading = true);
    final me = await AppwriteService.instance.getCurrentUser();
    _myId = me?.$id;
    final users = await AppwriteService.instance.searchUsers(query, excludeId: _myId);
    setState(() {
      _users = users;
      _loading = false;
    });
  }

  Future<void> _startChat(models.Document user) async {
    if (_myId == null || _starting) return;
    setState(() => _starting = true);
    try {
      final chat = await AppwriteService.instance.findOrCreateDirectChat(
        myId: _myId!,
        otherId: user.$id,
        otherName: user.data['name'] ?? '',
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => OneToOneChatScreen(chatId: chat.$id, chatName: user.data['name'] ?? ''),
        ),
      );
    } catch (e) {
      setState(() => _starting = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not start chat: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Chat')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              onChanged: _load,
              style: AppTheme.body(color: Colors.white),
              decoration: const InputDecoration(hintText: 'Search by name', prefixIcon: Icon(Icons.search, color: AppTheme.textSecondary)),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.cyan))
                : _users.isEmpty
                    ? Center(child: Text('No users found', style: AppTheme.body(color: AppTheme.textSecondary)))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: _users.length,
                        itemBuilder: (context, i) {
                          final u = _users[i];
                          final name = u.data['name'] ?? '';
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(14)),
                            child: ListTile(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              leading: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: AppTheme.glowBorder(),
                                child: CircleAvatar(
                                  backgroundColor: AppTheme.surfaceLight,
                                  child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: AppTheme.heading(size: 14, color: Colors.white)),
                                ),
                              ),
                              title: Text(name, style: AppTheme.body(color: Colors.white, weight: FontWeight.w600)),
                              subtitle: Text(u.data['email'] ?? '', style: AppTheme.body(size: 12, color: AppTheme.textSecondary)),
                              onTap: () => _startChat(u),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
FILEEOF

cat > lib/screens/verify_email_screen.dart << 'FILEEOF'
import 'dart:async';
import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/appwrite_service.dart';
import 'main_nav_screen.dart';
import 'login_screen.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> with WidgetsBindingObserver {
  bool _resending = false;
  String _email = '';
  Timer? _pollTimer;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadEmail();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _checkVerified());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkVerified();
    }
  }

  Future<void> _loadEmail() async {
    final user = await AppwriteService.instance.getCurrentUser();
    if (user != null && mounted) setState(() => _email = user.email);
  }

  Future<void> _resend() async {
    setState(() => _resending = true);
    try {
      await AppwriteService.instance.sendVerificationEmail();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Verification email sent')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  Future<void> _checkVerified() async {
    if (_navigated) return;
    final user = await AppwriteService.instance.getCurrentUser();
    if (!mounted || _navigated) return;
    if (user != null && user.emailVerification) {
      _navigated = true;
      _pollTimer?.cancel();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainNavScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: AppTheme.glowBorder(color: AppTheme.pink),
                child: const Icon(Icons.mark_email_unread_outlined, size: 48, color: AppTheme.pink),
              ),
              const SizedBox(height: 24),
              Text('VERIFY YOUR GMAIL', style: AppTheme.heading(size: 20)),
              const SizedBox(height: 10),
              Text(
                "We sent a verification link to $_email. Open Gmail, tap the link — this screen will continue automatically once verified.",
                textAlign: TextAlign.center,
                style: AppTheme.body(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 28),
              const CircularProgressIndicator(color: AppTheme.cyan, strokeWidth: 2),
              const SizedBox(height: 24),
              TextButton(
                onPressed: _resending ? null : _resend,
                child: Text(_resending ? 'Sending...' : 'Resend email', style: const TextStyle(color: AppTheme.cyan)),
              ),
              TextButton(
                onPressed: () async {
                  await AppwriteService.instance.logout();
                  if (!mounted) return;
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                },
                child: Text('Use a different account', style: AppTheme.body(color: AppTheme.textSecondary)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
FILEEOF

cat > lib/screens/create_group_screen.dart << 'FILEEOF'
import 'package:flutter/material.dart';
import 'package:appwrite/models.dart' as models;
import '../config/theme.dart';
import '../services/appwrite_service.dart';
import 'group_chat_screen.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  List<models.Document> _users = [];
  final Set<String> _selected = {};
  String? _myId;
  bool _loading = true;
  bool _creating = false;
  bool _isPublic = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final me = await AppwriteService.instance.getCurrentUser();
    _myId = me?.$id;
    final users = await AppwriteService.instance.searchUsers('', excludeId: _myId);
    setState(() {
      _users = users;
      _loading = false;
    });
  }

  Future<void> _create() async {
    if (_nameCtrl.text.trim().isEmpty || _myId == null || _creating) return;
    setState(() => _creating = true);
    try {
      final members = [_myId!, ..._selected];
      final group = await AppwriteService.instance.createGroup(
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        memberIds: members,
        creatorId: _myId!,
        isPublic: _isPublic,
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => GroupChatScreen(groupId: group.$id, groupName: group.data['name'])),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to create group: $e')));
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Group'),
        actions: [
          TextButton(
            onPressed: _creating ? null : _create,
            child: Text('Create', style: TextStyle(color: AppTheme.cyan, fontWeight: FontWeight.bold, fontSize: _creating ? 0 : 16)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.cyan))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  controller: _nameCtrl,
                  style: AppTheme.body(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Group Name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descCtrl,
                  style: AppTheme.body(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Description (optional)'),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(14)),
                  child: SwitchListTile(
                    activeColor: AppTheme.cyan,
                    value: _isPublic,
                    title: Text('Public group', style: AppTheme.body(color: Colors.white)),
                    subtitle: Text(
                      _isPublic ? 'Anyone can find and join this group' : 'Only people you add can join',
                      style: AppTheme.body(size: 12, color: AppTheme.textSecondary),
                    ),
                    onChanged: (v) => setState(() => _isPublic = v),
                  ),
                ),
                const SizedBox(height: 16),
                Text('ADD MEMBERS', style: AppTheme.body(size: 12, weight: FontWeight.w700, color: AppTheme.cyan)),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(14)),
                  child: Column(
                    children: _users.map((u) {
                      final name = u.data['name'] ?? '';
                      final selected = _selected.contains(u.$id);
                      return CheckboxListTile(
                        value: selected,
                        onChanged: (v) => setState(() {
                          if (v == true) {
                            _selected.add(u.$id);
                          } else {
                            _selected.remove(u.$id);
                          }
                        }),
                        activeColor: AppTheme.cyan,
                        checkColor: AppTheme.bg,
                        title: Text(name, style: AppTheme.body(color: Colors.white)),
                        secondary: CircleAvatar(
                          backgroundColor: AppTheme.surfaceLight,
                          child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: AppTheme.heading(size: 14, color: Colors.white)),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
    );
  }
}
FILEEOF

cat > lib/screens/create_channel_screen.dart << 'FILEEOF'
import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/appwrite_service.dart';
import 'channels_screen.dart';

class CreateChannelScreen extends StatefulWidget {
  const CreateChannelScreen({super.key});

  @override
  State<CreateChannelScreen> createState() => _CreateChannelScreenState();
}

class _CreateChannelScreenState extends State<CreateChannelScreen> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _creating = false;

  Future<void> _create() async {
    if (_nameCtrl.text.trim().isEmpty || _creating) return;
    setState(() => _creating = true);
    final me = await AppwriteService.instance.getCurrentUser();
    if (me == null) return;
    await AppwriteService.instance.createChannel(
      name: _nameCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      creatorId: me.$id,
    );
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ChannelsScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Channel'),
        actions: [
          TextButton(
            onPressed: _creating ? null : _create,
            child: const Text('Create', style: TextStyle(color: AppTheme.cyan, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _nameCtrl,
              style: AppTheme.body(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Channel Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descCtrl,
              style: AppTheme.body(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Description (optional)'),
            ),
          ],
        ),
      ),
    );
  }
}
FILEEOF

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

cat > lib/services/appwrite_service.dart << 'FILEEOF'
import 'dart:convert';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import '../config/app_config.dart';

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

  Future<void> logout() => account.deleteSession(sessionId: 'current');

  Future<models.User?> getCurrentUser() async {
    try {
      return await account.get();
    } catch (_) {
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
  Future<List<models.Document>> getChats(String userId) async {
    final res = await databases.listDocuments(
      databaseId: AppwriteConfig.databaseId,
      collectionId: AppwriteConfig.chatsCollection,
      queries: [Query.search('participantIds', userId)],
    );
    return res.documents;
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
  /// [otherName] is used only as the chat's display name if a new chat
  /// document has to be created.
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

  // ---------------- USERS ----------------
  Future<List<models.Document>> searchUsers(String query, {String? excludeId}) async {
    final queries = <String>[Query.limit(50)];
    if (query.trim().isNotEmpty) queries.add(Query.search('name', query.trim()));
    final res = await databases.listDocuments(
      databaseId: AppwriteConfig.databaseId,
      collectionId: AppwriteConfig.usersCollection,
      queries: queries,
    );
    if (excludeId == null) return res.documents;
    return res.documents.where((d) => d.$id != excludeId).toList();
  }

  Future<models.Document?> getUserDoc(String userId) async {
    try {
      return await databases.getDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.usersCollection,
        documentId: userId,
      );
    } catch (_) {
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
  Future<List<models.Document>> getMessages(String chatId) async {
    final res = await databases.listDocuments(
      databaseId: AppwriteConfig.databaseId,
      collectionId: AppwriteConfig.messagesCollection,
      queries: [
        Query.equal('chatId', chatId),
        Query.orderAsc('\$createdAt'),
        Query.limit(200),
      ],
    );
    return res.documents;
  }

  Future<models.Document> sendMessage({
    required String chatId,
    required String senderId,
    String text = '',
    String attachmentUrl = '',
    String attachmentType = '',
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
      },
    );
    // Best-effort: only relevant for direct chats stored in the `chats`
    // collection. Groups/channels use their own doc ID as chatId and
    // don't have a matching `chats` document, so this must not fail send.
    try {
      await databases.updateDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.chatsCollection,
        documentId: chatId,
        data: {
          'lastMessage': text.isNotEmpty ? text : 'Attachment',
        },
      );
    } catch (_) {}
    return doc;
  }

  RealtimeSubscription subscribeToMessages(String chatId, Function(models.Document) onMessage) {
    final sub = realtime.subscribe([
      'databases.${AppwriteConfig.databaseId}.collections.${AppwriteConfig.messagesCollection}.documents'
    ]);
    sub.stream.listen((event) {
      final data = event.payload;
      if (data['chatId'] == chatId && event.events.any((e) => e.contains('create'))) {
        onMessage(models.Document.fromMap(data));
      }
    });
    return sub;
  }

  /// Generic realtime listener for a whole collection — calls [onChange]
  /// with the changed document and its Appwrite event list (e.g.
  /// ["...documents.*.create"]) on every create/update/delete.
  RealtimeSubscription subscribeToCollection(
    String collectionId,
    void Function(models.Document doc, List<String> events) onChange,
  ) {
    final sub = realtime.subscribe([
      'databases.${AppwriteConfig.databaseId}.collections.$collectionId.documents'
    ]);
    sub.stream.listen((event) {
      onChange(models.Document.fromMap(event.payload), event.events);
    });
    return sub;
  }

  // ---------------- GROUPS ----------------
  Future<List<models.Document>> getGroups() async {
    final res = await databases.listDocuments(
      databaseId: AppwriteConfig.databaseId,
      collectionId: AppwriteConfig.groupsCollection,
    );
    return res.documents;
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

  // ---------------- CHANNELS ----------------
  Future<List<models.Document>> getChannels() async {
    final res = await databases.listDocuments(
      databaseId: AppwriteConfig.databaseId,
      collectionId: AppwriteConfig.channelsCollection,
    );
    return res.documents;
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
  Future<List<models.Document>> getAds({String? targetType}) async {
    final queries = <String>[];
    if (targetType != null) queries.add(Query.equal('targetType', targetType));
    final res = await databases.listDocuments(
      databaseId: AppwriteConfig.databaseId,
      collectionId: AppwriteConfig.adsCollection,
      queries: queries,
    );
    return res.documents;
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
FILEEOF

