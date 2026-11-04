// Oturum durumuna göre giriş veya akış sayfası
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme.dart';
import 'auth_eposta.dart';
import 'email_dogrulama_page.dart';
import 'feed_page.dart';
import 'firebase_bootstrap.dart';
import 'google_giris_servis.dart';
import 'google_profil_tamamlama_page.dart';
import 'google_sifre_belirle_page.dart';
import 'kayit_servis.dart';
import 'login_page.dart';
import 'reklam_servis.dart';
import 'sosyal_oauth.dart';
import 'theme_controller.dart';
import 'widgets/acilis_splash.dart';
import 'widgets/web_shell.dart';
import 'yas_hesap_kontrol.dart';

late final ThemeController themeController;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Release web'de gri boş ekran yerine hatayı göster.
  if (kIsWeb) {
    ErrorWidget.builder = (FlutterErrorDetails details) {
      return Directionality(
        textDirection: TextDirection.ltr,
        child: Material(
          color: const Color(0xFF1A002E),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Ekran hatası:\n\n${details.exceptionAsString()}',
                style: const TextStyle(
                  color: Color(0xFFFFAB91),
                  fontSize: 14,
                  height: 1.35,
                ),
              ),
            ),
          ),
        ),
      );
    };
  }
  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
    ]);
  }
  runApp(const BootstrapApp());
}

class BootstrapApp extends StatefulWidget {
  const BootstrapApp({super.key});

  @override
  State<BootstrapApp> createState() => _BootstrapAppState();
}

class _BootstrapAppState extends State<BootstrapApp> {
  late final Future<void> _baslatmaFuture = _uygulamayiBaslat();
  Object? _baslatmaHatasi;

  Future<void> _uygulamayiBaslat() async {
    try {
      await firebaseGuvenlikBaslat();
      themeController = ThemeController();
      await themeController.load();
      unawaited(ReklamServis.baslat());
      // Oturum yoksa ilk kareden itibaren tam genişlik (480 flash yok).
      webShellController = WebShellController(
        baslangicGenis: FirebaseAuth.instance.currentUser == null,
      );
    } catch (e) {
      _baslatmaHatasi = e;
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _baslatmaFuture,
      builder: (context, snapshot) {
        final tamamlandi =
            snapshot.connectionState == ConnectionState.done && _baslatmaHatasi == null;

        if (tamamlandi) {
          return const MyVibelApp();
        }

        return MaterialApp(
          title: 'MyVibel',
          debugShowCheckedModeBanner: false,
          theme: VibeAppTheme.light,
          darkTheme: VibeAppTheme.dark,
          themeMode: ThemeMode.dark,
          builder: (context, child) {
            final body = child ?? const SizedBox.shrink();
            if (!kIsWeb) return body;
            // Splash'ta 480 kullanma — giriş ekranına geçince geniş flash olmasın.
            final isDark =
                Theme.of(context).brightness == Brightness.dark;
            return ColoredBox(
              color: isDark
                  ? const Color(0xFF0B0614)
                  : const Color(0xFFFDFBFF),
              child: body,
            );
          },
          home: AcilisSplash(
            mesaj: _baslatmaHatasi != null
                ? 'Bağlantı kurulamadı. Uygulamayı yeniden aç.'
                : null,
          ),
        );
      },
    );
  }
}

