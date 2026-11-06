// Kullanıcı engelleme, şikayet ve kullanıcı adı işlemleri
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:myvibel/sosyal/begeni_yorum_servis.dart';
import 'package:myvibel/sosyal/etiket_servis.dart';
import 'package:myvibel/sosyal/sosyal_core.dart';

// Engel, şikayet ve profil gizlilik servisi
class EngelServis {
  // Kullanıcının tüm gönderilerinde gizlilik bayrağını günceller
  static Future<void> kullaniciGonderilerindeGizlilikGuncelle(
    String uid,
    bool hesapGizli,
  ) async {
    final posts = await SosyalCore.db
        .collection("posts")
        .where("userId", isEqualTo: uid)
        .get();

    if (posts.docs.isEmpty) return;

    var batch = SosyalCore.db.batch();
    var sayac = 0;

    for (final doc in posts.docs) {
      batch.update(doc.reference, {"ownerHesapGizli": hesapGizli});
      sayac++;
      if (sayac >= 400) {
        await batch.commit(); // Batch limitinde commit
        batch = SosyalCore.db.batch();
        sayac = 0;
      }
    }
    if (sayac > 0) await batch.commit();
  }

  // Kullanıcıyı engeller ve takip bağlantılarını temizler
  static Future<void> engelleKullanici(String hedefUid) async {
    final current = FirebaseAuth.instance.currentUser;
    if (current == null) throw "Oturum bulunamadı.";
    if (current.uid == hedefUid) throw "Kendini engelleyemezsin.";

    final now = FieldValue.serverTimestamp();
    final benimRef = SosyalCore.db.collection("users").doc(current.uid);
    final hedefRef = SosyalCore.db.collection("users").doc(hedefUid);

    final batch = SosyalCore.db.batch();
    batch.set(benimRef.collection("blocked").doc(hedefUid), {
      "uid": hedefUid,
      "createdAt": now,
    });
    batch.set(hedefRef.collection("blockedBy").doc(current.uid), {
      "uid": current.uid,
      "createdAt": now,
    });

    await batch.commit();

    // Takip ve istek kayıtlarını paralel temizle
    await Future.wait([
      SosyalCore.guvenliSil(benimRef.collection("following").doc(hedefUid)),
      SosyalCore.guvenliSil(benimRef.collection("followers").doc(hedefUid)),
      SosyalCore.guvenliSil(benimRef.collection("followRequests").doc(hedefUid)),
      SosyalCore.guvenliSil(hedefRef.collection("following").doc(current.uid)),
      SosyalCore.guvenliSil(hedefRef.collection("followers").doc(current.uid)),
      SosyalCore.guvenliSil(hedefRef.collection("followRequests").doc(current.uid)),
    ]);

    // Karşı tarafın bildirimlerini silmek rules'a takılabilir; engellemeyi bozmasın.
    await SosyalCore.guvenliTakipIstegiBildirimleriniSil(hedefUid, current.uid);
    await SosyalCore.guvenliTakipIstegiBildirimleriniSil(current.uid, hedefUid);

    try {
      await BegeniYorumServis.engellenenKullanicininBegenileriniKaldir(
        uid: current.uid,
        hedefUid: hedefUid,
      );
      await BegeniYorumServis.engelleneninGonderilerindekiBegenileriKaldir(
        ownerUid: current.uid,
        likerUid: hedefUid,
      );
    } catch (e) {
      debugPrint('engelle begeni temizligi ($hedefUid): $e');
    }
  }

