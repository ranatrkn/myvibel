// Ana feed içeriği: takip/keşfet sekmeleri, sayfalama ve maskot üst bar
import 'package:myvibel/tek_sefer_navigasyon.dart';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myvibel/alinti_gonderi.dart';
import 'package:myvibel/app_theme.dart';
import 'package:myvibel/widgets/vibe_yukleniyor.dart';
import 'package:myvibel/error_messages.dart';
import 'package:myvibel/maestro_semantics.dart';
import 'package:myvibel/messages_page.dart';
import 'package:myvibel/maskot_page.dart';
import 'package:myvibel/maskot_servis.dart';
import 'package:myvibel/reklam_servis.dart';
import 'package:myvibel/sosyal/sosyal_onbellek_servis.dart';
import 'package:myvibel/sosyal_servis.dart';
import 'package:myvibel/widgets/post_card.dart';
import 'package:myvibel/widgets/mascot_ruh_hali_metni.dart';
import 'package:myvibel/widgets/maskot_gelisim_cercevesi.dart';
import 'package:myvibel/widgets/maskot_lottie_view.dart';
import 'package:myvibel/widgets/vibe_ikonlar.dart';
import 'package:myvibel/widgets/vil_rozeti.dart';
import 'package:myvibel/widgets/web_shell.dart';
import 'package:myvibel/yas_hesap_kontrol.dart';

// Feed sekmesi türleri
enum FeedSekmesi { takip, kesfet }

const _sabitGonderiId = 'myvibel-karsilama';

// Feed ana içerik widget'ı
class FeedPageContent extends StatefulWidget {
  final VoidCallback onKendiProfilineGit;
  final ValueChanged<AlintiGonderiBaglam>? onAlintiYap;
  final bool aktif;

  const FeedPageContent({
    super.key,
    required this.onKendiProfilineGit,
    this.onAlintiYap,
    this.aktif = true,
  });

  @override
  State<FeedPageContent> createState() => FeedPageContentState();
}

