import 'package:flutter/material.dart';
import 'services/theme_notifier.dart';
import 'services/ads_service.dart';

void main() async {
  // 1. Flutter bindings initialize karna zaroori hai
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Theme load karein (safe try-catch ke sath)
  try {
    await ThemeNotifier.load();
  } catch (e) {
    debugPrint("Theme load error: $e");
  }

  // 3. Ads service initialize karein (safe check ke sath)
  try {
    await AdsService.init();
  } catch (e) {
    debugPrint("Ads init error: $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeNotifier.mode,
      builder: (context, currentMode, child) {
        return MaterialApp(
          title: 'Texter',
          debugShowCheckedModeBanner: false,
          themeMode: currentMode,
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          home: const Scaffold(
            body: Center(
              child: Text('Texter App Running Successfully!'),
            ),
          ),
        );
      },
    );
  }
}
