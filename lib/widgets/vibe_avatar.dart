// Profil avatar seçenekleri ve görüntüleme.
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

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
];

// Anahtara göre avatar seçeneği bulur
VibeAvatarOption? vibeAvatarByKey(String? key) {
  if (key == null || key.trim().isEmpty) return null;
  for (final option in vibeAvatarOptions) {
    if (option.key == key) return option;
  }
  return null;
}

// Fotoğraf, emoji veya harf ile CircleAvatar döndürür
Widget vibeAvatar({
  required double radius,
  String? avatarKey,
  String? photoUrl,
  String? fallbackText,
  double emojiSize = 18,
  double fallbackIconSize = 20,
  Color fallbackBackgroundColor = Colors.blueGrey,
  Color fallbackForegroundColor = Colors.white,
}) {
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

  final option = vibeAvatarByKey(avatarKey);
  if (option != null) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: option.backgroundColor,
      child: Text(
        option.emoji,
        style: TextStyle(fontSize: emojiSize),
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
            Icons.person,
            color: fallbackForegroundColor,
            size: fallbackIconSize,
          ),
  );
}
