// Haftalık günlük görev sistemi ve Firestore kaydı.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:vibe_life/maskot_servis.dart';

// Görev ilerlemesinde sayılan aksiyon türleri
enum GorevAksiyon { acilis, begeni, takip, yorum, gonderi }

// Tek günlük görev tanımı
class GorevSatiri {
  const GorevSatiri({
    required this.id,
    required this.baslik,
    required this.hedef,
    required this.odul,
    required this.aksiyon,
  });

  final String id;
  final String baslik;
  final int hedef;
  final int odul;
  final GorevAksiyon aksiyon;
}

// Kullanıcının güncel haftalık görev durumu
class HaftalikGorevDurum {
  const HaftalikGorevDurum({
    required this.hafta,
    required this.puan,
    required this.gunTarih,
    required this.sayac,
    required this.tamamlanan,
    required this.gunBonusuAlindi,
    required this.gorevler,
  });

  final String hafta;
  final int puan;
  final String gunTarih;
  final Map<GorevAksiyon, int> sayac;
  final Set<String> tamamlanan;
  final bool gunBonusuAlindi;
  final List<GorevSatiri> gorevler;

  // Görev tamamlanmış mı kontrol eder
  bool gorevTamamMi(GorevSatiri gorev) {
    return tamamlanan.contains(gorev.id) ||
        (sayac[gorev.aksiyon] ?? 0) >= gorev.hedef;
  }

  // Bugün kazanılan toplam görev puanı
  int get bugunkuKazanilanPuan {
    var toplam = 0;
    for (final gorev in gorevler) {
      if (gorevTamamMi(gorev)) {
        toplam += gorev.odul;
      }
    }
    if (gunBonusuAlindi) {
      toplam += HaftalikGorevServis.gunBonusu;
    }
    return toplam;
  }

  // Bugün kazanılabilecek maksimum puan
  int get bugunkuMaksPuan {
    var toplam = gorevler.fold<int>(0, (toplam, gorev) => toplam + gorev.odul);
    return toplam + HaftalikGorevServis.gunBonusu;
  }

  // Tüm günlük görevler tamamlandı mı
  bool get gunTamamlandi => gorevler.isNotEmpty && gorevler.every(gorevTamamMi);
}

// Görev kayıt işleminin sonucu
class HaftalikGorevSonuc {
  const HaftalikGorevSonuc({
    this.durum,
    this.mesajlar = const [],
    this.hata,
  });

  final HaftalikGorevDurum? durum;
  final List<String> mesajlar;
  final String? hata;

  bool get basarili => hata == null && durum != null;
}

// Haftalık görev mantığı ve Firestore işlemleri
class HaftalikGorevServis {
  HaftalikGorevServis._();

  static const gunBonusu = 100; // Gün tamamlama bonusu
  static const maksHaftalikPuan = 1320; // Haftalık puan üst sınırı

  static String get gorevlerAcilmaHatasi =>
      'Görevler ${MascotServis.mutlulukAcilisSeviyesi}. seviyede açılır.';

  static const _gunAdlari = [
    'Pazartesi',
    'Salı',
    'Çarşamba',
    'Perşembe',
    'Cuma',
    'Cumartesi',
    'Pazar',
  ];

  static const _begeniHedefleri = [3, 6, 9, 12, 15, 18, 21];
  static const _takipHedefleri = [1, 2, 3, 4, 3, 2, 1];
  static const _yorumHedefleri = [2, 4, 6, 8, 10, 12, 14];
  static const _gonderiHedefleri = [1, 2, 3, 4, 3, 2, 1];

  static const _gunlukGorevOdulleri = [
    [10, 10, 10, 15, 15],
    [10, 15, 15, 15, 15],
    [10, 15, 15, 20, 20],
    [10, 15, 20, 20, 25],
    [10, 20, 20, 20, 25],
    [10, 20, 20, 25, 30],
    [10, 25, 25, 25, 40],
  ];

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Türkiye saatine göre şimdiki zaman
  static DateTime turkiyeSimdi() {
    return DateTime.now().toUtc().add(const Duration(hours: 3));
  }

  // Verilen günün hafta pazartesisini bulur
  static DateTime haftaninPazartesisi(DateTime tarih) {
    return DateTime(tarih.year, tarih.month, tarih.day)
        .subtract(Duration(days: tarih.weekday - DateTime.monday));
  }

  // Hafta kimliği (YYYY-MM-DD pazartesi)
  static String haftaKimligi([DateTime? tarih]) {
    final pazartesi = haftaninPazartesisi(tarih ?? turkiyeSimdi());
    return _tarihKimligi(pazartesi);
  }

