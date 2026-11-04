// E-posta/şifre hesapları için doğrulama yardımcıları.
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'error_messages.dart';

/// Kullanıcı e-posta + şifre ile mi kayıtlı?
bool epostaSifreKullanicisiMi(User user) {
  return user.providerData.any((info) => info.providerId == 'password');
}

/// E-posta doğrulaması bekleniyor mu?
///
/// Google / Apple (veya +şifre) hesaplarında e-posta sağlayıcı tarafından
/// doğrulanmış kabul edilir. `linkWithCredential` sonrası Firebase bazen
/// `emailVerified=false` yapabiliyor; bu durumda doğrulama ekranına
/// düşürmemek / oturumu silmemek için OAuth provider varsa false döner.
bool epostaDogrulamaBekliyorMu(User user) {
  final providers = user.providerData.map((p) => p.providerId).toSet();
  if (providers.contains('google.com') || providers.contains('apple.com')) {
    return false;
  }
  return providers.contains('password') && !user.emailVerified;
}

/// Firebase'den güncel doğrulama durumunu çeker.
///
/// `reload` kullanıcı nesnesini günceller; Firestore kuralları ise kimlik
/// jetonundaki `email_verified` alanına bakar. Onay linkinden dönünce jeton
/// yenilenmezse profil yazımı reddedilir.
Future<bool> epostaDogrulamaDurumunuYenile(User user) async {
  await user.reload();
  final guncel = FirebaseAuth.instance.currentUser;
  if (guncel == null) return false;
  if (guncel.emailVerified) {
    await guncel.getIdToken(true);
  }
  return guncel.emailVerified;
}

/// Doğrulama e-postası gönderir (Firebase varsayılan şablonu).
Future<void> epostaDogrulamaMailiGonder(User user) async {
  try {
    await user.reload();
  } catch (e) {
    debugPrint('E-posta doğrulama reload: $e');
  }
  final guncel = FirebaseAuth.instance.currentUser;
  if (guncel == null) {
    throw FirebaseAuthException(
      code: 'user-not-found',
      message: 'Oturum bulunamadı.',
    );
  }
  if (guncel.emailVerified) {
    await guncel.getIdToken(true);
    return;
  }

  // ActionCodeSettings bazı projelerde mailin hiç gitmemesine yol açabiliyor;
  // varsayılan Firebase doğrulama maili en güvenilir yol.
  await guncel.sendEmailVerification();

  if (kDebugMode) {
    debugPrint('Doğrulama e-postası isteği gönderildi: ${guncel.email}');
  }
}

/// Şifre sıfırlama sayfası (Firebase Hosting — myvibel.com).
const String sifreSifirlamaDevamUrl =
    'https://myvibel.com/reset-password.html';

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

/// Mevcut şifreyi doğrular, yeni adrese onay maili gönderir.
/// Adres, linke basılınca değişir.
Future<void> epostaDegisikligiBaslat({
  required User user,
  required String yeniEmail,
  required String mevcutSifre,
}) async {
  final eski = user.email?.trim() ?? '';
  final hedef = yeniEmail.trim();
  if (eski.isEmpty || !eski.contains('@')) {
    throw FirebaseAuthException(
      code: 'invalid-email',
      message: 'Mevcut e-posta bulunamadı.',
    );
  }
  if (!epostaSifreKullanicisiMi(user)) {
    throw FirebaseAuthException(
      code: 'operation-not-allowed',
      message: 'Bu hesap Google veya Apple ile bağlı. E-posta oradan değişir.',
    );
  }
  if (mevcutSifre.isEmpty) {
    throw FirebaseAuthException(
      code: 'missing-password',
      message: 'Mevcut şifre gerekli.',
    );
  }
  if (!hedef.contains('@') || hedef.toLowerCase() == eski.toLowerCase()) {
    throw FirebaseAuthException(
      code: 'invalid-email',
      message: 'Yeni bir e-posta adresi gir.',
    );
  }

  final credential = EmailAuthProvider.credential(
    email: eski,
    password: mevcutSifre,
  );
  await user.reauthenticateWithCredential(credential);
  await user.verifyBeforeUpdateEmail(hedef);
}

/// E-posta değiştirme hatalarını Türkçe metne çevirir.
String epostaDegistirmeHataMesaji(FirebaseAuthException e) {
  switch (e.code) {
    case 'wrong-password':
    case 'invalid-credential':
      return 'Mevcut şifre hatalı.';
    case 'invalid-email':
      return e.message?.trim().isNotEmpty == true
          ? e.message!.trim()
          : 'Geçerli bir e-posta adresi gir.';
    case 'email-already-in-use':
      return 'Bu e-posta başka bir hesapta kayıtlı.';
    case 'requires-recent-login':
      return 'Güvenlik için şifreni yeniden gir.';
    case 'too-many-requests':
      return 'Çok fazla deneme. Bir süre bekleyip tekrar dene.';
    case 'operation-not-allowed':
      return e.message?.trim().isNotEmpty == true
          ? e.message!.trim()
          : 'Bu hesapta e-posta buradan değiştirilemez.';
    case 'missing-password':
      return 'Mevcut şifre gerekli.';
    default:
      final mesaj = e.message?.trim();
      if (mesaj != null && mesaj.isNotEmpty) return mesaj;
      return 'E-posta değiştirilemedi (${e.code}).';
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
      return baglantiUyariMesaji(e);
    default:
      final mesaj = e.message?.trim();
      if (mesaj != null && mesaj.isNotEmpty) return mesaj;
      return 'Şifre sıfırlama maili gönderilemedi (${e.code}).';
  }
}
