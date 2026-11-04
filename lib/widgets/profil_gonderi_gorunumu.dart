import 'package:myvibel/tek_sefer_navigasyon.dart';
import 'package:flutter/material.dart';
import 'package:myvibel/alinti_gonderi.dart';
import 'package:myvibel/app_theme.dart';
import 'package:myvibel/maestro_semantics.dart';
import 'package:myvibel/utils/tarih_saat.dart';

enum ProfilGonderiGorunumu { liste, izgara }

class ProfilGorunumAnahtari extends StatelessWidget {
  const ProfilGorunumAnahtari({
    super.key,
    required this.gorunum,
    required this.onChanged,
  });

  final ProfilGonderiGorunumu gorunum;
  final ValueChanged<ProfilGonderiGorunumu> onChanged;

  @override
  Widget build(BuildContext context) {
    final vibe = context.vibe;
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: vibe.inputFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: vibe.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _GorunumButonu(
            icon: Icons.view_agenda_rounded,
            label: MaestroSemantics.listeGorunumu,
            selected: gorunum == ProfilGonderiGorunumu.liste,
            color: theme.colorScheme.onSurface,
            onTap: () => onChanged(ProfilGonderiGorunumu.liste),
          ),
          const SizedBox(width: 4),
          _GorunumButonu(
            icon: Icons.grid_view_rounded,
            label: MaestroSemantics.izgaraGorunumu,
            selected: gorunum == ProfilGonderiGorunumu.izgara,
            color: theme.colorScheme.onSurface,
            onTap: () => onChanged(ProfilGonderiGorunumu.izgara),
          ),
        ],
      ),
    );
  }
}

class _GorunumButonu extends StatelessWidget {
  const _GorunumButonu({
    required this.icon,
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return maestroButton(
      label: label,
      selected: selected,
      onTap: onTap,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: selected
                  ? const Color.fromARGB(255, 120, 0, 0)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: selected ? Colors.white : color),
          ),
        ),
      ),
    );
  }
}

class ProfilGonderiIzgaraKarti extends StatelessWidget {
  const ProfilGonderiIzgaraKarti({
    super.key,
    required this.postId,
    required this.currentUserId,
    required this.kullaniciAdi,
    required this.createdAt,
    required this.metin,
    required this.begeniSayisi,
    required this.yorumSayisi,
    this.alintiSnapshot,
    this.onSil,
  });

  final String postId;
  final String currentUserId;
  final String kullaniciAdi;
  final dynamic createdAt;
  final String metin;
  final int begeniSayisi;
  final int yorumSayisi;
  final AlintiGonderiSnapshot? alintiSnapshot;
  final VoidCallback? onSil;

  @override
  Widget build(BuildContext context) {
    final vibe = context.vibe;
    final theme = Theme.of(context);
    final sadeceMetin = metin.trim();
    final onizleme = sadeceMetin.isEmpty
        ? (alintiSnapshot != null ? 'Alıntılı gönderi' : 'Metin yok')
        : sadeceMetin;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        gonderiDetayiniAc(
          context,
          postId: postId,
          currentUserId: currentUserId,
        );
      },
      child: Container(
        decoration: vibe.cardDecoration(radius: 16),
        padding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: onSil != null ? 28 : 0),
                        child: Text(
                          kullaniciAdi,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    if (alintiSnapshot != null)
                      Icon(Icons.format_quote_rounded,
                          size: 16, color: vibe.mutedText),
                  ],
                ),
            const SizedBox(height: 4),
            Text(
              tarihSaatYaz(createdAt),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: vibe.faintText, fontSize: 12),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Text(
                onizleme,
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                  height: 1.25,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.favorite_outline_rounded,
                    size: 16, color: vibe.mutedText),
                const SizedBox(width: 4),
                Text('$begeniSayisi',
                    style: TextStyle(color: vibe.mutedText, fontSize: 12)),
                const SizedBox(width: 10),
                Icon(Icons.mode_comment_outlined,
                    size: 16, color: vibe.mutedText),
                const SizedBox(width: 4),
                Text('$yorumSayisi',
                    style: TextStyle(color: vibe.mutedText, fontSize: 12)),
              ],
            ),
              ],
            ),
            if (onSil != null)
              Positioned(
                top: -4,
                right: -4,
                child: IconButton(
                  tooltip: MaestroSemantics.gonderiyiSil,
                  splashRadius: 20,
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(
                    minHeight: 32,
                    minWidth: 32,
                  ),
                  onPressed: onSil,
                  icon: const Icon(
                    Icons.delete_forever_rounded,
                    size: 20,
                    color: Colors.redAccent,
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
    );
  }
}