  // Gün kimliği (YYYY-MM-DD)
  static String gunKimligi([DateTime? tarih]) {
    return _tarihKimligi(tarih ?? turkiyeSimdi());
  }

  // Haftanın gün adını döndürür
  static String bugununAdi([DateTime? tarih]) {
    final gun = (tarih ?? turkiyeSimdi()).weekday - DateTime.monday;
    return _gunAdlari[gun.clamp(0, _gunAdlari.length - 1)];
  }

  static String _tarihKimligi(DateTime tarih) {
    final ay = tarih.month.toString().padLeft(2, '0');
    final gun = tarih.day.toString().padLeft(2, '0');
    return '${tarih.year}-$ay-$gun';
  }

  static int _int(dynamic value, [int varsayilan = 0]) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return varsayilan;
  }

  // Haftanın gününe göre görev listesi oluşturur
  static List<GorevSatiri> gorevlerForWeekday(int weekday) {
    final index = (weekday - DateTime.monday).clamp(0, 6);
    final oduller = _gunlukGorevOdulleri[index];
    return [
      GorevSatiri(
        id: 'acilis',
        baslik: 'Uygulamaya gir',
        hedef: 1,
        odul: oduller[0],
        aksiyon: GorevAksiyon.acilis,
      ),
      GorevSatiri(
        id: 'begeni',
        baslik: 'Gönderi beğen',
        hedef: _begeniHedefleri[index],
        odul: oduller[1],
        aksiyon: GorevAksiyon.begeni,
      ),
      GorevSatiri(
        id: 'takip',
        baslik: 'Kişi takip et',
        hedef: _takipHedefleri[index],
        odul: oduller[2],
        aksiyon: GorevAksiyon.takip,
      ),
      GorevSatiri(
        id: 'yorum',
        baslik: 'Yorum yap',
        hedef: _yorumHedefleri[index],
        odul: oduller[3],
        aksiyon: GorevAksiyon.yorum,
      ),
      GorevSatiri(
        id: 'gonderi',
        baslik: 'Gönderi paylaş',
        hedef: _gonderiHedefleri[index],
        odul: oduller[4],
        aksiyon: GorevAksiyon.gonderi,
      ),
    ];
  }

  // Hafta/gün değiştiyse görev haritasını senkronize eder
  static Map<String, dynamic> senkronHaftalikGorevMap(dynamic raw) {
    final simdi = turkiyeSimdi();
    final buHafta = haftaKimligi(simdi);
    final bugun = gunKimligi(simdi);

    Map<String, dynamic> gorevMap;
    if (raw is Map) {
      gorevMap = Map<String, dynamic>.from(raw);
    } else {
      return _bosHaftalikGorev(hafta: buHafta, gunTarih: bugun);
    }

    if ((gorevMap['hafta'] ?? '').toString() != buHafta) {
      return _bosHaftalikGorev(hafta: buHafta, gunTarih: bugun);
    }
    if ((gorevMap['gunTarih'] ?? '').toString() != bugun) {
      return _gunSifirla(gorevMap, gunTarih: bugun);
    }
    return gorevMap;
  }

  // Kullanıcı verisinden görev durumu üretir
  static HaftalikGorevDurum kullaniciVerisindenDurum(
      Map<String, dynamic>? data) {
    final simdi = turkiyeSimdi();
    return parse(
      raw: senkronHaftalikGorevMap(data?['haftalikGorev']),
      weekday: simdi.weekday,
    );
  }

  // Ham Firestore map'ini HaftalikGorevDurum'a çevirir
  static HaftalikGorevDurum parse({
    required dynamic raw,
    required int weekday,
  }) {
    final map =
        raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    final sayacRaw = map['sayac'];
    final sayacMap = sayacRaw is Map
        ? Map<String, dynamic>.from(sayacRaw)
        : <String, dynamic>{};
    final tamamlananRaw = map['tamamlanan'];
    final tamamlanan = tamamlananRaw is List
        ? tamamlananRaw.map((e) => e.toString()).toSet()
        : <String>{};

    final sayac = <GorevAksiyon, int>{};
    for (final aksiyon in GorevAksiyon.values) {
      sayac[aksiyon] = _int(sayacMap[aksiyon.name]);
    }

    return HaftalikGorevDurum(
      hafta: (map['hafta'] ?? '').toString(),
      puan: _int(map['puan']),
      gunTarih: (map['gunTarih'] ?? '').toString(),
      sayac: sayac,
      tamamlanan: tamamlanan,
      gunBonusuAlindi: map['gunBonusuAlindi'] == true,
      gorevler: gorevlerForWeekday(weekday),
    );
  }

  static Map<String, dynamic> _bosHaftalikGorev({
    required String hafta,
    required String gunTarih,
  }) {
    return {
      'hafta': hafta,
      'puan': 0,
      'gunTarih': gunTarih,
      'sayac': _bosSayac(),
      'tamamlanan': <String>[],
      'gunBonusuAlindi': false,
    };
  }

  static Map<String, int> _bosSayac() {
    return {
      for (final aksiyon in GorevAksiyon.values) aksiyon.name: 0,
    };
  }

  static Map<String, dynamic> _gunSifirla(
    Map<String, dynamic> mevcut, {
    required String gunTarih,
  }) {
    final guncel = Map<String, dynamic>.from(mevcut);
    guncel['gunTarih'] = gunTarih;
    guncel['sayac'] = _bosSayac();
    guncel['tamamlanan'] = <String>[];
    guncel['gunBonusuAlindi'] = false;
    return guncel;
  }

  static bool _gorevlerAcik(Map<String, dynamic>? userData) {
    if (userData == null) return false;
    return MascotServis.gunlukGorevlerAcik(
      MascotServis.parse(userData['robot']).seviye,
    );
  }

  static bool _mapAyni(dynamic ham, Map<String, dynamic> hedef) {
    if (ham is! Map) return false;
    final kaynak = Map<String, dynamic>.from(ham);
    return _json(kaynak) == _json(hedef);
  }

  static String _json(Map<String, dynamic> map) {
    final keys = map.keys.toList()..sort();
    return keys.map((key) => '$key:${map[key]}').join('|');
  }

  static _GorevIslem? _gorevIsle({
    required Map<String, dynamic>? userData,
    required GorevAksiyon aksiyon,
  }) {
    if (!_gorevlerAcik(userData)) return null;

    final simdi = turkiyeSimdi();
    final buHafta = haftaKimligi(simdi);
    final bugun = gunKimligi(simdi);
    final weekday = simdi.weekday;
    final gorevMap = senkronHaftalikGorevMap(userData?['haftalikGorev']);
    final durum = parse(raw: gorevMap, weekday: weekday);
    final gorev = durum.gorevler.firstWhere(
      (item) => item.aksiyon == aksiyon,
      orElse: () => throw StateError('Görev bulunamadı: $aksiyon'),
    );

    final sayac = Map<GorevAksiyon, int>.from(durum.sayac);
    final tamamlanan = Set<String>.from(durum.tamamlanan);
    var puan = durum.puan;
    var gunBonusuAlindi = durum.gunBonusuAlindi;
    final mesajlar = <String>[];

    if (!durum.gorevTamamMi(gorev)) {
      sayac[aksiyon] = (sayac[aksiyon] ?? 0) + 1;
    }

    for (final item in durum.gorevler) {
      if (tamamlanan.contains(item.id)) continue;
      if ((sayac[item.aksiyon] ?? 0) < item.hedef) continue;

      tamamlanan.add(item.id);
      puan += item.odul;
      mesajlar.add('${item.baslik} tamamlandı! +${item.odul} görev puanı');
    }

    final guncelDurum = HaftalikGorevDurum(
      hafta: buHafta,
      puan: puan,
      gunTarih: bugun,
      sayac: sayac,
      tamamlanan: tamamlanan,
      gunBonusuAlindi: gunBonusuAlindi,
      gorevler: durum.gorevler,
    );

    if (!guncelDurum.gorevTamamMi(gorev) && aksiyon != GorevAksiyon.acilis) {
      final hedefGorev = guncelDurum.gorevler.firstWhere(
        (item) => item.aksiyon == aksiyon,
      );
      final mevcut = guncelDurum.sayac[aksiyon] ?? 0;
      if (mevcut < hedefGorev.hedef) {
        mesajlar.add('${hedefGorev.baslik}: $mevcut/${hedefGorev.hedef}');
      }
    }

    if (guncelDurum.gorevler.every(guncelDurum.gorevTamamMi) &&
        !gunBonusuAlindi) {
      gunBonusuAlindi = true;
      puan += gunBonusu;
      mesajlar.add('Günün görevleri bitti! +$gunBonusu bonus');
    }

    if (puan > maksHaftalikPuan) {
      puan = maksHaftalikPuan;
    }

    final yazilacak = <String, dynamic>{
      'hafta': buHafta,
      'puan': puan,
      'gunTarih': bugun,
      'sayac': {
        for (final entry in sayac.entries) entry.key.name: entry.value,
      },
      'tamamlanan': tamamlanan.toList(),
      'gunBonusuAlindi': gunBonusuAlindi,
    };

    return _GorevIslem(
      durum: parse(raw: yazilacak, weekday: weekday),
      mesajlar: mesajlar,
      yazilacak: yazilacak,
    );
  }

  static String _hataMesaji(FirebaseException e) {
    if (e.code == 'permission-denied') {
      return 'Görev kaydı reddedildi. Firestore kurallarını kontrol et.';
    }
    return 'Görev kaydedilemedi (${e.code}).';
  }

  /// Gün/hafta değiştiyse Firestore kaydını günceller.
  static Future<HaftalikGorevSonuc> gunSenkronizeEt(String uid) async {
    if (uid.isEmpty) {
      return const HaftalikGorevSonuc(hata: 'Oturum bulunamadı.');
    }

    final ref = _db.collection('users').doc(uid);
    try {
      return await _db.runTransaction<HaftalikGorevSonuc>((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) {
          return const HaftalikGorevSonuc(hata: 'Kullanıcı kaydı bulunamadı.');
        }
        if (!_gorevlerAcik(snap.data())) {
          return HaftalikGorevSonuc(hata: gorevlerAcilmaHatasi);
        }

        final ham = snap.data()?['haftalikGorev'];
        final synced = senkronHaftalikGorevMap(ham);
        if (_mapAyni(ham, synced)) {
          return HaftalikGorevSonuc(
            durum: kullaniciVerisindenDurum(snap.data()),
          );
        }

        tx.set(
          ref,
          {'haftalikGorev': synced},
          SetOptions(merge: true),
        );

        return HaftalikGorevSonuc(
          durum: kullaniciVerisindenDurum({
            ...?snap.data(),
            'haftalikGorev': synced,
          }),
        );
      });
    } on FirebaseException catch (e, stack) {
      debugPrint(
        'HaftalikGorevServis.gunSenkronizeEt failed (${e.code}): ${e.message}\n$stack',
      );
      return HaftalikGorevSonuc(hata: _hataMesaji(e));
    }
  }

  /// Uygulama açılışında: gün senkronu + giriş görevi.
  static Future<HaftalikGorevSonuc> oturumSenkronizeEt(String uid) async {
    final senkron = await gunSenkronizeEt(uid);
    if (senkron.hata == gorevlerAcilmaHatasi) {
      return senkron;
    }
    if (senkron.hata != null &&
        senkron.hata != gorevlerAcilmaHatasi) {
      return senkron;
    }
    return aksiyonKaydet(uid, GorevAksiyon.acilis);
  }

  static Future<HaftalikGorevSonuc> acilisKaydet(String uid) {
    return aksiyonKaydet(uid, GorevAksiyon.acilis);
  }

  // Sosyal aksiyon sonrası görev ilerlemesini kaydeder
  static Future<HaftalikGorevSonuc> aksiyonKaydet(
    String uid,
    GorevAksiyon aksiyon,
  ) async {
    if (uid.isEmpty) {
      return const HaftalikGorevSonuc(hata: 'Oturum bulunamadı.');
    }

    for (var deneme = 0; deneme < 5; deneme++) {
      try {
        final sonuc = await _db.runTransaction<HaftalikGorevSonuc>((tx) async {
          final ref = _db.collection('users').doc(uid);
          final snap = await tx.get(ref);
          if (!snap.exists) {
            return const HaftalikGorevSonuc(
                hata: 'Kullanıcı kaydı bulunamadı.');
          }

          final islem = _gorevIsle(userData: snap.data(), aksiyon: aksiyon);
          if (islem == null) {
            return HaftalikGorevSonuc(
              hata: gorevlerAcilmaHatasi,
            );
          }

          tx.set(
            ref,
            {'haftalikGorev': islem.yazilacak},
            SetOptions(merge: true),
          );

          return HaftalikGorevSonuc(
            durum: islem.durum,
            mesajlar: islem.mesajlar,
          );
        });

        if (sonuc.basarili || sonuc.hata == gorevlerAcilmaHatasi) {
          return sonuc;
        }
        if (deneme == 4) return sonuc;
      } on FirebaseException catch (e, stack) {
        debugPrint(
          'HaftalikGorevServis.aksiyonKaydet failed (${e.code}): ${e.message}\n$stack',
        );
        if (deneme == 4) {
          return HaftalikGorevSonuc(hata: _hataMesaji(e));
        }
      } catch (e, stack) {
        debugPrint('HaftalikGorevServis.aksiyonKaydet failed: $e\n$stack');
        if (deneme == 4) {
          return const HaftalikGorevSonuc(hata: 'Görev kaydedilemedi.');
        }
      }
    }

    return const HaftalikGorevSonuc(hata: 'Görev kaydedilemedi.');
  }
}

// Dahili görev işlem sonucu
class _GorevIslem {
  const _GorevIslem({
    required this.durum,
    required this.mesajlar,
    required this.yazilacak,
  });

  final HaftalikGorevDurum durum;
  final List<String> mesajlar;
  final Map<String, dynamic> yazilacak;
}
