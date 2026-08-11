// Hesap silme: Firestore ve Auth verilerini temizler.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Kullanıcı hesabını ve tüm ilişkili verileri siler
class HesapSilServis {
  // Hata olsa bile silme akışını durdurmaz
  static Future<void> _guvenliCalistir(Future<void> Function() islem) async {
    try {
      await islem();
    } catch (_) {
      // Tek kayıt hatası tüm silmeyi durdurmasın.
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
      await _yorumlariSilIndexesiz(firestore, uid);
    }
  }

  static Future<void> _yorumlariSilIndexesiz(
    FirebaseFirestore firestore,
    String uid,
  ) async {
    DocumentSnapshot<Map<String, dynamic>>? sonPost;

    while (true) {
      Query<Map<String, dynamic>> sorgu = firestore
          .collection("posts")
          .orderBy(FieldPath.documentId)
          .limit(100);

      if (sonPost != null) {
        sorgu = sorgu.startAfterDocument(sonPost);
      }

      final postlar = await sorgu.get();
      if (postlar.docs.isEmpty) break;
      sonPost = postlar.docs.last;

      for (final post in postlar.docs) {
        final yorumlar = await post.reference
            .collection("comments")
            .where("userId", isEqualTo: uid)
            .get();

        for (final yorum in yorumlar.docs) {
          await _guvenliCalistir(
            () => _tekYorumuSil(firestore, yorum.reference),
          );
        }
      }
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
      await _guvenliCalistir(() async {
        await _altKoleksiyonuSil(sohbet.reference.collection("messages"));
        await sohbet.reference.delete();
      });
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

  static Future<void> _raporlarimiSil(
    FirebaseFirestore firestore,
    String uid,
  ) async {
    try {
      final raporlar = await firestore
          .collection("reports")
          .where("reporterUid", isEqualTo: uid)
          .get();

      for (final doc in raporlar.docs) {
        await _guvenliCalistir(() => doc.reference.delete());
      }
    } catch (_) {
      // index yoksa atla
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
    ];

    for (final ad in altKoleksiyonlar) {
      await _altKoleksiyonuSil(userRef.collection(ad));
    }
  }

  /// Firestore verilerini ve Auth hesabını siler.
  /// Giriş ekranına yönlendirme [main.dart] içindeki auth dinleyicisiyle olur.
  static Future<void> hesabiSil(String sifre) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception("Kullanıcı bulunamadı.");
    }

    final email = user.email;
    if (email == null || email.isEmpty) {
      throw Exception("E-posta adresi bulunamadı.");
    }

    final credential = EmailAuthProvider.credential(
      email: email,
      password: sifre,
    );

    await user.reauthenticateWithCredential(credential);

    final uid = user.uid;
    final firestore = FirebaseFirestore.instance;
    final userRef = firestore.collection("users").doc(uid);

    await _begeniVerileriniSil(firestore, userRef, uid);
    await _yorumlariSil(firestore, uid);
    await _gonderilerimiSil(firestore, uid);
    await _sohbetleriSil(firestore, uid);
    await _takipBaglantilariniSil(firestore, userRef, uid);
    await _engellemeleriTemizle(firestore, userRef, uid);
    await _followRewardedTemizle(firestore, userRef, uid);
    await _gidenTakipIstekleriniSil(firestore, uid);
    await _gonderdigimBildirimleriSil(firestore, uid);
    await _raporlarimiSil(firestore, uid);
    await _kullaniciAltKoleksiyonlariniSil(userRef);

    final userDoc = await userRef.get();
    final kullaniciAdiKucuk =
        userDoc.data()?["kullaniciAdiKucuk"]?.toString() ?? "";
    if (kullaniciAdiKucuk.isNotEmpty) {
      await firestore.collection("usernames").doc(kullaniciAdiKucuk).delete();
    }

    await userRef.delete();
    await user.delete();
  }
}
