// Takip, takipçi, liderlik ve görünürlük işlemleri
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:myvibel/error_messages.dart';
import 'package:myvibel/haftalik_gorev_servis.dart';
import 'package:myvibel/maskot_servis.dart';
import 'package:myvibel/sosyal/bildirim_servis.dart';
import 'package:myvibel/sosyal/engel_servis.dart';
import 'package:myvibel/sosyal/sosyal_core.dart';

// Kullanıcının takip durumu
enum TakipDurumu {
  takipEtmiyor, // Takip ilişkisi yok
  istekGonderildi, // Gizli hesaba istek gönderildi
  takipEdiliyor, // Aktif takip ilişkisi var
}

// Takip isteği kabul/red sonucu
class TakipIslemSonucu {
  const TakipIslemSonucu({
    required this.basarili,
    required this.mesaj,
    this.bildirimiTemizle = false,
  });

  final bool basarili;
  final String mesaj;
  final bool bildirimiTemizle;
}

class LiderlikTabloSonucu {
  const LiderlikTabloSonucu({
    required this.liste,
    this.benimSira,
  });

  final List<Map<String, dynamic>> liste;
  final int? benimSira;

  bool get ilkYuzde {
    final sira = benimSira;
    if (sira == null) return false;
    return sira >= 1 && sira <= liste.length && sira <= 100;
  }
}

// Takip sistemi ve liderlik servisi
class TakipServis {
  static const liderlikLimit = 100;

  static bool takipCikisVilHarcanacakVeri(Map<String, dynamic>? data) {
    return data != null &&
        data["puanVerildi"] == true &&
        data["vilGeriAlindi"] != true;
  }

  static Future<bool> takipCikisVilHarcanacak(String hedefUid) async {
    final current = FirebaseAuth.instance.currentUser;
    if (current == null || hedefUid.isEmpty) return false;
    final snap = await SosyalCore.db
        .collection("users")
        .doc(current.uid)
        .collection("followRewarded")
        .doc(hedefUid)
        .get();
    return takipCikisVilHarcanacakVeri(snap.data());
  }

  // Liderlik satırlarını maskot seviyesine göre sıralar
  static List<Map<String, dynamic>> _liderlikSatirlariniDuzenle(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs, {
    int? limit,
  }) {
    final satirlar = docs.map((doc) {
      final data = doc.data();
      final robot = MascotServis.parse(data["robot"]);
      return {
        "uid": doc.id,
        "adSoyad": data["adSoyad"] ?? "Vibe Kullanıcısı",
        "kullaniciAdi": data["kullaniciAdi"] ?? "kullanici",
        "photoUrl": data["photoUrl"] ?? "",
        "avatarKey": data["avatarKey"] ?? "",
        "robotSeviye": robot.seviye,
        "robotGelisimPuani": robot.gelisimPuani,
        "robotIsim": robot.isim,
      };
    }).where((satir) {
      return (satir["robotSeviye"] as int) >= 1;
    }).toList();

    satirlar.sort((a, b) {
      final seviyeKars = (b["robotSeviye"] as int)
          .compareTo(a["robotSeviye"] as int);
      if (seviyeKars != 0) return seviyeKars;
      return (b["robotGelisimPuani"] as int)
          .compareTo(a["robotGelisimPuani"] as int);
    });

    if (limit == null) return satirlar;
    return satirlar.take(limit).toList();
  }

  static Query<Map<String, dynamic>> _liderlikSiraliSorgu({required int limit}) {
    return SosyalCore.db
        .collection("users")
        .orderBy("robot.seviye", descending: true)
        .orderBy("robot.gelisimPuani", descending: true)
        .limit(limit);
  }

  static Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      _liderlikBelgeleriniGetir({required int limit}) async {
    try {
      final snap = await _liderlikSiraliSorgu(limit: limit).get();
      return snap.docs;
    } catch (e) {
      debugPrint("liderlik sirali sorgu yedegi: $e");
      final snap = await SosyalCore.db.collection("users").limit(300).get();
      return snap.docs;
    }
  }

  static Future<int?> _benimSirayiHesapla({
    required String uid,
    required List<Map<String, dynamic>> sirali,
  }) async {
    final idx = sirali.indexWhere((s) => s["uid"] == uid);
    if (idx >= 0) return idx + 1;
    // Limitsiz count() kuralda kapalı; listede yoksa sıra gösterme.
    return null;
  }

