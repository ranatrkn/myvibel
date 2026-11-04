// Gönderi beğeni, yorum ve silme işlemleri
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:myvibel/haftalik_gorev_servis.dart';
import 'package:myvibel/icerik_filtre_servis.dart';
import 'package:myvibel/maskot_servis.dart';
import 'package:myvibel/sosyal/bildirim_servis.dart';
import 'package:myvibel/sosyal/etiket_servis.dart';
import 'package:myvibel/sosyal/sosyal_core.dart';
import 'package:myvibel/widgets/vibe_avatar.dart';

class BegenenKayit {
  final String userId;
  final String kullaniciAdi;
  final String adSoyad;
  final String photoUrl;
  final String avatarKey;

  const BegenenKayit({
    required this.userId,
    required this.kullaniciAdi,
    required this.adSoyad,
    required this.photoUrl,
    required this.avatarKey,
  });
}

/// Gönderi başına tek seferlik beğeni ödülü ve geri çekme ücreti durumu.
class BegeniOdulDurumu {
  final bool odulAlindi;
  final bool geriAlindi;

  const BegeniOdulDurumu({required this.odulAlindi, required this.geriAlindi});
}

class BegenenSayfa {
  final List<BegenenKayit> kayitlar;
  final DocumentSnapshot<Map<String, dynamic>>? sonBelge;
  final bool devamVar;

  const BegenenSayfa({
    required this.kayitlar,
    required this.sonBelge,
    required this.devamVar,
  });
}

// Beğeni ve yorum etkileşim servisi
class BegeniYorumServis {
  static const begenenSayfaBoyutu = 30;
  static final Map<String, BegeniOdulDurumu> _odulOnbellek = {};

  static Future<DocumentSnapshot<Map<String, dynamic>>> _onbellektenOku(
    DocumentReference<Map<String, dynamic>> ref,
  ) async {
    try {
      final snap = await ref.get(const GetOptions(source: Source.cache));
      if (snap.exists) return snap;
    } catch (_) {}
    return ref.get();
  }

  static String _odulAnahtar(String uid, String postId) => '$uid|$postId';

  static DocumentReference<Map<String, dynamic>> _begeniOdulRef(
    String uid,
    String postId,
  ) =>
      SosyalCore.db
          .collection('users')
          .doc(uid)
          .collection('begeniOdulleri')
          .doc(postId);

  static BegeniOdulDurumu? begeniOdulDurumuOnbellek({
    required String uid,
    required String postId,
  }) =>
      _odulOnbellek[_odulAnahtar(uid, postId)];

  static Future<BegeniOdulDurumu> begeniOdulDurumu({
    required String uid,
    required String postId,
  }) async {
    final onbellek = _odulOnbellek[_odulAnahtar(uid, postId)];
    if (onbellek != null) return onbellek;
    final snap = await _begeniOdulRef(uid, postId).get();
    final durum = BegeniOdulDurumu(
      odulAlindi: snap.exists,
      geriAlindi: snap.data()?['geriAlindi'] == true,
    );
    _odulOnbellek[_odulAnahtar(uid, postId)] = durum;
    return durum;
  }

