// Özelleştirilmiş snackbar mesajları.
import 'package:flutter/material.dart';
import 'package:myvibel/app_theme.dart';

// Snackbar mesaj türleri
enum VibeMesajTipi { hata, uyari, bilgi, basari }

// Tipe göre stillendirilmiş snackbar gösterir
void vibeSnackbarGoster(
  BuildContext context,
  String mesaj, {
  VibeMesajTipi tip = VibeMesajTipi.hata,
}) {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;

  late final Color arkaPlan;
  late final Color yaziRengi;
  late final Color? kenarlik;
  late final double radius;
  late final IconData ikon;

  // Tipe göre renk ve ikon seç
  switch (tip) {
    case VibeMesajTipi.hata:
      arkaPlan = const Color.fromARGB(255, 120, 0, 0);
      yaziRengi = Colors.white;
      kenarlik = null;
      radius = 10;
      ikon = Icons.error_outline_rounded;
      break;
    case VibeMesajTipi.uyari:
      arkaPlan = isDark ? const Color(0xFF4A3800) : const Color(0xFFFFF3E0);
      yaziRengi = isDark ? const Color(0xFFFFE082) : const Color(0xFF8D4B00);
      kenarlik = isDark ? const Color(0xFFFFB74D) : const Color(0xFFFFCC80);
      radius = 18;
      ikon = Icons.warning_amber_rounded;
      break;
    case VibeMesajTipi.bilgi:
      arkaPlan = isDark ? const Color(0xFF2A1A3E) : const Color(0xFFF3EBF8);
      yaziRengi = isDark ? Colors.white : const Color(0xFF3D2A4F);
      kenarlik = isDark ? VibeAppTheme.accent.withOpacity(0.45) : null;
      radius = 14;
      ikon = Icons.info_outline_rounded;
      break;
    case VibeMesajTipi.basari:
      arkaPlan = isDark ? const Color(0xFF1B4D3E) : const Color(0xFFE8F5E9);
      yaziRengi = isDark ? const Color(0xFFA5D6A7) : const Color(0xFF1B5E20);
      kenarlik = isDark ? const Color(0xFF66BB6A) : null;
      radius = 14;
      ikon = Icons.check_circle_outline_rounded;
      break;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.transparent,
      elevation: 0,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      content: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: arkaPlan,
          borderRadius: BorderRadius.circular(radius),
          border: kenarlik != null
              ? Border.all(color: kenarlik, width: 1.2)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.35 : 0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(ikon, color: yaziRengi, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                mesaj,
                style: TextStyle(
                  color: yaziRengi,
                  fontSize: 14,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
