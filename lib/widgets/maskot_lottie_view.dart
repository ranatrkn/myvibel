// Seviyeye ve ruh haline göre Lottie animasyon görüntüleyici.
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:vibe_life/maskot_servis.dart';

class MascotLottieView extends StatelessWidget {
  const MascotLottieView({
    super.key,
    required this.seviye,
    this.gorselDurum,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.repeat = true,
    this.borderRadius,
    this.decoration,
    this.tamEkranAc = true,
  });

  final int seviye;
  final MascotGorselDurum? gorselDurum;
  final bool tamEkranAc;
  final double? width;
  final double? height;
  final BoxFit fit;
  final bool repeat;
  final BorderRadius? borderRadius;
  final BoxDecoration? decoration;

  /// Seviyeye ve ruh haline göre animasyon dosyası seçer.
  /// 1–5: blue1_5 · 6–10: blue6_10 · 11–20: blue11_20 / yorgun
  /// 21+: blue21 / uyku / uzgun / yorgun
  static String animasyonAsset(
    int seviye, {
    MascotGorselDurum durum = MascotGorselDurum.normal,
  }) {
    final level = seviye < 1 ? 1 : seviye;

    if (level >= 21) {
      switch (durum) {
        case MascotGorselDurum.uyku:
          return 'assets/animations/blue21_uyku.json';
        case MascotGorselDurum.yorgun:
          return 'assets/animations/blue21_yorgun.json';
        case MascotGorselDurum.uzgun:
          return 'assets/animations/blue21_uzgun.json';
        case MascotGorselDurum.mutlu:
        case MascotGorselDurum.normal:
          return 'assets/animations/blue21.json';
      }
    }

    if (level >= 11) {
      if (durum == MascotGorselDurum.yorgun) {
        return 'assets/animations/blue11_20_yorgun.json';
      }
      return 'assets/animations/blue11_20.json';
    }

    if (level >= 6) return 'assets/animations/blue6_10.json';
    return 'assets/animations/blue1_5.json';
  }

  String get _asset =>
      animasyonAsset(seviye, durum: gorselDurum ?? MascotGorselDurum.normal);

  static Future<void> tamEkranGoster(
    BuildContext context,
    int seviye, {
    MascotGorselDurum durum = MascotGorselDurum.normal,
  }) {
    return Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.transparent,
        pageBuilder: (context, animation, secondaryAnimation) {
          return _TamEkranAnimasyon(seviye: seviye, gorselDurum: durum);
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget fallback() => Container(
          width: width,
          height: height,
          alignment: Alignment.center,
          child: Icon(
            Icons.auto_awesome,
            color: Colors.white.withOpacity(0.7),
            size: (width ?? 38).clamp(24.0, 48.0),
          ),
        );

    final kucukGorunum = width != null && width! <= 100;
    final lottie = Lottie.asset(
      _asset,
      key: ValueKey(_asset),
      width: width,
      height: height,
      fit: fit,
      repeat: kucukGorunum ? false : repeat,
      frameRate: FrameRate.composition,
      errorBuilder: (context, error, stackTrace) => fallback(),
    );

    Widget child = borderRadius != null
        ? ClipRRect(borderRadius: borderRadius!, child: lottie)
        : lottie;

    child = RepaintBoundary(child: child);

    if (decoration != null) {
      child = Container(
        width: width,
        height: height,
        decoration: decoration,
        child: child,
      );
    }

    if (!tamEkranAc) return child;

    return GestureDetector(
      onTap: () => tamEkranGoster(
        context,
        seviye,
        durum: gorselDurum ?? MascotGorselDurum.normal,
      ),
      child: child,
    );
  }
}

class _TamEkranAnimasyon extends StatelessWidget {
  const _TamEkranAnimasyon({
    required this.seviye,
    required this.gorselDurum,
  });

  final int seviye;
  final MascotGorselDurum gorselDurum;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.88),
      child: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                behavior: HitTestBehavior.opaque,
                child: Center(
                  child: Lottie.asset(
                    MascotLottieView.animasyonAsset(
                      seviye,
                      durum: gorselDurum,
                    ),
                    width: MediaQuery.sizeOf(context).width * 0.9,
                    height: MediaQuery.sizeOf(context).height * 0.72,
                    fit: BoxFit.contain,
                    repeat: true,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.auto_awesome,
                      color: Colors.white70,
                      size: 92,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                tooltip: 'Kapat',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
