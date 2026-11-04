// Web geniş ekran: sol tanıtım + sağ auth formu (masaüstü ayrı kompozisyon).
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:myvibel/app_theme.dart';
import 'package:myvibel/yasal_icerik.dart';
import 'package:myvibel/widgets/maskot_lottie_view.dart';
import 'package:myvibel/widgets/vibe_gradient_scaffold.dart';
import 'package:myvibel/widgets/vibe_marka_baslik.dart';
import 'package:myvibel/widgets/web_shell.dart';

/// Geriye dönük: [kWebMasaustuEsik] ile aynı.
const double kWebAuthSplitEsik = kWebMasaustuEsik;

/// Dar ekranda [form] olduğu gibi; geniş web'de sol tanıtım + sağ form.
class WebAuthLanding extends StatelessWidget {
  const WebAuthLanding({
    super.key,
    required this.form,
    this.slogan = 'Paylaş, Bağ kur, Vibel ile büyü.',
  });

  final Widget form;
  final String slogan;

  static bool genisMi(BuildContext context) {
    if (!kIsWeb) return false;
    return MediaQuery.sizeOf(context).width >= kWebAuthSplitEsik;
  }

  @override
  Widget build(BuildContext context) {
    final genis = genisMi(context);
    if (!genis) return form;

    return SizedBox.expand(
      child: Row(
        children: [
          Expanded(
            flex: 58,
            child: _TanitimPaneli(slogan: slogan),
          ),
          Expanded(
            flex: 42,
            child: DecoratedBox(
              decoration: context.vibe.gradientDecoration(),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: VibeGradyanKapali(child: form),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TanitimPaneli extends StatelessWidget {
  const _TanitimPaneli({required this.slogan});

  final String slogan;

  static const _maddeler = <(IconData, String, String)>[
    (
      Icons.auto_awesome_rounded,
      'Sosyal akış',
      'Gönderi paylaş, beğen, yorumla ve keşfet.',
    ),
    (
      Icons.pets_rounded,
      'Vibel büyütme',
      'Paylaştıkça Vibel’in büyür; 6. seviyeden sonra vil kazanıp onu beslersin.',
    ),
    (
      Icons.chat_bubble_outline_rounded,
      'Mesajlar',
      'Arkadaşlarınla özel sohbet et.',
    ),
    (
      Icons.emoji_events_outlined,
      'Puan ve görevler',
      'Haftalık görevlerle ilerlemeyi hızlandır.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final vibe = context.vibe;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final yukseklik = MediaQuery.sizeOf(context).height;

    // Material yoksa Text'ler sarı çift çizgiyle çizilir (özellikle web).
    return Material(
      color: Colors.transparent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              vibe.gradientStart,
              vibe.gradientEnd,
              // Açık temada siyaha düşme; koyuda derin arka plan.
              vibe.isDark
                  ? const Color(0xFF0B0614)
                  : const Color(0xFFD6E4FA),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(48, 40, 40, 40),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: yukseklik - 80),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Image.asset(
                        'assets/icon/myvibel_ikon.png',
                        width: 52,
                        height: 52,
                        filterQuality: FilterQuality.high,
                      ),
                      const SizedBox(width: 14),
                      const VibeMarkaYazi(yukseklik: 34),
                    ],
                  ),
                  const SizedBox(height: 40),
                  // Hero: slogan + maskot yan yana (masaüstü kompozisyonu)
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 11,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              slogan,
                              style: TextStyle(
                                color: onSurface,
                                fontSize: 38,
                                fontWeight: FontWeight.w700,
                                height: 1.12,
                                letterSpacing: -0.6,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 9,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.12),
                              ),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  vibe.primaryButton.withOpacity(0.35),
                                  Colors.black.withOpacity(0.35),
                                ],
                              ),
                            ),
                            child: const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: MascotLottieView(
                                  seviye: 4,
                                  width: 200,
                                  height: 200,
                                  tamEkranAc: false,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  // 2×2 özellik ızgarası — satırda eşit yükseklik
                  LayoutBuilder(
                    builder: (context, c) {
                      final genisIzgara = c.maxWidth >= 420;
                      Widget kart((IconData, String, String) m) => _OzellikKarti(
                            ikon: m.$1,
                            baslik: m.$2,
                            aciklama: m.$3,
                            vibe: vibe,
                            onSurface: onSurface,
                          );
                      if (!genisIzgara) {
                        return Column(
                          children: [
                            for (var i = 0; i < _maddeler.length; i++) ...[
                              if (i > 0) const SizedBox(height: 14),
                              kart(_maddeler[i]),
                            ],
                          ],
                        );
                      }
                      Widget satir(List<(IconData, String, String)> ikili) {
                        return IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(child: kart(ikili[0])),
                              const SizedBox(width: 14),
                              Expanded(child: kart(ikili[1])),
                            ],
                          ),
                        );
                      }
                      return Column(
                        children: [
                          satir(_maddeler.sublist(0, 2)),
                          const SizedBox(height: 14),
                          satir(_maddeler.sublist(2, 4)),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 36),
                  Text(
                    '© ${YasalIcerik.uygulamaAdi}',
                    style: TextStyle(
                      color: vibe.faintText,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OzellikKarti extends StatelessWidget {
  const _OzellikKarti({
    required this.ikon,
    required this.baslik,
    required this.aciklama,
    required this.vibe,
    required this.onSurface,
  });

  final IconData ikon;
  final String baslik;
  final String aciklama;
  final VibeThemeExtension vibe;
  final Color onSurface;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(ikon, color: vibe.primaryButton, size: 22),
          const SizedBox(height: 10),
          Text(
            baslik,
            style: TextStyle(
              color: onSurface,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            aciklama,
            style: TextStyle(
              color: vibe.mutedText,
              fontSize: 13.5,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
