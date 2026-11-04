// Moderatör şikayet kuyruğu paneli.
import 'dart:async';

import 'package:myvibel/tek_sefer_navigasyon.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:myvibel/app_theme.dart';
import 'package:myvibel/error_messages.dart';
import 'package:myvibel/moderator/mod_ortak.dart';
import 'package:myvibel/sosyal/moderasyon_servis.dart';
import 'package:myvibel/utils/tarih_saat.dart';
import 'package:myvibel/vibe_snackbar.dart';
import 'package:myvibel/widgets/vibe_gradient_scaffold.dart';
import 'package:myvibel/widgets/vibe_yukleniyor.dart';

class ModerasyonPanelPage extends StatefulWidget {
  const ModerasyonPanelPage({super.key, this.gomulu = false});

  /// Üst konsol içinde gösteriliyorsa AppBar/erişim kontrolü atlanır.
  final bool gomulu;

  @override
  State<ModerasyonPanelPage> createState() => _ModerasyonPanelPageState();
}

class _ModerasyonPanelPageState extends State<ModerasyonPanelPage> {
  bool _erisimKontrolEdiliyor = true;
  bool _erisimVar = false;
  String _turFiltresi = 'tumu';
  String _durumFiltresi = 'pending';
  final Map<String, String> _kullaniciEtiketleri = {};
  final Map<String, RaporIcerik> _icerikOnbellegi = {};
  final Map<String, String> _yerelDurum = {};
  final Map<String, bool> _yerelGizli = {};
  String? _sonRaporImzasi;

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _raporAkisi =
      FirebaseFirestore.instance
          .collection('reports')
          .orderBy('createdAt', descending: true)
          .limit(200)
          .snapshots();

  static const _turEtiketleri = <String, String>{
    'post': 'Gönderi',
    'comment': 'Yorum',
    'user': 'Hesap',
  };

  static const _turIkonlari = <String, IconData>{
    'post': Icons.article_outlined,
    'comment': Icons.chat_bubble_outline,
    'user': Icons.person_outline,
  };

  static final _gizleStili = FilledButton.styleFrom(
    backgroundColor: Colors.redAccent,
    foregroundColor: Colors.white,
  );

