// Uygulama içi destek ve geri bildirim talepleri.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DestekServis {
  static const kategoriler = <String, String>{
    'hesap': 'Hesap',
    'hata': 'Hata / Teknik sorun',
    'kvkk': 'KVKK / Veri talebi',
    'yas_itiraz': 'Yaş / hesap itirazı',
    'oneri': 'Öneri',
    'diger': 'Diğer',
  };

  // Talep geçerliyse null, değilse kullanıcıya gösterilecek hata.
  static String? talepHatasi({
    required String kategori,
    required String konu,
    required String mesaj,
  }) {
    if (!kategoriler.containsKey(kategori)) return 'Geçersiz kategori.';
    final trimmedMesaj = mesaj.trim();
    if (konu.trim().length < 3) return 'Konu en az 3 karakter olmalı.';
    if (trimmedMesaj.length < 10) return 'Mesaj en az 10 karakter olmalı.';
    if (trimmedMesaj.length > 2000) {
      return 'Mesaj en fazla 2000 karakter olabilir.';
    }
    return null;
  }

  static Future<void> talepGonder({
    required String kategori,
    required String konu,
    required String mesaj,
    String appVersion = '1.0.0',
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw 'Oturum bulunamadı.';

    final hata = talepHatasi(kategori: kategori, konu: konu, mesaj: mesaj);
    if (hata != null) throw hata;

    final trimmedKonu = konu.trim();
    final trimmedMesaj = mesaj.trim();

    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final userData = userDoc.data() ?? {};
    final kullaniciAdi =
        (userData['kullaniciAdi'] ?? 'Vibe Kullanıcısı').toString();

    await FirebaseFirestore.instance.collection('supportTickets').add({
      'userId': user.uid,
      'kullaniciAdi': kullaniciAdi,
      'kategori': kategori,
      'konu': trimmedKonu,
      'mesaj': trimmedMesaj,
      'status': 'pending',
      'appVersion': appVersion,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static const bildirimGonderenAdi = 'MyVibel Destek';
  static const yanitSiniri = 2000;

  /// Moderatör: talebin durumunu günceller, isteğe bağlı yanıt yazar.
  /// Talep çözüldüğünde veya yanıtlandığında sahibine bildirim gider.
  static Future<void> moderatorGuncelle({
    required DocumentReference<Map<String, dynamic>> talepRef,
    required String talepSahibi,
    required String konu,
    String? durum,
    String? yanit,
  }) async {
    final moderator = FirebaseAuth.instance.currentUser;
    if (moderator == null) throw 'Oturum bulunamadı.';
    final temizYanit = yanit?.trim() ?? '';
    if (temizYanit.length > yanitSiniri) {
      throw 'Yanıt en fazla $yanitSiniri karakter olabilir.';
    }

    final db = FirebaseFirestore.instance;
    final batch = db.batch();
    batch.update(talepRef, {
      if (durum != null) 'status': durum,
      if (temizYanit.isNotEmpty) ...{
        'modYaniti': temizYanit,
        'yanitlandiAt': FieldValue.serverTimestamp(),
      },
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewedBy': moderator.uid,
    });

    final bildirimGerekli = temizYanit.isNotEmpty || durum == 'resolved';
    if (bildirimGerekli &&
        talepSahibi.isNotEmpty &&
        talepSahibi != moderator.uid) {
      batch.set(
        db.collection('users').doc(talepSahibi).collection('notifications').doc(),
        {
          'tip': 'destek',
          'gonderenUid': moderator.uid,
          'gonderenKullaniciAdi': bildirimGonderenAdi,
          'ticketId': talepRef.id,
          'konu': konu,
          'durum': durum ?? '',
          'metin': temizYanit.length > 300
              ? '${temizYanit.substring(0, 297)}...'
              : temizYanit,
          'postId': '',
          'chatId': '',
          'okundu': false,
          'createdAt': FieldValue.serverTimestamp(),
        },
      );
    }
    await batch.commit();
  }

  /// Kullanıcının kendi talepleri (en yeni üstte).
  static Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      taleplerimAkisi(String uid) {
    return FirebaseFirestore.instance
        .collection('supportTickets')
        .where('userId', isEqualTo: uid)
        .limit(30)
        .snapshots()
        .map((snap) {
      final docs = snap.docs.toList();
      int zaman(QueryDocumentSnapshot<Map<String, dynamic>> d) {
        final t = d.data()['createdAt'];
        return t is Timestamp ? t.millisecondsSinceEpoch : 1 << 52;
      }

      docs.sort((a, b) => zaman(b).compareTo(zaman(a)));
      return docs;
    });
  }
}
