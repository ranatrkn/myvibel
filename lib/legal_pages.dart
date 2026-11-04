// Gizlilik, KVKK, kullanım koşulları, SSS ve destek sayfaları.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:myvibel/app_theme.dart';
import 'package:myvibel/destek_servis.dart';
import 'package:myvibel/error_messages.dart';
import 'package:myvibel/vibe_snackbar.dart';
import 'package:myvibel/yasal_icerik.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Sistem paylaşımı (WhatsApp, SMS, vs.); olmazsa metni panoya kopyalar.
Future<void> arkadaslaraOner(BuildContext context) async {
  const metin =
      'MyVibel\'de Vibel büyütüyorum. Sen de bak:\n${VibeLegal.uygulamaDavetUrl}';
  try {
    await Share.share(metin, subject: 'MyVibel');
  } catch (_) {
    await Clipboard.setData(const ClipboardData(text: metin));
    if (!context.mounted) return;
    vibeSnackbarGoster(
      context,
      'Davet metni kopyalandı, arkadaşlarına yapıştır.',
      tip: VibeMesajTipi.bilgi,
    );
  }
}

/// Yasal metnin web sürümünü tarayıcıda açar; açılmazsa linki panoya kopyalar.
Future<void> yasalLinkiAc(BuildContext context, String url) async {
  var acildi = false;
  try {
    acildi = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    acildi = false;
  }
  if (acildi || !context.mounted) return;

  await Clipboard.setData(ClipboardData(text: url));
  if (!context.mounted) return;
  vibeSnackbarGoster(
    context,
    'Tarayıcı açılamadı, link kopyalandı.',
    tip: VibeMesajTipi.bilgi,
  );
}

// Yasal sabitler (URL, sürüm)
class VibeLegal {
  static const privacyPolicyUrl = 'https://myvibel.com/privacy.html';
  static const kvkkPolicyUrl = 'https://myvibel.com/kvkk.html';
  static const termsUrl = 'https://myvibel.com/terms.html';
  static const cocukGuvenligiUrl =
      'https://myvibel.com/cocuk-guvenligi.html';
  static const uygulamaDavetUrl = 'https://myvibel.com/app/';
  static const appVersionLabel = YasalIcerik.surum;
}

class _YasalMetinSayfasi extends StatelessWidget {
  const _YasalMetinSayfasi({
    required this.baslik,
    required this.metin,
    this.altLink,
  });

  final String baslik;
  final String metin;
  final ({String etiket, String url})? altLink;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vibe = context.vibe;

    return Scaffold(
      appBar: AppBar(
        title: Text(baslik),
        actions: [
          if (altLink != null)
            TextButton(
              onPressed: () => yasalLinkiAc(context, altLink!.url),
              child: Text(altLink!.etiket),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Son güncelleme: ${YasalIcerik.guncellemeTarihi} · Sürüm ${YasalIcerik.surum}',
              style: TextStyle(color: vibe.faintText, fontSize: 12),
            ),
            const SizedBox(height: 16),
            Text(
              metin.trim(),
              style: TextStyle(
                color: vibe.mutedText,
                height: 1.55,
                fontSize: 14,
              ),
            ),
            if (altLink != null) ...[
              const SizedBox(height: 20),
              ListTile(
                tileColor: vibe.inputFill,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                title: const Text('Web sitesinde aç'),
                subtitle: Text(
                  altLink!.url,
                  style: TextStyle(color: theme.colorScheme.onSurface),
                ),
                trailing: const Icon(Icons.open_in_new_rounded),
                onTap: () => yasalLinkiAc(context, altLink!.url),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _YasalMetinSayfasi(
      baslik: 'Gizlilik Politikası',
      metin: YasalIcerik.gizlilikMetni,
      altLink: (
        etiket: 'Web sürümü',
        url: VibeLegal.privacyPolicyUrl,
      ),
    );
  }
}

class KvkkPage extends StatelessWidget {
  const KvkkPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _YasalMetinSayfasi(
      baslik: YasalIcerik.kvkkBaslik,
      metin: YasalIcerik.kvkkMetni,
      altLink: (
        etiket: 'Web sürümü',
        url: VibeLegal.kvkkPolicyUrl,
      ),
    );
  }
}

class TermsOfUsePage extends StatelessWidget {
  const TermsOfUsePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _YasalMetinSayfasi(
      baslik: YasalIcerik.kullanimKosullariBaslik,
      metin: YasalIcerik.kullanimKosullariMetni,
      altLink: (
        etiket: 'Web sürümü',
        url: VibeLegal.termsUrl,
      ),
    );
  }
}

class CocukGuvenligiPage extends StatelessWidget {
  const CocukGuvenligiPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _YasalMetinSayfasi(
      baslik: YasalIcerik.cocukGuvenligiBaslik,
      metin: YasalIcerik.cocukGuvenligiMetni,
      altLink: (
        etiket: 'Web sürümü',
        url: VibeLegal.cocukGuvenligiUrl,
      ),
    );
  }
}

class HelpFaqPage extends StatelessWidget {
  const HelpFaqPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Yardım / SSS')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final item in YasalIcerik.sss)
            _FaqTile(q: item.soru, a: item.cevap),
        ],
      ),
    );
  }
}

class ChangelogPage extends StatelessWidget {
  const ChangelogPage({super.key});

  @override
  Widget build(BuildContext context) {
    final vibe = context.vibe;
    return Scaffold(
      appBar: AppBar(title: const Text('Sürüm Notları')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'v${VibeLegal.appVersionLabel}',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(
            YasalIcerik.surumNotlari.trim(),
            style: TextStyle(color: vibe.mutedText, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class ContactPage extends StatefulWidget {
  const ContactPage({super.key, this.ilkKategori});

  final String? ilkKategori;

  @override
  State<ContactPage> createState() => _ContactPageState();
}

class _ContactPageState extends State<ContactPage> {
  final _konuController = TextEditingController();
  final _mesajController = TextEditingController();
  late String _kategori;
  bool _gonderiliyor = false;
  bool _gonderildi = false;

  @override
  void initState() {
    super.initState();
    final ilk = widget.ilkKategori;
    _kategori = (ilk != null && DestekServis.kategoriler.containsKey(ilk))
        ? ilk
        : DestekServis.kategoriler.keys.first;
  }

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
        _kategori = widget.ilkKategori != null &&
                DestekServis.kategoriler.containsKey(widget.ilkKategori)
            ? widget.ilkKategori!
            : DestekServis.kategoriler.keys.first;
      });
      vibeSnackbarGoster(
        context,
        'Talebin ${YasalIcerik.uygulamaAdi} ekibine iletildi.',
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
                        '${YasalIcerik.uygulamaAdi} ekibine yaz',
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
                  'Hesap, teknik sorun veya önerilerini buradan iletebilirsin. '
                  'KVKK başvuruları web sitesinden yapılır.\n\n'
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
                      'Son talebin alındı. ${YasalIcerik.uygulamaAdi} ekibi inceleyecek.',
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          ListTile(
            tileColor: vibe.inputFill,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            leading: const Icon(Icons.gavel_outlined),
            title: const Text('KVKK başvurusu'),
            subtitle: const Text('Aydınlatma metni ve başvuru web sitesinde'),
            trailing: const Icon(Icons.open_in_new_rounded),
            onTap: () => yasalLinkiAc(context, VibeLegal.kvkkPolicyUrl),
          ),
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
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(a),
          ),
        ),
      ],
    );
  }
}
