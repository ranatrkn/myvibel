// Moderatör ekranlarında ortak küçük parçalar.
import 'package:flutter/material.dart';
import 'package:myvibel/app_theme.dart';

/// Geniş ekranda içeriği okunur genişlikte ortalar.
class ModIcerikGenisligi extends StatelessWidget {
  const ModIcerikGenisligi({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 920),
        child: child,
      ),
    );
  }
}

/// Renkli küçük durum etiketi.
class ModRozet extends StatelessWidget {
  const ModRozet({
    super.key,
    required this.metin,
    required this.renk,
    this.ikon,
  });

  final String metin;
  final Color renk;
  final IconData? ikon;

  @override
  Widget build(BuildContext context) {
    final koyu = Theme.of(context).brightness == Brightness.dark;
    final yazi = koyu ? renk : Color.lerp(renk, Colors.black, 0.35)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: renk.withOpacity(koyu ? 0.16 : 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: renk.withOpacity(0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (ikon != null) ...[
            Icon(ikon, size: 13, color: yazi),
            const SizedBox(width: 4),
          ],
          Text(
            metin,
            style: TextStyle(
              color: yazi,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Sayılı filtre seçeneği.
class ModFiltreSecenegi {
  const ModFiltreSecenegi(this.deger, this.etiket, {this.sayi, this.ikon});

  final String deger;
  final String etiket;
  final int? sayi;
  final IconData? ikon;
}

class ModFiltreSatiri extends StatelessWidget {
  const ModFiltreSatiri({
    super.key,
    required this.baslik,
    required this.secenekler,
    required this.secili,
    required this.sec,
  });

  final String baslik;
  final List<ModFiltreSecenegi> secenekler;
  final String secili;
  final ValueChanged<String> sec;

  @override
  Widget build(BuildContext context) {
    final vibe = context.vibe;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Text(
              baslik,
              style: TextStyle(
                color: vibe.mutedText,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final s in secenekler)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        avatar: s.ikon == null ? null : Icon(s.ikon, size: 16),
                        label: Text(
                          s.sayi == null ? s.etiket : '${s.etiket} (${s.sayi})',
                        ),
                        selected: secili == s.deger,
                        showCheckmark: false,
                        onSelected: (_) => sec(s.deger),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Liste boşken gösterilen açıklama.
class ModBosDurum extends StatelessWidget {
  const ModBosDurum({
    super.key,
    required this.ikon,
    required this.baslik,
    this.aciklama,
  });

  final IconData ikon;
  final String baslik;
  final String? aciklama;

  @override
  Widget build(BuildContext context) {
    final vibe = context.vibe;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(ikon, size: 44, color: vibe.faintText),
            const SizedBox(height: 12),
            Text(
              baslik,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (aciklama != null) ...[
              const SizedBox(height: 6),
              Text(
                aciklama!,
                textAlign: TextAlign.center,
                style: TextStyle(color: vibe.mutedText, height: 1.4),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Kart içinde etiketli bilgi satırı; [onTap] varsa bağlantı gibi görünür.
class ModBilgiSatiri extends StatelessWidget {
  const ModBilgiSatiri({
    super.key,
    required this.ikon,
    required this.etiket,
    required this.deger,
    this.onTap,
    this.sonEk,
  });

  final IconData ikon;
  final String etiket;
  final String deger;
  final VoidCallback? onTap;
  final Widget? sonEk;

  @override
  Widget build(BuildContext context) {
    final vibe = context.vibe;
    final theme = Theme.of(context);
    final satir = Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(ikon, size: 15, color: vibe.faintText),
          const SizedBox(width: 6),
          Text(
            '$etiket: ',
            style: TextStyle(color: vibe.faintText, fontSize: 12.5),
          ),
          Flexible(
            child: Text(
              deger,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: onTap != null
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                decoration: onTap != null ? TextDecoration.underline : null,
                decorationColor: theme.colorScheme.primary.withOpacity(0.5),
              ),
            ),
          ),
          if (sonEk != null) sonEk!,
        ],
      ),
    );
    if (onTap == null) return satir;
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: satir,
    );
  }
}

/// Kullanıcının yazdığı metni alıntı kutusunda gösterir.
class ModAlintiKutusu extends StatelessWidget {
  const ModAlintiKutusu({
    super.key,
    required this.metin,
    this.baslik,
    this.maxLines,
  });

  final String metin;
  final String? baslik;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final vibe = context.vibe;
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: vibe.inputFill,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: theme.colorScheme.primary, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (baslik != null) ...[
            Text(
              baslik!,
              style: TextStyle(
                color: vibe.faintText,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
          ],
          SelectableText(
            metin,
            minLines: maxLines == null ? null : 1,
            maxLines: maxLines,
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