  /// Gönderi silinince tüm kullanıcıların likedPosts kayıtlarını temizler.
  static Future<void> postBegeniKayitlariniTemizle(String postId) async {
    if (postId.isEmpty) return;

    try {
      final postRef = SosyalCore.gonderiRef(postId);
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

  /// Artık var olmayan veya erişilemeyen gönderilere ait likedPosts kayıtlarını siler.
  static Future<void> gecersizBegeniKayitlariniTemizle(String uid) async {
    if (uid.isEmpty) return;
    final userRef = SosyalCore.db.collection('users').doc(uid);
    final likedSnap = await userRef.collection('likedPosts').get();
    if (likedSnap.docs.isEmpty) return;

    var batch = SosyalCore.db.batch();
    var sayac = 0;

    for (final liked in likedSnap.docs) {
      final sil = await _begeniKaydiSilinmeliMi(liked.id);
      if (!sil) continue;

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

  /// Tek bir erişilemeyen beğeni kaydını kaldırır.
  static Future<void> erisilemeyenBegeniKaydiniSil({
    required String uid,
    required String postId,
  }) async {
    if (uid.isEmpty || postId.isEmpty) return;
    if (!await _begeniKaydiSilinmeliMi(postId)) return;

    try {
      await SosyalCore.db
          .collection('users')
          .doc(uid)
          .collection('likedPosts')
          .doc(postId)
          .delete();
    } catch (e) {
      debugPrint('erisilemeyenBegeniKaydiniSil ($postId): $e');
    }
  }

  static Future<bool> _begeniKaydiSilinmeliMi(String postId) async {
    try {
      final postSnap = await SosyalCore.gonderiRef(postId).get();
      return !postSnap.exists;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') return true;
      rethrow;
    }
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
          await SosyalCore.gonderiRef(doc.id).get();
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

    final postRef = SosyalCore.gonderiRef(postId);
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
          vilZorunlu: false,
        );
      } catch (e) {
        debugPrint('engel begeni puan geri alimi ($postId): $e');
      }
    }

    return likeVardi || likedPostVardi;
  }

  /// Beğeni kaldırıldıktan sonra kullanıcı puan/sayaç/vil geri alımı (ayrı yazım).
  static Future<void> _begeniKullaniciGeriAlimi({
    required String uid,
    required String postId,
    required bool puanAlindi,
    bool vilZorunlu = true,
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

      final guncelleme = <String, dynamic>{
        'begeniSayisi': FieldValue.increment(-1),
        'sonBegeniPuanPostId': postId,
      };
      if (puanAlindi && puanInt >= 2) {
        guncelleme['puan'] = FieldValue.increment(-2);
      }
      if (puanAlindi) {
        MascotServis.sosyalGeriAlVilEkle(
          guncelleme: guncelleme,
          robotHam: data['robot'],
          maliyet: MascotServis.sosyalGeriAlVilMaliyeti,
          yetersizMesaji: MascotServis.sosyalGeriAlVilYetersizMesaji(
            'Beğeniyi geri çekmek',
            MascotServis.sosyalGeriAlVilMaliyeti,
          ),
          zorunlu: vilZorunlu,
        );
      }
      transaction.update(userRef, guncelleme);
    });
  }

