// Uygulama içi destek ve geri bildirim talepleri.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DestekServis {
  static const kategoriler = <String, String>{
    'hesap': 'Hesap',
    'hata': 'Hata / Teknik sorun',
    'kvkk': 'KVKK / Veri talebi',
    'oneri': 'Öneri',
    'diger': 'Diğer',
  };

  static Future<void> talepGonder({
    required String kategori,
    required String konu,
    required String mesaj,
    String appVersion = '1.0.0',
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw 'Oturum bulunamadı.';

    if (!kategoriler.containsKey(kategori)) {
      throw 'Geçersiz kategori.';
    }

    final trimmedKonu = konu.trim();
    final trimmedMesaj = mesaj.trim();
    if (trimmedKonu.length < 3) {
      throw 'Konu en az 3 karakter olmalı.';
    }
    if (trimmedMesaj.length < 10) {
      throw 'Mesaj en az 10 karakter olmalı.';
    }
    if (trimmedMesaj.length > 2000) {
      throw 'Mesaj en fazla 2000 karakter olabilir.';
    }

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
}
