// Yalnızca moderatör hesabının erişebildiği destek talepleri paneli.
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:myvibel/app_theme.dart';
import 'package:myvibel/destek_servis.dart';
import 'package:myvibel/error_messages.dart';
import 'package:myvibel/moderator/mod_ortak.dart';
import 'package:myvibel/tek_sefer_navigasyon.dart';
import 'package:myvibel/utils/tarih_saat.dart';
import 'package:myvibel/vibe_snackbar.dart';
import 'package:myvibel/widgets/vibe_yukleniyor.dart';
import 'package:url_launcher/url_launcher.dart';

class DestekTalepleriPanelPage extends StatefulWidget {
  const DestekTalepleriPanelPage({super.key, this.gomulu = false});

  final bool gomulu;

  @override
  State<DestekTalepleriPanelPage> createState() =>
      _DestekTalepleriPanelPageState();
}

class _DestekTalepleriPanelPageState extends State<DestekTalepleriPanelPage> {
  bool _erisimKontrolEdiliyor = true;
  bool _erisimVar = false;
  String _durumFiltresi = 'pending';
  String _kategoriFiltresi = 'tumu';
  final Map<String, String> _yerelDurum = {};

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _talepAkisi =
      FirebaseFirestore.instance
          .collection('supportTickets')
          .orderBy('createdAt', descending: true)
          .limit(200)
          .snapshots();

  static const _durumEtiketleri = <String, String>{
    'pending': 'Bekliyor',
    'reviewed': 'İnceleniyor',
    'resolved': 'Çözüldü',
    'rejected': 'Reddedildi',
  };

  static const _kategoriIkonlari = <String, IconData>{
    'hesap': Icons.manage_accounts_outlined,
    'hata': Icons.bug_report_outlined,
    'yas_itiraz': Icons.badge_outlined,
    'oneri': Icons.lightbulb_outline,
    'diger': Icons.help_outline,
  };

  @override
  void initState() {
    super.initState();
    if (widget.gomulu) {
      _erisimVar = true;
      _erisimKontrolEdiliyor = false;
    } else {
      _erisimiDogrula();
    }
  }