  // Beğeniyi ekler veya kaldırır
  static Future<bool> begeniDegistir({
    required String postId,
    required String postOwnerId,
    required String currentUserId,
    required bool begen,
  }) async {
    if (postId.isEmpty || currentUserId.isEmpty) {
      throw 'Geçersiz beğeni isteği.';
    }

    final postRef = SosyalCore.gonderiRef(postId);
    final gercekOwnerId = postOwnerId.trim();
    final kendiGonderisi = SosyalCore.kendiGonderisiMi(
      postOwnerId: gercekOwnerId,
      currentUserId: currentUserId,
    );

    final likeRef = postRef.collection('likes').doc(currentUserId);
    final userRef = SosyalCore.db.collection('users').doc(currentUserId);
    final likedPostRef = userRef.collection('likedPosts').doc(postId);
    final odulRef = _begeniOdulRef(currentUserId, postId);
    final begenildi = begen;

    final durumlar = await Future.wait<Object?>([
      likeRef.get(),
      likedPostRef.get(),
      kendiGonderisi
          ? Future<Object?>.value(null)
          : begeniOdulDurumu(uid: currentUserId, postId: postId),
    ]);
    final likeVar = (durumlar[0] as DocumentSnapshot).exists;
    final likedPostVar = (durumlar[1] as DocumentSnapshot).exists;
    final odulDurumu = durumlar[2] as BegeniOdulDurumu?;

    // Sayaçlar sıfırlanınca likes silinip likedPosts kalabiliyor; set update sayılır.
    if (!likeVar && likedPostVar) {
      await likedPostRef.delete();
    }
    if (begenildi && likeVar) return true;
    if (!begenildi && !likeVar) return false;

    final odulVerilecek =
        begenildi && !kendiGonderisi && !(odulDurumu?.odulAlindi ?? false);
    final geriAlimUcretli =
        !begenildi && !kendiGonderisi && !(odulDurumu?.geriAlindi ?? false);

    if (geriAlimUcretli) {
      await MascotServis.sosyalGeriAlVilOnKontrol(
        uid: currentUserId,
        maliyet: MascotServis.sosyalGeriAlVilMaliyeti,
        yetersizMesaji: MascotServis.sosyalGeriAlVilYetersizMesaji(
          'Beğeniyi geri çekmek',
          MascotServis.sosyalGeriAlVilMaliyeti,
        ),
      );
    }

    final batch = SosyalCore.db.batch();
    if (begenildi) {
      batch.set(likeRef, {
        'userId': currentUserId,
        'createdAt': FieldValue.serverTimestamp(),
      });
      batch.set(likedPostRef, {
        'postId': postId,
        'postOwnerId': gercekOwnerId,
        'puanAlindi': odulVerilecek,
        'createdAt': FieldValue.serverTimestamp(),
      });
      final postGuncelleme = <String, dynamic>{
        'begeniSayisi': FieldValue.increment(1),
      };
      if (!kendiGonderisi) {
        postGuncelleme['skor'] = FieldValue.increment(3);
      }
      batch.update(postRef, postGuncelleme);
      if (odulVerilecek) {
        batch.set(odulRef, {
          'geriAlindi': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
        batch.update(userRef, {
          'puan': FieldValue.increment(2),
          'begeniSayisi': FieldValue.increment(1),
          'sonBegeniPuanPostId': postId,
        });
      } else if (!kendiGonderisi) {
        batch.update(userRef, {
          'begeniSayisi': FieldValue.increment(1),
          'sonBegeniPuanPostId': postId,
        });
      }
    } else {
      batch.delete(likeRef);
      batch.delete(likedPostRef);
      final postGuncelleme = <String, dynamic>{
        'begeniSayisi': FieldValue.increment(-1),
      };
      if (!kendiGonderisi) {
        postGuncelleme['skor'] = FieldValue.increment(-3);
      }
      batch.update(postRef, postGuncelleme);
      if (geriAlimUcretli) {
        if (odulDurumu?.odulAlindi ?? false) {
          batch.update(odulRef, {
            'geriAlindi': true,
            'guncellendi': FieldValue.serverTimestamp(),
          });
        } else {
          batch.set(odulRef, {
            'geriAlindi': true,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }
    }
    await batch.commit();

    if (odulVerilecek) {
      _odulOnbellek[_odulAnahtar(currentUserId, postId)] =
          const BegeniOdulDurumu(odulAlindi: true, geriAlindi: false);
    } else if (geriAlimUcretli) {
      _odulOnbellek[_odulAnahtar(currentUserId, postId)] =
          const BegeniOdulDurumu(odulAlindi: true, geriAlindi: true);
    }

    if (odulVerilecek) {
      try {
        await MascotServis.sosyalOdulKaydet(
          currentUserId,
          MascotServis.vilBegeni,
        );
      } catch (e) {
        debugPrint('begeni maskot odul: $e');
      }
    }

    if (!begenildi && !kendiGonderisi) {
      try {
        await _begeniKullaniciGeriAlimi(
          uid: currentUserId,
          postId: postId,
          puanAlindi: geriAlimUcretli,
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
        );
      } catch (e) {
        debugPrint('begeni bildirimi gonderilemedi: $e');
      }
    }

    if (begenildi && !kendiGonderisi) {
      unawaited(MascotServis.sosyalAksiyon(currentUserId, 'begeni'));
    }
    if (odulVerilecek) {
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

  // Gönderiye yorum veya yanıt ekler
  static Future<void> yorumEkle({
    required String postId,
    required String postOwnerId,
    required String currentUserId,
    required String metin,
    String? parentId,
  }) async {
    final kendiGonderisi = SosyalCore.kendiGonderisiMi(
      postOwnerId: postOwnerId,
      currentUserId: currentUserId,
    );

    IcerikFiltreServis.uygunsuzsaAt(metin.trim());

    await SosyalCore.aksiyonHizLimitiKontrol(
      uid: currentUserId,
      aksiyon: 'yorum',
      minAralikMs: SosyalCore.yorumMinAralikMs,
      mesaj: 'Cok hizli yorum yapiyorsun. Lutfen biraz bekle.',
    );

    final postRef = SosyalCore.gonderiRef(postId);
    final commentRef = postRef.collection('comments').doc();
    final userRef = SosyalCore.db.collection('users').doc(currentUserId);
    final istenenParentId = (parentId ?? '').trim();

    // Okumalar paralel: sıralı beklemek yorumu ~3 sn geciktiriyordu.
    final onOkumalar = await Future.wait<Object?>([
      !kendiGonderisi && postOwnerId.isNotEmpty
          ? SosyalCore.engellendiMi(
              kaynakUid: currentUserId, hedefUid: postOwnerId)
          : Future<Object?>.value(false),
      _onbellektenOku(userRef),
      EtiketServis.bahsetmeUidleriniCoz(metin),
      istenenParentId.isNotEmpty
          ? postRef.collection('comments').doc(istenenParentId).get()
          : Future<Object?>.value(null),
    ]);
    if (onOkumalar[0] == true) {
      throw 'Bu kullanıcı ile etkileşim kuramazsın.';
    }
    final userData =
        (onOkumalar[1] as DocumentSnapshot<Map<String, dynamic>>).data() ??
            <String, dynamic>{};
    if (!kendiGonderisi) {
      MascotServis.etkilesimEngeliVeriden(userData, aksiyonTipi: 'yorum');
    }
    final kullaniciAdi = userData['kullaniciAdi'] ?? 'Vibe Kullanıcısı';
    final avatarKey = (userData['avatarKey'] ?? '').toString();
    final photoUrl = vibeDenormalizePhotoUrl(
      avatarKey: avatarKey,
      photoUrl: userData['photoUrl']?.toString(),
    );
    final mentionUidleri = onOkumalar[2] as Map<String, String>;

    String? kokParentId;
    String? yanitUserId;
    String? yanitKullaniciAdi;
    if (istenenParentId.isNotEmpty) {
      final parentSnap =
          onOkumalar[3] as DocumentSnapshot<Map<String, dynamic>>;
      if (!parentSnap.exists) {
        throw 'Yanıtlanacak yorum bulunamadı.';
      }
      final parentData = parentSnap.data() ?? {};
      kokParentId = parentSnap.id;
      yanitUserId = (parentData['userId'] ?? '').toString();
      yanitKullaniciAdi = (parentData['kullaniciAdi'] ?? '').toString();
    }

    final batch = SosyalCore.db.batch();
    if (!kendiGonderisi) {
      batch.update(userRef, {
        'puan': FieldValue.increment(3),
        'yorumSayisi': FieldValue.increment(1),
        'sonYorumPuanPostId': postId,
        'sonYorumPuanCommentId': commentRef.id,
      });
    }

    final yorumVerisi = <String, dynamic>{
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
    };
    if (kokParentId != null && kokParentId.isNotEmpty) {
      yorumVerisi['parentId'] = kokParentId;
      yorumVerisi['yanitUserId'] = yanitUserId ?? '';
      yorumVerisi['yanitKullaniciAdi'] = yanitKullaniciAdi ?? '';
    }
    batch.set(commentRef, yorumVerisi);

    final postGuncelleme = <String, dynamic>{
      'yorumSayisi': FieldValue.increment(1),
      'sonYorumId': commentRef.id,
    };
    if (!kendiGonderisi) {
      postGuncelleme['skor'] = FieldValue.increment(5);
    }
    batch.update(postRef, postGuncelleme);
    await batch.commit();

    if (!kendiGonderisi) {
      try {
        await MascotServis.sosyalOdulKaydet(
          currentUserId,
          MascotServis.vilYorum,
        );
      } catch (e) {
        debugPrint('yorum maskot odul: $e');
      }
    }

    await SosyalCore.aksiyonHizLimitiKaydet(
        uid: currentUserId, aksiyon: 'yorum');

    if (yanitUserId != null &&
        yanitUserId.isNotEmpty &&
        yanitUserId != currentUserId) {
      await BildirimServis.bildirimEkle(
        hedefUid: yanitUserId,
        tip: 'comment_reply',
        gonderenUid: currentUserId,
        postId: postId,
        metin: 'yorumuna yanıt verdi',
        yorumMetin: metin,
      );
    }

    if (postOwnerId.isNotEmpty &&
        postOwnerId != currentUserId &&
        postOwnerId != yanitUserId) {
      await BildirimServis.bildirimEkle(
        hedefUid: postOwnerId,
        tip: 'comment',
        gonderenUid: currentUserId,
        postId: postId,
        metin: 'gönderine yorum yaptı',
        yorumMetin: metin,
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

  // Yorumu siler: yorum sahibi veya gönderi sahibi.
  static Future<void> yorumSil({
    required String postId,
    required String commentId,
  }) async {
    final current = FirebaseAuth.instance.currentUser;
    if (current == null) throw 'Oturum bulunamadı.';
    if (postId.isEmpty || commentId.isEmpty) throw 'Geçersiz yorum.';

    final postRef = SosyalCore.gonderiRef(postId);
    final commentRef = postRef.collection('comments').doc(commentId);
    final userRef = SosyalCore.db.collection('users').doc(current.uid);

    final commentSnap = await commentRef.get();
    if (!commentSnap.exists) throw 'Yorum bulunamadı.';
    final yorumSahibiId = (commentSnap.data()?['userId'] ?? '').toString();
    final kendiYorumu = yorumSahibiId == current.uid;

    final postSnap = await postRef.get();
    if (!postSnap.exists) throw 'Gönderi bulunamadı.';
    final postOwnerId = (postSnap.data()?['userId'] ?? '').toString();
    final gonderiSahibi = postOwnerId.isNotEmpty && postOwnerId == current.uid;
    if (!kendiYorumu && !gonderiSahibi) {
      throw 'Bu yorumu silemezsin.';
    }

    final odulAlindi = kendiYorumu && postOwnerId.isNotEmpty && postOwnerId != current.uid;
    final kokMu = (commentSnap.data()?['parentId'] ?? '').toString().trim().isEmpty;

    var yanitDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    if (kokMu) {
      final yanitSnap = await postRef
          .collection('comments')
          .where('parentId', isEqualTo: commentId)
          .limit(40)
          .get();
      yanitDocs = yanitSnap.docs;
    }

    if (odulAlindi) {
      await MascotServis.sosyalGeriAlVilOnKontrol(
        uid: current.uid,
        maliyet: MascotServis.sosyalGeriAlVilMaliyeti,
        yetersizMesaji: MascotServis.sosyalGeriAlVilYetersizMesaji(
          'Yorum silmek',
          MascotServis.sosyalGeriAlVilMaliyeti,
        ),
      );
    }

    Future<void> yorumSilTxn({required bool kullaniciOdulGeriAl}) async {
      await SosyalCore.db.runTransaction((tx) async {
        final yorumSnap = await tx.get(commentRef);
        if (!yorumSnap.exists) return;
        final yorumUid = (yorumSnap.data()?['userId'] ?? '').toString();

        final gonderiSnap = await tx.get(postRef);
        if (!gonderiSnap.exists) throw 'Gönderi bulunamadı.';
        final ownerId = (gonderiSnap.data()?['userId'] ?? '').toString();
        final sahibiMi = ownerId.isNotEmpty && ownerId == current.uid;
        if (yorumUid != current.uid && !sahibiMi) {
          throw 'Bu yorumu silemezsin.';
        }

        final yanitSnaps = <DocumentSnapshot<Map<String, dynamic>>>[];
        for (final yanit in yanitDocs) {
          yanitSnaps.add(await tx.get(yanit.reference));
        }

        Map<String, dynamic> userData = const {};
        if (kullaniciOdulGeriAl && odulAlindi) {
          final userSnap = await tx.get(userRef);
          userData = userSnap.data() ?? <String, dynamic>{};
        }

        var silinen = 0;
        var skorAdet = 0;
        void sil(DocumentSnapshot<Map<String, dynamic>> snap) {
          if (!snap.exists) return;
          final uid = (snap.data()?['userId'] ?? '').toString();
          tx.delete(snap.reference);
          silinen += 1;
          if (ownerId.isEmpty || uid != ownerId) {
            skorAdet += 1;
          }
        }

        sil(yorumSnap);
        for (final yanitSnap in yanitSnaps) {
          sil(yanitSnap);
        }
        if (silinen <= 0) return;

        final postGuncelleme = <String, dynamic>{
          'yorumSayisi': FieldValue.increment(-silinen),
          'sonYorumId': commentId,
        };
        if (skorAdet > 0) {
          postGuncelleme['skor'] = FieldValue.increment(-5 * skorAdet);
        }
        tx.update(postRef, postGuncelleme);

        if (!kullaniciOdulGeriAl || !odulAlindi) return;

        final puanInt =
            userData['puan'] is num ? (userData['puan'] as num).toInt() : 0;
        final yorumInt = userData['yorumSayisi'] is num
            ? (userData['yorumSayisi'] as num).toInt()
            : 0;
        if (yorumInt <= 0) return;

        final guncelleme = <String, dynamic>{
          'yorumSayisi': FieldValue.increment(-1),
          'sonYorumPuanPostId': postId,
          'sonYorumPuanCommentId': commentId,
        };
        if (puanInt >= 3) {
          guncelleme['puan'] = FieldValue.increment(-3);
        }
        MascotServis.sosyalGeriAlVilEkle(
          guncelleme: guncelleme,
          robotHam: userData['robot'],
          maliyet: MascotServis.sosyalGeriAlVilMaliyeti,
          yetersizMesaji: MascotServis.sosyalGeriAlVilYetersizMesaji(
            'Yorum silmek',
            MascotServis.sosyalGeriAlVilMaliyeti,
          ),
        );
        tx.update(userRef, guncelleme);
      });
    }

    try {
      await yorumSilTxn(kullaniciOdulGeriAl: true);
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') rethrow;
      // Vil/puan geri alma takılırsa yorum yine silinsin.
      debugPrint('yorumSil odul geri al permission-denied, yalin silme: $e');
      await yorumSilTxn(kullaniciOdulGeriAl: false);
    }
  }

  // Kendi gönderisini, beğenileri ve yorumları aynı işlemde siler.
  static Future<void> gonderiSil(String postId) async {
    final current = FirebaseAuth.instance.currentUser;
    if (current == null) throw 'Oturum bulunamadı.';

    final postRef = SosyalCore.gonderiRef(postId);
    final userRef = SosyalCore.db.collection('users').doc(current.uid);
    final postDoc = await postRef.get();
    if (!postDoc.exists) throw 'Gönderi bulunamadı.';
    if ((postDoc.data()?['userId'] ?? '') != current.uid) {
      throw 'Bu gönderiyi silemezsin.';
    }

    final onKontrolUser = await userRef.get();
    final onRobot = onKontrolUser.data()?['robot'];
    final onMascot = MascotServis.tryParse(onRobot);
    if (onMascot != null &&
        MascotServis.gonderiSilVilGerekir(onMascot.seviye) &&
        !MascotServis.gonderiSilVilYeterli(onMascot)) {
      throw 'Gönderi silmek için ${MascotServis.gonderiSilVilMaliyeti} vil gerekli.';
    }

    final likeSnap = await postRef.collection('likes').get();
    final commentSnap = await postRef.collection('comments').get();
    final likeRefs = likeSnap.docs.map((d) => d.reference).toList();
    final commentRefs = commentSnap.docs.map((d) => d.reference).toList();
    final baskaBegenenler = likeSnap.docs
        .map((d) => d.id)
        .where((uid) => uid.isNotEmpty && uid != current.uid)
        .toList();

    // Firestore işlem limiti ~500 yazma.
    if (likeRefs.length + commentRefs.length + 3 > 490) {
      throw 'Bu gönderide çok fazla etkileşim var, şu an silinemedi.';
    }

    Future<void> gonderiSilTxn({required bool kullaniciGuncelle}) async {
      await SosyalCore.db.runTransaction((tx) async {
        final postSnap = await tx.get(postRef);
        if (!postSnap.exists) return;
        if ((postSnap.data()?['userId'] ?? '') != current.uid) {
          throw 'Bu gönderiyi silemezsin.';
        }

        Map<String, dynamic> userData = const {};
        MascotDurum? mascot;
        if (kullaniciGuncelle) {
          final userSnap = await tx.get(userRef);
          userData = userSnap.data() ?? <String, dynamic>{};
          final robotHam = userData['robot'];
          mascot = MascotServis.tryParse(robotHam);
          if (mascot != null &&
              MascotServis.gonderiSilVilGerekir(mascot.seviye) &&
              !MascotServis.gonderiSilVilYeterli(mascot)) {
            throw 'Gönderi silmek için ${MascotServis.gonderiSilVilMaliyeti} vil gerekli.';
          }
        }

        for (final ref in likeRefs) {
          tx.delete(ref);
        }
        for (final ref in commentRefs) {
          tx.delete(ref);
        }
        tx.delete(userRef.collection('likedPosts').doc(postId));
        tx.delete(postRef);

        if (!kullaniciGuncelle) return;

        final mevcutPuan = userData['puan'];
        final puanInt = mevcutPuan is num ? mevcutPuan.toInt() : 0;
        final sonGonderiPuanPostId =
            userData['sonGonderiPuanPostId']?.toString() ?? '';
        final puanDusus =
            sonGonderiPuanPostId == postId ? (puanInt >= 10 ? 10 : puanInt) : 0;

        final userGuncelleme = <String, dynamic>{
          'gonderiSayisi': FieldValue.increment(-1),
          'sonGonderiPuanPostId': postId,
        };
        if (puanDusus > 0) {
          userGuncelleme['puan'] = FieldValue.increment(-puanDusus);
        }
        final robotHam = userData['robot'];
        if (mascot != null && MascotServis.gonderiSilVilGerekir(mascot.seviye)) {
          final robot = MascotServis.gonderiSilIcinVilHarca(
            Map<String, dynamic>.from(
              robotHam is Map
                  ? Map<String, dynamic>.from(robotHam)
                  : <String, dynamic>{},
            ),
          );
          userGuncelleme['robot'] = robot;
        }
        tx.update(userRef, userGuncelleme);
      });
    }

    try {
      await gonderiSilTxn(kullaniciGuncelle: true);
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') rethrow;
      debugPrint('gonderiSil kullanici guncelleme permission-denied, yalin silme: $e');
      await gonderiSilTxn(kullaniciGuncelle: false);
    }

    if (baskaBegenenler.isEmpty) return;
    try {
      var batch = SosyalCore.db.batch();
      var sayac = 0;
      for (final uid in baskaBegenenler) {
        batch.delete(
          SosyalCore.db
              .collection('users')
              .doc(uid)
              .collection('likedPosts')
              .doc(postId),
        );
        sayac++;
        if (sayac >= 400) {
          await batch.commit();
          batch = SosyalCore.db.batch();
          sayac = 0;
        }
      }
      if (sayac > 0) await batch.commit();
    } catch (e) {
      debugPrint('gonderiSil likedPosts temizlik: $e');
    }
  }

  static Future<BegenenSayfa> begenenleriGetir({
    required String postId,
    DocumentSnapshot<Map<String, dynamic>>? baslangic,
  }) async {
    if (postId.isEmpty) {
      return const BegenenSayfa(
        kayitlar: [],
        sonBelge: null,
        devamVar: false,
      );
    }

    Query<Map<String, dynamic>> sorgu = SosyalCore.gonderiRef(postId)
        .collection('likes')
        .orderBy('createdAt', descending: true)
        .limit(begenenSayfaBoyutu + 1);
    if (baslangic != null) {
      sorgu = sorgu.startAfterDocument(baslangic);
    }

    final snap = await sorgu.get();
    final devamVar = snap.docs.length > begenenSayfaBoyutu;
    final sayfa = devamVar
        ? snap.docs.sublist(0, begenenSayfaBoyutu)
        : snap.docs;

    final uidler = <String>[];
    for (final doc in sayfa) {
      final uid = (doc.data()['userId'] ?? doc.id).toString();
      if (uid.isNotEmpty) uidler.add(uid);
    }

    final userSnaps = uidler.isEmpty
        ? const <DocumentSnapshot<Map<String, dynamic>>>[]
        : await Future.wait(
            uidler.map(
              (uid) => SosyalCore.db.collection('users').doc(uid).get(),
            ),
          );
    final users = <String, Map<String, dynamic>>{};
    for (final userSnap in userSnaps) {
      if (userSnap.exists) {
        users[userSnap.id] = userSnap.data() ?? {};
      }
    }

    final kayitlar = <BegenenKayit>[];
    for (final uid in uidler) {
      final u = users[uid] ?? {};
      final kullaniciAdi = (u['kullaniciAdi'] ?? 'kullanici').toString();
      kayitlar.add(
        BegenenKayit(
          userId: uid,
          kullaniciAdi: kullaniciAdi,
          adSoyad: (u['adSoyad'] ?? kullaniciAdi).toString(),
          photoUrl: (u['photoUrl'] ?? '').toString(),
          avatarKey: (u['avatarKey'] ?? '').toString(),
        ),
      );
    }

    return BegenenSayfa(
      kayitlar: kayitlar,
      sonBelge: sayfa.isEmpty ? null : sayfa.last,
      devamVar: devamVar,
    );
  }
}
