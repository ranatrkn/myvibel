// Takipçi ve takip edilen listesi sayfası.
import 'package:myvibel/tek_sefer_navigasyon.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:myvibel/app_theme.dart';
import 'package:myvibel/sosyal_servis.dart';
import 'package:myvibel/vibe_snackbar.dart';
import 'package:myvibel/maskot_servis.dart';
import 'package:myvibel/widgets/vil_harcama_uyarisi.dart';
import 'package:myvibel/widgets/vibe_avatar.dart';
import 'package:myvibel/widgets/vibe_yukleniyor.dart';
import 'package:myvibel/widgets/vibe_gradient_scaffold.dart';

// Takipçi/takip edilen sekmeli liste
class FollowListPage extends StatefulWidget {
  const FollowListPage({
    super.key,
    required this.userId,
    this.initialTab = 0,
    this.kullaniciAdi,
  });

  final String userId; // Profil sahibi uid
  final int initialTab; // Başlangıç sekmesi (0: takipçi)
  final String? kullaniciAdi; // AppBar başlığı için

  @override
  State<FollowListPage> createState() => _FollowListPageState();
}

class _FollowListPageState extends State<FollowListPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController; // Sekme kontrolü
  Set<String> _engelIdleri = {};
  final Map<String, TakipDurumu> _takipDurumlari = {};
  bool? _listeGorulebilir; // Gizli hesap kontrolü

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 1),
    );
    _engelleriYukle();
    _gorusIzniniYukle();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Engel listesini yükler
  Future<void> _engelleriYukle() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final engelledigim = await SosyalServis.engellenenKullanicilariGetir(uid);
    final beniEngelleyen =
        await SosyalServis.beniEngelleyenKullanicilariGetir(uid);
    if (!mounted) return;
    setState(() {
      _engelIdleri = {...engelledigim, ...beniEngelleyen};
    });
  }

  // Gizli hesap için liste görünürlüğünü kontrol eder
  Future<void> _gorusIzniniYukle() async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) {
      if (!mounted) return;
      setState(() => _listeGorulebilir = false);
      return;
    }
    final gorulebilir = await SosyalServis.profilGonderileriGorulebilir(
      izleyiciUid: currentUid,
      profilUid: widget.userId,
    );
    if (!mounted) return;
    setState(() => _listeGorulebilir = gorulebilir);
  }

  Future<void> _takipDurumunuYukle(String hedefUid) async {
    if (_takipDurumlari.containsKey(hedefUid)) return;
    final durum = await SosyalServis.takipDurumuGetir(hedefUid);
    if (!mounted) return;
    setState(() {
      _takipDurumlari[hedefUid] = durum;
    });
  }

  Future<void> _takipButonunaBas(String hedefUid) async {
    if (_engelIdleri.contains(hedefUid)) return;
    final mevcut = _takipDurumlari[hedefUid] ?? TakipDurumu.takipEtmiyor;
    if (mevcut == TakipDurumu.takipEdiliyor) {
      final vilHarcanacak =
          await TakipServis.takipCikisVilHarcanacak(hedefUid);
      if (vilHarcanacak) {
        if (!mounted) return;
        final devam = await VilHarcamaUyarisi.onayla(
          context: context,
          islem: VilHarcamaUyarisi.takipCik,
          maliyet: MascotServis.vilTakipGeriAlMaliyeti,
        );
        if (!devam || !mounted) return;
      }
    }
    final mesaj = await SosyalServis.takipButonunaBas(hedefUid, mevcut);
    final yeniDurum = await SosyalServis.takipDurumuGetir(hedefUid);
    if (!mounted) return;
    setState(() {
      _takipDurumlari[hedefUid] = yeniDurum;
    });
    if (mesaj.isNotEmpty) {
      vibeSnackbarGoster(context, mesaj, tip: VibeMesajTipi.bilgi);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vibe = context.vibe;
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? "";
    final baslik = widget.kullaniciAdi != null && widget.kullaniciAdi!.isNotEmpty
        ? "@${widget.kullaniciAdi}"
        : "Bağlantılar";

    return VibeGradientScaffold(
      appBar: VibeGradientScaffold.seffafBaslik(baslik),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TabBar(
            controller: _tabController,
            indicatorColor: theme.colorScheme.primary,
            labelColor: theme.colorScheme.onSurface,
            unselectedLabelColor: vibe.mutedText,
            tabs: const [
              Tab(text: "Takipçi"),
              Tab(text: "Takip Edilen"),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _listeGorulebilir == null
                  ? const [
                      Center(child: VibeYukleniyor()),
                      Center(child: VibeYukleniyor()),
                    ]
                  : _listeGorulebilir == false
                      ? const [
                          _GizliHesapTakipBilgisi(),
                          _GizliHesapTakipBilgisi(),
                        ]
                      : [
                          _TakipListesi(
                            userId: widget.userId,
                            koleksiyon: "followers",
                            currentUid: currentUid,
                            engelIdleri: _engelIdleri,
                            takipDurumlari: _takipDurumlari,
                            onTakipDurumuYukle: _takipDurumunuYukle,
                            onTakipButonunaBas: _takipButonunaBas,
                          ),
                          _TakipListesi(
                            userId: widget.userId,
                            koleksiyon: "following",
                            currentUid: currentUid,
                            engelIdleri: _engelIdleri,
                            takipDurumlari: _takipDurumlari,
                            onTakipDurumuYukle: _takipDurumunuYukle,
                            onTakipButonunaBas: _takipButonunaBas,
                          ),
                        ],
            ),
          ),
        ],
      ),
    );
  }
}

