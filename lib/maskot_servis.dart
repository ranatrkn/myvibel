// Maskot enerji, mutluluk, uyku ve gelişim mantığı.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

// Maskot animasyon durumları
enum MascotGorselDurum { normal, mutlu, uzgun, uyku, yorgun }

// Maskot anlık durum modeli
class MascotDurum {
  const MascotDurum({
    required this.isim,
    required this.seviye,
    required this.gelisimPuani,
    required this.etkilesimPuani,
    required this.tokluk,
    required this.enerji,
    required this.mutluluk,
    required this.sonBakim,
    required this.kazanilanSeviyeOdulleri,
    required this.uykuBitisMs,
    required this.sonAktiviteMs,
    required this.sonEnerjiDususMs,
  });

  final String isim;
  final int seviye;
  final int gelisimPuani;
  /// Sosyal etkilesimlerden biriken; yemek/uyku harcanir.
  final int etkilesimPuani;
  final int tokluk;
  final int enerji;
  final int mutluluk;
  final Map<String, dynamic> sonBakim;
  final List<int> kazanilanSeviyeOdulleri;
  final int uykuBitisMs;
  final int sonAktiviteMs;
  final int sonEnerjiDususMs;

  int get gerekliGelisim =>
      MascotServis.gerekliGelisimPuani(seviye); // Seviye atlama eşiği

  // Gelişim çubuğu oranı (0-1)
  double get gelisimOrani {
    if (gerekliGelisim <= 0) return 1;
    return (gelisimPuani / gerekliGelisim).clamp(0.0, 1.0);
  }

  bool get uyuyor => MascotServis.uyuyorMu(this); // Uyku durumu

  MascotGorselDurum get gorselDurum =>
      MascotServis.gorselDurum(this); // Animasyon durumu
}

// Maskot geliştirme işlemi sonucu
class MascotGelistirSonuc {
  const MascotGelistirSonuc({
    required this.seviyeAtladi,
    required this.eskiSeviye,
    required this.yeniSeviye,
    required this.yeniSeviyeOdulleri,
  });

  final bool seviyeAtladi;
  final int eskiSeviye;
  final int yeniSeviye;
  final List<int> yeniSeviyeOdulleri;
}

// Zaman senkronizasyonu sonucu
class MascotSenkronSonuc {
  const MascotSenkronSonuc({
    required this.robot,
    required this.mesajlar,
  });

  final MascotDurum robot;
  final List<String> mesajlar;
}

// Maskot oyun mekaniği servisi
class MascotServis {
  MascotServis._();

  static const gelistirmeMaliyeti = 20; // Eski geliştir butonu (kullanılmıyor)
  static const odaAcilisSeviyesi = 6;
  static const toklukAcilisSeviyesi = 6;
  static const enerjiAcilisSeviyesi = 11;
  static const mutlulukAcilisSeviyesi = 21;
  static const etkilesimEnerjiKilitEsigi = 10;
  static const uyuMaxEnerji = 50;
  static const uyuErkenUyandirmaMinEnerji = 30;
  static const uyuSureMs = 4 * 60 * 60 * 1000;
  static const uykuEnerjiDakikaBasina = 0.2;
  static const uykuMaxEnerjiArtisi = 50;
  static const yemekGelisimPuani = 40;
  static const uykuGelisimPuani = 25;
  static const yemekEtkilesimMaliyeti = 15;
  static const uykuEtkilesimMaliyeti = 25;
  static const etkilesimEnerjiGonderi = 5;
  static const etkilesimEnerjiYorum = 3;
  static const etkilesimEnerjiBegeni = 1;
  static const toklukEtkilesimGonderi = 6;
  static const toklukEtkilesimYorum = 4;
  static const toklukEtkilesimBegeni = 2;
  static const mutlulukEtkilesimGonderi = 6;
  static const mutlulukEtkilesimYorum = 4;
  static const mutlulukEtkilesimBegeni = 2;
  static const mutlulukGelisimBonusCarpani = 1.15;
  /// Uygulama kapalıyken tokluğun sıfıra inme süresi (dakika).
  static const toklukUygulamaDisiDakika = 360;
  /// Uygulama açıkken etkileşim yoksa tokluk düşüşü (dakika).
  static const toklukEtkilesimsizDakika = 480;
  static const mutlulukUygulamaDisiDakika = 180;
  static const mutlulukEtkilesimsizDakika = 360;
  static const uyanincaMutlulukBonus = 5; // Uyanınca mutluluk bonusu
  static const _dakikaMs = 60 * 1000;
  // Maskot sistemi etkin. 1-5 seviyelerde etkileşim puanları otomatik gelişim sağlar.
  static const bool enabled = true;

  // Sosyal etkilesimden etkilesim puani (+ 1-5 arasi otomatik gelisim).
  static Future<void> etkilesimPuaniniGelismeyeEkle(
    String uid,
    int puan,
  ) async {
    await etkilesimPuaniEkle(uid, puan);
  }