  static const _durumEtiketleri = <String, String>{
    'pending': 'Bekliyor',
    'reviewed': 'İncelendi',
    'action_taken': 'Gizlendi',
    'rejected': 'Sorun yok',
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
      final yetkili = await ModerasyonServis.moderatorMu(uid);
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

  String _turMetni(String tur) => _turEtiketleri[tur] ?? tur;

  String _durumMetni(String durum) => _durumEtiketleri[durum] ?? durum;

  Color _durumRengi(String durum) {
    switch (durum) {
      case 'pending':
        return Colors.orange;
      case 'action_taken':
        return Colors.redAccent;
      case 'rejected':
        return Colors.green;
      default:
        return Colors.blue;
    }
  }

  IconData _durumIkonu(String durum) {
    switch (durum) {
      case 'pending':
        return Icons.schedule;
      case 'action_taken':
        return Icons.visibility_off_outlined;
      case 'rejected':
        return Icons.check_circle_outline;
      default:
        return Icons.done;
    }
  }

  String _durumOku(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final sunucu = (doc.data()['status'] ?? 'pending').toString();
    final yerel = _yerelDurum[doc.id];
    if (yerel == null) return sunucu;
    if (yerel == sunucu) _yerelDurum.remove(doc.id);
    return yerel;
  }

  Future<void> _raporBaglaminiYukle(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    final uidler = <String>{};
    for (final doc in docs) {
      final data = doc.data();
      final reporter = (data['reporterUid'] ?? '').toString();
      final target = (data['targetUid'] ?? '').toString();
      if (reporter.isNotEmpty) uidler.add(reporter);
      if (target.isNotEmpty) uidler.add(target);
    }

    final eksikUidler =
        uidler.where((uid) => !_kullaniciEtiketleri.containsKey(uid)).toSet();
    if (eksikUidler.isNotEmpty) {
      final yeni = await ModerasyonServis.kullaniciEtiketleriGetir(eksikUidler);
      if (!mounted) return;
      setState(() => _kullaniciEtiketleri.addAll(yeni));
    }

    final eksikler =
        docs.where((d) => !_icerikOnbellegi.containsKey(d.id)).toList();
    final sonuclar = await Future.wait(
      eksikler.map((d) => ModerasyonServis.raporIcerikDurumu(d.data())),
    );
    if (!mounted) return;
    setState(() {
      for (var i = 0; i < eksikler.length; i++) {
        final s = sonuclar[i];
        if (s != null) _icerikOnbellegi[eksikler[i].id] = s;
      }
    });
  }

  String _kullaniciEtiketi(String uid) {
    if (uid.isEmpty) return '—';
    return _kullaniciEtiketleri[uid] ?? 'Yükleniyor…';
  }

  bool? _icerikGizliMi(String docId) {
    final yerel = _yerelGizli[docId];
    if (yerel != null) return yerel;
    final o = _icerikOnbellegi[docId];
    if (o == null || o.silinmis) return null;
    return o.gizli;
  }

  void _hataGoster(Object e, String yedek) {
    if (!mounted) return;
    vibeSnackbarGoster(
      context,
      internetAwareErrorMessage(error: e, fallback: yedek),
    );
  }

  void _durumYap(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    String durum,
    String basariMesaji,
  ) {
    final onceki = _durumOku(doc);
    setState(() => _yerelDurum[doc.id] = durum);
    vibeSnackbarGoster(context, basariMesaji, tip: VibeMesajTipi.basari);
    unawaited(
      ModerasyonServis.raporDurumuGuncelle(raporRef: doc.reference, durum: durum)
          .catchError((Object e) {
        if (!mounted) return;
        setState(() => _yerelDurum[doc.id] = onceki);
        _hataGoster(e, 'Durum güncellenemedi.');
      }),
    );
  }

  void _gizle(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final onceki = _durumOku(doc);
    setState(() {
      _yerelDurum[doc.id] = 'action_taken';
      _yerelGizli[doc.id] = true;
    });
    vibeSnackbarGoster(
      context,
      'İçerik gizlendi ve şikayet kapatıldı.',
      tip: VibeMesajTipi.basari,
    );
    unawaited(
      ModerasyonServis.islemUygula(raporRef: doc.reference, data: doc.data())
          .catchError((Object e) {
        if (!mounted) return;
        setState(() {
          _yerelDurum[doc.id] = onceki;
          _yerelGizli.remove(doc.id);
        });
        _hataGoster(e, 'İçerik gizlenemedi.');
      }),
    );
  }

  void _yayinaAl(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final onceki = _durumOku(doc);
    setState(() {
      _yerelDurum[doc.id] = 'rejected';
      _yerelGizli[doc.id] = false;
    });
    vibeSnackbarGoster(
      context,
      'İçerik yeniden yayında; şikayet kapatıldı.',
      tip: VibeMesajTipi.basari,
    );
    unawaited(() async {
      try {
        await ModerasyonServis.icerikGizlemesiniKaldir(doc.data());
        await ModerasyonServis.raporDurumuGuncelle(
          raporRef: doc.reference,
          durum: 'rejected',
        );
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _yerelDurum[doc.id] = onceki;
          _yerelGizli.remove(doc.id);
        });
        _hataGoster(e, 'Gizleme kaldırılamadı.');
      }
    }());
  }

  void _icerigiAc(Map<String, dynamic> data) {
    final tur = (data['type'] ?? '').toString();
    if (tur == 'user') {
      profiliAc(context, (data['targetUid'] ?? '').toString());
      return;
    }
    gonderiDetayiniAc(
      context,
      postId: (data['postId'] ?? '').toString(),
      currentUserId: FirebaseAuth.instance.currentUser?.uid ?? '',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vibe = context.vibe;

    if (_erisimKontrolEdiliyor || !_erisimVar) {
      if (widget.gomulu) {
        return const Center(child: VibeYukleniyor());
      }
      return VibeGradientScaffold(
        appBar: VibeGradientScaffold.seffafBaslik('Moderasyon Paneli'),
        body: const Center(child: VibeYukleniyor()),
      );
    }

    final govde = StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _raporAkisi,
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
            baslik: 'Şikayetler yüklenemedi',
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
        final turSayilari = <String, int>{};
        for (final d in durumaUyan) {
          final t = (d.data()['type'] ?? '').toString();
          turSayilari[t] = (turSayilari[t] ?? 0) + 1;
        }
        final docs = durumaUyan
            .where((d) =>
                _turFiltresi == 'tumu' ||
                (d.data()['type'] ?? '').toString() == _turFiltresi)
            .toList();

        if (docs.isNotEmpty) {
          final imza = docs.map((doc) => doc.id).join('|');
          if (_sonRaporImzasi != imza) {
            _sonRaporImzasi = imza;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _raporBaglaminiYukle(docs);
            });
          }
        }

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
                  ModFiltreSecenegi('action_taken', 'Gizlenen',
                      sayi: durumSayilari['action_taken'] ?? 0),
                  ModFiltreSecenegi('rejected', 'Sorun yok',
                      sayi: durumSayilari['rejected'] ?? 0),
                  ModFiltreSecenegi('reviewed', 'İncelenen',
                      sayi: durumSayilari['reviewed'] ?? 0),
                  ModFiltreSecenegi('tumu', 'Tümü', sayi: tumu.length),
                ],
              ),
              ModFiltreSatiri(
                baslik: 'Tür',
                secili: _turFiltresi,
                sec: (v) => setState(() => _turFiltresi = v),
                secenekler: [
                  const ModFiltreSecenegi('tumu', 'Hepsi'),
                  for (final t in _turEtiketleri.keys)
                    ModFiltreSecenegi(
                      t,
                      _turEtiketleri[t]!,
                      sayi: turSayilari[t] ?? 0,
                      ikon: _turIkonlari[t],
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Divider(height: 1, color: vibe.cardBorder),
              Expanded(
                child: docs.isEmpty
                    ? ModBosDurum(
                        ikon: _durumFiltresi == 'pending'
                            ? Icons.verified_outlined
                            : Icons.inbox_outlined,
                        baslik: _durumFiltresi == 'pending'
                            ? 'Bekleyen şikayet yok'
                            : 'Bu filtrede şikayet yok',
                        aciklama: _durumFiltresi == 'pending'
                            ? 'Yeni bir şikayet gelince burada görünecek.'
                            : 'Başka bir durum veya tür seçebilirsin.',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                        itemCount: docs.length,
                        itemBuilder: (context, index) =>
                            _raporKarti(docs[index]),
                      ),
              ),
            ],
          ),
        );
      },
    );

    if (widget.gomulu) return govde;

    return VibeGradientScaffold(
      appBar: VibeGradientScaffold.seffafBaslik('Moderasyon Paneli'),
      body: govde,
    );
  }

  Widget _raporKarti(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final theme = Theme.of(context);
    final vibe = context.vibe;
    final data = doc.data();
    final type = (data['type'] ?? '').toString();
    final status = _durumOku(doc);
    final reason = (data['reason'] ?? '').toString().trim();
    final details = (data['details'] ?? '').toString().trim();
    final targetUid = (data['targetUid'] ?? '').toString();
    final reporterUid = (data['reporterUid'] ?? '').toString();
    final icerik = _icerikOnbellegi[doc.id];
    final gizli = _icerikGizliMi(doc.id);
    final hesap = type == 'user';
    final gizleEtiketi = hesap ? 'Hesabı gizle' : 'İçeriği gizle';

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
                  _turIkonlari[type] ?? Icons.flag_outlined,
                  size: 18,
                  color: theme.colorScheme.onSurface,
                ),
                const SizedBox(width: 6),
                Text(
                  '${_turMetni(type)} şikayeti',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(width: 8),
                ModRozet(
                  metin: _durumMetni(status),
                  renk: _durumRengi(status),
                  ikon: _durumIkonu(status),
                ),
                const Spacer(),
                Text(
                  tarihSaatYaz(data['createdAt']),
                  style: TextStyle(color: vibe.faintText, fontSize: 11.5),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'Sebep: ',
                    style: TextStyle(color: vibe.mutedText),
                  ),
                  TextSpan(
                    text: reason.isEmpty ? 'Belirtilmemiş' : reason,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (details.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '“$details”',
                style: TextStyle(
                  color: vibe.mutedText,
                  fontStyle: FontStyle.italic,
                  height: 1.35,
                ),
              ),
            ],
            const SizedBox(height: 10),
            if (icerik == null)
              const ModAlintiKutusu(
                baslik: 'ŞİKAYET EDİLEN İÇERİK',
                metin: 'Yükleniyor…',
              )
            else if (icerik.silinmis)
              ModAlintiKutusu(
                baslik: 'ŞİKAYET EDİLEN İÇERİK',
                metin: hesap
                    ? 'Bu hesap artık yok.'
                    : 'Bu içerik silinmiş.',
              )
            else
              ModAlintiKutusu(
                baslik: 'ŞİKAYET EDİLEN İÇERİK',
                metin: icerik.metin,
                maxLines: 8,
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (gizli == true)
                  const ModRozet(
                    metin: 'Şu an gizli',
                    renk: Colors.redAccent,
                    ikon: Icons.visibility_off_outlined,
                  )
                else if (gizli == false)
                  const ModRozet(
                    metin: 'Yayında',
                    renk: Colors.green,
                    ikon: Icons.visibility_outlined,
                  ),
                if ((icerik?.sikayetSayisi ?? 0) > 1)
                  ModRozet(
                    metin: 'Toplam ${icerik!.sikayetSayisi} şikayet',
                    renk: Colors.deepPurple,
                    ikon: Icons.flag_outlined,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            ModBilgiSatiri(
              ikon: Icons.person_outline,
              etiket: 'Şikayet eden',
              deger: _kullaniciEtiketi(reporterUid),
              onTap: reporterUid.isEmpty
                  ? null
                  : () => profiliAc(context, reporterUid),
            ),
            if (targetUid.isNotEmpty)
              ModBilgiSatiri(
                ikon: Icons.report_outlined,
                etiket: 'Şikayet edilen',
                deger: _kullaniciEtiketi(targetUid),
                onTap: () => profiliAc(context, targetUid),
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
                      if (gizli == true) ...[
                        if (status != 'action_taken')
                          FilledButton.icon(
                            style: _gizleStili,
                            onPressed: () => _gizle(doc),
                            icon: const Icon(
                              Icons.visibility_off_outlined,
                              size: 18,
                            ),
                            label: const Text('Gizli kalsın'),
                          ),
                        OutlinedButton.icon(
                          onPressed: () => _yayinaAl(doc),
                          icon: const Icon(Icons.visibility_outlined, size: 18),
                          label: Text(
                            status == 'action_taken'
                                ? 'Gizlemeyi kaldır'
                                : 'Sorun yok, yayına al',
                          ),
                        ),
                      ] else ...[
                        if (icerik?.silinmis != true &&
                            status != 'action_taken')
                          FilledButton.icon(
                            style: _gizleStili,
                            onPressed: () => _gizle(doc),
                            icon: const Icon(
                              Icons.visibility_off_outlined,
                              size: 18,
                            ),
                            label: Text(gizleEtiketi),
                          ),
                        if (status != 'rejected')
                          OutlinedButton.icon(
                            onPressed: () => _durumYap(
                              doc,
                              'rejected',
                              'Şikayet kapatıldı: sorun yok.',
                            ),
                            icon: const Icon(Icons.check, size: 18),
                            label: const Text('Sorun yok'),
                          ),
                      ],
                      if (icerik?.silinmis != true)
                        TextButton.icon(
                          onPressed: () => _icerigiAc(data),
                          icon: const Icon(Icons.open_in_new, size: 18),
                          label: Text(hesap ? 'Profili aç' : 'Gönderiyi aç'),
                        ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Diğer işlemler',
                  icon: Icon(Icons.more_vert, color: vibe.mutedText),
                  onSelected: (secim) {
                    switch (secim) {
                      case 'reviewed':
                        _durumYap(doc, 'reviewed', 'İncelendi olarak işaretlendi.');
                      case 'pending':
                        _durumYap(doc, 'pending', 'Şikayet yeniden bekleyenlere alındı.');
                    }
                  },
                  itemBuilder: (_) => [
                    if (status != 'reviewed')
                      const PopupMenuItem(
                        value: 'reviewed',
                        child: Text('İncelendi olarak işaretle'),
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
