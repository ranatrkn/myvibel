// Özelleştirilmiş snackbar mesajları.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:myvibel/app_theme.dart';
import 'package:myvibel/error_messages.dart';
import 'package:myvibel/widgets/web_shell.dart';

// Snackbar mesaj türleri
enum VibeMesajTipi { hata, uyari, bilgi, basari }

// Başarı mesajını hemen gösterir, işlemi arka planda yürütür; hata olursa
// mesajı hata ile değiştirir. Çağıran widget bu arada kapanmış olabilir.
void vibeIyimserIslem(
  BuildContext context, {
  required Future<void> Function() islem,
  required String basariMesaji,
  required String hataMesaji,
}) {
  final messengerContext = ScaffoldMessenger.of(context).context;
  vibeSnackbarGoster(context, basariMesaji, tip: VibeMesajTipi.basari);
  unawaited(islem().catchError((Object e) {
    if (!messengerContext.mounted) return;
    ScaffoldMessenger.of(messengerContext).hideCurrentSnackBar();
    vibeSnackbarGoster(
      messengerContext,
      internetAwareErrorMessage(error: e, fallback: hataMesaji),
    );
  }));
}

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

  // Masaüstünde kök Scaffold'un altında durur; iç sayfaların alt menülerini örtmesin
  // ve yan paneller yüzünden kaymasın diye mesajı çağıran sayfanın ortasına hizalanır.
  EdgeInsets margin = const EdgeInsets.fromLTRB(16, 0, 16, 16);
  if (webMasaustuMu(context)) {
    const genislik = 440.0;
    final ekran = MediaQuery.sizeOf(context).width;
    var merkez = ekran / 2;
    final kutu = context.findRenderObject();
    if (kutu is RenderBox && kutu.attached && kutu.hasSize) {
      merkez = kutu.localToGlobal(kutu.size.center(Offset.zero)).dx;
    }
    final sol = (merkez - genislik / 2)
        .clamp(16.0, (ekran - genislik - 16).clamp(16.0, double.infinity));
    margin = EdgeInsets.fromLTRB(sol, 0, (ekran - sol - genislik).clamp(16.0, double.infinity), 96);
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.transparent,
      elevation: 0,
      margin: margin,
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
