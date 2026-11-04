// Moderatör rapor kuyruğu işlemleri.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:myvibel/sosyal/sosyal_core.dart';

/// Şikayet edilen içeriğin şu anki hâli.
class RaporIcerik {
  const RaporIcerik({
    required this.metin,
    required this.gizli,
    this.sikayetSayisi,
  }) : silinmis = false;

  const RaporIcerik.silinmis()
      : metin = '',
        gizli = false,
        sikayetSayisi = null,
        silinmis = true;

  final String metin;
  final bool gizli;
  final int? sikayetSayisi;
  final bool silinmis;
}

class ModerasyonServis {
  static final _db = SosyalCore.db;

  static Future<bool> moderatorMu(String uid) async {
    if (uid.isEmpty) return false;
    final doc = await _db.collection('users').doc(uid).get();
    return doc.data()?['isModerator'] == true;
  }

  static Future<Map<String, String>> kullaniciEtiketleriGetir(
    Set<String> uidler,
  ) async {
    final sonuc = <String, String>{};
    final hedefler = uidler.where((uid) => uid.isNotEmpty).toSet();
    if (hedefler.isEmpty) return sonuc;

    final okuma = await Future.wait(
      hedefler.map((uid) => _db.collection('users').doc(uid).get()),
    );

    for (final doc in okuma) {
      if (!doc.exists) continue;
      final data = doc.data() ?? {};
      final kullaniciAdi = (data['kullaniciAdi'] ?? 'kullanici').toString();
      final adSoyad = (data['adSoyad'] ?? 'Vibe Kullanıcısı').toString();
      sonuc[doc.id] = '$adSoyad (@$kullaniciAdi)';
    }
    return sonuc;
  }

  static Future<RaporIcerik?> raporIcerikDurumu(
    Map<String, dynamic> data,
  ) async {
    final type = (data['type'] ?? '').toString();
    int sayi(dynamic v) => v is num ? v.toInt() : 0;
    try {
      switch (type) {
        case 'post':
          final postId = (data['postId'] ?? '').toString();
          if (postId.isEmpty) return null;
          final doc = await SosyalCore.gonderiRef(postId).get();
          if (!doc.exists) return const RaporIcerik.silinmis();
          final d = doc.data() ?? {};
          final metin = (d['metin'] ?? '').toString().trim();
          return RaporIcerik(
            metin: metin.isEmpty ? '(Metinsiz gönderi)' : metin,
            gizli: d['raporNedeniyleGizli'] == true,
            sikayetSayisi: sayi(d['sikayetSayisi']),
          );
        case 'comment':
          final postId = (data['postId'] ?? '').toString();
          final commentId = (data['commentId'] ?? '').toString();
          if (postId.isEmpty || commentId.isEmpty) return null;
          final doc = await SosyalCore.gonderiRef(postId)
              .collection('comments')
              .doc(commentId)
              .get();
          if (!doc.exists) return const RaporIcerik.silinmis();
          final d = doc.data() ?? {};
          final metin = (d['metin'] ?? '').toString().trim();
          return RaporIcerik(
            metin: metin.isEmpty ? '(Boş yorum)' : metin,
            gizli: d['raporNedeniyleGizli'] == true,
            sikayetSayisi: sayi(d['sikayetSayisi']),
          );
        case 'user':
          final targetUid = (data['targetUid'] ?? '').toString();
          if (targetUid.isEmpty) return null;
          final doc = await _db.collection('users').doc(targetUid).get();
          if (!doc.exists) return const RaporIcerik.silinmis();
          final d = doc.data() ?? {};
          final adSoyad = (d['adSoyad'] ?? 'Vibe Kullanıcısı').toString();
          final kullaniciAdi = (d['kullaniciAdi'] ?? 'kullanici').toString();
          return RaporIcerik(
            metin: '$adSoyad (@$kullaniciAdi)',
            gizli: d['raporNedeniyleGizli'] == true,
          );
        default:
          return null;
      }
    } catch (_) {
      return null;
    }
  }

  static Future<void> raporDurumuGuncelle({
    required DocumentReference<Map<String, dynamic>> raporRef,
    required String durum,
  }) async {
    await raporRef.update({
      'status': durum,
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewedBy': FirebaseAuth.instance.currentUser?.uid ?? '',
    });
  }

  static Future<void> icerigiGizle(Map<String, dynamic> data) async {
    final type = (data['type'] ?? '').toString();
    final guncelleme = {
      'raporNedeniyleGizli': true,
      'raporGuncellenmeTarihi': FieldValue.serverTimestamp(),
    };

    if (type == 'post') {
      final postId = (data['postId'] ?? '').toString();
      if (postId.isEmpty) return;
      await SosyalCore.gonderiRef(postId).update(guncelleme);
      return;
    }

    if (type == 'comment') {
      final postId = (data['postId'] ?? '').toString();
      final commentId = (data['commentId'] ?? '').toString();
      if (postId.isEmpty || commentId.isEmpty) return;
      await SosyalCore.gonderiRef(postId)
          .collection('comments')
          .doc(commentId)
          .update(guncelleme);
      return;
    }

    if (type == 'user') {
      final targetUid = (data['targetUid'] ?? '').toString();
      if (targetUid.isEmpty) return;
      await _db.collection('users').doc(targetUid).update(guncelleme);
    }
  }

  static Future<void> icerikGizlemesiniKaldir(Map<String, dynamic> data) async {
    final type = (data['type'] ?? '').toString();
    const guncelleme = {
      'raporNedeniyleGizli': false,
    };

    if (type == 'post') {
      final postId = (data['postId'] ?? '').toString();
      if (postId.isEmpty) return;
      await SosyalCore.gonderiRef(postId).update(guncelleme);
      return;
    }

    if (type == 'comment') {
      final postId = (data['postId'] ?? '').toString();
      final commentId = (data['commentId'] ?? '').toString();
      if (postId.isEmpty || commentId.isEmpty) return;
      await SosyalCore.gonderiRef(postId)
          .collection('comments')
          .doc(commentId)
          .update(guncelleme);
      return;
    }

    if (type == 'user') {
      final targetUid = (data['targetUid'] ?? '').toString();
      if (targetUid.isEmpty) return;
      await _db.collection('users').doc(targetUid).update(guncelleme);
    }
  }

  static Future<void> islemUygula({
    required DocumentReference<Map<String, dynamic>> raporRef,
    required Map<String, dynamic> data,
  }) async {
    await icerigiGizle(data);
    await raporDurumuGuncelle(raporRef: raporRef, durum: 'action_taken');
  }
}
