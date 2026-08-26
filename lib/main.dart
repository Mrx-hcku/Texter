import 'package:flutter/material.dart';
import 'config/theme.dart';
import 'services/appwrite_service.dart';
import 'services/ads_service.dart';
import 'screens/login_screen.dart';
import 'screens/main_nav_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  AdsService.init();
  runApp(const TexterApp());
}

class TexterApp extends StatelessWidget {
  const TexterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Texter',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const _AuthGate(),
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
        if (snapshot.data != null) {
          return const MainNavScreen();
        }
        return const LoginScreen();
      },
    );
  }
}
