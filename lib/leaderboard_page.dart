// Maskot seviyesi liderlik tablosu.
import 'dart:async';

import 'package:myvibel/tek_sefer_navigasyon.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:myvibel/app_theme.dart';
import 'package:myvibel/widgets/vibe_yukleniyor.dart';
import 'package:myvibel/error_messages.dart';
import 'package:myvibel/sosyal_servis.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:myvibel/haftalik_gorev_servis.dart';
import 'package:myvibel/widgets/isim_yan_rozet.dart';
import 'package:myvibel/widgets/vibe_avatar.dart';
import 'package:myvibel/widgets/vibe_gradient_scaffold.dart';
import 'package:myvibel/widgets/vil_rozeti.dart';
import 'package:myvibel/vibe_snackbar.dart';

// Liderlik sıralaması sayfası
class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  late Future<LiderlikTabloSonucu> _tabloFuture;

  @override
  void initState() {
    super.initState();
    _tabloFuture = SosyalServis.liderlikTablosuGetir();
    unawaited(HaftaRozetServis.instance.yenile());
  }

  int _intDeger(dynamic value, int varsayilan) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return varsayilan;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vibe = context.vibe;
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? "";

    return VibeGradientScaffold(
      appBar: VibeGradientScaffold.seffafBaslik('Liderlik Tablosu'),
      body: ValueListenableBuilder<bool>(
        valueListenable: HaftaRozetServis.instance.acik,
        builder: (context, gorevAcik, seviyeSayfasi) {
          if (!gorevAcik) return seviyeSayfasi!;
          return DefaultTabController(
            length: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TabBar(
                  indicatorColor: theme.colorScheme.primary,
                  labelColor: theme.colorScheme.onSurface,
                  unselectedLabelColor: vibe.mutedText,
                  tabs: const [
                    Tab(text: 'Seviye'),
                    Tab(text: 'Haftalık Görev'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      seviyeSayfasi!,
                      _HaftaSirasi(myUid: myUid),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
        child: FutureBuilder<LiderlikTabloSonucu>(
        future: _tabloFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
              child: VibeYukleniyor(renk: VibeAppTheme.accent),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  internetAwareErrorMessage(
                    error: snapshot.error ?? "Tablo yüklenemedi.",
                    fallback: "Tablo yüklenemedi.",
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: vibe.subtleText),
                ),
              ),
            );
          }

          final sonuc = snapshot.data;
          final liste = sonuc?.liste ?? [];
          if (liste.isEmpty) {
            return Center(
              child: Text(
                "Henüz sıralama oluşmadı.",
                style: TextStyle(color: vibe.mutedText),
              ),
            );
          }

          final benimSira = sonuc?.benimSira;
          final altSiraGoster = benimSira != null && !sonuc!.ilkYuzde;

          return Column(
            children: [
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  itemCount: liste.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    return _siraKarti(
                      context: context,
                      k: liste[index],
                      sira: index + 1,
                      myUid: myUid,
                    );
                  },
                ),
              ),
              if (altSiraGoster)
                SafeArea(
                  top: false,
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: theme.colorScheme.primary,
                        width: 1.5,
                      ),
                      color: vibe.cardColor,
                    ),
                    child: Text(
                      'Sen $benimSira. sıradasın',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
        ),
      ),
    );
  }

  Widget _siraKarti({
    required BuildContext context,
    required Map<String, dynamic> k,
    required int sira,
    required String myUid,
  }) {
    final theme = Theme.of(context);
    final vibe = context.vibe;
    final uid = k["uid"] as String;
    final adSoyad = k["adSoyad"] as String;
    final kullaniciAdi = k["kullaniciAdi"] as String;
    final mascotSeviye = _intDeger(k["robotSeviye"], 1);
    final robotIsim = (k["robotIsim"] ?? "Vibel").toString();
    final benim = uid == myUid;

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: benim
            ? Border.all(color: theme.colorScheme.primary, width: 1.5)
            : Border.all(color: vibe.cardBorder),
        color: vibe.cardColor,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        onTap: () {
          if (uid.isEmpty) return;
          profiliAc(context, uid);
        },
        leading: _siraRozeti(
          context: context,
          sira: sira,
        ),
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            vibeAvatar(
              userId: uid,
              radius: 16,
              photoUrl: (k["photoUrl"] ?? "").toString(),
              avatarKey: (k["avatarKey"] ?? "").toString(),
              fallbackText: kullaniciAdi,
              emojiSize: 14,
              liderSira: sira,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    adSoyad,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    "@$kullaniciAdi",
                    style: TextStyle(color: vibe.mutedText, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'Seviye $mascotSeviye',
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              robotIsim,
              style: TextStyle(
                color: vibe.mutedText,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _siraRozeti({
    required BuildContext context,
    required int sira,
  }) {
    final theme = Theme.of(context);
    final vibe = context.vibe;

    final decoration = switch (sira) {
      1 => const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [Color(0xFFFFE08A), Color(0xFFFFB300)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      2 => const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [Color(0xFFF1F5F9), Color(0xFF94A3B8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      3 => const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [Color(0xFFF5CBA7), Color(0xFFB87333)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      _ => BoxDecoration(
          shape: BoxShape.circle,
          color: vibe.inputFill,
          border: Border.all(color: vibe.cardBorder),
        ),
    };

    final textColor =
        sira <= 3 ? const Color(0xFF2A1600) : theme.colorScheme.onSurface;

    return Container(
      width: 32,
      height: 32,
      decoration: decoration,
      alignment: Alignment.center,
      child: Text(
        '$sira',
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w800,
          fontSize: sira >= 100 ? 10 : 12,
        ),
      ),
    );
  }
}

class _HaftaBolum {
  _HaftaBolum({
    required this.altSinir,
    this.ustSinir,
    required this.ilkAdet,
    required this.devamEdebilir,
  });

  final int altSinir;
  final int? ustSinir;
  final int ilkAdet;
  final bool devamEdebilir;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs = [];
  bool yukleniyor = false;
  bool dahaVar = false;
  int? toplam;
}

class _HaftaSirasi extends StatefulWidget {
  const _HaftaSirasi({required this.myUid});

  final String myUid;

  @override
  State<_HaftaSirasi> createState() => _HaftaSirasiState();
}

class _HaftaSirasiState extends State<_HaftaSirasi> {
  static const _devamAdedi = 10;

  final String _hafta = HaftalikGorevServis.haftaKimligi();
  late List<_HaftaBolum> _bolumler;
  bool _ilkYukleme = true;
  Object? _hata;

  _HaftaBolum get _altin => _bolumler[0];
  _HaftaBolum get _gumus => _bolumler[1];
  _HaftaBolum get _bronz => _bolumler[2];
  _HaftaBolum get _katilim => _bolumler[3];

  @override
  void initState() {
    super.initState();
    unawaited(_hepsiniYukle());
  }

  List<_HaftaBolum> _yeniBolumler() => [
        _HaftaBolum(
          altSinir: HaftalikGorevServis.altinPuan,
          ilkAdet: 3,
          devamEdebilir: true,
        ),
        _HaftaBolum(
          altSinir: HaftalikGorevServis.gumusPuan,
          ustSinir: HaftalikGorevServis.altinPuan,
          ilkAdet: 3,
          devamEdebilir: true,
        ),
        _HaftaBolum(
          altSinir: HaftalikGorevServis.bronzPuan,
          ustSinir: HaftalikGorevServis.gumusPuan,
          ilkAdet: 3,
          devamEdebilir: true,
        ),
        _HaftaBolum(
          altSinir: 1,
          ustSinir: HaftalikGorevServis.bronzPuan,
          ilkAdet: 10,
          devamEdebilir: false,
        ),
      ];

  Query<Map<String, dynamic>> _sorgu(_HaftaBolum b) {
    var q = FirebaseFirestore.instance
        .collection('users')
        .where('haftalikGorev.hafta', isEqualTo: _hafta)
        .where('haftalikGorev.puan', isGreaterThanOrEqualTo: b.altSinir);
    if (b.ustSinir != null) {
      q = q.where('haftalikGorev.puan', isLessThan: b.ustSinir);
    }
    return q.orderBy('haftalikGorev.puan', descending: true);
  }

  Future<void> _sayfaYukle(_HaftaBolum b, int adet) async {
    var q = _sorgu(b);
    if (b.docs.isNotEmpty) q = q.startAfterDocument(b.docs.last);
    final snap = await q.limit(adet + 1).get();
    final gelen = snap.docs;
    b.dahaVar = gelen.length > adet;
    b.docs.addAll(gelen.take(adet));
  }

  Future<void> _toplamYukle(_HaftaBolum b) async {
    try {
      final s = await _sorgu(b).count().get();
      b.toplam = s.count;
    } catch (_) {}
  }

  Future<void> _hepsiniYukle() async {
    final yeni = _yeniBolumler();
    try {
      await Future.wait([
        for (final b in yeni) _sayfaYukle(b, b.ilkAdet),
        for (final b in yeni) _toplamYukle(b),
      ]);
      if (!mounted) return;
      setState(() {
        _bolumler = yeni;
        _ilkYukleme = false;
        _hata = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (_ilkYukleme) _bolumler = yeni;
        _ilkYukleme = false;
        _hata = e;
      });
    }
  }

  Future<void> _devam(_HaftaBolum b) async {
    if (b.yukleniyor) return;
    setState(() => b.yukleniyor = true);
    try {
      await _sayfaYukle(b, _devamAdedi);
    } catch (e) {
      if (mounted) {
        vibeSnackbarGoster(
          context,
          internetAwareErrorMessage(error: e, fallback: 'Liste yüklenemedi.'),
        );
      }
    } finally {
      if (mounted) setState(() => b.yukleniyor = false);
    }
  }

  static int _puan(Map<String, dynamic> data) {
    final gorev = data['haftalikGorev'];
    return gorev is Map && gorev['puan'] is num
        ? (gorev['puan'] as num).toInt()
        : 0;
  }

  int _siraBaslangici(int bolumIndeksi) {
    var toplam = 0;
    for (var i = 0; i < bolumIndeksi; i++) {
      final b = _bolumler[i];
      toplam += b.toplam ?? b.docs.length;
    }
    return toplam;
  }

  @override
  Widget build(BuildContext context) {
    final vibe = context.vibe;
    if (_ilkYukleme) return const Center(child: VibeYukleniyor());

    final hepsiBos = _bolumler.every((b) => b.docs.isEmpty);
    if (hepsiBos) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _hata != null
                ? internetAwareErrorMessage(
                    error: _hata!,
                    fallback: 'Liste yüklenemedi.',
                  )
                : 'Bu hafta henüz görev yapan yok.',
            textAlign: TextAlign.center,
            style: TextStyle(color: vibe.mutedText),
          ),
        ),
      );
    }

    final benimListede =
        _bolumler.any((b) => b.docs.any((d) => d.id == widget.myUid));

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: _hepsiniYukle,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [
                const _BolumBasligi(metin: 'Hak kazananlar'),
                const _OdulBasligi(
                  metin: 'Altın',
                  rozet: 'altin',
                  vil: HaftalikGorevServis.altinVil,
                  esik: HaftalikGorevServis.altinPuan,
                ),
                ..._bolumSatirlari(_altin, 0),
                const _OdulBasligi(
                  metin: 'Gümüş',
                  rozet: 'gumus',
                  vil: HaftalikGorevServis.gumusVil,
                  esik: HaftalikGorevServis.gumusPuan,
                ),
                ..._bolumSatirlari(_gumus, 1),
                const _OdulBasligi(
                  metin: 'Bronz',
                  rozet: 'bronz',
                  vil: HaftalikGorevServis.bronzVil,
                  esik: HaftalikGorevServis.bronzPuan,
                ),
                ..._bolumSatirlari(_bronz, 2),
                const SizedBox(height: 12),
                const _BolumBasligi(
                  metin: 'Hak kazanamayanlar',
                  vil: HaftalikGorevServis.katilimVil,
                ),
                ..._bolumSatirlari(_katilim, 3),
              ],
            ),
          ),
        ),
        if (!benimListede)
          _KendiHaftaSirasi(myUid: widget.myUid, hafta: _hafta),
      ],
    );
  }

  List<Widget> _bolumSatirlari(_HaftaBolum b, int bolumIndeksi) {
    if (b.docs.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
          child: Text(
            'Henüz kimse yok.',
            style: TextStyle(color: context.vibe.faintText, fontSize: 13),
          ),
        ),
      ];
    }
    final baslangic = _siraBaslangici(bolumIndeksi);
    final kalan =
        b.toplam == null ? null : (b.toplam! - b.docs.length).clamp(0, 1 << 30);
    return [
      for (var i = 0; i < b.docs.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _HaftaSatiri(
            sira: baslangic + i + 1,
            uid: b.docs[i].id,
            kullaniciAdi:
                (b.docs[i].data()['kullaniciAdi'] ?? 'kullanici').toString(),
            puan: _puan(b.docs[i].data()),
            benim: b.docs[i].id == widget.myUid,
          ),
        ),
      if (b.devamEdebilir && b.dahaVar)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Center(
            child: TextButton.icon(
              onPressed: b.yukleniyor ? null : () => _devam(b),
              icon: b.yukleniyor
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.expand_more),
              label: Text(
                kalan != null && kalan > 0
                    ? 'Devam ($kalan kişi daha)'
                    : 'Devam',
              ),
            ),
          ),
        ),
    ];
  }
}

