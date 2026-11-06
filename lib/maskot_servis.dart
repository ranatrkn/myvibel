// Maskot enerji, mutluluk, uyku ve gelişim mantığı.
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:myvibel/maskot_bakim_sozleri.dart';
import 'package:myvibel/maskot_bildirim_servis.dart';
import 'package:myvibel/rety_renk.dart';

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
    required this.sonToklukPozitifMs,
    this.renk = RetyRenk.varsayilan,
  });

  final String isim;
  final int seviye;
  final int gelisimPuani;
  /// Sosyal etkilesimlerden biriken vil (6+); Firestore: etkilesimPuani.
  final int etkilesimPuani;
  int get vil => etkilesimPuani;
  final int tokluk;
  final int enerji;
  final int mutluluk;
  final Map<String, dynamic> sonBakim;
  final List<int> kazanilanSeviyeOdulleri;
  final int uykuBitisMs;
  final int sonAktiviteMs;
  final int sonEnerjiDususMs;
  final int sonToklukPozitifMs;
  final RetyRenk renk;

  int get gerekliGelisim =>
      MascotServis.gerekliGelisimPuani(seviye); // Seviye atlama eşiği

  // Gelişim çubuğu oranı (0-1)
  double get gelisimOrani {
    if (gerekliGelisim <= 0) return 1;
    return (gelisimPuani / gerekliGelisim).clamp(0.0, 1.0);
  }

  bool get uyuyor => MascotServis.uyuyorMu(this); // Uyku durumu

  bool get aclikOlumRiski =>
      MascotServis.toklukAktif(seviye) && tokluk <= 0;

  MascotGorselDurum get gorselDurum =>
      MascotServis.gorselDurum(this); // Animasyon durumu
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

/// İki kişinin birbirinin Vibel'ine en az bir kez yemek vermesiyle oluşan bağ.
class RetyBagKaydi {
  const RetyBagKaydi({
    required this.otherUid,
    required this.benimMs,
    required this.onunMs,
    required this.ilkMs,
    this.takipKesildiMs = 0,
  });

  final String otherUid;
  final int benimMs;
  final int onunMs;
  final int ilkMs;
  final int takipKesildiMs;

  bool get bagVar => benimMs > 0 && onunMs > 0;

  int get sonMs => benimMs >= onunMs ? benimMs : onunMs;

  bool get takipKesilmeSuresiDoldu {
    if (takipKesildiMs <= 0) return false;
    return DateTime.now().millisecondsSinceEpoch - takipKesildiMs >=
        MascotServis.bagTakipKesilmeSureMs;
  }

  bool get parlak {
    if (!bagVar || takipKesilmeSuresiDoldu) return false;
    final sinir =
        DateTime.now().millisecondsSinceEpoch - MascotServis.bagSolmaMs;
    return benimMs >= sinir && onunMs >= sinir;
  }

  factory RetyBagKaydi.fromMap(String otherUid, Map<String, dynamic>? raw) {
    int oku(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return 0;
    }

    return RetyBagKaydi(
      otherUid: otherUid,
      benimMs: oku(raw?['benimMs']),
      onunMs: oku(raw?['onunMs']),
      ilkMs: oku(raw?['ilkMs']),
      takipKesildiMs: oku(raw?['takipKesildiMs']),
    );
  }
}

// Maskot oyun mekaniği servisi
class MascotServis {
  MascotServis._();

  static const varsayilanIsim = 'Vibel';
  static const odaAcilisSeviyesi = 6;
  static const toklukAcilisSeviyesi = 6;
  static const enerjiAcilisSeviyesi = 11;
  static const mutlulukAcilisSeviyesi = 21;
  static const gorevAcilisSeviyesi = 11;
  static const etkilesimEnerjiKilitEsigi = 10;
  static const uyuMaxEnerji = 50;
  static const uyuErkenUyandirmaMinEnerji = 30;
  static const uyuSureMs = 60 * 60 * 1000; // 0→100 enerji için 1 saat
  static const vilGonderi = 10;
  static const vilYorum = 3;
  static const vilBegeni = 2;
  static const vilTakip = 5;
  static const gonderiSilVilMaliyeti = 3;
  static const sosyalGeriAlVilMaliyeti = 2;
  static const vilTakipGeriAlMaliyeti = 3;
  static const yemekVilMaliyeti = 15;
  static const arkadasYemekVilMaliyeti = 20;
  static const reklamVilOdulu = 15;
  static const reklamVilGunlukSinir = 5;
  /// Karşılıklı yemek 30 gün içinde değilse rozet solar; silinmez.
  static const bagSolmaMs = 30 * 24 * 60 * 60 * 1000;
  /// Takipten çıkınca bağın silinmesi için tanınan süre.
  static const bagTakipKesilmeSureMs = 3 * 24 * 60 * 60 * 1000;
  static const yemekGelisimPuani = 15;
  static const uykuGelisimPuani = 40;
  static const yemekToklukArtisi = 20;
  static const yemekEnerjiArtisi = 8; // 5 yemek = %40 enerji
  /// Açken (tokluk ≤ 25) enerjinin 100→0 inme süresi.
  static const aclikEnerjiBosalmaDakika = 360;
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
  /// 300 dk = yaklaşık 5 saatte tam boşalma.
  static const toklukUygulamaDisiDakika = 300;
  /// Uygulama açıkken etkileşim yoksa tokluk düşüşü (dakika).
  /// Uygulama dışı hızla aynı tutulur; davranış daha öngörülebilir olur.
  static const toklukEtkilesimsizDakika = 300;
  /// Tokluk 0 olduktan sonra yumurtaya dönüş süresi.
  static const aclikOlumSureMs = 3 * 24 * 60 * 60 * 1000;
  static const mutlulukUygulamaDisiDakika = 180;
  static const mutlulukEtkilesimsizDakika = 360;
  static const uyanincaMutlulukBonus = 5; // Uyanınca mutluluk bonusu
  static const _dakikaMs = 60 * 1000;
  // Maskot sistemi etkin. 1-5 seviyelerde etkileşim puanları otomatik gelişim sağlar.
  static const bool enabled = true;

  // Sosyal etkilesim odulu: 1-5 XP, 6+ vil.
  static Future<void> sosyalOdulKaydet(String uid, int miktar) async {
    await _sosyalOdulUygula(uid, miktar);
  }

  static Future<void> etkilesimPuaniniGelismeyeEkle(
    String uid,
    int puan,
  ) async {
    await _sosyalOdulUygula(uid, puan);
  }

  static Map<String, dynamic> sosyalOdulRobotUygula(
    Map<String, dynamic> userData,
    int miktar,
  ) {
    final robot = _robotHaritasi(userData['robot']);
    var seviye = _int(robot['seviye'], 1);

    if (seviye < toklukAcilisSeviyesi) {
      var gelisimPuani = _int(robot['gelisimPuani'], 0) + miktar;
      var gerekli = gerekliGelisimPuani(seviye);
      // Rules: tek yazımda en fazla +1 seviye. Çoklu atlama permission-denied yapar.
      if (gelisimPuani >= gerekli && seviye < toklukAcilisSeviyesi) {
        gelisimPuani -= gerekli;
        seviye += 1;
        robot['gelisimPuani'] = gelisimPuani;
        robot['seviye'] = seviye;
        _seviyeOdulleriniIsle(robot, seviye);
        _fazStatlariniHizala(robot, seviye);
      } else {
        robot['gelisimPuani'] = gelisimPuani;
        robot['seviye'] = seviye;
      }
    } else {
      robot['etkilesimPuani'] = _int(robot['etkilesimPuani'], 0) + miktar;
    }
    return robot;
  }

