// Firebase App Check ve Crashlytics başlatma
import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import 'app_check_config.dart';
import 'firebase_options.dart';

// Firebase çekirdek + güvenlik servislerini başlatır
Future<void> firebaseGuvenlikBaslat() async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Web: Settings atama cloud_firestore≤5.3'te long-polling timeout'u düşürüyordu
  // (null → FirebaseError). Varsayılan Firestore ayarı kullan; sadece oturum.
  if (kIsWeb) {
    try {
      // Sekme/tarayıcı kapanınca oturum bitsin; her ziyarette giriş.
      await FirebaseAuth.instance.setPersistence(Persistence.SESSION);
    } catch (e) {
      debugPrint('Auth persistence: $e');
    }
  }

  // Web Google redirect dönüşü (popup engellenirse)
  if (kIsWeb) {
    try {
      await FirebaseAuth.instance.getRedirectResult();
    } catch (e) {
      debugPrint('Google redirect sonucu: $e');
    }
  }

  await _crashlyticsBaslat();
  await _appCheckBaslat();
}

Future<void> _crashlyticsBaslat() async {
  if (kIsWeb) return;

  final desteklenen = defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;
  if (!desteklenen) return;

  await FirebaseCrashlytics.instance
      .setCrashlyticsCollectionEnabled(!kDebugMode);

  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };
}

Future<void> _appCheckBaslat() async {
  const betaVeyaDebug = appCheckBetaModu || kDebugMode;

  try {
    if (kIsWeb) {
      if (appCheckWebRecaptchaSiteKey.isEmpty) {
        debugPrint(
          'Web App Check atlandı: APP_CHECK_WEB_SITE_KEY / '
          'appCheckWebRecaptchaSiteKey boş. Yayın öncesi Firebase '
          'Console\'da reCAPTCHA v3 site key ekleyin.',
        );
        return;
      }
      await FirebaseAppCheck.instance.activate(
        webProvider: ReCaptchaV3Provider(appCheckWebRecaptchaSiteKey),
      );
    } else {
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          // Debug APK: debug sağlayıcı (Play Integrity sideload'da yazımı keser).
          // Mağaza sürümü: Play Integrity.
          await FirebaseAppCheck.instance.activate(
            androidProvider: betaVeyaDebug
                ? AndroidProvider.debug
                : AndroidProvider.playIntegrity,
          );
          break;
        case TargetPlatform.iOS:
        case TargetPlatform.macOS:
          await FirebaseAppCheck.instance.activate(
            appleProvider:
                betaVeyaDebug ? AppleProvider.debug : AppleProvider.appAttest,
          );
          break;
        default:
          return;
      }
    }
  } catch (e) {
    debugPrint('App Check activation failed: $e');
    return;
  }

  if (!betaVeyaDebug && !kIsWeb) return;

  unawaited(
    FirebaseAppCheck.instance.getToken(false).then((token) {
      debugPrint('App Check hazır. Token uzunluğu: ${token?.length ?? 0}');
    }).catchError((Object e) {
      debugPrint('App Check token alınamadı (başlangıç): $e');
    }),
  );
}
