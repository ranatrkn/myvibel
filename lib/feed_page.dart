// Ana sayfa kabuğu: alt menü ile feed, keşfet, yeni gönderi, bildirim ve profil sekmeleri
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:myvibel/alinti_gonderi.dart';
import 'package:myvibel/explore_page.dart';
import 'package:myvibel/feed/feed_content.dart';
import 'package:myvibel/haftalik_gorev_servis.dart';
import 'package:myvibel/messages_page.dart';
import 'package:myvibel/newpost_page.dart';
import 'package:myvibel/notifications_page.dart';
import 'package:myvibel/profile_page.dart';
import 'package:myvibel/puan_animasyon.dart';
import 'package:myvibel/maskot_servis.dart';
import 'package:myvibel/sosyal/lider_tac_servis.dart';
import 'package:myvibel/widgets/isim_yan_rozet.dart';
import 'package:myvibel/sosyal_servis.dart';
import 'package:myvibel/maestro_semantics.dart';
import 'package:myvibel/vibe_snackbar.dart';
import 'package:myvibel/yasal_icerik.dart';
import 'package:myvibel/widgets/vibel_anlatici_paneli.dart';
import 'package:myvibel/app_theme.dart';
import 'package:myvibel/widgets/vibe_gradient_scaffold.dart';
import 'package:myvibel/widgets/vibe_ikonlar.dart';
import 'package:myvibel/widgets/vibe_marka_baslik.dart';
import 'package:myvibel/ana_kabuk.dart';
import 'package:myvibel/widgets/web_shell.dart';
import 'package:myvibel/yas_hesap_kontrol.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Feed modülü bileşenlerini dışa aktar
export 'package:myvibel/feed/feed_content.dart';
export 'package:myvibel/widgets/post_card.dart';
export 'package:myvibel/widgets/yorum_paneli.dart';

// Ana uygulama sayfası (StatefulWidget)
class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

// Feed sayfası durumu ve yaşam döngüsü yönetimi
class _FeedPageState extends State<FeedPage> with WidgetsBindingObserver {
  int _secilenIndeks = 0;
  Timer? _mascotDakikaTimer;
  DateTime? _sonMascotSenkron;
  final _feedKey = GlobalKey<FeedPageContentState>();
  final _exploreKey = GlobalKey();
  final _newPostKey = GlobalKey();
  final _notificationsKey = GlobalKey();
  final _profileKey = GlobalKey<ProfilePageState>();
  final Set<int> _acilanSekmeler = {0};
  AlintiGonderiBaglam? _alintiBaglam;
  bool _sohbetAcik = false;
  WebSohbetHedef? _acikSohbetHedef;
  final Map<int, GlobalKey<NavigatorState>> _ortaNavAnahtarlari = {};
  AnaKabuk? _kabuk;

  GlobalKey<NavigatorState> _ortaNavAnahtari(int indeks) {
    return _ortaNavAnahtarlari.putIfAbsent(
      indeks,
      () => GlobalKey<NavigatorState>(),
    );
  }

  void _sohbetiAc([WebSohbetHedef? hedef]) {
    setState(() {
      _sohbetAcik = true;
      if (hedef != null) _acikSohbetHedef = hedef;
    });
  }

  // Kapat (X) düğmesi, kapanınca altında beliren daraltılmış kartla aynı yerde;
  // aynı tıklamanın kartı yeniden açmasını engeller.
  DateTime? _sohbetKapanisZamani;

  void _sohbetKartinaTiklandi() {
    final kapanis = _sohbetKapanisZamani;
    if (kapanis != null &&
        DateTime.now().difference(kapanis) < const Duration(milliseconds: 600)) {
      return;
    }
    _sohbetiAc();
  }

  void _sohbetiKapat() {
    if (!_sohbetAcik) return;
    _sohbetKapanisZamani = DateTime.now();
    setState(() {
      _sohbetAcik = false;
      _acikSohbetHedef = null;
    });
  }

