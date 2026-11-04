// Uygulama renk teması ve tema uzantıları.
import 'package:flutter/material.dart';

// BuildContext üzerinden VibeThemeExtension erişimi
extension VibeThemeContext on BuildContext {
  VibeThemeExtension get vibe =>
      Theme.of(this).extension<VibeThemeExtension>() ??
      VibeThemeExtension.dark;
}

// MyVibel'a özel tema renkleri ve dekorasyonları
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

  static const dark = VibeThemeExtension(
    gradientStart: Color.fromARGB(255, 40, 0, 0),
    gradientEnd: Color.fromARGB(255, 15, 0, 38),
    cardColor: Color(0x18FFFFFF),
    cardBorder: Color(0x28FFFFFF),
    mutedText: Color(0x8AFFFFFF),
    subtleText: Color(0xB3FFFFFF),
    faintText: Color(0x61FFFFFF),
    sheetBackground: Color(0xFF1A002E),
    inputFill: Color(0x1FFFFFFF),
    dialogBackground: Color(0xFF1A002E),
    primaryButton: Color.fromARGB(255, 120, 0, 0),
    titleOnGradient: Color.fromARGB(200, 237, 237, 237),
    isDark: true,
  );

  static const light = VibeThemeExtension(
    gradientStart: Color(0xFFFFE8E8),
    gradientEnd: Color(0xFFE8E8FA),
    cardColor: Color(0xFFFFFFFF),
    cardBorder: Color(0x336B5B7A),
    mutedText: Color(0xFF6A6278),
    subtleText: Color(0xFF524A5E),
    faintText: Color(0xFF7A7388),
    sheetBackground: Color(0xFFFDFBFF),
    inputFill: Color(0xFFFFFFFF),
    dialogBackground: Color(0xFFFDFBFF),
    primaryButton: Color.fromARGB(255, 120, 0, 0),
    titleOnGradient: Color(0xFF524A5E),
    isDark: false,
  );

  BoxDecoration cardDecoration({double radius = 16}) {
    return BoxDecoration(
      color: cardColor,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: cardBorder),
      boxShadow: isDark
          ? null
          : [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
    );
  }

  BoxDecoration kahramanKart({double radius = 22}) {
    return cardDecoration(radius: radius);
  }

  BoxDecoration satirKart({double radius = 12}) {
    return BoxDecoration(
      color: cardColor,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: cardBorder),
    );
  }

  BoxDecoration gradientDecoration() {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [gradientStart, gradientEnd],
      ),
    );
  }

  InputDecoration alanDekoru({
    required String hint,
    IconData? ikon,
  }) {
    final kenar = BorderRadius.circular(18);
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: mutedText),
      filled: true,
      fillColor: inputFill,
      prefixIcon: ikon == null ? null : Icon(ikon, color: mutedText),
      border: OutlineInputBorder(
        borderRadius: kenar,
        borderSide: BorderSide(color: cardBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: kenar,
        borderSide: BorderSide(color: cardBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: kenar,
        borderSide: const BorderSide(color: VibeAppTheme.accent, width: 1.4),
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
    return t < 0.5 ? this : other;
  }
}

class VibeAppTheme {
  static const String fontFamily = 'Outfit';
  static const Color accent = Colors.redAccent;
  static const Color splashArkaPlan = Color(0xFF1A002E);

  /// Giriş/kayıt hariç uygulama içi yazı ölçeği.
  static const icerikYaziCarpani = 1.35;

  static ThemeData get dark {
    const vibe = VibeThemeExtension.dark;
    return _olustur(
      brightness: Brightness.dark,
      vibe: vibe,
      scaffold: const Color(0xFF1A002E),
      scheme: const ColorScheme.dark(
        surface: Color(0xFF1A002E),
        onSurface: Colors.white,
        onSurfaceVariant: Color(0xB3FFFFFF),
        primary: accent,
        onPrimary: Colors.white,
      ),
      navArkaPlan: const Color(0xFF1A002E),
      navSecili: accent,
      navNormal: const Color(0x8AFFFFFF),
      appBarYazi: Colors.white,
      dialogArkaPlan: const Color(0xFF1A002E),
      bolen: Colors.white12,
    );
  }

  static ThemeData get light {
    const vibe = VibeThemeExtension.light;
    return _olustur(
      brightness: Brightness.light,
      vibe: vibe,
      scaffold: const Color(0xFFF5F0FA),
      scheme: const ColorScheme.light(
        surface: Color(0xFFF5F0FA),
        onSurface: Color(0xFF524A5E),
        onSurfaceVariant: Color(0xFF6A6278),
        primary: accent,
        onPrimary: Colors.white,
      ),
      navArkaPlan: const Color(0xFFFDFBFF),
      navSecili: accent,
      navNormal: const Color(0xFF6A6278),
      appBarYazi: const Color(0xFF524A5E),
      dialogArkaPlan: const Color(0xFFFDFBFF),
      bolen: const Color(0x1A6B5B7A),
    );
  }

  static ThemeData _olustur({
    required Brightness brightness,
    required VibeThemeExtension vibe,
    required Color scaffold,
    required ColorScheme scheme,
    required Color navArkaPlan,
    required Color navSecili,
    required Color navNormal,
    required Color appBarYazi,
    required Color dialogArkaPlan,
    required Color bolen,
  }) {
    final acikTema = brightness == Brightness.light;
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: scaffold,
      colorScheme: scheme,
      extensions: [vibe],
    );

    return base.copyWith(
      textTheme: _yaziTemasi(base.textTheme, scheme.onSurface, acikTema),
      primaryTextTheme:
          _yaziTemasi(base.primaryTextTheme, scheme.onSurface, acikTema),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
        foregroundColor: appBarYazi,
        titleTextStyle: _kalinYazi(
          size: 24,
          color: appBarYazi,
          weight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
        toolbarTextStyle: _kalinYazi(
          size: 16,
          color: appBarYazi,
          weight: FontWeight.w600,
        ),
      ),
      listTileTheme: ListTileThemeData(
        titleTextStyle: _kalinYazi(
          size: 16,
          color: scheme.onSurface,
          weight: FontWeight.w600,
        ),
        subtitleTextStyle: _kalinYazi(
          size: 13,
          color: vibe.mutedText,
          weight: FontWeight.w500,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: _kalinYazi(
          size: 15,
          color: vibe.mutedText,
          weight: FontWeight.w500,
        ),
        labelStyle: _kalinYazi(
          size: 15,
          color: scheme.onSurface,
          weight: FontWeight.w500,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: navArkaPlan,
        selectedItemColor: navSecili,
        unselectedItemColor: navNormal,
        selectedLabelStyle: _kalinYazi(
          size: 12,
          weight: FontWeight.w600,
        ),
        unselectedLabelStyle: _kalinYazi(
          size: 12,
          weight: FontWeight.w500,
        ),
        type: BottomNavigationBarType.fixed,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: vibe.primaryButton,
        behavior: SnackBarBehavior.floating,
        contentTextStyle: _kalinYazi(
          size: 15,
          color: Colors.white,
          weight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dialogTheme: DialogTheme(
        backgroundColor: dialogArkaPlan,
        titleTextStyle: _kalinYazi(
          size: 22,
          color: scheme.onSurface,
          weight: FontWeight.w600,
        ),
        contentTextStyle: _kalinYazi(
          size: 16,
          color: scheme.onSurface,
          weight: FontWeight.w500,
        ),
      ),
      dividerColor: bolen,
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.all(Colors.white),
        trackColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) return accent;
          return brightness == Brightness.dark
              ? const Color(0xFF4A3040)
              : const Color(0xFFD8CEDE);
        }),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: vibe.primaryButton,
          foregroundColor: Colors.white,
          textStyle: _kalinYazi(
            size: 16,
            color: Colors.white,
            weight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: _kalinYazi(
            size: 15,
            weight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  static TextStyle _kalinYazi({
    required FontWeight weight,
    double? size,
    Color? color,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontFamily: fontFamily,
      fontWeight: weight,
      fontSize: size,
      color: color,
      letterSpacing: letterSpacing,
      fontVariations: [FontVariation('wght', weight.value.toDouble())],
    );
  }

  static TextTheme _yaziTemasi(TextTheme kaynak, Color yaziRenk, bool acikTema) {
    TextStyle? u(TextStyle? s, FontWeight acikMin) {
      final taban = s ?? const TextStyle();
      var w = taban.fontWeight ?? FontWeight.w400;
      if (acikTema) {
        if (w.value < acikMin.value) w = acikMin;
        if (w.value < FontWeight.w500.value) w = FontWeight.w500;
        if (w.value > FontWeight.w600.value) w = FontWeight.w600;
      } else if (w.value < FontWeight.w500.value) {
        w = FontWeight.w500;
      }
      return taban.copyWith(
        fontFamily: fontFamily,
        fontWeight: w,
        color: taban.color ?? yaziRenk,
        fontVariations: [FontVariation('wght', w.value.toDouble())],
      );
    }

    return kaynak.copyWith(
      displayLarge: u(kaynak.displayLarge, FontWeight.w600),
      displayMedium: u(kaynak.displayMedium, FontWeight.w600),
      displaySmall: u(kaynak.displaySmall, FontWeight.w600),
      headlineLarge: u(kaynak.headlineLarge, FontWeight.w600),
      headlineMedium: u(kaynak.headlineMedium, FontWeight.w600),
      headlineSmall: u(kaynak.headlineSmall, FontWeight.w600),
      titleLarge: u(kaynak.titleLarge, FontWeight.w600),
      titleMedium: u(kaynak.titleMedium, FontWeight.w600),
      titleSmall: u(kaynak.titleSmall, FontWeight.w600),
      bodyLarge: u(kaynak.bodyLarge, FontWeight.w500),
      bodyMedium: u(kaynak.bodyMedium, FontWeight.w500),
      bodySmall: u(kaynak.bodySmall, FontWeight.w500),
      labelLarge: u(kaynak.labelLarge, FontWeight.w600),
      labelMedium: u(kaynak.labelMedium, FontWeight.w500),
      labelSmall: u(kaynak.labelSmall, FontWeight.w500),
    );
  }
}

/// Giriş/kayıt ekranlarında yazı boyutunu uygulama içi büyütmeden korur.
class AuthEkranYaziOlcegi extends StatelessWidget {
  const AuthEkranYaziOlcegi({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const geri = 1 / VibeAppTheme.icerikYaziCarpani;
    final appBarYazi = theme.appBarTheme.titleTextStyle;
    return Theme(
      data: theme.copyWith(
        textTheme: theme.textTheme.apply(fontSizeFactor: geri),
        primaryTextTheme: theme.primaryTextTheme.apply(fontSizeFactor: geri),
        appBarTheme: theme.appBarTheme.copyWith(
          titleTextStyle: appBarYazi?.copyWith(
            fontSize: (appBarYazi.fontSize ?? 20) * geri,
          ),
        ),
      ),
      child: child,
    );
  }
}
