// E-posta doğrulanmadan tam profil oluşturulmaz; iptal edilince kayıt silinir.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'auth_eposta.dart';

class KayitServis {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const _beklemeSuresi = Duration(hours: 48);

  /// Uygulama profili (users koleksiyonu) oluşmuş mu?
  static Future<bool> profilTamamlandiMi(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.exists;
  }

  /// Bekleyen kayıt var mı?
  static Future<bool> bekleyenKayitVarMi(String uid) async {
    final doc = await _db.collection('pendingProfiles').doc(uid).get();
    return doc.exists;
  }

  /// Auth hesabı + bekleyen profil oluşturur; users/usernames henüz yazılmaz.
  /// Mail gönderilemezse hata metni döner; kayıt yine de tamamlanmış olur.
  static Future<String?> bekleyenKayitOlustur({
    required String adSoyad,
    required String kullaniciAdi,
    required String kullaniciAdiKucuk,
    required String email,
    required String sifre,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: sifre,
    );
    final user = credential.user;
    if (user == null) {
      throw 'Kullanıcı oluşturulamadı.';
    }

    final usernameRef = _db.collection('usernames').doc(kullaniciAdiKucuk);
    final holdRef = _db.collection('usernameHolds').doc(kullaniciAdiKucuk);
    final pendingRef = _db.collection('pendingProfiles').doc(user.uid);

    try {
      await user.updateDisplayName(kullaniciAdi);

      final expiresAt =
          Timestamp.fromDate(DateTime.now().add(_beklemeSuresi));

      await _db.runTransaction((tx) async {
        final uSnap = await tx.get(usernameRef);
        if (uSnap.exists) {
          throw 'Bu kullanıcı adı zaten alınmış.';
        }

        final hSnap = await tx.get(holdRef);
        if (hSnap.exists &&
            hSnap.data()?['uid'] != user.uid &&
            !_holdSuresiDolmus(hSnap.data())) {
          throw 'Bu kullanıcı adı şu an başka bir kayıtta.';
        }

        tx.set(holdRef, {
          'uid': user.uid,
          'kullaniciAdiKucuk': kullaniciAdiKucuk,
          'expiresAt': expiresAt,
          'createdAt': FieldValue.serverTimestamp(),
        });

        tx.set(pendingRef, {
          'uid': user.uid,
          'adSoyad': adSoyad,
          'kullaniciAdi': kullaniciAdi,
          'kullaniciAdiKucuk': kullaniciAdiKucuk,
          'email': email,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      await bekleyenKayitKayitlariniSil(user.uid);
      await _authHesabiniSil(user);
      rethrow;
    }

    try {
      await epostaDogrulamaMailiGonder(user);
      return null;
    } on FirebaseAuthException catch (e) {
      debugPrint('Kayıt sonrası e-posta gönderilemedi: ${e.code} ${e.message}');
      return epostaGonderimHataMesaji(e);
    }
  }

  /// E-posta doğrulandıktan veya linkle girişten sonra gerçek profili oluşturur.
  static Future<void> profilOlustur({
    required String uid,
    required String adSoyad,
    required String kullaniciAdi,
    required String kullaniciAdiKucuk,
    required String email,
  }) async {
    if (kullaniciAdiKucuk.length < 3) {
      throw 'Kayıt bilgisi geçersiz. Lütfen yeniden kayıt ol.';
    }

    final userRef = _db.collection('users').doc(uid);
    final usernameRef = _db.collection('usernames').doc(kullaniciAdiKucuk);
    final holdRef = _db.collection('usernameHolds').doc(kullaniciAdiKucuk);
    final pendingRef = _db.collection('pendingProfiles').doc(uid);

    await _db.runTransaction((tx) async {
      final mevcutProfil = await tx.get(userRef);
      if (mevcutProfil.exists) return;

      final uSnap = await tx.get(usernameRef);
      if (uSnap.exists) {
        throw 'Bu kullanıcı adı artık alınmış. Farklı bir ad ile yeniden kayıt ol.';
      }

      tx.set(userRef, {
        'uid': uid,
        'adSoyad': adSoyad,
        'kullaniciAdi': kullaniciAdi,
        'kullaniciAdiKucuk': kullaniciAdiKucuk,
        'email': email,
        'photoUrl': '',
        'avatarKey': 'koala_blue',
        'aramaSkoru': 0,
        'puan': 0,
        'gonderiSayisi': 0,
        'begeniSayisi': 0,
        'yorumSayisi': 0,
        'hesapGizli': false,
        'robot': {
          'isim': 'Mini Vibe',
          'seviye': 1,
          'gelisimPuani': 0,
          'enerji': 50,
          'mutluluk': 50,
          'sonUygulamaMs': DateTime.now().millisecondsSinceEpoch,
          'sonEtkilesimMs': DateTime.now().millisecondsSinceEpoch,
          'sonMutlulukTickMs': DateTime.now().millisecondsSinceEpoch,
        },
        'createdAt': FieldValue.serverTimestamp(),
      });

      tx.set(usernameRef, {
        'uid': uid,
        'kullaniciAdi': kullaniciAdi,
        'createdAt': FieldValue.serverTimestamp(),
      });

      tx.delete(pendingRef);
      tx.delete(holdRef);
    });
  }

  /// E-posta doğrulandıktan sonra gerçek profili oluşturur (eski akış).
  static Future<void> dogrulamaSonrasiKaydiTamamla() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw 'Oturum bulunamadı.';
    }

    await user.reload();
    final guncel = _auth.currentUser;
    if (guncel == null || !guncel.emailVerified) {
      throw 'E-posta henüz doğrulanmamış.';
    }

    final userRef = _db.collection('users').doc(guncel.uid);
    final mevcutProfil = await userRef.get();
    if (mevcutProfil.exists) return;

    final pendingRef = _db.collection('pendingProfiles').doc(guncel.uid);
    final pendingSnap = await pendingRef.get();
    if (!pendingSnap.exists) {
      throw 'Kayıt bilgisi bulunamadı. Lütfen yeniden kayıt ol.';
    }

    final pending = pendingSnap.data() ?? {};
    final kullaniciAdi = pending['kullaniciAdi']?.toString() ?? '';
    final kullaniciAdiKucuk = pending['kullaniciAdiKucuk']?.toString() ?? '';
    final adSoyad = pending['adSoyad']?.toString() ?? '';
    final email = pending['email']?.toString() ?? guncel.email ?? '';

    if (kullaniciAdiKucuk.length < 3) {
      throw 'Kayıt bilgisi geçersiz. Lütfen yeniden kayıt ol.';
    }

    await profilOlustur(
      uid: guncel.uid,
      adSoyad: adSoyad,
      kullaniciAdi: kullaniciAdi,
      kullaniciAdiKucuk: kullaniciAdiKucuk,
      email: email,
    );
  }

  /// Doğrulanmamış kayıt iptal: bekleyen veriler + auth hesabı silinir.
  static Future<void> bekleyenKayitIptal() async {
    final user = _auth.currentUser;
    if (user == null) {
      await _auth.signOut();
      return;
    }

    final uid = user.uid;
    final dogrulanmamis = !user.emailVerified;
    await bekleyenKayitKayitlariniSil(uid);

    if (dogrulanmamis) {
      await _authHesabiniSil(user);
    }

    await _auth.signOut();
  }

  static Future<void> bekleyenKayitKayitlariniSil(String uid) async {
    final pendingRef = _db.collection('pendingProfiles').doc(uid);
    final pending = await pendingRef.get();
    final kucuk = pending.data()?['kullaniciAdiKucuk']?.toString() ?? '';

    final batch = _db.batch();
    batch.delete(pendingRef);

    if (kucuk.isNotEmpty) {
      final holdRef = _db.collection('usernameHolds').doc(kucuk);
      final hold = await holdRef.get();
      if (hold.exists && hold.data()?['uid'] == uid) {
        batch.delete(holdRef);
      }
    }

    await batch.commit();
  }

  static bool _holdSuresiDolmus(Map<String, dynamic>? data) {
    if (data == null) return true;
    final expiresAt = data['expiresAt'];
    if (expiresAt is! Timestamp) return true;
    return expiresAt.toDate().isBefore(DateTime.now());
  }

  /// Doğrulanmamış ve bekleyen kaydı olmayan boş auth oturumunu siler.
  static Future<bool> gecersizOturumuTemizle(User user) async {
    if (user.emailVerified) return false;
    if (user.providerData.any((info) => info.providerId == 'password')) {
      return false;
    }
    if (await profilTamamlandiMi(user.uid)) return false;
    if (await bekleyenKayitVarMi(user.uid)) return false;

    await bekleyenKayitKayitlariniSil(user.uid);
    await _authHesabiniSil(user);
    if (_auth.currentUser != null) {
      await _auth.signOut();
    }
    return true;
  }

  static Future<void> _authHesabiniSil(User user) async {
    try {
      await user.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        await _auth.signOut();
      }
    }
  }
}
