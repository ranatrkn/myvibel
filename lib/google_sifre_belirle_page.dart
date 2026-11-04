// Eski Google hesaplarında eksik şifreyi zorunlu belirleme.
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:myvibel/app_theme.dart';
import 'package:myvibel/error_messages.dart';
import 'package:myvibel/apple_giris_servis.dart';
import 'package:myvibel/google_giris_servis.dart';
import 'package:myvibel/sosyal_oauth.dart';
import 'package:myvibel/vibe_snackbar.dart';
import 'package:myvibel/widgets/vibe_gradient_scaffold.dart';
import 'package:myvibel/widgets/vibe_marka_baslik.dart';

class GoogleSifreBelirlePage extends StatefulWidget {
  const GoogleSifreBelirlePage({super.key, required this.onTamamlandi});

  final VoidCallback onTamamlandi;

  @override
  State<GoogleSifreBelirlePage> createState() => _GoogleSifreBelirlePageState();
}

class _GoogleSifreBelirlePageState extends State<GoogleSifreBelirlePage> {
  final _sifreController = TextEditingController();
  final _tekrarController = TextEditingController();
  bool _sifreGizli = true;
  bool _tekrarGizli = true;
  bool _yukleniyor = false;

  @override
  void dispose() {
    _sifreController.dispose();
    _tekrarController.dispose();
    super.dispose();
  }

  Future<void> _kaydet() async {
    final sifre = _sifreController.text;
    final tekrar = _tekrarController.text;
    if (sifre.length < 6) {
      _mesaj('Şifre en az 6 karakter olmalı.');
      return;
    }
    if (sifre != tekrar) {
      _mesaj('Şifreler eşleşmiyor.');
      return;
    }

    setState(() => _yukleniyor = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && SosyalOAuth.sifreEksikMi(user)) {
        try {
          if (SosyalOAuth.appleMu(user)) {
            await AppleGirisServis.yenidenDogrula();
          } else {
            await GoogleGirisServis.yenidenDogrula();
          }
        } on FirebaseAuthException catch (e) {
          if (e.code == 'canceled' || e.code == 'sign_in_canceled') {
            if (mounted) setState(() => _yukleniyor = false);
            return;
          }
          rethrow;
        }
      }
      await SosyalOAuth.sifreBagla(sifre);
      await FirebaseAuth.instance.currentUser?.reload();
      if (!mounted) return;
      widget.onTamamlandi();
    } catch (e) {
      if (!mounted) return;
      final user = FirebaseAuth.instance.currentUser;
      final oauthMesaj = (user != null && SosyalOAuth.appleMu(user))
          ? AppleGirisServis.hataMesaji(e)
          : GoogleGirisServis.hataMesaji(e);
      _mesaj(
        oauthMesaj.isNotEmpty
            ? oauthMesaj
            : internetAwareErrorMessage(
                error: e,
                fallback: 'Şifre kaydedilemedi. Tekrar dene.',
              ),
      );
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  void _mesaj(String mesaj) {
    vibeSnackbarGoster(context, mesaj, tip: VibeMesajTipi.hata);
  }

  @override
  Widget build(BuildContext context) {
    final vibe = context.vibe;
    final theme = Theme.of(context);
    final email = FirebaseAuth.instance.currentUser?.email ?? '';

    return AuthEkranYaziOlcegi(
      child: VibeGradientScaffold(
        appBar: VibeGradientScaffold.seffafBaslik(
          'Şifre belirle',
          leading: IconButton(
            onPressed: _yukleniyor ? null : () => GoogleGirisServis.oturumuKapat(),
            icon: const Icon(Icons.close_rounded),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              children: [
                const SizedBox(height: 12),
                const VibeMarkaBaslik(ikonBoyut: 64, yaziBoyut: 26),
                const SizedBox(height: 16),
                Text(
                  email.isEmpty
                      ? 'Hesap güvenliği için bir şifre belirle. Hesap silerken de bu şifre istenir.'
                      : 'Hesap güvenliği için bir şifre belirle ($email). Hesap silerken de bu şifre istenir.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: vibe.mutedText, fontSize: 14),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _sifreController,
                  enabled: !_yukleniyor,
                  obscureText: _sifreGizli,
                  style: TextStyle(color: theme.colorScheme.onSurface),
                  decoration: vibe
                      .alanDekoru(
                        hint: 'Şifre (en az 6 karakter)',
                        ikon: Icons.lock,
                      )
                      .copyWith(
                        suffixIcon: IconButton(
                          onPressed: _yukleniyor
                              ? null
                              : () =>
                                  setState(() => _sifreGizli = !_sifreGizli),
                          icon: Icon(
                            _sifreGizli
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: vibe.mutedText,
                          ),
                        ),
                      ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _tekrarController,
                  enabled: !_yukleniyor,
                  obscureText: _tekrarGizli,
                  style: TextStyle(color: theme.colorScheme.onSurface),
                  decoration: vibe
                      .alanDekoru(hint: 'Şifre tekrar', ikon: Icons.lock_outline)
                      .copyWith(
                        suffixIcon: IconButton(
                          onPressed: _yukleniyor
                              ? null
                              : () => setState(
                                    () => _tekrarGizli = !_tekrarGizli,
                                  ),
                          icon: Icon(
                            _tekrarGizli
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: vibe.mutedText,
                          ),
                        ),
                      ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _yukleniyor ? null : _kaydet,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: vibe.primaryButton,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 55),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: _yukleniyor
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        )
                      : const Text(
                          'ŞİFREYİ KAYDET',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
