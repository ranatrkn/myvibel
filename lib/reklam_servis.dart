import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:myvibel/app_theme.dart';
import 'package:myvibel/web_akis_reklam_stub.dart'
    if (dart.library.js_interop) 'package:myvibel/web_akis_reklam.dart';

/// AdMob yayın kimlikleri. Web reklamı ayrı AdSense birimi ister.
class ReklamKimlikleri {
  static const androidUygulama = 'ca-app-pub-4786108844945952~4156557723';
  static const androidGonderi = 'ca-app-pub-4786108844945952/6117277160';

  /// AdMob'da oluşturulan ödüllü birim. Boşken release'de ödüllü reklam kapalı.
  static const androidOdullu = '';
  static const _androidOdulluTest = 'ca-app-pub-3940256099942544/5224354917';

  static String get androidOdulluBirim =>
      kReleaseMode ? androidOdullu : _androidOdulluTest;
}

/// "Reklam izle, vil kazan": tek seferlik ödüllü reklam; bir sonraki önceden yüklenir.
class OdulluReklamServis {
  OdulluReklamServis._();

  static RewardedAd? _hazir;
  static Future<void>? _yukleniyor;

  static bool get kullanilabilir =>
      ReklamServis.androidde && ReklamKimlikleri.androidOdulluBirim.isNotEmpty;

  static Future<void> onYukle() {
    if (!kullanilabilir || _hazir != null) return Future.value();
    return _yukleniyor ??= _yukle().whenComplete(() => _yukleniyor = null);
  }

  static Future<void> _yukle() async {
    await ReklamServis.baslat();
    final tamam = Completer<void>();
    await RewardedAd.load(
      adUnitId: ReklamKimlikleri.androidOdulluBirim,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _hazir = ad;
          if (!tamam.isCompleted) tamam.complete();
        },
        onAdFailedToLoad: (error) {
          debugPrint('Odullu reklam yuklenemedi: ${error.code} ${error.message}');
          if (!tamam.isCompleted) tamam.complete();
        },
      ),
    );
    await tamam.future;
  }

  /// Reklamı gösterir; kullanıcı ödülü hak ettiyse true döner.
  static Future<bool> goster() async {
    if (!kullanilabilir) return false;
    if (_hazir == null) await onYukle();
    final reklam = _hazir;
    if (reklam == null) throw 'Şu an izlenebilecek reklam yok. Biraz sonra tekrar dene.';
    _hazir = null;

    var kazandi = false;
    final kapandi = Completer<void>();
    reklam.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        if (!kapandi.isCompleted) kapandi.complete();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('Odullu reklam gosterilemedi: ${error.code} ${error.message}');
        ad.dispose();
        if (!kapandi.isCompleted) kapandi.complete();
      },
    );
    await reklam.show(onUserEarnedReward: (_, __) => kazandi = true);
    await kapandi.future;
    unawaited(onYukle());
    return kazandi;
  }
}

class ReklamServis {
  ReklamServis._();

  /// Gönderiler arasında rastgele reklam aralığı (dahil).
  static const minAra = 3;
  static const maxAra = 10;
  static Future<void>? _baslatma;

  static bool get androidde =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Android akışında AdMob, web akışında AdSense. Giriş sayfasında yok.
  static bool get akista => androidde || kIsWeb;

  static Future<void> baslat() {
    if (!androidde) return Future.value();
    return _baslatma ??= MobileAds.instance.initialize();
  }

  /// Gönderi indeksi veya null (reklam). Tohum aynı kalınca sıra zıplamaz.
  static List<int?> akisPlani(
    int postSayisi,
    int tohum, {
    bool reklamsiz = false,
  }) {
    if (!akista || postSayisi == 0 || reklamsiz) {
      return List<int?>.generate(postSayisi, (i) => i);
    }
    final rastgele = Random(tohum);
    final plan = <int?>[];
    var i = 0;
    while (i < postSayisi) {
      final ara = minAra + rastgele.nextInt(maxAra - minAra + 1);
      final al = min(ara, postSayisi - i);
      for (var k = 0; k < al; k++) {
        plan.add(i++);
      }
      if (i < postSayisi) plan.add(null);
    }
    return plan;
  }
}

class _ReklamOnbellek {
  NativeAd? ad;
  AdWidget? gorunum;
  bool hazir = false;
  bool isteniyor = false;
}

final _reklamOnbellek = <String, _ReklamOnbellek>{};

/// Akışta gönderi kartıyla aynı düzende native reklam.
class GonderiReklami extends StatefulWidget {
  const GonderiReklami({super.key, required this.slot});

  final String slot;

  @override
  State<GonderiReklami> createState() => _GonderiReklamiState();
}

class _GonderiReklamiState extends State<GonderiReklami>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!ReklamServis.androidde) return;
    final kayit = _reklamOnbellek.putIfAbsent(widget.slot, _ReklamOnbellek.new);
    if (kayit.isteniyor || kayit.hazir) return;
    kayit.isteniyor = true;
    final vibe = context.vibe;
    final yazi = Theme.of(context).colorScheme.onSurface;
    unawaited(_yukle(kayit, vibe, yazi));
  }

  Future<void> _yukle(
    _ReklamOnbellek kayit,
    VibeThemeExtension vibe,
    Color yazi,
  ) async {
    await ReklamServis.baslat();
    if (!mounted) return;
    final reklam = NativeAd(
      adUnitId: ReklamKimlikleri.androidGonderi,
      factoryId: 'gonderiReklam',
      customOptions: {
        'yazi': yazi.value,
        'soluk': vibe.mutedText.value,
        'buton': const Color(0xFF780000).value,
      },
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          kayit.gorunum = AdWidget(ad: ad as NativeAd);
          kayit.hazir = true;
          if (mounted) setState(() {});
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint(
            'Gonderi reklam yuklenemedi: ${error.code} ${error.message}',
          );
          ad.dispose();
          kayit.ad = null;
          kayit.isteniyor = false;
        },
      ),
    );
    kayit.ad = reklam;
    reklam.load();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (kIsWeb) {
      return akisReklamGorunumu(widget.slot);
    }
    final kayit = _reklamOnbellek[widget.slot];
    final gorunum = kayit?.gorunum;
    if (kayit == null || !kayit.hazir || gorunum == null) {
      return const SizedBox.shrink();
    }
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      decoration: context.vibe.cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 390,
        width: double.infinity,
        child: gorunum,
      ),
    );
  }
}