  static Future<void> etkilesimPuaniEkle(String uid, int puan) async {
    if (!enabled || uid.isEmpty || puan <= 0) return;
    final ref = _db.collection('users').doc(uid);
    try {
      await _db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) return;
        final data = snap.data() ?? <String, dynamic>{};
        final robot = _robotHaritasi(data['robot']);
        var seviye = _int(robot['seviye'], 1);

        robot['etkilesimPuani'] =
            _int(robot['etkilesimPuani'], 0) + puan;

        // 1-5: oda acilmadan otomatik gelisim devam eder.
        if (seviye < toklukAcilisSeviyesi) {
          var gelisimPuani = _int(robot['gelisimPuani'], 0) + puan;
          var gerekli = gerekliGelisimPuani(seviye);
          var seviyeAtladi = false;
          while (gelisimPuani >= gerekli) {
            gelisimPuani -= gerekli;
            seviye += 1;
            seviyeAtladi = true;
            gerekli = gerekliGelisimPuani(seviye);
          }
          robot['gelisimPuani'] = gelisimPuani;
          robot['seviye'] = seviye;
          if (seviyeAtladi) {
            _seviyeOdulleriniIsle(robot, seviye);
            _fazStatlariniHizala(robot, seviye);
          }
        }

        tx.update(ref, {'robot': robot});
      });
    } catch (e) {
      debugPrint('Maskot etkilesim puani guncelleme hatasi: $e');
    }
  }

  static void _etkilesimPuaniHarca(
    Map<String, dynamic> robot,
    int maliyet,
  ) {
    final mevcut = _int(robot['etkilesimPuani'], 0);
    if (mevcut < maliyet) {
      throw 'Yeterli etkileşim puanı yok ($maliyet gerekli, $mevcut var).';
    }
    robot['etkilesimPuani'] = mevcut - maliyet;
  }

  static List<int> _gelisimVeSeviyeUygula(
    Map<String, dynamic> robot,
    int ekGelisim,
  ) {
    var gelisimPuani = _int(robot['gelisimPuani'], 0) + ekGelisim;
    var seviye = _int(robot['seviye'], 1);
    var gerekli = gerekliGelisimPuani(seviye);
    final eskiSeviye = seviye;
    while (gelisimPuani >= gerekli) {
      gelisimPuani -= gerekli;
      seviye += 1;
      gerekli = gerekliGelisimPuani(seviye);
    }
    robot['gelisimPuani'] = gelisimPuani;
    robot['seviye'] = seviye;
    if (seviye > eskiSeviye) {
      _fazStatlariniHizala(robot, seviye);
      return _seviyeOdulleriniIsle(robot, seviye);
    }
    return [];
  }

  /// Yeni faza geciste eksik statlari mantikli varsayilanlara ceker.
  static void _fazStatlariniHizala(Map<String, dynamic> robot, int seviye) {
    if (toklukAktif(seviye) && !robot.containsKey('tokluk')) {
      robot['tokluk'] = 80;
    }
    if (enerjiAktif(seviye) && _int(robot['enerji'], 0) < 30) {
      robot['enerji'] = 70;
    }
    if (mutlulukAktif(seviye) && _int(robot['mutluluk'], 0) < 40) {
      robot['mutluluk'] = 65;
    }
  }

  // Eski bakım anahtarlarını temizler
  static void _sonBakimTemizle(Map<String, dynamic> robot) {
    final sonBakimRaw = robot['sonBakim'];
    if (sonBakimRaw is! Map) return;

    final sonBakim = Map<String, dynamic>.from(sonBakimRaw);
    var degisti = false;

    for (final key in ['yemek', 'uyu', 'besle', 'oyna']) {
      if (sonBakim.remove(key) != null) {
        degisti = true;
      }
    }

    if (degisti) {
      robot['sonBakim'] = sonBakim;
    }
  }

  // Maskot alanı açık mı (seviye 6+)
  static bool odaAcik(int seviye) => seviye >= odaAcilisSeviyesi;

  static bool toklukAktif(int seviye) => seviye >= toklukAcilisSeviyesi;

  static bool enerjiAktif(int seviye) => seviye >= enerjiAcilisSeviyesi;

  static bool mutlulukAktif(int seviye) => seviye >= mutlulukAcilisSeviyesi;

  static bool yemekSistemiAcik(int seviye) =>
      seviye >= toklukAcilisSeviyesi && seviye < enerjiAcilisSeviyesi;

  static bool uyuSistemiAcik(int seviye) => seviye >= enerjiAcilisSeviyesi;

  static String fazBasligi(int seviye) {
    if (seviye < toklukAcilisSeviyesi) {
      return 'Etkileşimle birlikte büyüyor';
    }
    if (seviye < enerjiAcilisSeviyesi) {
      return 'Tokluk · yemek zamanı';
    }
    if (seviye < mutlulukAcilisSeviyesi) {
      return 'Enerji · dinlenme zamanı';
    }
    return 'Mutluluk · güçlü bağ';
  }

  static int sonrakiFazSeviyesi(int seviye) {
    if (seviye < toklukAcilisSeviyesi) return toklukAcilisSeviyesi;
    if (seviye < enerjiAcilisSeviyesi) return enerjiAcilisSeviyesi;
    if (seviye < mutlulukAcilisSeviyesi) return mutlulukAcilisSeviyesi;
    return seviye;
  }

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const _odulSeviyeleri = [2, 3, 4, 5, 7, 10];

  static int gerekliGelisimPuani(int seviye) {
    if (seviye < toklukAcilisSeviyesi) return 100;
    if (seviye < enerjiAcilisSeviyesi) return 200;
    if (seviye < mutlulukAcilisSeviyesi) return 400;
    return 600;
  }

  static int _int(dynamic value, int varsayilan) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value.trim());
      if (parsed != null) return parsed;
    }
    return varsayilan;
  }

  static int _clampStat(int value) => value.clamp(0, 100);

  static int _simdiMs() => DateTime.now().millisecondsSinceEpoch;

  // Firestore verisini MascotDurum'a çevirir
  static MascotDurum parse(dynamic raw) {
    final map =
        raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    final sonBakimRaw = map['sonBakim'];
    final sonBakim = sonBakimRaw is Map
        ? Map<String, dynamic>.from(sonBakimRaw)
        : <String, dynamic>{};
    final odulRaw = map['kazanilanSeviyeOdulleri'];
    final oduller = odulRaw is List
        ? odulRaw.map((e) => _int(e, 0)).where((e) => e > 0).toList()
        : <int>[];
    final simdi = _simdiMs();

    return MascotDurum(
      isim: (map['isim'] ?? 'Mini Vibe').toString(),
      seviye: _int(map['seviye'], 1),
      gelisimPuani: _int(map['gelisimPuani'], 0),
      etkilesimPuani: _int(map['etkilesimPuani'], 0),
      tokluk: _clampStat(_int(map['tokluk'], 80)),
      enerji: _clampStat(_int(map['enerji'], 70)),
      mutluluk: _clampStat(_int(map['mutluluk'], 65)),
      sonBakim: sonBakim,
      kazanilanSeviyeOdulleri: oduller,
      uykuBitisMs: _int(map['uykuBitisMs'], 0),
      sonAktiviteMs: _int(map['sonAktiviteMs'], simdi),
      sonEnerjiDususMs: _int(map['sonEnerjiDususMs'], simdi),
    );
  }

  // Maskot şu an uyuyor mu
  static bool uyuyorMu(MascotDurum robot) => robot.uykuBitisMs > _simdiMs();

  // Erken uyandırma mümkün mü (11+ fazda enerji eşiği)
  static bool erkenUyandirabilir(MascotDurum robot) {
    if (!uyuyorMu(robot)) return false;
    if (!uyuSistemiAcik(robot.seviye)) return true;
    return robot.enerji > uyuErkenUyandirmaMinEnerji;
  }

  static String? uyandirEngelMesaji(MascotDurum robot) {
    if (!uyuyorMu(robot)) return null;
    if (!odaAcik(robot.seviye)) return 'Maskot odası henüz açık değil.';
    if (uyuSistemiAcik(robot.seviye) &&
        robot.enerji <= uyuErkenUyandirmaMinEnerji) {
      return 'Enerji %$uyuErkenUyandirmaMinEnerji altındayken erken uyandırılamaz.';
    }
    return null;
  }

  static Duration? uykuKalanSure(MascotDurum robot) {
    if (!uyuyorMu(robot)) return null;
    return Duration(milliseconds: robot.uykuBitisMs - _simdiMs());
  }

  // Duruma göre animasyon durumu seçer
  static MascotGorselDurum gorselDurum(MascotDurum robot) {
    if (odaAcik(robot.seviye) && uyuyorMu(robot)) {
      return MascotGorselDurum.uyku;
    }
    if (enerjiAktif(robot.seviye) && robot.enerji <= 25) {
      return MascotGorselDurum.yorgun;
    }
    if (toklukAktif(robot.seviye) && robot.tokluk <= 25) {
      return MascotGorselDurum.uzgun;
    }
    if (mutlulukAktif(robot.seviye) && robot.mutluluk <= 25) {
      return MascotGorselDurum.uzgun;
    }
    if (mutlulukAktif(robot.seviye) &&
        robot.mutluluk >= 75 &&
        (!enerjiAktif(robot.seviye) || robot.enerji >= 50) &&
        (!toklukAktif(robot.seviye) || robot.tokluk >= 50)) {
      return MascotGorselDurum.mutlu;
    }
    if (toklukAktif(robot.seviye) &&
        !enerjiAktif(robot.seviye) &&
        robot.tokluk >= 70) {
      return MascotGorselDurum.mutlu;
    }
    return MascotGorselDurum.normal;
  }

  // Aksiyon tipine göre enerji maliyeti
  static int etkilesimEnerjiMaliyeti(String aksiyonTipi) {
    switch (aksiyonTipi) {
      case 'gonderi':
        return etkilesimEnerjiGonderi;
      case 'yorum':
        return etkilesimEnerjiYorum;
      case 'begeni':
        return etkilesimEnerjiBegeni;
      default:
        return 1;
    }
  }

  // Maskot etkileşimleri: 11+ dusuk enerjide kilitlenir.
  static void _etkilesimEngeli(
    MascotDurum robot, {
    required int enerjiMaliyeti,
  }) {
    if (enerjiAktif(robot.seviye)) {
      if (uyuyorMu(robot)) {
        throw '${robot.isim} uyuyor. Dinlenene kadar etkileşim yapılamaz.';
      }
      if (robot.enerji <= etkilesimEnerjiKilitEsigi) {
        throw '${robot.isim} çok yorgun. Uyutup enerji toplamalısın.';
      }
      if (robot.enerji < enerjiMaliyeti) {
        throw '${robot.isim} için yeterli enerji yok.';
      }
    }
  }

  // Firestore'dan maskot durumunu okuyup engel kontrolü yapar
  static Future<void> etkilesimEngelliyseAt(
    String uid, {
    required String aksiyonTipi,
  }) async {
    if (!enabled) return; // Maskot devre dışıysa etkileşim engeli yok
    if (uid.isEmpty) return;
    final snap = await _db.collection('users').doc(uid).get();
    etkilesimEngeliVeriden(
      snap.data(),
      aksiyonTipi: aksiyonTipi,
    );
  }

  static void etkilesimEngeliVeriden(
    Map<String, dynamic>? userData, {
    required String aksiyonTipi,
  }) {
    if (!enabled) return; // Maskot devre dışıysa hiçbir etkileşim engellenmez
    if (userData == null) return;
    final robot = parse(userData['robot']);
    _etkilesimEngeli(
      robot,
      enerjiMaliyeti: etkilesimEnerjiMaliyeti(aksiyonTipi),
    );
  }

  // Maskot ruh hali mesajını döndürür
  static String ruhHaliMesaji(MascotDurum robot) {
    if (robot.seviye < toklukAcilisSeviyesi) {
      return 'Seninle vibe kasıyorum!';
    }
    if (odaAcik(robot.seviye) && robot.uyuyor) {
      return '${robot.isim} dinleniyor...';
    }
    if (enerjiAktif(robot.seviye) && robot.enerji <= etkilesimEnerjiKilitEsigi) {
      return 'Çok yoruldum, biraz uyumam lazım...';
    }
    if (toklukAktif(robot.seviye) && robot.tokluk <= 25) {
      if (robot.etkilesimPuani < yemekEtkilesimMaliyeti) {
        return 'Etkileşim puanın lazım, yemek verelim mi?';
      }
      return 'Acıktım, birlikte yemek zamanı mı?';
    }
    if (mutlulukAktif(robot.seviye) && robot.mutluluk <= 30) {
      return 'Seni özledim, birlikte takılalım mı?';
    }
    if (mutlulukAktif(robot.seviye) &&
        robot.mutluluk >= 80 &&
        robot.tokluk >= 60 &&
        robot.enerji >= 50) {
      return 'Harika hissediyorum! Vibe\'ım zirvede!';
    }
    if (robot.seviye < enerjiAcilisSeviyesi) {
      return 'Etkileşim puanınla yemek ver, birlikte büyüyelim.';
    }
    if (robot.seviye < mutlulukAcilisSeviyesi) {
      if (robot.etkilesimPuani < uykuEtkilesimMaliyeti &&
          robot.enerji <= uyuMaxEnerji) {
        return 'Etkileşim puanınla uyutup enerji toplayabilirsin.';
      }
      return 'Enerjimi dengede tut, etkileşim puanınla uyku ver.';
    }
    return 'Seninle güçlü bir bağ kurduk!';
  }

  static bool senkronMesajBasariMi(String mesaj) {
    return mesaj.contains('uyandı');
  }

  static bool senkronMesajBilgiMi(String mesaj) {
    return mesaj.contains('uyuyor') || mesaj == 'Maskotun seni çok özledi';
  }

  static String seviyeOdulAciklamasi(int seviye) {
    switch (seviye) {
      case 2:
        return 'Daha fazla ruh hali mesajı açıldı';
      case 3:
        return 'Maskot bağları güçlendi';
      case 4:
        return 'Bakım etkisi güçlendi';
      case 5:
        return 'Yeni maskot görünümü';
      case 6:
        return 'Tokluk ve yemek açıldı';
      case 11:
        return 'Enerji ve uyku açıldı';
      case 21:
        return 'Mutluluk ve güçlü bağ';
      default:
        return 'Seviye $seviye ödülü kazanıldı';
    }
  }

  static Map<String, dynamic> _robotHaritasi(dynamic raw) {
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    final simdi = _simdiMs();
    return {
      'isim': 'Mini Vibe',
      'seviye': 1,
      'gelisimPuani': 0,
      'etkilesimPuani': 0,
      'tokluk': 80,
      'enerji': 70,
      'mutluluk': 65,
      'sonUygulamaMs': simdi,
      'sonEtkilesimMs': simdi,
      'sonMutlulukTickMs': simdi,
      'sonEnerjiDususMs': simdi,
    };
  }

  static int _mutlulukDususMiktari({
    required int gecenMs,
    required int tamBosalmaDakika,
  }) {
    if (gecenMs <= 0 || tamBosalmaDakika <= 0) return 0;
    final toplamMs = tamBosalmaDakika * _dakikaMs;
    return (gecenMs * 100) ~/ toplamMs;
  }

  static int _mutlulukDususTuketilenMs({
    required int dususMiktari,
    required int tamBosalmaDakika,
  }) {
    if (dususMiktari <= 0 || tamBosalmaDakika <= 0) return 0;
    final toplamMs = tamBosalmaDakika * _dakikaMs;
    return (dususMiktari * toplamMs) ~/ 100;
  }

  static int _uykudaEnerjiHesapla({
    required int baslangicEnerji,
    required int uykuBaslangicMs,
    required int simdiMs,
  }) {
    if (simdiMs <= uykuBaslangicMs) {
      return _clampStat(baslangicEnerji);
    }
    final dakikaUykuda = ((simdiMs - uykuBaslangicMs) / _dakikaMs).floor();
    final artis = (dakikaUykuda * uykuEnerjiDakikaBasina).round();
    final sinirliArtis =
        artis > uykuMaxEnerjiArtisi ? uykuMaxEnerjiArtisi : artis;
    return _clampStat(baslangicEnerji + sinirliArtis);
  }

  static void _etkilesimKaydet(Map<String, dynamic> robot, int simdiMs) {
    robot['sonEtkilesimMs'] = simdiMs;
    robot['sonMutlulukTickMs'] = simdiMs;
  }

  static int _toklukDususUygula({
    required Map<String, dynamic> robot,
    required int simdiMs,
    required bool uygulamaAcildi,
  }) {
    var tokluk = _clampStat(_int(robot['tokluk'], 80));
    var sonUygulama =
        _int(robot['sonUygulamaMs'] ?? robot['sonAktiviteMs'], simdiMs);
    var sonEtkilesim =
        _int(robot['sonEtkilesimMs'] ?? robot['sonAktiviteMs'], sonUygulama);
    var tick = _int(robot['sonToklukTickMs'], sonUygulama);

    if (uygulamaAcildi && simdiMs > sonUygulama) {
      final awayGecenMs = simdiMs - sonUygulama;
      final awayDusus = _mutlulukDususMiktari(
        gecenMs: awayGecenMs,
        tamBosalmaDakika: toklukUygulamaDisiDakika,
      );
      if (awayDusus > 0) {
        tokluk = _clampStat(tokluk - awayDusus);
      }
      sonUygulama = simdiMs;
      robot['sonUygulamaMs'] = simdiMs;
    }

    final pasifBaslangic =
        sonEtkilesim > sonUygulama ? sonEtkilesim : sonUygulama;
    final pasifFrom = tick > pasifBaslangic ? tick : pasifBaslangic;
    if (simdiMs > pasifFrom) {
      final pasifGecenMs = simdiMs - pasifFrom;
      final pasifDusus = _mutlulukDususMiktari(
        gecenMs: pasifGecenMs,
        tamBosalmaDakika: toklukEtkilesimsizDakika,
      );
      if (pasifDusus > 0) {
        tokluk = _clampStat(tokluk - pasifDusus);
        tick = pasifFrom +
            _mutlulukDususTuketilenMs(
              dususMiktari: pasifDusus,
              tamBosalmaDakika: toklukEtkilesimsizDakika,
            );
      }
    }

    robot['sonToklukTickMs'] = simdiMs;
    return tokluk;
  }

  static int _mutlulukDususUygula({
    required Map<String, dynamic> robot,
    required int simdiMs,
    required bool uygulamaAcildi,
  }) {
    var mutluluk = _clampStat(_int(robot['mutluluk'], 50));
    var sonUygulama =
        _int(robot['sonUygulamaMs'] ?? robot['sonAktiviteMs'], simdiMs);
    var sonEtkilesim =
        _int(robot['sonEtkilesimMs'] ?? robot['sonAktiviteMs'], sonUygulama);
    var tick = _int(robot['sonMutlulukTickMs'], sonUygulama);

    if (uygulamaAcildi && simdiMs > sonUygulama) {
      final awayGecenMs = simdiMs - sonUygulama;
      final awayDusus = _mutlulukDususMiktari(
        gecenMs: awayGecenMs,
        tamBosalmaDakika: mutlulukUygulamaDisiDakika,
      );
      if (awayDusus > 0) {
        mutluluk = _clampStat(
          mutluluk - awayDusus,
        );
      }
      sonUygulama = simdiMs;
      robot['sonUygulamaMs'] = simdiMs;
    }

    final pasifBaslangic =
        sonEtkilesim > sonUygulama ? sonEtkilesim : sonUygulama;
    final pasifFrom = tick > pasifBaslangic ? tick : pasifBaslangic;
    if (simdiMs > pasifFrom) {
      final pasifGecenMs = simdiMs - pasifFrom;
      final pasifDusus = _mutlulukDususMiktari(
        gecenMs: pasifGecenMs,
        tamBosalmaDakika: mutlulukEtkilesimsizDakika,
      );
      if (pasifDusus > 0) {
        mutluluk = _clampStat(
          mutluluk - pasifDusus,
        );
        tick = pasifFrom +
            _mutlulukDususTuketilenMs(
              dususMiktari: pasifDusus,
              tamBosalmaDakika: mutlulukEtkilesimsizDakika,
            );
      }
    }

    robot['sonMutlulukTickMs'] = simdiMs;
    robot['sonUygulamaMs'] = sonUygulama;
    robot['sonEtkilesimMs'] = sonEtkilesim;
    return mutluluk;
  }

  static void _robotUyandir(Map<String, dynamic> robot) {
    robot['uykuBitisMs'] = 0;
    robot['uykuBaslangicMs'] = 0;
    robot['uykuBaslangicEnerji'] = 0;
    robot['mutluluk'] =
        _clampStat(_int(robot['mutluluk'], 50) + uyanincaMutlulukBonus);
  }

  /// 11. seviye oncesi kalan uyku kayitlarini isler (eski surum uyumlulugu).
  static List<String> _legacyUykuIsle(
    Map<String, dynamic> robot,
    int seviye,
    int simdiMs, {
    bool uygulamaAcildi = false,
  }) {
    final mesajlar = <String>[];
    if (uyuSistemiAcik(seviye)) return mesajlar;

    final uykuBitis = _int(robot['uykuBitisMs'], 0);
    if (uykuBitis <= 0) return mesajlar;

    if (simdiMs >= uykuBitis) {
      _robotUyandir(robot);
      mesajlar.add('${robot['isim'] ?? 'Maskot'} uyandı!');
      return mesajlar;
    }

    if (uygulamaAcildi) {
      mesajlar.add('${robot['isim'] ?? 'Maskot'} dinleniyor...');
    }
    return mesajlar;
  }

  static List<String> _zamanGuncelle(
    Map<String, dynamic> robot,
    int simdiMs, {
    bool uygulamaAcildi = false,
    bool etkilesimKaydedildi = false,
  }) {
    _sonBakimTemizle(robot);
    final mesajlar = <String>[];
    var enerji = _clampStat(_int(robot['enerji'], 70));
    var mutluluk = _clampStat(_int(robot['mutluluk'], 65));
    var tokluk = _clampStat(_int(robot['tokluk'], 80));
    final seviye = _int(robot['seviye'], 1);
    if (!odaAcik(seviye)) {
      return mesajlar;
    }

    if (toklukAktif(seviye)) {
      tokluk = _toklukDususUygula(
        robot: robot,
        simdiMs: simdiMs,
        uygulamaAcildi: uygulamaAcildi,
      );
    }

    if (mutlulukAktif(seviye)) {
      final oncekiMutluluk = mutluluk;
      mutluluk = _mutlulukDususUygula(
        robot: robot,
        simdiMs: simdiMs,
        uygulamaAcildi: uygulamaAcildi,
      );
      if (etkilesimKaydedildi) {
        _etkilesimKaydet(robot, simdiMs);
      }
      final mutlulukDususu = oncekiMutluluk - mutluluk;
      if (uygulamaAcildi && mutlulukDususu >= 5) {
        mesajlar.add('${robot['isim'] ?? 'Maskot'} seni özledi');
      }
    } else if (etkilesimKaydedildi) {
      _etkilesimKaydet(robot, simdiMs);
    }

    mesajlar.addAll(
      _legacyUykuIsle(
        robot,
        seviye,
        simdiMs,
        uygulamaAcildi: uygulamaAcildi,
      ),
    );

    if (!enerjiAktif(seviye)) {
      robot['tokluk'] = tokluk;
      robot['mutluluk'] = mutluluk;
      robot['enerji'] = enerji;
      return mesajlar;
    }

    final uykuBitis = _int(robot['uykuBitisMs'], 0);
    var uykuBaslangic = _int(robot['uykuBaslangicMs'], 0);
    if (uykuBaslangic <= 0 && uykuBitis > 0) {
      uykuBaslangic = uykuBitis - uyuSureMs;
    }
    final halaUyuyor = uykuBitis > simdiMs;

    if (uygulamaAcildi && halaUyuyor) {
      mesajlar.add('${robot['isim'] ?? 'Maskot'} dinleniyor...');
    }

    if (uykuBitis > 0) {
      if (simdiMs >= uykuBitis) {
        final baslangicEnerji = _int(robot['uykuBaslangicEnerji'], enerji);
        enerji = _uykudaEnerjiHesapla(
          baslangicEnerji: baslangicEnerji,
          uykuBaslangicMs: uykuBaslangic,
          simdiMs: uykuBitis,
        );
        robot['enerji'] = enerji;
        _robotUyandir(robot);
        mutluluk = _int(robot['mutluluk'], mutluluk);
        _gelisimVeSeviyeUygula(robot, uykuGelisimPuani);
        mesajlar.add('${robot['isim'] ?? 'Maskot'} uyandı!');
      } else {
        final baslangicEnerji = _int(robot['uykuBaslangicEnerji'], enerji);
        enerji = _uykudaEnerjiHesapla(
          baslangicEnerji: baslangicEnerji,
          uykuBaslangicMs: uykuBaslangic,
          simdiMs: simdiMs,
        );
        robot['enerji'] = enerji;
        robot['tokluk'] = tokluk;
        robot['mutluluk'] = mutluluk;
        return mesajlar;
      }
    }

    robot['enerji'] = enerji;
    robot['tokluk'] = tokluk;
    robot['mutluluk'] = mutluluk;
    return mesajlar;
  }

  static void _uykuEngeli(Map<String, dynamic> robot) {
    if (_int(robot['uykuBitisMs'], 0) > _simdiMs()) {
      throw '${robot['isim'] ?? 'Maskot'} uyuyor. Maskot uyanana kadar bu işlem kapalı.';
    }
  }

  static List<int> _seviyeOdulleriniIsle(
    Map<String, dynamic> robot,
    int seviye,
  ) {
    final mevcutRaw = robot['kazanilanSeviyeOdulleri'];
    final mevcut = mevcutRaw is List
        ? mevcutRaw.map((e) => _int(e, 0)).where((e) => e > 0).toSet()
        : <int>{};
    final yeni = <int>[];
    for (final odulSeviye in _odulSeviyeleri) {
      if (seviye >= odulSeviye && !mevcut.contains(odulSeviye)) {
        mevcut.add(odulSeviye);
        yeni.add(odulSeviye);
      }
    }
    robot['kazanilanSeviyeOdulleri'] = mevcut.toList()..sort();
    return yeni;
  }

  // Uygulama açılışında zaman/mutluluk senkronizasyonu
  static Future<MascotSenkronSonuc?> senkronizeEt(String uid) async {
    if (!enabled) {
      return MascotSenkronSonuc(robot: parse(null), mesajlar: const []);
    }
    if (uid.isEmpty) return null;
    final ref = _db.collection('users').doc(uid);
    try {
      return await _db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) return null;
        final robot = _robotHaritasi(snap.data()?['robot']);
        final seviye = _int(robot['seviye'], 1);
        _fazStatlariniHizala(robot, seviye);
        if (!odaAcik(seviye)) {
          return MascotSenkronSonuc(robot: parse(robot), mesajlar: const []);
        }
        final mesajlar =
            _zamanGuncelle(robot, _simdiMs(), uygulamaAcildi: true);
        tx.update(ref, {'robot': robot});
        return MascotSenkronSonuc(
          robot: parse(robot),
          mesajlar: mesajlar,
        );
      });
    } catch (e) {
      debugPrint('Maskot senkronizasyon hatası: $e');
      return null;
    }
  }

  /// Uygulama açıkken dakikalık mutluluk düşüşü (etkileşimsiz 4 saat kuralı).
  static Future<void> dakikaSenkronizeEt(String uid) async {
    if (!enabled) return;
    if (uid.isEmpty) return;
    final ref = _db.collection('users').doc(uid);
    try {
      await _db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) return;
        final robot = _robotHaritasi(snap.data()?['robot']);
        if (!odaAcik(_int(robot['seviye'], 1))) return;
        _zamanGuncelle(robot, _simdiMs());
        tx.update(ref, {'robot': robot});
      });
    } catch (e) {
      debugPrint('Maskot dakika senkron hatası: $e');
    }
  }

  /// @deprecated Otomatik gelisim etkilesimden gelir; gelistir butonu kaldirildi.
  static Future<MascotGelistirSonuc> gelistir(String uid) async {
    if (!enabled) {
      // Maskot devre dışıyken geliştirilemez; boş bir sonuç dönülür.
      return const MascotGelistirSonuc(
        seviyeAtladi: false,
        eskiSeviye: 1,
        yeniSeviye: 1,
        yeniSeviyeOdulleri: [],
      );
    }
    final ref = _db.collection('users').doc(uid);
    return _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data() ?? {};
      final puan = _int(data['puan'], 0);
      if (puan < gelistirmeMaliyeti) {
        throw 'Geliştirmek için en az $gelistirmeMaliyeti puan gerekir.';
      }

      final robot = _robotHaritasi(data['robot']);
      final simdi = _simdiMs();
      _zamanGuncelle(robot, simdi, etkilesimKaydedildi: true);
      _uykuEngeli(robot);
      _etkilesimEngeli(parse(robot), enerjiMaliyeti: 0);

      var seviye = _int(robot['seviye'], 1);
      final eskiSeviye = seviye;
      var gelisimPuani = _int(robot['gelisimPuani'], 0);
      gelisimPuani += gelistirmeMaliyeti;

      var gerekli = gerekliGelisimPuani(seviye);
      var seviyeAtladi = false;
      while (gelisimPuani >= gerekli) {
        gelisimPuani -= gerekli;
        seviye += 1;
        seviyeAtladi = true;
        gerekli = gerekliGelisimPuani(seviye);
      }

      robot['seviye'] = seviye;
      robot['gelisimPuani'] = gelisimPuani;
      if (odaAcik(seviye)) {
        robot['mutluluk'] = _clampStat(_int(robot['mutluluk'], 50) + 8);
      }

      final yeniOduller =
          seviyeAtladi ? _seviyeOdulleriniIsle(robot, seviye) : <int>[];

      tx.update(ref, {
        'puan': FieldValue.increment(-gelistirmeMaliyeti),
        'robot': robot,
      });

      return MascotGelistirSonuc(
        seviyeAtladi: seviyeAtladi,
        eskiSeviye: eskiSeviye,
        yeniSeviye: seviye,
        yeniSeviyeOdulleri: yeniOduller,
      );
    });
  }

  // Maskot ismini günceller
  static Future<String> isimGuncelle(String uid, String yeniIsim) async {
    final temiz = yeniIsim.trim();
    if (temiz.isEmpty || temiz.length > 24) {
      throw 'Maskot ismi 1-24 karakter olmalı.';
    }
    if (!enabled) {
      // Maskot devre dışı — DB güncellemesi yapılmaz, fakat çağırana başarılı dönüş verilir.
      return temiz;
    }
    await _db.collection('users').doc(uid).update({'robot.isim': temiz});
    return temiz;
  }

  // Uyuyan maskotu erken uyandırır
  static Future<String> uyandir(String uid) async {
    if (!enabled) return 'Maskot sistemi devre dışı.';
    final ref = _db.collection('users').doc(uid);
    return _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final robot = _robotHaritasi(snap.data()?['robot']);
      final seviye = _int(robot['seviye'], 1);
      if (!odaAcik(seviye)) {
        throw 'Maskot odası henüz açık değil.';
      }
      final simdi = _simdiMs();
      _zamanGuncelle(robot, simdi, etkilesimKaydedildi: true);

      if (_int(robot['uykuBitisMs'], 0) <= simdi) {
        throw 'Maskot zaten uyanık.';
      }

      if (uyuSistemiAcik(seviye)) {
        final enerji = _int(robot['enerji'], 50);
        if (enerji <= uyuErkenUyandirmaMinEnerji) {
          throw 'Enerji %$uyuErkenUyandirmaMinEnerji altındayken erken uyandırılamaz.';
        }
      }

      _robotUyandir(robot);
      tx.update(ref, {'robot': robot});
      return '${robot['isim'] ?? 'Maskot'} uyandı!';
    });
  }

  // Maskotu uyutmaya başlatır
  static Future<String> uyuYap(String uid) async {
    if (!enabled) return 'Maskot sistemi devre dışı.';
    final ref = _db.collection('users').doc(uid);
    return _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final robot = _robotHaritasi(snap.data()?['robot']);
      if (!uyuSistemiAcik(_int(robot['seviye'], 1))) {
        throw 'Uyku ${enerjiAcilisSeviyesi}. seviyede açılır.';
      }
      final simdi = _simdiMs();
      _zamanGuncelle(robot, simdi, etkilesimKaydedildi: true);

      final enerji = _int(robot['enerji'], 70);
      if (enerji > uyuMaxEnerji) {
        throw 'Enerji %51 ve üzerindeyken maskot uyuyamaz.';
      }
      if (_int(robot['uykuBitisMs'], 0) > simdi) {
        throw 'Maskot zaten uyuyor.';
      }

      _etkilesimPuaniHarca(robot, uykuEtkilesimMaliyeti);

      if (toklukAktif(_int(robot['seviye'], 1))) {
        robot['tokluk'] =
            _clampStat(_int(robot['tokluk'], 80) - 18);
      }

      robot['uykuBaslangicEnerji'] = enerji;
      robot['uykuBaslangicMs'] = simdi;
      robot['uykuBitisMs'] = simdi + uyuSureMs;

      tx.update(ref, {'robot': robot});
      return 'Maskot uyumaya başladı ($uykuEtkilesimMaliyeti etkileşim puanı). '
          '4 saatte enerji %$uykuMaxEnerjiArtisi dolacak.';
    });
  }

  // Sosyal aksiyon sonrasi (11+ enerji dusumu, 21+ mutluluk).
  static Future<void> sosyalAksiyon(String uid, String tip) async {
    if (!enabled) return;
    if (uid.isEmpty) return;
    final ref = _db.collection('users').doc(uid);
    try {
      await _db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) return;
        final robot = _robotHaritasi(snap.data()?['robot']);
        if (!odaAcik(_int(robot['seviye'], 1))) return;
        final simdi = _simdiMs();
        _zamanGuncelle(robot, simdi, etkilesimKaydedildi: true);
        if (_int(robot['uykuBitisMs'], 0) > simdi) return;

        final seviye = _int(robot['seviye'], 1);
        final maliyet = etkilesimEnerjiMaliyeti(tip);

        if (enerjiAktif(seviye)) {
          if (_int(robot['enerji'], 70) < maliyet) return;
          robot['enerji'] =
              _clampStat(_int(robot['enerji'], 70) - maliyet);
        }

        if (mutlulukAktif(seviye)) {
          switch (tip) {
            case 'gonderi':
              robot['mutluluk'] = _clampStat(
                _int(robot['mutluluk'], 65) + mutlulukEtkilesimGonderi,
              );
              break;
            case 'yorum':
              robot['mutluluk'] = _clampStat(
                _int(robot['mutluluk'], 65) + mutlulukEtkilesimYorum,
              );
              break;
            case 'begeni':
              robot['mutluluk'] = _clampStat(
                _int(robot['mutluluk'], 65) + mutlulukEtkilesimBegeni,
              );
              break;
          }
        }

        tx.update(ref, {'robot': robot});
      });
    } catch (e) {
      debugPrint('Maskot sosyal aksiyon hatası ($tip): $e');
    }
  }

  // Bebek beslenmesiyle gelişim puanı artırır
  static Future<String> yemekVer(String uid) async {
    if (!enabled) return 'Maskot sistemi devre dışı.';
    if (uid.isEmpty) return 'Kullanıcı bulunamadı.';

    final ref = _db.collection('users').doc(uid);
    return _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) {
        throw 'Kullanıcı kaydı bulunamadı.';
      }

      final robot = _robotHaritasi(snap.data()?['robot']);
      final seviye = _int(robot['seviye'], 1);
      if (!yemekSistemiAcik(seviye)) {
        if (seviye < odaAcilisSeviyesi) {
          throw '$odaAcilisSeviyesi. seviye olana kadar yemek verilemez.';
        }
        throw 'Yemek geliştirme yalnızca 6-10 seviyeleri arasında geçerlidir.';
      }

      final simdi = _simdiMs();
      _zamanGuncelle(robot, simdi, etkilesimKaydedildi: true);
      _uykuEngeli(robot);
      _etkilesimPuaniHarca(robot, yemekEtkilesimMaliyeti);

      final yeniOduller =
          _gelisimVeSeviyeUygula(robot, yemekGelisimPuani);
      final seviyeAtladi = _int(robot['seviye'], 1) > seviye;

      robot['tokluk'] = 100;
      robot['mutluluk'] = _clampStat(_int(robot['mutluluk'], 65) + 10);

      tx.update(ref, {'robot': robot});

      if (seviyeAtladi) {
        final odulMetni = yeniOduller.isNotEmpty
            ? ' Yeni ödüller: ${yeniOduller.join(', ')}.'
            : '';
        return 'Lezzetli! ($yemekEtkilesimMaliyeti puan harcandı) '
            'Tokluk doldu, $yemekGelisimPuani gelişim kazandın. Seviye atlandı!$odulMetni';
      }
      return 'Lezzetli! ($yemekEtkilesimMaliyeti puan harcandı) '
          'Tokluk doldu, $yemekGelisimPuani gelişim kazandın.';
    });
  }
}
