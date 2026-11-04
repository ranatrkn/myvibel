// Google / Apple OAuth ortak yardımcıları.
import 'package:firebase_auth/firebase_auth.dart';

abstract final class SosyalOAuth {
  static bool googleMu(User user) =>
      user.providerData.any((info) => info.providerId == 'google.com');

  static bool appleMu(User user) =>
      user.providerData.any((info) => info.providerId == 'apple.com');

  /// Google veya Apple ile oturum açmış (şifre bağlı olsa bile).
  static bool oauthMu(User user) => googleMu(user) || appleMu(user);

  /// OAuth hesabında henüz e-posta/şifre bağlı değilse true.
  static bool sifreEksikMi(User user) =>
      oauthMu(user) &&
      !user.providerData.any((info) => info.providerId == 'password');

  static String kullaniciAdiOner({String? displayName, String? email}) {
    String temizle(String raw) =>
        raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9._]'), '');

    var aday = temizle(displayName ?? '');
    if (aday.length < 3) {
      aday = temizle(email?.split('@').first ?? '');
    }
    if (aday.length < 3) {
      aday = 'vibe${DateTime.now().millisecondsSinceEpoch % 100000}';
    }
    if (aday.length > 30) aday = aday.substring(0, 30);
    return aday;
  }

  static String adSoyadOner({String? displayName, String? email}) {
    final ad = displayName?.trim() ?? '';
    if (ad.length >= 2) return ad.length > 80 ? ad.substring(0, 80) : ad;
    final yerel = email?.split('@').first.trim() ?? '';
    if (yerel.length >= 2) return yerel;
    return 'Vibe Kullanıcısı';
  }

  /// OAuth oturumuna e-posta/şifre bağlar (hesap silme ve şifre girişi için).
  static Future<void> sifreBagla(String sifre) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'Oturum bulunamadı.',
      );
    }
    final email = user.email;
    if (email == null || email.isEmpty) {
      throw FirebaseAuthException(
        code: 'invalid-email',
        message: 'E-posta adresi bulunamadı.',
      );
    }
    if (sifre.length < 6) {
      throw FirebaseAuthException(
        code: 'weak-password',
        message: 'Şifre en az 6 karakter olmalı.',
      );
    }
    if (!sifreEksikMi(user)) {
      await user.updatePassword(sifre);
      return;
    }
    final credential = EmailAuthProvider.credential(
      email: email,
      password: sifre,
    );
    try {
      await user.linkWithCredential(credential);
      await user.reload();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'provider-already-linked' ||
          e.code == 'credential-already-in-use') {
        await user.updatePassword(sifre);
        await user.reload();
        return;
      }
      rethrow;
    }
  }
}
