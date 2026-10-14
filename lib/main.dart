import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config/theme.dart';
import 'services/appwrite_service.dart';
import 'services/ads_service.dart';
import 'services/theme_notifier.dart';
import 'services/net_utils.dart';
import 'screens/login_screen.dart';
import 'screens/main_nav_screen.dart';
import 'screens/verify_email_screen.dart';

/// Must be a top-level (or static) function — Firebase calls this in a
/// separate isolate when a push notification arrives while the app is fully
/// closed or in the background.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase/Android already shows the notification itself using the
  // payload's "notification" block, so there's nothing to do here — this
  // handler just needs to exist for background delivery to work at all.
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
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
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
  bool _isLocked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setOnline(true);
    _checkAppLockOnStart();
  }

  Future<void> _checkAppLockOnStart() async {
    final prefs = await SharedPreferences.getInstance();
    final lockEnabled = prefs.getBool('app_lock_enabled') ?? false;
    if (lockEnabled) {
      setState(() => _isLocked = true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _setOnline(false);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    _setOnline(state == AppLifecycleState.resumed);

    if (state == AppLifecycleState.resumed) {
      final prefs = await SharedPreferences.getInstance();
      final lockEnabled = prefs.getBool('app_lock_enabled') ?? false;
      if (lockEnabled) {
        setState(() => _isLocked = true);
      }
    }
  }

  Future<void> _setOnline(bool online) async {
    try {
      final user = await AppwriteService.instance.getCurrentUser();
      if (user != null) {
        AppwriteService.instance.updateOnlineStatus(user.$id, online);
        if (online) {
          AppwriteService.instance.registerPushTarget();
          AppwriteService.instance.listenForTokenRefresh();
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
          title: 'Texter',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dayTheme,
          darkTheme: AppTheme.dark,
          themeMode: mode,
          home: Stack(
            children: [
              const _AuthGate(),
              if (_isLocked)
                Scaffold(
                  backgroundColor: AppTheme.bg,
                  body: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.lock_rounded, size: 64, color: AppTheme.cyan),
                          const SizedBox(height: 16),
                          Text('App is Locked', style: AppTheme.heading(size: 22, color: Colors.white)),
                          const SizedBox(height: 8),
                          Text('Tap below to unlock your application session', style: AppTheme.body(color: AppTheme.textSecondary), textAlign: TextAlign.center),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.cyan,
                              foregroundColor: AppTheme.bg,
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () => setState(() => _isLocked = false),
                            child: const Text('Unlock App', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
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
