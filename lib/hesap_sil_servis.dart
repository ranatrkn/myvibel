// Hesap silme: Firestore ve Auth verilerini temizler.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'apple_giris_servis.dart';
import 'auth_eposta.dart';
import 'google_giris_servis.dart';
import 'kayit_servis.dart';
import 'sosyal_oauth.dart';

// Kullanıcı hesabını ve tüm ilişkili verileri siler
class HesapSilServis {
  // İlişkili kayıt hatası tüm silmeyi durdurmasın; profil/Auth silinmeli.
  static Future<void> _guvenliCalistir(Future<void> Function() islem) async {
    try {
      await islem();
    } catch (e, st) {
      debugPrint('hesap silme adımı atlandı: $e\n$st');
    }
  }

  static Future<void> _varsaSil(DocumentReference<Map<String, dynamic>> ref) async {
    final snap = await ref.get();
    if (snap.exists) {
      await ref.delete();
    }
  }

  // Alt koleksiyonu batch ile siler (400'lük gruplar)
  static Future<void> _altKoleksiyonuSil(
    CollectionReference<Map<String, dynamic>> koleksiyon,
  ) async {
    final snap = await koleksiyon.limit(400).get();
    if (snap.docs.isEmpty) return;

    var batch = FirebaseFirestore.instance.batch();
    var sayac = 0;

    for (final doc in snap.docs) {
      batch.delete(doc.reference);
      sayac++;
      if (sayac >= 400) {
        await batch.commit();
        batch = FirebaseFirestore.instance.batch();
        sayac = 0;
      }
    }
    if (sayac > 0) await batch.commit();

    if (snap.docs.length >= 400) {
      await _altKoleksiyonuSil(koleksiyon);
    }
  }

  // Beğeni kayıtlarını ve sayaçları günceller
  static Future<void> _begeniVerileriniSil(
    FirebaseFirestore firestore,
    DocumentReference<Map<String, dynamic>> userRef,
    String uid,
  ) async {
    final likedPosts = await userRef.collection("likedPosts").get();
    for (final liked in likedPosts.docs) {
      await _guvenliCalistir(() async {
        final postId = liked.id;
        final postRef = firestore.collection("posts").doc(postId);
        final likeRef = postRef.collection("likes").doc(uid);

        await firestore.runTransaction((tx) async {
          final likeSnap = await tx.get(likeRef);
          if (!likeSnap.exists) {
            tx.delete(liked.reference);
            return;
          }
          tx.delete(likeRef);
          tx.delete(liked.reference);
          tx.update(postRef, {
            "begeniSayisi": FieldValue.increment(-1),
            "skor": FieldValue.increment(-3),
          });
        });
      });
    }

    await _altKoleksiyonuSil(userRef.collection("likedPosts"));
  }

  static Future<void> _tekYorumuSil(
    FirebaseFirestore firestore,
    DocumentReference<Map<String, dynamic>> yorumRef,
  ) async {
    final postRef = yorumRef.parent.parent;
    if (postRef == null) return;

    await firestore.runTransaction((tx) async {
      final yorumSnap = await tx.get(yorumRef);
      if (!yorumSnap.exists) return;

      tx.delete(yorumRef);
      tx.update(postRef, {
        "yorumSayisi": FieldValue.increment(-1),
        "skor": FieldValue.increment(-5),
        "sonYorumId": yorumRef.id,
      });
    });
  }

  // Kullanıcının tüm yorumlarını siler
  static Future<void> _yorumlariSil(
    FirebaseFirestore firestore,
    String uid,
  ) async {
    try {
      final yorumlar = await firestore
          .collectionGroup("comments")
          .where("userId", isEqualTo: uid)
          .get();

      for (final yorum in yorumlar.docs) {
        await _guvenliCalistir(
          () => _tekYorumuSil(firestore, yorum.reference),
        );
      }
    } catch (_) {
      // Index yoksa başkalarının gönderilerindeki yorumlar orphan kalabilir;
      // kendi gönderilerindeki yorumlar _gonderilerimiSil ile silinir.
    }
  }

