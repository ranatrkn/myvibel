// Apple ile Firebase oturumu (iOS / Android / web).
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'error_messages.dart';
import 'kayit_servis.dart';
import 'sosyal_oauth.dart';

enum AppleGirisSonuc { iptal, oturumAcildi }

class AppleGirisServis {
  AppleGirisServis._();

  /// Apple Developer hesabı açılınca true yapılır. Buton silinmez.
  static const gorunur = false;

  static bool appleKullanicisiMi(User user) => SosyalOAuth.appleMu(user);

  static AppleAuthProvider _provider() {
    return AppleAuthProvider()
      ..addScope('email')
      ..addScope('name');
  }

  /// Web: redirect (mobil tarayıcıda popup güvenilir değil).
  /// iOS/macOS: native Sign in with Apple + nonce.
  /// Android: Firebase provider (Firebase Console’daki Apple Service ID).
  static Future<AppleGirisSonuc> girisYap() async {
    if (kIsWeb) {
      try {
        await FirebaseAuth.instance.signInWithRedirect(_provider());
        return AppleGirisSonuc.iptal;
      } on FirebaseAuthException catch (e) {
        if (e.code == 'popup-closed-by-user' ||
            e.code == 'cancelled-popup-request') {
          return AppleGirisSonuc.iptal;
        }
        if (e.code == 'account-exists-with-different-credential') {
          throw FirebaseAuthException(
            code: e.code,
            message:
                'Bu e-posta zaten başka bir yöntemle kayıtlı. Giriş ekranından e-posta/şifre veya Google ile dene.',
          );
        }
        rethrow;
      }
    }

    try {
      if (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.iOS ||
              defaultTargetPlatform == TargetPlatform.macOS)) {
        await _nativeAppleGiris();
      } else {
        await FirebaseAuth.instance.signInWithProvider(_provider());
      }
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return AppleGirisSonuc.iptal;
      }
      rethrow;
    } on FirebaseAuthException catch (e) {
      debugPrint('Apple giris FirebaseAuthException: ${e.code} ${e.message}');
      if (e.code == 'canceled' ||
          e.code == 'web-context-canceled' ||
          e.code == 'popup-closed-by-user' ||
          e.code == 'cancelled-popup-request') {
        return AppleGirisSonuc.iptal;
      }
      if (e.code == 'account-exists-with-different-credential') {
        throw FirebaseAuthException(
          code: e.code,
          message:
              'Bu e-posta zaten başka bir yöntemle kayıtlı. Giriş ekranından e-posta/şifre veya Google ile dene.',
        );
      }
      rethrow;
    }
    return AppleGirisSonuc.oturumAcildi;
  }

  static Future<void> _nativeAppleGiris() async {
    final rawNonce = _nonceUret();
    final nonce = _sha256(rawNonce);

    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: nonce,
    );

    final idToken = appleCredential.identityToken;
    if (idToken == null || idToken.isEmpty) {
      throw FirebaseAuthException(
        code: 'missing-id-token',
        message: 'Apple oturumu alınamadı. Tekrar dene.',
      );
    }

    final oauthCredential = OAuthProvider('apple.com').credential(
      idToken: idToken,
      rawNonce: rawNonce,
      accessToken: appleCredential.authorizationCode,
    );

    final sonuc =
        await FirebaseAuth.instance.signInWithCredential(oauthCredential);

    // Apple adı yalnızca ilk girişte verir; profilde boşsa yaz.
    final given = appleCredential.givenName?.trim() ?? '';
    final family = appleCredential.familyName?.trim() ?? '';
    final birlesik = '$given $family'.trim();
    final user = sonuc.user;
    if (user != null &&
        birlesik.length >= 2 &&
        (user.displayName == null || user.displayName!.trim().isEmpty)) {
      await user.updateDisplayName(birlesik);
      await user.reload();
    }
  }

  static Future<void> yenidenDogrula() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'Oturum bulunamadı.',
      );
    }

    if (kIsWeb) {
      try {
        await user.reauthenticateWithPopup(_provider());
      } on FirebaseAuthException catch (e) {
        if (e.code == 'popup-blocked' ||
            e.code == 'popup-closed-by-user' ||
            e.code == 'cancelled-popup-request') {
          await user.reauthenticateWithRedirect(_provider());
          return;
        }
        rethrow;
      }
      return;
    }

    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      final rawNonce = _nonceUret();
      final nonce = _sha256(rawNonce);
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );
      final idToken = appleCredential.identityToken;
      if (idToken == null || idToken.isEmpty) {
        throw FirebaseAuthException(
          code: 'missing-id-token',
          message: 'Apple oturumu alınamadı. Tekrar dene.',
        );
      }
      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: idToken,
        rawNonce: rawNonce,
        accessToken: appleCredential.authorizationCode,
      );
      await user.reauthenticateWithCredential(oauthCredential);
      return;
    }

    await user.reauthenticateWithProvider(_provider());
  }

  static Future<void> oturumuKapat() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await KayitServis.profilOnbelleginiTemizle(uid);
    }
    await FirebaseAuth.instance.signOut();
  }

  static String hataMesaji(Object error) {
    if (error is SignInWithAppleAuthorizationException) {
      if (error.code == AuthorizationErrorCode.canceled) return '';
      if (error.code == AuthorizationErrorCode.notHandled ||
          error.code == AuthorizationErrorCode.notInteractive) {
        return 'Apple ile giriş bu cihazda tamamlanamadı.';
      }
      return 'Apple ile giriş yapılamadı. Tekrar dene.';
    }

    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'account-exists-with-different-credential':
          return 'Bu e-posta zaten başka bir yöntemle kayıtlı. E-posta/şifre veya Google ile giriş yap.';
        case 'invalid-credential':
          return 'Apple oturumu doğrulanamadı. Firebase’deki Apple Service ID / Key ayarlarını kontrol et.';
        case 'operation-not-allowed':
          // Android/web: toggle yetmez; OAuth code flow (Services ID + Key) dolu olmalı.
          // Firebase mesajı sıkça: "Code flow is not enabled for Apple."
          return 'Apple girişi Android/web için henüz tam ayarlanmadı. '
              'Firebase Console → Authentication → Apple içinde '
              'Service ID ve OAuth code flow (Team ID, Key ID, Private Key) '
              'alanlarını doldurup kaydet.';
        case 'network-request-failed':
          return baglantiUyariMesaji(error);
        case 'user-disabled':
          return 'Bu hesap devre dışı.';
        case 'canceled':
        case 'web-context-canceled':
        case 'popup-closed-by-user':
        case 'cancelled-popup-request':
          return '';
        case 'user-mismatch':
          return 'Onay için aynı Apple hesabını seçmelisin.';
        case 'missing-id-token':
          return 'Apple oturumu alınamadı. Tekrar dene.';
        case 'auth/unauthorized-domain':
        case 'unauthorized-domain':
          return 'Bu site Apple girişi için henüz yetkili değil.';
        default:
          return 'Apple ile giriş yapılamadı. Tekrar dene.';
      }
    }

    final metin = error.toString().toLowerCase();
    if (metin.contains('network-request-failed') ||
        metin.contains('network_error') ||
        metin.contains('socketexception') ||
        metin.contains('failed host lookup')) {
      return baglantiUyariMesaji(error);
    }
    if (metin.contains('canceled') || metin.contains('cancelled')) return '';
    return 'Apple ile giriş yapılamadı.';
  }

  static String _nonceUret([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  static String _sha256(String input) {
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }
}
