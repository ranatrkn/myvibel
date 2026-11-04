// Profil avatar seçenekleri ve görüntüleme.
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:myvibel/sosyal/lider_tac_servis.dart';
import 'package:myvibel/widgets/lider_taci.dart';
import 'package:myvibel/widgets/vibe_ikonlar.dart';

// Tek avatar seçeneği (emoji + arka plan)
class VibeAvatarOption {
  final String key;
  final String emoji;
  final Color backgroundColor;

  const VibeAvatarOption({
    required this.key,
    required this.emoji,
    required this.backgroundColor,
  });
}

// Kullanılabilir avatar listesi
const List<VibeAvatarOption> vibeAvatarOptions = [
  VibeAvatarOption(
    key: "cat_pink",
    emoji: "🐱",
    backgroundColor: Color(0xFFEF9A9A),
  ),
  VibeAvatarOption(
    key: "dog_brown",
    emoji: "🐶",
    backgroundColor: Color(0xFFBCAAA4),
  ),
  VibeAvatarOption(
    key: "fox_orange",
    emoji: "🦊",
    backgroundColor: Color(0xFFFFCC80),
  ),
  VibeAvatarOption(
    key: "panda_gray",
    emoji: "🐼",
    backgroundColor: Color(0xFFB0BEC5),
  ),
  VibeAvatarOption(
    key: "bear_honey",
    emoji: "🐻",
    backgroundColor: Color(0xFFD7B899),
  ),
  VibeAvatarOption(
    key: "frog_green",
    emoji: "🐸",
    backgroundColor: Color(0xFFA5D6A7),
  ),
  VibeAvatarOption(
    key: "rabbit_lilac",
    emoji: "🐰",
    backgroundColor: Color(0xFFD1C4E9),
  ),
  VibeAvatarOption(
    key: "koala_blue",
    emoji: "🐨",
    backgroundColor: Color(0xFFB3E5FC),
  ),
  VibeAvatarOption(
    key: "tiger_gold",
    emoji: "🐯",
    backgroundColor: Color(0xFFFFE082),
  ),
  VibeAvatarOption(
    key: "unicorn_mint",
    emoji: "🦄",
    backgroundColor: Color(0xFFB2DFDB),
  ),
  VibeAvatarOption(
    key: "robot_violet",
    emoji: "🤖",
    backgroundColor: Color(0xFFCE93D8),
  ),
  VibeAvatarOption(
    key: "star_night",
    emoji: "⭐",
    backgroundColor: Color(0xFF90CAF9),
  ),
  VibeAvatarOption(
    key: "lion_amber",
    emoji: "🦁",
    backgroundColor: Color(0xFFB87A32),
  ),
  VibeAvatarOption(
    key: "pig_blush",
    emoji: "🐷",
    backgroundColor: Color(0xFFA24A6C),
  ),
  VibeAvatarOption(
    key: "monkey_tan",
    emoji: "🐵",
    backgroundColor: Color(0xFF8A5A38),
  ),
  VibeAvatarOption(
    key: "chick_sun",
    emoji: "🐤",
    backgroundColor: Color(0xFFC4A032),
  ),
  VibeAvatarOption(
    key: "penguin_ice",
    emoji: "🐧",
    backgroundColor: Color(0xFF3A5A7A),
  ),
  VibeAvatarOption(
    key: "owl_plum",
    emoji: "🦉",
    backgroundColor: Color(0xFF5A3A7A),
  ),
  VibeAvatarOption(
    key: "wolf_slate",
    emoji: "🐺",
    backgroundColor: Color(0xFF4A5568),
  ),
  VibeAvatarOption(
    key: "horse_sand",
    emoji: "🐴",
    backgroundColor: Color(0xFF7A5A48),
  ),
  VibeAvatarOption(
    key: "mouse_peach",
    emoji: "🐭",
    backgroundColor: Color(0xFFB86A58),
  ),
  VibeAvatarOption(
    key: "hamster_apricot",
    emoji: "🐹",
    backgroundColor: Color(0xFFB87848),
  ),
  VibeAvatarOption(
    key: "otter_teal",
    emoji: "🦦",
    backgroundColor: Color(0xFF2A7A78),
  ),
  VibeAvatarOption(
    key: "sloth_sage",
    emoji: "🦥",
    backgroundColor: Color(0xFF5A7A48),
  ),
  VibeAvatarOption(
    key: "bee_gold",
    emoji: "🐝",
    backgroundColor: Color(0xFFC4A028),
  ),
  VibeAvatarOption(
    key: "butterfly_lavender",
    emoji: "🦋",
    backgroundColor: Color(0xFF5A4A9C),
  ),
  VibeAvatarOption(
    key: "turtle_sea",
    emoji: "🐢",
    backgroundColor: Color(0xFF2A7A68),
  ),
  VibeAvatarOption(
    key: "dolphin_sky",
    emoji: "🐬",
    backgroundColor: Color(0xFF2A6A9C),
  ),
  VibeAvatarOption(
    key: "whale_navy",
    emoji: "🐳",
    backgroundColor: Color(0xFF2A4A8C),
  ),
  VibeAvatarOption(
    key: "octopus_coral",
    emoji: "🐙",
    backgroundColor: Color(0xFFC45A58),
  ),
  VibeAvatarOption(
    key: "chick_bloom",
    emoji: "🐥",
    backgroundColor: Color(0xFFC4A032),
  ),
  VibeAvatarOption(
    key: "cow_cream",
    emoji: "🐮",
    backgroundColor: Color(0xFF8A7A48),
  ),
  VibeAvatarOption(
    key: "dragon_ember",
    emoji: "🐲",
    backgroundColor: Color(0xFFB84A3A),
  ),
  VibeAvatarOption(
    key: "alien_lime",
    emoji: "👽",
    backgroundColor: Color(0xFF4A8A3A),
  ),
  VibeAvatarOption(
    key: "ghost_mist",
    emoji: "👻",
    backgroundColor: Color(0xFF5A5A6A),
  ),
  VibeAvatarOption(
    key: "flower_rose",
    emoji: "🌸",
    backgroundColor: Color(0xFFA24A6C),
  ),
  VibeAvatarOption(
    key: "sunflower_gold",
    emoji: "🌻",
    backgroundColor: Color(0xFFC49A28),
  ),
  VibeAvatarOption(
    key: "rainbow_cloud",
    emoji: "🌈",
    backgroundColor: Color(0xFF3A7A8C),
  ),
  VibeAvatarOption(
    key: "moon_indigo",
    emoji: "🌙",
    backgroundColor: Color(0xFF3A3A8C),
  ),
  VibeAvatarOption(
    key: "fire_ember",
    emoji: "🔥",
    backgroundColor: Color(0xFFC44A32),
  ),
  VibeAvatarOption(
    key: "snow_ice",
    emoji: "❄️",
    backgroundColor: Color(0xFF3A6A8C),
  ),
  VibeAvatarOption(
    key: "donut_pink",
    emoji: "🍩",
    backgroundColor: Color(0xFFA24A6C),
  ),
  VibeAvatarOption(
    key: "cookie_cocoa",
    emoji: "🍪",
    backgroundColor: Color(0xFF7A5A48),
  ),
  VibeAvatarOption(
    key: "game_lime",
    emoji: "🎮",
    backgroundColor: Color(0xFF4A7A3A),
  ),
  VibeAvatarOption(
    key: "music_magenta",
    emoji: "🎵",
    backgroundColor: Color(0xFFA23A6C),
  ),
  VibeAvatarOption(
    key: "gem_cyan",
    emoji: "💎",
    backgroundColor: Color(0xFF2A7A8C),
  ),
  VibeAvatarOption(
    key: "lightning_yellow",
    emoji: "⚡",
    backgroundColor: Color(0xFFC4A028),
  ),
  VibeAvatarOption(
    key: "cactus_mint",
    emoji: "🌵",
    backgroundColor: Color(0xFF2F7A58),
  ),
  VibeAvatarOption(
    key: "smile_sunny",
    emoji: "😊",
    backgroundColor: Color(0xFFC49A28),
  ),
];

