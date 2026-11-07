// E-posta/şifre ile giriş ekranı.
import 'package:myvibel/tek_sefer_navigasyon.dart';
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:myvibel/auth_eposta.dart';
import 'package:myvibel/app_theme.dart';
import 'package:myvibel/error_messages.dart';
import 'package:myvibel/apple_giris_servis.dart';
import 'package:myvibel/google_giris_servis.dart';
import 'package:myvibel/register_page.dart';
import 'package:myvibel/kayit_servis.dart';
import 'package:myvibel/widgets/apple_giris_butonu.dart';
import 'package:myvibel/widgets/google_giris_butonu.dart';
import 'package:myvibel/widgets/vibe_gradient_scaffold.dart';
import 'package:myvibel/widgets/vibe_marka_baslik.dart';
import 'package:myvibel/widgets/web_auth_landing.dart';
import 'package:myvibel/vibe_snackbar.dart';

// Ana giriş sayfası
class VibeHomePage extends StatefulWidget {
  const VibeHomePage({super.key});

  @override
  State<VibeHomePage> createState() => _VibeHomePageState();
}

class _VibeHomePageState extends State<VibeHomePage> {
  final TextEditingController emailController =
      TextEditingController(); // E-posta alanı
  final TextEditingController sifreController =
      TextEditingController(); // Şifre alanı

  bool isLoading = false; // Giriş işlemi sürüyor mu
  bool googleYukleniyor = false;
  bool appleYukleniyor = false;

  bool get _sosyalYukleniyor => googleYukleniyor || appleYukleniyor;

  @override
  void dispose() {
    emailController.dispose();
    sifreController.dispose();
    super.dispose();
  }

  // Firebase ile e-posta veya kullanıcı adı + şifre girişi
  Future<void> girisYap() async {
    final kimlikGirdi = emailController.text.trim();
    final sifre = sifreController.text.trim();

    if (kimlikGirdi.isEmpty || sifre.isEmpty) {
      mesajGoster("Lütfen e-posta/kullanıcı adı ve şifre alanlarını doldur.");
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final email = await KayitServis.girisKimliginiCoz(kimlikGirdi);
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: sifre,
      );

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        unawaited(KayitServis.kullaniciAdiGirisEmailiniSenkronla(uid));
      }

      if (!mounted) return;

