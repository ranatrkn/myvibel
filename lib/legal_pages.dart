// Gizlilik, KVKK, SSS ve destek sayfaları.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vibe_life/app_theme.dart';
import 'package:vibe_life/destek_servis.dart';
import 'package:vibe_life/error_messages.dart';
import 'package:vibe_life/vibe_snackbar.dart';

// Yasal sabitler (URL, sürüm)
class VibeLegal {
  static const privacyPolicyUrl = 'https://vibe-life-app.web.app/privacy.html';
  static const kvkkPolicyUrl = 'https://vibe-life-app.web.app/kvkk.html';
  static const appVersionLabel = '1.0.0';
}

// Gizlilik politikası metin sayfası
class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vibe = context.vibe;
    return Scaffold(
      appBar: AppBar(title: const Text('Gizlilik Politikasi')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'VibeLife Gizlilik Politikasi',
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Toplanan veriler: e-posta, profil bilgileri, gonderiler, yorumlar, mesajlar, bildirim tokeni ve uygulama ici maskot istatistikleri.',
              style: TextStyle(color: vibe.mutedText),
            ),
            const SizedBox(height: 8),
            Text(
              'Veriler Firebase altyapisinda saklanir ve uygulama islevleri, guvenlik ve destek amaciyla kullanilir.',
              style: TextStyle(color: vibe.mutedText),
            ),
            const SizedBox(height: 8),
            Text(
              'Hesap silme islemi uygulama icinden yapildiginda kullanici verileri silme akisina dahil edilir.',
              style: TextStyle(color: vibe.mutedText),
            ),
            const SizedBox(height: 8),
            Text(
              'Destek ve KVKK talepleri uygulama icindeki «Destek ve Geri Bildirim» alanindan VibeLife ekibine iletilir.',
              style: TextStyle(color: vibe.mutedText),
            ),
            const SizedBox(height: 18),
            ListTile(
              tileColor: vibe.inputFill,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              title: const Text('Gizlilik Politikasi URL'),
              subtitle: const Text(VibeLegal.privacyPolicyUrl),
              trailing: const Icon(Icons.copy),
              onTap: () async {
                await Clipboard.setData(
                  const ClipboardData(text: VibeLegal.privacyPolicyUrl),
                );
                if (!context.mounted) return;
                vibeSnackbarGoster(
                  context,
                  'Gizlilik politikasi linki kopyalandi.',
                  tip: VibeMesajTipi.basari,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// KVKK aydınlatma metni sayfası
class KvkkPage extends StatelessWidget {
  const KvkkPage({super.key});

  @override
  Widget build(BuildContext context) {
    final vibe = context.vibe;
    return Scaffold(
      appBar: AppBar(title: const Text('KVKK Aydinlatma')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Text(
          'VibeLife, 6698 sayili KVKK kapsaminda veri sorumlusu olarak; kimlik (ad-soyad, kullanici adi), iletisim (e-posta), icerik (gonderi, yorum, mesaj) ve teknik verileri (bildirim tokeni) hizmetin sunulmasi, guvenlik, moderasyon ve iletisim amaclariyla isler.\n\n'
          'Veriler, Firebase altyapisinda saklanir. Kullanici; hesap silme, veri duzeltme ve erisim taleplerini uygulama ici araclar veya «Destek ve Geri Bildirim» formu uzerinden VibeLife ekibine iletebilir.',
          style: TextStyle(color: vibe.mutedText, height: 1.5),
        ),
      ),
    );
  }
}

// Sık sorulan sorular sayfası
class HelpFaqPage extends StatelessWidget {
  const HelpFaqPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Yardim / SSS')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _FaqTile(
            q: 'Maskot nasil calisir?',
            a: 'Maskot sosyal etkilesimlerle mutluluk kazanir, enerji tuketir ve uyuyarak enerji toplar.',
          ),
          _FaqTile(
            q: 'Enerji ve mutluluk nasil duser?',
            a: 'Enerji yalnizca sosyal etkilesimlerle duser. Mutluluk etkilesimsiz kalma suresine gore duser. Enerji bitince etkilesimler kilitlenir.',
          ),
          _FaqTile(
            q: 'Uyku sistemi nasil isliyor?',
            a: 'Enerji %50 ve altindayken maskot uyutulabilir. Maskot 4 saat uyur, dakika basina enerji artar. Enerji yeterliyse erken uyandirma secenegi acilir.',
          ),
          _FaqTile(
            q: 'Gizli hesap ne yapar?',
            a: 'Takipci olmayan kullanicilar gonderileri ve takip listelerini goremez.',
          ),
          _FaqTile(
            q: 'Bir gonderiyi nasil sikayet ederim?',
            a: 'Gonderi kartindaki menu uzerinden «Sikayet Et» secenegini kullan. Genel destek ve KVKK talepleri icin profil ayarlarindaki Destek ve Geri Bildirim alanini kullan.',
          ),
        ],
      ),
    );
  }
}