class FeedPageContentState extends State<FeedPageContent>
    with WidgetsBindingObserver {
  FeedSekmesi _aktifSekme = FeedSekmesi.takip; // Aktif sekme
  Set<String> _takipEdilenIdler = {}; // Takip edilen kullanıcı uid'leri
  Set<String> _engelledigimIdler = {}; // Engellediğim kullanıcılar
  Set<String> _beniEngelleyenIdler = {}; // Beni engelleyen kullanıcılar
  SharedPreferences? _prefs; // DM okunma durumu için yerel depolama
  final ScrollController _scrollController = ScrollController();
  final List<DocumentSnapshot<Map<String, dynamic>>> _gorunenPostlar = [];
  final List<DocumentSnapshot<Map<String, dynamic>>> _bekleyenPostlar = [];
  DocumentSnapshot<Map<String, dynamic>>? _sabitGonderi;
  DocumentSnapshot<Map<String, dynamic>>?
      _sonPostBelgesi; // Keşfet sayfalama imleci
  static const int _sayfaBoyutu = 10; // Her yüklemede gösterilecek post sayısı
  static const int _partiBoyutu = 20; // Firestore'dan çekilen parti boyutu
  bool _ilkYukleme = true; // İlk yükleme devam ediyor mu
  bool _yukleniyorDahaFazla = false; // Sonsuz kaydırma yükleniyor mu
  bool _dahaFazlaVar = true; // Daha fazla post var mı
  bool _takipHazir = false; // Takip listesi yüklendi mi
  bool _engellerHazir = false; // Engel listeleri yüklendi mi
  bool _kendiPostlarYuklendi = false; // Kendi postları eklendi mi
  bool _takipIlkPartiYuklendi = false; // Takip edilenlerden ilk parti geldi mi
  final Map<String, DocumentSnapshot<Map<String, dynamic>>> _takipChunkImlec =
      {}; // Takip feed whereIn imleçleri
  String? _yuklemeHatasi; // Hata mesajı
  bool _feedYenilemeSuruyor = false; // Yenileme kilidi
  double _cekmeMesafesi = 0;
  bool _usttenNabiz = false; // Üstten çekme nabzı
  bool _yenilemedeListeyiDegistir = false;
  Set<String> _begenilenPostIdler = {}; // Beğeni durumu önbelleği
  bool _begenilenPostlarYuklendi = false;
  static const int _whereInChunk = 10;
  int _kesfetBosPartiSayaci =
      0; // Keşfet: filtre sonrası boş gelen ardışık partiler
  static const int _maxKesfetBosParti = 12;
  DateTime? _sonArkaPlanYenilemesi;

  List<int?> get _akisPlani {
    var tohum = 0;
    for (final post in _gorunenPostlar) {
      tohum = tohum * 31 + post.id.hashCode;
    }
    final reklamGosterilir =
        YasHesapKontrol.maybeOf(context)?.reklamGosterilir ?? true;
    return ReklamServis.akisPlani(
      _gorunenPostlar.length,
      tohum,
      reklamsiz: !reklamGosterilir,
    );
  }

  // Dışarıdan feed yenileme
  Future<void> feediYenile() => _feediYenile();

  // Beğeni değişince önbelleği güncelle
  void begeniOnbelleginiGuncelle(String postId, bool begenildi) {
    if (postId.isEmpty) return;
    setState(() {
      if (begenildi) {
        _begenilenPostIdler.add(postId);
      } else {
        _begenilenPostIdler.remove(postId);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_kaydirmaDinleyici);
    unawaited(_sosyalListeleriVeFeedBaslat());
    unawaited(_sabitGonderiyiGetir());
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      unawaited(_begenilenPostlariOnbellegeAl(uid).then((_) {
        if (mounted) setState(() {});
      }));
    }
    SharedPreferences.getInstance().then((prefs) {
      if (mounted) setState(() => _prefs = prefs);
    });
  }

  Future<void> _sosyalListeleriVeFeedBaslat() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _takipHazir = true;
          _engellerHazir = true;
        });
      }
      _feedYuklemeyeHazirMi();
      return;
    }

    final onbellek = await SosyalOnbellekServis.sosyalListeleriYukle(user.uid);
    if (onbellek != null && mounted) {
      setState(() {
        _takipEdilenIdler = onbellek.takipEdilenIdler;
        _engelledigimIdler = onbellek.engelledigimIdler;
        _beniEngelleyenIdler = onbellek.beniEngelleyenIdler;
        _takipHazir = true;
        _engellerHazir = true;
      });
      _feedYuklemeyeHazirMi();
      final taze = await SosyalOnbellekServis.sosyalListeTazeMi(user.uid);
      if (taze) return;
    }

    await _sosyalListeleriAgdanYukle(
      feedBaslat: onbellek == null,
      uid: user.uid,
    );
  }

  // Uygulama ön plana gelince feed'i yenile (seyrek)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final simdi = DateTime.now();
      if (_sonArkaPlanYenilemesi != null &&
          simdi.difference(_sonArkaPlanYenilemesi!) <
              const Duration(minutes: 15)) {
        return;
      }
      _sonArkaPlanYenilemesi = simdi;
      _feediYenile();
    }
  }

  // Önkoşullar sağlanınca post yükle
  void _feedYuklemeyeHazirMi() {
    if (!_takipHazir ||
        !_engellerHazir ||
        !_ilkYukleme ||
        _yukleniyorDahaFazla) {
      return;
    }
    _sonrakiPostlariYukle();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    super.dispose();
  }

  // Takip ve engel listelerini ağdan günceller
  Future<void> _sosyalListeleriAgdanYukle({
    required bool feedBaslat,
    required String uid,
  }) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final takipFuture = firestore
          .collection("users")
          .doc(uid)
          .collection("following")
          .limit(120)
          .get();
      final engelFuture = firestore
          .collection("users")
          .doc(uid)
          .collection("blocked")
          .limit(100)
          .get();
      final engelByFuture = firestore
          .collection("users")
          .doc(uid)
          .collection("blockedBy")
          .limit(100)
          .get();

      final takipSnap = await takipFuture;
      final takip = takipSnap.docs.map((d) => d.id).toSet();
      if (!mounted) return;
      setState(() {
        _takipEdilenIdler = takip;
        _takipHazir = true;
        _engellerHazir = true;
      });
      if (feedBaslat) _feedYuklemeyeHazirMi();

      final engelSonuclari = await Future.wait([engelFuture, engelByFuture]);
      final engel = engelSonuclari[0].docs.map((d) => d.id).toSet();
      final engelBy = engelSonuclari[1].docs.map((d) => d.id).toSet();
      unawaited(
        SosyalOnbellekServis.sosyalListeleriKaydet(
          uid,
          takipEdilenIdler: takip,
          engelledigimIdler: engel,
          beniEngelleyenIdler: engelBy,
        ),
      );
      if (!mounted) return;
      setState(() {
        _engelledigimIdler = engel;
        _beniEngelleyenIdler = engelBy;
        _gorunenPostlar.removeWhere(_engelliGonderiMi);
        _bekleyenPostlar.removeWhere(_engelliGonderiMi);
      });
    } catch (e) {
      debugPrint("sosyal listeler yuklenemedi: $e");
      if (!mounted) return;
      setState(() {
        _takipHazir = true;
        _engellerHazir = true;
      });
      if (feedBaslat) _feedYuklemeyeHazirMi();
    }
  }

  // Pull-to-refresh ve yenileme için sosyal listeleri tekrar çeker
  Future<void> _sosyalListeleriYukle({bool feedBaslat = true}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _takipHazir = true;
          _engellerHazir = true;
        });
      }
      if (feedBaslat) _feedYuklemeyeHazirMi();
      return;
    }

    await _sosyalListeleriAgdanYukle(feedBaslat: feedBaslat, uid: user.uid);
  }

  Future<void> _begenilenPostlariOnbellegeAl(
    String uid, {
    bool zorla = false,
  }) async {
    if (!zorla && _begenilenPostlarYuklendi) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection("users")
          .doc(uid)
          .collection("likedPosts")
          .orderBy("createdAt", descending: true)
          .limit(80)
          .get();
      _begenilenPostIdler = snap.docs.map((d) => d.id).toSet();
      _begenilenPostlarYuklendi = true;
    } catch (e) {
      debugPrint("begeni onbellek hatasi: $e");
      try {
        final yedek = await FirebaseFirestore.instance
            .collection("users")
            .doc(uid)
            .collection("likedPosts")
            .limit(80)
            .get();
        _begenilenPostIdler = yedek.docs.map((d) => d.id).toSet();
        _begenilenPostlarYuklendi = true;
      } catch (yedekHata) {
        debugPrint("begeni onbellek yedek hatasi: $yedekHata");
      }
    }
  }

  // Alta yaklaşınca daha fazla post yükle
  void _kaydirmaDinleyici() {
    if (YasHesapKontrol.maybeOf(context)?.sonsuzKaydirmaAcik == false) {
      return;
    }
    if (!_scrollController.hasClients ||
        _yukleniyorDahaFazla ||
        !_dahaFazlaVar) {
      return;
    }
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 300) {
      _sonrakiPostlariYukle();
    }
  }

  // Feed durumunu sıfırla ve yeniden yükle
  bool _asagiCekmeyiDinle(ScrollNotification bildirim) {
    if (bildirim.metrics.axis != Axis.vertical) return false;
    final tepede = bildirim.metrics.pixels <=
        bildirim.metrics.minScrollExtent + 0.5;
    if (bildirim is OverscrollNotification &&
        bildirim.overscroll < 0 &&
        tepede) {
      _cekmeMesafesi += -bildirim.overscroll;
    } else if (bildirim is ScrollUpdateNotification &&
        bildirim.dragDetails != null &&
        tepede &&
        (bildirim.scrollDelta ?? 0) < 0) {
      _cekmeMesafesi += -(bildirim.scrollDelta ?? 0);
    } else if (bildirim is ScrollUpdateNotification &&
        bildirim.metrics.pixels < bildirim.metrics.minScrollExtent) {
      _cekmeMesafesi =
          bildirim.metrics.minScrollExtent - bildirim.metrics.pixels;
    }
    if (bildirim is ScrollEndNotification) {
      final tetik = _cekmeMesafesi > 48;
      _cekmeMesafesi = 0;
      if (tetik && !_feedYenilemeSuruyor) {
        unawaited(_feediYenile());
      }
    }
    return false;
  }

  Future<void> _feediYenile() async {
    if (_feedYenilemeSuruyor) return;
    _feedYenilemeSuruyor = true;
    _usttenNabiz = true;
    if (mounted) setState(() {});
    if (_scrollController.hasClients) {
      unawaited(
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        ),
      );
    }
    try {
      await _sosyalListeleriYukle(feedBaslat: false);
      if (!mounted) return;
      _sabitGonderi = null;
      _sabitIstegi = null;
      _bekleyenPostlar.clear();
      _sonPostBelgesi = null;
      _yukleniyorDahaFazla = false;
      _dahaFazlaVar = true;
      _kendiPostlarYuklendi = false;
      _takipIlkPartiYuklendi = false;
      _takipChunkImlec.clear();
      _yuklemeHatasi = null;
      _kesfetBosPartiSayaci = 0;
      _yenilemedeListeyiDegistir = true;
    } finally {
      _feedYenilemeSuruyor = false;
      if (mounted) {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          unawaited(_begenilenPostlariOnbellegeAl(uid, zorla: true));
        }
        await _sonrakiPostlariYukle();
        if (mounted && _usttenNabiz && !_yukleniyorDahaFazla) {
          setState(() => _usttenNabiz = false);
        }
      }
    }
  }

  // createdAt alanını milisaniyeye çevir
  int _createdAtMs(Map<String, dynamic> data) {
    final createdAt = data["createdAt"];
    if (createdAt is Timestamp) {
      return createdAt.millisecondsSinceEpoch;
    }
    return 0;
  }

  // Takip feed chunk anahtarı
  String _takipChunkAnahtari(List<String> userIds) {
    final sirali = List<String>.from(userIds)..sort();
    return sirali.join('|');
  }

  // Postu bekleyen kuyruğa ekle (filtrelerden geçerse)
  bool _postuBekleyeneEkle(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    String currentUid,
    Set<String> gosterilenIdler,
  ) {
    if (doc.id == _sabitGonderiId) return false;
    if (gosterilenIdler.contains(doc.id)) return false;
    if (_bekleyenPostlar.any((d) => d.id == doc.id)) return false;

    final data = doc.data();
    if (data["raporNedeniyleGizli"] == true) return false;
    final ownerId = data["userId"]?.toString() ?? "";
    if (!_gonderiSekmedeGosterilir(data, ownerId, currentUid)) return false;

    _bekleyenPostlar.add(doc);
    return true;
  }

  // Feed sıralama puanı hesapla (skor + etkileşim + tazelik)
  double _feedPuani(Map<String, dynamic> post) {
    final skor = _intDeger(post["skor"], 0).toDouble();
    final begeni = _intDeger(post["begeniSayisi"], 0).toDouble();
    final yorum = _intDeger(post["yorumSayisi"], 0).toDouble();

    var tazelik = 0.0;
    final createdAt = post["createdAt"];
    if (createdAt is Timestamp) {
      final fark = DateTime.now().difference(createdAt.toDate());
      final benimUid = FirebaseAuth.instance.currentUser?.uid;
      if (benimUid != null &&
          post["userId"]?.toString() == benimUid &&
          fark.inMinutes < 30) {
        return 100000 - fark.inSeconds.toDouble();
      }
      final saat = fark.inHours;
      if (saat <= 6) {
        tazelik = 40;
      } else if (saat <= 24) {
        tazelik = 28;
      } else if (saat <= 72) {
        tazelik = 15;
      } else if (saat <= 168) {
        tazelik = 5;
      }
    }

    return skor * 0.4 + begeni * 0.8 + yorum * 1.2 + tazelik;
  }

  // Bekleyen postları puana göre sırala
  void _bekleyenPostlariSirala() {
    _bekleyenPostlar.sort(
      (a, b) => _feedPuani(b.data() ?? {}).compareTo(_feedPuani(a.data() ?? {})),
    );
  }

  // Kullanıcının kendi postlarını ekle
  Future<void> _kendiPostlarimiEkle(
    String uid,
    Set<String> gosterilenIdler,
  ) async {
    QuerySnapshot<Map<String, dynamic>> snap;
    try {
      snap = await FirebaseFirestore.instance
          .collection("posts")
          .where("userId", isEqualTo: uid)
          .orderBy("createdAt", descending: true)
          .limit(30)
          .get();
    } catch (e) {
      debugPrint("kendi postlari orderBy failed: $e");
      try {
        // İndeks yoksa sırasız sorgu dene
        snap = await FirebaseFirestore.instance
            .collection("posts")
            .where("userId", isEqualTo: uid)
            .limit(30)
            .get();
      } catch (yedek) {
        debugPrint("kendi postlari yedek failed: $yedek");
        return;
      }
    }

    final siraliDocs = snap.docs.toList()
      ..sort(
        (a, b) => _createdAtMs(b.data()).compareTo(_createdAtMs(a.data())),
      );

    for (final doc in siraliDocs) {
      _postuBekleyeneEkle(doc, uid, gosterilenIdler);
    }
  }

  // Takip feed için geçerli hedef kullanıcıları filtrele
  List<String> _takipFeedHedefleri(String uid) {
    return _takipEdilenIdler
        .where(
          (id) =>
              id.isNotEmpty &&
              id != uid &&
              !_engelledigimIdler.contains(id) &&
              !_beniEngelleyenIdler.contains(id),
        )
        .toList()
      ..sort();
  }

  // Tek takip edilen kullanıcının postlarını getir
  Future<({List<QueryDocumentSnapshot<Map<String, dynamic>>> docs, bool tamParti})>
      _takipEdilenPostlariniGetir({
    required String hedefUid,
    required String izleyiciUid,
  }) async {
    QuerySnapshot<Map<String, dynamic>> snap;
    final chunkKey = hedefUid;
    try {
      Query<Map<String, dynamic>> sorgu = FirebaseFirestore.instance
          .collection("posts")
          .where("userId", isEqualTo: hedefUid)
          .where("raporNedeniyleGizli", isEqualTo: false)
          .orderBy("createdAt", descending: true)
          .limit(_partiBoyutu);
      final imlec = _takipChunkImlec[chunkKey];
      if (imlec != null) {
        sorgu = sorgu.startAfterDocument(imlec);
      }
      snap = await sorgu.get();
    } catch (e) {
      debugPrint("takip feed $hedefUid indexed query failed: $e");
      snap = await FirebaseFirestore.instance
          .collection("posts")
          .where("userId", isEqualTo: hedefUid)
          .where("raporNedeniyleGizli", isEqualTo: false)
          .limit(_partiBoyutu)
          .get();
    }

    var docs =
        List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(snap.docs);
    docs.sort(
      (a, b) => _createdAtMs(b.data()).compareTo(_createdAtMs(a.data())),
    );

    if (docs.isNotEmpty) {
      _takipChunkImlec[chunkKey] = docs.last;
    }

    if (docs.length > _partiBoyutu) {
      docs = docs.sublist(0, _partiBoyutu);
    }
    return (docs: docs, tamParti: snap.docs.length >= _partiBoyutu);
  }

  // Takip edilen grubundan post partisi getir (whereIn ile tek sorgu)
  Future<({List<QueryDocumentSnapshot<Map<String, dynamic>>> docs, bool tamParti})>
      _takipChunkPostlariniGetir(
    List<String> userIds,
  ) async {
    if (userIds.isEmpty) {
      return (docs: <QueryDocumentSnapshot<Map<String, dynamic>>>[], tamParti: false);
    }

    final chunkKey = _takipChunkAnahtari(userIds);
    QuerySnapshot<Map<String, dynamic>> snap;
    try {
      Query<Map<String, dynamic>> sorgu = FirebaseFirestore.instance
          .collection("posts")
          .where("userId", whereIn: userIds)
          .where("raporNedeniyleGizli", isEqualTo: false)
          .orderBy("createdAt", descending: true)
          .limit(_partiBoyutu);
      final imlec = _takipChunkImlec[chunkKey];
      if (imlec != null) {
        sorgu = sorgu.startAfterDocument(imlec);
      }
      snap = await sorgu.get();
    } catch (e) {
      debugPrint("takip feed whereIn query failed: $e");
      var herhangiTamParti = false;
      final merged = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
      for (final hedefUid in userIds) {
        final sonuc = await _takipEdilenPostlariniGetir(
          hedefUid: hedefUid,
          izleyiciUid: '',
        );
        if (sonuc.tamParti) herhangiTamParti = true;
        merged.addAll(sonuc.docs);
      }
      merged.sort(
        (a, b) => _createdAtMs(b.data()).compareTo(_createdAtMs(a.data())),
      );
      final docs = merged.length > _partiBoyutu
          ? merged.sublist(0, _partiBoyutu)
          : merged;
      return (docs: docs, tamParti: herhangiTamParti);
    }

    var docs =
        List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(snap.docs);
    if (docs.isNotEmpty) {
      _takipChunkImlec[chunkKey] = docs.last;
    }
    docs.sort(
      (a, b) => _createdAtMs(b.data()).compareTo(_createdAtMs(a.data())),
    );
    if (docs.length > _partiBoyutu) {
      docs = docs.sublist(0, _partiBoyutu);
    }
    return (docs: docs, tamParti: snap.docs.length >= _partiBoyutu);
  }

  // Tüm takip edilenlerden post partisi yükle
  Future<({int eklenen, bool dahaFazlaPostVar})> _takipPostPartisiYukle(
    String uid,
    Set<String> gosterilenIdler,
  ) async {
    final takipEdilen = _takipFeedHedefleri(uid);

    if (takipEdilen.isEmpty) {
      return (eklenen: 0, dahaFazlaPostVar: false);
    }

    var eklenen = 0;
    var herhangiTamParti = false;
    for (var i = 0; i < takipEdilen.length; i += _whereInChunk) {
      final chunkEnd = i + _whereInChunk > takipEdilen.length
          ? takipEdilen.length
          : i + _whereInChunk;
      final chunk = takipEdilen.sublist(i, chunkEnd);
      final sonuc = await _takipChunkPostlariniGetir(chunk);
      if (sonuc.tamParti) herhangiTamParti = true;
      for (final doc in sonuc.docs) {
        if (_postuBekleyeneEkle(doc, uid, gosterilenIdler)) {
          eklenen++;
        }
      }
    }

    return (eklenen: eklenen, dahaFazlaPostVar: herhangiTamParti);
  }

  // Keşfet/Akış sekmesi için genel post partisi yükle
  Future<int> _kesfetPostPartisiYukle(
    String uid,
    Set<String> gosterilenIdler,
  ) async {
    QuerySnapshot<Map<String, dynamic>> snap;
    try {
      Query<Map<String, dynamic>> sorgu = FirebaseFirestore.instance
          .collection("posts")
          .where("ownerHesapGizli", isEqualTo: false)
          .where("raporNedeniyleGizli", isEqualTo: false)
          .orderBy("createdAt", descending: true)
          .limit(_partiBoyutu);

      if (_sonPostBelgesi != null) {
        sorgu = sorgu.startAfterDocument(_sonPostBelgesi!);
      }

      snap = await sorgu.get();
    } on FirebaseException catch (e) {
      debugPrint("kesfet feed indexed query failed: ${e.code} ${e.message}");
      // Tüm koleksiyonu taramak kurallarda permission-denied üretir; filtreli yedek kullan.
      final fallbackSnap = await FirebaseFirestore.instance
          .collection("posts")
          .where("ownerHesapGizli", isEqualTo: false)
          .where("raporNedeniyleGizli", isEqualTo: false)
          .limit(_partiBoyutu * 4)
          .get();
      var docs = fallbackSnap.docs.toList()
        ..sort(
          (a, b) => _createdAtMs(b.data()).compareTo(_createdAtMs(a.data())),
        );

      if (_sonPostBelgesi != null) {
        final cursorMs = _createdAtMs(_sonPostBelgesi!.data() ?? {});
        final cursorId = _sonPostBelgesi!.id;
        docs = docs.where((doc) {
          final ms = _createdAtMs(doc.data());
          if (ms < cursorMs) return true;
          if (ms > cursorMs) return false;
          return doc.id.compareTo(cursorId) < 0;
        }).toList();
      }

      if (docs.length > _partiBoyutu) {
        docs = docs.sublist(0, _partiBoyutu);
      }

      if (docs.isEmpty) {
        return 0;
      }

      _sonPostBelgesi = docs.last;
      if (docs.length < _partiBoyutu) {
        _dahaFazlaVar = false;
      }

      var eklenen = 0;
      for (final doc in docs) {
        if (_postuBekleyeneEkle(doc, uid, gosterilenIdler)) {
          eklenen++;
        }
      }
      return eklenen;
    }

    if (snap.docs.isEmpty) {
      return 0;
    }

    _sonPostBelgesi = snap.docs.last;
    if (snap.docs.length < _partiBoyutu) {
      _dahaFazlaVar = false;
    }

    var eklenen = 0;
    for (final doc in snap.docs) {
      if (_postuBekleyeneEkle(doc, uid, gosterilenIdler)) {
        eklenen++;
      }
    }
    return eklenen;
  }

  // Sonraki sayfa postlarını yükle (sonsuz kaydırma)
  Future<void> _sonrakiPostlariYukle() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null ||
        _yukleniyorDahaFazla ||
        _feedYenilemeSuruyor ||
        !_dahaFazlaVar ||
        !_takipHazir ||
        !_engellerHazir) {
      return;
    }

    setState(() {
      _yukleniyorDahaFazla = true;
      _yuklemeHatasi = null;
    });

    try {
      await _sonrakiPostlariYukleGovdesi(user);
    } catch (e) {
      if (!mounted) return;
      final kod = e is FirebaseException ? e.code : e.runtimeType.toString();
      setState(() {
        _yuklemeHatasi = internetAwareErrorMessage(
          error: e,
          fallback: "Gönderiler yüklenemedi ($kod).",
        );
        _ilkYukleme = false;
        _yukleniyorDahaFazla = false;
        _usttenNabiz = false;
        _yenilemedeListeyiDegistir = false;
      });
    }
  }

  Future<void> _sonrakiPostlariYukleGovdesi(User user) async {
    final gosterilenIdler = _yenilemedeListeyiDegistir
        ? <String>{}
        : _gorunenPostlar.map((d) => d.id).toSet();

    // Takip sekmesinde önce kendi postlarını ekle
    if (_aktifSekme == FeedSekmesi.takip && !_kendiPostlarYuklendi) {
      await _kendiPostlarimiEkle(user.uid, gosterilenIdler);
      _kendiPostlarYuklendi = true;
      _bekleyenPostlariSirala();
    }

    // Kuyruk dolana kadar parti yükle; kendi postları kuyruğu doldursa da
    // takip edilenlerin ilk partisi sıralamaya girmeli.
    while ((_bekleyenPostlar.length < _sayfaBoyutu ||
            (_aktifSekme == FeedSekmesi.takip && !_takipIlkPartiYuklendi)) &&
        _dahaFazlaVar) {
      final oncekiSayi = _bekleyenPostlar.length;
      if (_aktifSekme == FeedSekmesi.takip) {
        late final ({int eklenen, bool dahaFazlaPostVar}) sonuc;
        try {
          sonuc = await _takipPostPartisiYukle(user.uid, gosterilenIdler);
          _takipIlkPartiYuklendi = true;
        } catch (e) {
          debugPrint('takip post partisi failed: $e');
          _dahaFazlaVar = false;
          break;
        }
        if (sonuc.eklenen == 0 &&
            _bekleyenPostlar.length == oncekiSayi &&
            !sonuc.dahaFazlaPostVar) {
          final takipHedefiVar = _takipFeedHedefleri(user.uid).isNotEmpty;
          if (!takipHedefiVar && _kendiPostlarYuklendi) {
            _dahaFazlaVar = false;
          } else if (takipHedefiVar) {
            _dahaFazlaVar = false;
          }
          break;
        }
      } else {
        late final int eklenen;
        try {
          eklenen =
              await _kesfetPostPartisiYukle(user.uid, gosterilenIdler);
        } catch (e) {
          debugPrint('kesfet post partisi failed: $e');
          rethrow;
        }
        if (eklenen == 0) {
          if (!_dahaFazlaVar) {
            break;
          }
          _kesfetBosPartiSayaci++;
          if (_kesfetBosPartiSayaci >= _maxKesfetBosParti) {
            _dahaFazlaVar = false;
            break;
          }
          continue;
        }
        _kesfetBosPartiSayaci = 0;
      }

      _bekleyenPostlariSirala();
    }

    if (_gorunenPostlar.isEmpty || _yenilemedeListeyiDegistir) {
      await _sabitGonderiyiGetir();
    }

    if (_bekleyenPostlar.isEmpty && !_dahaFazlaVar && _sabitGonderi == null) {
      if (!mounted) return;
      setState(() {
        if (_yenilemedeListeyiDegistir) _gorunenPostlar.clear();
        _ilkYukleme = false;
        _yukleniyorDahaFazla = false;
        _usttenNabiz = false;
        _yenilemedeListeyiDegistir = false;
      });
      return;
    }

    // Sayfa boyutu kadarını görünür listeye taşı
    final eklenecek = _bekleyenPostlar.take(_sayfaBoyutu).toList();
    if (eklenecek.isNotEmpty) {
      _bekleyenPostlar.removeRange(0, eklenecek.length);
    }

    if (!mounted) return;
    setState(() {
      if (_yenilemedeListeyiDegistir) {
        _gorunenPostlar
          ..clear()
          ..addAll(eklenecek);
        _yenilemedeListeyiDegistir = false;
        _usttenNabiz = false;
      } else {
        _gorunenPostlar.addAll(eklenecek);
      }
      _gorunenPostlar.removeWhere((d) => d.id == _sabitGonderiId);
      final sabit = _sabitGonderi;
      if (sabit != null && sabit.data()?['raporNedeniyleGizli'] != true) {
        _gorunenPostlar.insert(0, sabit);
      }
      _ilkYukleme = false;
      _yukleniyorDahaFazla = false;
      _dahaFazlaVar = _bekleyenPostlar.isNotEmpty || _dahaFazlaVar;
    });
  }

  bool _engelliGonderiMi(DocumentSnapshot<Map<String, dynamic>> doc) {
    final sahip = doc.data()?["userId"]?.toString() ?? "";
    return _engelledigimIdler.contains(sahip) ||
        _beniEngelleyenIdler.contains(sahip);
  }

  Future<void>? _sabitIstegi;

  Future<void> _sabitGonderiyiGetir() {
    return _sabitIstegi ??= _sabitGonderiyiGetirIc();
  }

  Future<void> _sabitGonderiyiGetirIc() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('posts')
          .doc(_sabitGonderiId)
          .get();
      _sabitGonderi = snap.exists ? snap : null;
    } catch (e) {
      debugPrint('sabit gonderi: $e');
    }
    final sabit = _sabitGonderi;
    if (!mounted || sabit == null || _ilkYukleme) return;
    if (sabit.data()?['raporNedeniyleGizli'] == true) return;
    setState(() {
      _gorunenPostlar.removeWhere((d) => d.id == _sabitGonderiId);
      _gorunenPostlar.insert(0, sabit);
    });
  }

  // Post aktif sekmede gösterilmeli mi
  bool _gonderiSekmedeGosterilir(
    Map<String, dynamic> post,
    String postOwnerId,
    String currentUid,
  ) {
    if (postOwnerId.isEmpty) return false;
    if (_engelledigimIdler.contains(postOwnerId) ||
        _beniEngelleyenIdler.contains(postOwnerId)) {
      return false;
    }

    switch (_aktifSekme) {
      case FeedSekmesi.takip:
        // Takip edilen veya kendi postu
        if (postOwnerId != currentUid &&
            !_takipEdilenIdler.contains(postOwnerId)) {
          return false;
        }
        final gizli = post["ownerHesapGizli"] == true;
        if (gizli &&
            postOwnerId != currentUid &&
            !_takipEdilenIdler.contains(postOwnerId)) {
          return false;
        }
        return true;
      case FeedSekmesi.kesfet:
        // Açık hesap gönderileri keşfette görünür (takip etsen de etmesen de).
        if (post["ownerHesapGizli"] == true) return false;
        return true;
    }
  }

  // Sekme değişince feed'i sıfırla
  void _sekmeDegistir(FeedSekmesi yeniSekme) {
    if (_aktifSekme == yeniSekme) return;
    setState(() {
      _aktifSekme = yeniSekme;
    });
    _feediYenile();
  }

  // Boş feed mesajı (sekme bazlı)
  String get _bosFeedMesaji {
    switch (_aktifSekme) {
      case FeedSekmesi.takip:
        return "Henüz gösterilecek gönderi yok.\nPaylaş veya takip ettiğin hesapları kontrol et.";
      case FeedSekmesi.kesfet:
        return "Keşfet feed'inde gösterilecek gönderi yok.";
    }
  }

  // Dinamik değeri int'e çevir
  int _intDeger(dynamic value, int varsayilan) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return varsayilan;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);
    final vibe = context.vibe;

    if (user == null) {
      return Center(
        child: Text(
          "Kullanıcı bulunamadı.",
          style: TextStyle(color: theme.colorScheme.onSurface),
        ),
      );
    }

    final akisKolonu = Column(
      children: [
        // Maskot ve kullanıcı üst barı (önbellek + canlı dinleme)
        _FeedUstBar(
          uid: user.uid,
          prefs: _prefs,
          aktif: widget.aktif,
          onMascotTap: () {
            tekSeferPush(
              context,
              MaterialPageRoute(builder: (_) => const MascotPage()),
            );
          },
          onMessagesReturn: () {
            if (mounted) setState(() {});
          },
        ),
        // Takip / Keşfet sekme seçici
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Container(
            decoration: vibe.cardDecoration(radius: 16),
            child: Row(
              children: [
                Expanded(
                  child: _feedSekmeButonu(
                    theme: theme,
                    vibe: vibe,
                    etiket: "Takip Edilen",
                    secili: _aktifSekme == FeedSekmesi.takip,
                    onTap: () => _sekmeDegistir(FeedSekmesi.takip),
                  ),
                ),
                Expanded(
                  child: _feedSekmeButonu(
                    theme: theme,
                    vibe: vibe,
                    etiket: "Akış",
                    secili: _aktifSekme == FeedSekmesi.kesfet,
                    onTap: () => _sekmeDegistir(FeedSekmesi.kesfet),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Post listesi veya durum göstergeleri
        Expanded(
          child: _ilkYukleme
              ? Center(
                  child: VibeYukleniyor(renk: theme.colorScheme.primary),
                )
              : _yuklemeHatasi != null
                  ? Center(
                      child: Text(
                        _yuklemeHatasi!,
                        style: TextStyle(color: vibe.subtleText),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : _gorunenPostlar.isEmpty
                      ? Center(
                          child: Text(
                            _bosFeedMesaji,
                            style: TextStyle(color: vibe.subtleText),
                            textAlign: TextAlign.center,
                          ),
                        )
                      : ScrollConfiguration(
                          behavior: const _PariltiYok(),
                          child: NotificationListener<ScrollNotification>(
                          onNotification: _asagiCekmeyiDinle,
                          child: ListView.builder(
                            controller: _scrollController,
                            physics: const BouncingScrollPhysics(
                              parent: AlwaysScrollableScrollPhysics(),
                            ),
                            padding:
                                const EdgeInsets.only(top: 5, bottom: 28),
                            itemCount: (_usttenNabiz ? 1 : 0) +
                                _akisPlani.length +
                                (_dahaFazlaVar ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (_usttenNabiz && index == 0) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 14),
                                  child: Center(child: VibeYukleniyor()),
                                );
                              }
                              final listeIndex =
                                  _usttenNabiz ? index - 1 : index;
                              final slotSayisi = _akisPlani.length;
                              if (listeIndex >= slotSayisi) {
                                final butonla =
                                    YasHesapKontrol.maybeOf(context)
                                            ?.sonsuzKaydirmaAcik ==
                                        false;
                                if (butonla) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                      horizontal: 24,
                                    ),
                                    child: Center(
                                      child: OutlinedButton(
                                        onPressed: _yukleniyorDahaFazla
                                            ? null
                                            : _sonrakiPostlariYukle,
                                        child: Text(
                                          _yukleniyorDahaFazla
                                              ? 'Yükleniyor...'
                                              : 'Daha fazla göster',
                                        ),
                                      ),
                                    ),
                                  );
                                }
                                return Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: Center(
                                    child: VibeYukleniyor(
                                      renk: theme.colorScheme.primary,
                                    ),
                                  ),
                                );
                              }

                              final postSirasi = _akisPlani[listeIndex];
                              if (postSirasi == null) {
                                return GonderiReklami(
                                  key: ValueKey('reklam-$index'),
                                  slot: 'reklam-$index',
                                );
                              }
                              final postId = _gorunenPostlar[postSirasi].id;
                              final post =
                                  _gorunenPostlar[postSirasi].data() ?? {};

                              return PostCard(
                                key: ValueKey(postId),
                                postId: postId,
                                postOwnerId: post["userId"] ?? "",
                                kullaniciAdi: post["kullaniciAdi"] ??
                                    "Vibe Kullanıcısı",
                                metin: post["metin"] ?? "",
                                mentionUidleri:
                                    SosyalServis.bahsetmeUidHaritasiParse(
                                  post["mentionUidleri"],
                                ),
                                photoUrl: post["photoUrl"] ?? "",
                                avatarKey: post["avatarKey"] ?? "",
                                createdAt: post["createdAt"],
                                ownerHesapGizli:
                                    post["ownerHesapGizli"] == true,
                                alintiSnapshot: AlintiGonderiSnapshot.haritadan(
                                  post["alintiSnapshot"],
                                  postId: post["alintiPostId"]?.toString(),
                                  icAlintiDahilEt: false,
                                ),
                                baslangicBegeniSayisi:
                                    post["begeniSayisi"] ?? 0,
                                baslangicYorumSayisi:
                                    post["yorumSayisi"] ?? 0,
                                baslangicBegenildi: _begenilenPostlarYuklendi
                                    ? _begenilenPostIdler.contains(postId)
                                    : null,
                                userId: user.uid,
                                engellenenKullanicilar: _engelledigimIdler,
                                beniEngelleyenler: _beniEngelleyenIdler,
                                onKendiProfilineGit:
                                    widget.onKendiProfilineGit,
                                onAlintiYap: widget.onAlintiYap,
                                onBegeniDegisti: (begenildi) =>
                                    begeniOnbelleginiGuncelle(
                                        postId, begenildi),
                              );
                            },
                          ),
                        ),
                      ),
        ),
      ],
    );

    return SafeArea(
      bottom: false,
      child: akisKolonu,
    );
  }

