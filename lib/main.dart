import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'config/theme.dart';
import 'services/appwrite_service.dart';
import 'services/ads_service.dart';
import 'services/theme_notifier.dart';
import 'screens/login_screen.dart';
import 'screens/main_nav_screen.dart';
import 'screens/verify_email_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  // 1. UI / Framework errors ko pakad kar screen par dikhane ke liye
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.dumpErrorToConsole(details);
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
    try {
      final user = await AppwriteService.instance.getCurrentUser();
      if (user != null) {
        AppwriteService.instance.updateOnlineStatus(user.$id, online);
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
