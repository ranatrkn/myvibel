// Google hesabı ile Firebase oturumu.
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'error_messages.dart';
import 'kayit_servis.dart';
import 'sosyal_oauth.dart';

enum GoogleGirisSonuc { iptal, oturumAcildi }

class GoogleGirisServis {
  GoogleGirisServis._();

  /// google-services.json içindeki web (client_type 3) OAuth istemcisi.
  static const webClientId =
      '808611716551-e9usr5incluue56upgtout3r2lbme2cs.apps.googleusercontent.com';

  /// Android/iOS: native Google Sign-In.
  /// Web: clientId zorunlu; idToken için aynı web OAuth istemcisi kullanılır.
  static final GoogleSignIn _google = GoogleSignIn(
    scopes: const ['email', 'profile'],
    clientId: kIsWeb ? webClientId : null,
    serverClientId: kIsWeb ? null : webClientId,
  );

  static GoogleAuthProvider _webGoogleProvider() {
    return GoogleAuthProvider()
      ..addScope('email')
      ..addScope('profile')
      ..setCustomParameters({'prompt': 'select_account'});
  }

  static bool googleKullanicisiMi(User user) => SosyalOAuth.googleMu(user);

  /// Google veya Apple hesabında henüz e-posta/şifre bağlı değilse true.
  static bool sifreEksikMi(User user) => SosyalOAuth.sifreEksikMi(user);

  /// OAuth oturumuna e-posta/şifre bağlar (hesap silme ve şifre girişi için).
  static Future<void> sifreBagla(String sifre) => SosyalOAuth.sifreBagla(sifre);

  static String kullaniciAdiOner({String? displayName, String? email}) =>
      SosyalOAuth.kullaniciAdiOner(displayName: displayName, email: email);

  static String adSoyadOner({String? displayName, String? email}) =>
      SosyalOAuth.adSoyadOner(displayName: displayName, email: email);

  /// Google hesap seçiciyi her seferinde gösterir; ardından Firebase oturumu açar.
  /// Yeni hesap → profil tamamlama; mevcut profil → giriş (AuthControl yönlendirir).
  static Future<GoogleGirisSonuc> girisYap({
    bool hesabiYenidenSec = true,
  }) async {
    // Masaüstü web: popup; mobil tarayıcı / engellenirse redirect.
    if (kIsWeb) {
      try {
        await FirebaseAuth.instance.signInWithPopup(_webGoogleProvider());
        return GoogleGirisSonuc.oturumAcildi;
      } on FirebaseAuthException catch (e) {
        if (e.code == 'popup-closed-by-user' ||
            e.code == 'cancelled-popup-request') {
          return GoogleGirisSonuc.iptal;
        }
        if (e.code == 'account-exists-with-different-credential') {
          throw FirebaseAuthException(
            code: e.code,
            message:
                'Bu e-posta zaten şifre ile kayıtlı. Giriş ekranından e-posta ve şifrenle gir.',
          );
        }
        // Popup engelli veya desteklenmiyor → redirect.
        if (e.code == 'popup-blocked' ||
            e.code == 'operation-not-allowed' ||
            e.code == 'auth/operation-not-supported-in-this-environment' ||
            e.message?.toLowerCase().contains('popup') == true) {
          debugPrint('Google popup başarısız (${e.code}), redirect deneniyor');
          await FirebaseAuth.instance.signInWithRedirect(_webGoogleProvider());
          return GoogleGirisSonuc.iptal;
        }
        rethrow;
      }
    }

    if (hesabiYenidenSec) {
      await _hesapSeciminiTemizle();
    }

    final googleUser = await _google.signIn();
    if (googleUser == null) return GoogleGirisSonuc.iptal;

    final googleAuth = await googleUser.authentication;
    var idToken = googleAuth.idToken;
    // Nadiren token gecikir; bir kez yenile.
    if (idToken == null || idToken.isEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      final tekrar = await googleUser.authentication;
      idToken = tekrar.idToken;
    }
    if (idToken == null || idToken.isEmpty) {
      await _hesapSeciminiTemizle();
      throw FirebaseAuthException(
        code: 'missing-id-token',
        message: 'Google oturumu alınamadı. SHA parmak izini kontrol et.',
      );
    }

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: idToken,
    );

