// Oturum açıkken mevcut şifre ile güvenli şifre değiştirme.
import 'package:firebase_auth/firebase_auth.dart';

import 'auth_eposta.dart';

class SifreDegistirServis {
  /// Mevcut şifreyi doğrular, ardından yeni şifreyi kaydeder.
  static Future<void> sifreDegistir({
    required String mevcutSifre,
    required String yeniSifre,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'Oturum bulunamadı.',
      );
    }

    if (!epostaSifreKullanicisiMi(user)) {
      throw FirebaseAuthException(
        code: 'operation-not-allowed',
        message: 'Bu hesap türünde şifre değiştirilemez.',
      );
    }

    final email = user.email;
    if (email == null || email.isEmpty) {
      throw FirebaseAuthException(
        code: 'invalid-email',
        message: 'E-posta adresi bulunamadı.',
      );
    }

    if (mevcutSifre.isEmpty) {
      throw FirebaseAuthException(
        code: 'missing-password',
        message: 'Mevcut şifre boş olamaz.',
      );
    }

    if (yeniSifre.length < 6) {
      throw FirebaseAuthException(
        code: 'weak-password',
        message: 'Yeni şifre en az 6 karakter olmalı.',
      );
    }

    final credential = EmailAuthProvider.credential(
      email: email,
      password: mevcutSifre,
    );

    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(yeniSifre);
  }
}

/// Şifre değiştirme hatalarını Türkçe metne çevirir.
String sifreDegistirHataMesaji(Object error) {
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'wrong-password':
      case 'invalid-credential':
        return 'Mevcut şifre hatalı.';
      case 'weak-password':
        return 'Yeni şifre çok zayıf. En az 6 karakter kullan.';
      case 'requires-recent-login':
        return 'Güvenlik için çıkış yapıp tekrar giriş yaptıktan sonra dene.';
      case 'too-many-requests':
        return 'Çok fazla deneme. Bir süre bekleyip tekrar dene.';
      case 'user-not-found':
        return 'Oturum bulunamadı. Yeniden giriş yap.';
      case 'operation-not-allowed':
        return 'Bu hesap türünde şifre değiştirilemez.';
      case 'missing-password':
        return 'Mevcut şifre boş olamaz.';
      case 'network-request-failed':
        return 'İnternet bağlantısı yok.';
      default:
        final mesaj = error.message?.trim();
        if (mesaj != null && mesaj.isNotEmpty) return mesaj;
        return 'Şifre değiştirilemedi (${error.code}).';
    }
  }

  return 'Şifre değiştirilemedi.';
}
