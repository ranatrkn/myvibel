// Ana feed içeriği: takip/keşfet sekmeleri, sayfalama ve maskot üst bar
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibe_life/alinti_gonderi.dart';
import 'package:vibe_life/app_theme.dart';
import 'package:vibe_life/error_messages.dart';
import 'package:vibe_life/messages_page.dart';
import 'package:vibe_life/maskot_page.dart';
import 'package:vibe_life/maskot_servis.dart';
import 'package:vibe_life/sosyal_servis.dart';
import 'package:vibe_life/widgets/post_card.dart';
import 'package:vibe_life/widgets/maskot_gelisim_cercevesi.dart';
import 'package:vibe_life/widgets/maskot_lottie_view.dart';

// Feed sekmesi türleri
enum FeedSekmesi { takip, kesfet }

// Feed ana içerik widget'ı
class FeedPageContent extends StatefulWidget {
  final VoidCallback onKendiProfilineGit;
  final ValueChanged<AlintiGonderiBaglam>? onAlintiYap;

  const FeedPageContent({
    super.key,
    required this.onKendiProfilineGit,
    this.onAlintiYap,
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
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> _gorunenPostlar =
      []; // Ekranda gösterilen
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> _bekleyenPostlar =
      []; // Sıralama kuyruğu
  DocumentSnapshot<Map<String, dynamic>>?
      _sonPostBelgesi; // Keşfet sayfalama imleci
  static const int _sayfaBoyutu = 10; // Her yüklemede gösterilecek post sayısı
  static const int _partiBoyutu = 50; // Firestore'dan çekilen parti boyutu
  bool _ilkYukleme = true; // İlk yükleme devam ediyor mu
  bool _yukleniyorDahaFazla = false; // Sonsuz kaydırma yükleniyor mu
  bool _dahaFazlaVar = true; // Daha fazla post var mı
  bool _takipHazir = false; // Takip listesi yüklendi mi
  bool _engellerHazir = false; // Engel listeleri yüklendi mi
  bool _kendiPostlarYuklendi = false; // Kendi postları eklendi mi
  final Map<String, DocumentSnapshot<Map<String, dynamic>>> _takipChunkImlec =
      {}; // Takip feed whereIn imleçleri
  String? _yuklemeHatasi; // Hata mesajı
  bool _feedYenilemeSuruyor = false; // Yenileme kilidi
  Set<String> _begenilenPostIdler = {}; // Beğeni durumu önbelleği
  bool _begenilenPostlarYuklendi = false;
  static const int _whereInChunk = 10;
  int _kesfetBosPartiSayaci =
      0; // Keşfet: filtre sonrası boş gelen ardışık partiler
  static const int _maxKesfetBosParti = 12;
  DateTime? _sonArkaPlanYenilemesi;

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
    _sosyalListeleriYukle();
    SharedPreferences.getInstance().then((prefs) {
      if (mounted) setState(() => _prefs = prefs);
    });
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

  // Takip ve engel listelerini tek seferde yükle (canlı dinleyici yok)
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

    try {
      final firestore = FirebaseFirestore.instance;
      final sonuclar = await Future.wait([
        firestore
            .collection("users")
            .doc(user.uid)
            .collection("following")
            .limit(500)
            .get(),
        firestore
            .collection("users")
            .doc(user.uid)
            .collection("blocked")
            .limit(200)
            .get(),
        firestore
            .collection("users")
            .doc(user.uid)
            .collection("blockedBy")
            .limit(200)
            .get(),
      ]);

      if (!mounted) return;
      setState(() {
        _takipEdilenIdler = sonuclar[0].docs.map((d) => d.id).toSet();
        _engelledigimIdler = sonuclar[1].docs.map((d) => d.id).toSet();
        _beniEngelleyenIdler = sonuclar[2].docs.map((d) => d.id).toSet();
        _takipHazir = true;
        _engellerHazir = true;
      });
      if (feedBaslat) _feedYuklemeyeHazirMi();
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

  Future<void> _begenilenPostlariOnbellegeAl(String uid) async {
    if (_begenilenPostlarYuklendi) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection("users")
          .doc(uid)
          .collection("likedPosts")
          .limit(500)
          .get();
      _begenilenPostIdler = snap.docs.map((d) => d.id).toSet();
      _begenilenPostlarYuklendi = true;
    } catch (e) {
      debugPrint("begeni onbellek hatasi: $e");
    }
  }

  // Alta yaklaşınca daha fazla post yükle
  void _kaydirmaDinleyici() {
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
  Future<void> _feediYenile() async {
    if (_feedYenilemeSuruyor) return;
    _feedYenilemeSuruyor = true;
    try {
      await _sosyalListeleriYukle(feedBaslat: false);
      if (!mounted) return;
      setState(() {
        _gorunenPostlar.clear();
        _bekleyenPostlar.clear();
        _sonPostBelgesi = null;
        _ilkYukleme = true;
        _yukleniyorDahaFazla = false;
        _dahaFazlaVar = true;
        _kendiPostlarYuklendi = false;
        _takipChunkImlec.clear();
        _yuklemeHatasi = null;
        _kesfetBosPartiSayaci = 0;
        _begenilenPostIdler = {};
        _begenilenPostlarYuklendi = false;
      });
    } finally {
      _feedYenilemeSuruyor = false;
      if (mounted) {
        _feedYuklemeyeHazirMi();
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
      final saat = DateTime.now().difference(createdAt.toDate()).inHours;
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
      (a, b) => _feedPuani(b.data()).compareTo(_feedPuani(a.data())),
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
      // İndeks yoksa sırasız sorgu dene
      snap = await FirebaseFirestore.instance
          .collection("posts")
          .where("userId", isEqualTo: uid)
          .limit(30)
          .get();
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
      await _begenilenPostlariOnbellegeAl(user.uid);
      final gosterilenIdler = _gorunenPostlar.map((d) => d.id).toSet();

      // Takip sekmesinde önce kendi postlarını ekle
      if (_aktifSekme == FeedSekmesi.takip && !_kendiPostlarYuklendi) {
        await _kendiPostlarimiEkle(user.uid, gosterilenIdler);
        _kendiPostlarYuklendi = true;
        _bekleyenPostlariSirala();
      }

      // Kuyruk dolana kadar parti yükle
      while (_bekleyenPostlar.length < _sayfaBoyutu && _dahaFazlaVar) {
        final oncekiSayi = _bekleyenPostlar.length;
        if (_aktifSekme == FeedSekmesi.takip) {
          final sonuc =
              await _takipPostPartisiYukle(user.uid, gosterilenIdler);
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
          final eklenen =
              await _kesfetPostPartisiYukle(user.uid, gosterilenIdler);
          if (eklenen == 0) {
            if (!_dahaFazlaVar) {
              break;
            }
            // Parti geldi ama engel filtresi hepsini eledi; sonraki sayfayı dene.
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

      if (_bekleyenPostlar.isEmpty && !_dahaFazlaVar) {
        if (!mounted) return;
        setState(() {
          _ilkYukleme = false;
          _yukleniyorDahaFazla = false;
        });
        return;
      }

      // Sayfa boyutu kadarını görünür listeye taşı
      final eklenecek = _bekleyenPostlar.take(_sayfaBoyutu).toList();
      _bekleyenPostlar.removeRange(0, eklenecek.length);

      if (!mounted) return;
      setState(() {
        _gorunenPostlar.addAll(eklenecek);
        _ilkYukleme = false;
        _yukleniyorDahaFazla = false;
        _dahaFazlaVar = _bekleyenPostlar.isNotEmpty || _dahaFazlaVar;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _yuklemeHatasi = internetAwareErrorMessage(
          error: e,
          fallback: "Gönderiler yüklenemedi.",
        );
        _ilkYukleme = false;
        _yukleniyorDahaFazla = false;
      });
    }
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

    return SafeArea(
      child: Column(
        children: [
          // Maskot ve kullanıcı üst barı (tek seferlik yükleme)
          _FeedUstBar(
            uid: user.uid,
            prefs: _prefs,
            onMascotTap: () {
              Navigator.push(
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
                    child: CircularProgressIndicator(
                      color: theme.colorScheme.primary,
                    ),
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
                        : RefreshIndicator(
                            onRefresh: _feediYenile,
                            child: ListView.builder(
                              controller: _scrollController,
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding:
                                  const EdgeInsets.only(top: 5, bottom: 20),
                              itemCount: _gorunenPostlar.length +
                                  (_dahaFazlaVar ? 1 : 0),
                              itemBuilder: (context, index) {
                                // Alta kaydırma yükleniyor göstergesi
                                if (index >= _gorunenPostlar.length) {
                                  return const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 16),
                                    child: Center(
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    ),
                                  );
                                }

                                final postId = _gorunenPostlar[index].id;
                                final post = _gorunenPostlar[index].data();

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
                                  ),
                                  baslangicBegeniSayisi:
                                      post["begeniSayisi"] ?? 0,
                                  baslangicYorumSayisi:
                                      post["yorumSayisi"] ?? 0,
                                  baslangicBegenildi:
                                      _begenilenPostIdler.contains(postId),
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
        ],
      ),
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
    return InkWell(
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
    );
  }
}

// Feed üst barı: tek seferlik kullanıcı verisi + sınırlı DM kontrolü
class _FeedUstBar extends StatefulWidget {
  const _FeedUstBar({
    required this.uid,
    required this.prefs,
    required this.onMascotTap,
    required this.onMessagesReturn,
  });

  final String uid;
  final SharedPreferences? prefs;
  final VoidCallback onMascotTap;
  final VoidCallback onMessagesReturn;

  @override
  State<_FeedUstBar> createState() => _FeedUstBarState();
}

class _FeedUstBarState extends State<_FeedUstBar> {
  int _intDeger(dynamic value, int varsayilan) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return varsayilan;
  }

  bool _dmOkunmamisVar(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final prefs = widget.prefs;
    if (prefs == null) return false;
    for (final doc in docs) {
      final data = doc.data();
      final hiddenKey = "dm_hidden_chat_${widget.uid}_${doc.id}";
      final hiddenAtMs = prefs.getInt(hiddenKey) ?? 0;
      if (SosyalServis.sohbetGizliMi(
        uid: widget.uid,
        chat: data,
        localHiddenAtMs: hiddenAtMs,
      )) {
        continue;
      }
      final localReadMs = prefs.getInt("dm_last_read_${widget.uid}_${doc.id}");
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

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: SizedBox(
              height: 75,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          );
        }

        final data = snapshot.data!.data() ?? {};
        final mascot = MascotServis.tryParse(data['robot']);
        if (mascot == null) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: SizedBox(
              height: 75,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          );
        }
        return _ustBarIcerik(context, theme, vibe, data, mascot);
      },
    );
  }

  Widget _ustBarIcerik(
    BuildContext context,
    ThemeData theme,
    VibeThemeExtension vibe,
    Map<String, dynamic> data,
    MascotDurum mascot,
  ) {
    final kullaniciAdi = data['kullaniciAdi'] ?? 'Vibe Kullanıcısı';
    final puan = _intDeger(data['puan'], 0);
    final seviye = mascot.seviye;
    final odaAcik = MascotServis.odaAcik(seviye);
    final ruhHali = odaAcik
        ? MascotServis.ruhHaliMesaji(mascot)
        : '${MascotServis.odaAcilisSeviyesi}. seviyede maskot sistemi açılır.';

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
              backgroundFill: vibe.inputFill,
              backgroundColor: vibe.cardBorder,
              child: MascotLottieView(
                seviye: seviye,
                gorselDurum: mascot.gorselDurum,
                width: 75,
                height: 75,
                repeat: false,
                tamEkranAc: true,
              ),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mascot.isim,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '@$kullaniciAdi • $puan puan • Seviye $seviye',
                  style: TextStyle(
                    color: vibe.subtleText,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  ruhHali,
                  maxLines: 1,
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
          FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
            future: SosyalServis.sonSohbetleriGetir(widget.uid),
            builder: (context, snap) {
              final docs = snap.data?.docs ?? [];
              final okunmamisVar = _dmOkunmamisVar(docs);
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MessagesPage(),
                        ),
                      );
                      widget.onMessagesReturn();
                    },
                    icon: Icon(
                      Icons.chat_bubble_outline,
                      color: vibe.mutedText,
                      size: 22,
                    ),
                    tooltip: "Mesajlar",
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
              );
            },
          ),
        ],
      ),
    );
  }
}
