// Seviyeye ve ruh haline göre Lottie animasyon görüntüleyici.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:vibe_life/maskot_servis.dart';
import 'package:vibe_life/widgets/mascot_lottie_cache.dart';

class MascotLottieView extends StatefulWidget {
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
  /// 1–5: blue1_5 · 6–10: blue6_10 · 11–20: blue11_20 / uyku / yorgun
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
      switch (durum) {
        case MascotGorselDurum.uyku:
          return 'assets/animations/blue11_20_uyku.json';
        case MascotGorselDurum.yorgun:
          return 'assets/animations/blue11_20_yorgun.json';
        case MascotGorselDurum.mutlu:
        case MascotGorselDurum.uzgun:
        case MascotGorselDurum.normal:
          return 'assets/animations/blue11_20.json';
      }
    }

    if (level >= 6) return 'assets/animations/blue6_10.json';
    return 'assets/animations/blue1_5.json';
  }

  static Future<void> tumAnimasyonlariOnbellegeAl() =>
      MascotLottieCache.onbellegeAl();

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
  State<MascotLottieView> createState() => _MascotLottieViewState();
}

class _MascotLottieViewState extends State<MascotLottieView> {
  static const _durumDebounce = Duration(milliseconds: 350);

  MascotGorselDurum? _stabilDurum;
  Timer? _durumZamanlayici;
  String? _gosterilenAsset;
  LottieComposition? _composition;
  int _yuklemeToken = 0;

  @override
  void initState() {
    super.initState();
    _stabilDurum = widget.gorselDurum;
    _assetYukle(_hedefAsset);
  }

  @override
  void didUpdateWidget(covariant MascotLottieView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.seviye != oldWidget.seviye) {
      _durumZamanlayici?.cancel();
      _stabilDurum = widget.gorselDurum;
      _assetYukle(_hedefAsset);
      return;
    }

    if (widget.gorselDurum != oldWidget.gorselDurum) {
      _durumZamanlayici?.cancel();
      _durumZamanlayici = Timer(_durumDebounce, () {
        if (!mounted) return;
        if (_stabilDurum == widget.gorselDurum) return;
        setState(() => _stabilDurum = widget.gorselDurum);
        _assetYukle(_hedefAsset);
      });
    }
  }

  @override
  void dispose() {
    _durumZamanlayici?.cancel();
    super.dispose();
  }

  String get _hedefAsset => MascotLottieView.animasyonAsset(
        widget.seviye,
        durum: _stabilDurum ?? MascotGorselDurum.normal,
      );

  Future<void> _assetYukle(String asset) async {
    if (_gosterilenAsset == asset && _composition != null) return;

    final token = ++_yuklemeToken;
    final composition = await MascotLottieCache.yukle(asset);
    if (!mounted || token != _yuklemeToken) return;

    setState(() {
      _gosterilenAsset = asset;
      _composition = composition;
    });
  }

  bool get _kucukGorunum =>
      widget.width != null && widget.width! <= 100;

  Widget _fallback() => Container(
        width: widget.width,
        height: widget.height,
        alignment: Alignment.center,
        child: Icon(
          Icons.auto_awesome,
          color: Colors.white.withOpacity(0.7),
          size: (widget.width ?? 38).clamp(24.0, 48.0),
        ),
      );

  Widget _lottieWidget() {
    final composition = _composition;
    if (composition == null) return _fallback();

    return Lottie(
      composition: composition,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      repeat: widget.repeat,
      frameRate: _kucukGorunum ? FrameRate(30) : FrameRate.composition,
      filterQuality: FilterQuality.medium,
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget child = _lottieWidget();

    if (widget.borderRadius != null) {
      child = ClipRRect(borderRadius: widget.borderRadius!, child: child);
    }

    child = RepaintBoundary(child: child);

    if (widget.decoration != null) {
      child = Container(
        width: widget.width,
        height: widget.height,
        decoration: widget.decoration,
        child: child,
      );
    }

    if (!widget.tamEkranAc) return child;

    return GestureDetector(
      onTap: () => MascotLottieView.tamEkranGoster(
        context,
        widget.seviye,
        durum: widget.gorselDurum ?? MascotGorselDurum.normal,
      ),
      child: child,
    );
  }
}

class _TamEkranAnimasyon extends StatefulWidget {
  const _TamEkranAnimasyon({
    required this.seviye,
    required this.gorselDurum,
  });

  final int seviye;
  final MascotGorselDurum gorselDurum;

  @override
  State<_TamEkranAnimasyon> createState() => _TamEkranAnimasyonState();
}

class _TamEkranAnimasyonState extends State<_TamEkranAnimasyon> {
  LottieComposition? _composition;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    final asset = MascotLottieView.animasyonAsset(
      widget.seviye,
      durum: widget.gorselDurum,
    );
    final composition = await MascotLottieCache.yukle(asset);
    if (!mounted) return;
    setState(() => _composition = composition);
  }

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
                  child: _composition == null
                      ? const CircularProgressIndicator()
                      : Lottie(
                          composition: _composition!,
                          width: MediaQuery.sizeOf(context).width * 0.9,
                          height: MediaQuery.sizeOf(context).height * 0.72,
                          fit: BoxFit.contain,
                          repeat: true,
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
