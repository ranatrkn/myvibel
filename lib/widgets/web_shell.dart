// Web: auth tam genişlik; uygulama responsive (telefon / masaüstü).
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Masaüstü düzen eşiği (auth split ile aynı).
const double kWebMasaustuEsik = 900;

/// Ana sekmelerde kabuk max genişlik (çok kolonlu düzenler için).
const double kWebIcerikMaxGenislik = 1120;

/// Akış orta kolon max genişlik (masaüstü).
const double kWebAkisOrtaMax = 640;

/// Akış sağ yan panel genişliği.
const double kWebAkisYanGenislik = 280;

/// Mesajlar masaüstü: sohbet listesi genişliği.
const double kWebMesajListeGenislik = 380;

/// Masaüstü sağ sohbet paneli (açık) hedef genişlik.
const double kWebSohbetPanelGenislik = 720;

/// Web masaüstü mü? (native her zaman false)
bool webMasaustuMu(BuildContext context) {
  if (!kIsWeb) return false;
  return MediaQuery.sizeOf(context).width >= kWebMasaustuEsik;
}

/// Masaüstü sağ panelde açılacak sohbet.
class WebSohbetHedef {
  const WebSohbetHedef({
    required this.chatId,
    required this.otherUid,
    required this.otherDisplayName,
    required this.otherUsername,
    required this.otherPhotoUrl,
    required this.otherAvatarKey,
  });

  final String chatId;
  final String otherUid;
  final String otherDisplayName;
  final String otherUsername;
  final String otherPhotoUrl;
  final String otherAvatarKey;
}

/// Masaüstü kabuktan sohbet panelini açmak için (feed mesaj ikonu vb.).
class WebSohbetKapsayici extends InheritedWidget {
  const WebSohbetKapsayici({
    super.key,
    required this.sohbetAcik,
    required this.sohbetiAc,
    required this.sohbetiKapat,
    required this.sohbetToggle,
    required super.child,
  });

  final bool sohbetAcik;
  final void Function([WebSohbetHedef? hedef]) sohbetiAc;
  final VoidCallback sohbetiKapat;
  final VoidCallback sohbetToggle;

  static WebSohbetKapsayici? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<WebSohbetKapsayici>();
  }

  @override
  bool updateShouldNotify(WebSohbetKapsayici oldWidget) {
    return sohbetAcik != oldWidget.sohbetAcik;
  }
}

/// Auth / uygulama kabuğu: auth’ta tam genişlik bayrağı.
class WebShellController extends ChangeNotifier {
  WebShellController({required bool baslangicGenis}) : _genis = baslangicGenis;

  bool _genis;

  /// true = giriş/kayıt (tam genişlik split).
  bool get authGenis => _genis;

  void genisAyarla(bool deger) {
    if (_genis == deger) return;
    _genis = deger;
    notifyListeners();
  }
}

late final WebShellController webShellController;

bool get webShellHazir {
  try {
    // ignore: unnecessary_statements
    webShellController;
    return true;
  } catch (_) {
    return false;
  }
}

void webShellAuthMi(bool authEkrani) {
  if (!kIsWeb || !webShellHazir) return;
  webShellController.genisAyarla(authEkrani);
}

/// Masaüstünde içeriği ortalar; telefonda child olduğu gibi.
/// Not: Align + height:infinity kullanma — web’de boş ekrana yol açabiliyor.
class WebIcerikCercevesi extends StatelessWidget {
  const WebIcerikCercevesi({
    super.key,
    required this.child,
    this.maxWidth = kWebIcerikMaxGenislik,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    if (!webMasaustuMu(context)) return child;
    return LayoutBuilder(
      builder: (context, constraints) {
        final genislik = constraints.maxWidth.isFinite
            ? math.min(constraints.maxWidth, maxWidth)
            : maxWidth;
        final yukseklik =
            constraints.hasBoundedHeight ? constraints.maxHeight : null;
        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: genislik,
            height: yukseklik,
            child: child,
          ),
        );
      },
    );
  }
}

/// Masaüstünde orta kolon + sağ yan panel; telefonda yalnızca [orta].
class WebMasaustuOrtaYan extends StatelessWidget {
  const WebMasaustuOrtaYan({
    super.key,
    required this.orta,
    required this.yan,
    this.ortaMax = kWebAkisOrtaMax,
    this.yanGenislik = kWebAkisYanGenislik,
  });

  final Widget orta;
  final Widget yan;
  final double ortaMax;
  final double yanGenislik;

  @override
  Widget build(BuildContext context) {
    if (!webMasaustuMu(context)) return orta;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Daralmış masaüstü: yan panel sığmazsa tek kolon.
        final yanIcinMin = yanGenislik + 48;
        if (!constraints.hasBoundedWidth ||
            constraints.maxWidth < yanIcinMin + 360) {
          return orta;
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: orta),
            const SizedBox(width: 16),
            SizedBox(
              width: yanGenislik,
              child: yan,
            ),
          ],
        );
      },
    );
  }
}