// Gizli hesapta gösterilen bilgi metni
class _GizliHesapTakipBilgisi extends StatelessWidget {
  const _GizliHesapTakipBilgisi();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text(
          "Bu hesap gizli. Takipçi ve takip edilen listesi görüntülenemiyor.",
          textAlign: TextAlign.center,
          style: TextStyle(color: context.vibe.mutedText),
        ),
      ),
    );
  }
}

// Takipçi veya takip edilen Firestore listesi
class _TakipListesi extends StatelessWidget {
  const _TakipListesi({
    required this.userId,
    required this.koleksiyon,
    required this.currentUid,
    required this.engelIdleri,
    required this.takipDurumlari,
    required this.onTakipDurumuYukle,
    required this.onTakipButonunaBas,
  });

  final String userId;
  final String koleksiyon;
  final String currentUid;
  final Set<String> engelIdleri;
  final Map<String, TakipDurumu> takipDurumlari;
  final Future<void> Function(String hedefUid) onTakipDurumuYukle;
  final Future<void> Function(String hedefUid) onTakipButonunaBas;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vibe = context.vibe;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection("users")
          .doc(userId)
          .collection(koleksiyon)
          .limit(400)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting &&
            !snap.hasData) {
          return Center(
            child: VibeYukleniyor(renk: theme.colorScheme.primary),
          );
        }

        if (snap.hasError) {
          return Center(
            child: Text(
              "Liste yüklenemedi.",
              style: TextStyle(color: vibe.mutedText),
            ),
          );
        }

        final uidler = snap.data?.docs
                .map((d) => d.id)
                .where((id) => !engelIdleri.contains(id))
                .toList() ??
            [];

        if (uidler.isEmpty) {
          return Center(
            child: Text(
              koleksiyon == "followers"
                  ? "Henüz takipçi yok."
                  : "Henüz takip edilen yok.",
              style: TextStyle(color: vibe.mutedText),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
          itemCount: uidler.length,
          itemBuilder: (context, index) {
            final hedefUid = uidler[index];
            return _TakipKullaniciSatiri(
              hedefUid: hedefUid,
              currentUid: currentUid,
              takipDurumu: takipDurumlari[hedefUid],
              onTakipDurumuYukle: onTakipDurumuYukle,
              onTakipButonunaBas: onTakipButonunaBas,
            );
          },
        );
      },
    );
  }
}

// Tek kullanıcı satırı (profil + takip butonu)
class _TakipKullaniciSatiri extends StatefulWidget {
  const _TakipKullaniciSatiri({
    required this.hedefUid,
    required this.currentUid,
    required this.takipDurumu,
    required this.onTakipDurumuYukle,
    required this.onTakipButonunaBas,
  });

  final String hedefUid;
  final String currentUid;
  final TakipDurumu? takipDurumu;
  final Future<void> Function(String hedefUid) onTakipDurumuYukle;
  final Future<void> Function(String hedefUid) onTakipButonunaBas;

  @override
  State<_TakipKullaniciSatiri> createState() => _TakipKullaniciSatiriState();
}

class _TakipKullaniciSatiriState extends State<_TakipKullaniciSatiri> {
  @override
  void initState() {
    super.initState();
    if (widget.hedefUid != widget.currentUid && widget.takipDurumu == null) {
      widget.onTakipDurumuYukle(widget.hedefUid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vibe = context.vibe;
    final kendiHesap = widget.hedefUid == widget.currentUid;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection("users")
          .doc(widget.hedefUid)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData || !snap.data!.exists) {
          return const SizedBox.shrink();
        }

        final data = snap.data!.data() ?? {};
        final adSoyad = (data["adSoyad"] ?? "Vibe Kullanıcısı").toString();
        final kullaniciAdi = (data["kullaniciAdi"] ?? "kullanici").toString();
        final photoUrl = (data["photoUrl"] ?? "").toString();
        final avatarKey = (data["avatarKey"] ?? "").toString();
        final durum = widget.takipDurumu ?? TakipDurumu.takipEtmiyor;
        final takipEdiliyor = durum == TakipDurumu.takipEdiliyor;
        final istekGonderildi = durum == TakipDurumu.istekGonderildi;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: vibe.satirKart(),
          child: ListTile(
            onTap: () {
              profiliAc(context, widget.hedefUid);
            },
            leading: vibeAvatar(
              radius: 22,
              userId: widget.hedefUid,
              photoUrl: photoUrl,
              avatarKey: avatarKey,
              fallbackText: kullaniciAdi,
              emojiSize: 18,
            ),
            title: Text(
              adSoyad,
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              "@$kullaniciAdi",
              style: TextStyle(color: vibe.mutedText, fontSize: 13),
            ),
            trailing: kendiHesap
                ? null
                : TextButton(
                    onPressed: () => widget.onTakipButonunaBas(widget.hedefUid),
                    style: TextButton.styleFrom(
                      backgroundColor: takipEdiliyor || istekGonderildi
                          ? vibe.inputFill
                          : vibe.primaryButton,
                      foregroundColor: takipEdiliyor || istekGonderildi
                          ? vibe.mutedText
                          : Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: Text(
                      SosyalServis.takipButonMetni(durum),
                      style: TextStyle(
                        color: takipEdiliyor || istekGonderildi
                            ? vibe.mutedText
                            : Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
          ),
        );
      },
    );
  }
}