// Anahtara göre avatar seçeneği bulur
VibeAvatarOption? vibeAvatarByKey(String? key) {
  if (key == null || key.trim().isEmpty) return null;
  for (final option in vibeAvatarOptions) {
    if (option.key == key) return option;
  }
  return null;
}

/// Galeri avatarı varsa photoUrl gömme (Google URL eski gönderilerde kalmasın).
String vibeDenormalizePhotoUrl({
  required String? avatarKey,
  String? photoUrl,
  String? authPhotoUrl,
}) {
  if (vibeAvatarByKey(avatarKey) != null) return '';
  final firestorePhoto = (photoUrl ?? '').trim();
  if (firestorePhoto.isNotEmpty) return firestorePhoto;
  return (authPhotoUrl ?? '').trim();
}

// Fotoğraf, emoji veya harf ile CircleAvatar döndürür; liderlerde taç gösterir
Widget vibeAvatar({
  required double radius,
  String? avatarKey,
  String? photoUrl,
  String? fallbackText,
  String? userId,
  bool liderTaciGoster = false,
  int? liderSira,
  double emojiSize = 18,
  double fallbackIconSize = 20,
  Color fallbackBackgroundColor = Colors.blueGrey,
  Color fallbackForegroundColor = Colors.white,
}) {
  final normalizedUserId = (userId ?? '').trim();
  final servis = LiderTacServis.instance;
  final listeSirasi = liderSira != null && liderSira >= 1 && liderSira <= 3
      ? liderSira
      : null;

  Widget avatar = _vibeAvatarCore(
    radius: radius,
    avatarKey: avatarKey,
    photoUrl: photoUrl,
    fallbackText: fallbackText,
    emojiSize: emojiSize,
    fallbackIconSize: fallbackIconSize,
    fallbackBackgroundColor: fallbackBackgroundColor,
    fallbackForegroundColor: fallbackForegroundColor,
  );

  Widget tacliAvatar(int aktifSira) {
    return RepaintBoundary(
      child: _VibeAvatarTacli(
        radius: radius,
        sira: aktifSira,
        child: avatar,
      ),
    );
  }

  if (!liderTaciGoster && listeSirasi == null) {
    return avatar;
  }

  if (listeSirasi != null) {
    return tacliAvatar(listeSirasi);
  }

  if (normalizedUserId.isEmpty) return avatar;

  return ValueListenableBuilder<int>(
    valueListenable: servis.siraDinleyici(normalizedUserId),
    builder: (context, aktifSira, _) {
      if (aktifSira < 1 || aktifSira > 3) return avatar;
      return tacliAvatar(aktifSira);
    },
  );
}

