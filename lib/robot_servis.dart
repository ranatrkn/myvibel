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

  static const gelistirmeMaliyeti = 20; // Geliştirme puan maliyeti
  static const odaAcilisSeviyesi = 6; // Maskot alanı açılış seviyesi
  static const uyuMaxEnerji = 50; // Uyku için max enerji eşiği
  static const uyuErkenUyandirmaMinEnerji = 30; // Erken uyandırma min enerji
  static const uyuSureMs = 4 * 60 * 60 * 1000; // Uyku süresi (4 saat)
  static const uykuEnerjiDakikaBasina = 0.2; // Uykuda dakika başı enerji
  static const uykuMaxEnerjiArtisi = 50; // Uykuda max enerji artışı
  static const yemekGelisimPuani = 50; // Yemekle kazanılan gelişim puanı
  static const etkilesimEnerjiGonderi = 5; // Gönderi enerji maliyeti
  static const etkilesimEnerjiYorum = 3; // Yorum enerji maliyeti
  static const etkilesimEnerjiBegeni = 1; // Beğeni enerji maliyeti
  /// Uygulama kapalıyken mutluluğun sıfıra inme süresi (dakika).
  static const mutlulukUygulamaDisiDakika = 120;

  /// Uygulama açıkken etkileşim yoksa mutluluğun sıfıra inme süresi (dakika).
  static const mutlulukEtkilesimsizDakika = 240;
  static const uyanincaMutlulukBonus = 5; // Uyanınca mutluluk bonusu
  static const _dakikaMs = 60 * 1000;
  // Maskot sistemi etkin. 1-5 seviyelerde etkileşim puanları otomatik gelişim sağlar.
  static const bool enabled = true;

  // Etkileşim puanlarını 1-5 seviyelerde maskot gelişimine aktarır.
  static Future<void> etkilesimPuaniniGelismeyeEkle(
    String uid,
    int puan,
  ) async {
    if (!enabled || uid.isEmpty || puan <= 0) return;
    final ref = _db.collection('users').doc(uid);
    try {
      await _db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) return;
        final data = snap.data() ?? <String, dynamic>{};
        final robot = _robotHaritasi(data['robot']);
        var seviye = _int(robot['seviye'], 1);
        if (seviye >= odaAcilisSeviyesi) return;

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
        }

        tx.update(ref, {'robot': robot});
      });
    } catch (e) {
      debugPrint('Maskot etkileşim gelişim puanı güncelleme hatası: $e');
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

  static bool yemekSistemiAcik(int seviye) =>
      seviye >= odaAcilisSeviyesi && seviye <= 10;

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const _odulSeviyeleri = [2, 3, 4, 5, 7, 10];

  static int gerekliGelisimPuani(int seviye) =>
      seviye < odaAcilisSeviyesi ? 100 : 500;

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
      enerji: _clampStat(_int(map['enerji'], 50)),
      mutluluk: _clampStat(_int(map['mutluluk'], 50)),
      sonBakim: sonBakim,
      kazanilanSeviyeOdulleri: oduller,
      uykuBitisMs: _int(map['uykuBitisMs'], 0),
      sonAktiviteMs: _int(map['sonAktiviteMs'], simdi),
      sonEnerjiDususMs: _int(map['sonEnerjiDususMs'], simdi),
    );
  }

  // Maskot şu an uyuyor mu
  static bool uyuyorMu(MascotDurum robot) => robot.uykuBitisMs > _simdiMs();

  // Erken uyandırma mümkün mü
  static bool erkenUyandirabilir(MascotDurum robot) =>
      uyuyorMu(robot) && robot.enerji > uyuErkenUyandirmaMinEnerji;

  static Duration? uykuKalanSure(MascotDurum robot) {
    if (!uyuyorMu(robot)) return null;
    return Duration(milliseconds: robot.uykuBitisMs - _simdiMs());
  }

  // Duruma göre animasyon durumu seçer
  static MascotGorselDurum gorselDurum(MascotDurum robot) {
    if (!odaAcik(robot.seviye)) return MascotGorselDurum.normal;
    if (uyuyorMu(robot)) return MascotGorselDurum.uyku;
    if (robot.enerji <= 25) return MascotGorselDurum.yorgun;
    if (robot.mutluluk >= 70) return MascotGorselDurum.mutlu;
    if (robot.mutluluk <= 25) return MascotGorselDurum.uzgun;
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

  // Maskot etkileşimleri 1-10 seviyelerde kullanıcıya kısıtlama getirmez.
  static void _etkilesimEngeli(MascotDurum robot,
      {required int enerjiMaliyeti}) {
    if (!odaAcik(robot.seviye)) return;
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
    if (!odaAcik(robot.seviye)) {
      return '';
    }
    if (robot.uyuyor) {
      return '${robot.isim} uyuyor...';
    }
    if (robot.enerji <= 0) {
      return 'Enerjim bitti, uyuyana kadar etkileşim yapamam...';
    }
    if (robot.enerji <= 25) {
      return 'Çok yoruldum, uyumam lazım...';
    }
    if (robot.mutluluk <= 30) {
      return 'Biraz sessizim, uygulamada etkileşime geçelim mi?';
    }
    if (robot.mutluluk >= 80 && robot.enerji >= 60) {
      return 'Harika hissediyorum! Vibe\'ım zirvede!';
    }
    if (robot.seviye >= odaAcilisSeviyesi) {
      return 'Büyüdüm ama hâlâ seninle gelişmek istiyorum.';
    }
    return 'Seninle vibe kasıyorum!';
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
        return 'Evrim! Yeni maskot görünümü';
      case 7:
        return 'Profil rozet efekti';
      case 10:
        return 'Efsane maskot unvanı';
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
      'enerji': 50,
      'mutluluk': 50,
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

  static List<String> _zamanGuncelle(
    Map<String, dynamic> robot,
    int simdiMs, {
    bool uygulamaAcildi = false,
    bool etkilesimKaydedildi = false,
  }) {
    _sonBakimTemizle(robot);
    final mesajlar = <String>[];
    var enerji = _clampStat(_int(robot['enerji'], 50));
    var mutluluk = _clampStat(_int(robot['mutluluk'], 50));
    final seviye = _int(robot['seviye'], 1);
    if (!odaAcik(seviye)) {
      // 6 alti seviyelerde maskot enerji/mutluluk sistemi tamamen pasif.
      return mesajlar;
    }
    final uykuBitis = _int(robot['uykuBitisMs'], 0);
    var uykuBaslangic = _int(robot['uykuBaslangicMs'], 0);
    if (uykuBaslangic <= 0 && uykuBitis > 0) {
      uykuBaslangic = uykuBitis - uyuSureMs;
    }
    final halaUyuyor = uykuBitis > simdiMs;
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
    if (uygulamaAcildi && halaUyuyor) {
      mesajlar.add('${robot['isim'] ?? 'Maskot'} uyuyor...');
    } else if (mutlulukDususu >= 5) {
      mesajlar.add('Maskotun seni çok özledi');
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
        mesajlar.add('${robot['isim'] ?? 'Maskot'} uyandı!');
      } else {
        final baslangicEnerji = _int(robot['uykuBaslangicEnerji'], enerji);
        enerji = _uykudaEnerjiHesapla(
          baslangicEnerji: baslangicEnerji,
          uykuBaslangicMs: uykuBaslangic,
          simdiMs: simdiMs,
        );
        robot['enerji'] = enerji;
        robot['mutluluk'] = mutluluk;
        return mesajlar;
      }
    }

    robot['enerji'] = enerji;
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
        if (!odaAcik(_int(robot['seviye'], 1))) {
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

  // Puan harcayarak maskotu geliştirir
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
      if (!odaAcik(_int(robot['seviye'], 1))) {
        throw 'Maskot alanı $odaAcilisSeviyesi. seviyede açılır.';
      }
      final simdi = _simdiMs();
      _zamanGuncelle(robot, simdi, etkilesimKaydedildi: true);

      if (_int(robot['uykuBitisMs'], 0) <= simdi) {
        throw 'Maskot zaten uyanık.';
      }

      final enerji = _int(robot['enerji'], 50);
      if (enerji <= uyuErkenUyandirmaMinEnerji) {
        throw 'Enerji %$uyuErkenUyandirmaMinEnerji altındayken erken uyandırılamaz.';
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
      if (!odaAcik(_int(robot['seviye'], 1))) {
        throw 'Maskot alanı $odaAcilisSeviyesi. seviyede açılır.';
      }
      final simdi = _simdiMs();
      _zamanGuncelle(robot, simdi, etkilesimKaydedildi: true);

      final enerji = _int(robot['enerji'], 50);
      if (enerji > uyuMaxEnerji) {
        throw 'Enerji %51 ve üzerindeyken maskot uyuyamaz.';
      }
      if (_int(robot['uykuBitisMs'], 0) > simdi) {
        throw 'Maskot zaten uyuyor.';
      }

      robot['uykuBaslangicEnerji'] = enerji;
      robot['uykuBaslangicMs'] = simdi;
      robot['uykuBitisMs'] = simdi + uyuSureMs;

      tx.update(ref, {'robot': robot});
      return 'Maskot uyumaya başladı. 4 saatte enerji %$uykuMaxEnerjiArtisi dolacak.';
    });
  }

  // Sosyal aksiyon sonrası enerji/mutluluk günceller
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

        final maliyet = etkilesimEnerjiMaliyeti(tip);
        if (_int(robot['enerji'], 50) < maliyet) return;

        switch (tip) {
          case 'gonderi':
            robot['mutluluk'] = _clampStat(_int(robot['mutluluk'], 50) + 8);
            robot['enerji'] = _clampStat(_int(robot['enerji'], 50) - maliyet);
            break;
          case 'yorum':
            robot['mutluluk'] = _clampStat(_int(robot['mutluluk'], 50) + 4);
            robot['enerji'] = _clampStat(_int(robot['enerji'], 50) - maliyet);
            break;
          case 'begeni':
            robot['mutluluk'] = _clampStat(_int(robot['mutluluk'], 50) + 2);
            robot['enerji'] = _clampStat(_int(robot['enerji'], 50) - maliyet);
            break;
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

      var gelisimPuani = _int(robot['gelisimPuani'], 0);
      gelisimPuani += yemekGelisimPuani;

      var seviyeGuncel = seviye;
      var gerekli = gerekliGelisimPuani(seviyeGuncel);
      var seviyeAtladi = false;
      while (gelisimPuani >= gerekli) {
        gelisimPuani -= gerekli;
        seviyeGuncel += 1;
        seviyeAtladi = true;
        gerekli = gerekliGelisimPuani(seviyeGuncel);
      }

      robot['seviye'] = seviyeGuncel;
      robot['gelisimPuani'] = gelisimPuani;
      robot['mutluluk'] = _clampStat(_int(robot['mutluluk'], 50) + 8);

      final yeniOduller =
          seviyeAtladi ? _seviyeOdulleriniIsle(robot, seviyeGuncel) : <int>[];

      tx.update(ref, {'robot': robot});

      if (seviyeAtladi) {
        final odulMetni = yeniOduller.isNotEmpty
            ? ' Yeni ödüller: ${yeniOduller.join(', ')}.'
            : '';
        return 'Yemek verildi. $yemekGelisimPuani gelişim puanı kazanıldı. Seviye atlandı!$odulMetni';
      }
      return 'Yemek verildi. $yemekGelisimPuani gelişim puanı kazanıldı.';
    });
  }
}
