// Ana sayfa kabuğu: alt menü ile feed, keşfet, yeni gönderi, bildirim ve profil sekmeleri
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibe_life/explore_page.dart';
import 'package:vibe_life/feed/feed_content.dart';
import 'package:vibe_life/haftalik_gorev_servis.dart';
import 'package:vibe_life/legal_pages.dart';
import 'package:vibe_life/newpost_page.dart';
import 'package:vibe_life/notifications_page.dart';
import 'package:vibe_life/profile_page.dart';
import 'package:vibe_life/maskot_servis.dart';
import 'package:vibe_life/sosyal_servis.dart';
import 'package:vibe_life/maestro_semantics.dart';
import 'package:vibe_life/vibe_snackbar.dart';
import 'package:vibe_life/widgets/vibe_gradient_scaffold.dart';

// Feed modülü bileşenlerini dışa aktar
export 'package:vibe_life/feed/feed_content.dart';
export 'package:vibe_life/widgets/post_card.dart';
export 'package:vibe_life/widgets/yorum_paneli.dart';

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
  final Map<int, Widget> _sayfaOnbellek = {};
  final Set<int> _acilanSekmeler = {0};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _mascotSenkronBaslat();
    _mascotDakikaTimerBaslat();
    _surumNotuGoster();
    _gunlukGorevAcilisKaydet();
  }

  void _sekmeyeGit(int indeks) {
    setState(() {
      _acilanSekmeler.add(indeks);
      _secilenIndeks = indeks;
    });
  }

  Widget _sayfaOlustur(int indeks) {
    switch (indeks) {
      case 0:
        return FeedPageContent(
          key: _feedKey,
          onKendiProfilineGit: () => _sekmeyeGit(4),
        );
      case 1:
        return const ExplorePage();
      case 2:
        return NewPostPage(
          onPostCreated: () {
            FocusManager.instance.primaryFocus?.unfocus();
            _sekmeyeGit(0);
            _feedKey.currentState?.feediYenile();
          },
        );
      case 3:
        return const NotificationsPage();
      case 4:
        return const ProfilePage();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _sayfaWidget(int indeks) {
    return _sayfaOnbellek.putIfAbsent(indeks, () => _sayfaOlustur(indeks));
  }

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
    HaftalikGorevServis.oturumSenkronizeEt(uid);
    unawaited(SosyalServis.takipOdulleriniSenkronizeEt(uid));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _mascotDakikaTimer?.cancel();
    super.dispose();
  }

  // Uygulama ön/arka plana geçince maskot ve görevleri yönet
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _mascotSenkronBaslat();
      _mascotDakikaTimerBaslat();
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
  void _mascotSenkronBaslat() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final simdi = DateTime.now();
    if (_sonMascotSenkron != null &&
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
    final prefs = await SharedPreferences.getInstance();
    const key = 'last_seen_changelog_version';
    final seen = prefs.getString(key);
    if (seen == VibeLegal.appVersionLabel) return; // Zaten görüldü
    if (!mounted) return;
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yenilikler v${VibeLegal.appVersionLabel}'),
        content: const Text(
          '- Maskot sistemi iyilestirildi\n'
          '- Gizlilik ve guvenlik ayarlari guclendirildi\n'
          '- Arayuz ve mesajlar standardize edildi',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
    await prefs.setString(
        key, VibeLegal.appVersionLabel); // Görüldü olarak kaydet
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return VibeGradientScaffold(
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        title: const Text(
          "VibeLife",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ),
      // Seçili sekme görünür, diğerleri bellekte tutulur
      body: IndexedStack(
        index: _secilenIndeks,
        children: _sekmeGovdeleri,
      ),
      bottomNavigationBar: _altMenuCubugu(theme),
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
                child: Center(child: ikonWidget ?? Icon(ikon)),
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
        child: Row(
          children: [
            oge(
              erisimEtiketi: MaestroSemantics.altMenuAna,
              ikon: Icons.home,
              indeks: 0,
            ),
            oge(
              erisimEtiketi: MaestroSemantics.altMenuKesfet,
              ikon: Icons.search,
              indeks: 1,
            ),
            oge(
              erisimEtiketi: MaestroSemantics.altMenuYeni,
              ikon: Icons.add_circle_outline,
              indeks: 2,
            ),
            oge(
              erisimEtiketi: MaestroSemantics.altMenuBildirim,
              ikon: Icons.notifications_none,
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
                      const Icon(Icons.notifications_none),
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
                              color: Colors.redAccent,
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
              ikon: Icons.person_outline,
              indeks: 4,
            ),
          ],
        ),
      ),
    );
  }
}