  // Kullanıcının gönderilerini ve alt verilerini siler
  static Future<void> _gonderilerimiSil(
    FirebaseFirestore firestore,
    String uid,
  ) async {
    final posts = await firestore
        .collection("posts")
        .where("userId", isEqualTo: uid)
        .get();

    for (final doc in posts.docs) {
      await _altKoleksiyonuSil(doc.reference.collection("likes"));
      await _altKoleksiyonuSil(doc.reference.collection("comments"));
      await doc.reference.delete();
    }
  }

  // DM sohbetlerini ve mesajları siler
  static Future<void> _sohbetleriSil(
    FirebaseFirestore firestore,
    String uid,
  ) async {
    final sohbetler = await firestore
        .collection("chats")
        .where("participants", arrayContains: uid)
        .get();

    for (final sohbet in sohbetler.docs) {
      await _altKoleksiyonuSil(sohbet.reference.collection("messages"));
      await sohbet.reference.delete();
    }
  }

  // Takipçi/takip edilen bağlantılarını kaldırır
  static Future<void> _takipBaglantilariniSil(
    FirebaseFirestore firestore,
    DocumentReference<Map<String, dynamic>> userRef,
    String uid,
  ) async {
    final followers = await userRef.collection("followers").get();
    for (final doc in followers.docs) {
      await _guvenliCalistir(() async {
        await firestore
            .collection("users")
            .doc(doc.id)
            .collection("following")
            .doc(uid)
            .delete();
        await doc.reference.delete();
      });
    }

    final following = await userRef.collection("following").get();
    for (final doc in following.docs) {
      await _guvenliCalistir(() async {
        await firestore
            .collection("users")
            .doc(doc.id)
            .collection("followers")
            .doc(uid)
            .delete();
        await doc.reference.delete();
      });
    }
  }

  // Engel kayıtlarını iki taraflı temizler
  static Future<void> _engellemeleriTemizle(
    FirebaseFirestore firestore,
    DocumentReference<Map<String, dynamic>> userRef,
    String uid,
  ) async {
    final blocked = await userRef.collection("blocked").get();
    for (final doc in blocked.docs) {
      await _guvenliCalistir(() async {
        await firestore
            .collection("users")
            .doc(doc.id)
            .collection("blockedBy")
            .doc(uid)
            .delete();
        await doc.reference.delete();
      });
    }

    final blockedBy = await userRef.collection("blockedBy").get();
    for (final doc in blockedBy.docs) {
      await _guvenliCalistir(() async {
        await firestore
            .collection("users")
            .doc(doc.id)
            .collection("blocked")
            .doc(uid)
            .delete();
        await doc.reference.delete();
      });
    }

    await _altKoleksiyonuSil(userRef.collection("blocked"));
    await _altKoleksiyonuSil(userRef.collection("blockedBy"));
  }

  static Future<void> _followRewardedTemizle(
    FirebaseFirestore firestore,
    DocumentReference<Map<String, dynamic>> userRef,
    String uid,
  ) async {
    await _altKoleksiyonuSil(userRef.collection("followRewarded"));

    try {
      final digerKayitlar = await firestore
          .collectionGroup("followRewarded")
          .where("targetUid", isEqualTo: uid)
          .get();

      for (final doc in digerKayitlar.docs) {
        await _guvenliCalistir(() => doc.reference.delete());
      }
    } catch (_) {
      // Index yoksa kendi alt koleksiyonu yeterli; diğerleri orphan kalabilir.
    }
  }

  static Future<void> _gidenTakipIstekleriniSil(
    FirebaseFirestore firestore,
    String uid,
  ) async {
    try {
      final gidenIstekler = await firestore
          .collectionGroup("followRequests")
          .where("userId", isEqualTo: uid)
          .get();

      for (final doc in gidenIstekler.docs) {
        await _guvenliCalistir(() => doc.reference.delete());
      }
    } catch (_) {
      // index yoksa atla
    }
  }