  // Maskot seviyesine göre liderlik tablosunu getirir
  static Future<LiderlikTabloSonucu> liderlikTablosuGetir({
    int limit = liderlikLimit,
  }) async {
    final current = FirebaseAuth.instance.currentUser;
    const onYedek = 60;
    final ilkLimit = (limit + onYedek).clamp(limit, 250).toInt();
    final belgeFuture = _liderlikBelgeleriniGetir(limit: ilkLimit);
    var engelIdleri = <String>{};
    if (current != null) {
      final engeller = await Future.wait([
        EngelServis.engellenenKullanicilariGetir(current.uid),
        EngelServis.beniEngelleyenKullanicilariGetir(current.uid),
      ]);
      engelIdleri = {...engeller[0], ...engeller[1]};
    }

    var snapDocs = await belgeFuture;
    final cekimLimiti =
        (limit + engelIdleri.length + 30).clamp(limit, 250).toInt();
    if (cekimLimiti > ilkLimit) {
      snapDocs = await _liderlikBelgeleriniGetir(limit: cekimLimiti);
    }
    final docs = engelIdleri.isEmpty
        ? snapDocs
        : snapDocs.where((doc) => !engelIdleri.contains(doc.id)).toList();

    final tumu = _liderlikSatirlariniDuzenle(docs);
    int? benimSira;
    final uid = current?.uid;
    if (uid != null && uid.isNotEmpty) {
      benimSira = await _benimSirayiHesapla(uid: uid, sirali: tumu);
    }

    return LiderlikTabloSonucu(
      liste: tumu.take(limit).toList(),
      benimSira: benimSira,
    );
  }

  // Engel filtresi olmadan global ilk 3 kullanıcı uid'lerini getirir (avatar taçları için)
  static Future<List<String>> liderlikUstUcUidleri() async {
    final snapDocs = await _liderlikBelgeleriniGetir(limit: 12);
    final satirlar = _liderlikSatirlariniDuzenle(snapDocs, limit: 3);
    return satirlar
        .map((satir) => (satir['uid'] ?? '').toString())
        .where((uid) => uid.isNotEmpty)
        .toList();
  }

  // Bekleyen takip ödüllerini senkronize eder; verilen toplam puanı döner.
  static Future<int> takipOdulleriniSenkronizeEt(String uid) async {
    if (uid.isEmpty) return 0;

    final oduller = await SosyalCore.db
        .collection("users")
        .doc(uid)
        .collection("followRewarded")
        .get();

    var toplamPuan = 0;
    for (final doc in oduller.docs) {
      final data = doc.data();
      if (data["puanVerildi"] == true) continue; // Zaten verilmiş
      try {
        final verildi = await _takipOdulunuVer(
          takipEdenUid: uid,
          hedefUid: doc.id,
        );
        if (verildi) {
          toplamPuan += 5;
          unawaited(
            HaftalikGorevServis.aksiyonKaydet(uid, GorevAksiyon.takip)
                .then((sonuc) {
              if (!sonuc.basarili && sonuc.hata != null) {
                debugPrint('Görev takip senkron kaydı: ${sonuc.hata}');
              }
            }),
          );
        }
      } catch (e) {
        debugPrint('takipOdulleriniSenkronizeEt failed (${doc.id}): $e');
      }
    }
    return toplamPuan;
  }

  // Takip ödül puanını transaction ile verir
  static Future<bool> _takipOdulunuVer({
    required String takipEdenUid,
    required String hedefUid,
  }) async {
    final userRef = SosyalCore.db.collection("users").doc(takipEdenUid);
    final rewardRef = userRef.collection("followRewarded").doc(hedefUid);

    return SosyalCore.db.runTransaction<bool>((tx) async {
      final rewardSnap = await tx.get(rewardRef);
      if (rewardSnap.exists && rewardSnap.data()?["puanVerildi"] == true) {
        return false; // Daha önce verilmiş
      }

      await tx.get(userRef);

      if (rewardSnap.exists) {
        tx.update(rewardRef, {"puanVerildi": true});
      } else {
        tx.set(rewardRef, {
          "targetUid": hedefUid,
          "puanVerildi": true,
          "createdAt": FieldValue.serverTimestamp(),
        });
      }

      final userGuncelleme = <String, dynamic>{
        "puan": FieldValue.increment(5),
        "sonTakipOdulUid": hedefUid,
      };
      tx.update(userRef, userGuncelleme);
      return true;
    }).then((verildi) async {
      if (verildi) {
        try {
          await MascotServis.sosyalOdulKaydet(
            takipEdenUid,
            MascotServis.vilTakip,
          );
        } catch (e) {
          debugPrint('takip maskot odul: $e');
        }
      }
      return verildi;
    });
  }

