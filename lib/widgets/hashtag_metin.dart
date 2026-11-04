// Hashtag ve @bahsetme tıklanabilir metin widget'ı.
import 'package:myvibel/tek_sefer_navigasyon.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:myvibel/app_theme.dart';
import 'package:myvibel/sosyal_servis.dart';

// Metin parçası türü
enum _MetinParcaTipi { metin, hashtag, bahsetme }

// Metin içindeki hashtag/bahsetme parçası
class _MetinParca {
  final int baslangic;
  final int bitis;
  final _MetinParcaTipi tip;
  final String ham;
  final String deger;

  const _MetinParca({
    required this.baslangic,
    required this.bitis,
    required this.tip,
    required this.ham,
    required this.deger,
  });
}

// #etiket ve @kullanici linklerini renklendirir
class HashtagMetin extends StatelessWidget {
  final String metin;
  final TextStyle? style;
  final Map<String, String>? mentionUidleri;
  final void Function(String tag)? onHashtagTap;
  final void Function(String kullaniciAdi, String? uid)? onMentionTap;

  const HashtagMetin({
    super.key,
    required this.metin,
    this.style,
    this.mentionUidleri,
    this.onHashtagTap,
    this.onMentionTap,
  });

  static final RegExp _hashtagRegex = RegExp(
    r'#([a-zA-Z0-9_\.\u00C0-\u024F\u0130\u0131\u015f\u011f\u00fc\u00f6\u00e7]+)',
  );
  static final RegExp _bahsetmeRegex = RegExp(r'@([a-zA-Z0-9_\.]{3,30})');

  // Metni hashtag ve bahsetme parçalarına ayırır
  List<_MetinParca> _parcala() {
    final parcalar = <_MetinParca>[];

    for (final match in _hashtagRegex.allMatches(metin)) {
      final tag = SosyalServis.etiketNormalize(match.group(1) ?? "");
      if (tag.isEmpty) continue;
      parcalar.add(
        _MetinParca(
          baslangic: match.start,
          bitis: match.end,
          tip: _MetinParcaTipi.hashtag,
          ham: match.group(0) ?? "",
          deger: tag,
        ),
      );
    }

    for (final match in _bahsetmeRegex.allMatches(metin)) {
      final ad = SosyalServis.etiketNormalize(match.group(1) ?? "");
      if (ad.length < 3) continue;
      parcalar.add(
        _MetinParca(
          baslangic: match.start,
          bitis: match.end,
          tip: _MetinParcaTipi.bahsetme,
          ham: match.group(0) ?? "",
          deger: ad,
        ),
      );
    }

    parcalar.sort((a, b) => a.baslangic.compareTo(b.baslangic));

    final temiz = <_MetinParca>[];
    var sonBitis = -1;
    for (final parca in parcalar) {
      if (parca.baslangic < sonBitis) continue;
      temiz.add(parca);
      sonBitis = parca.bitis;
    }
    return temiz;
  }

  // @bahsetme tıklanınca profile gider
  Future<void> _bahsetmeyeGit(
    BuildContext context,
    String kullaniciAdi,
  ) async {
    final bilet = tekSeferGecisAl();
    if (bilet == null) return;
    final uid = mentionUidleri?[kullaniciAdi] ??
        await SosyalServis.kullaniciUidGetir(kullaniciAdi);
    onMentionTap?.call(kullaniciAdi, uid);
    if (uid == null || !context.mounted) {
      tekSeferGecisIptal(bilet);
      return;
    }
    profiliAc(context, uid);
    tekSeferGecisBirak(bilet);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseStyle = style ??
        TextStyle(
          color: theme.colorScheme.onSurface,
          fontWeight: FontWeight.w500,
          fontSize: 15,
        );
    final parcalar = _parcala();
    if (parcalar.isEmpty) {
      return Text(metin, style: baseStyle);
    }

    final spans = <InlineSpan>[];
    var start = 0;

    for (final parca in parcalar) {
      if (parca.baslangic > start) {
        spans.add(TextSpan(text: metin.substring(start, parca.baslangic)));
      }

      switch (parca.tip) {
        case _MetinParcaTipi.hashtag:
          spans.add(
            TextSpan(
              text: parca.ham,
              style: baseStyle.copyWith(
                color: VibeAppTheme.accent,
                fontWeight: FontWeight.bold,
              ),
              recognizer: onHashtagTap == null
                  ? null
                  : (TapGestureRecognizer()
                    ..onTap = () => onHashtagTap!(parca.deger)),
            ),
          );
          break;
        case _MetinParcaTipi.bahsetme:
          spans.add(
            TextSpan(
              text: parca.ham,
              style: baseStyle.copyWith(
                color: Colors.lightBlueAccent,
                fontWeight: FontWeight.w600,
              ),
              recognizer: TapGestureRecognizer()
                ..onTap = () => _bahsetmeyeGit(context, parca.deger),
            ),
          );
          break;
        case _MetinParcaTipi.metin:
          break;
      }

      start = parca.bitis;
    }

    if (start < metin.length) {
      spans.add(TextSpan(text: metin.substring(start)));
    }

    return Text.rich(TextSpan(style: baseStyle, children: spans));
  }
}
