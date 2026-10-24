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
  static const Color dayBg = Color(0xFFEEF3F3);
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

/// Colours for the chat screens. Night mode keeps the exact look it had;
/// day mode uses soft, low-glare colours (mint bubbles, off-white background,
/// dark-slate text) so long chats don't strain the eyes.
class ChatPalette {
  const ChatPalette({
    required this.chatBg,
    required this.mineBubble,
    required this.mineBorder,
    required this.mineText,
    required this.otherBubble,
    required this.otherBorder,
    required this.otherText,
    required this.panel,
    required this.inputBar,
    required this.inputText,
    required this.inputHint,
    required this.accent,
    required this.quoteBg,
    required this.quoteText,
    required this.sheet,
    required this.sheetBorder,
    required this.sheetChip,
    required this.sheetText,
    required this.sheetIcon,
  });

  final Color chatBg;
  final Color mineBubble;
  final Color mineBorder;
  final Color mineText;
  final Color otherBubble;
  final Color otherBorder;
  final Color otherText;
  final Color panel;
  final Color inputBar;
  final Color inputText;
  final Color inputHint;
  final Color accent;
  final Color quoteBg;
  final Color quoteText;
  final Color sheet;
  final Color sheetBorder;
  final Color sheetChip;
  final Color sheetText;
  final Color sheetIcon;

  static const ChatPalette dark = ChatPalette(
    chatBg: AppTheme.bg,
    mineBubble: Color(0xFF1E222B),
    mineBorder: Color(0xFF2A2E39),
    mineText: Colors.white,
    otherBubble: AppTheme.surface,
    otherBorder: Color(0xFF2A2E39),
    otherText: Colors.white,
    panel: AppTheme.surfaceLight,
    inputBar: Color(0xFF1E222B),
    inputText: Colors.white,
    inputHint: Color(0xFF9E9E9E),
    accent: Color(0xFF00E5FF),
    quoteBg: Color(0x38000000),
    quoteText: Color(0xFFE0E0E0),
    sheet: Color(0xFF161922),
    sheetBorder: Color(0xFF2A2E39),
    sheetChip: Color(0xFF232733),
    sheetText: Colors.white,
    sheetIcon: Color(0xB3FFFFFF),
  );

  static const ChatPalette light = ChatPalette(
    chatBg: Color(0xFFEEF3F3),
    mineBubble: Color(0xFFD6EFEA),
    mineBorder: Color(0xFFBADDD6),
    mineText: Color(0xFF10302C),
    otherBubble: Color(0xFFFBFCFC),
    otherBorder: Color(0xFFDDE4E6),
    otherText: Color(0xFF1C262B),
    panel: Color(0xFFE4EBED),
    inputBar: Color(0xFFFAFBFB),
    inputText: Color(0xFF1C262B),
    inputHint: Color(0xFF8A96A3),
    accent: Color(0xFF008F85),
    quoteBg: Color(0x0F000000),
    quoteText: Color(0xFF4A5A60),
    sheet: Color(0xFFFAFBFB),
    sheetBorder: Color(0xFFDDE4E6),
    sheetChip: Color(0xFFE4EBED),
    sheetText: Color(0xFF1C262B),
    sheetIcon: Color(0xFF5B6770),
  );

  static ChatPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}


/// Colours for the normal (non-chat) screens: lists, cards, profile, nav bar.
/// Night mode keeps its current look; day mode is soft and low-glare.
class UiPalette {
  const UiPalette({
    required this.card,
    required this.cardAlt,
    required this.border,
    required this.text,
    required this.subtext,
    required this.accent,
  });

  final Color card;
  final Color cardAlt;
  final Color border;
  final Color text;
  final Color subtext;
  final Color accent;

  static const UiPalette dark = UiPalette(
    card: AppTheme.surface,
    cardAlt: AppTheme.surfaceLight,
    border: Color(0xFF222B35),
    text: Colors.white,
    subtext: AppTheme.textSecondary,
    accent: AppTheme.cyan,
  );

  static const UiPalette light = UiPalette(
    card: Color(0xFFFBFCFC),
    cardAlt: Color(0xFFE4EBED),
    border: Color(0xFFDDE4E6),
    text: Color(0xFF1C262B),
    subtext: Color(0xFF6B7480),
    accent: Color(0xFF008F85),
  );

  static UiPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

/// A stable colour family per name (so every group / channel keeps its own
/// tint), used for the gradient cards on the Groups and Channels tabs.
class NameTint {
  static double _hue(String name) {
    var h = 0;
    for (final c in name.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return (h % 12) * 30.0;
  }

  static List<Color> gradient(String name, bool dark) {
    final h = _hue(name);
    if (dark) {
      return [
        HSLColor.fromAHSL(1, h, 0.55, 0.28).toColor(),
        HSLColor.fromAHSL(1, (h + 35) % 360, 0.60, 0.16).toColor(),
      ];
    }
    return [
      HSLColor.fromAHSL(1, h, 0.65, 0.90).toColor(),
      HSLColor.fromAHSL(1, (h + 35) % 360, 0.70, 0.82).toColor(),
    ];
  }

  static Color accent(String name, bool dark) =>
      HSLColor.fromAHSL(1, _hue(name), 0.65, dark ? 0.65 : 0.32).toColor();
}