// Sürüm notları sayfası
class ChangelogPage extends StatelessWidget {
  const ChangelogPage({super.key});

  @override
  Widget build(BuildContext context) {
    final vibe = context.vibe;
    return Scaffold(
      appBar: AppBar(title: const Text('Surum Notlari')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'v${VibeLegal.appVersionLabel}',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(
            '- Maskot uyku/mutluluk sistemi guncellendi\n- Snackbar tasarimi standartlastirildi\n- Gizli hesap gorunurluk kurallari iyilestirildi\n- Profil ve maskot deneyimi sadeleştirildi\n- Uygulama ici destek formu eklendi',
            style: TextStyle(color: vibe.mutedText, height: 1.5),
          ),
        ],
      ),
    );
  }
}

// Uygulama içi destek ve geri bildirim formu
class ContactPage extends StatefulWidget {
  const ContactPage({super.key});

  @override
  State<ContactPage> createState() => _ContactPageState();
}

class _ContactPageState extends State<ContactPage> {
  final _konuController = TextEditingController();
  final _mesajController = TextEditingController();
  String _kategori = DestekServis.kategoriler.keys.first;
  bool _gonderiliyor = false;
  bool _gonderildi = false;

  @override
  void dispose() {
    _konuController.dispose();
    _mesajController.dispose();
    super.dispose();
  }

  Future<void> _talepGonder() async {
    if (_gonderiliyor) return;

    setState(() => _gonderiliyor = true);
    try {
      await DestekServis.talepGonder(
        kategori: _kategori,
        konu: _konuController.text,
        mesaj: _mesajController.text,
        appVersion: VibeLegal.appVersionLabel,
      );
      if (!mounted) return;
      setState(() {
        _gonderildi = true;
        _konuController.clear();
        _mesajController.clear();
        _kategori = DestekServis.kategoriler.keys.first;
      });
      vibeSnackbarGoster(
        context,
        'Talebin VibeLife ekibine iletildi.',
        tip: VibeMesajTipi.basari,
      );
    } catch (e) {
      if (!mounted) return;
      vibeSnackbarGoster(
        context,
        internetAwareErrorMessage(
          error: e,
          fallback: 'Talep gönderilemedi.',
        ),
      );
    } finally {
      if (mounted) setState(() => _gonderiliyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vibe = context.vibe;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Destek ve Geri Bildirim')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: vibe.cardDecoration(radius: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.support_agent, color: theme.colorScheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'VibeLife ekibine yaz',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Hesap, teknik sorun, KVKK veya önerilerini buradan iletebilirsin. '
                  'Gerekirse uygulama içinden bilgilendirileceksin.\n\n'
                  'Bir gönderi veya kullanıcıyı şikayet etmek için ilgili kartın menüsündeki '
                  '«Şikayet Et» seçeneğini kullan.',
                  style: TextStyle(color: vibe.mutedText, height: 1.45),
                ),
              ],
            ),
          ),
          if (_gonderildi) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: vibe.inputFill,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withOpacity(0.4)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_outline, color: Colors.green),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Son talebin alındı. VibeLife ekibi inceleyecek.',
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          Text('Kategori', style: TextStyle(color: vibe.mutedText)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: _kategori,
            decoration: InputDecoration(
              filled: true,
              fillColor: vibe.inputFill,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            items: DestekServis.kategoriler.entries
                .map(
                  (e) => DropdownMenuItem(
                    value: e.key,
                    child: Text(e.value),
                  ),
                )
                .toList(),
            onChanged: _gonderiliyor
                ? null
                : (v) {
                    if (v != null) setState(() => _kategori = v);
                  },
          ),
          const SizedBox(height: 16),
          Text('Konu', style: TextStyle(color: vibe.mutedText)),
          const SizedBox(height: 6),
          TextField(
            controller: _konuController,
            enabled: !_gonderiliyor,
            maxLength: 120,
            decoration: InputDecoration(
              hintText: 'Kısa özet (ör. giriş yapamıyorum)',
              filled: true,
              fillColor: vibe.inputFill,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text('Mesaj', style: TextStyle(color: vibe.mutedText)),
          const SizedBox(height: 6),
          TextField(
            controller: _mesajController,
            enabled: !_gonderiliyor,
            maxLength: 2000,
            minLines: 5,
            maxLines: 8,
            decoration: InputDecoration(
              hintText:
                  'Sorunu veya talebini ayrıntılı yaz. Hata varsa ne yaptığını da ekle.',
              filled: true,
              fillColor: vibe.inputFill,
              alignLabelWithHint: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _gonderiliyor ? null : _talepGonder,
              icon: _gonderiliyor
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text(_gonderiliyor ? 'Gönderiliyor...' : 'Talebi Gönder'),
            ),
          ),
        ],
      ),
    );
  }
}

// Genişletilebilir SSS satırı
class _FaqTile extends StatelessWidget {
  const _FaqTile({required this.q, required this.a});
  final String q;
  final String a;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: Text(q),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Text(a),
        ),
      ],
    );
  }
}
