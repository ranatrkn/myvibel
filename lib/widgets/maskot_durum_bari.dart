// Maskot enerji/mutluluk ilerleme çubuğu.
import 'package:flutter/material.dart';
import 'package:myvibel/app_theme.dart';

// Etiketli yüzdelik durum çubuğu
class MascotDurumBari extends StatelessWidget {
  const MascotDurumBari({
    super.key,
    required this.etiket,
    required this.deger,
    required this.renk,
    this.ters = false,
    this.compact = false,
    this.sayiGoster = true,
  });

  final String etiket; // Gösterilecek isim (Enerji, Mutluluk)
  final int deger; // 0-100 arası değer
  final Color renk; // Çubuk rengi
  final bool ters; // Doluluk tersine çevrilsin mi
  final bool compact; // Küçük boyut modu
  final bool sayiGoster; // Sağdaki sayısal değer

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vibe = context.vibe;
    final gosterim = ters ? (100 - deger.clamp(0, 100)) : deger.clamp(0, 100);
    final oran = gosterim / 100.0;

    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 6 : 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                etiket,
                style: TextStyle(
                  color: vibe.mutedText,
                  fontSize: compact ? 11 : 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (sayiGoster) ...[
                const Spacer(),
                Text(
                  '$deger',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: compact ? 11 : 12,
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: compact ? 4 : 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: oran,
              minHeight: compact ? 6 : 8,
              backgroundColor: vibe.isDark ? vibe.inputFill : vibe.cardBorder,
              valueColor: AlwaysStoppedAnimation<Color>(renk),
            ),
          ),
        ],
      ),
    );
  }
}
