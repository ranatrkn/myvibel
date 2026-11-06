// Seviyeye ve ruh haline göre Lottie animasyon görüntüleyici.
import 'package:myvibel/tek_sefer_navigasyon.dart';
import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:myvibel/app_theme.dart';
import 'package:myvibel/widgets/web_shell.dart';
import 'package:lottie/lottie.dart';
import 'package:myvibel/error_messages.dart';
import 'package:myvibel/maestro_semantics.dart';
import 'package:myvibel/maskot_servis.dart';
import 'package:myvibel/rety_renk.dart';
import 'package:myvibel/vibe_snackbar.dart';
import 'package:myvibel/widgets/mascot_lottie_cache.dart';
import 'package:myvibel/widgets/vibe_yukleniyor.dart';

class MascotLottieView extends StatefulWidget {
  const MascotLottieView({
    super.key,
    required this.seviye,
    this.gorselDurum,
    this.renk = RetyRenk.varsayilan,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.repeat = true,
    this.borderRadius,
    this.decoration,
    this.tamEkranAc = true,
    this.renkSecilebilir = false,
  });

  final int seviye;
  final MascotGorselDurum? gorselDurum;
  final RetyRenk renk;
  final bool tamEkranAc;
  final bool renkSecilebilir;
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
    RetyRenk renk = RetyRenk.varsayilan,
  }) {
    return tekSeferPush(
      context,
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.transparent,
        pageBuilder: (context, animation, secondaryAnimation) {
          return _escIleKapat(
            context,
            _TamEkranAnimasyon(
              seviye: seviye,
              gorselDurum: durum,
              renk: renk,
            ),
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
      kokte: true,
    );
  }

  static Future<void> renkSeciciGoster(
    BuildContext context, {
    required int seviye,
    MascotGorselDurum durum = MascotGorselDurum.normal,
    RetyRenk mevcut = RetyRenk.varsayilan,
  }) {
    return tekSeferPush(context, 
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.transparent,
        pageBuilder: (context, animation, secondaryAnimation) {
          return _escIleKapat(
            context,
            _RetyRenkSecici(
              seviye: seviye,
              gorselDurum: durum,
              mevcut: mevcut,
            ),
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
      kokte: true,
    );
  }

  /// PNG katmanlı Lottie'de widget ColorFiltered güvenilir değil;
  /// boyama anında ValueDelegate.colorFilter kullan.
  static LottieDelegates? renkDelegates(RetyRenk renk) {
    if (!renk.filtreGerekli) return null;
    return LottieDelegates(
      values: [
        ValueDelegate.colorFilter(
          const ['**'],
          value: renk.colorFilter,
        ),
      ],
    );
  }

  static Widget renkliLottie({
    required LottieComposition composition,
    required RetyRenk renk,
    double? width,
    double? height,
    BoxFit fit = BoxFit.contain,
    bool repeat = true,
    FrameRate? frameRate,
    FilterQuality filterQuality = FilterQuality.medium,
  }) {
    return Lottie(
      key: ValueKey('rety-${renk.id}'),
      composition: composition,
      width: width,
      height: height,
      fit: fit,
      repeat: repeat,
      frameRate: frameRate,
      filterQuality: filterQuality,
      addRepaintBoundary: false,
      delegates: renkDelegates(renk),
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

    return MascotLottieView.renkliLottie(
      composition: composition,
      renk: widget.renk,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      repeat: widget.repeat,
      frameRate: _kucukGorunum ? const FrameRate(30) : FrameRate.composition,
      filterQuality: FilterQuality.medium,
    );
  }

  void _tiklandi() {
    if (widget.renkSecilebilir &&
        widget.seviye >= MascotServis.odaAcilisSeviyesi) {
      unawaited(
        MascotLottieView.renkSeciciGoster(
          context,
          seviye: widget.seviye,
          durum: widget.gorselDurum ?? MascotGorselDurum.normal,
          mevcut: widget.renk,
        ),
      );
      return;
    }
    unawaited(
      MascotLottieView.tamEkranGoster(
        context,
        widget.seviye,
        durum: widget.gorselDurum ?? MascotGorselDurum.normal,
        renk: widget.renk,
      ),
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

    if (widget.renkSecilebilir &&
        widget.seviye >= MascotServis.odaAcilisSeviyesi) {
      child = Stack(
        clipBehavior: Clip.none,
        children: [
          child,
          if ((widget.width ?? 120) >= 70)
            const Positioned(
              right: 2,
              bottom: 2,
              child: Icon(
                Icons.palette_outlined,
                size: 16,
                color: Colors.white70,
              ),
            ),
        ],
      );
    }

    if (!widget.tamEkranAc && !widget.renkSecilebilir) return child;

    return GestureDetector(
      onTap: _tiklandi,
      behavior: HitTestBehavior.opaque,
      child: child,
    );
  }
}

Widget _escIleKapat(BuildContext context, Widget child) {
  if (!webMasaustuMu(context)) return child;
  return CallbackShortcuts(
    bindings: {
      const SingleActivator(LogicalKeyboardKey.escape): () =>
          Navigator.of(context).maybePop(),
    },
    child: Focus(autofocus: true, child: child),
  );
}

class _TamEkranAnimasyon extends StatefulWidget {
  const _TamEkranAnimasyon({
    required this.seviye,
    required this.gorselDurum,
    required this.renk,
  });

  final int seviye;
  final MascotGorselDurum gorselDurum;
  final RetyRenk renk;

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
                      ? const VibeYukleniyor()
                      : MascotLottieView.renkliLottie(
                          composition: _composition!,
                          renk: widget.renk,
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
              child: maestroButton(
                label: MaestroSemantics.kapat,
                onTap: () => Navigator.of(context).pop(),
                child: IconButton(
                tooltip: MaestroSemantics.kapat,
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RetyRenkSecici extends StatefulWidget {
  const _RetyRenkSecici({
    required this.seviye,
    required this.gorselDurum,
    required this.mevcut,
  });

  final int seviye;
  final MascotGorselDurum gorselDurum;
  final RetyRenk mevcut;

  @override
  State<_RetyRenkSecici> createState() => _RetyRenkSeciciState();
}

class _RetyRenkSeciciState extends State<_RetyRenkSecici> {
  LottieComposition? _composition;
  late RetyRenk _secilen;
  int _kayitJetonu = 0;

  @override
  void initState() {
    super.initState();
    _secilen = widget.mevcut;
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

  void _renkSec(RetyRenk renk) {
    if (_secilen == renk) return;
    final onceki = _secilen;
    setState(() => _secilen = renk);
    final jeton = ++_kayitJetonu;
    unawaited(_kaydet(renk, onceki, jeton));
  }

  Future<void> _kaydet(RetyRenk renk, RetyRenk onceki, int jeton) async {
    try {
      await MascotServis.renkGuncelle(renk);
    } catch (e) {
      if (!mounted || jeton != _kayitJetonu) return;
      setState(() => _secilen = onceki);
      debugPrint('Rety renk kayit hatasi: $e');
      final kod = e is FirebaseException ? e.code : null;
      vibeSnackbarGoster(
        context,
        internetAwareErrorMessage(
          error: e,
          fallback: kod == null
              ? 'Renk kaydedilemedi.'
              : 'Renk kaydedilemedi ($kod).',
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (webMasaustuMu(context)) return _masaustuKart(context);
    final boyut = MediaQuery.sizeOf(context);
    return Material(
      color: Colors.black.withOpacity(0.9),
      child: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                behavior: HitTestBehavior.opaque,
              ),
            ),
            Column(
              children: [
                const SizedBox(height: 12),
                const Text(
                  'Vibel rengi',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _secilen.etiket,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.75),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Expanded(
                  child: Center(
                    child: _composition == null
                        ? const VibeYukleniyor()
                        : MascotLottieView.renkliLottie(
                            composition: _composition!,
                            renk: _secilen,
                            width: boyut.width * 0.78,
                            height: boyut.height * 0.42,
                            fit: BoxFit.contain,
                            repeat: true,
                          ),
                  ),
                ),
                SizedBox(
                  height: 168,
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 6,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                    ),
                    itemCount: RetyRenk.tumu.length,
                    itemBuilder: (context, i) {
                      final renk = RetyRenk.tumu[i];
                      return _RenkDaire(
                        renk: renk,
                        secili: _secilen == renk,
                        onTap: () => _renkSec(renk),
                      );
                    },
                  ),
                ),
              ],
            ),
            Positioned(
              top: 8,
              right: 8,
              child: maestroButton(
                label: MaestroSemantics.kapat,
                onTap: () => Navigator.of(context).pop(),
                child: IconButton(
                tooltip: MaestroSemantics.kapat,
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _masaustuKart(BuildContext context) {
    final vibe = context.vibe;
    final yazi = vibe.isDark ? Colors.white : const Color(0xFF1A1024);
    return Material(
      color: Colors.black.withOpacity(0.35),
      child: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: vibe.dialogBackground,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: vibe.cardBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.18),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 8, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Vibel rengi',
                              style: TextStyle(
                                color: yazi,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          maestroButton(
                            label: MaestroSemantics.kapat,
                            onTap: () => Navigator.of(context).pop(),
                            child: IconButton(
                              tooltip: MaestroSemantics.kapat,
                              visualDensity: VisualDensity.compact,
                              onPressed: () => Navigator.of(context).pop(),
                              icon: Icon(
                                Icons.close_rounded,
                                color: yazi.withOpacity(0.7),
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(
                        height: 132,
                        child: _composition == null
                            ? const Center(
                                child: VibeYukleniyor(),
                              )
                            : MascotLottieView.renkliLottie(
                                composition: _composition!,
                                renk: _secilen,
                                width: 132,
                                height: 132,
                                fit: BoxFit.contain,
                                repeat: true,
                              ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _secilen.etiket,
                        style: TextStyle(
                          color: yazi.withOpacity(0.62),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          for (final renk in RetyRenk.tumu)
                            SizedBox(
                              width: 28,
                              height: 28,
                              child: _RenkDaire(
                                renk: renk,
                                secili: _secilen == renk,
                                onTap: () => _renkSec(renk),
                                ince: true,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RenkDaire extends StatelessWidget {
  const _RenkDaire({
    required this.renk,
    required this.secili,
    required this.onTap,
    this.ince = false,
  });

  final RetyRenk renk;
  final bool secili;
  final VoidCallback onTap;
  final bool ince;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${MaestroSemantics.retyRengi} ${renk.etiket}',
      button: true,
      selected: secili,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: renk.ornek,
            shape: BoxShape.circle,
            border: Border.all(
              color: ince
                  ? Colors.white
                  : (secili ? Colors.white : Colors.white24),
              width: secili ? (ince ? 2 : 3) : (ince ? 1 : 1.5),
            ),
            boxShadow: ince
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(secili ? 0.45 : 0.18),
                      spreadRadius: secili ? 1 : 0.4,
                    ),
                  ]
                : secili
                    ? [
                        BoxShadow(
                          color: renk.ornek.withOpacity(0.55),
                          blurRadius: 10,
                        ),
                      ]
                    : null,
          ),
        ),
      ),
    );
  }
}
