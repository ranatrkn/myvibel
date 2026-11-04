// Kullanıcı ve etiket arama/keşfet sayfası.
import 'package:myvibel/tek_sefer_navigasyon.dart';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:myvibel/app_theme.dart';
import 'package:myvibel/widgets/vibe_yukleniyor.dart';
import 'package:myvibel/error_messages.dart';
import 'package:myvibel/etiket_navigasyon.dart';
import 'package:myvibel/puan_animasyon.dart';
import 'package:myvibel/sosyal_servis.dart';
import 'package:myvibel/leaderboard_page.dart';
import 'package:myvibel/maestro_semantics.dart';
import 'package:myvibel/vibe_snackbar.dart';
import 'package:myvibel/maskot_servis.dart';
import 'package:myvibel/widgets/vil_harcama_uyarisi.dart';
import 'package:myvibel/widgets/vibe_avatar.dart';
import 'package:myvibel/widgets/web_shell.dart';
import 'package:myvibel/yas_hesap_kontrol.dart';

// Keşfet ve arama ekranı
class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key, this.aktif = true});

  final bool aktif;

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> with WidgetsBindingObserver {
  final TextEditingController _aramaController = TextEditingController(); // Arama kutusu
  Timer? _aramaDebounce; // Yazmayı geciktiren zamanlayıcı
  bool _yuklemeSuruyor = false;

  List<Map<String, dynamic>> _tumKullanicilar = []; // Tüm kullanıcı listesi
  List<Map<String, dynamic>> _onerilenKullanicilar = []; // Önerilenler
  final Map<String, TakipDurumu> _takipDurumlari = {}; // Takip durumları
  final Set<String> _takipDurumuYukleniyor = {}; // Yüklenen takip durumları
  bool _yukleniyor = true;
  bool _veriYuklendi = false;
  String? _hataMesaji;
  Set<String> _engelIdleri = {};
  Set<String> _takipEdilenIdler = {};
  Set<String> _bilinenEtiketler = {}; // Bilinen hashtag'ler
  List<String> _etiketOnerileri = []; // Aktif arama etiket sonuçları
  List<Map<String, dynamic>> _uzakAramaSonuclari = [];
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
        unawaited(_etiketOnerileriniGuncelle());
        unawaited(_kullaniciAramasiniGuncelle());
      } else {
        setState(() {
          _etiketOnerileri = [];
          _uzakAramaSonuclari = [];
        });
      }
      setState(() {});
      if (_bilinenEtiketler.isEmpty) {
        _bilinenEtiketleriYenile();
      }
    });
  }

  Future<void> _kullaniciAramasiniGuncelle() async {
    final user = FirebaseAuth.instance.currentUser;
    final sorgu = _aramaSorgusu;
    if (user == null || sorgu.isEmpty) return;
    try {
      final prefix = SosyalServis.aramaMetnindenEtiket(sorgu) ?? sorgu;
      final uzak = await SosyalServis.kullaniciOnerileri(
        prefix,
        haricUid: user.uid,
        limit: 20,
      );
      final birlesik = [...uzak];
      final idler = birlesik.map((k) => k["uid"]?.toString() ?? "").toSet();

      Future<void> ekleUid(String? uid) async {
        if (uid == null || uid.isEmpty || uid == user.uid || idler.contains(uid)) {
          return;
        }
        if (_engelIdleri.contains(uid)) return;
        final snap =
            await FirebaseFirestore.instance.collection("users").doc(uid).get();
        if (!snap.exists) return;
        final data = snap.data() ?? {};
        idler.add(uid);
        birlesik.add({
          "uid": uid,
          "adSoyad": data["adSoyad"] ?? "Vibe Kullanıcısı",
          "kullaniciAdi": data["kullaniciAdi"] ?? prefix,
          "kullaniciAdiKucuk": data["kullaniciAdiKucuk"] ?? "",
          "photoUrl": data["photoUrl"] ?? "",
          "avatarKey": data["avatarKey"] ?? "",
          "aramaSkoru": data["aramaSkoru"] ?? 0,
        });
      }

      await ekleUid(await SosyalServis.kullaniciUidGetir(prefix));
      final exactSnap = await FirebaseFirestore.instance
          .collection("users")
          .where("kullaniciAdiKucuk", isEqualTo: prefix.toLowerCase())
          .limit(5)
          .get();
      for (final doc in exactSnap.docs) {
        await ekleUid(doc.id);
      }

      if (!mounted || _aramaSorgusu != sorgu) return;
      setState(() => _uzakAramaSonuclari = birlesik);
    } catch (_) {
      if (!mounted || _aramaSorgusu != sorgu) return;
      setState(() => _uzakAramaSonuclari = []);
    }
  }

  String get _aramaSorgusu => _aramaController.text.trim(); // Aktif arama metni

  // Etiket önerisine tıklanınca etiket sayfasına git
  void _etiketOnerisineBas(String tag) {
    etiketSayfasinaGit(context, tag);
  }

  void _aramayiTemizle() {
    _aramaController.clear();
    setState(() {
      _etiketOnerileri = [];
      _uzakAramaSonuclari = [];
    });
  }

  @override
  void didUpdateWidget(covariant ExplorePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.aktif && widget.aktif) {
      _verileriYukle();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _aramaDebounce?.cancel();
    _aramaController.dispose();
    super.dispose();
  }

  // Uygulama ön plana gelince, sekme görünürse verileri yenile
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.aktif) {
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

    if (_yuklemeSuruyor) return;
    _yuklemeSuruyor = true;

    final ilkYukleme = !_veriYuklendi;
    if (ilkYukleme) {
      setState(() {
        _yukleniyor = true;
        _hataMesaji = null;
      });
    }

    try {
      final firestore = FirebaseFirestore.instance;
      final sonuclar = await Future.wait([
        SosyalServis.engellenenKullanicilariGetir(user.uid),
        SosyalServis.beniEngelleyenKullanicilariGetir(user.uid),
        SosyalServis.takipEdilenIdleriGetir(user.uid),
      ]);
      _engelIdleri = {...sonuclar[0], ...sonuclar[1]};
      _takipEdilenIdler = sonuclar[2];

      await _kullanicilariYukle(firestore, user.uid);
      _veriYuklendi = true;
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
    } finally {
      _yuklemeSuruyor = false;
    }
  }

  Future<void> _kullanicilariYukle(FirebaseFirestore firestore, String uid) async {
    const kullaniciOnYuklemeLimiti = 120;
    final kullanicilarSnapshot = await firestore
        .collection("users")
        .limit(kullaniciOnYuklemeLimiti)
        .get();
    if (!mounted) return;
    final kullanicilar = kullanicilarSnapshot.docs
        .where((doc) => doc.id != uid && !_engelIdleri.contains(doc.id))
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
            "cocukHesabi": data["cocukHesabi"] == true,
            "aramaSkoru": data["aramaSkoru"] ?? 0,
          };
        })
        .toList();

    final onerilenler = kullanicilar
        .where((k) =>
            k["hesapGizli"] != true &&
            k["cocukHesabi"] != true &&
            !_takipEdilenIdler.contains(k["uid"]))
        .toList();
    onerilenler.sort((a, b) {
      final skorA = _intDeger(a["aramaSkoru"], 0);
      final skorB = _intDeger(b["aramaSkoru"], 0);
      final skorKarsilastirma = skorB.compareTo(skorA);
      if (skorKarsilastirma != 0) return skorKarsilastirma;
      final adA = (a["adSoyad"] as String).toLowerCase();
      final adB = (b["adSoyad"] as String).toLowerCase();
      return adA.compareTo(adB);
    });

    setState(() {
      _tumKullanicilar = kullanicilar;
      _onerilenKullanicilar =
          YasHesapKontrol.maybeOf(context)?.kullaniciOnerisiAcik == false
              ? <Map<String, dynamic>>[]
              : onerilenler.take(10).toList();
      _yukleniyor = false;
      _hataMesaji = null;
    });

    for (final k in _onerilenKullanicilar) {
      _takipDurumunuYukle(k["uid"] as String);
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

  // Profilden dönünce takip durumunu yeniler; eski durum görünür kalır
  Future<void> _takipDurumunuZorlaYukle(String uid) async {
    if (!_takipDurumlari.containsKey(uid)) {
      await _takipDurumunuYukle(uid);
      return;
    }
    try {
      final durum = await SosyalServis.takipDurumuGetir(uid);
      if (!mounted) return;
      setState(() => _takipDurumlari[uid] = durum);
    } catch (_) {}
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
    final yerel = _tumKullanicilar.where((kullanici) {
      final adSoyad = _normalle((kullanici["adSoyad"] as String));
      final kullaniciAdi = _normalle((kullanici["kullaniciAdi"] as String));
      final kullaniciAdiKucuk =
          _normalle((kullanici["kullaniciAdiKucuk"] as String));

      return adSoyad.contains(normSorgu) ||
          kullaniciAdi.contains(normSorgu) ||
          kullaniciAdiKucuk.contains(normSorgu);
    }).toList();

    final birlesik = [...yerel];
    final gorunenIdler = yerel.map((k) => k["uid"] as String).toSet();
    for (final kullanici in _uzakAramaSonuclari) {
      final uid = (kullanici["uid"] ?? "").toString();
      if (uid.isEmpty ||
          gorunenIdler.contains(uid) ||
          _engelIdleri.contains(uid)) {
        continue;
      }
      gorunenIdler.add(uid);
      birlesik.add({
        ...kullanici,
        "kullaniciAdiKucuk":
            (kullanici["kullaniciAdi"] ?? "").toString().toLowerCase(),
        "aramaSkoru": kullanici["aramaSkoru"] ?? 0,
      });
    }

    birlesik.sort((a, b) {
      final skorA = _intDeger(a["aramaSkoru"], 0);
      final skorB = _intDeger(b["aramaSkoru"], 0);
      final skorKarsilastirma = skorB.compareTo(skorA);
      if (skorKarsilastirma != 0) return skorKarsilastirma;
      final adA = (a["adSoyad"] as String).toLowerCase();
      final adB = (b["adSoyad"] as String).toLowerCase();
      return adA.compareTo(adB);
    });
    return birlesik;
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

    await profiliAc(context, userId);
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
    if (durum == TakipDurumu.takipEdiliyor) {
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
                    ? maestroButton(
                        label: MaestroSemantics.aramayiTemizle,
                        onTap: _aramayiTemizle,
                        child: IconButton(
                          tooltip: MaestroSemantics.aramayiTemizle,
                          onPressed: _aramayiTemizle,
                          icon: Icon(Icons.close, color: vibe.mutedText),
                        ),
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
                    _aramaYapiliyor
                        ? "Arama Sonuçları"
                        : (YasHesapKontrol.maybeOf(context)
                                    ?.kullaniciOnerisiAcik ==
                                false
                            ? "Keşfet"
                            : "Önerilen Kullanıcılar"),
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (!_aramaYapiliyor)
                  Semantics(
                    label: 'Liderlik',
                    button: true,
                    child: TextButton.icon(
                      onPressed: () {
                        tekSeferPush(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LeaderboardPage(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.emoji_events_outlined, size: 18),
                      label: const Text("Liderlik"),
                    ),
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
        child: VibeYukleniyor(renk: theme.colorScheme.primary),
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
              : "Şimdilik önerilecek yeni kullanıcı yok.\nArama ile kişi bulabilirsin.",
          textAlign: TextAlign.center,
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
            if (webMasaustuMu(context))
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final sutun = constraints.maxWidth >= 900 ? 3 : 2;
                    const gap = 10.0;
                    final kartGenislik =
                        (constraints.maxWidth - gap * (sutun - 1)) / sutun;
                    return Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: gorunenKullanicilar.map((kullanici) {
                        final uid = kullanici["uid"] as String;
                        if (!_takipDurumlari.containsKey(uid)) {
                          _takipDurumunuYukle(uid);
                        }
                        final durum =
                            _takipDurumlari[uid] ?? TakipDurumu.takipEtmiyor;
                        final durumYukleniyor =
                            _takipDurumuYukleniyor.contains(uid);
                        return SizedBox(
                          width: kartGenislik,
                          child: _KullaniciSatiri(
                            userId: uid,
                            adSoyad: kullanici["adSoyad"] as String,
                            kullaniciAdi: kullanici["kullaniciAdi"] as String,
                            photoUrl: kullanici["photoUrl"] as String,
                            avatarKey:
                                (kullanici["avatarKey"] ?? "").toString(),
                            takipDurumu: durum,
                            durumYukleniyor: durumYukleniyor,
                            onProfileTap: () => _kullaniciProfilineGit(uid),
                            onFollowTap: () => _takipButonunaBas(uid),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              )
            else
              ...gorunenKullanicilar.map((kullanici) {
                final uid = kullanici["uid"] as String;
                if (!_takipDurumlari.containsKey(uid)) {
                  _takipDurumunuYukle(uid);
                }
                final durum =
                    _takipDurumlari[uid] ?? TakipDurumu.takipEtmiyor;
                final durumYukleniyor = _takipDurumuYukleniyor.contains(uid);
                return _KullaniciSatiri(
                  userId: uid,
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
      decoration: vibe.satirKart(radius: 14),
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
  final String userId;
  final String adSoyad;
  final String kullaniciAdi;
  final String photoUrl;
  final String avatarKey;
  final TakipDurumu takipDurumu;
  final bool durumYukleniyor;
  final VoidCallback onProfileTap;
  final VoidCallback onFollowTap;

  const _KullaniciSatiri({
    required this.userId,
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

    return Semantics(
      label: 'Kullanıcı @$kullaniciAdi',
      button: true,
      child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 6),
      decoration: vibe.satirKart(),
      child: ListTile(
        onTap: onProfileTap,
        leading: vibeAvatar(
          radius: 20,
          userId: userId,
          liderTaciGoster: true,
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
    ),
    );
  }
}