  static Future<void> _gonderdigimBildirimleriSil(
    FirebaseFirestore firestore,
    String uid,
  ) async {
    try {
      final bildirimler = await firestore
          .collectionGroup("notifications")
          .where("gonderenUid", isEqualTo: uid)
          .get();

      for (final doc in bildirimler.docs) {
        await _guvenliCalistir(() => doc.reference.delete());
      }
    } catch (_) {
      // index yoksa atla
    }
  }

  static Future<void> _raporlariSil(
    FirebaseFirestore firestore,
    String uid,
  ) async {
    Future<void> alanaGoreSil(String alan) async {
      try {
        final raporlar = await firestore
            .collection("reports")
            .where(alan, isEqualTo: uid)
            .get();
        for (final doc in raporlar.docs) {
          await _guvenliCalistir(() => doc.reference.delete());
        }
      } catch (e) {
        debugPrint('rapor silme ($alan) atlandı: $e');
      }
    }

    await alanaGoreSil("reporterUid");
    await alanaGoreSil("targetUid");
  }

  static Future<void> _retyBaglariniSil(
    FirebaseFirestore firestore,
    DocumentReference<Map<String, dynamic>> userRef,
    String uid,
  ) async {
    final baglar = await userRef.collection("retyBaglari").get();
    for (final doc in baglar.docs) {
      await _guvenliCalistir(() async {
        await firestore
            .collection("users")
            .doc(doc.id)
            .collection("retyBaglari")
            .doc(uid)
            .delete();
        await doc.reference.delete();
      });
    }
  }

  static Future<void> _destekTalepleriniSil(
    FirebaseFirestore firestore,
    String uid,
  ) async {
    final talepler = await firestore
        .collection("supportTickets")
        .where("userId", isEqualTo: uid)
        .get();
    for (final doc in talepler.docs) {
      await _guvenliCalistir(() => doc.reference.delete());
    }
  }

  static Future<void> _kullaniciAltKoleksiyonlariniSil(
    DocumentReference<Map<String, dynamic>> userRef,
  ) async {
    const altKoleksiyonlar = [
      "followers",
      "following",
      "followRequests",
      "notifications",
      "likedPosts",
      "blocked",
      "blockedBy",
      "followRewarded",
      "retyBaglari",
    ];

    for (final ad in altKoleksiyonlar) {
      await _altKoleksiyonuSil(userRef.collection(ad));
    }
  }

  /// Kullanıcı adı, hold, pending ve profil belgesi. Profil silinemezse hesap
  /// Auth'tan da silinmez — aksi halde sahipsiz hayalet profil kalır.
  static Future<void> _profilKimliginiSil(
    FirebaseFirestore firestore,
    DocumentReference<Map<String, dynamic>> userRef,
    String uid,
  ) async {
    final userDoc = await userRef.get();
    final kullaniciAdiKucuk =
        userDoc.data()?["kullaniciAdiKucuk"]?.toString() ?? "";
    if (kullaniciAdiKucuk.isNotEmpty) {
      await _guvenliCalistir(
        () => _varsaSil(firestore.collection("usernames").doc(kullaniciAdiKucuk)),
      );
      await _guvenliCalistir(
        () => _varsaSil(
          firestore.collection("usernameHolds").doc(kullaniciAdiKucuk),
        ),
      );
    }
    await _guvenliCalistir(
      () => _varsaSil(firestore.collection("pendingProfiles").doc(uid)),
    );
    if (userDoc.exists) {
      await userRef.delete();
    }
  }

  static const silmeNedenleri = [
    'Uygulamayı yeterince kullanmıyorum',
    'Vibel bakımı yorucu geldi',
    'Arkadaşlarımı burada bulamadım',
    'Bildirimler veya bakımı unutmak canımı sıktı',
    'Gizlilik endişem var',
    'Başka bir hesap açacağım',
    'Diğer...',
  ];

