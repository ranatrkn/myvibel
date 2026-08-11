// Firebase App Check ve Crashlytics başlatma
import 'package:firebase_app_check/firebase_app_check.dart';
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
  if (kIsWeb) return;

  const betaVeyaDebug = appCheckBetaModu || kDebugMode;

  try {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
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
  } catch (e) {
    debugPrint('App Check activation failed: $e');
    return;
  }

  if (!betaVeyaDebug) return;

  try {
    final token = await FirebaseAppCheck.instance.getToken(false);
    debugPrint('App Check hazır. Token uzunluğu: ${token?.length ?? 0}');
  } catch (e) {
    debugPrint('App Check token alınamadı (başlangıç): $e');
  }
}