  // Kullanıcı adını benzersiz şekilde günceller
  static Future<void> kullaniciAdiGuncelle({
    required String uid,
    required String eskiKullaniciAdiKucuk,
    required String yeniKullaniciAdi,
    required String yeniKullaniciAdiKucuk,
  }) async {
    final yeniKullaniciAdiKucukNorm = EtiketServis.etiketNormalize(yeniKullaniciAdiKucuk);
    if (yeniKullaniciAdiKucukNorm.length < 3) {
      throw "Kullanıcı adı en az 3 karakter olmalı.";
    }
    final regex = RegExp(r'^[a-z0-9_\.]+$');
    if (!regex.hasMatch(yeniKullaniciAdiKucukNorm)) {
      throw "Kullanıcı adında sadece harf, sayı, nokta ve alt çizgi kullan.";
    }

    if (eskiKullaniciAdiKucuk == yeniKullaniciAdiKucukNorm) return; // Değişiklik yok

    final eskiRef = SosyalCore.db.collection("usernames").doc(eskiKullaniciAdiKucuk);
    final yeniRef =
        SosyalCore.db.collection("usernames").doc(yeniKullaniciAdiKucukNorm);

    await SosyalCore.db.runTransaction((tx) async {
      final yeniSnap = await tx.get(yeniRef);
      if (yeniSnap.exists && yeniSnap.data()?["uid"] != uid) {
        throw "Bu kullanıcı adı zaten alınmış.";
      }

      DocumentSnapshot<Map<String, dynamic>>? eskiSnap;
      if (eskiKullaniciAdiKucuk.isNotEmpty) {
        eskiSnap = await tx.get(eskiRef);
      }

      final authEmail =
          FirebaseAuth.instance.currentUser?.email?.trim().toLowerCase() ?? '';
      final eskiEmail = eskiSnap?.data()?['email']?.toString().trim() ?? '';
      final email = authEmail.isNotEmpty
          ? authEmail
          : (eskiEmail.contains('@') ? eskiEmail.toLowerCase() : '');
      if (email.isEmpty || !email.contains('@')) {
        throw "Kullanıcı adı güncellenemedi. E-posta bilgisi eksik; yeniden giriş yap.";
      }

      tx.set(yeniRef, {
        "uid": uid,
        "kullaniciAdi": yeniKullaniciAdi,
        "email": email,
        "createdAt": FieldValue.serverTimestamp(),
      });

      if (eskiSnap != null &&
          eskiSnap.exists &&
          eskiSnap.data()?["uid"] == uid) {
        tx.delete(eskiRef);
      }
    });
  }

  // Kullanıcı engelini kaldırır
  static Future<void> engeliKaldir(String hedefUid) async {
    final current = FirebaseAuth.instance.currentUser;
    if (current == null) throw "Oturum bulunamadı.";

    final benimRef = SosyalCore.db.collection("users").doc(current.uid);
    final hedefRef = SosyalCore.db.collection("users").doc(hedefUid);

    final batch = SosyalCore.db.batch();
    batch.delete(benimRef.collection("blocked").doc(hedefUid));
    batch.delete(hedefRef.collection("blockedBy").doc(current.uid));
    await batch.commit();
  }

  // İki yönlü engel durumunu döndürür
  static Future<Map<String, bool>> engelDurumuGetir(String hedefUid) async {
    final current = FirebaseAuth.instance.currentUser;
    if (current == null) {
      return {"engelledim": false, "beniEngelledi": false};
    }

    final benimRef = SosyalCore.db
        .collection("users")
        .doc(current.uid)
        .collection("blocked")
        .doc(hedefUid)
        .get();
    final beniRef = SosyalCore.db
        .collection("users")
        .doc(current.uid)
        .collection("blockedBy")
        .doc(hedefUid)
        .get();
    final cift = await Future.wait([benimRef, beniRef]);
    final benimBlocked = cift[0];
    final beniBlocked = cift[1];

    return {
      "engelledim": benimBlocked.exists,
      "beniEngelledi": beniBlocked.exists,
    };
  }

  // Engellediğim kullanıcı id'lerini getirir
  static Future<Set<String>> engellenenKullanicilariGetir(String uid) async {
    final snap = await SosyalCore.db
        .collection("users")
        .doc(uid)
        .collection("blocked")
        .limit(200)
        .get();
    return snap.docs.map((d) => d.id).toSet();
  }

  // Beni engelleyen kullanıcı id'lerini getirir
  static Future<Set<String>> beniEngelleyenKullanicilariGetir(
      String uid) async {
    final snap = await SosyalCore.db
        .collection("users")
        .doc(uid)
        .collection("blockedBy")
        .limit(200)
        .get();
    return snap.docs.map((d) => d.id).toSet();
  }

