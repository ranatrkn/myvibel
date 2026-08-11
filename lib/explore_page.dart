// Kullanıcı ve etiket arama/keşfet sayfası.
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:vibe_life/app_theme.dart';
import 'package:vibe_life/error_messages.dart';
import 'package:vibe_life/etiket_navigasyon.dart';
import 'package:vibe_life/puan_animasyon.dart';
import 'package:vibe_life/sosyal_servis.dart';
import 'package:vibe_life/leaderboard_page.dart';
import 'package:vibe_life/user_profile_page.dart';
import 'package:vibe_life/vibe_snackbar.dart';
import 'package:vibe_life/widgets/vibe_avatar.dart';

// Keşfet ve arama ekranı
class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> with WidgetsBindingObserver {
  final TextEditingController _aramaController = TextEditingController(); // Arama kutusu
  Timer? _aramaDebounce; // Yazmayı geciktiren zamanlayıcı

  List<Map<String, dynamic>> _tumKullanicilar = []; // Tüm kullanıcı listesi
  List<Map<String, dynamic>> _onerilenKullanicilar = []; // Önerilenler
  final Map<String, TakipDurumu> _takipDurumlari = {}; // Takip durumları
  final Set<String> _takipDurumuYukleniyor = {}; // Yüklenen takip durumları
  bool _yukleniyor = true;
  String? _hataMesaji;
  Set<String> _engelIdleri = {};
  Set<String> _takipEdilenIdler = {};
  Set<String> _bilinenEtiketler = {}; // Bilinen hashtag'ler
  List<String> _etiketOnerileri = []; // Aktif arama etiket sonuçları
  bool _etiketlerYukleniyor = false;
  bool _etiketAramasiSuruyor = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _verileriYukle();
    _aramaController.addListener(_aramaDegisti);
  }

  // Arama metni değişince debounce ile filtrele
  void _aramaDegisti() {
    _aramaDebounce?.cancel();
    _aramaDebounce = Timer(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      if (_aramaSorgusu.isNotEmpty) {
        _etiketOnerileriniGuncelle();
      } else {
        setState(() => _etiketOnerileri = []);
      }
      setState(() {});
      if (_bilinenEtiketler.isEmpty) {
        _bilinenEtiketleriYenile();
      }
    });
  }

  String get _aramaSorgusu => _aramaController.text.trim(); // Aktif arama metni

  // Etiket önerisine tıklanınca etiket sayfasına git
  void _etiketOnerisineBas(String tag) {
    etiketSayfasinaGit(context, tag);
  }

  void _aramayiTemizle() {
    _aramaController.clear();
    setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _aramaDebounce?.cancel();
    _aramaController.dispose();
    super.dispose();
  }

  // Uygulama ön plana gelince verileri yenile
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _verileriYukle();
    }
  }

  // Kullanıcıları ve önerileri Firestore'dan yükler
  Future<void> _verileriYukle() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _yukleniyor = false;
        _hataMesaji = "Oturum bulunamadı.";
      });
      return;
    }

    setState(() {
      _yukleniyor = true;
      _hataMesaji = null;
    });

    try {
      final firestore = FirebaseFirestore.instance;
      final engelledigim =
          await SosyalServis.engellenenKullanicilariGetir(user.uid);
      final beniEngelleyen =
          await SosyalServis.beniEngelleyenKullanicilariGetir(user.uid);
      final takipEdilenIdler =
          await SosyalServis.takipEdilenIdleriGetir(user.uid);
      _engelIdleri = {...engelledigim, ...beniEngelleyen};
      _takipEdilenIdler = takipEdilenIdler;

      const kullaniciOnYuklemeLimiti = 120;
      final kullanicilarSnapshot = await firestore
          .collection("users")
          .limit(kullaniciOnYuklemeLimiti)
          .get();

      final kullanicilar = kullanicilarSnapshot.docs
          .where((doc) => doc.id != user.uid && !_engelIdleri.contains(doc.id))
          .map((doc) {
            final data = doc.data();
            return {
              "uid": doc.id,
              "adSoyad": data["adSoyad"] ?? "Vibe Kullanıcısı",
              "kullaniciAdi": data["kullaniciAdi"] ?? "kullanici",
              "kullaniciAdiKucuk": data["kullaniciAdiKucuk"] ?? "",
              "photoUrl": data["photoUrl"] ?? "",
              "avatarKey": data["avatarKey"] ?? "",
              "hesapGizli": data["hesapGizli"] == true,
              "aramaSkoru": data["aramaSkoru"] ?? 0,
            };
          })
          .toList();

      final onerilenler = List<Map<String, dynamic>>.from(kullanicilar);
      onerilenler.sort((a, b) {
        final skorA = _intDeger(a["aramaSkoru"], 0);
        final skorB = _intDeger(b["aramaSkoru"], 0);
        final skorKarsilastirma = skorB.compareTo(skorA);
        if (skorKarsilastirma != 0) return skorKarsilastirma;
        final adA = (a["adSoyad"] as String).toLowerCase();
        final adB = (b["adSoyad"] as String).toLowerCase();
        return adA.compareTo(adB);
      });

      if (!mounted) return;

      setState(() {
        _tumKullanicilar = kullanicilar;
        _onerilenKullanicilar = onerilenler.take(10).toList();
        _takipDurumlari.clear();
        _yukleniyor = false;
      });

      for (final k in _onerilenKullanicilar) {
        _takipDurumunuYukle(k["uid"] as String);
      }

      unawaited(_bilinenEtiketleriYenile());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _yukleniyor = false;
        _hataMesaji = internetAwareErrorMessage(
          error: e,
          fallback: "Kullanıcılar yüklenemedi.",
        );
      });
    }
  }

  // Bir kullanıcının takip durumunu getirir
  Future<void> _takipDurumunuYukle(String uid) async {
    if (_takipDurumlari.containsKey(uid) ||
        _takipDurumuYukleniyor.contains(uid)) {
      return;
    }

    _takipDurumuYukleniyor.add(uid);
    final durum = await SosyalServis.takipDurumuGetir(uid);
    if (!mounted) return;
    setState(() {
      _takipDurumlari[uid] = durum;
      _takipDurumuYukleniyor.remove(uid);
    });
  }

  // Profilden dönünce önbelleği atlayıp takip durumunu yeniler
  Future<void> _takipDurumunuZorlaYukle(String uid) async {
    _takipDurumlari.remove(uid);
    _takipDurumuYukleniyor.remove(uid);
    await _takipDurumunuYukle(uid);
  }

  int _intDeger(dynamic value, int varsayilan) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return varsayilan;
  }

  // Türkçe karakterleri arama için normalize eder
  String _normalle(String metin) {
    return metin
        .toLowerCase()
        .replaceAll("ı", "i")
        .replaceAll("İ", "i")
        .replaceAll("ş", "s")
        .replaceAll("ğ", "g")
        .replaceAll("ç", "c")
        .replaceAll("ö", "o")
        .replaceAll("ü", "u");
  }

  // Arama sorgusuna göre filtrelenmiş kullanıcı listesi
  List<Map<String, dynamic>> get _gorunenKullanicilar {
    final sorgu = _aramaSorgusu;
    if (sorgu.isEmpty) {
      return _onerilenKullanicilar;
    }

    final normSorgu = _normalle(
      SosyalServis.aramaMetnindenEtiket(sorgu) ?? sorgu,
    );
    return _tumKullanicilar.where((kullanici) {
      final adSoyad = _normalle((kullanici["adSoyad"] as String));
      final kullaniciAdi = _normalle((kullanici["kullaniciAdi"] as String));
      final kullaniciAdiKucuk =
          _normalle((kullanici["kullaniciAdiKucuk"] as String));

      return adSoyad.contains(normSorgu) ||
          kullaniciAdi.contains(normSorgu) ||
          kullaniciAdiKucuk.contains(normSorgu);
    }).toList()
      ..sort((a, b) {
        final skorA = _intDeger(a["aramaSkoru"], 0);
        final skorB = _intDeger(b["aramaSkoru"], 0);
        final skorKarsilastirma = skorB.compareTo(skorA);
        if (skorKarsilastirma != 0) return skorKarsilastirma;
        final adA = (a["adSoyad"] as String).toLowerCase();
        final adB = (b["adSoyad"] as String).toLowerCase();
        return adA.compareTo(adB);
      });
  }

  // Arama metnine uygun etiket önerileri (Firestore ile güncellenir)
  Future<void> _etiketOnerileriniGuncelle() async {
    final user = FirebaseAuth.instance.currentUser;
    final sorgu = _aramaSorgusu;
    if (user == null || sorgu.isEmpty) {
      if (mounted) setState(() => _etiketOnerileri = []);
      return;
    }

    final hizli = SosyalServis.etiketOnerileri(_bilinenEtiketler, sorgu);
    if (mounted) {
      setState(() {
        _etiketOnerileri = hizli;
        _etiketAramasiSuruyor = true;
      });
    }

    final zengin = await SosyalServis.etiketleriAra(
      sorgu: sorgu,
      izleyiciUid: user.uid,
      takipEdilenIdler: _takipEdilenIdler,
      engelIdleri: _engelIdleri,
      bilinenEtiketler: _bilinenEtiketler,
    );

    if (!mounted || _aramaSorgusu != sorgu) return;
    setState(() {
      _etiketOnerileri = zengin;
      _etiketAramasiSuruyor = false;
    });
  }

  bool get _aramaYapiliyor => _aramaSorgusu.isNotEmpty; // Aktif arama var mı

  void _mesajGoster(String mesaj, {VibeMesajTipi tip = VibeMesajTipi.hata}) {
    vibeSnackbarGoster(context, mesaj, tip: tip);
  }

  // Kullanıcı profiline git; dönüşte takip durumunu yenile
  Future<void> _kullaniciProfilineGit(String userId) async {
    if (userId.isEmpty) return;
    if (_engelIdleri.contains(userId)) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserProfilePage(userId: userId),
      ),
    );
    if (!mounted) return;

    await _takipDurumunuZorlaYukle(userId);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final takipEdilen =
        await SosyalServis.takipEdilenIdleriGetir(user.uid);
    if (!mounted) return;
    setState(() {
      _takipEdilenIdler = takipEdilen;
    });
  }

  // Takip/istek butonu işlemi
  Future<void> _takipButonunaBas(String hedefUid) async {
    if (_engelIdleri.contains(hedefUid)) {
      _mesajGoster("Bu kullanıcı ile etkileşim kuramazsın.", tip: VibeMesajTipi.uyari);
      return;
    }
    var durum =
        _takipDurumlari[hedefUid] ?? TakipDurumu.takipEtmiyor;

    final mesaj = await SosyalServis.takipButonunaBas(hedefUid, durum);
    final yeniDurum = await SosyalServis.takipDurumuGetir(hedefUid);

    if (!mounted) return;

    setState(() {
      _takipDurumlari[hedefUid] = yeniDurum;
      if (yeniDurum == TakipDurumu.takipEdiliyor) {
        _takipEdilenIdler.add(hedefUid);
      } else {
        _takipEdilenIdler.remove(hedefUid);
      }
    });

    if (yeniDurum == TakipDurumu.takipEdiliyor ||
        yeniDurum == TakipDurumu.takipEtmiyor) {
      _bilinenEtiketleriYenile();
    }

    if (mesaj.contains("+5")) {
      puanAnimasyonuGoster(context, 5);
    } else if (mesaj.isNotEmpty && !mesaj.contains("zaten")) {
      _mesajGoster(mesaj, tip: VibeMesajTipi.basari);
    }
  }

  // Bilinen etiket listesini günceller
  Future<void> _bilinenEtiketleriYenile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _etiketlerYukleniyor) return;
    _etiketlerYukleniyor = true;

    try {
      final etiketler = await SosyalServis.bilinenEtiketleriGetir(
        izleyiciUid: user.uid,
        takipEdilenIdler: _takipEdilenIdler,
        engelIdleri: _engelIdleri,
      );
      if (!mounted) return;
      setState(() {
        _bilinenEtiketler = etiketler;
      });
      if (_aramaSorgusu.isNotEmpty) {
        unawaited(_etiketOnerileriniGuncelle());
      }
    } catch (_) {
      // Sessiz gec: etiket onerisi yuklenemese de arama calismaya devam eder.
    } finally {
      _etiketlerYukleniyor = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final gorunenKullanicilar = _gorunenKullanicilar;
    final etiketOnerileri = _etiketOnerileri;
    final theme = Theme.of(context);
    final vibe = context.vibe;

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _aramaController,
              style: TextStyle(color: theme.colorScheme.onSurface),
              cursorColor: VibeAppTheme.accent,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: "Kullanıcı veya etiket ara",
                hintStyle: TextStyle(color: vibe.mutedText),
                filled: true,
                fillColor: vibe.inputFill,
                prefixIcon: Icon(Icons.search, color: vibe.mutedText),
                suffixIcon: _aramaController.text.isNotEmpty
                    ? IconButton(
                        onPressed: _aramayiTemizle,
                        icon: Icon(Icons.close, color: vibe.mutedText),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide(color: vibe.cardBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide(color: vibe.cardBorder),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _aramaYapiliyor ? "Arama Sonuçları" : "Önerilen Kullanıcılar",
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (!_aramaYapiliyor)
                  TextButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LeaderboardPage(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.emoji_events_outlined, size: 18),
                    label: const Text("Liderlik"),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _birlesikAramaListesi(
              theme: theme,
              vibe: vibe,
              gorunenKullanicilar: gorunenKullanicilar,
              etiketOnerileri: etiketOnerileri,
            ),
          ),
        ],
      ),
    );
  }

  // Kullanıcı ve etiket sonuçlarını birleşik listeler
  Widget _birlesikAramaListesi({
    required ThemeData theme,
    required VibeThemeExtension vibe,
    required List<Map<String, dynamic>> gorunenKullanicilar,
    required List<String> etiketOnerileri,
  }) {
    if (_yukleniyor) {
      return Center(
        child: CircularProgressIndicator(color: theme.colorScheme.primary),
      );
    }

    if (_hataMesaji != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _hataMesaji!,
            textAlign: TextAlign.center,
            style: TextStyle(color: vibe.subtleText),
          ),
        ),
      );
    }

    final hicSonucYok = !_aramaYapiliyor
        ? gorunenKullanicilar.isEmpty
        : etiketOnerileri.isEmpty && gorunenKullanicilar.isEmpty;

    if (hicSonucYok) {
      return Center(
        child: Text(
          _aramaYapiliyor
              ? "Eşleşen etiket veya kullanıcı bulunamadı."
              : "Gösterilecek kullanıcı yok.",
          style: TextStyle(color: vibe.mutedText),
        ),
      );
    }

    return RefreshIndicator(
      color: VibeAppTheme.accent,
      backgroundColor: theme.scaffoldBackgroundColor,
      onRefresh: _verileriYukle,
      child: ListView(
        padding: const EdgeInsets.only(top: 4, bottom: 24),
        children: [
          if (_aramaYapiliyor && etiketOnerileri.isNotEmpty) ...[
            _bolumBasligi(theme, vibe, "Etiketler"),
            ...etiketOnerileri.map(
              (tag) => _EtiketOneriSatiri(
                tag: tag,
                onTap: () => _etiketOnerisineBas(tag),
              ),
            ),
          ] else if (_aramaYapiliyor && _etiketAramasiSuruyor) ...[
            _bolumBasligi(theme, vibe, "Etiketler"),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          ],
          if (gorunenKullanicilar.isNotEmpty) ...[
            if (_aramaYapiliyor)
              _bolumBasligi(theme, vibe, "Kullanıcılar"),
            ...gorunenKullanicilar.map((kullanici) {
              final uid = kullanici["uid"] as String;
              if (!_takipDurumlari.containsKey(uid)) {
                _takipDurumunuYukle(uid);
              }
              final durum =
                  _takipDurumlari[uid] ?? TakipDurumu.takipEtmiyor;
              final durumYukleniyor = _takipDurumuYukleniyor.contains(uid);
              return _KullaniciSatiri(
                adSoyad: kullanici["adSoyad"] as String,
                kullaniciAdi: kullanici["kullaniciAdi"] as String,
                photoUrl: kullanici["photoUrl"] as String,
                avatarKey: (kullanici["avatarKey"] ?? "").toString(),
                takipDurumu: durum,
                durumYukleniyor: durumYukleniyor,
                onProfileTap: () => _kullaniciProfilineGit(uid),
                onFollowTap: () => _takipButonunaBas(uid),
              );
            }),
          ],
        ],
      ),
    );
  }

  // Bölüm başlık widget'ı
  Widget _bolumBasligi(
    ThemeData theme,
    VibeThemeExtension vibe,
    String baslik,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
      child: Text(
        baslik,
        style: TextStyle(
          color: vibe.mutedText,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }
}

// Etiket arama sonucu satırı
class _EtiketOneriSatiri extends StatelessWidget {
  final String tag;
  final VoidCallback onTap;

  const _EtiketOneriSatiri({
    required this.tag,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vibe = context.vibe;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 4),
      decoration: vibe.cardDecoration(radius: 14),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primary.withOpacity(0.15),
          child: Icon(
            Icons.tag,
            color: theme.colorScheme.primary,
            size: 20,
          ),
        ),
        title: Text(
          "#$tag",
          style: TextStyle(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          "Gönderileri gör",
          style: TextStyle(color: vibe.mutedText, fontSize: 12),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: vibe.mutedText,
        ),
      ),
    );
  }
}

