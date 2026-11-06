// Google ile ilk girişte kullanıcı adı, yaş ve yasal onay.
import 'package:myvibel/tek_sefer_navigasyon.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:myvibel/apple_giris_servis.dart';
import 'package:myvibel/app_theme.dart';
import 'package:myvibel/error_messages.dart';
import 'package:myvibel/google_giris_servis.dart';
import 'package:myvibel/kayit_servis.dart';
import 'package:myvibel/legal_pages.dart';
import 'package:myvibel/maestro_semantics.dart';
import 'package:myvibel/sosyal_oauth.dart';
import 'package:myvibel/vibe_snackbar.dart';
import 'package:myvibel/widgets/vibe_gradient_scaffold.dart';
import 'package:myvibel/widgets/vibe_marka_baslik.dart';
import 'package:myvibel/yasal_icerik.dart';
import 'package:myvibel/yas_dogrulama.dart';

class GoogleProfilTamamlamaPage extends StatefulWidget {
  const GoogleProfilTamamlamaPage({super.key, required this.onTamamlandi});

  final VoidCallback onTamamlandi;

  @override
  State<GoogleProfilTamamlamaPage> createState() =>
      _GoogleProfilTamamlamaPageState();
}

class _GoogleProfilTamamlamaPageState extends State<GoogleProfilTamamlamaPage> {
  late final TextEditingController adController;
  late final TextEditingController kullaniciAdController;
  final sifreController = TextEditingController();
  final sifreTekrarController = TextEditingController();
  bool isLoading = false;
  bool gizlilikOnayi = false;
  bool sifreGizli = true;
  bool sifreTekrarGizli = true;
  DateTime? dogumTarihi;

