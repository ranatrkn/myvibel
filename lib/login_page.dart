// E-posta/şifre ile giriş ekranı.
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:vibe_life/auth_eposta.dart';
import 'package:vibe_life/app_theme.dart';
import 'package:vibe_life/error_messages.dart';
import 'package:vibe_life/register_page.dart';
import 'package:vibe_life/widgets/vibe_gradient_scaffold.dart';
import 'package:vibe_life/vibe_snackbar.dart';

// Ana giriş sayfası
class VibeHomePage extends StatefulWidget {
  const VibeHomePage({super.key});

  @override
  State<VibeHomePage> createState() => _VibeHomePageState();
}

class _VibeHomePageState extends State<VibeHomePage> {
  final TextEditingController emailController = TextEditingController(); // E-posta alanı
  final TextEditingController sifreController = TextEditingController(); // Şifre alanı

  bool isLoading = false; // Giriş işlemi sürüyor mu

  @override
  void dispose() {
    emailController.dispose();
    sifreController.dispose();
    super.dispose();
  }

  // Firebase ile e-posta/şifre girişi
  Future<void> girisYap() async {
    final email = emailController.text.trim();
    final sifre = sifreController.text.trim();

    if (email.isEmpty || sifre.isEmpty) {
      mesajGoster("Lütfen e-posta ve şifre alanlarını doldur.");
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: sifre,
      );

      if (!mounted) return;

      vibeSnackbarGoster(context, "Hoş geldin", tip: VibeMesajTipi.basari);
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      String mesaj = "Giriş yapılamadı.";

      if (e.code == 'user-not-found') {
        mesaj = "Bu e-posta ile kayıtlı kullanıcı bulunamadı.";
      } else if (e.code == 'wrong-password') {
        mesaj = "Şifre hatalı.";
      } else if (e.code == 'invalid-email') {
        mesaj = "Geçerli bir e-posta adresi gir.";
      } else if (e.code == 'invalid-credential') {
        mesaj = "E-posta veya şifre hatalı.";
      } else if (e.code == 'network-request-failed') {
        mesaj = "internet bağlantısı yok";
      }

      mesajGoster(mesaj);
    } catch (e) {
      mesajGoster(
        internetAwareErrorMessage(
          error: e,
          fallback: "Beklenmeyen bir hata oluştu.",
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

    return VibeGradientScaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 80),
              Text(
                "VibeLife",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 52,
                  fontWeight: FontWeight.w900,
                  color: vibe.titleOnGradient,
                  letterSpacing: 6.0,
                  shadows: vibe.isDark
                      ? const [
                          Shadow(
                            blurRadius: 10.0,
                            color: Colors.black45,
                            offset: Offset(3.0, 3.0),
                          ),
                        ]
                      : null,
                ),
              ),
              const SizedBox(height: 160),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                style: TextStyle(color: theme.colorScheme.onSurface),
                decoration: InputDecoration(
                  hintText: "E-posta",
                  hintStyle: TextStyle(color: vibe.mutedText),
                  filled: true,
                  fillColor: vibe.inputFill,
                  prefixIcon: Icon(Icons.email, color: vibe.mutedText),
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
              const SizedBox(height: 40),
              TextField(
                controller: sifreController,
                obscureText: true,
                style: TextStyle(color: theme.colorScheme.onSurface),
                decoration: InputDecoration(
                  hintText: "Şifre",
                  hintStyle: TextStyle(color: vibe.mutedText),
                  filled: true,
                  fillColor: vibe.inputFill,
                  prefixIcon: Icon(Icons.key, color: vibe.mutedText),
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
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: isLoading ? null : sifremiUnuttumPaneliniAc,
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
                  onPressed: isLoading ? null : girisYap,
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
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Giriş Yap"),
                ),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () {
                  Navigator.push(
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
    );
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