    try {
      await FirebaseAuth.instance.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      await _hesapSeciminiTemizle();
      if (e.code == 'account-exists-with-different-credential') {
        throw FirebaseAuthException(
          code: e.code,
          message:
              'Bu e-posta zaten şifre ile kayıtlı. Giriş ekranından e-posta ve şifrenle gir.',
        );
      }
      rethrow;
    }
    return GoogleGirisSonuc.oturumAcildi;
  }

  /// Önceki Google seçimini temizler; böylece hesap listesi yeniden çıkar.
  /// Not: disconnect() bazı Xiaomi cihazlarda idToken'ı boş bırakıp
  /// girişin sessizce başarısız olmasına yol açıyor; önce signOut yeter.
  static Future<void> _hesapSeciminiTemizle() async {
    try {
      await _google.signOut();
    } catch (e) {
      debugPrint('Google signOut: $e');
    }
  }

  static Future<AuthCredential> _googleKimlikAl({
    bool hesabiYenidenSec = true,
  }) async {
    if (hesabiYenidenSec) {
      await _hesapSeciminiTemizle();
    }
    final googleUser = _google.currentUser ?? await _google.signIn();
    if (googleUser == null) {
      throw FirebaseAuthException(
        code: 'canceled',
        message: 'Google onayı iptal edildi.',
      );
    }

    final googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw FirebaseAuthException(
        code: 'missing-id-token',
        message: 'Google oturumu alınamadı. SHA parmak izini kontrol et.',
      );
    }

    return GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: idToken,
    );
  }

  /// Hesap silme gibi hassas işlemler için Google oturumunu yeniden doğrular.
  static Future<void> yenidenDogrula({bool hesabiYenidenSec = true}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'Oturum bulunamadı.',
      );
    }
    if (kIsWeb) {
      // Mobil web: redirect; masaüstü: popup dene, olmazsa redirect.
      try {
        await user.reauthenticateWithPopup(_webGoogleProvider());
      } on FirebaseAuthException catch (e) {
        if (e.code == 'popup-blocked' ||
            e.code == 'popup-closed-by-user' ||
            e.code == 'cancelled-popup-request') {
          await user.reauthenticateWithRedirect(_webGoogleProvider());
          return;
        }
        rethrow;
      }
      return;
    }
    final credential = await _googleKimlikAl(hesabiYenidenSec: hesabiYenidenSec);
    await user.reauthenticateWithCredential(credential);
  }

  static Future<void> googleOturumunuKapat() async {
    try {
      await _google.signOut();
    } catch (e) {
      debugPrint('Google signOut: $e');
    }
  }

  static Future<void> oturumuKapat() async {
    // Web'de Google Sign-In signOut sıkça asılı kalır; Firebase çıkışını engellemesin.
    try {
      await _google.signOut().timeout(const Duration(seconds: 2));
    } catch (e) {
      debugPrint('Google signOut: $e');
    }
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        await KayitServis.profilOnbelleginiTemizle(uid);
      } catch (e) {
        debugPrint('Profil onbellek temizle: $e');
      }
    }
    try {
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      debugPrint('Firebase signOut: $e');
      rethrow;
    }
  }

  static String hataMesaji(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'account-exists-with-different-credential':
          return 'Bu e-posta zaten şifre ile kayıtlı. Giriş ekranından e-posta ve şifrenle gir.';
        case 'invalid-credential':
          return 'Google oturumu doğrulanamadı. Tekrar dene.';
        case 'operation-not-allowed':
          return 'Google ile giriş Firebase Console\'da açık değil.';
        case 'network-request-failed':
          return baglantiUyariMesaji(error);
        case 'user-disabled':
          return 'Bu hesap devre dışı.';
        case 'weak-password':
          return 'Şifre en az 6 karakter olmalı.';
        case 'email-already-in-use':
        case 'credential-already-in-use':
          return 'Bu e-posta zaten şifre ile kayıtlı. Şifrenle giriş yap.';
        case 'provider-already-linked':
          return 'Bu hesaba zaten şifre bağlı.';
        case 'requires-recent-login':
          return 'Güvenlik için Google ile tekrar onayla, sonra şifre belirle.';
        case 'canceled':
        case 'popup-closed-by-user':
        case 'cancelled-popup-request':
          return '';
        case 'user-mismatch':
          return 'Onay için aynı Google hesabını seçmelisin.';
        case 'missing-id-token':
          return 'Google oturumu alınamadı. Tekrar dene.';
        case 'auth/unauthorized-domain':
        case 'unauthorized-domain':
          return 'Bu site Google girişi için henüz yetkili değil.';
        default:
          return 'Google ile giriş yapılamadı. Tekrar dene.';
      }
    }

    final metin = error.toString().toLowerCase();
    if (metin.contains('network-request-failed') ||
        metin.contains('network_error') ||
        metin.contains('socketexception') ||
        metin.contains('failed host lookup')) {
      return baglantiUyariMesaji(error);
    }
    if (metin.contains('sign_in_failed') ||
        metin.contains('developer_error') ||
        metin.contains('api_exception: 10') ||
        metin.contains('10:')) {
      return 'Google giriş ayarı eksik. Firebase\'e uygulama SHA-1 parmak izi eklenmeli.';
    }
    if (metin.contains('12501') || metin.contains('sign_in_canceled')) {
      return '';
    }
    return 'Google ile giriş yapılamadı.';
  }
}
