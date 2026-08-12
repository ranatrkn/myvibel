// Gönderi beğeni, yorum ve silme işlemleri
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:vibe_life/haftalik_gorev_servis.dart';
import 'package:vibe_life/icerik_filtre_servis.dart';
import 'package:vibe_life/maskot_servis.dart';
import 'package:vibe_life/sosyal/bildirim_servis.dart';
import 'package:vibe_life/sosyal/etiket_servis.dart';
import 'package:vibe_life/sosyal/sosyal_core.dart';

// Beğeni ve yorum etkileşim servisi
class BegeniYorumServis {
  static int _sayacDeger(dynamic value, int varsayilan) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return varsayilan;
  }

  /// Gönderi silinince tüm kullanıcıların likedPosts kayıtlarını temizler.
  static Future<void> postBegeniKayitlariniTemizle(String postId) async {
    if (postId.isEmpty) return;

    try {
      final postRef = SosyalCore.db.collection('posts').doc(postId);
      final likeler = await postRef.collection('likes').get();
      if (likeler.docs.isEmpty) return;

      var batch = SosyalCore.db.batch();
      var sayac = 0;
      for (final likeDoc in likeler.docs) {
        final likerUid = likeDoc.id;
        final likedPostRef = SosyalCore.db
            .collection('users')
            .doc(likerUid)
            .collection('likedPosts')
            .doc(postId);
        batch.delete(likedPostRef);
        sayac++;
        if (sayac >= 400) {
          await batch.commit();
          batch = SosyalCore.db.batch();
          sayac = 0;
        }
      }
      if (sayac > 0) await batch.commit();
    } catch (e) {
      debugPrint('postBegeniKayitlariTemizle ($postId): $e');
    }
  }

  /// Artık var olmayan gönderilere ait likedPosts kayıtlarını siler.
  static Future<void> gecersizBegeniKayitlariniTemizle(String uid) async {
    final userRef = SosyalCore.db.collection('users').doc(uid);
    final likedSnap = await userRef.collection('likedPosts').get();
    if (likedSnap.docs.isEmpty) return;

    var batch = SosyalCore.db.batch();
    var sayac = 0;

    for (final liked in likedSnap.docs) {
      final postSnap =
          await SosyalCore.db.collection('posts').doc(liked.id).get();
      if (postSnap.exists) continue;

      batch.delete(liked.reference);
      sayac++;
      if (sayac >= 400) {
        await batch.commit();
        batch = SosyalCore.db.batch();
        sayac = 0;
      }
    }

    if (sayac > 0) await batch.commit();
  }

  /// Engellenen kullanıcının gönderilerine verilen beğenileri kaldırır.
  static Future<int> engellenenKullanicininBegenileriniKaldir({
    required String uid,
    required String hedefUid,
  }) async {
    if (uid.isEmpty || hedefUid.isEmpty || uid == hedefUid) return 0;

    final userRef = SosyalCore.db.collection('users').doc(uid);
    final kayitlar = await _engellenenKullanicininBegeniKayitlari(
      userRef,
      hedefUid,
    );
    if (kayitlar.isEmpty) return 0;

    var kaldirilan = 0;
    for (final liked in kayitlar) {
      final silindi = await _begeniSessizceKaldir(
        uid: uid,
        postId: liked.id,
        likedData: liked.data(),
      );
      if (silindi) kaldirilan++;
    }
    return kaldirilan;
  }

  /// Engellenen kullanıcının, engelleyenin gönderilerine verdiği beğenileri kaldırır.
  static Future<int> engelleneninGonderilerindekiBegenileriKaldir({
    required String ownerUid,
    required String likerUid,
  }) async {
    if (ownerUid.isEmpty || likerUid.isEmpty || ownerUid == likerUid) return 0;

    final posts = await SosyalCore.db
        .collection('posts')
        .where('userId', isEqualTo: ownerUid)
        .get();
    if (posts.docs.isEmpty) return 0;

    var kaldirilan = 0;
    for (final post in posts.docs) {
      final likeSnap =
          await post.reference.collection('likes').doc(likerUid).get();
      if (!likeSnap.exists) continue;

      final likedPostRef = SosyalCore.db
          .collection('users')
          .doc(likerUid)
          .collection('likedPosts')
          .doc(post.id);
      final likedSnap = await likedPostRef.get();
      final likedData = likedSnap.data() ??
          <String, dynamic>{
            'postOwnerId': ownerUid,
            'puanAlindi': true,
          };

      final silindi = await _begeniSessizceKaldir(
        uid: likerUid,
        postId: post.id,
        likedData: likedData,
      );
      if (silindi) kaldirilan++;
    }
    return kaldirilan;
  }

  static Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      _engellenenKullanicininBegeniKayitlari(
    DocumentReference<Map<String, dynamic>> userRef,
    String hedefUid,
  ) async {
    final bulunan = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};

    final sorgu = await userRef
        .collection('likedPosts')
        .where('postOwnerId', isEqualTo: hedefUid)
        .get();
    for (final doc in sorgu.docs) {
      bulunan[doc.id] = doc;
    }

    final tumu = await userRef.collection('likedPosts').get();
    for (final doc in tumu.docs) {
      if (bulunan.containsKey(doc.id)) continue;
      final owner = doc.data()['postOwnerId']?.toString() ?? '';
      if (owner == hedefUid) {
        bulunan[doc.id] = doc;
        continue;
      }
      if (owner.isNotEmpty) continue;

      final postSnap =
          await SosyalCore.db.collection('posts').doc(doc.id).get();
      if (postSnap.data()?['userId']?.toString() == hedefUid) {
        bulunan[doc.id] = doc;
      }
    }

    return bulunan.values.toList();
  }

  static Future<bool> _begeniSessizceKaldir({
    required String uid,
    required String postId,
    required Map<String, dynamic> likedData,
  }) async {
    if (postId.isEmpty || uid.isEmpty) return false;

    final postRef = SosyalCore.db.collection('posts').doc(postId);
    final likeRef = postRef.collection('likes').doc(uid);
    final likedPostRef =
        SosyalCore.db.collection('users').doc(uid).collection('likedPosts').doc(postId);
    final puanAlindi = likedData['puanAlindi'] == true;
    final postOwnerId = likedData['postOwnerId']?.toString() ?? '';
    final kendiGonderisi = SosyalCore.kendiGonderisiMi(
      postOwnerId: postOwnerId,
      currentUserId: uid,
    );

    var likeVardi = false;
    var likedPostVardi = false;
    try {
      await SosyalCore.db.runTransaction((tx) async {
        final likeSnap = await tx.get(likeRef);
        final likedPostSnap = await tx.get(likedPostRef);
        final postSnap = await tx.get(postRef);

        if (!likeSnap.exists && !likedPostSnap.exists) return;

        likeVardi = likeSnap.exists;
        likedPostVardi = likedPostSnap.exists;
        if (likeSnap.exists) tx.delete(likeRef);
        if (likedPostSnap.exists) tx.delete(likedPostRef);

        if (postSnap.exists && likeSnap.exists) {
          final postGuncelleme = <String, dynamic>{
            'begeniSayisi': FieldValue.increment(-1),
          };
          if (!kendiGonderisi) {
            postGuncelleme['skor'] = FieldValue.increment(-3);
          }
          tx.update(postRef, postGuncelleme);
        }
      });
    } catch (e) {
      debugPrint('engel begeni kaldir ($postId): $e');
      return false;
    }

    if (likeVardi && !kendiGonderisi) {
      try {
        await _begeniKullaniciGeriAlimi(
          uid: uid,
          postId: postId,
          puanAlindi: puanAlindi,
        );
      } catch (e) {
        debugPrint('engel begeni puan geri alimi ($postId): $e');
      }
    }

    return likeVardi || likedPostVardi;
  }

  /// Beğeni kaldırıldıktan sonra kullanıcı puan/sayaç geri alımı (ayrı yazım).
  static Future<void> _begeniKullaniciGeriAlimi({
    required String uid,
    required String postId,
    required bool puanAlindi,
  }) async {
    final userRef = SosyalCore.db.collection('users').doc(uid);
    await SosyalCore.db.runTransaction((transaction) async {
      final userSnap = await transaction.get(userRef);
      final data = userSnap.data() ?? <String, dynamic>{};
      final puanInt = data['puan'] is num ? (data['puan'] as num).toInt() : 0;
      final begeniInt = data['begeniSayisi'] is num
          ? (data['begeniSayisi'] as num).toInt()
          : 0;
      if (begeniInt <= 0) return;

      if (puanAlindi && puanInt >= 2) {
        transaction.update(userRef, {
          'puan': FieldValue.increment(-2),
          'begeniSayisi': FieldValue.increment(-1),
          'sonBegeniPuanPostId': postId,
        });
      } else {
        transaction.update(userRef, {
          'begeniSayisi': FieldValue.increment(-1),
          'sonBegeniPuanPostId': postId,
        });
      }
    });
  }

  // Beğeniyi ekler veya kaldırır
  static Future<bool> begeniDegistir({
    required String postId,
    required String postOwnerId,
    required String currentUserId,
  }) async {
    if (postId.isEmpty || currentUserId.isEmpty) {
      throw 'Geçersiz beğeni isteği.';
    }

    final postRef = SosyalCore.db.collection('posts').doc(postId);
    final postSnap = await postRef.get();
    if (!postSnap.exists) {
      throw 'Gönderi bulunamadı.';
    }

    final postData = postSnap.data() ?? {};
    final gercekOwnerId =
        postData['userId']?.toString().trim() ?? postOwnerId.trim();
    final kendiGonderisi = SosyalCore.kendiGonderisiMi(
      postOwnerId: gercekOwnerId,
      currentUserId: currentUserId,
    );

    final likeRef = postRef.collection('likes').doc(currentUserId);
    final likeSnap = await likeRef.get();

    if (!kendiGonderisi &&
        gercekOwnerId.isNotEmpty &&
        !likeSnap.exists &&
        await SosyalCore.engellendiMi(
            kaynakUid: currentUserId, hedefUid: gercekOwnerId)) {
      throw 'Bu kullanıcı ile etkileşim kuramazsın.';
    }

    if (!likeSnap.exists) {
      await SosyalCore.aksiyonHizLimitiKontrol(
        uid: currentUserId,
        aksiyon: 'begeni',
        minAralikMs: SosyalCore.begeniMinAralikMs,
        mesaj: 'Cok hizli begeni yapiyorsun. Lutfen biraz bekle.',
      );
      if (!kendiGonderisi) {
        await MascotServis.etkilesimEngelliyseAt(
          currentUserId,
          aksiyonTipi: 'begeni',
        );
      }
    }

    final userRef = SosyalCore.db.collection('users').doc(currentUserId);
    final likedPostRef = userRef.collection('likedPosts').doc(postId);

    var unlikePuanAlindi = false;
    if (likeSnap.exists) {
      final likedPostDoc = await likedPostRef.get();
      unlikePuanAlindi = likedPostDoc.data()?['puanAlindi'] == true;
    }

    final begenildi =
        await SosyalCore.db.runTransaction<bool>((transaction) async {
      final likeSnapshot = await transaction.get(likeRef);
      final likedPostSnapshot = await transaction.get(likedPostRef);
      final postSnapshot = await transaction.get(postRef);
      if (!postSnapshot.exists) {
        throw 'Gönderi bulunamadı.';
      }

      if (!likeSnapshot.exists && !kendiGonderisi) {
        final userSnapshot = await transaction.get(userRef);
        MascotServis.etkilesimEngeliVeriden(
          userSnapshot.data(),
          aksiyonTipi: 'begeni',
        );
      }

      if (likeSnapshot.exists) {
        transaction.delete(likeRef);
        if (likedPostSnapshot.exists) {
          transaction.delete(likedPostRef);
        }

        final postGuncelleme = <String, dynamic>{
          'begeniSayisi': FieldValue.increment(-1),
        };
        if (!kendiGonderisi) {
          postGuncelleme['skor'] = FieldValue.increment(-3);
        }
        transaction.update(postRef, postGuncelleme);
        return false;
      }

      final guncelPost = postSnapshot.data() ?? {};
      final mevcutBegeni = _sayacDeger(guncelPost['begeniSayisi'], 0);
      final mevcutYorum = _sayacDeger(guncelPost['yorumSayisi'], 0);
      transaction.set(likeRef, {
        'userId': currentUserId,
        'createdAt': FieldValue.serverTimestamp(),
      });
      transaction.set(likedPostRef, {
        'postId': postId,
        'postOwnerId': gercekOwnerId,
        'kullaniciAdi': guncelPost['kullaniciAdi'] ?? '',
        'metin': guncelPost['metin'] ?? '',
        'photoUrl': guncelPost['photoUrl'] ?? '',
        'avatarKey': guncelPost['avatarKey'] ?? '',
        'ownerHesapGizli': guncelPost['ownerHesapGizli'] == true,
        'raporNedeniyleGizli': guncelPost['raporNedeniyleGizli'] == true,
        'begeniSayisi': mevcutBegeni + 1,
        'yorumSayisi': mevcutYorum,
        'puanAlindi': !kendiGonderisi,
        'createdAt': FieldValue.serverTimestamp(),
      });

      final postGuncelleme = <String, dynamic>{
        'begeniSayisi': FieldValue.increment(1),
      };
      if (!kendiGonderisi) {
        postGuncelleme['skor'] = FieldValue.increment(3);
      }
      transaction.update(postRef, postGuncelleme);

      if (!kendiGonderisi) {
        transaction.update(userRef, {
          'puan': FieldValue.increment(2),
          'begeniSayisi': FieldValue.increment(1),
          'sonBegeniPuanPostId': postId,
        });
      }
      return true;
    });

    if (!begenildi && !kendiGonderisi) {
      try {
        await _begeniKullaniciGeriAlimi(
          uid: currentUserId,
          postId: postId,
          puanAlindi: unlikePuanAlindi,
        );
      } catch (e) {
        debugPrint('begeni kullanici geri alimi ($postId): $e');
      }
    }

    try {
      await SosyalCore.aksiyonHizLimitiKaydet(
          uid: currentUserId, aksiyon: 'begeni');
    } catch (e) {
      debugPrint('begeni hiz limiti kaydi: $e');
    }

    if (begenildi && !kendiGonderisi) {
      unawaited(MascotServis.sosyalOdulKaydet(currentUserId, MascotServis.vilBegeni));
    }

    if (begenildi &&
        gercekOwnerId.isNotEmpty &&
        gercekOwnerId != currentUserId) {
      try {
        await BildirimServis.bildirimEkle(
          hedefUid: gercekOwnerId,
          tip: 'like',
          gonderenUid: currentUserId,
          postId: postId,
          metin: 'gönderini beğendi',
          postOzetiniAtla: true,
        );
      } catch (e) {
        debugPrint('begeni bildirimi gonderilemedi: $e');
      }
    }

    if (begenildi && !kendiGonderisi) {
      unawaited(MascotServis.sosyalAksiyon(currentUserId, 'begeni'));
      unawaited(
        HaftalikGorevServis.aksiyonKaydet(currentUserId, GorevAksiyon.begeni)
            .then((sonuc) {
          if (!sonuc.basarili && sonuc.hata != null) {
            debugPrint('Görev beğeni kaydı: ${sonuc.hata}');
          }
        }),
      );
    }

    return begenildi;
  }

  // Gönderiye yorum ekler
  static Future<void> yorumEkle({
    required String postId,
    required String postOwnerId,
    required String currentUserId,
    required String metin,
  }) async {
    final kendiGonderisi = SosyalCore.kendiGonderisiMi(
      postOwnerId: postOwnerId,
      currentUserId: currentUserId,
    );

    if (!kendiGonderisi &&
        postOwnerId.isNotEmpty &&
        await SosyalCore.engellendiMi(
            kaynakUid: currentUserId, hedefUid: postOwnerId)) {
      throw 'Bu kullanıcı ile etkileşim kuramazsın.';
    }

    IcerikFiltreServis.uygunsuzsaAt(metin.trim());

    await SosyalCore.aksiyonHizLimitiKontrol(
      uid: currentUserId,
      aksiyon: 'yorum',
      minAralikMs: SosyalCore.yorumMinAralikMs,
      mesaj: 'Cok hizli yorum yapiyorsun. Lutfen biraz bekle.',
    );

    if (!kendiGonderisi) {
      await MascotServis.etkilesimEngelliyseAt(
        currentUserId,
        aksiyonTipi: 'yorum',
      );
    }

    final userDoc =
        await SosyalCore.db.collection('users').doc(currentUserId).get();
    final userData = userDoc.data() ?? {};
    final kullaniciAdi = userDoc.data()?['kullaniciAdi'] ?? 'Vibe Kullanıcısı';
    final photoUrl = (userData['photoUrl'] ?? '').toString();
    final avatarKey = (userData['avatarKey'] ?? '').toString();
    final mentionUidleri = await EtiketServis.bahsetmeUidleriniCoz(metin);

    final postRef = SosyalCore.db.collection('posts').doc(postId);
    final commentRef = postRef.collection('comments').doc();
    final userRef = SosyalCore.db.collection('users').doc(currentUserId);

    await SosyalCore.db.runTransaction((transaction) async {
      if (!kendiGonderisi) {
        final userSnapshot = await transaction.get(userRef);
        MascotServis.etkilesimEngeliVeriden(
          userSnapshot.data(),
          aksiyonTipi: 'yorum',
        );
      }

      transaction.set(commentRef, {
        'userId': currentUserId,
        'kullaniciAdi': kullaniciAdi,
        'photoUrl': photoUrl,
        'avatarKey': avatarKey,
        'metin': metin,
        'bahsetmeler': EtiketServis.bahsetmeleriAyikla(metin),
        'mentionUidleri': mentionUidleri,
        'sikayetSayisi': 0,
        'raporNedeniyleGizli': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      final postGuncelleme = <String, dynamic>{
        'yorumSayisi': FieldValue.increment(1),
        'sonYorumId': commentRef.id,
      };
      if (!kendiGonderisi) {
        postGuncelleme['skor'] = FieldValue.increment(5);
      }
      transaction.update(postRef, postGuncelleme);

      if (!kendiGonderisi) {
        transaction.update(userRef, {
          'puan': FieldValue.increment(3),
          'yorumSayisi': FieldValue.increment(1),
          'sonYorumPuanPostId': postId,
          'sonYorumPuanCommentId': commentRef.id,
        });
      }
    });

    await SosyalCore.aksiyonHizLimitiKaydet(
        uid: currentUserId, aksiyon: 'yorum');

    if (postOwnerId.isNotEmpty && postOwnerId != currentUserId) {
      await BildirimServis.bildirimEkle(
        hedefUid: postOwnerId,
        tip: 'comment',
        gonderenUid: currentUserId,
        postId: postId,
        metin: 'gönderine yorum yaptı',
      );
    }

    if (mentionUidleri.isNotEmpty) {
      await EtiketServis.bahsetmeBildirimleriGonder(
        gonderenUid: currentUserId,
        mentionUidleri: mentionUidleri,
        kaynak: 'comment',
        postId: postId,
      );
    }

    if (!kendiGonderisi) {
      unawaited(MascotServis.sosyalOdulKaydet(currentUserId, MascotServis.vilYorum));
      unawaited(MascotServis.sosyalAksiyon(currentUserId, 'yorum'));
      unawaited(
        HaftalikGorevServis.aksiyonKaydet(currentUserId, GorevAksiyon.yorum)
            .then((sonuc) {
          if (!sonuc.basarili && sonuc.hata != null) {
            debugPrint('Görev yorum kaydı: ${sonuc.hata}');
          }
        }),
      );
    }
  }

  // Kendi gönderisini ve alt koleksiyonlarını siler
  static Future<void> gonderiSil(String postId) async {
    final current = FirebaseAuth.instance.currentUser;
    if (current == null) throw 'Oturum bulunamadı.';

    final postRef = SosyalCore.db.collection('posts').doc(postId);
    final userRef = SosyalCore.db.collection('users').doc(current.uid);
    final postDoc = await postRef.get();
    if (!postDoc.exists) throw 'Gönderi bulunamadı.';
    if ((postDoc.data()?['userId'] ?? '') != current.uid) {
      throw 'Bu gönderiyi silemezsin.';
    }

    await postBegeniKayitlariniTemizle(postId);

    try {
      await SosyalCore.altKoleksiyonuSil(postRef.collection('likes'));
    } catch (e) {
      debugPrint('gonderiSil likes cleanup failed: $e');
    }
    try {
      await SosyalCore.altKoleksiyonuSil(postRef.collection('comments'));
    } catch (e) {
      debugPrint('gonderiSil comments cleanup failed: $e');
    }

    await SosyalCore.db.runTransaction((tx) async {
      final postSnap = await tx.get(postRef);
      if (!postSnap.exists) return;
      if ((postSnap.data()?['userId'] ?? '') != current.uid) {
        throw 'Bu gönderiyi silemezsin.';
      }

      final userSnap = await tx.get(userRef);
      final userData = userSnap.data() ?? <String, dynamic>{};
      final robotHam = userData['robot'];
      final mascot = MascotServis.tryParse(robotHam);
      if (mascot != null &&
          MascotServis.gonderiSilVilGerekir(mascot.seviye) &&
          !MascotServis.gonderiSilVilYeterli(mascot)) {
        throw 'Gönderi silmek için ${MascotServis.gonderiSilVilMaliyeti} vil gerekli.';
      }

      final mevcutPuan = userData['puan'];
      final puanInt = mevcutPuan is num ? mevcutPuan.toInt() : 0;
      final sonGonderiPuanPostId =
          userData['sonGonderiPuanPostId']?.toString() ?? '';
      final puanDusus =
          sonGonderiPuanPostId == postId ? (puanInt >= 10 ? 10 : puanInt) : 0;

      tx.delete(postRef);
      final userGuncelleme = <String, dynamic>{
        'gonderiSayisi': FieldValue.increment(-1),
        'sonGonderiPuanPostId': postId,
      };
      if (puanDusus > 0) {
        userGuncelleme['puan'] = FieldValue.increment(-puanDusus);
      }
      if (mascot != null && MascotServis.gonderiSilVilGerekir(mascot.seviye)) {
        final robot = MascotServis.gonderiSilIcinVilHarca(
          Map<String, dynamic>.from(
            robotHam is Map ? Map<String, dynamic>.from(robotHam) : <String, dynamic>{},
          ),
        );
        userGuncelleme['robot'] = robot;
      }
      tx.update(userRef, userGuncelleme);
    });
  }
}
