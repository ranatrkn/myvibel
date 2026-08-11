// Kullanıcı bildirimlerini oluşturma ve yönetme servisi
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:vibe_life/sosyal/sosyal_core.dart';

// Bildirim CRUD ve okunma durumu işlemleri
class BildirimServis {
  // Yeni bildirim kaydı ekler
  static Future<void> bildirimEkle({
    required String hedefUid,
    required String tip,
    required String gonderenUid,
    String? postId,
    String? chatId,
    String? metin,
    String? postMetin,
    bool postOzetiniAtla = false,
  }) async {
    if (hedefUid.isEmpty || gonderenUid.isEmpty || hedefUid == gonderenUid) {
      return; // Geçersiz veya kendi kendine bildirim atla
    }
    // Rules nedeniyle karşı tarafın blocked/blockedBy alt koleksiyonunu
    // okuyamayız; kontrolü sadece gönderen kullanıcının görünümünden yap.
    // Bu kontrol iki yönü de kapsar:
    // - gonderen -> blocked/{hedef}
    // - gonderen -> blockedBy/{hedef}
    if (await SosyalCore.engellendiMi(
        kaynakUid: gonderenUid, hedefUid: hedefUid)) {
      return; // Engel varsa bildirim gönderme
    }

    final gonderen = await SosyalCore.kullaniciVerisi(gonderenUid);
    final kullaniciAdi = gonderen?["kullaniciAdi"] ?? "Bir kullanıcı";

    String gonderiOzeti = postMetin ?? "";
    if (!postOzetiniAtla &&
        gonderiOzeti.trim().isEmpty &&
        postId != null &&
        postId.isNotEmpty) {
      // Gönderi metninden kısa özet oluştur
      final postDoc = await SosyalCore.db.collection("posts").doc(postId).get();
      final ham = postDoc.data()?["metin"]?.toString() ?? "";
      gonderiOzeti = ham.length > 60 ? "${ham.substring(0, 60)}..." : ham;
    }

    await SosyalCore.db
        .collection("users")
        .doc(hedefUid)
        .collection("notifications")
        .add({
      "tip": tip,
      "gonderenUid": gonderenUid,
      "gonderenKullaniciAdi": kullaniciAdi,
      "postId": postId ?? "",
      "chatId": chatId ?? "",
      "postMetin": gonderiOzeti,
      "metin": metin ?? "",
      "okundu": false,
      "createdAt": FieldValue.serverTimestamp(),
    });
  }

  // Tek bildirimi siler
  static Future<void> bildirimSil(String uid, String bildirimId) async {
    await SosyalCore.db
        .collection("users")
        .doc(uid)
        .collection("notifications")
        .doc(bildirimId)
        .delete();
  }

  // Belirli takip isteği bildirimlerini siler
  static Future<void> takipIstegiBildirimleriniSil(
    String hedefUid,
    String istekciUid,
  ) async {
    try {
      final snap = await SosyalCore.db
          .collection("users")
          .doc(hedefUid)
          .collection("notifications")
          .where("tip", isEqualTo: "follow_request")
          .get();

      for (final doc in snap.docs) {
        if ((doc.data()["gonderenUid"] ?? "").toString() != istekciUid) {
          continue; // Farklı gönderenleri atla
        }
        await doc.reference.delete();
      }
    } catch (e) {
      debugPrint("takipIstegiBildirimleriniSil failed: $e");
    }
  }

  // Bildirimi okundu olarak işaretler (belge yoksa sessizce atlar)
  static Future<void> bildirimOkunduYap(String uid, String bildirimId) async {
    if (uid.isEmpty || bildirimId.isEmpty) return;

    final ref = SosyalCore.db
        .collection("users")
        .doc(uid)
        .collection("notifications")
        .doc(bildirimId);
    final snap = await ref.get();
    if (!snap.exists) return;

    await ref.update({"okundu": true});
  }

  // Tüm okunmamış bildirimleri okundu yapar
  static Future<void> tumBildirimleriOkunduYap(String uid) async {
    final snap = await SosyalCore.db
        .collection("users")
        .doc(uid)
        .collection("notifications")
        .where("okundu", isEqualTo: false)
        .get();

    if (snap.docs.isEmpty) return;

    var batch = SosyalCore.db.batch();
    var sayac = 0;

    for (final doc in snap.docs) {
      batch.update(doc.reference, {"okundu": true});
      sayac++;
      if (sayac >= 400) {
        await batch.commit(); // Batch limitinde commit
        batch = SosyalCore.db.batch();
        sayac = 0;
      }
    }
    if (sayac > 0) await batch.commit();
  }

  // Okunmamış bildirim sayısı akışı
  static Stream<int> okunmamisBildirimSayisi(String uid) {
    return SosyalCore.db
        .collection("users")
        .doc(uid)
        .collection("notifications")
        .where("okundu", isEqualTo: false)
        .limit(100)
        .snapshots()
        .map(
          (snap) => snap.docs
              .where((doc) => (doc.data()["tip"] ?? "") != "message")
              .length,
        );
  }
}
