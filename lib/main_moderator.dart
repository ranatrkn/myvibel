// MyVibel Moderatör Konsolu — Windows / masaüstü girişi.
// Çalıştır: flutter run -d windows -t lib/main_moderator.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_theme.dart';
import 'firebase_bootstrap.dart';
import 'login_page.dart';
import 'moderator_konsol_page.dart';
import 'sosyal/moderasyon_servis.dart';
import 'theme_controller.dart';
import 'widgets/acilis_splash.dart';

late final ThemeController themeController;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ModeratorBootstrapApp());
}

class ModeratorBootstrapApp extends StatefulWidget {
  const ModeratorBootstrapApp({super.key});

  @override
  State<ModeratorBootstrapApp> createState() => _ModeratorBootstrapAppState();
}

class _ModeratorBootstrapAppState extends State<ModeratorBootstrapApp> {
  late final Future<void> _baslatma = _baslat();
  Object? _hata;

  Future<void> _baslat() async {
    try {
      await firebaseGuvenlikBaslat();
      themeController = ThemeController();
      await themeController.load();
    } catch (e) {
      _hata = e;
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _baslatma,
      builder: (context, snapshot) {
        final ok = snapshot.connectionState == ConnectionState.done &&
            _hata == null;
        if (!ok) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: VibeAppTheme.light,
            darkTheme: VibeAppTheme.dark,
            themeMode: ThemeMode.system,
            home: AcilisSplash(
              mesaj: _hata != null
                  ? 'Bağlantı kurulamadı. Uygulamayı yeniden aç.'
                  : null,
            ),
          );
        }

        return ThemeScope(
          controller: themeController,
          child: ListenableBuilder(
            listenable: themeController,
            builder: (context, _) {
              return MaterialApp(
                debugShowCheckedModeBanner: false,
                title: 'MyVibel Mod',
                locale: const Locale('tr', 'TR'),
                supportedLocales: const [Locale('tr', 'TR')],
                localizationsDelegates: const [
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                theme: VibeAppTheme.light,
                darkTheme: VibeAppTheme.dark,
                themeMode: themeController.themeMode,
                home: const ModeratorAuthGate(),
              );
            },
          ),
        );
      },
    );
  }
}

class ModeratorAuthGate extends StatelessWidget {
  const ModeratorAuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AcilisSplash();
        }

        final user = snapshot.data;
        if (user == null) {
          return const VibeHomePage();
        }

        return FutureBuilder<bool>(
          future: ModerasyonServis.moderatorMu(user.uid),
          builder: (context, yetkiSnap) {
            if (yetkiSnap.connectionState != ConnectionState.done) {
              return const AcilisSplash(mesaj: 'Yetki kontrol ediliyor…');
            }
            if (yetkiSnap.data != true) {
              return _YetkisizEkran(
                onCikis: () async {
                  await FirebaseAuth.instance.signOut();
                },
              );
            }
            return ModeratorKonsolPage(
              masaustuModu: true,
              onCikis: () async {
                await FirebaseAuth.instance.signOut();
              },
            );
          },
        );
      },
    );
  }
}

class _YetkisizEkran extends StatelessWidget {
  const _YetkisizEkran({required this.onCikis});

  final VoidCallback onCikis;

  @override
  Widget build(BuildContext context) {
    final vibe = context.vibe;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, size: 48, color: vibe.mutedText),
                const SizedBox(height: 16),
                Text(
                  'Bu hesap moderatör değil.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Firebase’de users belgene isModerator: true eklenmiş olmalı.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: vibe.mutedText),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: onCikis,
                  child: const Text('Çıkış yap'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