  void _sohbetToggle() {
    setState(() {
      _sohbetAcik = !_sohbetAcik;
      if (!_sohbetAcik) {
        _acikSohbetHedef = null;
        _sohbetKapanisZamani = DateTime.now();
      }
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _kabuk = AnaKabuk(
      sekmeyeGit: _sekmeyeGit,
      ortaNavigator: () => _ortaNavAnahtari(_secilenIndeks).currentState,
      kokNavigator: () {
        if (!mounted) return null;
        return Navigator.of(context, rootNavigator: true);
      },
    );
    AnaKabuk.aktif = _kabuk;
    _mascotDakikaTimerBaslat();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(LiderTacServis.instance.baslat());
      unawaited(HaftaRozetServis.instance.yenile());
      _mascotSenkronBaslat(zorla: true);
      Future<void>.delayed(const Duration(seconds: 3), () {
        if (!mounted) return;
        _gunlukGorevAcilisKaydet();
      });
      _surumNotuGoster();
      _seviyeKutlamaBaslat();
    });
  }

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _seviyeAboneligi;
  Future<void> _seviyeKuyrugu = Future<void>.value();
  int? _bilinenSeviye;

  // Seviye 6, 11 veya 21'e ulaşınca bir kez kutlama göster.
  void _seviyeKutlamaBaslat() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    _seviyeAboneligi?.cancel();
    _seviyeAboneligi = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen((snap) {
      final seviye = MascotServis.tryParse(snap.data()?['robot'])?.seviye;
      if (seviye == null) return;
      _seviyeKuyrugu = _seviyeKuyrugu
          .then((_) => _seviyeKontrol(uid, seviye))
          .catchError((Object e) {
        debugPrint('Seviye kutlaması kontrol edilemedi: $e');
      });
    }, onError: (Object e) {
      debugPrint('Seviye dinleyicisi hata verdi: $e');
    });
  }

  Future<void> _seviyeKontrol(String uid, int seviye) async {
    final anahtar = 'son_gorulen_seviye_$uid';
    final prefs = await SharedPreferences.getInstance();
    final onceki = _bilinenSeviye ?? prefs.getInt(anahtar);
    if (onceki == seviye) return;
    _bilinenSeviye = seviye;
    await prefs.setInt(anahtar, seviye);
    if (onceki == null || seviye < onceki || !mounted) return;
    final kutlanacak = MascotServis.kutlamaSeviyeleri
        .where((s) => s > onceki && s <= seviye)
        .toList();
    if (kutlanacak.isEmpty) return;
    await VibelAnlaticiPaneli.seviyeKutlamasiGoster(context, kutlanacak.last);
  }

  void _sekmeyeGit(int indeks) {
    final ayni = _secilenIndeks == indeks;
    setState(() {
      _acilanSekmeler.add(indeks);
      _secilenIndeks = indeks;
    });
    // Aynı sekmeye tekrar: iç navigator köküne dön (profil/detay stack temizle).
    if (ayni) {
      _ortaNavAnahtari(indeks).currentState?.popUntil((r) => r.isFirst);
    }
    if (indeks == 0) {
      final akis = _feedKey.currentState;
      if (akis != null && akis.mounted) {
        unawaited(akis.feediYenile());
      }
    }
  }

  void _alintiIlePaylas(AlintiGonderiBaglam baglam) {
    setState(() {
      _alintiBaglam = baglam;
      _acilanSekmeler.add(2);
      _secilenIndeks = 2;
    });
  }

  void _alintiBaglaminiTemizle() {
    if (_alintiBaglam == null) return;
    setState(() {
      _alintiBaglam = null;
    });
  }

  Widget _sayfaOlustur(int indeks) {
    switch (indeks) {
      case 0:
        return FeedPageContent(
          key: _feedKey,
          aktif: _secilenIndeks == 0,
          onKendiProfilineGit: AnaKabuk.kendiProfilineGit,
          onAlintiYap: _alintiIlePaylas,
        );
      case 1:
        return ExplorePage(
          key: _exploreKey,
          aktif: _secilenIndeks == 1,
        );
      case 2:
        return NewPostPage(
          key: _newPostKey,
          alintiBaglam: _alintiBaglam,
          onAlintiIptal: _alintiBaglaminiTemizle,
          onPostCreated: () {
            FocusManager.instance.primaryFocus?.unfocus();
            _alintiBaglaminiTemizle();
            _profileKey.currentState?.gonderileriYenile();
            _sekmeyeGit(0);
            _feedKey.currentState?.feediYenile();
          },
        );
      case 3:
        return NotificationsPage(
          key: _notificationsKey,
          aktif: _secilenIndeks == 3,
        );
      case 4:
        return ProfilePage(
          key: _profileKey,
          aktif: _secilenIndeks == 4,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _sayfaWidget(int indeks) => _sayfaOlustur(indeks);

  List<Widget> get _sekmeGovdeleri => List.generate(
        5,
        (indeks) => _acilanSekmeler.contains(indeks)
            ? _sayfaWidget(indeks)
            : const SizedBox.shrink(),
      );

  // Oturum açılışında görev ve takip ödüllerini senkronize et
  void _gunlukGorevAcilisKaydet() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    unawaited(HaftalikGorevServis.oturumSenkronizeEt(uid));
    unawaited(_takipOdulSenkronVeAnimasyon(uid));
  }

  Future<void> _takipOdulSenkronVeAnimasyon(String uid) async {
    final puan = await SosyalServis.takipOdulleriniSenkronizeEt(uid);
    if (!mounted || puan <= 0) return;
    // Overlay hazır olsun diye kısa gecikme
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    puanAnimasyonuGoster(context, puan);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _mascotDakikaTimer?.cancel();
    _seviyeAboneligi?.cancel();
    if (identical(AnaKabuk.aktif, _kabuk)) {
      AnaKabuk.aktif = null;
    }
    super.dispose();
  }

  // Uygulama ön/arka plana geçince maskot ve görevleri yönet
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _mascotSenkronBaslat(zorla: true);
      _mascotDakikaTimerBaslat();
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        unawaited(_takipOdulSenkronVeAnimasyon(uid));
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _mascotDakikaTimer?.cancel();
    }
  }

  // Her dakika maskot dakika senkronunu çalıştır
  void _mascotDakikaTimerBaslat() {
    _mascotDakikaTimer?.cancel();
    _mascotDakikaTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        MascotServis.dakikaSenkronizeEt(uid);
      }
    });
  }

  // Maskot senkron mesajlarını snackbar ile göster
  void _mascotSenkronBaslat({bool zorla = false}) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final simdi = DateTime.now();
    if (!zorla &&
        _sonMascotSenkron != null &&
        simdi.difference(_sonMascotSenkron!) <
            const Duration(minutes: 15)) {
      return;
    }
    _sonMascotSenkron = simdi;
    MascotServis.senkronizeEt(uid).then((sonuc) {
      if (!mounted || sonuc == null || sonuc.mesajlar.isEmpty) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger == null) return;
      for (final mesaj in sonuc.mesajlar) {
        // Mesaj tipine göre snackbar rengi seç
        final tip = MascotServis.senkronMesajBasariMi(mesaj)
            ? VibeMesajTipi.basari
            : MascotServis.senkronMesajBilgiMi(mesaj)
                ? VibeMesajTipi.bilgi
                : VibeMesajTipi.uyari;
        vibeSnackbarGoster(context, mesaj, tip: tip);
      }
    });
  }

  // İlk açılışta sürüm yeniliklerini bir kez göster
  Future<void> _surumNotuGoster() async {
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    await VibelAnlaticiPaneli.gerekirseGoster(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final masaustu = webMasaustuMu(context);

    // Web masaüstü: Twitter benzeri rail + dar orta + sağ sohbet.
    // Orta kolon nested Navigator: profil/detay vb. push rail+sohbeti kapatmaz.
    if (kIsWeb && masaustu) {
      final ortaNav = _ortaNavAnahtari(_secilenIndeks);
      return PopScope(
        canPop: false,
        onPopInvoked: (didPop) {
          if (didPop) return;
          final nav = ortaNav.currentState;
          if (nav != null && nav.canPop()) {
            nav.pop();
          }
        },
        child: VibeGradientScaffold(
          body: WebSohbetKapsayici(
            sohbetAcik: _sohbetAcik,
            sohbetiAc: _sohbetiAc,
            sohbetiKapat: _sohbetiKapat,
            sohbetToggle: _sohbetToggle,
            child: LayoutBuilder(
              builder: (context, kisit) => Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _masaustuRail(theme),
                Expanded(
                  child: WebIcerikCercevesi(
                    maxWidth: kWebAkisOrtaMax,
                    // Açılmış sekmeler canlı kalır: sekme değişince sayfa
                    // yeniden yüklenmez, iç navigator yığını korunur.
                    child: IndexedStack(
                      index: _secilenIndeks,
                      children: List.generate(
                        5,
                        (indeks) => _acilanSekmeler.contains(indeks)
                            ? Material(
                                type: MaterialType.transparency,
                                child: Navigator(
                                  key: _ortaNavAnahtari(indeks),
                                  onGenerateRoute: (settings) {
                                    return MaterialPageRoute<void>(
                                      settings: settings,
                                      builder: (_) => Material(
                                        type: MaterialType.transparency,
                                        child: _sayfaOlustur(indeks),
                                      ),
                                    );
                                  },
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
                if (YasHesapKontrol.maybeOf(context)?.mesajAcik == true)
                  _sagSohbetAlani(theme, kisit.maxWidth),
              ],
            ),
            ),
          ),
        ),
      );
    }

    // Web telefon: alt bar + aktif sekme.
    if (kIsWeb) {
      return VibeGradientScaffold(
        appBar: VibeGradientScaffold.seffafBaslik(
          YasalIcerik.uygulamaAdi,
          title: const VibeMarkaYazi(yukseklik: 35),
        ),
        body: _sayfaOlustur(_secilenIndeks),
        bottomNavigationBar: _altMenuCubugu(theme),
      );
    }

    final sekmeler = IndexedStack(
      index: _secilenIndeks,
      children: _sekmeGovdeleri,
    );

    return VibeGradientScaffold(
      appBar: VibeGradientScaffold.seffafBaslik(
        YasalIcerik.uygulamaAdi,
        title: const VibeMarkaYazi(yukseklik: 35),
      ),
      body: sekmeler,
      bottomNavigationBar: _altMenuCubugu(theme),
    );
  }

  Widget _sagSohbetAlani(ThemeData theme, double toplamGenislik) {
    final vibe = context.vibe;

    if (_sohbetAcik) {
      // Orta kolon (akış/keşfet) sıkışmasın: önce ona yer, kalan sohbete.
      final sohbetGenislik = (toplamGenislik - 92 - kWebAkisOrtaMax - 32)
          .clamp(420.0, kWebSohbetPanelGenislik);
      return SizedBox(
        width: sohbetGenislik,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: vibe.cardBorder, width: 1),
            ),
          ),
          child: MessagesPage(
            gomulu: true,
            onKapat: _sohbetiKapat,
            ilkHedef: _acikSohbetHedef,
          ),
        ),
      );
    }

    return SizedBox(
      width: kWebAkisYanGenislik,
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 20, 16, 8),
          child: Material(
            color: theme.cardColor.withOpacity(0.55),
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: _sohbetKartinaTiklandi,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(VibeIkon.mesajBos, color: vibe.mutedText, size: 22),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Sohbetler',
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.open_in_full,
                          size: 16,
                          color: vibe.faintText,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Mesajlarını görüntüle ve sohbet başlat.',
                      style: TextStyle(
                        color: vibe.mutedText,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _masaustuRail(ThemeData theme) {
    final seciliRenk = theme.bottomNavigationBarTheme.selectedItemColor ??
        theme.colorScheme.primary;
    final normalRenk = theme.bottomNavigationBarTheme.unselectedItemColor ??
        theme.colorScheme.onSurface.withOpacity(0.55);
    final uid = FirebaseAuth.instance.currentUser?.uid;

    Widget oge({
      required String etiket,
      required IconData ikon,
      required int indeks,
      IconData? ikonSecili,
      Widget? ikonWidget,
    }) {
      final secili = _secilenIndeks == indeks;
      final renk = secili ? seciliRenk : normalRenk;
      return InkWell(
        onTap: () {
          FocusManager.instance.primaryFocus?.unfocus();
          _sekmeyeGit(indeks);
        },
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconTheme(
                data: IconThemeData(color: renk, size: 26),
                child: ikonWidget ??
                    Icon(secili ? (ikonSecili ?? ikon) : ikon),
              ),
              const SizedBox(height: 4),
              Text(
                etiket,
                style: TextStyle(
                  color: renk,
                  fontSize: 11,
                  fontWeight: secili ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Material(
      color: theme.cardColor.withOpacity(0.4),
      child: SafeArea(
        right: false,
        child: SizedBox(
          width: 92,
          child: Column(
            children: [
              const SizedBox(height: 18),
              Image.asset(
                'assets/icon/myvibel_ikon.png',
                width: 40,
                height: 40,
                filterQuality: FilterQuality.high,
              ),
              const SizedBox(height: 20),
              oge(
                etiket: 'Akış',
                ikon: VibeIkon.ana,
                ikonSecili: VibeIkon.anaSecili,
                indeks: 0,
              ),
              oge(
                etiket: 'Keşfet',
                ikon: VibeIkon.kesfet,
                indeks: 1,
              ),
              oge(
                etiket: 'Gönder',
                ikon: VibeIkon.yeni,
                ikonSecili: VibeIkon.yeniSecili,
                indeks: 2,
              ),
              oge(
                etiket: 'Bildirim',
                ikon: VibeIkon.bildirim,
                ikonSecili: VibeIkon.bildirimSecili,
                indeks: 3,
                ikonWidget: StreamBuilder<int>(
                  stream: uid == null
                      ? Stream.value(0)
                      : SosyalServis.okunmamisBildirimSayisi(uid),
                  builder: (context, snapshot) {
                    final sayi = snapshot.data ?? 0;
                    final secili = _secilenIndeks == 3;
                    return Badge(
                      isLabelVisible: sayi > 0,
                      label: Text(sayi > 99 ? '99+' : '$sayi'),
                      child: Icon(
                        secili ? VibeIkon.bildirimSecili : VibeIkon.bildirim,
                        color: secili ? seciliRenk : normalRenk,
                      ),
                    );
                  },
                ),
              ),
              oge(
                etiket: 'Profil',
                ikon: VibeIkon.profil,
                ikonSecili: VibeIkon.profilSecili,
                indeks: 4,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _altMenuCubugu(ThemeData theme) {
    final seciliRenk = theme.bottomNavigationBarTheme.selectedItemColor ??
        theme.colorScheme.primary;
    final normalRenk = theme.bottomNavigationBarTheme.unselectedItemColor ??
        theme.colorScheme.onSurface.withOpacity(0.55);
    final arkaPlan =
        theme.bottomNavigationBarTheme.backgroundColor ?? theme.cardColor;

    Widget oge({
      required String erisimEtiketi,
      required IconData ikon,
      required int indeks,
      IconData? ikonSecili,
      Widget? ikonWidget,
    }) {
      final secili = _secilenIndeks == indeks;
      return Expanded(
        child: maestroButton(
          label: erisimEtiketi,
          selected: secili,
          onTap: () {
            FocusManager.instance.primaryFocus?.unfocus();
            _sekmeyeGit(indeks);
          },
          child: InkWell(
            onTap: () {
              FocusManager.instance.primaryFocus?.unfocus();
              _sekmeyeGit(indeks);
            },
            child: SizedBox(
              height: 56,
              child: IconTheme(
                data: IconThemeData(
                  color: secili ? seciliRenk : normalRenk,
                          size: 26,
                ),
                child: Center(
                    child: ikonWidget ??
                        Icon(secili ? (ikonSecili ?? ikon) : ikon),
                  ),
              ),
            ),
          ),
        ),
      );
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Material(
      color: arkaPlan,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Row(
          children: [
            oge(
              erisimEtiketi: MaestroSemantics.altMenuAna,
              ikon: VibeIkon.ana,
              ikonSecili: VibeIkon.anaSecili,
              indeks: 0,
            ),
            oge(
              erisimEtiketi: MaestroSemantics.altMenuKesfet,
              ikon: VibeIkon.kesfet,
              indeks: 1,
            ),
            oge(
              erisimEtiketi: MaestroSemantics.altMenuYeni,
              ikon: VibeIkon.yeni,
              ikonSecili: VibeIkon.yeniSecili,
              indeks: 2,
            ),
            oge(
              erisimEtiketi: MaestroSemantics.altMenuBildirim,
              ikon: VibeIkon.bildirim,
              ikonSecili: VibeIkon.bildirimSecili,
              indeks: 3,
              ikonWidget: StreamBuilder<int>(
                stream: uid == null
                    ? Stream.value(0)
                    : SosyalServis.okunmamisBildirimSayisi(uid),
                builder: (context, snapshot) {
                  final sayi = snapshot.data ?? 0;
                  return Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        _secilenIndeks == 3
                            ? VibeIkon.bildirimSecili
                            : VibeIkon.bildirim,
                      ),
                      if (sayi > 0)
                        Positioned(
                          right: -10,
                          top: -8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            constraints: const BoxConstraints(minWidth: 18),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              sayi > 99 ? "99+" : "$sayi",
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
            oge(
              erisimEtiketi: MaestroSemantics.altMenuProfil,
              ikon: VibeIkon.profil,
              ikonSecili: VibeIkon.profilSecili,
              indeks: 4,
            ),
          ],
        ),
      ),
    );
  }
}
