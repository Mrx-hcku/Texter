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
