// Rety görünüm renkleri: hue kaydırma. Animasyonla kaymayan tek ton.
import 'dart:math' as math;

import 'package:flutter/material.dart';

class RetyRenk {
  const RetyRenk(this.id, this.etiket, this.hueDerece, this.ornek);

  final String id;
  final String etiket;
  final double hueDerece;
  final Color ornek;

  bool get filtreGerekli => hueDerece.abs() > 0.01;

  ColorFilter get colorFilter =>
      ColorFilter.matrix(_hueRotateMatrix(hueDerece));

  static const mavi = RetyRenk('mavi', 'Mavi', 0, Color(0xFF5B9CFF));
  static const lacivert =
      RetyRenk('lacivert', 'Lacivert', 20, Color(0xFF4B6BFF));
  static const mor = RetyRenk('mor', 'Mor', 48, Color(0xFF9B78FF));
  static const eflatun =
      RetyRenk('eflatun', 'Eflatun', 68, Color(0xFFC56BFF));
  static const fusya = RetyRenk('fusya', 'Fuşya', 90, Color(0xFFFF5AD5));
  static const pembe = RetyRenk('pembe', 'Pembe', 108, Color(0xFFFF73B8));
  static const kirmizi =
      RetyRenk('kirmizi', 'Kırmızı', 126, Color(0xFFFF5A6A));
  static const mercan =
      RetyRenk('mercan', 'Mercan', 142, Color(0xFFFF6B4A));
  static const turuncu =
      RetyRenk('turuncu', 'Turuncu', 158, Color(0xFFFF8F45));
  static const altin = RetyRenk('altin', 'Altın', 174, Color(0xFFFFC14A));
  static const sari = RetyRenk('sari', 'Sarı', 192, Color(0xFFFFE44A));
  static const limon = RetyRenk('limon', 'Limon', 218, Color(0xFFC6FF4A));
  static const cimen = RetyRenk('cimen', 'Çimen', 248, Color(0xFF4AE06A));
  static const yesil = RetyRenk('yesil', 'Yeşil', 278, Color(0xFF3ED9A3));
  static const turkuaz =
      RetyRenk('turkuaz', 'Turkuaz', 305, Color(0xFF3ED0D9));
  static const cyan = RetyRenk('cyan', 'Cyan', 328, Color(0xFF4AB8FF));

  static const varsayilan = mavi;

  static const List<RetyRenk> tumu = [
    mavi,
    lacivert,
    mor,
    eflatun,
    fusya,
    pembe,
    kirmizi,
    mercan,
    turuncu,
    altin,
    sari,
    limon,
    cimen,
    yesil,
    turkuaz,
    cyan,
  ];

  static RetyRenk oku(dynamic raw) {
    final id = raw is String ? raw.trim() : '';
    for (final renk in tumu) {
      if (renk.id == id) return renk;
    }
    return varsayilan;
  }

  Widget kapla(Widget child) {
    if (!filtreGerekli) return child;
    return ColorFiltered(colorFilter: colorFilter, child: child);
  }

  @override
  bool operator ==(Object other) => other is RetyRenk && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// W3C / CSS `hue-rotate` matrisi. Gri (göz, gölge) pikseller korunur.
List<double> _hueRotateMatrix(double degrees) {
  final rad = degrees * math.pi / 180;
  final c = math.cos(rad);
  final s = math.sin(rad);
  const lumR = 0.213;
  const lumG = 0.715;
  const lumB = 0.072;
  return <double>[
    lumR + c * (1 - lumR) + s * (-lumR),
    lumG + c * (-lumG) + s * (-lumG),
    lumB + c * (-lumB) + s * (1 - lumB),
    0,
    0,
    lumR + c * (-lumR) + s * 0.143,
    lumG + c * (1 - lumG) + s * 0.140,
    lumB + c * (-lumB) + s * (-0.283),
    0,
    0,
    lumR + c * (-lumR) + s * (-(1 - lumR)),
    lumG + c * (-lumG) + s * lumG,
    lumB + c * (1 - lumB) + s * lumB,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ];
}