// Sekme butonu widget'ı
  Widget _feedSekmeButonu({
    required ThemeData theme,
    required VibeThemeExtension vibe,
    required String etiket,
    required bool secili,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: secili ? theme.colorScheme.primary.withOpacity(0.15) : null,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: Text(
          etiket,
          style: TextStyle(
            color: secili ? theme.colorScheme.primary : vibe.mutedText,
            fontWeight: secili ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    ),
    );
  }
}

// Feed üst barı: önbellekten anında çiz, kullanıcı belgesini canlı dinle
class _FeedUstBar extends StatefulWidget {
  const _FeedUstBar({
    required this.uid,
    required this.prefs,
    required this.onMascotTap,
    required this.onMessagesReturn,
    this.aktif = true,
  });

  final String uid;
  final SharedPreferences? prefs;
  final VoidCallback onMascotTap;
  final VoidCallback onMessagesReturn;
  final bool aktif;

  @override
  State<_FeedUstBar> createState() => _FeedUstBarState();
}

class _FeedUstBarState extends State<_FeedUstBar> {
  static String _dmNoktaAnahtari(String uid) => 'dm_unread_badge_$uid';

  Map<String, dynamic>? _kullaniciVerisi;
  bool _dmOkunmamis = false;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _sonSohbetDocs = [];
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _kullaniciAbonelik;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _dmAbonelik;