class _BolumBasligi extends StatelessWidget {
  const _BolumBasligi({required this.metin, this.vil});

  final String metin;
  final int? vil;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 8, 2, 6),
      child: Row(
        children: [
          Text(
            metin,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (vil != null) ...[
            const SizedBox(width: 10),
            VilRozeti(miktar: vil!),
          ],
        ],
      ),
    );
  }
}

class _OdulBasligi extends StatelessWidget {
  const _OdulBasligi({
    required this.metin,
    required this.rozet,
    required this.vil,
    required this.esik,
  });

  final String metin;
  final String rozet;
  final int vil;
  final int esik;

  @override
  Widget build(BuildContext context) {
    final vibe = context.vibe;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 10, 2, 8),
      child: Row(
        children: [
          Flexible(
            child: Text(
              metin,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          HaftaRozetGorsel(tur: rozet, boy: 24),
          const SizedBox(width: 6),
          VilRozeti(miktar: vil),
          const Spacer(),
          Text(
            '$esik+ puan',
            style: TextStyle(color: vibe.faintText, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _HaftaSatiri extends StatelessWidget {
  const _HaftaSatiri({
    required this.sira,
    required this.uid,
    required this.kullaniciAdi,
    required this.puan,
    required this.benim,
  });

  final int sira;
  final String uid;
  final String kullaniciAdi;
  final int puan;
  final bool benim;

  @override
  Widget build(BuildContext context) {
    final vibe = context.vibe;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: uid.isEmpty ? null : () => profiliAc(context, uid),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: vibe.cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: benim
                  ? Theme.of(context).colorScheme.primary
                  : vibe.cardBorder,
              width: benim ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 32,
                child: Text(
                  '$sira',
                  style: TextStyle(
                    color: onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        '@$kullaniciAdi',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IsimYanRozet(uid: uid),
                  ],
                ),
              ),
              Text(
                '$puan puan',
                style: TextStyle(
                  color: onSurface,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KendiHaftaSirasi extends StatelessWidget {
  const _KendiHaftaSirasi({required this.myUid, required this.hafta});

  final String myUid;
  final String hafta;

  @override
  Widget build(BuildContext context) {
    if (myUid.isEmpty) return const SizedBox.shrink();
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('users').doc(myUid).get(),
      builder: (context, snap) {
        final gorev = snap.data?.data()?['haftalikGorev'];
        if (gorev is! Map) return const SizedBox.shrink();
        if (gorev['hafta']?.toString() != hafta) return const SizedBox.shrink();
        final puan = gorev['puan'] is num ? (gorev['puan'] as num).toInt() : 0;
        if (puan <= 0) return const SizedBox.shrink();
        return FutureBuilder<AggregateQuerySnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .where('haftalikGorev.hafta', isEqualTo: hafta)
              .where('haftalikGorev.puan', isGreaterThan: puan)
              .orderBy('haftalikGorev.puan', descending: true)
              .count()
              .get(),
          builder: (context, countSnap) {
            final sira = (countSnap.data?.count ?? 0) + 1;
            return SafeArea(
              top: false,
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 1.5,
                  ),
                  color: context.vibe.cardColor,
                ),
                child: Text(
                  'Sen $sira. sıradasın · $puan puan',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
