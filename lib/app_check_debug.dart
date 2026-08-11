// App Check debug token enjeksiyonu ve test menüsü.
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_check_config.dart';

String? appCheckDebugTokenOnbellek;
String? appCheckDebugSonHata;

/// Android: Console'dan alınan sabit token'ı native tarafta kaydeder.
/// Firebase.initializeApp'ten ÖNCE çağrılmalı.
Future<void> appCheckDebugTokenEnjekteEt() async {
  if (!appCheckBetaModu || appCheckDebugTokenSabit.isEmpty) return;
  if (defaultTargetPlatform != TargetPlatform.android) return;

  try {
    await const MethodChannel('vibe_life/app_check').invokeMethod<void>(
      'setDebugToken',
      appCheckDebugTokenSabit,
    );
    appCheckDebugTokenOnbellek = appCheckDebugTokenSabit;
    debugPrint('App Check sabit debug token enjekte edildi.');
  } catch (e) {
    appCheckDebugSonHata = e.toString();
    debugPrint('App Check debug token enjekte edilemedi: $e');
  }
}

/// Mevcut App Check token'ını okur (zorla yenilemez).
Future<String?> appCheckDebugTokenOku() async {
  if (!appCheckBetaModu) return null;

  if (appCheckDebugTokenSabit.isNotEmpty) {
    return appCheckDebugTokenSabit;
  }

  if (appCheckDebugTokenOnbellek != null && appCheckDebugTokenOnbellek!.isNotEmpty) {
    return appCheckDebugTokenOnbellek;
  }

  try {
    final token = await FirebaseAppCheck.instance.getToken(false);
    if (token != null && token.isNotEmpty) {
      appCheckDebugTokenOnbellek = token;
      appCheckDebugSonHata = null;
      return token;
    }
    appCheckDebugSonHata = 'Boş token döndü.';
  } catch (e) {
    appCheckDebugSonHata = e.toString();
    debugPrint('App Check token okunamadı: $e');
  }

  return null;
}

Future<void> appCheckDebugTokenGoster(BuildContext context) async {
  if (!context.mounted) return;

  showDialog<void>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: const Text('App Check Token'),
        content: FutureBuilder<String?>(
          future: appCheckDebugTokenOku(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 48,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final token = snapshot.data;
            if (token == null || token.isEmpty) {
              final cokDeneme = (appCheckDebugSonHata ?? '')
                  .toLowerCase()
                  .contains('too many attempts');

              return Text(
                cokDeneme
                    ? 'Çok fazla deneme yapıldı (Too many attempts).\n\n'
                        'Çözüm — Console\'dan token oluşturun:\n'
                        '1) Firebase > App Check > android > ⋮ > '
                        'Manage debug tokens > Add debug token\n'
                        '2) Oluşan kodu lib/app_check_config.dart içindeki '
                        'appCheckDebugTokenSabit alanına yapıştırın\n'
                        '3) flutter run ile yeniden kurun\n'
                        '4) 30 dakika bu menüye girmeyin'
                    : 'Token alınamadı.\n\n'
                        'Hata: ${appCheckDebugSonHata ?? "Bilinmeyen"}\n\n'
                        'app_check_config.dart dosyasına Console\'dan '
                        'oluşturduğunuz debug token\'ı yapıştırın.',
              );
            }

            if (appCheckDebugTokenSabit.isNotEmpty) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sabit debug token aktif. Console\'da aynı token '
                    'kayıtlı olmalı:',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  SelectableText(
                    token,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ],
              );
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bu kodu Firebase Console > App Check > android > ⋮ > '
                  'Manage debug tokens bölümüne ekleyin:',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 12),
                SelectableText(
                  token,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Kapat'),
          ),
          if (appCheckDebugTokenSabit.isEmpty)
            FilledButton(
              onPressed: () async {
                final token = await appCheckDebugTokenOku();
                if (token == null || token.isEmpty) return;
                await Clipboard.setData(ClipboardData(text: token));
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Token kopyalandı. Firebase Console\'a ekleyin.',
                      ),
                    ),
                  );
                }
              },
              child: const Text('Kopyala'),
            ),
        ],
      );
    },
  );
}