  @override
  void initState() {
    super.initState();
    _dmOkunmamis = widget.prefs?.getBool(_dmNoktaAnahtari(widget.uid)) ?? false;
    unawaited(_onbellektenYukle());
    if (widget.aktif) {
      _kullaniciDinlemeyiBaslat();
      _dmDinlemeyiBaslat();
    }
  }

  @override
  void didUpdateWidget(covariant _FeedUstBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uid != widget.uid) {
      _kullaniciVerisi = null;
      _sonSohbetDocs = [];
      _dmOkunmamis =
          widget.prefs?.getBool(_dmNoktaAnahtari(widget.uid)) ?? false;
      unawaited(_onbellektenYukle());
    }
    if (oldWidget.prefs != widget.prefs && _sonSohbetDocs.isNotEmpty) {
      _dmDurumunuUygula(_sonSohbetDocs);
    }
    if (oldWidget.uid != widget.uid || oldWidget.aktif != widget.aktif) {
      if (widget.aktif) {
        _kullaniciDinlemeyiBaslat();
        _dmDinlemeyiBaslat();
      } else {
        _kullaniciAbonelik?.cancel();
        _kullaniciAbonelik = null;
        _dmAbonelik?.cancel();
        _dmAbonelik = null;
      }
    }
  }

  @override
  void dispose() {
    _kullaniciAbonelik?.cancel();
    _dmAbonelik?.cancel();
    super.dispose();
  }

  Future<void> _onbellektenYukle() async {
    final onbellek =
        await SosyalOnbellekServis.feedUstVerisiYukle(widget.uid);
    if (onbellek == null || !mounted || _kullaniciVerisi != null) return;
    setState(() => _kullaniciVerisi = onbellek);
  }

  void _kullaniciDinlemeyiBaslat() {
    _kullaniciAbonelik?.cancel();
    _kullaniciAbonelik = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.uid)
        .snapshots()
        .listen(
      (doc) {
        if (!doc.exists || !mounted) return;
        final data = doc.data() ?? {};
        setState(() => _kullaniciVerisi = data);
        unawaited(SosyalOnbellekServis.feedUstVerisiKaydet(widget.uid, data));
      },
      onError: (e) {
        debugPrint('feed ust bar verisi yuklenemedi: $e');
      },
    );
  }

  void _dmDinlemeyiBaslat() {
    _dmAbonelik?.cancel();
    _dmAbonelik = SosyalServis.sohbetlerim(widget.uid).listen(
      (snap) {
        if (!mounted) return;
        _dmDurumunuUygula(snap.docs);
      },
      onError: (e) {
        debugPrint('dm durumu dinlenemedi: $e');
      },
    );
  }

  void _dmDurumunuUygula(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    _sonSohbetDocs = docs;
    final yeni = _dmOkunmamisVar(docs);
    if (yeni != _dmOkunmamis && mounted) {
      setState(() => _dmOkunmamis = yeni);
    }
    final prefs = widget.prefs;
    if (prefs != null) {
      unawaited(prefs.setBool(_dmNoktaAnahtari(widget.uid), yeni));
    }
  }

  bool _dmOkunmamisVar(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final prefs = widget.prefs;
    for (final doc in docs) {
      final data = doc.data();
      final hiddenKey = "dm_hidden_chat_${widget.uid}_${doc.id}";
      final hiddenAtMs = prefs?.getInt(hiddenKey);
      if (SosyalServis.sohbetGizliMi(
        uid: widget.uid,
        chat: data,
        localHiddenAtMs: hiddenAtMs,
      )) {
        continue;
      }
      final localReadMs = prefs?.getInt("dm_last_read_${widget.uid}_${doc.id}");
      if (SosyalServis.sohbetOkunmamisMi(
        uid: widget.uid,
        chat: data,
        localReadAtMs: localReadMs,
      )) {
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vibe = context.vibe;
    final data = _kullaniciVerisi;
    final mascot = data == null ? null : MascotServis.tryParse(data['robot']);

    if (data == null || mascot == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: SizedBox(
          height: 75,
          child: Center(
            child: VibeYukleniyor(renk: theme.colorScheme.primary),
          ),
        ),
      );
    }

    return _ustBarIcerik(context, theme, vibe, data, mascot, _dmOkunmamis);
  }

  Widget _ustBarIcerik(
    BuildContext context,
    ThemeData theme,
    VibeThemeExtension vibe,
    Map<String, dynamic> data,
    MascotDurum mascot,
    bool okunmamisVar,
  ) {
    final kullaniciAdi = data['kullaniciAdi'] ?? 'Vibe Kullanıcısı';
    final seviye = mascot.seviye;
    final odaAcik = MascotServis.odaAcik(seviye);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: odaAcik ? widget.onMascotTap : null,
            child: MascotGelisimCercevesi(
              progress: mascot.gelisimOrani,
              size: 90,
              strokeWidth: 3,
              innerPadding: 3,
              borderRadius: 18,
              backgroundColor: vibe.cardBorder,
              child: MascotLottieView(
                seviye: seviye,
                gorselDurum: mascot.gorselDurum,
                renk: mascot.renk,
                width: 75,
                height: 75,
                tamEkranAc: true,
              ),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        mascot.isim,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (seviye >= MascotServis.toklukAcilisSeviyesi) ...[
                      const SizedBox(width: 10),
                      VilRozeti(miktar: mascot.vil),
                    ],
                  ],
                ),
                Text(
                  '@$kullaniciAdi • Seviye $seviye',
                  style: TextStyle(
                    color: vibe.subtleText,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                MascotRuhHaliMetni(
                  mascot: mascot,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: VibeAppTheme.accent,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          if (YasHesapKontrol.maybeOf(context)?.mesajAcik == true)
          Stack(
            clipBehavior: Clip.none,
            children: [
              maestroButton(
                label: MaestroSemantics.mesajlar,
                onTap: () async {
                  final sohbet = WebSohbetKapsayici.maybeOf(context);
                  if (sohbet != null && webMasaustuMu(context)) {
                    sohbet.sohbetiAc();
                    return;
                  }
                  await tekSeferPush(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MessagesPage(),
                    ),
                    kokte: true,
                  );
                  widget.onMessagesReturn();
                  _dmDurumunuUygula(_sonSohbetDocs);
                },
                child: IconButton(
                  tooltip: "Mesajlar",
                  onPressed: () async {
                    final sohbet = WebSohbetKapsayici.maybeOf(context);
                    if (sohbet != null && webMasaustuMu(context)) {
                      sohbet.sohbetiAc();
                      return;
                    }
                    await tekSeferPush(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MessagesPage(),
                      ),
                      kokte: true,
                    );
                    widget.onMessagesReturn();
                    _dmDurumunuUygula(_sonSohbetDocs);
                  },
                  icon: Icon(
                    VibeIkon.mesajBos,
                    color: vibe.mutedText,
                    size: 22,
                  ),
                ),
              ),
              if (okunmamisVar)
                const Positioned(
                  right: 8,
                  top: 8,
                  child: SizedBox(
                    width: 8,
                    height: 8,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PariltiYok extends ScrollBehavior {
  const _PariltiYok();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return GlowingOverscrollIndicator(
      axisDirection: details.direction,
      color: Colors.transparent,
      child: child,
    );
  }
}