  // Kullanıcı şikayeti oluşturur
  static Future<void> kullaniciSikayetEt({
    required String hedefUid,
    required String sebep,
    String aciklama = "",
  }) async {
    final current = FirebaseAuth.instance.currentUser;
    if (current == null) throw "Oturum bulunamadı.";
    if (current.uid == hedefUid) throw "Kendini şikayet edemezsin.";

    final raporId = "user_${current.uid}_$hedefUid";
    final raporRef = SosyalCore.db.collection("reports").doc(raporId);
    final onceki = await raporRef.get();
    if (onceki.exists) return; // Şikayet zaten kayıtlı

    await raporRef.set({
      "type": "user",
      "reporterUid": current.uid,
      "targetUid": hedefUid,
      "reason": sebep,
      "details": aciklama.trim(),
      "status": "pending",
      "createdAt": FieldValue.serverTimestamp(),
    });

    // Kullanıcı dokümanını üçüncü kişi güncellemesi rules tarafından
    // çoğunlukla engellendiği için burada sadece rapor kaydı oluşturuyoruz.
    // Moderatör panelindeki "İşlem Uygula" adımı kullanıcıyı gizler.
  }

  // Gönderi şikayeti oluşturur ve eşiği kontrol eder
  static Future<void> gonderiSikayetEt({
    required String postId,
    required String postOwnerId,
    required String sebep,
    String aciklama = "",
  }) async {
    final current = FirebaseAuth.instance.currentUser;
    if (current == null) throw "Oturum bulunamadı.";

    final raporId = "post_${current.uid}_$postId";
    final raporRef = SosyalCore.db.collection("reports").doc(raporId);
    final onceki = await raporRef.get();
    if (onceki.exists) return; // Şikayet zaten kayıtlı

    final postRef = SosyalCore.db.collection("posts").doc(postId);
    await SosyalCore.db.runTransaction((tx) async {
      final oncekiRapor = await tx.get(raporRef);
      if (oncekiRapor.exists) return;

      final snap = await tx.get(postRef);
      final mevcut = snap.data()?["sikayetSayisi"];
      final sayi =
          mevcut is int ? mevcut : (mevcut is num ? mevcut.toInt() : 0);
      final yeni = sayi + 1;
      tx.set(raporRef, {
        "type": "post",
        "reporterUid": current.uid,
        "postId": postId,
        "targetUid": postOwnerId,
        "reason": sebep,
        "details": aciklama.trim(),
        "status": "pending",
        "createdAt": FieldValue.serverTimestamp(),
      });
      tx.update(postRef, {
        "sikayetSayisi": yeni,
        "raporNedeniyleGizli": yeni >= SosyalCore.postRaporEsigi, // Eşikte gizle
        if (yeni >= SosyalCore.postRaporEsigi)
          "raporGuncellenmeTarihi": FieldValue.serverTimestamp(),
      });
    });
  }

  // Yorum şikayeti oluşturur ve eşiği kontrol eder
  static Future<void> yorumSikayetEt({
    required String postId,
    required String yorumId,
    required String yorumSahibiUid,
    required String sebep,
    String aciklama = "",
  }) async {
    final current = FirebaseAuth.instance.currentUser;
    if (current == null) throw "Oturum bulunamadı.";

    final raporId = "comment_${current.uid}_${postId}_$yorumId";
    final raporRef = SosyalCore.db.collection("reports").doc(raporId);
    final onceki = await raporRef.get();
    if (onceki.exists) return; // Şikayet zaten kayıtlı

    final yorumRef =
        SosyalCore.db.collection("posts").doc(postId).collection("comments").doc(yorumId);
    await SosyalCore.db.runTransaction((tx) async {
      final oncekiRapor = await tx.get(raporRef);
      if (oncekiRapor.exists) return;

      final snap = await tx.get(yorumRef);
      final mevcut = snap.data()?["sikayetSayisi"];
      final sayi =
          mevcut is int ? mevcut : (mevcut is num ? mevcut.toInt() : 0);
      final yeni = sayi + 1;
      tx.set(raporRef, {
        "type": "comment",
        "reporterUid": current.uid,
        "postId": postId,
        "commentId": yorumId,
        "targetUid": yorumSahibiUid,
        "reason": sebep,
        "details": aciklama.trim(),
        "status": "pending",
        "createdAt": FieldValue.serverTimestamp(),
      });
      tx.update(yorumRef, {
        "sikayetSayisi": yeni,
        "raporNedeniyleGizli": yeni >= SosyalCore.yorumRaporEsigi, // Eşikte gizle
        if (yeni >= SosyalCore.yorumRaporEsigi)
          "raporGuncellenmeTarihi": FieldValue.serverTimestamp(),
      });
    });
  }
}