class MyVibelApp extends StatelessWidget {
  const MyVibelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ThemeScope(
      controller: themeController,
      child: ListenableBuilder(
        listenable: themeController,
        builder: (context, _) {
          return MaterialApp(
            title: 'MyVibel',
            debugShowCheckedModeBanner: false,
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
            builder: (context, child) {
              final styled = DefaultTextStyle.merge(
                style: const TextStyle(
                  fontFamily: VibeAppTheme.fontFamily,
                  fontWeight: FontWeight.w500,
                  fontVariations: [
                    FontVariation('wght', 500),
                  ],
                ),
                child: child ?? const SizedBox.shrink(),
              );
              // Auth: tam genişlik. Uygulama: tam genişlik (FeedPage responsive).
              if (!kIsWeb) return styled;
              return ListenableBuilder(
                listenable: webShellController,
                builder: (context, _) {
                  final isDark =
                      Theme.of(context).brightness == Brightness.dark;
                  return ColoredBox(
                    color: isDark
                        ? const Color(0xFF0B0614)
                        : const Color(0xFFFDFBFF),
                    child: styled,
                  );
                },
              );
            },
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
  StreamSubscription<User?>? _authAbonelik;
  String? _cozulenUid;
  Widget _govde = const SizedBox.shrink();
  bool _yukleniyor = true;

  @override
  void initState() {
    super.initState();
    _authAbonelik =
        FirebaseAuth.instance.authStateChanges().listen(_oturumuIsle);
    unawaited(_oturumuIsle(FirebaseAuth.instance.currentUser));
  }

  @override
  void dispose() {
    _authAbonelik?.cancel();
    super.dispose();
  }

  void _oturumSayfasiniYenile() {
    _cozulenUid = null;
    unawaited(_oturumuIsle(FirebaseAuth.instance.currentUser));
  }

  Future<void> _oturumuIsle(User? user) async {
    if (user == null) {
      webShellAuthMi(true);
      if (!mounted) return;
      setState(() {
        _cozulenUid = null;
        _yukleniyor = false;
        _govde = const VibeHomePage();
      });
      return;
    }

    // Oturum açık: uygulama kabuğu (responsive FeedPage).
    webShellAuthMi(false);

    // Aynı uid ile yükleme sürerken çift çağrıyı engelle; aksi halde
    // Google ile yeniden girişte profil/Feed yönünü tekrar çöz.
    if (user.uid == _cozulenUid && _yukleniyor) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final onbellekProfil =
        prefs.getBool(KayitServis.profilOnbellekAnahtari(user.uid)) == true;

    if (onbellekProfil) {
      // Önbellek olsa bile şifresiz Google hesabını Feed'e alma.
      if (SosyalOAuth.sifreEksikMi(user)) {
        if (!mounted) return;
        setState(() {
          _cozulenUid = user.uid;
          _yukleniyor = false;
          _govde = GoogleSifreBelirlePage(
            key: ValueKey('google_sifre_${user.uid}'),
            onTamamlandi: _oturumSayfasiniYenile,
          );
        });
        return;
      }
      if (!mounted) return;
      setState(() {
        _cozulenUid = user.uid;
        _yukleniyor = false;
        _govde = YasHesapKapsayici(
          child: FeedPage(key: ValueKey(user.uid)),
        );
      });
      unawaited(KayitServis.kullaniciAdiGirisEmailiniSenkronla(user.uid));
      unawaited(_oturumArkaplanDogrula(user));
      return;
    }

    if (!mounted) return;
    setState(() {
      _cozulenUid = user.uid;
      _yukleniyor = true;
    });

    try {
      final sayfa = await _girisSonrasiSayfa(user).timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          debugPrint('girisSonrasiSayfa timeout — web Firestore yavaş');
          if (SosyalOAuth.oauthMu(user)) {
            return GoogleProfilTamamlamaPage(
              key: ValueKey('google_profil_to_${user.uid}'),
              onTamamlandi: _oturumSayfasiniYenile,
            );
          }
          // Profil önbelleği yoksa bile Feed'e dene; feed kendi hatalarını gösterir.
          return YasHesapKapsayici(
            child: FeedPage(key: ValueKey(user.uid)),
          );
        },
      );
      if (!mounted) return;
      webShellAuthMi(sayfa is VibeHomePage);
      setState(() {
        _yukleniyor = false;
        _govde = sayfa;
      });
    } catch (e) {
      debugPrint('Giris sonrasi sayfa hatasi: $e');
      if (!mounted) return;
      // Google/Apple kullanıcılarını e-posta doğrulama ekranına düşürme.
      if (SosyalOAuth.oauthMu(user)) {
        setState(() {
          _yukleniyor = false;
          _govde = GoogleProfilTamamlamaPage(
            key: ValueKey('google_profil_err_${user.uid}'),
            onTamamlandi: _oturumSayfasiniYenile,
          );
        });
        return;
      }
      setState(() {
        _yukleniyor = false;
        _govde = EmailDogrulamaPage(
          key: ValueKey('verify_err_${user.uid}'),
          onDogrulandi: _oturumSayfasiniYenile,
        );
      });
    }
  }

  Future<void> _oturumArkaplanDogrula(User user) async {
    try {
      if (epostaDogrulamaBekliyorMu(user)) {
        final bekleyenVar = await KayitServis.bekleyenKayitVarMi(user.uid);
        if (bekleyenVar &&
            await KayitServis.bekleyenKayitSuresiDolmusMu(user.uid)) {
          await KayitServis.bekleyenKayitIptal();
          if (!mounted) return;
          webShellAuthMi(true);
          setState(() {
            _cozulenUid = null;
            _govde = const VibeHomePage();
          });
          return;
        }
        if (!mounted) return;
        setState(() {
          _govde = EmailDogrulamaPage(
            key: ValueKey('verify_${user.uid}'),
            onDogrulandi: _oturumSayfasiniYenile,
          );
        });
        return;
      }

      if (!user.emailVerified) {
        if (await KayitServis.gecersizOturumuTemizle(user)) {
          if (!mounted) return;
          webShellAuthMi(true);
          setState(() {
            _cozulenUid = null;
            _govde = const VibeHomePage();
          });
          return;
        }
      }

      final profilVar = await KayitServis.profilTamamlandiMi(user.uid);
      if (profilVar) {
        await KayitServis.profilTamamlandiOnbellegeAl(user.uid);
        if (SosyalOAuth.sifreEksikMi(user)) {
          if (!mounted) return;
          setState(() {
            _govde = GoogleSifreBelirlePage(
              key: ValueKey('google_sifre_${user.uid}'),
              onTamamlandi: _oturumSayfasiniYenile,
            );
          });
        }
        return;
      }

      if (await KayitServis.bekleyenKayitVarMi(user.uid)) {
        await KayitServis.dogrulamaSonrasiKaydiTamamla();
        await KayitServis.profilTamamlandiOnbellegeAl(user.uid);
        return;
      }

      await KayitServis.profilOnbelleginiTemizle(user.uid);
      if (SosyalOAuth.oauthMu(user)) {
        if (!mounted) return;
        setState(() {
          _govde = GoogleProfilTamamlamaPage(
            key: ValueKey('google_profil_${user.uid}'),
            onTamamlandi: _oturumSayfasiniYenile,
          );
        });
        return;
      }
      await GoogleGirisServis.oturumuKapat();
    } catch (e) {
      debugPrint('Arkaplan oturum dogrulama: $e');
    }
  }

  Future<Widget> _girisSonrasiSayfa(User user) async {
    if (epostaDogrulamaBekliyorMu(user)) {
      final bekleyenVar = await KayitServis.bekleyenKayitVarMi(user.uid);
      if (bekleyenVar &&
          await KayitServis.bekleyenKayitSuresiDolmusMu(user.uid)) {
        await KayitServis.bekleyenKayitIptal();
        return const VibeHomePage();
      }
      // Pending yokken de doğrulama ekranı — kayıt yazımı yarışında hesabı silme.
      return EmailDogrulamaPage(
        key: ValueKey('verify_${user.uid}'),
        onDogrulandi: _oturumSayfasiniYenile,
      );
    }

    if (!user.emailVerified) {
      if (await KayitServis.gecersizOturumuTemizle(user)) {
        return const VibeHomePage();
      }
    }

    // Önce Firestore profili — varsa giriş (Feed / şifre belirle).
    final profilVar = await KayitServis.profilTamamlandiMi(user.uid);
    if (profilVar) {
      await KayitServis.profilTamamlandiOnbellegeAl(user.uid);
      unawaited(KayitServis.hassasProfiliAyir(user.uid));
      unawaited(KayitServis.kullaniciAdiGirisEmailiniSenkronla(user.uid));
      if (SosyalOAuth.sifreEksikMi(user)) {
        return GoogleSifreBelirlePage(
          key: ValueKey('google_sifre_${user.uid}'),
          onTamamlandi: _oturumSayfasiniYenile,
        );
      }
      return YasHesapKapsayici(
        child: FeedPage(key: ValueKey(user.uid)),
      );
    }

    if (await KayitServis.bekleyenKayitVarMi(user.uid)) {
      await KayitServis.dogrulamaSonrasiKaydiTamamla();
      await KayitServis.profilTamamlandiOnbellegeAl(user.uid);
      return YasHesapKapsayici(
        child: FeedPage(key: ValueKey(user.uid)),
      );
    }

    await KayitServis.profilOnbelleginiTemizle(user.uid);
    if (SosyalOAuth.oauthMu(user)) {
      // Profil yok → OAuth kayıt / profil tamamlama.
      return GoogleProfilTamamlamaPage(
        key: ValueKey('google_profil_${user.uid}'),
        onTamamlandi: _oturumSayfasiniYenile,
      );
    }
    await GoogleGirisServis.oturumuKapat();
    return const VibeHomePage();
  }

  @override
  Widget build(BuildContext context) {
    if (_yukleniyor) {
      return const AuthEkranYaziOlcegi(child: AcilisSplash());
    }
    return _govde;
  }
}
