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
