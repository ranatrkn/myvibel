// Ana uygulama kabuğu: profil sekmesi ve web orta kolon navigator'ı.
import 'package:flutter/material.dart';

class AnaKabuk {
  AnaKabuk({
    required this.sekmeyeGit,
    required this.ortaNavigator,
    required this.kokNavigator,
  });

  final void Function(int indeks) sekmeyeGit;
  final NavigatorState? Function() ortaNavigator;
  final NavigatorState? Function() kokNavigator;

  static AnaKabuk? aktif;

  /// Kendi profile: kök overlay kapanır, profil sekmesi seçilir (alt bar kalır).
  static bool kendiProfilineGit() {
    final kabuk = aktif;
    if (kabuk == null) return false;
    final kok = kabuk.kokNavigator();
    if (kok != null && kok.canPop()) {
      kok.popUntil((route) => route.isFirst);
    }
    kabuk.sekmeyeGit(4);
    return true;
  }
}