  User? get _user => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    final user = _user;
    adController = TextEditingController(
      text: GoogleGirisServis.adSoyadOner(
        displayName: user?.displayName,
        email: user?.email,
      ),
    );
    kullaniciAdController = TextEditingController(
      text: GoogleGirisServis.kullaniciAdiOner(
        displayName: user?.displayName,
        email: user?.email,
      ),
    );
  }

  @override
  void dispose() {
    adController.dispose();
    kullaniciAdController.dispose();
    sifreController.dispose();
    sifreTekrarController.dispose();
    super.dispose();
  }

  String _kullaniciAdiniTemizle(String value) => value.trim().toLowerCase();

  bool _kullaniciAdiGecerliMi(String kullaniciAdi) =>
      RegExp(r'^[a-z0-9_\.]+$').hasMatch(kullaniciAdi);

  Future<void> _kaydet() async {
    final user = _user;
    if (user == null) {
      await GoogleGirisServis.oturumuKapat();
      return;
    }

    final adSoyad = adController.text.trim();
    final kullaniciAdi = kullaniciAdController.text.trim();
    final kullaniciAdiKucuk = _kullaniciAdiniTemizle(kullaniciAdi);
    final sifreGerekli = GoogleGirisServis.sifreEksikMi(user);

    if (adSoyad.length < 2 || kullaniciAdi.isEmpty) {
      _mesaj('Lütfen ad ve kullanıcı adını doldur.');
      return;
    }
    if (kullaniciAdiKucuk.length < 3) {
      _mesaj('Kullanıcı adı en az 3 karakter olmalı.');
      return;
    }
    if (!_kullaniciAdiGecerliMi(kullaniciAdiKucuk)) {
      _mesaj('Kullanıcı adında sadece harf, sayı, nokta ve alt çizgi kullan.');
      return;
    }
    if (dogumTarihi == null) {
      _mesaj('Doğum tarihini seçmelisin.');
      return;
    }
    if (!YasDogrulama.kayitIcinUygunMu(dogumTarihi!)) {
      _mesaj(
        YasDogrulama.kayitYasMesaji(YasalIcerik.uygulamaAdi),
      );
      return;
    }
    if (!gizlilikOnayi) {
      _mesaj(
        'Kayıt için Gizlilik Politikası, KVKK Aydınlatma Metni ve Kullanım Koşulları\'nı onaylamalısın.',
      );
      return;
    }

    final sifre = sifreController.text;
    final sifreTekrar = sifreTekrarController.text;
    if (sifreGerekli) {
      if (sifre.length < 6) {
        _mesaj('Şifre en az 6 karakter olmalı.');
        return;
      }
      if (sifre != sifreTekrar) {
        _mesaj('Şifreler eşleşmiyor.');
        return;
      }
    }

    setState(() => isLoading = true);
    try {
      // 1) Şifre önce. Yeni Google oturumu taze olduğu için çoğu zaman
      // yeniden doğrulama gerekmez; gerekirse sessizce (hesap seçicisiz) dene.
      if (sifreGerekli) {
        try {
          await SosyalOAuth.sifreBagla(sifre);
        } on FirebaseAuthException catch (e) {
          if (e.code == 'requires-recent-login') {
            try {
              if (SosyalOAuth.appleMu(user)) {
                await AppleGirisServis.yenidenDogrula();
              } else {
                await GoogleGirisServis.yenidenDogrula(hesabiYenidenSec: false);
              }
            } on FirebaseAuthException catch (e2) {
              if (e2.code == 'canceled' ||
                  e2.code == 'sign_in_canceled' ||
                  e2.code == 'popup-closed-by-user' ||
                  e2.code == 'cancelled-popup-request') {
                return;
              }
              rethrow;
            }
            await SosyalOAuth.sifreBagla(sifre);
          } else {
            rethrow;
          }
        }
        await FirebaseAuth.instance.currentUser?.reload();
      }

      final guncel = FirebaseAuth.instance.currentUser;
      if (guncel == null) {
        _mesaj('Oturum kayboldu. Tekrar giriş yap.');
        return;
      }

      // 2) Profil sonra
      await KayitServis.profilOlustur(
        uid: guncel.uid,
        adSoyad: adSoyad,
        kullaniciAdi: kullaniciAdi,
        kullaniciAdiKucuk: kullaniciAdiKucuk,
        email: guncel.email ?? '',
        dogumTarihi: YasDogrulama.sadeceTarih(dogumTarihi!),
        // Galeri avatarı varsayılan; Google photoURL gömülmesin.
        photoUrl: '',
      );
      if (!mounted) return;
      widget.onTamamlandi();
    } catch (e) {
      if (!mounted) return;
      // Profil yazılamadıysa ama şifre bağlandıysa sonraki açılışta
      // şifre alanları atlanır; kullanıcı adı tekrar denenebilir.
      if (e is FirebaseAuthException) {
        final mesaj = SosyalOAuth.appleMu(user)
            ? AppleGirisServis.hataMesaji(e)
            : GoogleGirisServis.hataMesaji(e);
        _mesaj(mesaj.isNotEmpty ? mesaj : 'Şifre kaydedilemedi. Tekrar dene.');
      } else if (e is String && e.trim().isNotEmpty) {
        _mesaj(e.trim());
      } else {
        final metin = e.toString().replaceFirst('Exception: ', '');
        final kullaniciAdiHatasi = metin.toLowerCase().contains('kullanıcı adı') ||
            metin.toLowerCase().contains('kullanici adi');
        _mesaj(
          internetAwareErrorMessage(
            error: e,
            fallback: kullaniciAdiHatasi
                ? metin
                : 'Profil oluşturulamadı. Biraz bekleyip tekrar dene.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _vazgec() async {
    final user = _user;
    try {
      await KayitServis.bekleyenKayitIptal(
        authSilmedenOnceYenidenDogrula: () async {
          if (user != null && SosyalOAuth.appleMu(user)) {
            await AppleGirisServis.yenidenDogrula();
          } else {
            await GoogleGirisServis.yenidenDogrula();
          }
        },
      );
    } catch (e) {
      debugPrint('OAuth kayıt iptal: $e');
      await GoogleGirisServis.oturumuKapat();
      return;
    }
    await GoogleGirisServis.googleOturumunuKapat();
  }

  void _mesaj(String mesaj) {
    vibeSnackbarGoster(context, mesaj, tip: VibeMesajTipi.hata);
  }

  Future<void> _dogumTarihiSec() async {
    final secilen = await YasDogrulama.dogumTarihiSec(
      context,
      baslangic: dogumTarihi,
    );
    if (secilen != null) {
      setState(() => dogumTarihi = YasDogrulama.sadeceTarih(secilen));
    }
  }

  @override
  Widget build(BuildContext context) {
    final vibe = context.vibe;
    final theme = Theme.of(context);
    final email = _user?.email ?? '';
    final sifreGerekli = _user != null && GoogleGirisServis.sifreEksikMi(_user!);

    return AuthEkranYaziOlcegi(
      child: VibeGradientScaffold(
        appBar: VibeGradientScaffold.seffafBaslik(
          'Profilini tamamla',
          leading: IconButton(
            onPressed: isLoading ? null : _vazgec,
            icon: const Icon(Icons.close_rounded),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              children: [
                const SizedBox(height: 12),
                const VibeMarkaBaslik(
                  ikonBoyut: 64,
                  yaziBoyut: 26,
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    sifreGerekli
                        ? (email.isEmpty
                          ? 'Hesabın bağlandı. Kullanıcı adı, doğum tarihi ve bir şifre belirle.'
                          : 'Hesabın bağlandı ($email). Kullanıcı adı, doğum tarihi ve bir şifre belirle.')
                        : (email.isEmpty
                            ? 'Kullanıcı adı ve doğum tarihini tamamla.'
                            : 'Kullanıcı adı ve doğum tarihini tamamla ($email).'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: vibe.mutedText, fontSize: 14),
                  ),
                ),
                const SizedBox(height: 20),
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
                if (sifreGerekli) ...[
                  _sifreKutusu(
                    controller: sifreController,
                    hintText: 'Şifre (en az 6 karakter)',
                    gizli: sifreGizli,
                    onGizlilik: () => setState(() => sifreGizli = !sifreGizli),
                  ),
                  _sifreKutusu(
                    controller: sifreTekrarController,
                    hintText: 'Şifre tekrar',
                    gizli: sifreTekrarGizli,
                    onGizlilik: () => setState(
                      () => sifreTekrarGizli = !sifreTekrarGizli,
                    ),
                  ),
                ],
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 10,
                  ),
                  child: Material(
                    color: vibe.inputFill,
                    borderRadius: BorderRadius.circular(18),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: isLoading ? null : _dogumTarihiSec,
                      child: InputDecorator(
                        decoration: InputDecoration(
                          hintText: 'Doğum Tarihi',
                          hintStyle: TextStyle(color: vibe.mutedText),
                          filled: true,
                          fillColor: Colors.transparent,
                          prefixIcon: Icon(
                            Icons.cake_outlined,
                            color: vibe.mutedText,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide(color: vibe.cardBorder),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide(color: vibe.cardBorder),
                          ),
                        ),
                        child: Text(
                          dogumTarihi != null
                              ? YasDogrulama.tarihMetni(dogumTarihi!)
                              : 'Doğum tarihini seç',
                          style: TextStyle(
                            color: dogumTarihi != null
                                ? theme.colorScheme.onSurface
                                : vibe.mutedText,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(40, 0, 40, 6),
                  child: Text(
                    '15 yaşından küçükler kayıt olamaz.',
                    style: TextStyle(
                      color: vibe.mutedText,
                      fontSize: 12,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 34,
                    vertical: 2,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CheckboxListTile(
                        value: gizlilikOnayi,
                        contentPadding: EdgeInsets.zero,
                        activeColor: vibe.primaryButton,
                        title: const Text(
                          'Gizlilik Politikası, KVKK Aydınlatma Metni ve Kullanım Koşulları\'nı okudum, kabul ediyorum.',
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
                              tekSeferPush(
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
                              tekSeferPush(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const KvkkPage(),
                                ),
                              );
                            },
                            child: const Text('KVKK Aydınlatma'),
                          ),
                          TextButton(
                            onPressed: () {
                              tekSeferPush(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const TermsOfUsePage(),
                                ),
                              );
                            },
                            child: const Text('Kullanım Koşulları'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 10,
                  ),
                child: Semantics(
                  label: MaestroSemantics.googleProfilKaydet,
                  button: true,
                  excludeSemantics: true,
                  child: ElevatedButton(
                      onPressed: isLoading ? null : _kaydet,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: vibe.primaryButton,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 55),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
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
                              'DEVAM ET',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: isLoading ? null : _vazgec,
                  child: Text(
                    'Vazgeç',
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
      ),
    );
  }

  Widget _inputKutusu({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
  }) {
    final vibe = context.vibe;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 10),
      child: TextField(
        controller: controller,
        enabled: !isLoading,
        style: TextStyle(color: theme.colorScheme.onSurface),
        decoration: vibe.alanDekoru(hint: hintText, ikon: icon),
      ),
    );
  }

  Widget _sifreKutusu({
    required TextEditingController controller,
    required String hintText,
    required bool gizli,
    required VoidCallback onGizlilik,
  }) {
    final vibe = context.vibe;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 10),
      child: TextField(
        controller: controller,
        enabled: !isLoading,
        obscureText: gizli,
        style: TextStyle(color: theme.colorScheme.onSurface),
        decoration: vibe.alanDekoru(hint: hintText, ikon: Icons.lock).copyWith(
              suffixIcon: IconButton(
                onPressed: isLoading ? null : onGizlilik,
                icon: Icon(
                  gizli ? Icons.visibility_off : Icons.visibility,
                  color: vibe.mutedText,
                ),
              ),
            ),
      ),
    );
  }
}
