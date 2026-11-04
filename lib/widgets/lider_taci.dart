// Liderlik tablosu 1–2–3 için altın / gümüş / bronz taç.
import 'package:flutter/material.dart';

class LiderTaci extends StatelessWidget {
  const LiderTaci({
    super.key,
    required this.sira,
    this.size = 22,
  });

  final int sira;
  final double size;

  static const altinYolu = 'assets/badges/lider_taci_altin.png';
  static const gumusYolu = 'assets/badges/lider_taci_gumus.png';
  static const bronzYolu = 'assets/badges/lider_taci_bronz.png';
  static const enBoy = 690 / 440;

  static String? assetYolu(int sira) {
    return switch (sira) {
      1 => altinYolu,
      2 => gumusYolu,
      3 => bronzYolu,
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final yol = assetYolu(sira);
    if (yol == null) return const SizedBox.shrink();
    return Image.asset(
      yol,
      width: size,
      height: size / enBoy,
      fit: BoxFit.fill,
      filterQuality: FilterQuality.high,
      gaplessPlayback: true,
    );
  }
}