// Kullanıcı arama sonucu satırı
class _KullaniciSatiri extends StatelessWidget {
  final String adSoyad;
  final String kullaniciAdi;
  final String photoUrl;
  final String avatarKey;
  final TakipDurumu takipDurumu;
  final bool durumYukleniyor;
  final VoidCallback onProfileTap;
  final VoidCallback onFollowTap;

  const _KullaniciSatiri({
    required this.adSoyad,
    required this.kullaniciAdi,
    required this.photoUrl,
    required this.avatarKey,
    required this.takipDurumu,
    required this.durumYukleniyor,
    required this.onProfileTap,
    required this.onFollowTap,
  });

  @override
  Widget build(BuildContext context) {
    final takipEdiliyor = takipDurumu == TakipDurumu.takipEdiliyor;
    final istekGonderildi = takipDurumu == TakipDurumu.istekGonderildi;
    final theme = Theme.of(context);
    final vibe = context.vibe;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 6),
      decoration: vibe.cardDecoration(),
      child: ListTile(
        onTap: onProfileTap,
        leading: vibeAvatar(
          radius: 20,
          photoUrl: photoUrl,
          avatarKey: avatarKey,
          fallbackText: kullaniciAdi,
          emojiSize: 18,
          fallbackIconSize: 20,
          fallbackForegroundColor: theme.colorScheme.onPrimary,
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
        trailing: durumYukleniyor
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.colorScheme.primary,
                ),
              )
            : TextButton(
                onPressed: onFollowTap,
                style: TextButton.styleFrom(
                  backgroundColor: takipEdiliyor || istekGonderildi
                      ? vibe.inputFill
                      : vibe.primaryButton,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Text(
                  SosyalServis.takipButonMetni(takipDurumu),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: takipEdiliyor || istekGonderildi
                        ? vibe.mutedText
                        : Colors.white,
                  ),
                ),
              ),
      ),
    );
  }
}
