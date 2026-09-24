import 'package:flutter/material.dart';

class AppTheme {
  // Cyberpunk dark palette (night mode)
  static const Color bg = Color(0xFF0B0F14);
  static const Color surface = Color(0xFF141B22);
  static const Color surfaceLight = Color(0xFF1C2530);
  static const Color cyan = Color(0xFF00E5D4);
  static const Color pink = Color(0xFFFF3D6E);
  static const Color primary = cyan;
  static const Color textPrimary = Color(0xFFF2F6F7);
  static const Color textSecondary = Color(0xFF8A96A3);

  // Day/light palette
  static const Color dayBg = Color(0xFFF5F7F8);
  static const Color daySurface = Color(0xFFFFFFFF);
  static const Color daySurfaceLight = Color(0xFFECEFF1);
  static const Color dayTextPrimary = Color(0xFF14181D);
  static const Color dayTextSecondary = Color(0xFF6B7480);

  static TextStyle heading({double size = 20, Color? color, FontWeight weight = FontWeight.w700}) =>
      TextStyle(fontSize: size, fontWeight: weight, color: color ?? cyan, letterSpacing: 0.2);

  static TextStyle body({double size = 14, Color? color, FontWeight weight = FontWeight.w400}) =>
      TextStyle(fontSize: size, fontWeight: weight, color: color ?? textPrimary);

  static BoxDecoration glowBorder({Color color = cyan, double radius = 100}) => BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
        boxShadow: [BoxShadow(color: color.withOpacity(0.6), blurRadius: 8, spreadRadius: 1)],
      );

  static ThemeData get dark => ThemeData(
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
        textTheme: ThemeData.dark().textTheme.copyWith(
          titleLarge: TextStyle(fontWeight: FontWeight.w700, color: cyan),
          titleMedium: TextStyle(fontWeight: FontWeight.w600, color: cyan),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: bg,
          foregroundColor: cyan,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: cyan),
          surfaceTintColor: Colors.transparent,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: cyan,
            foregroundColor: bg,
            minimumSize: const Size.fromHeight(52),
            elevation: 0,
            textStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
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
          hintStyle: TextStyle(color: textSecondary, fontSize: 14),
          labelStyle: TextStyle(color: textSecondary, fontSize: 13),
        ),
        cardTheme: CardThemeData(
          color: surface,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: surface,
          indicatorColor: cyan.withOpacity(0.15),
          labelTextStyle: WidgetStateProperty.all(TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: cyan)),
          iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
                color: states.contains(WidgetState.selected) ? cyan : textSecondary,
              )),
          elevation: 0,
        ),
        dividerColor: surfaceLight,
      );

  static ThemeData get dayTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: cyan,
          primary: cyan,
          secondary: pink,
          brightness: Brightness.light,
          surface: daySurface,
        ),
        scaffoldBackgroundColor: dayBg,
        textTheme: ThemeData.light().textTheme.copyWith(
          titleLarge: TextStyle(fontWeight: FontWeight.w700, color: dayTextPrimary),
          titleMedium: TextStyle(fontWeight: FontWeight.w600, color: dayTextPrimary),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: daySurface,
          foregroundColor: dayTextPrimary,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: dayTextPrimary),
          surfaceTintColor: Colors.transparent,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: cyan,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(52),
            elevation: 0,
            textStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: daySurfaceLight,
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: daySurfaceLight),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: cyan, width: 1.6),
          ),
          hintStyle: TextStyle(color: dayTextSecondary, fontSize: 14),
          labelStyle: TextStyle(color: dayTextSecondary, fontSize: 13),
        ),
        cardTheme: CardThemeData(
          color: daySurface,
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: daySurface,
          indicatorColor: cyan.withOpacity(0.15),
          labelTextStyle: WidgetStateProperty.all(TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: dayTextPrimary)),
          iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
                color: states.contains(WidgetState.selected) ? cyan : dayTextSecondary,
              )),
          elevation: 0,
        ),
        dividerColor: daySurfaceLight,
      );
}
