import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Global, persisted light/dark mode switch. MaterialApp listens to
/// [mode] and rebuilds its ThemeData whenever it changes, so toggling
/// this actually switches the app's theme app-wide (not just a
/// decorative icon).
class ThemeNotifier {
  static final ValueNotifier<ThemeMode> mode = ValueNotifier(ThemeMode.dark);

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isDay = prefs.getBool('isDayMode') ?? false;
      mode.value = isDay ? ThemeMode.light : ThemeMode.dark;
    } catch (_) {}
  }

  static Future<void> toggle() async {
    final goingToDay = mode.value == ThemeMode.dark;
    mode.value = goingToDay ? ThemeMode.light : ThemeMode.dark;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isDayMode', goingToDay);
    } catch (_) {}
  }

  static bool get isDay => mode.value == ThemeMode.light;
}