Widget _vibeAvatarCore({
  required double radius,
  String? avatarKey,
  String? photoUrl,
  String? fallbackText,
  required double emojiSize,
  required double fallbackIconSize,
  required Color fallbackBackgroundColor,
  required Color fallbackForegroundColor,
}) {
  // Galeri avatarı, Google'ın harfli varsayılan fotoğrafından önce gelir.
  final option = vibeAvatarByKey(avatarKey);
  if (option != null) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: option.backgroundColor,
      child: Text(
        option.emoji,
        style: TextStyle(fontSize: emojiSize, height: 1.1),
      ),
    );
  }

  final normalizedPhotoUrl = (photoUrl ?? "").trim();
  if (normalizedPhotoUrl.isNotEmpty) {
    final cacheSize = (radius * 2 * 2).round().clamp(48, 256);
    return CircleAvatar(
      radius: radius,
      backgroundColor: fallbackBackgroundColor,
      backgroundImage: CachedNetworkImageProvider(
        normalizedPhotoUrl,
        maxWidth: cacheSize,
        maxHeight: cacheSize,
      ),
    );
  }

  final normalizedFallback = (fallbackText ?? "").trim();
  final initial =
      normalizedFallback.isNotEmpty ? normalizedFallback[0].toUpperCase() : "";

  return CircleAvatar(
    radius: radius,
    backgroundColor: fallbackBackgroundColor,
    child: initial.isNotEmpty
        ? Text(
            initial,
            style: TextStyle(
              color: fallbackForegroundColor,
              fontWeight: FontWeight.w700,
              fontSize: fallbackIconSize * 0.8,
            ),
          )
        : Icon(
            VibeIkon.profilSecili,
            color: fallbackForegroundColor,
            size: fallbackIconSize,
          ),
  );
}

class _VibeAvatarTacli extends StatelessWidget {
  const _VibeAvatarTacli({
    required this.radius,
    required this.sira,
    required this.child,
  });

  final double radius;
  final int sira;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final avatarCap = radius * 2;
    final tacGenislik = (avatarCap * 1.16).clamp(28.0, 140.0);
    final tacYukseklik = tacGenislik / LiderTaci.enBoy;
    final oturma = radius * 0.44;
    final genislik = avatarCap > tacGenislik ? avatarCap : tacGenislik;
    final yukseklik = avatarCap + tacYukseklik - oturma;

    return SizedBox(
      width: genislik,
      height: yukseklik,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          Positioned(
            bottom: 0,
            child: child,
          ),
          Positioned(
            top: 0,
            child: LiderTaci(sira: sira, size: tacGenislik),
          ),
        ],
      ),
    );
  }
}
