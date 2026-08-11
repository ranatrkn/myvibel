// E-posta/şifre hesapları için doğrulama yardımcıları.
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Kullanıcı e-posta + şifre ile mi kayıtlı?
bool epostaSifreKullanicisiMi(User user) {
  return user.providerData.any((info) => info.providerId == 'password');
}

/// E-posta doğrulaması bekleniyor mu?
bool epostaDogrulamaBekliyorMu(User user) {
  return epostaSifreKullanicisiMi(user) && !user.emailVerified;
}

/// Firebase'den güncel doğrulama durumunu çeker.
Future<bool> epostaDogrulamaDurumunuYenile(User user) async {
  await user.reload();
  return FirebaseAuth.instance.currentUser?.emailVerified == true;
}

/// Doğrulama e-postası gönderir (Firebase varsayılan şablonu).
Future<void> epostaDogrulamaMailiGonder(User user) async {
  await user.reload();
  final guncel = FirebaseAuth.instance.currentUser;
  if (guncel == null) {
    throw FirebaseAuthException(
      code: 'user-not-found',
      message: 'Oturum bulunamadı.',
    );
  }
  if (guncel.emailVerified) return;

  // ActionCodeSettings bazı projelerde mailin hiç gitmemesine yol açabiliyor;
  // varsayılan Firebase doğrulama maili en güvenilir yol.
  await guncel.sendEmailVerification();

  if (kDebugMode) {
    debugPrint('Doğrulama e-postası isteği gönderildi: ${guncel.email}');
  }
}

/// Şifre sıfırlama sayfası (Firebase Hosting).
/// Console'da action URL kaydedilemiyorsa sorun değil; mail varsayılan
/// firebaseapp.com handler'ına gider. Bu adres continueUrl için kullanılır.
const String sifreSifirlamaDevamUrl =
    'https://vibe-life-app.firebaseapp.com/reset-password.html';

/// Şifre sıfırlama bağlantısı gönderir.
Future<void> sifreSifirlamaMailiGonder(String email) async {
  final normalized = email.trim();
  if (normalized.isEmpty) {
    throw FirebaseAuthException(
      code: 'invalid-email',
      message: 'E-posta adresi gir.',
    );
  }

  try {
    await FirebaseAuth.instance.sendPasswordResetEmail(
      email: normalized,
      actionCodeSettings: ActionCodeSettings(
        url: sifreSifirlamaDevamUrl,
        handleCodeInApp: false,
      ),
    );
  } on FirebaseAuthException catch (e) {
    if (e.code == 'invalid-continue-uri' ||
        e.code == 'unauthorized-continue-uri') {
      // Yetkili domain yoksa varsayılan Firebase sıfırlama maili gönder.
      await FirebaseAuth.instance.sendPasswordResetEmail(email: normalized);
      return;
    }
    rethrow;
  }
}

/// Firebase Auth e-posta hatalarını Türkçe metne çevirir.
String epostaGonderimHataMesaji(FirebaseAuthException e) {
  switch (e.code) {
    case 'too-many-requests':
      return 'Çok fazla e-posta isteği. 15–30 dakika bekleyip tekrar dene.';
    case 'invalid-continue-uri':
    case 'unauthorized-continue-uri':
      return 'Doğrulama linki ayarı hatalı. Firebase Console\'da yetkili domainleri kontrol et.';
    case 'user-not-found':
      return 'Oturum bulunamadı. Yeniden giriş yap.';
    default:
      final mesaj = e.message?.trim();
      if (mesaj != null && mesaj.isNotEmpty) return mesaj;
      return 'Doğrulama e-postası gönderilemedi (${e.code}).';
  }
}

/// Şifre sıfırlama e-postası hatalarını Türkçe metne çevirir.
String sifreSifirlamaHataMesaji(FirebaseAuthException e) {
  switch (e.code) {
    case 'invalid-email':
      return 'Geçerli bir e-posta adresi gir.';
    case 'user-not-found':
      return 'Bu e-posta ile kayıtlı kullanıcı bulunamadı.';
    case 'too-many-requests':
      return 'Çok fazla istek. Bir süre bekleyip tekrar dene.';
    case 'network-request-failed':
      return 'İnternet bağlantısı yok.';
    default:
      final mesaj = e.message?.trim();
      if (mesaj != null && mesaj.isNotEmpty) return mesaj;
      return 'Şifre sıfırlama maili gönderilemedi (${e.code}).';
  }
}