  static Future<void> silmeGeriBildirimiKaydet({
    required String neden,
    required String digerMetin,
    required String sorunMetin,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance
        .collection('hesapSilmeGeriBildirimleri')
        .add({
      'uid': user.uid,
      'neden': neden.trim(),
      'digerMetin': digerMetin.trim(),
      'sorunMetin': sorunMetin.trim(),
      'olusturmaMs': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Firestore verilerini ve Auth hesabını siler.
  /// Giriş ekranına yönlendirme [main.dart] içindeki auth dinleyicisiyle olur.
  static Future<void> hesabiSil({
    String? sifre,
    bool googleOnayiYapildi = false,
    bool appleOnayiYapildi = false,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception("Kullanıcı bulunamadı.");
    }

    final epostaHesabi = epostaSifreKullanicisiMi(user);
    final googleHesabi = GoogleGirisServis.googleKullanicisiMi(user);
    final appleHesabi = AppleGirisServis.appleKullanicisiMi(user);

    if (!epostaHesabi && !googleHesabi && !appleHesabi) {
      throw Exception("Bu hesap türü silinemiyor.");
    }

    if (epostaHesabi) {
      final email = FirebaseAuth.instance.currentUser?.email;
      if (email == null || email.isEmpty) {
        throw Exception("E-posta adresi bulunamadı.");
      }
      if (sifre == null || sifre.trim().isEmpty) {
        throw Exception("Şifre boş olamaz.");
      }
      await FirebaseAuth.instance.currentUser!.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: email, password: sifre.trim()),
      );
    } else if (googleHesabi && !googleOnayiYapildi) {
      await GoogleGirisServis.yenidenDogrula();
    } else if (appleHesabi && !appleOnayiYapildi) {
      await AppleGirisServis.yenidenDogrula();
    }

    final guncel = FirebaseAuth.instance.currentUser;
    if (guncel == null) {
      throw Exception("Oturum doğrulanamadı.");
    }

    final uid = guncel.uid;
    final firestore = FirebaseFirestore.instance;
    final userRef = firestore.collection("users").doc(uid);

    // Profil belgesi önce silinsin; aksi halde keşfet/liderlikte hayalet kalır.
    await _profilKimliginiSil(firestore, userRef, uid);
    await _guvenliCalistir(() => KayitServis.profilOnbelleginiTemizle(uid));

    await _guvenliCalistir(() => _begeniVerileriniSil(firestore, userRef, uid));
    await _guvenliCalistir(() => _yorumlariSil(firestore, uid));
    await _guvenliCalistir(() => _gonderilerimiSil(firestore, uid));
    await _guvenliCalistir(() => _sohbetleriSil(firestore, uid));
    await _guvenliCalistir(
      () => _takipBaglantilariniSil(firestore, userRef, uid),
    );
    await _guvenliCalistir(
      () => _engellemeleriTemizle(firestore, userRef, uid),
    );
    await _guvenliCalistir(
      () => _followRewardedTemizle(firestore, userRef, uid),
    );
    await _guvenliCalistir(() => _gidenTakipIstekleriniSil(firestore, uid));
    await _guvenliCalistir(() => _gonderdigimBildirimleriSil(firestore, uid));
    await _guvenliCalistir(() => _raporlariSil(firestore, uid));
    await _guvenliCalistir(() => _destekTalepleriniSil(firestore, uid));
    await _guvenliCalistir(() => _retyBaglariniSil(firestore, userRef, uid));
    await _guvenliCalistir(() => _kullaniciAltKoleksiyonlariniSil(userRef));

    try {
      await guncel.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        if (epostaHesabi) {
          final email = guncel.email;
          if (email == null || sifre == null || sifre.trim().isEmpty) rethrow;
          await guncel.reauthenticateWithCredential(
            EmailAuthProvider.credential(email: email, password: sifre.trim()),
          );
        } else if (appleHesabi || SosyalOAuth.appleMu(guncel)) {
          await AppleGirisServis.yenidenDogrula();
        } else {
          await GoogleGirisServis.yenidenDogrula(hesabiYenidenSec: false);
        }
        await FirebaseAuth.instance.currentUser?.delete();
      } else {
        rethrow;
      }
    }

    await GoogleGirisServis.googleOturumunuKapat();
  }
}
