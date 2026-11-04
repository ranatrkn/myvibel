import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:myvibel/ebeveyn_kontrol.dart';
import 'package:myvibel/ekran_koruma.dart';
import 'package:myvibel/google_giris_servis.dart';
import 'package:myvibel/legal_pages.dart';
import 'package:myvibel/sosyal_servis.dart';
import 'package:myvibel/widgets/vibe_gradient_scaffold.dart';
import 'package:myvibel/yas_dogrulama.dart';
import 'package:myvibel/yasal_icerik.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Oturumdaki kullanıcının beyan yaşına göre 15–17 / 18+ durumu.
class YasHesapKontrol extends ChangeNotifier {
  YasHesapKontrol._();

  DateTime? _dogum;

  DateTime? get dogumTarihi => _dogum;

  void _dogumuAyarla(DateTime? dogum) {
    _dogum = dogum;
    notifyListeners();
  }

  bool get yasAlti =>
      _dogum != null && !YasDogrulama.kayitIcinUygunMu(_dogum!);

  bool get cocukHesabi =>
      _dogum != null && YasDogrulama.cocukHesabiMi(_dogum!);

  bool get tamYetkili =>
      _dogum != null && YasDogrulama.tamYetkiliMi(_dogum!);

  /// Doğum tarihi yoksa (eski hesap) mesaj açık kalır.
  bool get mesajAcik => !cocukHesabi && !yasAlti;

  bool get reklamGosterilir => mesajAcik && !cocukHesabi;

  bool get kullaniciOnerisiAcik => !cocukHesabi && !yasAlti;

  bool get sonsuzKaydirmaAcik => !cocukHesabi && !yasAlti;

  static YasHesapKontrol? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_YasHesapScope>()?.kontrol;

  static YasHesapKontrol of(BuildContext context) {
    final k = maybeOf(context);
    assert(k != null, 'YasHesapKapsayici yok');
    return k!;
  }
}

class YasHesapKapsayici extends StatefulWidget {
  const YasHesapKapsayici({super.key, required this.child});

  final Widget child;

  @override
  State<YasHesapKapsayici> createState() => _YasHesapKapsayiciState();
}

class _YasHesapKapsayiciState extends State<YasHesapKapsayici> {
  final YasHesapKontrol _kontrol = YasHesapKontrol._();
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _abonelik;
  bool _senkronSuruyor = false;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      unawaited(_onbellektenYukle(uid));
      _dinlemeyeBasla(uid);
    }
  }

  @override
  void dispose() {
    _abonelik?.cancel();
    unawaited(EkranKoruma.ayarla(false));
    super.dispose();
  }

  String _onbellekAnahtari(String uid) => 'yas_dogum_ms_$uid';

  Future<void> _onbellektenYukle(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_onbellekAnahtari(uid));
    if (ms == null || !mounted || _kontrol._dogum != null) return;
    _kontrol._dogumuAyarla(DateTime.fromMillisecondsSinceEpoch(ms));
    if (mounted) setState(() {});
  }

  void _dinlemeyeBasla(String uid) {
    _abonelik = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('private')
        .doc('account')
        .snapshots()
        .listen((snap) {
      final dogum = YasDogrulama.timestampten(snap.data()?['dogumTarihi']);
      _kontrol._dogumuAyarla(dogum);
      unawaited(EkranKoruma.ayarla(_kontrol.cocukHesabi || _kontrol.yasAlti));
      if (mounted) setState(() {});
      if (dogum != null) {
        unawaited(_onbellegiYaz(uid, dogum));
        unawaited(_bayraklariSenkronizeEt(uid, dogum));
      }
    });
  }

  Future<void> _onbellegiYaz(String uid, DateTime dogum) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _onbellekAnahtari(uid),
      YasDogrulama.sadeceTarih(dogum).millisecondsSinceEpoch,
    );
  }

  Future<void> _bayraklariSenkronizeEt(String uid, DateTime dogum) async {
    if (_senkronSuruyor) return;
    if (!YasDogrulama.kayitIcinUygunMu(dogum)) return;
    _senkronSuruyor = true;
    try {
      final cocuk = YasDogrulama.cocukHesabiMi(dogum);
      final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
      final snap = await userRef.get();
      if (!snap.exists) return;
      final data = snap.data() ?? {};
      final guncelle = <String, dynamic>{};
      if (data['cocukHesabi'] != cocuk) {
        guncelle['cocukHesabi'] = cocuk;
      }
      if (cocuk && data['hesapGizli'] != true) {
        guncelle['hesapGizli'] = true;
      }
      if (guncelle.isEmpty) return;
      await userRef.update(guncelle);
      if (guncelle['hesapGizli'] == true) {
        await SosyalServis.kullaniciGonderilerindeGizlilikGuncelle(uid, true);
      }
    } catch (e) {
      debugPrint('yas bayrak senkron: $e');
    } finally {
      _senkronSuruyor = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _kontrol,
      builder: (context, _) {
        if (_kontrol.yasAlti) {
          return const _YasAltiEngelSayfasi();
        }
        final govde = _YasHesapScope(
          kontrol: _kontrol,
          child: widget.child,
        );
        if (_kontrol.cocukHesabi) {
          return EbeveynSureKapisi(child: govde);
        }
        return govde;
      },
    );
  }
}

class _YasHesapScope extends InheritedNotifier<YasHesapKontrol> {
  const _YasHesapScope({
    required YasHesapKontrol kontrol,
    required super.child,
  }) : super(notifier: kontrol);

  YasHesapKontrol get kontrol => notifier!;
}

class _YasAltiEngelSayfasi extends StatelessWidget {
  const _YasAltiEngelSayfasi();

  @override
  Widget build(BuildContext context) {
    return VibeGradientScaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 48),
              const SizedBox(height: 20),
              Text(
                '${YasalIcerik.uygulamaAdi} ${YasDogrulama.minimumYas} yaş ve üzeri içindir.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              const Text(
                'Beyan ettiğin doğum tarihine göre bu hesaba devam edilemez.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              OutlinedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          const ContactPage(ilkKategori: 'yas_itiraz'),
                    ),
                  );
                },
                child: const Text('İtiraz et'),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => GoogleGirisServis.oturumuKapat(),
                child: const Text('Çıkış yap'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