  Future<void> _erisimiDogrula() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) Navigator.pop(context);
      return;
    }

    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final yetkili = doc.data()?['isModerator'] == true;
      if (!mounted) return;
      if (!yetkili) {
        Navigator.pop(context);
        vibeSnackbarGoster(
          context,
          'Bu alana erişim yetkin yok.',
          tip: VibeMesajTipi.uyari,
        );
        return;
      }
      setState(() {
        _erisimVar = true;
        _erisimKontrolEdiliyor = false;
      });
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      vibeSnackbarGoster(
        context,
        internetAwareErrorMessage(
          error: e,
          fallback: 'Erişim doğrulanamadı.',
        ),
      );
    }
  }

  String _durumOku(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final sunucu = (doc.data()['status'] ?? 'pending').toString();
    final yerel = _yerelDurum[doc.id];
    if (yerel == null) return sunucu;
    if (yerel == sunucu) _yerelDurum.remove(doc.id);
    return yerel;
  }

  void _durumGuncelle(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    String durum,
    String basariMesaji,
  ) {
    final onceki = _durumOku(doc);
    setState(() => _yerelDurum[doc.id] = durum);
    vibeSnackbarGoster(context, basariMesaji, tip: VibeMesajTipi.basari);
    unawaited(
      doc.reference.update({
        'status': durum,
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': FirebaseAuth.instance.currentUser?.uid ?? '',
      }).catchError((Object e) {
        if (!mounted) return;
        setState(() => _yerelDurum[doc.id] = onceki);
        vibeSnackbarGoster(
          context,
          internetAwareErrorMessage(
            error: e,
            fallback: 'Durum güncellenemedi.',
          ),
        );
      }),
    );
  }

  String _durumMetni(String durum) => _durumEtiketleri[durum] ?? durum;

  String _kategoriMetni(String kategori) =>
      DestekServis.kategoriler[kategori] ?? kategori;

  Color _durumRengi(String durum) {
    switch (durum) {
      case 'pending':
        return Colors.orange;
      case 'resolved':
        return Colors.green;
      case 'rejected':
        return Colors.redAccent;
      default:
        return Colors.blue;
    }
  }

  Future<void> _kopyala(String metin, String mesaj) async {
    await Clipboard.setData(ClipboardData(text: metin));
    if (!mounted) return;
    vibeSnackbarGoster(context, mesaj, tip: VibeMesajTipi.basari);
  }

  Future<void> _epostaYaz(String eposta, String konu) async {
    final uri = Uri(
      scheme: 'mailto',
      path: eposta,
      query: 'subject=${Uri.encodeComponent('Re: $konu')}',
    );
    final acildi = await launchUrl(uri);
    if (!acildi && mounted) {
      await _kopyala(eposta, 'E-posta uygulaması açılamadı; adres kopyalandı.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vibe = context.vibe;

    if (_erisimKontrolEdiliyor || !_erisimVar) {
      if (widget.gomulu) {
        return const Center(child: VibeYukleniyor());
      }
      return Scaffold(
        appBar: AppBar(title: const Text('Destek Talepleri')),
        body: const Center(child: VibeYukleniyor()),
      );
    }

    final govde = StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _talepAkisi,
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
            baslik: 'Talepler yüklenemedi',
            aciklama: internetAwareErrorMessage(
              error: snapshot.error!,
              fallback: 'Bağlantını kontrol edip tekrar dene.',
            ),
          );
        }

        final tumu = snapshot.data?.docs ?? [];
        final durumSayilari = <String, int>{};
        for (final d in tumu) {
          final s = _durumOku(d);
          durumSayilari[s] = (durumSayilari[s] ?? 0) + 1;
        }
        final durumaUyan = tumu
            .where((d) =>
                _durumFiltresi == 'tumu' || _durumOku(d) == _durumFiltresi)
            .toList();
        final kategoriSayilari = <String, int>{};
        for (final d in durumaUyan) {
          final k = (d.data()['kategori'] ?? '').toString();
          kategoriSayilari[k] = (kategoriSayilari[k] ?? 0) + 1;
        }
        final docs = durumaUyan
            .where((d) =>
                _kategoriFiltresi == 'tumu' ||
                (d.data()['kategori'] ?? '').toString() == _kategoriFiltresi)
            .toList();

        return ModIcerikGenisligi(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 4),
              ModFiltreSatiri(
                baslik: 'Durum',
                secili: _durumFiltresi,
                sec: (v) => setState(() => _durumFiltresi = v),
                secenekler: [
                  ModFiltreSecenegi('pending', 'Bekleyen',
                      sayi: durumSayilari['pending'] ?? 0),
                  ModFiltreSecenegi('reviewed', 'İnceleniyor',
                      sayi: durumSayilari['reviewed'] ?? 0),
                  ModFiltreSecenegi('resolved', 'Çözülen',
                      sayi: durumSayilari['resolved'] ?? 0),
                  ModFiltreSecenegi('rejected', 'Reddedilen',
                      sayi: durumSayilari['rejected'] ?? 0),
                  ModFiltreSecenegi('tumu', 'Tümü', sayi: tumu.length),
                ],
              ),
              ModFiltreSatiri(
                baslik: 'Konu',
                secili: _kategoriFiltresi,
                sec: (v) => setState(() => _kategoriFiltresi = v),
                secenekler: [
                  const ModFiltreSecenegi('tumu', 'Hepsi'),
                  for (final k in DestekServis.kategoriler.keys)
                    ModFiltreSecenegi(
                      k,
                      DestekServis.kategoriler[k]!,
                      sayi: kategoriSayilari[k] ?? 0,
                      ikon: _kategoriIkonlari[k],
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Divider(height: 1, color: vibe.cardBorder),
              Expanded(
                child: docs.isEmpty
                    ? ModBosDurum(
                        ikon: _durumFiltresi == 'pending'
                            ? Icons.mark_email_read_outlined
                            : Icons.inbox_outlined,
                        baslik: _durumFiltresi == 'pending'
                            ? 'Bekleyen talep yok'
                            : 'Bu filtrede talep yok',
                        aciklama: _durumFiltresi == 'pending'
                            ? 'Kullanıcılar destek veya öneri gönderince burada görünecek.'
                            : 'Başka bir durum veya konu seçebilirsin.',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                        itemCount: docs.length,
                        itemBuilder: (context, index) =>
                            _talepKarti(docs[index]),
                      ),
              ),
            ],
          ),
        );
      },
    );

    if (widget.gomulu) return govde;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Destek Talepleri')),
      body: govde,
    );
  }

  Widget _talepKarti(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final theme = Theme.of(context);
    final vibe = context.vibe;
    final data = doc.data();
    final status = _durumOku(doc);
    final kategori = (data['kategori'] ?? '').toString();
    final konu = (data['konu'] ?? '').toString();
    final mesaj = (data['mesaj'] ?? '').toString();
    final kullaniciAdi =
        (data['kullaniciAdi'] ?? 'Vibe Kullanıcısı').toString();
    final userId = (data['userId'] ?? '').toString();
    final eposta = (data['eposta'] ?? '').toString().trim();
    final appVersion = (data['appVersion'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: vibe.cardDecoration(radius: 16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _kategoriIkonlari[kategori] ?? Icons.support_agent_outlined,
                  size: 18,
                  color: theme.colorScheme.onSurface,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    _kategoriMetni(kategori),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: vibe.mutedText,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ModRozet(metin: _durumMetni(status), renk: _durumRengi(status)),
                const Spacer(),
                Text(
                  tarihSaatYaz(data['createdAt']),
                  style: TextStyle(color: vibe.faintText, fontSize: 11.5),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              konu,
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            ModAlintiKutusu(metin: mesaj),
            const SizedBox(height: 8),
            ModBilgiSatiri(
              ikon: Icons.person_outline,
              etiket: 'Gönderen',
              deger: '@$kullaniciAdi',
              onTap: userId.isEmpty ? null : () => profiliAc(context, userId),
            ),
            if (eposta.isNotEmpty)
              ModBilgiSatiri(
                ikon: Icons.mail_outline,
                etiket: 'E-posta',
                deger: eposta,
                sonEk: IconButton(
                  tooltip: 'E-postayı kopyala',
                  visualDensity: VisualDensity.compact,
                  iconSize: 16,
                  onPressed: () => _kopyala(eposta, 'E-posta kopyalandı.'),
                  icon: Icon(Icons.copy, color: vibe.mutedText),
                ),
              ),
            if (appVersion.isNotEmpty)
              ModBilgiSatiri(
                ikon: Icons.phone_android,
                etiket: 'Uygulama sürümü',
                deger: appVersion,
              ),
            const SizedBox(height: 10),
            Divider(height: 1, color: vibe.cardBorder),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (status != 'resolved')
                        FilledButton.icon(
                          onPressed: () => _durumGuncelle(
                            doc,
                            'resolved',
                            'Talep çözüldü olarak kapatıldı.',
                          ),
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text('Çözüldü'),
                        ),
                      if (status == 'pending')
                        OutlinedButton.icon(
                          onPressed: () => _durumGuncelle(
                            doc,
                            'reviewed',
                            'Talep incelemeye alındı.',
                          ),
                          icon: const Icon(Icons.hourglass_top, size: 18),
                          label: const Text('İncelemeye al'),
                        ),
                      if (eposta.isNotEmpty)
                        TextButton.icon(
                          onPressed: () => _epostaYaz(eposta, konu),
                          icon: const Icon(Icons.reply, size: 18),
                          label: const Text('E-postayla yanıtla'),
                        ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Diğer işlemler',
                  icon: Icon(Icons.more_vert, color: vibe.mutedText),
                  onSelected: (secim) {
                    switch (secim) {
                      case 'rejected':
                        _durumGuncelle(doc, 'rejected', 'Talep reddedildi.');
                      case 'pending':
                        _durumGuncelle(
                          doc,
                          'pending',
                          'Talep yeniden bekleyenlere alındı.',
                        );
                    }
                  },
                  itemBuilder: (_) => [
                    if (status != 'rejected')
                      const PopupMenuItem(
                        value: 'rejected',
                        child: Text('Reddet'),
                      ),
                    if (status != 'pending')
                      const PopupMenuItem(
                        value: 'pending',
                        child: Text('Bekleyenlere geri al'),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