  static void sosyalOdulKullaniciAlaninaEkle({
    required Map<String, dynamic> guncelleme,
    required Map<String, dynamic>? userData,
    required int miktar,
  }) {
    if (!enabled || userData == null || miktar <= 0) return;
    guncelleme.addAll(sosyalOdulYazmaAlanlari(userData, miktar));
  }

  /// Gönderi/beğeni/yorum/takip ile aynı yazıma eklenir (ayrı vil yazımı düşmesin).
  static Map<String, dynamic> sosyalOdulYazmaAlanlari(
    Map<String, dynamic>? userData,
    int miktar,
  ) {
    if (!enabled || userData == null || miktar <= 0) return {};
    final hamRobot = userData['robot'];
    final onceki = _robotHaritasi(hamRobot);
    if (hamRobot is Map && _int(onceki['seviye'], 1) >= toklukAcilisSeviyesi) {
      return {'robot.etkilesimPuani': FieldValue.increment(miktar)};
    }
    final robot = sosyalOdulRobotUygula(userData, miktar);
    if (hamRobot is! Map) {
      return {'robot': robot};
    }
    return _robotNoktaliFark(onceki, robot);
  }

  static Future<void> _sosyalOdulUygula(String uid, int miktar) async {
    if (!enabled || uid.isEmpty || miktar <= 0) return;
    final ref = _db.collection('users').doc(uid);
    try {
      await _db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) return;
        final data = snap.data() ?? <String, dynamic>{};
        final hamRobot = data['robot'];
        final onceki = _robotHaritasi(hamRobot);
        final seviye = _int(onceki['seviye'], 1);
        if (hamRobot is Map && seviye >= toklukAcilisSeviyesi) {
          tx.update(ref, {
            'robot.etkilesimPuani': FieldValue.increment(miktar),
          });
          return;
        }
        final robot = sosyalOdulRobotUygula(data, miktar);
        if (hamRobot is! Map) {
          tx.update(ref, {'robot': robot});
          return;
        }
        final yaz = _robotNoktaliFark(onceki, robot);
        if (yaz.isEmpty) return;
        tx.update(ref, yaz);
      });
    } catch (e) {
      debugPrint('Maskot sosyal odul hatasi: $e');
    }
  }

  static bool _robotDegerAyni(dynamic a, dynamic b) {
    if (identical(a, b)) return true;
    if (a is num && b is num) return a == b;
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (!_robotDegerAyni(a[i], b[i])) return false;
      }
      return true;
    }
    return a == b;
  }

  /// Tam robot map yazmak web/mobilde fazla alanı "değişmiş" gösterip
  /// permission-denied üretebiliyor; yalnızca farkı noktalı yaz.
  static Map<String, dynamic> _robotNoktaliFark(
    Map<String, dynamic> onceki,
    Map<String, dynamic> sonraki,
  ) {
    const alanlar = [
      'gelisimPuani',
      'seviye',
      'etkilesimPuani',
      'kazanilanSeviyeOdulleri',
      'tokluk',
      'enerji',
      'mutluluk',
      'isim',
      'renk',
      'sonUygulamaMs',
      'sonEtkilesimMs',
      'sonMutlulukTickMs',
      'sonToklukPozitifMs',
      'sonEnerjiDususMs',
      'sonToklukTickMs',
      'sonAktiviteMs',
      'uykuBitisMs',
      'uykuBaslangicMs',
      'uykuBaslangicEnerji',
    ];
    final yaz = <String, dynamic>{};
    for (final alan in alanlar) {
      if (!_robotDegerAyni(sonraki[alan], onceki[alan])) {
        if (sonraki.containsKey(alan)) {
          yaz['robot.$alan'] = sonraki[alan];
        }
      }
    }
    return yaz;
  }

  static void _vilHarca(Map<String, dynamic> robot, int maliyet) {
    final mevcut = _int(robot['etkilesimPuani'], 0);
    if (mevcut < maliyet) {
      throw 'Yeterli vil yok.';
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
      _fazStatlariniHizala(robot, seviye, eskiSeviye: eskiSeviye);
      return _seviyeOdulleriniIsle(robot, seviye);
    }
    return [];
  }

  /// Yeni faza geciste eksik statlari mantikli varsayilanlara ceker.
  /// Düşük stat yalnızca o stat ilk açıldığı seviye atlamasında doldurulur;
  /// her senkronda doldurmak açlık/yalnızlık düşüşünü siler.
  static void _fazStatlariniHizala(
    Map<String, dynamic> robot,
    int seviye, {
    int? eskiSeviye,
  }) {
    bool yeniAcildi(int acilis) =>
        eskiSeviye != null && eskiSeviye < acilis && seviye >= acilis;

    if (toklukAktif(seviye) && !robot.containsKey('tokluk')) {
      // Saat eski sonUygulamaMs'ten başlarsa yeni çıkan Vibel anında 0 tokluk olur.
      final simdi = _simdiMs();
      robot['tokluk'] = 80;
      robot['sonToklukTickMs'] = simdi;
      robot['sonToklukPozitifMs'] = simdi;
    }
    if (enerjiAktif(seviye) &&
        (!robot.containsKey('enerji') ||
            (yeniAcildi(enerjiAcilisSeviyesi) &&
                _int(robot['enerji'], 0) < 30))) {
      robot['enerji'] = 70;
    }
    if (mutlulukAktif(seviye) &&
        (!robot.containsKey('mutluluk') ||
            (yeniAcildi(mutlulukAcilisSeviyesi) &&
                _int(robot['mutluluk'], 0) < 40))) {
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

  static bool gunlukGorevlerAcik(int seviye) =>
      seviye >= gorevAcilisSeviyesi;

  static bool yemekSistemiAcik(int seviye) => seviye >= toklukAcilisSeviyesi;

  static bool vilCuzdaniAcik(int seviye) => seviye >= toklukAcilisSeviyesi;

  static Future<bool> mevcutKullaniciVilCuzdaniAcik() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;
    try {
      final snap = await _db.collection('users').doc(uid).get();
      final mascot = tryParse(snap.data()?['robot']);
      return mascot != null && vilCuzdaniAcik(mascot.seviye);
    } catch (_) {
      return false;
    }
  }

  /// Türkiye saatine göre gün numarası; rules aynı formülle doğrular.
  static int reklamVilGunu([int? ms]) =>
      ((ms ?? _simdiMs()) + 3 * 60 * 60 * 1000) ~/ (24 * 60 * 60 * 1000);

  static int reklamVilKalan(Map<String, dynamic>? userData) {
    final kayit = userData?['reklamVil'];
    if (kayit is! Map || _int(kayit['gun'], -1) != reklamVilGunu()) {
      return reklamVilGunlukSinir;
    }
    return (reklamVilGunlukSinir - _int(kayit['adet'], 0))
        .clamp(0, reklamVilGunlukSinir)
        .toInt();
  }

  /// Ödüllü reklam sonrası vil. Günlük tavan rules'ta da zorunlu.
  static Future<void> reklamVilEkle(String uid) async {
    final ref = _db.collection('users').doc(uid);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data() ?? <String, dynamic>{};
      final mascot = tryParse(data['robot']);
      if (mascot == null || !vilCuzdaniAcik(mascot.seviye)) {
        throw 'Vil 6. seviyede açılır.';
      }
      if (reklamVilKalan(data) <= 0) {
        throw 'Bugünlük reklam ödülünün hepsini aldın. Yarın tekrar gel.';
      }
      final gun = reklamVilGunu();
      final kayit = data['reklamVil'];
      final oncekiAdet =
          kayit is Map && _int(kayit['gun'], -1) == gun ? _int(kayit['adet'], 0) : 0;
      tx.update(ref, {
        'robot.etkilesimPuani': FieldValue.increment(reklamVilOdulu),
        'reklamVil': {'gun': gun, 'adet': oncekiAdet + 1},
      });
    });
  }

  static bool gonderiSilVilGerekir(int seviye) => vilCuzdaniAcik(seviye);

  static bool gonderiSilVilYeterli(MascotDurum robot) {
    if (!gonderiSilVilGerekir(robot.seviye)) return true;
    return robot.vil >= gonderiSilVilMaliyeti;
  }

  static Map<String, dynamic> gonderiSilIcinVilHarca(
    Map<String, dynamic> robot,
  ) {
    final seviye = _int(robot['seviye'], 1);
    if (!gonderiSilVilGerekir(seviye)) return robot;
    _vilHarca(robot, gonderiSilVilMaliyeti);
    return robot;
  }

  static bool sosyalGeriAlVilGerekir(int seviye) => vilCuzdaniAcik(seviye);

  static bool sosyalGeriAlVilYeterli(MascotDurum? robot, int maliyet) {
    if (robot == null || !sosyalGeriAlVilGerekir(robot.seviye)) return true;
    return robot.vil >= maliyet;
  }

  static String sosyalGeriAlVilYetersizMesaji(String islem, int maliyet) =>
      '$islem için $maliyet vil gerekli.';

  static Future<void> sosyalGeriAlVilOnKontrol({
    required String uid,
    required int maliyet,
    required String yetersizMesaji,
  }) async {
    if (uid.isEmpty || maliyet <= 0) return;
    final snap = await _db.collection('users').doc(uid).get();
    if (!sosyalGeriAlVilYeterli(tryParse(snap.data()?['robot']), maliyet)) {
      throw yetersizMesaji;
    }
  }

  /// Seviye 6+ ise [guncelleme] içine vil düşüren `robot` yazar; yetersizse fırlatır.
  static void sosyalGeriAlVilEkle({
    required Map<String, dynamic> guncelleme,
    required dynamic robotHam,
    required int maliyet,
    required String yetersizMesaji,
    bool zorunlu = true,
  }) {
    final mascot = tryParse(robotHam);
    if (mascot == null || !sosyalGeriAlVilGerekir(mascot.seviye)) return;
    if (mascot.vil < maliyet) {
      if (zorunlu) throw yetersizMesaji;
      return;
    }
    final robot = Map<String, dynamic>.from(
      robotHam is Map
          ? Map<String, dynamic>.from(robotHam)
          : <String, dynamic>{},
    );
    _vilHarca(robot, maliyet);
    guncelleme['robot'] = robot;
  }

  static bool uyuSistemiAcik(int seviye) => seviye >= enerjiAcilisSeviyesi;

  static String fazBasligi(int seviye) {
    if (seviye < toklukAcilisSeviyesi) return 'Yumurta';
    if (seviye < enerjiAcilisSeviyesi) return 'Bebek';
    if (seviye < mutlulukAcilisSeviyesi) return 'Çocuk';
    return 'Yetişkin';
  }

  static int sonrakiFazSeviyesi(int seviye) {
    if (seviye < toklukAcilisSeviyesi) return toklukAcilisSeviyesi;
    if (seviye < enerjiAcilisSeviyesi) return enerjiAcilisSeviyesi;
    if (seviye < mutlulukAcilisSeviyesi) return mutlulukAcilisSeviyesi;
    return seviye;
  }

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const _odulSeviyeleri = [2, 3, 4, 5, 7, 10];

  static const _gelisimEsikleri = [
    50, 75, 100, 150, 200, // 1→6
    120, 150, 180, 200, 300, // 6→11
    450, 500, 550, 600, 700, 800, 900, 1000, 1200, // 11→20
  ];

  static int gerekliGelisimPuani(int seviye) {
    if (seviye < 1) return _gelisimEsikleri.first;
    if (seviye <= _gelisimEsikleri.length) {
      return _gelisimEsikleri[seviye - 1];
    }
    if (seviye < 30) return 1200;
    if (seviye < 40) return 1400;
    if (seviye < 50) return 1600;
    if (seviye < 60) return 1800;
    return 2000;
  }

  static int _int(dynamic value, int varsayilan) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value.trim());
      if (parsed != null) return parsed;
    }
    if (value is DateTime) return value.millisecondsSinceEpoch;
    if (value is Timestamp) return value.millisecondsSinceEpoch;
    return varsayilan;
  }

  /// Tokluk saati: yoksa "şimdi"ye sıfırlama (kapalı süre kaybolmasın).
  static int _toklukSaatiMs(Map<String, dynamic> robot, int simdiMs) {
    for (final alan in [
      'sonToklukTickMs',
      'sonUygulamaMs',
      'sonAktiviteMs',
      'sonToklukPozitifMs',
    ]) {
      final ms = _int(robot[alan], 0);
      if (ms > 0 && ms <= simdiMs) return ms;
    }
    return simdiMs;
  }

  static int _hesaplananTokluk(Map<String, dynamic> robot, int simdiMs) {
    final seviye = _int(robot['seviye'], 1);
    final kayitli = _clampStat(_int(robot['tokluk'], 80));
    if (!toklukAktif(seviye)) return kayitli;
    if (_int(robot['uykuBitisMs'], 0) > simdiMs) return kayitli;
    final tick = _toklukSaatiMs(robot, simdiMs);
    if (simdiMs <= tick) return kayitli;
    final dusus = _mutlulukDususMiktari(
      gecenMs: simdiMs - tick,
      tamBosalmaDakika: toklukUygulamaDisiDakika,
    );
    return _clampStat(kayitli - dusus);
  }

  static String _isimOku(dynamic value) {
    final isim = (value ?? '').toString().trim();
    if (isim.isEmpty || isim == 'Mini Vibe' || isim == 'Rety') {
      return varsayilanIsim;
    }
    return isim;
  }

  static int _clampStat(int value) => value.clamp(0, 100).toInt();

  static void _robotSayilariSabitle(Map<String, dynamic> robot) {
    const alanlar = [
      'seviye',
      'gelisimPuani',
      'etkilesimPuani',
      'tokluk',
      'enerji',
      'mutluluk',
      'uykuBitisMs',
      'uykuBaslangicMs',
      'uykuBaslangicEnerji',
      'sonToklukTickMs',
      'sonUygulamaMs',
      'sonAktiviteMs',
      'sonToklukPozitifMs',
      'sonEtkilesimMs',
      'sonMutlulukTickMs',
      'sonEnerjiDususMs',
    ];
    for (final alan in alanlar) {
      if (robot.containsKey(alan)) {
        robot[alan] = _int(robot[alan], 0);
      }
    }
    if (robot['isim'] != null) {
      robot['isim'] = robot['isim'].toString().trim();
    }
  }

  static int _simdiMs() => DateTime.now().millisecondsSinceEpoch;

  // Firestore verisini MascotDurum'a çevirir
  /// Firestore'dan gelen ham `robot` alanını okur; harita yoksa null.
  static MascotDurum? tryParse(dynamic raw) {
    if (raw is! Map) return null;
    return parse(raw);
  }

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
      isim: _isimOku(map['isim']),
      seviye: _int(map['seviye'], 1),
      gelisimPuani: _int(map['gelisimPuani'], 0),
      etkilesimPuani: _int(map['etkilesimPuani'], 0),
      tokluk: _hesaplananTokluk(map, simdi),
      enerji: _clampStat(_int(map['enerji'], 70)),
      mutluluk: _clampStat(_int(map['mutluluk'], 65)),
      sonBakim: sonBakim,
      kazanilanSeviyeOdulleri: oduller,
      uykuBitisMs: _int(map['uykuBitisMs'], 0),
      sonAktiviteMs: _int(map['sonAktiviteMs'], simdi),
      sonEnerjiDususMs: _int(map['sonEnerjiDususMs'], simdi),
      sonToklukPozitifMs: _int(map['sonToklukPozitifMs'], simdi),
      renk: RetyRenk.oku(map['renk']),
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
    if (!odaAcik(robot.seviye)) return 'Vibel odası 6. seviyede açılır.';
    if (uyuSistemiAcik(robot.seviye) &&
        robot.enerji <= uyuErkenUyandirmaMinEnerji) {
      return '${robot.isim} çok yorgun, biraz daha dinlenmeli.';
    }
    return null;
  }

  static Duration? uykuKalanSure(MascotDurum robot) {
    if (!uyuyorMu(robot)) return null;
    return Duration(milliseconds: robot.uykuBitisMs - _simdiMs());
  }

  /// Mevcut enerjiden %100'e ulasmak icin tahmini uyku suresi.
  static String uykuTahminiSureMetni(int enerji) => _uykuSureMetni(enerji);

  // Duruma göre animasyon durumu seçer
  static MascotGorselDurum gorselDurum(MascotDurum robot) {
    if (uyuyorMu(robot) && enerjiAktif(robot.seviye)) {
      return MascotGorselDurum.uyku;
    }
    if (enerjiAktif(robot.seviye) && robot.enerji <= 25) {
      return MascotGorselDurum.yorgun;
    }
    if (toklukAktif(robot.seviye) && robot.tokluk <= 25) {
      return MascotGorselDurum.yorgun;
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

  // 11+ yalnizca paylasim enerji harcar.
  static void _etkilesimEngeli(
    MascotDurum robot, {
    required String aksiyonTipi,
    required int enerjiMaliyeti,
  }) {
    if (!enerjiAktif(robot.seviye)) return;
    if (uyuyorMu(robot)) {
      throw '${robot.isim} uyuyor. Dinlenene kadar etkileşim yapılamaz.';
    }
    if (aksiyonTipi != 'gonderi') return;

    if (robot.enerji <= etkilesimEnerjiKilitEsigi) {
      throw '${robot.isim} çok yorgun. Uyutup enerji toplamalısın.';
    }
    if (robot.enerji < enerjiMaliyeti) {
      throw '${robot.isim} için paylaşım yapmak üzere yeterli enerji yok.';
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
      aksiyonTipi: aksiyonTipi,
      enerjiMaliyeti: etkilesimEnerjiMaliyeti(aksiyonTipi),
    );
  }

  // Maskot ruh hali mesajını döndürür
  static String ruhHaliMesaji(MascotDurum robot) {
    if (robot.seviye < toklukAcilisSeviyesi) {
      return MaskotBakimSozleri.donen(MaskotBakimSozleri.yumurtaKutuCumleleri);
    }
    if (odaAcik(robot.seviye) && robot.uyuyor) {
      return MaskotBakimSozleri.donen(
        MaskotBakimSozleri.uyuyorKutuCumleleri(robot.isim),
      );
    }
    // Açlık notu her zaman tokluk barına göre. Tokken aç cümlesi yok.
    if (toklukAktif(robot.seviye) &&
        robot.tokluk <= MaskotBakimSozleri.toklukEsik) {
      return MaskotBakimSozleri.toklukKutuNotu(robot.tokluk);
    }
    if (enerjiAktif(robot.seviye) &&
        robot.enerji <= MaskotBakimSozleri.enerjiEsik) {
      return MaskotBakimSozleri.donen(MaskotBakimSozleri.uykuKutuCumleleri);
    }
    if (mutlulukAktif(robot.seviye) && robot.mutluluk <= 30) {
      return 'Seni özledim. Birlikte takılalım mı?';
    }
    if (mutlulukAktif(robot.seviye) &&
        robot.mutluluk >= 80 &&
        robot.tokluk >= 60 &&
        robot.enerji >= 50) {
      return 'Harika hissediyorum!';
    }
    return MaskotBakimSozleri.toklukKutuNotu(robot.tokluk);
  }

  static bool senkronMesajBasariMi(String mesaj) {
    return mesaj.contains('uyandı');
  }

  static bool senkronMesajBilgiMi(String mesaj) {
    return mesaj.contains('uyuyor') ||
        mesaj == 'Maskotun seni çok özledi' ||
        mesaj.contains('dinleniyor');
  }

  /// Yeni bir özelliğin açıldığı ve kutlama gösterilen seviyeler.
  static const kutlamaSeviyeleri = [
    toklukAcilisSeviyesi,
    enerjiAcilisSeviyesi,
    mutlulukAcilisSeviyesi,
  ];

  static String? seviyeOdulAciklamasi(int seviye) {
    switch (seviye) {
      case toklukAcilisSeviyesi:
        return 'Kabuğumdan çıktım! Artık vil kazanıp bana yemek verebilirsin. '
            'Dikkat: uygulama kapalıyken de acıkırım. 3 gün aç kalırsam yumurtaya dönerim.';
      case enerjiAcilisSeviyesi:
        return 'Enerji ve uyku açıldı. Haftalık görevler de seni bekliyor!';
      case mutlulukAcilisSeviyesi:
        return 'Mutluluk açıldı. Birlikte vakit geçirdikçe daha mutlu olurum.';
      default:
        return null;
    }
  }

  static Map<String, dynamic> _robotHaritasi(dynamic raw) {
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    final simdi = _simdiMs();
    return {
      'isim': varsayilanIsim,
      'renk': RetyRenk.varsayilan.id,
      'seviye': 1,
      'gelisimPuani': 0,
      'etkilesimPuani': 0,
      'tokluk': 80,
      'enerji': 70,
      'mutluluk': 65,
      'sonUygulamaMs': simdi,
      'sonEtkilesimMs': simdi,
      'sonToklukPozitifMs': simdi,
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

  static int _uykuSuresiMs(int baslangicEnerji) {
    final baslangic = baslangicEnerji.clamp(0, 100);
    final eksik = 100 - baslangic;
    if (eksik <= 0) return 0;
    return (uyuSureMs * eksik) ~/ 100;
  }

  static String _uykuSureMetni(int baslangicEnerji) {
    final ms = _uykuSuresiMs(baslangicEnerji);
    if (ms <= 0) return 'hemen';
    final dakika = (ms / _dakikaMs).ceil();
    if (dakika >= 60) {
      final saat = dakika ~/ 60;
      final kalanDk = dakika % 60;
      if (kalanDk == 0) return '$saat saat';
      return '$saat sa $kalanDk dk';
    }
    return '$dakika dk';
  }

  static int _uykudaEnerjiHesapla({
    required int baslangicEnerji,
    required int uykuBaslangicMs,
    required int simdiMs,
  }) {
    if (simdiMs <= uykuBaslangicMs) {
      return _clampStat(baslangicEnerji);
    }
    final baslangic = baslangicEnerji.clamp(0, 100);
    final hedefArtis = 100 - baslangic;
    if (hedefArtis <= 0) return 100;

    final gerekliSureMs = _uykuSuresiMs(baslangic);
    if (gerekliSureMs <= 0) return 100;

    final gecenMs = simdiMs - uykuBaslangicMs;
    if (gecenMs >= gerekliSureMs) return 100;

    final artis = ((gecenMs / gerekliSureMs) * hedefArtis).round();
    final sinirliArtis = artis > hedefArtis ? hedefArtis : artis;
    return _clampStat(baslangic + sinirliArtis);
  }

  static void _etkilesimKaydet(Map<String, dynamic> robot, int simdiMs) {
    robot['sonEtkilesimMs'] = simdiMs;
    robot['sonMutlulukTickMs'] = simdiMs;
  }

  /// [aclikBaslangicMs]: tokluk bu senkron aralığında eşiğin altına indiyse
  /// indiği an.
  static ({int tokluk, int? aclikBaslangicMs}) _toklukDususUygula({
    required Map<String, dynamic> robot,
    required int simdiMs,
    required bool uygulamaAcildi,
  }) {
    var tokluk = _clampStat(_int(robot['tokluk'], 80));
    var tick = _toklukSaatiMs(robot, simdiMs);
    final uykuBitis = _int(robot['uykuBitisMs'], 0);
    final uykuBaslangic = _int(robot['uykuBaslangicMs'], 0);

    // Uyurken tokluk düşmez; uyanınca uyku süresi birikmiş borç olarak
    // tek seferde kesilmesin diye referans zaman uyku bitişine çekilir.
    if (uykuBitis > simdiMs) {
      return (tokluk: tokluk, aclikBaslangicMs: null);
    }
    if (uykuBaslangic > 0 && uykuBitis > 0 && simdiMs >= uykuBitis) {
      if (tick < uykuBitis) tick = uykuBitis;
    }

    int? aclikBaslangicMs;
    if (simdiMs > tick) {
      final oncekiTokluk = tokluk;
      final baslangicTick = tick;
      final dusus = _mutlulukDususMiktari(
        gecenMs: simdiMs - tick,
        tamBosalmaDakika: toklukUygulamaDisiDakika,
      );
      if (dusus > 0) {
        tokluk = _clampStat(tokluk - dusus);
        tick += _mutlulukDususTuketilenMs(
          dususMiktari: dusus,
          tamBosalmaDakika: toklukUygulamaDisiDakika,
        );
      }
      const esik = MaskotBakimSozleri.toklukEsik;
      if (oncekiTokluk > esik && tokluk <= esik) {
        aclikBaslangicMs = baslangicTick +
            _mutlulukDususTuketilenMs(
              dususMiktari: oncekiTokluk - esik,
              tamBosalmaDakika: toklukUygulamaDisiDakika,
            );
      }
    }

    robot['sonToklukTickMs'] = tick;
    robot['sonUygulamaMs'] = simdiMs;
    return (tokluk: tokluk, aclikBaslangicMs: aclikBaslangicMs);
  }

  /// Açken (tokluk düşük) enerji zamanla düşer.
  static int _aclikEnerjiDususUygula({
    required Map<String, dynamic> robot,
    required int simdiMs,
    required int enerji,
    required int tokluk,
    required int seviye,
    int? aclikBaslangicMs,
  }) {
    if (!enerjiAktif(seviye) ||
        tokluk > MaskotBakimSozleri.toklukEsik ||
        _int(robot['uykuBitisMs'], 0) > simdiMs) {
      robot['sonEnerjiDususMs'] = simdiMs;
      return enerji;
    }

    var tick = _int(robot['sonEnerjiDususMs'], simdiMs);
    if (aclikBaslangicMs != null && aclikBaslangicMs > tick) {
      tick = aclikBaslangicMs;
    }
    if (simdiMs <= tick) return enerji;

    final gecenMs = simdiMs - tick;
    final dusus = _mutlulukDususMiktari(
      gecenMs: gecenMs,
      tamBosalmaDakika: aclikEnerjiBosalmaDakika,
    );
    if (dusus > 0) {
      enerji = _clampStat(enerji - dusus);
      tick = tick +
          _mutlulukDususTuketilenMs(
            dususMiktari: dusus,
            tamBosalmaDakika: aclikEnerjiBosalmaDakika,
          );
    }
    robot['sonEnerjiDususMs'] = tick;
    return enerji;
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

    if (simdiMs > sonUygulama) {
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
    final simdi = _simdiMs();
    robot['uykuBitisMs'] = 0;
    robot['uykuBaslangicMs'] = 0;
    robot['uykuBaslangicEnerji'] = 0;
    robot['sonToklukTickMs'] = simdi;
    robot['sonEnerjiDususMs'] = simdi;
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
      mesajlar.add('${robot['isim'] ?? 'Vibel'} uyandı!');
      return mesajlar;
    }

    if (uygulamaAcildi) {
      mesajlar.add('${robot['isim'] ?? 'Vibel'} dinleniyor...');
    }
    return mesajlar;
  }

  static List<String> _zamanGuncelle(
    Map<String, dynamic> robot,
    int simdiMs, {
    bool uygulamaAcildi = false,
    bool etkilesimKaydedildi = false,
    bool aclikOlumuUygula = true,
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

    int? aclikBaslangicMs;
    if (toklukAktif(seviye)) {
      final toklukSonuc = _toklukDususUygula(
        robot: robot,
        simdiMs: simdiMs,
        uygulamaAcildi: uygulamaAcildi,
      );
      tokluk = toklukSonuc.tokluk;
      aclikBaslangicMs = toklukSonuc.aclikBaslangicMs;
      if (!robot.containsKey('sonToklukPozitifMs')) {
        robot['sonToklukPozitifMs'] = simdiMs;
      }
      if (tokluk > 0) {
        robot['sonToklukPozitifMs'] = simdiMs;
      } else {
        final sonPozitif = _int(robot['sonToklukPozitifMs'], simdiMs);
        if (aclikOlumuUygula &&
            simdiMs - sonPozitif >= aclikOlumSureMs) {
          final isim = (robot['isim'] ?? varsayilanIsim).toString();
          _acliktanYumurtayaDon(robot, simdiMs);
          mesajlar.add('$isim uzun süre aç kaldı ve yumurtaya döndü.');
          return mesajlar;
        }
      }
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
        mesajlar.add('${robot['isim'] ?? 'Vibel'} seni özledi');
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

    enerji = _aclikEnerjiDususUygula(
      robot: robot,
      simdiMs: simdiMs,
      enerji: enerji,
      tokluk: tokluk,
      seviye: seviye,
      aclikBaslangicMs: aclikBaslangicMs,
    );

    if (!enerjiAktif(seviye)) {
      robot['tokluk'] = tokluk;
      robot['mutluluk'] = mutluluk;
      robot['enerji'] = enerji;
      return mesajlar;
    }

    final uykuBitis = _int(robot['uykuBitisMs'], 0);
    var uykuBaslangic = _int(robot['uykuBaslangicMs'], 0);
    final baslangicEnerjiKayit = _int(robot['uykuBaslangicEnerji'], enerji);
    if (uykuBaslangic <= 0 && uykuBitis > 0) {
      uykuBaslangic = uykuBitis - _uykuSuresiMs(baslangicEnerjiKayit);
    }
    final halaUyuyor = uykuBitis > simdiMs;

    if (uygulamaAcildi && halaUyuyor) {
      mesajlar.add('${robot['isim'] ?? 'Vibel'} dinleniyor...');
    }

    if (uykuBitis > 0) {
      final baslangicEnerji = baslangicEnerjiKayit;
      enerji = _uykudaEnerjiHesapla(
        baslangicEnerji: baslangicEnerji,
        uykuBaslangicMs: uykuBaslangic,
        simdiMs: simdiMs,
      );
      if (enerji >= 100) {
        robot['enerji'] = 100;
        _robotUyandir(robot);
        mutluluk = _int(robot['mutluluk'], mutluluk);
        _gelisimVeSeviyeUygula(robot, uykuGelisimPuani);
        mesajlar.add('${robot['isim'] ?? 'Vibel'} enerjisi doldu, uyandı!');
      } else if (simdiMs >= uykuBitis) {
        robot['enerji'] = enerji;
        _robotUyandir(robot);
        mutluluk = _int(robot['mutluluk'], mutluluk);
        _gelisimVeSeviyeUygula(robot, uykuGelisimPuani);
        mesajlar.add('${robot['isim'] ?? 'Vibel'} uyandı!');
      } else {
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

  static void _acliktanYumurtayaDon(Map<String, dynamic> robot, int simdiMs) {
    final isim = _isimOku(robot['isim']);
    final vil = _int(robot['etkilesimPuani'], 0);
    robot
      ..['isim'] = isim
      ..['seviye'] = 1
      ..['gelisimPuani'] = 0
      ..['etkilesimPuani'] = vil
      ..['tokluk'] = 80
      ..['enerji'] = 70
      ..['mutluluk'] = 65
      ..['uykuBitisMs'] = 0
      ..['uykuBaslangicMs'] = 0
      ..['uykuBaslangicEnerji'] = 0
      ..['kazanilanSeviyeOdulleri'] = <int>[]
      ..['sonToklukPozitifMs'] = simdiMs
      ..['sonUygulamaMs'] = simdiMs
      ..['sonEtkilesimMs'] = simdiMs
      ..['sonToklukTickMs'] = simdiMs
      ..['sonMutlulukTickMs'] = simdiMs
      ..['sonEnerjiDususMs'] = simdiMs
      ..['sonAktiviteMs'] = simdiMs;
  }

  static void _uykuEngeli(Map<String, dynamic> robot) {
    if (_int(robot['uykuBitisMs'], 0) > _simdiMs()) {
      throw '${robot['isim'] ?? 'Vibel'} uyuyor. Uyanana kadar bu işlem kapalı.';
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
        final hamRobot = snap.data()?['robot'];
        final robot = _robotHaritasi(hamRobot);
        final seviye = _int(robot['seviye'], 1);
        _fazStatlariniHizala(robot, seviye);
        if (hamRobot is! Map) {
          tx.update(ref, {'robot': robot});
          return MascotSenkronSonuc(robot: parse(robot), mesajlar: const []);
        }
        if (!odaAcik(seviye)) {
          return MascotSenkronSonuc(robot: parse(robot), mesajlar: const []);
        }
        final onceki = Map<String, dynamic>.from(robot);
        final mesajlar =
            _zamanGuncelle(robot, _simdiMs(), uygulamaAcildi: true);
        final yaz = _robotNoktaliFark(onceki, robot);
        if (yaz.isNotEmpty) {
          tx.update(ref, yaz);
        }
        _bakimBildirimleriniYenile(robot);
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

  static void _bakimBildirimleriniYenile(Map<String, dynamic> robot) {
    unawaited(MaskotBildirimServis.planlaHaritadan(robot));
  }

  static bool _robotOynanisAyni(
    Map<String, dynamic> a,
    Map<String, dynamic> b,
  ) {
    const alanlar = [
      'enerji',
      'mutluluk',
      'tokluk',
      'seviye',
      'gelisimPuani',
      'etkilesimPuani',
      'uykuBitisMs',
      'uykuBaslangicMs',
      'uykuBaslangicEnerji',
      'isim',
    ];
    for (final alan in alanlar) {
      if (a[alan] != b[alan]) return false;
    }
    return true;
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
        final onceki = Map<String, dynamic>.from(robot);
        _zamanGuncelle(robot, _simdiMs());
        if (_robotOynanisAyni(onceki, robot)) return;
        final yaz = _robotNoktaliFark(onceki, robot);
        if (yaz.isEmpty) return;
        tx.update(ref, yaz);
        _bakimBildirimleriniYenile(robot);
      });
    } catch (e) {
      debugPrint('Maskot dakika senkron hatası: $e');
    }
  }

  // Maskot ismini günceller
  static Future<String> isimGuncelle(String uid, String yeniIsim) async {
    final temiz = yeniIsim.trim();
    if (temiz.isEmpty || temiz.length > 24) {
      throw 'Vibel ismi 1-24 karakter olmalı.';
    }
    if (!enabled) {
      // Maskot devre dışı — DB güncellemesi yapılmaz, fakat çağırana başarılı dönüş verilir.
      return temiz;
    }
    await _db.collection('users').doc(uid).update({'robot.isim': temiz});
    return temiz;
  }

  /// Vibel görünüm rengini kaydeder.
  static Future<void> renkGuncelle(RetyRenk renk) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw 'Oturum bulunamadı.';
    if (!enabled) return;
    try {
      // Noktalı alan: tüm robot haritasını yeniden yazmadan sadece renk.
      await _db.collection('users').doc(uid).update({
        'robot.renk': renk.id,
      });
    } catch (e, st) {
      debugPrint('renkGuncelle hata: $e\n$st');
      rethrow;
    }
  }

  // Uyuyan maskotu erken uyandırır
  static Future<String> uyandir(String uid) async {
    if (!enabled) return 'Vibel sistemi şu an kapalı.';
    final ref = _db.collection('users').doc(uid);
    return _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final robot = _robotHaritasi(snap.data()?['robot']);
      final seviye = _int(robot['seviye'], 1);
      if (!odaAcik(seviye)) {
        throw 'Vibel odası 6. seviyede açılır.';
      }
      final simdi = _simdiMs();
      _zamanGuncelle(robot, simdi, etkilesimKaydedildi: true);

      if (_int(robot['uykuBitisMs'], 0) <= simdi) {
        throw '${robot['isim'] ?? 'Vibel'} zaten uyanık.';
      }

      if (uyuSistemiAcik(seviye)) {
        final enerji = _int(robot['enerji'], 50);
        if (enerji <= uyuErkenUyandirmaMinEnerji) {
          throw '${robot['isim'] ?? 'Vibel'} çok yorgun, biraz daha dinlenmeli.';
        }
      }

      _robotUyandir(robot);
      tx.update(ref, {'robot': robot});
      _bakimBildirimleriniYenile(robot);
      return '${robot['isim'] ?? 'Vibel'} uyandı!';
    });
  }

  // Maskotu uyutmaya başlatır
  static Future<String> uyuYap(String uid) async {
    if (!enabled) return 'Vibel sistemi şu an kapalı.';
    final ref = _db.collection('users').doc(uid);
    return _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final robot = _robotHaritasi(snap.data()?['robot']);
      if (!uyuSistemiAcik(_int(robot['seviye'], 1))) {
        throw 'Uyku $enerjiAcilisSeviyesi. seviyede açılır.';
      }
      final simdi = _simdiMs();
      _zamanGuncelle(robot, simdi, etkilesimKaydedildi: true);

      final enerji = _int(robot['enerji'], 70);
      if (enerji > uyuMaxEnerji) {
        throw '${robot['isim'] ?? 'Vibel'} henüz uykulu değil. Yorulunca uyutabilirsin.';
      }
      if (_int(robot['uykuBitisMs'], 0) > simdi) {
        throw '${robot['isim'] ?? 'Vibel'} zaten uyuyor.';
      }

      robot['uykuBaslangicEnerji'] = enerji;
      robot['uykuBaslangicMs'] = simdi;
      final uykuMs = _uykuSuresiMs(enerji);
      robot['uykuBitisMs'] = simdi + uykuMs;

      tx.update(ref, {'robot': robot});
      _bakimBildirimleriniYenile(robot);
      return '${robot['isim'] ?? 'Vibel'} uyumaya başladı. Enerjisi dolunca uyanacak.';
    });
  }

  // Sosyal aksiyon: 11+ paylasim enerji dusurur; 21+ mutluluk artirir.
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
        final onceki = Map<String, dynamic>.from(robot);
        final simdi = _simdiMs();
        _zamanGuncelle(robot, simdi, etkilesimKaydedildi: true);
        if (_int(robot['uykuBitisMs'], 0) > simdi) return;

        final seviye = _int(robot['seviye'], 1);

        if (enerjiAktif(seviye) && tip == 'gonderi') {
          final maliyet = etkilesimEnerjiMaliyeti(tip);
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

        final yaz = _robotNoktaliFark(onceki, robot);
        if (yaz.isEmpty) return;
        tx.update(ref, yaz);
      });
    } catch (e) {
      debugPrint('Maskot sosyal aksiyon hatası ($tip): $e');
    }
  }

  /// Ekrandaki robot haritasına yemeği uygular. Ağ beklemez.
  static ({String mesaj, Map<String, dynamic> robot, Map<String, dynamic> yaz})
      yemekHesapla(dynamic ham) {
    final robot = _robotHaritasi(ham);
    final seviye = _int(robot['seviye'], 1);
    if (!yemekSistemiAcik(seviye)) {
      throw '$odaAcilisSeviyesi. seviye olana kadar yemek verilemez.';
    }

    final simdi = _simdiMs();
    _uykuEngeli(robot);

    final oncekiTokluk = _hesaplananTokluk(robot, simdi);
    if (oncekiTokluk >= 100) {
      throw 'Tokluk zaten dolu. Biraz bekleyip tekrar dene.';
    }

    _vilHarca(robot, yemekVilMaliyeti);

    _gelisimVeSeviyeUygula(robot, yemekGelisimPuani);
    final yeniSeviye = _int(robot['seviye'], 1);
    final seviyeAtladi = yeniSeviye > seviye;

    final yeniTokluk = _clampStat(oncekiTokluk + yemekToklukArtisi);
    robot['tokluk'] = yeniTokluk;
    robot['sonToklukTickMs'] = simdi;
    robot['sonUygulamaMs'] = simdi;
    if (yeniTokluk > 0) {
      robot['sonToklukPozitifMs'] = simdi;
    }
    if (enerjiAktif(seviye)) {
      robot['enerji'] = _clampStat(
        _int(robot['enerji'], 70) + yemekEnerjiArtisi,
      );
    }
    robot['mutluluk'] = _clampStat(_int(robot['mutluluk'], 65) + 5);
    _robotSayilariSabitle(robot);

    final yaz = <String, dynamic>{
      'robot.etkilesimPuani': _int(robot['etkilesimPuani'], 0),
      'robot.tokluk': yeniTokluk,
      'robot.sonToklukTickMs': simdi,
      'robot.sonUygulamaMs': simdi,
      'robot.sonToklukPozitifMs': simdi,
      'robot.gelisimPuani': _int(robot['gelisimPuani'], 0),
      'robot.mutluluk': _int(robot['mutluluk'], 65),
    };
    if (enerjiAktif(seviye)) {
      yaz['robot.enerji'] = _int(robot['enerji'], 70);
    }
    if (seviyeAtladi) {
      yaz['robot.seviye'] = yeniSeviye;
    }

    final mesaj = seviyeAtladi ? 'Lezzetli! Seviye atlandı!' : 'Lezzetli!';
    return (mesaj: mesaj, robot: robot, yaz: yaz);
  }

  // Bebek beslenmesiyle gelişim puanı artırır
  static Future<String> yemekVer(
    String uid, {
    Map<String, dynamic>? anlikRobot,
  }) async {
    if (!enabled) return 'Vibel sistemi şu an kapalı.';
    if (uid.isEmpty) return 'Kullanıcı bulunamadı.';

    final ref = _db.collection('users').doc(uid);
    try {
      Map<String, dynamic> ham = anlikRobot ?? {};
      if (anlikRobot == null) {
        final snap = await ref.get();
        if (!snap.exists) throw 'Kullanıcı kaydı bulunamadı.';
        final veri = snap.data()?['robot'];
        if (veri is Map) ham = Map<String, dynamic>.from(veri);
      }
      final sonuc = yemekHesapla(ham);
      await ref.update(sonuc.yaz);
      _bakimBildirimleriniYenile(sonuc.robot);
      return sonuc.mesaj;
    } on FirebaseException catch (e) {
      debugPrint('Yemek FirebaseException code=${e.code} message=${e.message}');
      throw 'Yemek kaydı reddedildi (${e.code}).';
    } catch (e) {
      debugPrint('Yemek beklenmeyen hata: $e');
      rethrow;
    }
  }

  static String _utcGunAnahtari(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  static int utcGeceYarisiKalanMs([int? simdiMs]) {
    final simdi = simdiMs ?? _simdiMs();
    final d = DateTime.fromMillisecondsSinceEpoch(simdi, isUtc: true);
    final next = DateTime.utc(d.year, d.month, d.day + 1);
    return next.millisecondsSinceEpoch - simdi;
  }

  static int arkadasYemekKalanMs({
    required Map<String, dynamic> feederRobot,
    required String hedefUid,
  }) {
    if (hedefUid.isEmpty) return 0;
    final kayit = feederRobot['sonArkadasYemek'];
    if (kayit is! Map || kayit[hedefUid] == null) return 0;
    final sonMs = _int(kayit[hedefUid], 0);
    if (sonMs <= 0) return 0;
    final simdi = _simdiMs();
    if (_utcGunAnahtari(sonMs) != _utcGunAnahtari(simdi)) return 0;
    return utcGeceYarisiKalanMs(simdi);
  }

  static String arkadasYemekBeklemeMetni(int kalanMs) {
    if (kalanMs <= 0) return '';
    final tekrar = DateTime.now().add(Duration(milliseconds: kalanMs));
    final hh = tekrar.hour.toString().padLeft(2, '0');
    final mm = tekrar.minute.toString().padLeft(2, '0');
    return 'Bugün verdin. Tekrar $hh:$mm\'te.';
  }

  static Future<bool> karsilikliTakipVarMi({
    required String uid1,
    required String uid2,
  }) async {
    if (uid1.isEmpty || uid2.isEmpty || uid1 == uid2) return false;
    final a = await _db
        .collection('users')
        .doc(uid1)
        .collection('following')
        .doc(uid2)
        .get();
    if (!a.exists) return false;
    final b = await _db
        .collection('users')
        .doc(uid2)
        .collection('following')
        .doc(uid1)
        .get();
    return b.exists;
  }

  static Future<bool> _karsilikliTakipVarMi({
    required String uid1,
    required String uid2,
  }) =>
      karsilikliTakipVarMi(uid1: uid1, uid2: uid2);

  /// Karşılıklı takipteki arkadaş, vil harcayarak hedef maskotu doyurur.
  static Future<String> arkadasYemekVer(String hedefUid) async {
    if (!enabled) return 'Vibel sistemi şu an kapalı.';
    final current = FirebaseAuth.instance.currentUser;
    if (current == null) throw 'Oturum bulunamadı.';
    if (hedefUid.isEmpty || hedefUid == current.uid) {
      throw 'Bu Vibel\'e yemek veremezsin.';
    }

    final karsilikli = await _karsilikliTakipVarMi(
      uid1: current.uid,
      uid2: hedefUid,
    );
    if (!karsilikli) {
      throw 'Yalnızca karşılıklı takipte yemek verebilirsin.';
    }

    final feederRef = _db.collection('users').doc(current.uid);
    final hedefRef = _db.collection('users').doc(hedefUid);
    final bagARef = feederRef.collection('retyBaglari').doc(hedefUid);
    final bagBRef = hedefRef.collection('retyBaglari').doc(current.uid);

    Map<String, dynamic> hedefRobot = {};
    final simdi = await _db.runTransaction<int>((txn) async {
      final feederSnap = await txn.get(feederRef);
      final hedefSnap = await txn.get(hedefRef);
      if (!feederSnap.exists || !hedefSnap.exists) {
        throw 'Kullanıcı kaydı bulunamadı.';
      }

      final feederRobot = _robotHaritasi(feederSnap.data()?['robot']);
      hedefRobot = _robotHaritasi(hedefSnap.data()?['robot']);
      final hedefSeviye = _int(hedefRobot['seviye'], 1);
      if (!yemekSistemiAcik(hedefSeviye)) {
        throw 'Bu Vibel henüz yumurta; yemek 6. seviyede açılır.';
      }

      final simdiMs = _simdiMs();
      if (_int(hedefRobot['uykuBitisMs'], 0) > simdiMs) {
        final isim = _isimOku(hedefRobot['isim']);
        throw '$isim uyuyor. Uyanınca yemek verebilirsin.';
      }

      final oncekiTokluk = _int(hedefRobot['tokluk'], 80);
      if (oncekiTokluk <= 0) {
        final sonPozitif = _int(hedefRobot['sonToklukPozitifMs'], simdiMs);
        if (simdiMs - sonPozitif >= aclikOlumSureMs) {
          throw 'Bu Vibel açlıktan yumurtaya döndü. Artık yemek verilemez.';
        }
      }
      if (oncekiTokluk >= 100) {
        throw 'Tokluk zaten dolu.';
      }

      final yemekKaydi = feederRobot['sonArkadasYemek'];
      if (yemekKaydi is Map && yemekKaydi[hedefUid] != null) {
        final sonMs = _int(yemekKaydi[hedefUid], 0);
        if (sonMs > 0 &&
            _utcGunAnahtari(sonMs) == _utcGunAnahtari(simdiMs)) {
          throw MascotServis.arkadasYemekBeklemeMetni(
            utcGeceYarisiKalanMs(simdiMs),
          );
        }
      }

      _vilHarca(feederRobot, arkadasYemekVilMaliyeti);

      final kayit = yemekKaydi is Map
          ? Map<String, dynamic>.from(yemekKaydi)
          : <String, dynamic>{};
      kayit[hedefUid] = simdiMs;
      feederRobot['sonArkadasYemek'] = kayit;

      final hedefYaz = Map<String, dynamic>.from(hedefRobot);
      hedefYaz['tokluk'] = _clampStat(oncekiTokluk + yemekToklukArtisi);
      hedefYaz['mutluluk'] = _clampStat(_int(hedefRobot['mutluluk'], 65) + 3);
      hedefYaz['sonToklukPozitifMs'] = simdiMs;
      hedefYaz['sonToklukTickMs'] = simdiMs;

      txn.update(feederRef, {'robot': feederRobot});
      txn.update(hedefRef, {'robot': hedefYaz});
      return simdiMs;
    });

    try {
      await Future.wait([
        bagARef.set({'benimMs': simdi}, SetOptions(merge: true)),
        bagBRef.set({'onunMs': simdi}, SetOptions(merge: true)),
      ]);
      unawaited(bagTakibiYenilendi(hedefUid));
    } catch (e) {
      debugPrint('Rety bagi yazilamadi: $e');
    }

    final isim = _isimOku(hedefRobot['isim']);
    return '$isim doydu.';
  }

  static DocumentReference<Map<String, dynamic>> _bagRef(
    String uid,
    String otherUid,
  ) =>
      _db.collection('users').doc(uid).collection('retyBaglari').doc(otherUid);

  static final Set<String> _bagSilmeAnahtarlari = {};

  static String _bagAnahtar(String a, String b) {
    final ilk = a.compareTo(b) <= 0 ? a : b;
    final son = a.compareTo(b) <= 0 ? b : a;
    return '$ilk|$son';
  }

  /// Takipten çıkınca 3 günlük silme süresini başlatır (süre zaten varsa dokunmaz).
  static Future<void> bagTakibiKesildi(String otherUid) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty || otherUid.isEmpty || uid == otherUid) {
      return;
    }
    try {
      final benim = await _bagRef(uid, otherUid).get();
      if (!benim.exists) return;
      final kayit = RetyBagKaydi.fromMap(otherUid, benim.data());
      if (!kayit.bagVar || kayit.takipKesildiMs > 0) return;

      final simdi = DateTime.now().millisecondsSinceEpoch;
      await Future.wait([
        _bagRef(uid, otherUid).update({'takipKesildiMs': simdi}),
        _bagRef(otherUid, uid).update({'takipKesildiMs': simdi}),
      ]);
    } catch (e) {
      debugPrint('Rety bagi takip kesme yazilamadi: $e');
    }
  }

  /// Karşılıklı takip geri gelince silme süresini iptal eder.
  static Future<void> bagTakibiYenilendi(String otherUid) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty || otherUid.isEmpty || uid == otherUid) {
      return;
    }
    try {
      final karsilikli = await karsilikliTakipVarMi(uid1: uid, uid2: otherUid);
      if (!karsilikli) return;

      final benim = await _bagRef(uid, otherUid).get();
      if (!benim.exists) return;
      final kayit = RetyBagKaydi.fromMap(otherUid, benim.data());
      if (kayit.takipKesildiMs <= 0) return;
      if (kayit.takipKesilmeSuresiDoldu) {
        await _suresiDolanBagiSil(uid, otherUid);
        return;
      }

      await Future.wait([
        _bagRef(uid, otherUid).update({
          'takipKesildiMs': FieldValue.delete(),
        }),
        _bagRef(otherUid, uid).update({
          'takipKesildiMs': FieldValue.delete(),
        }),
      ]);
    } catch (e) {
      debugPrint('Rety bagi takip yenileme yazilamadi: $e');
    }
  }

  static Future<void> _suresiDolanBagiSil(String uid, String otherUid) async {
    final anahtar = _bagAnahtar(uid, otherUid);
    if (_bagSilmeAnahtarlari.contains(anahtar)) return;
    _bagSilmeAnahtarlari.add(anahtar);
    try {
      await Future.wait([
        _bagRef(uid, otherUid).delete(),
        _bagRef(otherUid, uid).delete(),
      ]);
    } catch (e) {
      _bagSilmeAnahtarlari.remove(anahtar);
      debugPrint('Rety bagi silinemedi: $e');
    }
  }

  static void _suresiDolanBagiTemizle(String uid, RetyBagKaydi kayit) {
    if (!kayit.takipKesilmeSuresiDoldu) return;
    unawaited(_suresiDolanBagiSil(uid, kayit.otherUid));
  }

  /// Karşı profildeki rozet: yalnızca oturum sahibinin kendi alt koleksiyonu.
  static Stream<RetyBagKaydi?> bagStream(String otherUid) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty || uid == otherUid) {
      return Stream<RetyBagKaydi?>.value(null);
    }
    return _bagRef(uid, otherUid).snapshots().map((doc) {
      if (!doc.exists) return RetyBagKaydi.fromMap(otherUid, null);
      final kayit = RetyBagKaydi.fromMap(otherUid, doc.data());
      _suresiDolanBagiTemizle(uid, kayit);
      if (kayit.takipKesilmeSuresiDoldu) {
        return RetyBagKaydi.fromMap(otherUid, null);
      }
      return kayit;
    });
  }

  /// Kendi profildeki özel bağ listesi.
  static Stream<List<RetyBagKaydi>> benimBaglarStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      return Stream<List<RetyBagKaydi>>.value(const []);
    }
    return _db
        .collection('users')
        .doc(uid)
        .collection('retyBaglari')
        .snapshots()
        .map((snap) {
      final liste = <RetyBagKaydi>[];
      for (final d in snap.docs) {
        final kayit = RetyBagKaydi.fromMap(d.id, d.data());
        if (!kayit.bagVar) continue;
        if (kayit.takipKesilmeSuresiDoldu) {
          _suresiDolanBagiTemizle(uid, kayit);
          continue;
        }
        liste.add(kayit);
      }
      liste.sort((a, b) => b.sonMs.compareTo(a.sonMs));
      return liste;
    });
  }
}
