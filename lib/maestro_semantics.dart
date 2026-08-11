// Maestro ve ekran okuyucu testleri icin tutarli erisim etiketleri.
import 'package:flutter/material.dart';

abstract final class MaestroSemantics {
  static const altMenuAna = 'Alt menü Ana';
  static const altMenuKesfet = 'Alt menü Keşfet';
  static const altMenuYeni = 'Alt menü Yeni gönderi';
  static const altMenuBildirim = 'Alt menü Bildirimler';
  static const altMenuProfil = 'Alt menü Profil';

  static const maskotOdasi = 'Maskot odasini ac';
  static const ayarlar = 'Ayarlar';
}

Widget maestroButton({
  required String label,
  required Widget child,
  bool selected = false,
  VoidCallback? onTap,
}) {
  return Semantics(
    label: label,
    button: true,
    selected: selected,
    onTap: onTap,
    child: child,
  );
}
