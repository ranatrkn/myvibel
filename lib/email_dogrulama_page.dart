// E-posta doğrulama bekleme ekranı (Firebase doğrulama linki).
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:vibe_life/app_theme.dart';
import 'package:vibe_life/auth_eposta.dart';
import 'package:vibe_life/error_messages.dart';
import 'package:vibe_life/kayit_servis.dart';
import 'package:vibe_life/vibe_snackbar.dart';
import 'package:vibe_life/widgets/vibe_gradient_scaffold.dart';

class EmailDogrulamaPage extends StatefulWidget {
  final VoidCallback onDogrulandi;

  const EmailDogrulamaPage({
    super.key,
    required this.onDogrulandi,
  });

  @override
  State<EmailDogrulamaPage> createState() => _EmailDogrulamaPageState();
}

class _EmailDogrulamaPageState extends State<EmailDogrulamaPage> {
  bool _kontrolSuruyor = false;
  bool _gonderimSuruyor = false;
  int _tekrarGondermeSaniye = 0;
  String? _gonderimDurumu;

  User? get _user => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _tekrarGondermeSayaciniBaslat();
  }

  void _tekrarGondermeSayaciniBaslat() {
    setState(() => _tekrarGondermeSaniye = 60);
    Future<void>.delayed(const Duration(seconds: 1), _sayacTick);
  }

  void _sayacTick() {
    if (!mounted || _tekrarGondermeSaniye <= 0) return;
    setState(() => _tekrarGondermeSaniye--);
    if (_tekrarGondermeSaniye > 0) {
      Future<void>.delayed(const Duration(seconds: 1), _sayacTick);
    }
  }

  void _mesajGoster(String mesaj, {VibeMesajTipi tip = VibeMesajTipi.hata}) {
    vibeSnackbarGoster(context, mesaj, tip: tip);
  }

  Future<void> _dogrulamayiKontrolEt() async {
    final user = _user;
    if (user == null) return;

    setState(() => _kontrolSuruyor = true);
    try {
      final dogrulandi = await epostaDogrulamaDurumunuYenile(user);
      if (!mounted) return;
      if (dogrulandi) {
        try {
          await KayitServis.dogrulamaSonrasiKaydiTamamla();
        } catch (e) {
          if (!mounted) return;
          _mesajGoster(
            e is String
                ? e
                : internetAwareErrorMessage(
                    error: e,
                    fallback: 'Kayıt tamamlanamadı.',
                  ),
          );
          return;
        }
        if (!mounted) return;
        _mesajGoster('E-posta doğrulandı. Hoş geldin!', tip: VibeMesajTipi.basari);
        widget.onDogrulandi();
      } else {
        _mesajGoster(
          "E-posta henüz doğrulanmamış. Gelen kutunu ve spam klasörünü kontrol et.",
          tip: VibeMesajTipi.uyari,
        );
      }
    } catch (e) {
      if (!mounted) return;
      _mesajGoster(
        internetAwareErrorMessage(
          error: e,
          fallback: "Doğrulama durumu kontrol edilemedi.",
        ),
      );
    } finally {
      if (mounted) setState(() => _kontrolSuruyor = false);
    }
  }

  Future<void> _mailiTekrarGonder() async {
    final user = _user;
    if (user == null || _tekrarGondermeSaniye > 0) return;

    setState(() => _gonderimSuruyor = true);
    try {
      await epostaDogrulamaMailiGonder(user);
      if (!mounted) return;
      setState(() {
        _gonderimDurumu =
            'Son gönderim: başarılı (${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')})';
      });
      _mesajGoster(
        'Doğrulama e-postası gönderildi. Spam klasörünü de kontrol et.',
        tip: VibeMesajTipi.basari,
      );
      _tekrarGondermeSayaciniBaslat();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final mesaj = epostaGonderimHataMesaji(e);
      setState(() => _gonderimDurumu = 'Son gönderim: başarısız — $mesaj');
      _mesajGoster(mesaj);
    } catch (e) {
      if (!mounted) return;
      _mesajGoster(
        internetAwareErrorMessage(
          error: e,
          fallback: "E-posta gönderilemedi.",
        ),
      );
    } finally {
      if (mounted) setState(() => _gonderimSuruyor = false);
    }
  }

  Future<void> _cikisYap() async {
    try {
      await KayitServis.bekleyenKayitIptal();
    } catch (e) {
      if (!mounted) return;
      _mesajGoster(
        internetAwareErrorMessage(
          error: e,
          fallback: 'Çıkış yapılamadı.',
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vibe = context.vibe;
    final theme = Theme.of(context);
    final email = _user?.email ?? '';

    return VibeGradientScaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const SizedBox(height: 48),
              Icon(
                Icons.mark_email_unread_outlined,
                size: 72,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                "E-postanı doğrula",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: vibe.titleOnGradient,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "$email adresine doğrulama linki gönderdik.\n\n"
                "Gmail kullanıyorsan Promosyonlar ve Spam klasörüne de bak. "
                "Gönderen: noreply@vibe-life-app.firebaseapp.com\n\n"
                "VibeLife profilin, e-postanı onaylayıp «Doğruladım, kontrol et» "
                "dedikten sonra oluşur.\n\n"
                "Mail gelmediyse «Doğrulama e-postasını tekrar gönder» butonunu kullan.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: vibe.mutedText,
                  fontSize: 15,
                  height: 1.45,
                ),
              ),
              if (_gonderimDurumu != null) ...[
                const SizedBox(height: 12),
                Text(
                  _gonderimDurumu!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: vibe.mutedText,
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _kontrolSuruyor ? null : _dogrulamayiKontrolEt,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: vibe.primaryButton,
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                  ),
                  child: _kontrolSuruyor
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          "Doğruladım, kontrol et",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: (_gonderimSuruyor || _tekrarGondermeSaniye > 0)
                      ? null
                      : _mailiTekrarGonder,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.onSurface,
                    side: BorderSide(color: vibe.cardBorder),
                    shape: const StadiumBorder(),
                  ),
                  child: _gonderimSuruyor
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          _tekrarGondermeSaniye > 0
                              ? "Tekrar gönder ($_tekrarGondermeSaniye sn)"
                              : "Doğrulama e-postasını tekrar gönder",
                        ),
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: _cikisYap,
                child: Text(
                  'Kaydı iptal et',
                  style: TextStyle(color: vibe.mutedText),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
