// Giriş, kayıt ve üst barda ortak MyVibel marka görselleri.
import 'package:flutter/material.dart';
import 'package:myvibel/app_theme.dart';
import 'package:myvibel/yasal_icerik.dart';

class VibeMarkaYazi extends StatelessWidget {
  const VibeMarkaYazi({
    super.key,
    this.yukseklik = 36,
  });

  static const _yolKoyu = 'assets/icon/myvibel_yazi_dark.png';
  static const _yolAcik = 'assets/icon/myvibel_yazi_light.png';

  final double yukseklik;

  @override
  Widget build(BuildContext context) {
    final yazi = Image.asset(
      context.vibe.isDark ? _yolKoyu : _yolAcik,
      height: yukseklik,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      excludeFromSemantics: true,
    );

    return Semantics(
      label: YasalIcerik.uygulamaAdi,
      header: true,
      child: SizedBox(height: yukseklik, child: yazi),
    );
  }
}

class VibeMarkaBaslik extends StatelessWidget {
  const VibeMarkaBaslik({
    super.key,
    this.ikonBoyut = 88,
    this.yaziBoyut = 34,
    this.altYazi,
  });

  final double ikonBoyut;
  final double yaziBoyut;
  final String? altYazi;

  static const _ikonYolu = 'assets/icon/myvibel_ikon.png';

  @override
  Widget build(BuildContext context) {
    final vibe = context.vibe;

    return Column(
      children: [
        Image.asset(
          _ikonYolu,
          width: ikonBoyut,
          height: ikonBoyut,
          filterQuality: FilterQuality.high,
        ),
        SizedBox(height: ikonBoyut > 70 ? 12 : 8),
        VibeMarkaYazi(yukseklik: yaziBoyut * 1.25),
        if (altYazi != null) ...[
          const SizedBox(height: 8),
          Text(
            altYazi!,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: vibe.mutedText,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}
