// Uygulama renk teması ve tema uzantıları.
import 'package:flutter/material.dart';

// BuildContext üzerinden VibeThemeExtension erişimi
extension VibeThemeContext on BuildContext {
  VibeThemeExtension get vibe =>
      Theme.of(this).extension<VibeThemeExtension>() ??
      VibeThemeExtension.dark;
}

// VibeLife'a özel tema renkleri ve dekorasyonları
@immutable
class VibeThemeExtension extends ThemeExtension<VibeThemeExtension> {
  final Color gradientStart;
  final Color gradientEnd;
  final Color cardColor;
  final Color cardBorder;
  final Color mutedText;
  final Color subtleText;
  final Color faintText;
  final Color sheetBackground;
  final Color inputFill;
  final Color dialogBackground;
  final Color primaryButton;
  final Color titleOnGradient;
  final bool isDark;

  const VibeThemeExtension({
    required this.gradientStart,
    required this.gradientEnd,
    required this.cardColor,
    required this.cardBorder,
    required this.mutedText,
    required this.subtleText,
    required this.faintText,
    required this.sheetBackground,
    required this.inputFill,
    required this.dialogBackground,
    required this.primaryButton,
    required this.titleOnGradient,
    required this.isDark,
  });

  static const dark = VibeThemeExtension( // Koyu tema paleti
    gradientStart: Color.fromARGB(255, 40, 0, 0),
    gradientEnd: Color.fromARGB(255, 15, 0, 38),
    cardColor: Color(0x12FFFFFF),
    cardBorder: Color(0x1FFFFFFF),
    mutedText: Color(0x8AFFFFFF),
    subtleText: Color(0xB3FFFFFF),
    faintText: Color(0x61FFFFFF),
    sheetBackground: Color(0xFF1A002E),
    inputFill: Color(0x1AFFFFFF),
    dialogBackground: Color(0xFF1A002E),
    primaryButton: Color.fromARGB(255, 120, 0, 0),
    titleOnGradient: Color.fromARGB(200, 237, 237, 237),
    isDark: true,
  );

  static const light = VibeThemeExtension( // Açık tema paleti
    gradientStart: Color(0xFFFFE8F0),
    gradientEnd: Color(0xFFF0E8FA),
    cardColor: Color(0xFFFFFFFF),
    cardBorder: Color(0x1A6B5B7A),
    mutedText: Color(0xFF2D2538),
    subtleText: Color(0xFF18131F),
    faintText: Color(0xFF3F334D),
    sheetBackground: Color(0xFFFDFBFF),
    inputFill: Color(0xFFFFFFFF),
    dialogBackground: Color(0xFFFDFBFF),
    primaryButton: Color.fromARGB(255, 120, 0, 0),
    titleOnGradient: Color(0xFF1A1025),
    isDark: false,
  );

  // Kart stili dekorasyonu
  BoxDecoration cardDecoration({double radius = 25}) {
    return BoxDecoration(
      color: cardColor,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: cardBorder),
      boxShadow: isDark
          ? null
          : [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
    );
  }

  // Gradyan arka plan dekorasyonu
  BoxDecoration gradientDecoration() {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [gradientStart, gradientEnd],
      ),
    );
  }

  @override
  VibeThemeExtension copyWith({
    Color? gradientStart,
    Color? gradientEnd,
    Color? cardColor,
    Color? cardBorder,
    Color? mutedText,
    Color? subtleText,
    Color? faintText,
    Color? sheetBackground,
    Color? inputFill,
    Color? dialogBackground,
    Color? primaryButton,
    Color? titleOnGradient,
    bool? isDark,
  }) {
    return VibeThemeExtension(
      gradientStart: gradientStart ?? this.gradientStart,
      gradientEnd: gradientEnd ?? this.gradientEnd,
      cardColor: cardColor ?? this.cardColor,
      cardBorder: cardBorder ?? this.cardBorder,
      mutedText: mutedText ?? this.mutedText,
      subtleText: subtleText ?? this.subtleText,
      faintText: faintText ?? this.faintText,
      sheetBackground: sheetBackground ?? this.sheetBackground,
      inputFill: inputFill ?? this.inputFill,
      dialogBackground: dialogBackground ?? this.dialogBackground,
      primaryButton: primaryButton ?? this.primaryButton,
      titleOnGradient: titleOnGradient ?? this.titleOnGradient,
      isDark: isDark ?? this.isDark,
    );
  }

  @override
  VibeThemeExtension lerp(ThemeExtension<VibeThemeExtension>? other, double t) {
    if (other is! VibeThemeExtension) return this;
    return t < 0.5 ? this : other; // Basit geçiş
  }
}

// MaterialApp ThemeData tanımları
class VibeAppTheme {
  static const Color accent = Colors.redAccent;

  static ThemeData get dark {
    const vibe = VibeThemeExtension.dark;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF1A002E),
      colorScheme: const ColorScheme.dark(
        surface: Color(0xFF1A002E),
        onSurface: Colors.white,
        onSurfaceVariant: Color(0xB3FFFFFF),
        primary: accent,
        onPrimary: Colors.white,
      ),
      extensions: const [vibe],
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF1A002E),
        selectedItemColor: accent,
        unselectedItemColor: Color(0x8AFFFFFF),
        type: BottomNavigationBarType.fixed,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color.fromARGB(255, 120, 0, 0),
        behavior: SnackBarBehavior.floating,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      dialogTheme: const DialogTheme(
        backgroundColor: Color(0xFF1A002E),
      ),
      dividerColor: Colors.white12,
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.all(Colors.white),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: vibe.primaryButton,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }

  static ThemeData get light {
    const vibe = VibeThemeExtension.light;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF5F0FA),
      colorScheme: const ColorScheme.light(
        surface: Color(0xFFF5F0FA),
        onSurface: Color(0xFF000000),
        onSurfaceVariant: Color(0xFF1F1F1F),
        primary: accent,
        onPrimary: Colors.white,
      ),
      extensions: const [vibe],
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Color(0xFF000000),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFFFDFBFF),
        selectedItemColor: accent,
        unselectedItemColor: Color(0xFF2F2F2F),
        type: BottomNavigationBarType.fixed,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color.fromARGB(255, 120, 0, 0),
        behavior: SnackBarBehavior.floating,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      dialogTheme: const DialogTheme(
        backgroundColor: Color(0xFFFDFBFF),
      ),
      dividerColor: const Color(0x1A6B5B7A),
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.all(Colors.white),
        trackColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) return accent;
          return const Color(0xFFD8CEDE);
        }),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: vibe.primaryButton,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }
}