      vibeSnackbarGoster(context, "Hoş geldin", tip: VibeMesajTipi.basari);
      // AuthControlPage auth dinleyicisi Feed'e geçer.
      // Web'de canPop tarayıcı geçmişinden true olup boş gri ekrana düşürüyor.
    } on FirebaseAuthException catch (e) {
      String mesaj = "Giriş yapılamadı. Biraz sonra tekrar dene.";

      // Hesabın var olup olmadığı belli olmasın: bulunamadı ve yanlış şifre aynı mesaj.
      if (e.code == 'user-not-found' ||
          e.code == 'wrong-password' ||
          e.code == 'invalid-credential' ||
          e.code == 'INVALID_LOGIN_CREDENTIALS') {
        mesaj = "Kullanıcı adı veya şifre hatalı.";
      } else if (e.code == 'invalid-email') {
        mesaj = "Geçerli bir e-posta veya kullanıcı adı gir.";
      } else if (e.code == 'too-many-requests') {
        mesaj = "Çok fazla deneme yapıldı. Biraz sonra tekrar dene.";
      } else if (e.code == 'network-request-failed') {
        mesaj = baglantiUyariMesaji(e);
      }

      debugPrint('Giris Auth hatasi: ${e.code} ${e.message}');
      mesajGoster(mesaj);
    } catch (e) {
      debugPrint('Giris beklenmeyen hata: $e');
      mesajGoster(
        internetAwareErrorMessage(
          error: e,
          fallback: 'Beklenmeyen bir hata oluştu.',
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> googleIleDevam() async {
    setState(() => googleYukleniyor = true);
    try {
      // Her seferinde hesap seçici çıksın.
      final sonuc = await GoogleGirisServis.girisYap(hesabiYenidenSec: true);
      if (!mounted || sonuc == GoogleGirisSonuc.iptal) return;
      // AuthControlPage yönlendirir; web'de pop boş ekran yapıyor.
    } catch (e) {
      await GoogleGirisServis.googleOturumunuKapat();
      if (!mounted) return;
      final mesaj = GoogleGirisServis.hataMesaji(e);
      if (mesaj.isNotEmpty) mesajGoster(mesaj);
    } finally {
      if (mounted) setState(() => googleYukleniyor = false);
    }
  }

  Future<void> appleIleDevam() async {
    setState(() => appleYukleniyor = true);
    try {
      final sonuc = await AppleGirisServis.girisYap();
      if (!mounted || sonuc == AppleGirisSonuc.iptal) return;
      // AuthControlPage yönlendirir; web'de pop boş ekran yapıyor.
    } catch (e) {
      if (!mounted) return;
      final mesaj = AppleGirisServis.hataMesaji(e);
      if (mesaj.isNotEmpty) mesajGoster(mesaj);
    } finally {
      if (mounted) setState(() => appleYukleniyor = false);
    }
  }

  // Snackbar ile mesaj gösterir
  void mesajGoster(String mesaj, {VibeMesajTipi tip = VibeMesajTipi.hata}) {
    vibeSnackbarGoster(context, mesaj, tip: tip);
  }

  Future<void> sifremiUnuttumPaneliniAc() async {
    final emailOnizleme = emailController.text.trim();
    final vibe = context.vibe;
    final theme = Theme.of(context);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _SifremiUnuttumDialog(
        baslangicEmail: emailOnizleme,
        vibe: vibe,
        onSurface: theme.colorScheme.onSurface,
        onBasarili: () {
          if (!mounted) return;
          mesajGoster(
            "Şifre sıfırlama maili gönderildi. Sadece en son gelen maili kullan; "
            "linki kopyalayıp Chrome'da aç. Gmail bazen linke otomatik girer, "
            "o yüzden «süresi dolmuş» hatası çıkabilir.",
            tip: VibeMesajTipi.bilgi,
          );
        },
        onHata: (mesaj) {
          if (!mounted) return;
          mesajGoster(mesaj);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vibe = context.vibe;
    final theme = Theme.of(context);

    final form = AuthEkranYaziOlcegi(
      child: VibeGradientScaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 36),
                const VibeMarkaBaslik(altYazi: 'Hesabına gir'),
                const SizedBox(height: 36),
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 22, 18, 10),
                  decoration: vibe.kahramanKart(radius: 24),
                  child: Column(
                    children: [
                      TextField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autocorrect: false,
                        style: TextStyle(color: theme.colorScheme.onSurface),
                        decoration: vibe.alanDekoru(
                          hint: 'E-posta veya kullanıcı adı',
                          ikon: Icons.person_outline_rounded,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: sifreController,
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) {
                          if (!isLoading && !_sosyalYukleniyor) girisYap();
                        },
                        style: TextStyle(color: theme.colorScheme.onSurface),
                        decoration: vibe.alanDekoru(
                          hint: 'Şifre',
                          ikon: Icons.key_rounded,
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed:
                              isLoading ? null : sifremiUnuttumPaneliniAc,
                          child: Text(
                            "Şifremi unuttum",
                            style: TextStyle(
                              color: vibe.mutedText,
                              fontSize: 13,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed:
                              (isLoading || _sosyalYukleniyor) ? null : girisYap,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: vibe.primaryButton,
                            foregroundColor: Colors.white,
                            shape: const StadiumBorder(),
                            textStyle: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          child: isLoading
                              ? const CircularProgressIndicator(
                                  color: Colors.white)
                              : const Text("Giriş Yap"),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: Divider(color: vibe.cardBorder)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'veya',
                              style: TextStyle(
                                  color: vibe.mutedText, fontSize: 13),
                            ),
                          ),
                          Expanded(child: Divider(color: vibe.cardBorder)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      GoogleGirisButonu(
                        onPressed: (isLoading || _sosyalYukleniyor)
                            ? null
                            : googleIleDevam,
                        yukleniyor: googleYukleniyor,
                      ),
                      if (AppleGirisServis.gorunur) ...[
                        const SizedBox(height: 12),
                        AppleGirisButonu(
                          onPressed: (isLoading || _sosyalYukleniyor)
                              ? null
                              : appleIleDevam,
                          yukleniyor: appleYukleniyor,
                        ),
                      ],
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    tekSeferPush(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RegisterPage(),
                      ),
                    );
                  },
                  child: Text(
                    "Hesabın Yok mu? Kayıt Ol",
                    style: TextStyle(
                      color: vibe.mutedText,
                      fontSize: 14,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return WebAuthLanding(form: form);
  }
}

class _SifremiUnuttumDialog extends StatefulWidget {
  const _SifremiUnuttumDialog({
    required this.baslangicEmail,
    required this.vibe,
    required this.onSurface,
    required this.onBasarili,
    required this.onHata,
  });

  final String baslangicEmail;
  final VibeThemeExtension vibe;
  final Color onSurface;
  final VoidCallback onBasarili;
  final void Function(String mesaj) onHata;

  @override
  State<_SifremiUnuttumDialog> createState() => _SifremiUnuttumDialogState();
}

class _SifremiUnuttumDialogState extends State<_SifremiUnuttumDialog> {
  late final TextEditingController _emailController;
  bool _gonderiliyor = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.baslangicEmail);
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _gonder() async {
    setState(() => _gonderiliyor = true);

    try {
      await sifreSifirlamaMailiGonder(_emailController.text);
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onBasarili();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _gonderiliyor = false);
      widget.onHata(sifreSifirlamaHataMesaji(e));
    } catch (e) {
      if (!mounted) return;
      setState(() => _gonderiliyor = false);
      widget.onHata(
        internetAwareErrorMessage(
          error: e,
          fallback: 'Şifre sıfırlama maili gönderilemedi.',
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: widget.vibe.dialogBackground,
      title: Text('Şifremi unuttum', style: TextStyle(color: widget.onSurface)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Kayıtlı e-posta adresine şifre sıfırlama bağlantısı gönderilir.',
            style: TextStyle(color: widget.vibe.mutedText, fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            enabled: !_gonderiliyor,
            style: TextStyle(color: widget.onSurface),
            decoration: InputDecoration(
              hintText: 'E-posta',
              hintStyle: TextStyle(color: widget.vibe.faintText),
              filled: true,
              fillColor: widget.vibe.inputFill,
              prefixIcon: Icon(Icons.email, color: widget.vibe.mutedText),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _gonderiliyor ? null : () => Navigator.pop(context),
          child: const Text('Vazgeç'),
        ),
        TextButton(
          onPressed: _gonderiliyor ? null : _gonder,
          child: _gonderiliyor
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Gönder'),
        ),
      ],
    );
  }
}
