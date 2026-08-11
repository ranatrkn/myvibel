// Yeni kullanıcı kayıt ekranı — profil e-posta doğrulandıktan sonra oluşur.
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:vibe_life/app_theme.dart';
import 'package:vibe_life/error_messages.dart';
import 'package:vibe_life/kayit_servis.dart';
import 'package:vibe_life/legal_pages.dart';
import 'package:vibe_life/widgets/vibe_gradient_scaffold.dart';
import 'package:vibe_life/vibe_snackbar.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController adController = TextEditingController();
  final TextEditingController kullaniciAdController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController sifreController = TextEditingController();
  final TextEditingController sifreTekrarController = TextEditingController();

  bool isLoading = false;
  bool gizlilikOnayi = false;

  @override
  void dispose() {
    adController.dispose();
    kullaniciAdController.dispose();
    emailController.dispose();
    sifreController.dispose();
    sifreTekrarController.dispose();
    super.dispose();
  }

  String kullaniciAdiniTemizle(String value) {
    return value.trim().toLowerCase();
  }

  bool kullaniciAdiGecerliMi(String kullaniciAdi) {
    final regex = RegExp(r'^[a-z0-9_\.]+$');
    return regex.hasMatch(kullaniciAdi);
  }

  Future<void> kayitOl() async {
    final adSoyad = adController.text.trim();
    final kullaniciAdi = kullaniciAdController.text.trim();
    final kullaniciAdiKucuk = kullaniciAdiniTemizle(kullaniciAdi);
    final email = emailController.text.trim();
    final sifre = sifreController.text;
    final sifreTekrar = sifreTekrarController.text;

    if (adSoyad.isEmpty ||
        kullaniciAdi.isEmpty ||
        email.isEmpty ||
        sifre.isEmpty ||
        sifreTekrar.isEmpty) {
      mesajGoster('Lütfen tüm alanları doldur.');
      return;
    }

    if (kullaniciAdiKucuk.length < 3) {
      mesajGoster('Kullanıcı adı en az 3 karakter olmalı.');
      return;
    }

    if (!kullaniciAdiGecerliMi(kullaniciAdiKucuk)) {
      mesajGoster(
        'Kullanıcı adında sadece harf, sayı, nokta ve alt çizgi kullan.',
      );
      return;
    }

    if (sifre != sifreTekrar) {
      mesajGoster('Şifreler birbiriyle eşleşmiyor.');
      return;
    }

    if (sifre.length < 6) {
      mesajGoster('Şifre en az 6 karakter olmalı.');
      return;
    }

    if (!gizlilikOnayi) {
      mesajGoster('Kayıt için Gizlilik Politikası ve KVKK metnini onaylamalısın.');
      return;
    }

    setState(() => isLoading = true);

    try {
      final mailHatasi = await KayitServis.bekleyenKayitOlustur(
        adSoyad: adSoyad,
        kullaniciAdi: kullaniciAdi,
        kullaniciAdiKucuk: kullaniciAdiKucuk,
        email: email,
        sifre: sifre,
      );

      if (!mounted) return;
      if (mailHatasi == null) {
        mesajGoster(
          'Doğrulama e-postası gönderildi. Gelen kutunu, spam ve promosyon klasörünü kontrol et.',
          tip: VibeMesajTipi.basari,
        );
      } else {
        mesajGoster(
          'Kayıt tamam ama e-posta gönderilemedi: $mailHatasi\nDoğrulama ekranından tekrar dene.',
          tip: VibeMesajTipi.uyari,
        );
      }
      Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      String mesaj = 'Kayıt yapılamadı.';
      if (e.code == 'weak-password') {
        mesaj = 'Şifre çok zayıf.';
      } else if (e.code == 'email-already-in-use') {
        mesaj = 'Bu e-posta adresi zaten kayıtlı.';
      } else if (e.code == 'invalid-email') {
        mesaj = 'Geçersiz bir e-posta adresi girdiniz.';
      } else if (e.code == 'operation-not-allowed') {
        mesaj = 'E-posta/şifre ile kayıt şu anda kullanılamıyor.';
      } else if (e.code == 'network-request-failed') {
        mesaj = 'İnternet bağlantısı kurulamadı.';
      } else if (e.code == 'too-many-requests') {
        mesaj = 'Çok fazla kayıt denemesi yapıldı. Biraz bekleyip tekrar dene.';
      }
      mesajGoster(mesaj);
    } catch (e) {
      final metin = e.toString();
      if (metin.contains('kullanıcı adı') || e is String) {
        mesajGoster(metin.replaceFirst('Exception: ', ''));
      } else {
        mesajGoster(
          internetAwareErrorMessage(
            error: e,
            fallback: 'Kayıt sırasında bir hata oluştu.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void mesajGoster(String mesaj, {VibeMesajTipi tip = VibeMesajTipi.hata}) {
    vibeSnackbarGoster(context, mesaj, tip: tip);
  }

  @override
  Widget build(BuildContext context) {
    final vibe = context.vibe;

    return VibeGradientScaffold(
      appBar: AppBar(
        title: const Text('VibeLife Seni Bekliyor'),
        backgroundColor: vibe.primaryButton.withOpacity(0.9),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            children: [
              const SizedBox(height: 50),
              _inputKutusu(
                controller: adController,
                hintText: 'Ad Soyad',
                icon: Icons.person,
              ),
              _inputKutusu(
                controller: kullaniciAdController,
                hintText: 'Kullanıcı Adı',
                icon: Icons.alternate_email,
              ),
              _inputKutusu(
                controller: emailController,
                hintText: 'E-posta',
                icon: Icons.email,
                keyboardType: TextInputType.emailAddress,
              ),
              _inputKutusu(
                controller: sifreController,
                hintText: 'Şifre',
                icon: Icons.lock,
                obscureText: true,
              ),
              _inputKutusu(
                controller: sifreTekrarController,
                hintText: 'Şifre Tekrar',
                icon: Icons.lock_outline,
                obscureText: true,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CheckboxListTile(
                      value: gizlilikOnayi,
                      contentPadding: EdgeInsets.zero,
                      activeColor: vibe.primaryButton,
                      title: const Text(
                        'Gizlilik Politikası ve KVKK metnini okudum, kabul ediyorum.',
                        style: TextStyle(fontSize: 12),
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (v) {
                        setState(() => gizlilikOnayi = v == true);
                      },
                    ),
                    Wrap(
                      spacing: 6,
                      children: [
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const PrivacyPolicyPage(),
                              ),
                            );
                          },
                          child: const Text('Gizlilik Politikası'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const KvkkPage(),
                              ),
                            );
                          },
                          child: const Text('KVKK Aydınlatma'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 10),
                child: ElevatedButton(
                  onPressed: isLoading ? null : kayitOl,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: vibe.primaryButton,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 55),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 10,
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        )
                      : const Text(
                          'KAYIT OL',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Zaten hesabın var mı? Giriş Yap',
                  style: TextStyle(
                    color: vibe.mutedText,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _inputKutusu({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
  }) {
    final vibe = context.vibe;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 10),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: TextStyle(color: theme.colorScheme.onSurface),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: vibe.mutedText),
          filled: true,
          fillColor: vibe.inputFill,
          prefixIcon: Icon(icon, color: vibe.mutedText),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide(color: vibe.cardBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide(color: vibe.cardBorder),
          ),
        ),
      ),
    );
  }
}