  // Takip ödülünü bekletmeye alır
  static Future<void> _takipOdulBeklet({
    required String takipEdenUid,
    required String hedefUid,
  }) async {
    final rewardRef = SosyalCore.db
        .collection("users")
        .doc(takipEdenUid)
        .collection("followRewarded")
        .doc(hedefUid);
    final mevcut = await rewardRef.get();
    // Bu akış sadece "ilk create" için kullanılmalı.
    // Belge zaten varsa (true/false fark etmeksizin) update denemek rules tarafından reddedilir.
    if (mevcut.exists) return;

    await rewardRef.set(
      {
        "targetUid": hedefUid,
        "puanVerildi": false,
        "createdAt": FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  // Takip edilen kullanıcı profillerini getirir
  static Future<List<Map<String, dynamic>>> takipEdilenProfilleriGetir(
    String uid,
  ) async {
    final following = await SosyalCore.db
        .collection("users")
        .doc(uid)
        .collection("following")
        .get();
    final ids =
        following.docs.map((d) => d.id).where((id) => id.isNotEmpty).toList();
    if (ids.isEmpty) return [];

    final profiller = <Map<String, dynamic>>[];
    for (var i = 0; i < ids.length; i += 10) {
      final part = ids.sublist(i, i + 10 > ids.length ? ids.length : i + 10);
      final snap = await SosyalCore.db
          .collection("users")
          .where(FieldPath.documentId, whereIn: part)
          .limit(part.length)
          .get();
      for (final doc in snap.docs) {
        final data = doc.data();
        profiller.add({
          "uid": doc.id,
          "adSoyad": data["adSoyad"] ?? "Vibe Kullanıcısı",
          "kullaniciAdi": data["kullaniciAdi"] ?? "kullanici",
          "photoUrl": data["photoUrl"] ?? "",
          "avatarKey": data["avatarKey"] ?? "",
        });
      }
    }
    profiller.sort(
      (a, b) => (a["adSoyad"] as String).toLowerCase().compareTo(
            (b["adSoyad"] as String).toLowerCase(),
          ),
    );
    return profiller;
  }

  // Takip edilen kullanıcı id setini döndürür
  static Future<Set<String>> takipEdilenIdleriGetir(String uid) async {
    final snap = await SosyalCore.db
        .collection("users")
        .doc(uid)
        .collection("following")
        .limit(500)
        .get();
    return snap.docs.map((doc) => doc.id).toSet();
  }

  // Mevcut kullanıcının hedefe takip durumu
  static Future<TakipDurumu> takipDurumuGetir(String hedefUid) async {
    final current = FirebaseAuth.instance.currentUser;
    if (current == null || current.uid == hedefUid) {
      return TakipDurumu.takipEdiliyor; // Kendi profili
    }
    if (await SosyalCore.engellendiMi(
        kaynakUid: current.uid, hedefUid: hedefUid)) {
      return TakipDurumu.takipEtmiyor;
    }

    final following = await SosyalCore.db
        .collection("users")
        .doc(current.uid)
        .collection("following")
        .doc(hedefUid)
        .get();

    if (following.exists) return TakipDurumu.takipEdiliyor;

    final istek = await SosyalCore.db
        .collection("users")
        .doc(hedefUid)
        .collection("followRequests")
        .doc(current.uid)
        .get();

    if (istek.exists) return TakipDurumu.istekGonderildi;

    return TakipDurumu.takipEtmiyor;
  }

  // İzleyici hedefi takipçi mi
  static Future<bool> takipciMi({
    required String izleyiciUid,
    required String hedefUid,
  }) async {
    if (izleyiciUid == hedefUid) return true; // Kendi profili
    if (await SosyalCore.engellendiMi(
        kaynakUid: izleyiciUid, hedefUid: hedefUid)) {
      return false;
    }

    final follower = await SosyalCore.db
        .collection("users")
        .doc(hedefUid)
        .collection("followers")
        .doc(izleyiciUid)
        .get();

    return follower.exists;
  }

  // Tek gönderi izleyiciye görünür mü
  static Future<bool> gonderiGorulebilir({
    required String izleyiciUid,
    required String postOwnerUid,
  }) async {
    if (izleyiciUid == postOwnerUid) return true;
    if (await SosyalCore.engellendiMi(
        kaynakUid: izleyiciUid, hedefUid: postOwnerUid)) {
      return false;
    }

    final owner = await SosyalCore.kullaniciVerisi(postOwnerUid);
    final hesapGizli = owner?["hesapGizli"] == true;
    if (!hesapGizli) return true; // Açık hesap

    return takipciMi(izleyiciUid: izleyiciUid, hedefUid: postOwnerUid);
  }

  // Profil gönderileri izleyiciye görünür mü
  static Future<bool> profilGonderileriGorulebilir({
    required String izleyiciUid,
    required String profilUid,
    bool? hesapGizli,
  }) async {
    if (izleyiciUid == profilUid) return true;
    if (await SosyalCore.engellendiMi(
        kaynakUid: izleyiciUid, hedefUid: profilUid)) {
      return false;
    }

    final gizli = hesapGizli ??
        ((await SosyalCore.kullaniciVerisi(profilUid))?["hesapGizli"] == true);

    if (!gizli) return true;

    return takipciMi(izleyiciUid: izleyiciUid, hedefUid: profilUid);
  }

  // Karşılıklı takip kayıtlarını oluşturur
  static Future<bool> _takipBaglantisiniOlustur({
    required String takipEdenUid,
    required String hedefUid,
    required bool puanVer,
  }) async {
    if (await SosyalCore.takipEtkilesimEngelliMi(
      takipEdenUid: takipEdenUid,
      hedefUid: hedefUid,
    )) {
      throw "Bu kullanıcı ile takip işlemi yapılamıyor.";
    }

    final current = FirebaseAuth.instance.currentUser;
    if (current == null) throw "Oturum bulunamadı.";

    final veri = {
      "userId": takipEdenUid,
      "createdAt": FieldValue.serverTimestamp(),
    };
    final followingRef = SosyalCore.db
        .collection("users")
        .doc(takipEdenUid)
        .collection("following")
        .doc(hedefUid);
    final followerRef = SosyalCore.db
        .collection("users")
        .doc(hedefUid)
        .collection("followers")
        .doc(takipEdenUid);

    Future<void> kaydiYaz(
      DocumentReference<Map<String, dynamic>> ref,
      String etiket,
    ) async {
      try {
        await ref.set(veri);
      } on FirebaseException catch (e) {
        throw "Takip kaydı yazılamadı ($etiket): ${e.code} ${e.message ?? ''}";
      }
    }

    // Kabul eden kullanıcı karşı tarafın following listesini okuyamaz (gizli hesap).
    // Bu yüzden sadece erişilebilen taraftan kontrol yapılır.
    if (current.uid == hedefUid) {
      final followerSnap = await followerRef.get();
      if (!followerSnap.exists) {
        await kaydiYaz(followerRef, "followers");
        await kaydiYaz(followingRef, "following");
      }
    } else if (current.uid == takipEdenUid) {
      final followingSnap = await followingRef.get();
      if (!followingSnap.exists) {
        await kaydiYaz(followingRef, "following");
        await kaydiYaz(followerRef, "followers");
      }
    } else {
      throw "Takip işlemi için yetkin yok.";
    }

    var puanEklendi = false;
    if (puanVer) {
      final current = FirebaseAuth.instance.currentUser;
      try {
        if (current?.uid == takipEdenUid) {
          puanEklendi = await _takipOdulunuVer(
            takipEdenUid: takipEdenUid,
            hedefUid: hedefUid,
          );
        } else {
          await _takipOdulBeklet(
            takipEdenUid: takipEdenUid,
            hedefUid: hedefUid,
          );
        }
      } catch (e) {
        debugPrint("_takipBaglantisiniOlustur puan islemi failed: $e");
      }
    }

    try {
      final current = FirebaseAuth.instance.currentUser;
      // Sadece doğrudan takip eden kullanıcı bildirim gönderir (kabul akışında değil).
      if (current?.uid == takipEdenUid) {
        await BildirimServis.bildirimEkle(
          hedefUid: hedefUid,
          tip: "follow",
          gonderenUid: takipEdenUid,
          metin: "seni takip etmeye başladı",
        );
      }
    } catch (e) {
      debugPrint("_takipBaglantisiniOlustur follow bildirimi failed: $e");
    }

    if (puanEklendi) {
      unawaited(
        HaftalikGorevServis.aksiyonKaydet(takipEdenUid, GorevAksiyon.takip)
            .then((sonuc) {
          if (!sonuc.basarili && sonuc.hata != null) {
            debugPrint('Görev takip kaydı: ${sonuc.hata}');
          }
        }),
      );
    }

    final oturumUid = FirebaseAuth.instance.currentUser?.uid;
    if (oturumUid != null) {
      final otherUid = oturumUid == takipEdenUid ? hedefUid : takipEdenUid;
      unawaited(MascotServis.bagTakibiYenilendi(otherUid));
    }

    return puanEklendi;
  }

  /// following kaydı var ama karşı tarafta followers eksikse onarır (feed okuma izni).
  // Eksik takip bağlantısını onarır
  static Future<void> takipBaglantisiniOnar({
    required String takipEdenUid,
    required String hedefUid,
  }) async {
    if (takipEdenUid.isEmpty || hedefUid.isEmpty || takipEdenUid == hedefUid) {
      return;
    }

    final followingRef = SosyalCore.db
        .collection("users")
        .doc(takipEdenUid)
        .collection("following")
        .doc(hedefUid);
    final followerRef = SosyalCore.db
        .collection("users")
        .doc(hedefUid)
        .collection("followers")
        .doc(takipEdenUid);

    final following = await followingRef.get();
    final follower = await followerRef.get();
    if (following.exists && follower.exists) return; // Zaten tutarlı
    if (!following.exists && !follower.exists) return; // İkisi de yok

    final veri = {
      "userId": takipEdenUid,
      "createdAt": FieldValue.serverTimestamp(),
    };

    try {
      await (SosyalCore.db.batch()
            ..set(followingRef, veri, SetOptions(merge: true))
            ..set(followerRef, veri, SetOptions(merge: true)))
          .commit();
    } catch (e) {
      debugPrint(
        "takipBaglantisiniOnar failed ($takipEdenUid -> $hedefUid): $e",
      );
    }
  }

  // Kullanıcıyı takip etmeye başlar
  static Future<String> takipEt(String hedefUid) async {
    final current = FirebaseAuth.instance.currentUser;
    if (current == null) return "Oturum bulunamadı.";

    if (current.uid == hedefUid) return "Kendini takip edemezsin.";
    if (await SosyalCore.engellendiMi(
        kaynakUid: current.uid, hedefUid: hedefUid)) {
      return "Bu kullanıcı ile etkileşim kuramazsın.";
    }

    final hedef = await SosyalCore.kullaniciVerisi(hedefUid);
    if (hedef == null) return "Kullanıcı bulunamadı.";

    final hesapGizli = hedef["hesapGizli"] == true;
    final durum = await takipDurumuGetir(hedefUid);

    if (durum == TakipDurumu.takipEdiliyor) {
      return "Zaten takip ediyorsun.";
    }
    if (durum == TakipDurumu.istekGonderildi) {
      return "Takip isteği zaten gönderildi.";
    }

    if (hesapGizli) {
      // Gizli hesaba takip isteği gönder
      await SosyalCore.db
          .collection("users")
          .doc(hedefUid)
          .collection("followRequests")
          .doc(current.uid)
          .set({
        "userId": current.uid,
        "createdAt": FieldValue.serverTimestamp(),
      });

      await BildirimServis.bildirimEkle(
        hedefUid: hedefUid,
        tip: "follow_request",
        gonderenUid: current.uid,
        metin: "sana takip isteği gönderdi",
      );

      return "Takip isteği gönderildi.";
    }

    final puanVerildi = await _takipBaglantisiniOlustur(
      takipEdenUid: current.uid,
      hedefUid: hedefUid,
      puanVer: true,
    );

    return puanVerildi
        ? "Takip ediliyor. +5 puan kazandın!"
        : "Takip ediliyor.";
  }

  // Takipten çıkar ve istekleri temizler
  static Future<String> takiptenCik(String hedefUid) async {
    final current = FirebaseAuth.instance.currentUser;
    if (current == null) return "Oturum bulunamadı.";
    if (hedefUid.isEmpty) return "Geçersiz kullanıcı.";

    final userRef = SosyalCore.db.collection("users").doc(current.uid);
    final followingRef = userRef.collection("following").doc(hedefUid);
    final followerRef = SosyalCore.db
        .collection("users")
        .doc(hedefUid)
        .collection("followers")
        .doc(current.uid);
    final requestRef = SosyalCore.db
        .collection("users")
        .doc(hedefUid)
        .collection("followRequests")
        .doc(current.uid);
    final rewardRef = userRef.collection("followRewarded").doc(hedefUid);

    final followingSnap = await followingRef.get();
    if (!followingSnap.exists) {
      await requestRef.delete();
      return "Takipten çıkıldı.";
    }

    final rewardSnap = await rewardRef.get();
    final vilHarcanacak = takipCikisVilHarcanacakVeri(rewardSnap.data());

    if (vilHarcanacak) {
      await MascotServis.sosyalGeriAlVilOnKontrol(
        uid: current.uid,
        maliyet: MascotServis.vilTakipGeriAlMaliyeti,
        yetersizMesaji: MascotServis.sosyalGeriAlVilYetersizMesaji(
          "Takipten çıkmak",
          MascotServis.vilTakipGeriAlMaliyeti,
        ),
      );
    }

    try {
      await SosyalCore.db.runTransaction((tx) async {
        final followingNow = await tx.get(followingRef);
        if (!followingNow.exists) return;

        final rewardNow = await tx.get(rewardRef);
        final userSnap = await tx.get(userRef);
        final userData = userSnap.data() ?? <String, dynamic>{};
        final rewardData = rewardNow.data();
        final odulSimdi =
            rewardNow.exists && rewardData?["puanVerildi"] == true;
        final vilSimdi = takipCikisVilHarcanacakVeri(rewardData);

        if (vilSimdi) {
          final puanInt =
              userData["puan"] is num ? (userData["puan"] as num).toInt() : 0;
          final guncelleme = <String, dynamic>{
            "sonTakipOdulUid": hedefUid,
          };
          if (puanInt >= 5) {
            guncelleme["puan"] = FieldValue.increment(-5);
          }
          MascotServis.sosyalGeriAlVilEkle(
            guncelleme: guncelleme,
            robotHam: userData["robot"],
            maliyet: MascotServis.vilTakipGeriAlMaliyeti,
            yetersizMesaji: MascotServis.sosyalGeriAlVilYetersizMesaji(
              "Takipten çıkmak",
              MascotServis.vilTakipGeriAlMaliyeti,
            ),
          );
          if (guncelleme.length > 1) {
            tx.update(userRef, guncelleme);
          }
          tx.update(rewardRef, {"vilGeriAlindi": true});
        } else if (rewardNow.exists && !odulSimdi) {
          tx.delete(rewardRef);
        }

        tx.delete(followingRef);
        tx.delete(followerRef);
        tx.delete(requestRef);
      });
    } on FirebaseException catch (e) {
      if (e.code != "permission-denied") rethrow;
      // Puan/vil geri alma kuralı takılırsa takip kaydı yine silinsin.
      await Future.wait([
        SosyalCore.guvenliSil(followingRef),
        SosyalCore.guvenliSil(followerRef),
        SosyalCore.guvenliSil(requestRef),
      ]);
    }

    unawaited(MascotServis.bagTakibiKesildi(hedefUid));

    return "Takipten çıkıldı.";
  }

  // Hedef kullanıcıyla etkileşim engelli mi
  static Future<bool> etkilesimEngelliMi(String hedefUid) async {
    final current = FirebaseAuth.instance.currentUser;
    if (current == null) return true;
    if (current.uid == hedefUid) return false;
    return SosyalCore.engellendiMi(kaynakUid: current.uid, hedefUid: hedefUid);
  }

  // Gönderilmiş takip isteğini iptal eder
  static Future<String> takipIstegiIptal(String hedefUid) async {
    final current = FirebaseAuth.instance.currentUser;
    if (current == null) return "Oturum bulunamadı.";

    await SosyalCore.db
        .collection("users")
        .doc(hedefUid)
        .collection("followRequests")
        .doc(current.uid)
        .delete();

    return "Takip isteği iptal edildi.";
  }

  // Gelen takip isteğini kabul eder
  static Future<TakipIslemSonucu> takipIstegiKabul(String istekciUid) async {
    try {
      final current = FirebaseAuth.instance.currentUser;
      if (current == null) {
        return const TakipIslemSonucu(
          basarili: false,
          mesaj: "Oturum bulunamadı.",
        );
      }
      if (istekciUid.isEmpty) {
        return const TakipIslemSonucu(
          basarili: false,
          mesaj: "Geçersiz takip isteği.",
        );
      }

      final istekRef = SosyalCore.db
          .collection("users")
          .doc(current.uid)
          .collection("followRequests")
          .doc(istekciUid);

      final istek = await istekRef.get();
      final zatenTakipci = await takipciMi(
        izleyiciUid: istekciUid,
        hedefUid: current.uid,
      );

      if (!istek.exists && !zatenTakipci) {
        await BildirimServis.takipIstegiBildirimleriniSil(
          current.uid,
          istekciUid,
        );
        return const TakipIslemSonucu(
          basarili: false,
          bildirimiTemizle: true,
          mesaj:
              "Bu takip isteği artık geçerli değil. Karşı tarafın yeniden istek göndermesi gerekir.",
        );
      }

      if (!zatenTakipci) {
        await _takipBaglantisiniOlustur(
          takipEdenUid: istekciUid,
          hedefUid: current.uid,
          puanVer: true,
        );
      }

      await SosyalCore.guvenliSil(istekRef);
      await BildirimServis.takipIstegiBildirimleriniSil(
        current.uid,
        istekciUid,
      );

      try {
        await BildirimServis.bildirimEkle(
          hedefUid: istekciUid,
          tip: "follow_accepted",
          gonderenUid: current.uid,
          metin: "takip isteğini kabul etti",
        );
      } catch (e) {
        debugPrint("follow_accepted bildirimi failed: $e");
      }

      return TakipIslemSonucu(
        basarili: true,
        bildirimiTemizle: true,
        mesaj:
            zatenTakipci ? "Zaten takipçisin." : "Takip isteği kabul edildi.",
      );
    } catch (e, stack) {
      debugPrint("takipIstegiKabul failed: $e\n$stack");
      if (e is String) {
        return TakipIslemSonucu(basarili: false, mesaj: e);
      }
      return TakipIslemSonucu(
        basarili: false,
        mesaj: internetAwareErrorMessage(
          error: e,
          fallback: "Takip isteği kabul edilemedi. Lütfen tekrar dene.",
        ),
      );
    }
  }

  // Gelen takip isteğini reddeder
  static Future<TakipIslemSonucu> takipIstegiRed(String istekciUid) async {
    try {
      final current = FirebaseAuth.instance.currentUser;
      if (current == null) {
        return const TakipIslemSonucu(
          basarili: false,
          mesaj: "Oturum bulunamadı.",
        );
      }

      final istekRef = SosyalCore.db
          .collection("users")
          .doc(current.uid)
          .collection("followRequests")
          .doc(istekciUid);
      await SosyalCore.guvenliSil(istekRef);
      await BildirimServis.takipIstegiBildirimleriniSil(
          current.uid, istekciUid);

      return const TakipIslemSonucu(
        basarili: true,
        bildirimiTemizle: true,
        mesaj: "Takip isteği reddedildi.",
      );
    } catch (e, stack) {
      debugPrint("takipIstegiRed failed: $e\n$stack");
      return TakipIslemSonucu(
        basarili: false,
        mesaj: internetAwareErrorMessage(
          error: e,
          fallback: "Takip isteği reddedilemedi.",
        ),
      );
    }
  }

  // Takip butonuna basıldığında uygun işlemi yapar
  static Future<String> takipButonunaBas(
      String hedefUid, TakipDurumu durum) async {
    try {
      switch (durum) {
        case TakipDurumu.takipEdiliyor:
          return await takiptenCik(hedefUid);
        case TakipDurumu.istekGonderildi:
          return await takipIstegiIptal(hedefUid);
        case TakipDurumu.takipEtmiyor:
          return await takipEt(hedefUid);
      }
    } catch (e) {
      return internetAwareErrorMessage(
        error: e,
        fallback: "Takip işlemi başarısız.",
      );
    }
  }

  // Takip durumuna göre buton metni
  static String takipButonMetni(TakipDurumu durum) {
    switch (durum) {
      case TakipDurumu.takipEdiliyor:
        return "Takip Ediliyor";
      case TakipDurumu.istekGonderildi:
        return "İstek Gönderildi";
      case TakipDurumu.takipEtmiyor:
        return "Takip Et";
    }
  }
}
