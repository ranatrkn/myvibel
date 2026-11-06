// İlk açılış anlatıcısı ve sürüm güncelleme paneli.
import 'package:flutter/material.dart';
import 'package:myvibel/app_theme.dart';
import 'package:myvibel/legal_pages.dart';
import 'package:myvibel/maskot_servis.dart';
import 'package:myvibel/widgets/maskot_lottie_view.dart';
import 'package:myvibel/widgets/web_shell.dart';
import 'package:myvibel/yasal_icerik.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VibelAnlaticiPaneli {
  VibelAnlaticiPaneli._();

  static const anlaticiAnahtar = 'vibel_anlatici_v1';
  static const surumAnahtar = 'last_seen_changelog_version';

  /// Yeni kullanıcıya anlatıcı; ardından (veya eski kullanıcıya) bir kez güncelleme.
  static Future<void> gerekirseGoster(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    if (!context.mounted) return;

    final anlaticiGordu = prefs.getBool(anlaticiAnahtar) == true;
    if (!anlaticiGordu) {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _AnlaticiDiyalog(),
      );
      await prefs.setBool(anlaticiAnahtar, true);
      await prefs.setString(surumAnahtar, VibeLegal.appVersionLabel);
      return;
    }

    final gorulen = prefs.getString(surumAnahtar);
    if (gorulen == VibeLegal.appVersionLabel) return;
    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (_) => const _GuncellemeDiyalog(),
    );
    await prefs.setString(surumAnahtar, VibeLegal.appVersionLabel);
  }

  static Future<void> seviyeKutlamasiGoster(
    BuildContext context,
    int seviye,
  ) async {
    final metin = MascotServis.seviyeOdulAciklamasi(seviye);
    if (metin == null) return;
    await showDialog<void>(
      context: context,
      builder: (_) => _SeviyeKutlamaDiyalog(seviye: seviye, metin: metin),
    );
  }
}

class _SeviyeKutlamaDiyalog extends StatelessWidget {
  const _SeviyeKutlamaDiyalog({required this.seviye, required this.metin});

  final int seviye;
  final String metin;

  @override
  Widget build(BuildContext context) {
    final vibe = context.vibe;
    final theme = Theme.of(context);
    return Dialog(
      backgroundColor: theme.dialogBackgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: webMasaustuMu(context) ? 400 : double.infinity,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              MascotLottieView(
                seviye: seviye,
                width: 96,
                height: 96,
                tamEkranAc: false,
              ),
              const SizedBox(height: 8),
              Text(
                'Seviye $seviye!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                metin,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: vibe.mutedText,
                  height: 1.45,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Harika!'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnlaticiAdim {
  const _AnlaticiAdim({required this.baslik, required this.metin});
  final String baslik;
  final String metin;
}

class _AnlaticiDiyalog extends StatefulWidget {
  const _AnlaticiDiyalog();

  @override
  State<_AnlaticiDiyalog> createState() => _AnlaticiDiyalogState();
}

class _AnlaticiDiyalogState extends State<_AnlaticiDiyalog> {
  static const _adimlar = [
    _AnlaticiAdim(
      baslik: 'Merhaba, ben Vibel',
      metin:
          'Akışta gez, gönderileri beğen, yorum yap; her etkileşiminle birlikte büyürüm.',
    ),
    _AnlaticiAdim(
      baslik: 'Gelişim çubuğum',
      metin:
          'Çerçevemdeki çizgi gelişimim. Paylaş, yorum yap, beğen, takip et; çizgi dolunca seviye atlarım.',
    ),
    _AnlaticiAdim(
      baslik: 'Kabuktan çıkış',
      metin:
          '6. seviyede kabuğumdan çıkarım. Sonra vil kazanır, bana yemek verirsin. İlerleyen seviyelerde uyku ve haftalık görevler açılır.',
    ),
    _AnlaticiAdim(
      baslik: 'Beni aç bırakma',
      metin:
          '6. seviyeden sonra acıkırım. Uygulama kapalıyken de tokluğum azalır; tam tok olsam bile yaklaşık 5 saatte bitebilir. '
          'Tokluğum 3 gün boyunca sıfırda kalırsa yumurtaya dönerim ve seviyem 1’e iner. '
          'Bu olmadan önce her zaman bildirim gelmeyebilir; ara sıra uğrayıp bana yemek ver.',
    ),
    _AnlaticiAdim(
      baslik: 'Paylaş ve bağ kur',
      metin:
          'Gönder sekmesinden paylaş, arkadaşlarını takip et. Karşılıklı takipte birbirinizin Vibel’ini besleyerek bağ kurarsınız.',
    ),
    _AnlaticiAdim(
      baslik: 'Fikrin bizim için önemli',
      metin:
          'Bir sorun mu yaşadın ya da bir fikrin mi var? Profilindeki ayarlar (dişli simgesi) → Destek ve Geri Bildirim’den bize yazabilirsin. Hepsini okuyoruz. Hazırsan başlayalım!',
    ),
  ];

  int _indeks = 0;

  @override
  Widget build(BuildContext context) {
    final vibe = context.vibe;
    final theme = Theme.of(context);
    final adim = _adimlar[_indeks];
    final son = _indeks == _adimlar.length - 1;

    return Dialog(
      backgroundColor: theme.dialogBackgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MascotLottieView(
              seviye: 1,
              width: 88,
              height: 88,
              tamEkranAc: false,
            ),
            const SizedBox(height: 8),
            Text(
              adim.baslik,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              adim.metin,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: vibe.mutedText,
                height: 1.45,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Atla'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () {
                    if (son) {
                      Navigator.pop(context);
                      return;
                    }
                    setState(() => _indeks += 1);
                  },
                  child: Text(son ? 'Başla' : 'İleri'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GuncellemeDiyalog extends StatelessWidget {
  const _GuncellemeDiyalog();

  @override
  Widget build(BuildContext context) {
    final vibe = context.vibe;
    final theme = Theme.of(context);
    return Dialog(
      backgroundColor: theme.dialogBackgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Yenilikler v${VibeLegal.appVersionLabel}',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: SingleChildScrollView(
                child: Text(
                  YasalIcerik.kullaniciGuncellemeNotlari.trim(),
                  style: TextStyle(
                    color: vibe.mutedText,
                    height: 1.5,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Tamam'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
