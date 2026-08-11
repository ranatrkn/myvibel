// Oturum durumuna göre giriş veya akış sayfası
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'auth_eposta.dart';
import 'email_dogrulama_page.dart';
import 'feed_page.dart';
import 'firebase_bootstrap.dart';
import 'kayit_servis.dart';
import 'login_page.dart';
import 'theme_controller.dart';

late final ThemeController themeController;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await firebaseGuvenlikBaslat();
  themeController = ThemeController();
  await themeController.load();
  runApp(const VibeLifeApp());
}

class VibeLifeApp extends StatelessWidget {
  const VibeLifeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ThemeScope(
      controller: themeController,
      child: ListenableBuilder(
        listenable: themeController,
        builder: (context, _) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: VibeAppTheme.light,
            darkTheme: VibeAppTheme.dark,
            themeMode: themeController.themeMode,
            home: const AuthControlPage(),
          );
        },
      ),
    );
  }
}

class AuthControlPage extends StatefulWidget {
  const AuthControlPage({super.key});

  @override
  State<AuthControlPage> createState() => _AuthControlPageState();
}

class _AuthControlPageState extends State<AuthControlPage> {
  String? _sonUid;
  Future<Widget>? _sayfaFuture;

  void _oturumSayfasiniYenile() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() {
      _sonUid = user.uid;
      _sayfaFuture = _girisSonrasiSayfa(user);
    });
  }

  Future<Widget> _girisSonrasiSayfa(User user) async {
    if (epostaDogrulamaBekliyorMu(user)) {
      return EmailDogrulamaPage(
        key: ValueKey('verify_${user.uid}'),
        onDogrulandi: _oturumSayfasiniYenile,
      );
    }

    if (await KayitServis.gecersizOturumuTemizle(user)) {
      return const VibeHomePage();
    }

    if (!await KayitServis.profilTamamlandiMi(user.uid)) {
      if (await KayitServis.bekleyenKayitVarMi(user.uid)) {
        await KayitServis.dogrulamaSonrasiKaydiTamamla();
      } else {
        await FirebaseAuth.instance.signOut();
        return const VibeHomePage();
      }
    }

    return FeedPage(key: ValueKey(user.uid));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            FirebaseAuth.instance.currentUser == null) {
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: const Center(
              child: CircularProgressIndicator(color: VibeAppTheme.accent),
            ),
          );
        }

        final user = snapshot.data ?? FirebaseAuth.instance.currentUser;
        if (user == null) {
          _sonUid = null;
          _sayfaFuture = null;
          return const VibeHomePage();
        }

        if (_sonUid != user.uid || _sayfaFuture == null) {
          _sonUid = user.uid;
          _sayfaFuture = _girisSonrasiSayfa(user);
        }

        return FutureBuilder<Widget>(
          future: _sayfaFuture,
          builder: (context, sayfaSnap) {
            if (sayfaSnap.connectionState != ConnectionState.done) {
              return Scaffold(
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                body: const Center(
                  child: CircularProgressIndicator(color: VibeAppTheme.accent),
                ),
              );
            }
            if (sayfaSnap.hasError) {
              return EmailDogrulamaPage(
                key: ValueKey('verify_err_${user.uid}'),
                onDogrulandi: _oturumSayfasiniYenile,
              );
            }
            return sayfaSnap.data ?? const VibeHomePage();
          },
        );
      },
    );
  }
}
