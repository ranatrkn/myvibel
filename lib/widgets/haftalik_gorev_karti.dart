// Haftalık görev kartı widget'ı.
import 'package:myvibel/tek_sefer_navigasyon.dart';
import 'package:flutter/material.dart';
import 'package:myvibel/app_theme.dart';
import 'package:myvibel/haftalik_gorev_servis.dart';
import 'package:myvibel/leaderboard_page.dart';

// Günün görevlerini ve haftalık puanı gösterir
class HaftalikGorevKarti extends StatelessWidget {
  const HaftalikGorevKarti({
    super.key,
    required this.durum,
    this.mascotUyuyor = false,
  });
 
  final HaftalikGorevDurum durum; // Görev durumu
  final bool mascotUyuyor; // Maskot uyuyorsa uyarı göster

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vibe = context.vibe;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: vibe.cardDecoration(radius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Günün Görevleri',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${HaftalikGorevServis.bugununAdi()} · ${durum.bugunkuKazanilanPuan}/${durum.bugunkuMaksPuan} puan',
                      style: TextStyle(color: vibe.mutedText, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${durum.puan}',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                  Text(
                    'bu hafta',
                    style: TextStyle(color: vibe.faintText, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (mascotUyuyor) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: vibe.inputFill,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: vibe.cardBorder),
              ),
              child: Text(
                "Vibel uyuyor. Gönderi, beğeni ve yorum görevleri için Vibel'in uyanması gerekir.",
                style: TextStyle(color: vibe.mutedText, fontSize: 12),
              ),
            ),
            const SizedBox(height: 12),
          ],
          ...durum.gorevler.map(
            (gorev) => _GorevSatiriWidget(
              gorev: gorev,
              mevcut: durum.sayac[gorev.aksiyon] ?? 0,
              tamamlandi: durum.gorevTamamMi(gorev),
            ),
          ),
          if (durum.gunBonusuAlindi) ...[
            const SizedBox(height: 8),
            const Text(
              'Gün bonusu alındı (+${HaftalikGorevServis.gunBonusu})',
              style: TextStyle(
                color: VibeAppTheme.accent,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ] else if (durum.gunTamamlandi) ...[
            const SizedBox(height: 8),
            Text(
              'Gün bonusu: +${HaftalikGorevServis.gunBonusu}',
              style: TextStyle(color: vibe.mutedText, fontSize: 12),
            ),
          ] else ...[
            const SizedBox(height: 8),
            Text(
              '${durum.gorevler.length}/${durum.gorevler.length} bitince +${HaftalikGorevServis.gunBonusu} bonus',
              style: TextStyle(color: vibe.mutedText, fontSize: 12),
            ),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {
                tekSeferPush(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const LeaderboardPage(),
                  ),
                );
              },
              icon: const Icon(Icons.leaderboard_outlined, size: 18),
              label: const Text('Liderlik tablosu'),
            ),
          ),
        ],
      ),
    );
  }
}

// Tek görev satırı (ilerleme + ödül)
class _GorevSatiriWidget extends StatelessWidget {
  const _GorevSatiriWidget({
    required this.gorev,
    required this.mevcut,
    required this.tamamlandi,
  });

  final GorevSatiri gorev;
  final int mevcut;
  final bool tamamlandi;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vibe = context.vibe;
    final metin = tamamlandi
        ? gorev.baslik
        : '${gorev.baslik}  ${mevcut.clamp(0, gorev.hedef)}/${gorev.hedef}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            tamamlandi ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 18,
            color: tamamlandi ? VibeAppTheme.accent : vibe.mutedText,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              metin,
              style: TextStyle(
                color:
                    tamamlandi ? vibe.mutedText : theme.colorScheme.onSurface,
                fontSize: 13,
                decoration: tamamlandi ? TextDecoration.lineThrough : null,
                decorationColor: vibe.mutedText,
              ),
            ),
          ),
          Text(
            tamamlandi ? '+${gorev.odul}' : '+${gorev.odul}',
            style: TextStyle(
              color: tamamlandi
                  ? VibeAppTheme.accent
                  : theme.colorScheme.primary.withOpacity(0.85),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
