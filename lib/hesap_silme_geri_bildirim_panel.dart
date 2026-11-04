// Hesap silme nedenleri / sorun geri bildirimleri (yalnızca moderatör).
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:myvibel/app_theme.dart';
import 'package:myvibel/error_messages.dart';
import 'package:myvibel/moderator/mod_ortak.dart';
import 'package:myvibel/vibe_snackbar.dart';
import 'package:myvibel/widgets/vibe_yukleniyor.dart';

class HesapSilmeGeriBildirimPanel extends StatefulWidget {
  const HesapSilmeGeriBildirimPanel({super.key, this.gomulu = false});

  final bool gomulu;

  @override
  State<HesapSilmeGeriBildirimPanel> createState() =>
      _HesapSilmeGeriBildirimPanelState();
}

class _HesapSilmeGeriBildirimPanelState
    extends State<HesapSilmeGeriBildirimPanel> {
  String _nedenFiltresi = 'tumu';
  final Set<String> _gizliIdler = {};

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _akis =
      FirebaseFirestore.instance
          .collection('hesapSilmeGeriBildirimleri')
          .orderBy('olusturmaMs', descending: true)
          .limit(300)
          .snapshots();

  String _tarihYaz(dynamic raw) {
    if (raw is int) {
      final dt = DateTime.fromMillisecondsSinceEpoch(raw);
      final g = dt.day.toString().padLeft(2, '0');
      final a = dt.month.toString().padLeft(2, '0');
      final sa = dt.hour.toString().padLeft(2, '0');
      final dk = dt.minute.toString().padLeft(2, '0');
      return '$g.$a.${dt.year} $sa:$dk';
    }
    return '—';
  }

  String _nedenOku(Map<String, dynamic> data) {
    final neden = (data['neden'] ?? '').toString().trim();
    return neden.isEmpty ? 'Belirtilmemiş' : neden;
  }

  Future<void> _sil(DocumentReference<Map<String, dynamic>> ref) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kaydı sil'),
        content: const Text(
          'Bu geri bildirim kalıcı olarak silinecek. Emin misin?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (onay != true || !mounted) return;
    setState(() => _gizliIdler.add(ref.id));
    vibeSnackbarGoster(
      context,
      'Geri bildirim silindi.',
      tip: VibeMesajTipi.basari,
    );
    unawaited(
      ref.delete().catchError((Object e) {
        if (!mounted) return;
        setState(() => _gizliIdler.remove(ref.id));
        vibeSnackbarGoster(
          context,
          internetAwareErrorMessage(error: e, fallback: 'Silinemedi.'),
        );
      }),
    );
  }

  Future<void> _kopyala(String uid) async {
    await Clipboard.setData(ClipboardData(text: uid));
    if (!mounted) return;
    vibeSnackbarGoster(context, 'Kullanıcı kimliği kopyalandı.',
        tip: VibeMesajTipi.basari);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vibe = context.vibe;

    final govde = StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _akis,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return Center(
            child: VibeYukleniyor(renk: theme.colorScheme.primary),
          );
        }

        if (snapshot.hasError && !snapshot.hasData) {
          return ModBosDurum(
            ikon: Icons.wifi_off,
            baslik: 'Geri bildirimler yüklenemedi',
            aciklama: internetAwareErrorMessage(
              error: snapshot.error!,
              fallback: 'Bağlantını kontrol edip tekrar dene.',
            ),
          );
        }

        final tumu = (snapshot.data?.docs ?? [])
            .where((d) => !_gizliIdler.contains(d.id))
            .toList();
        final nedenSayilari = <String, int>{};
        for (final d in tumu) {
          final n = _nedenOku(d.data());
          nedenSayilari[n] = (nedenSayilari[n] ?? 0) + 1;
        }
        final nedenler = nedenSayilari.keys.toList()
          ..sort((a, b) => nedenSayilari[b]!.compareTo(nedenSayilari[a]!));
        if (_nedenFiltresi != 'tumu' &&
            !nedenSayilari.containsKey(_nedenFiltresi)) {
          _nedenFiltresi = 'tumu';
        }
        final docs = _nedenFiltresi == 'tumu'
            ? tumu
            : tumu.where((d) => _nedenOku(d.data()) == _nedenFiltresi).toList();

        return ModIcerikGenisligi(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
                child: Text(
                  'Hesabını silen kullanıcıların seçtiği neden ve yazdığı notlar. '
                  'Neden sayıları en çok seçilenden aza sıralı.',
                  style: TextStyle(color: vibe.mutedText, fontSize: 13),
                ),
              ),
              ModFiltreSatiri(
                baslik: 'Neden',
                secili: _nedenFiltresi,
                sec: (v) => setState(() => _nedenFiltresi = v),
                secenekler: [
                  ModFiltreSecenegi('tumu', 'Tümü', sayi: tumu.length),
                  for (final n in nedenler)
                    ModFiltreSecenegi(n, n, sayi: nedenSayilari[n]),
                ],
              ),
              const SizedBox(height: 6),
              Divider(height: 1, color: vibe.cardBorder),
              Expanded(
                child: docs.isEmpty
                    ? const ModBosDurum(
                        ikon: Icons.sentiment_satisfied_alt_outlined,
                        baslik: 'Kayıt yok',
                        aciklama: 'Hesap silen kullanıcı olunca nedeni burada görünecek.',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                        itemCount: docs.length,
                        itemBuilder: (context, index) => _kart(docs[index]),
                      ),
              ),
            ],
          ),
        );
      },
    );

    if (widget.gomulu) return govde;

    return Scaffold(
      appBar: AppBar(title: const Text('Hesap silme geri bildirimleri')),
      body: govde,
    );
  }

  Widget _kart(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final theme = Theme.of(context);
    final vibe = context.vibe;
    final data = doc.data();
    final neden = _nedenOku(data);
    final diger = (data['digerMetin'] ?? '').toString().trim();
    final sorun = (data['sorunMetin'] ?? '').toString().trim();
    final uid = (data['uid'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: vibe.cardDecoration(radius: 16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person_off_outlined,
                    size: 18, color: theme.colorScheme.onSurface),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    neden,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
                Text(
                  _tarihYaz(data['olusturmaMs']),
                  style: TextStyle(color: vibe.faintText, fontSize: 11.5),
                ),
                const SizedBox(width: 6),
              ],
            ),
            if (diger.isNotEmpty) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ModAlintiKutusu(baslik: 'DİĞER NEDEN', metin: diger),
              ),
            ],
            if (sorun.isNotEmpty) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ModAlintiKutusu(baslik: 'YAŞADIĞI SORUN', metin: sorun),
              ),
            ],
            if (diger.isEmpty && sorun.isEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Ek not bırakmamış.',
                style: TextStyle(color: vibe.faintText, fontSize: 12.5),
              ),
            ],
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: ModBilgiSatiri(
                    ikon: Icons.fingerprint,
                    etiket: 'Kullanıcı kimliği',
                    deger: uid.isEmpty ? '—' : uid,
                  ),
                ),
                if (uid.isNotEmpty)
                  IconButton(
                    tooltip: 'Kimliği kopyala',
                    onPressed: () => _kopyala(uid),
                    icon: Icon(Icons.copy, size: 18, color: vibe.mutedText),
                  ),
                IconButton(
                  tooltip: 'Kaydı sil',
                  onPressed: () => _sil(doc.reference),
                  icon: Icon(Icons.delete_outline,
                      size: 20, color: vibe.mutedText),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
