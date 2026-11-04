// E-posta doğrulama bekleme ekranı (Firebase doğrulama linki).
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:myvibel/app_theme.dart';
import 'package:myvibel/auth_eposta.dart';
import 'package:myvibel/error_messages.dart';
import 'package:myvibel/kayit_servis.dart';
import 'package:myvibel/vibe_snackbar.dart';
import 'package:myvibel/yasal_icerik.dart';
import 'package:myvibel/widgets/vibe_gradient_scaffold.dart';
import 'package:myvibel/widgets/vibe_marka_baslik.dart';

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
        _mesajGoster('E-posta doğrulandı. Hoş geldin!',
            tip: VibeMesajTipi.basari);
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
      if (FirebaseAuth.instance.currentUser?.emailVerified == true) {
        await _dogrulamayiKontrolEt();
        return;
      }
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

  Future<String?> _iptalSifresiSor() async {
    final kontrol = TextEditingController();
    final sonuc = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kaydı iptal et'),
        content: TextField(
          controller: kontrol,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Kayıt şifren',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, kontrol.text),
            child: const Text('Hesabı sil'),
          ),
        ],
      ),
    );
    kontrol.dispose();
    return sonuc;
  }

  Future<void> _cikisYap() async {
    try {
      await KayitServis.bekleyenKayitIptal();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      if (e.code != 'requires-recent-login') {
        _mesajGoster(epostaDegistirmeHataMesaji(e));
        return;
      }
      final sifre = await _iptalSifresiSor();
      if (!mounted || sifre == null || sifre.isEmpty) return;
      try {
        await KayitServis.bekleyenKayitIptal(mevcutSifre: sifre);
      } on FirebaseAuthException catch (e2) {
        if (!mounted) return;
        _mesajGoster(
          e2.code == 'wrong-password' || e2.code == 'invalid-credential'
              ? 'Şifre hatalı. Hesap silinmedi.'
              : epostaDegistirmeHataMesaji(e2),
        );
      }
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

    return AuthEkranYaziOlcegi(
      child: VibeGradientScaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              children: [
                const SizedBox(height: 28),
                const VibeMarkaBaslik(
                  ikonBoyut: 72,
                  yaziBoyut: 28,
                  altYazi: 'E-postanı doğrula',
                ),
                const SizedBox(height: 20),
                Text(
                  "$email adresine doğrulama linki gönderdik.\n\n"
                  "Gmail kullanıyorsan Promosyonlar ve Spam klasörüne de bak. "
                  "Gönderen: destek@myvibel.com\n\n"
                  "${YasalIcerik.uygulamaAdi} profilin, e-postanı onaylayıp «Doğruladım, kontrol et» "
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
      ),
    );
  }
}
