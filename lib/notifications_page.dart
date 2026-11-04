// Sosyal bildirimler: beğeni, yorum, takip, bahsetme ve takip isteği aksiyonları
import 'package:myvibel/tek_sefer_navigasyon.dart';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:myvibel/app_theme.dart';
import 'package:myvibel/widgets/vibe_yukleniyor.dart';
import 'package:myvibel/error_messages.dart';
import 'package:myvibel/maestro_semantics.dart';
import 'package:myvibel/messages_page.dart';
import 'package:myvibel/sosyal/sosyal_core.dart';
import 'package:myvibel/sosyal_servis.dart';
import 'package:myvibel/utils/tarih_saat.dart';
import 'package:myvibel/vibe_snackbar.dart';
import 'package:myvibel/widgets/vibe_ikonlar.dart';
import 'package:myvibel/widgets/web_shell.dart';
import 'package:myvibel/yas_hesap_kontrol.dart';

// Bildirimler sayfası
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key, this.aktif = true});

  final bool aktif;

  @override

  State<NotificationsPage> createState() => NotificationsPageState();
}

// Bildirimler sayfası durumu
class NotificationsPageState extends State<NotificationsPage>
    with WidgetsBindingObserver {
  Set<String> _engelIdleri = {}; // engelli kullanıcı uid kümesi
  String? _temizlemeKategorisi; // gonderi | takip | bahsetme
  final Set<String> _kapaliKategoriler = {};
  final Set<String> _seciliBildirimIdleri = {};
  final Set<String> _gizliBildirimIdleri = {}; // optimistik silme
  final Set<String> _silinenGonderenler = {};
  final Set<String> _gonderenKontrolEdilen = {};
  final Set<String> _gonderenYukleniyor = {};
  final Set<String> _bekleyenGonderenKontrol = {};
  bool _gonderenKontrolPlanlandi = false;
  QuerySnapshot<Map<String, dynamic>>? _bildirimSnap;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _bildirimAbonelik;
  Object? _bildirimHatasi;
  final Map<String, String> _postOzetOnbellek = {};
  final Set<String> _postOzetIstendi = {};
  // Masaüstü web: sayfa açılınca okundu yapılanlar; bu ziyaret boyunca vurgulu kalır.
  final Set<String> _ziyaretteOkunanIdler = {};

  bool _okunduMu(QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
      doc.data()["okundu"] == true && !_ziyaretteOkunanIdler.contains(doc.id);

  void _gorulenleriOkunduYap(QuerySnapshot<Map<String, dynamic>> snap) {
    if (!widget.aktif || !webMasaustuMu(context)) return;
    final yeni = snap.docs.where((d) {
      final data = d.data();
      return data["okundu"] != true &&
          (data["tip"] ?? "") != "message" &&
          !_ziyaretteOkunanIdler.contains(d.id);
    }).toList();
    if (yeni.isEmpty) return;
    _ziyaretteOkunanIdler.addAll(yeni.map((d) => d.id));
    final batch = FirebaseFirestore.instance.batch();
    for (final d in yeni) {
      batch.update(d.reference, {"okundu": true});
    }
    unawaited(batch.commit().catchError((_) {
      _ziyaretteOkunanIdler.removeAll(yeni.map((d) => d.id));
    }));
  }

  // Widget ilk yüklendiğinde çalışır
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _engelleriYukle();
    _bildirimDinlemeyiAyarla();
  }

  @override
  void didUpdateWidget(covariant NotificationsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.aktif != widget.aktif) {
      if (!widget.aktif) {
        _ziyaretteOkunanIdler.clear();
      } else if (_bildirimSnap != null) {
        _gorulenleriOkunduYap(_bildirimSnap!);
      }
      _bildirimDinlemeyiAyarla();
    }
  }

  // Abonelik ve kontrolcüleri temizle
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _bildirimAbonelik?.cancel();
    super.dispose();
  }

  // Uygulama ön plana gelince engelleri yenile
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.aktif) {
      _engelleriYukle();
      _bildirimDinlemeyiAyarla();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _bildirimAbonelik?.cancel();
      _bildirimAbonelik = null;
    }
  }

  void _bildirimDinlemeyiAyarla() {
    if (!widget.aktif) {
      _bildirimAbonelik?.cancel();
      _bildirimAbonelik = null;
      return;
    }
    if (_bildirimAbonelik != null) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    _bildirimAbonelik = FirebaseFirestore.instance
        .collection("users")
        .doc(uid)
        .collection("notifications")
        .orderBy("createdAt", descending: true)
        .limit(80)
        .snapshots()
        .listen(
      (snap) {
        if (!mounted) return;
        _gorulenleriOkunduYap(snap);
        setState(() {
          _bildirimSnap = snap;
          _bildirimHatasi = null;
        });
      },
      onError: (e) {
        if (!mounted) return;
        setState(() => _bildirimHatasi = e);
      },
    );
  }

  // Engelleri yükle
  Future<void> _engelleriYukle() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final engelledigim = await SosyalServis.engellenenKullanicilariGetir(uid);
    final beniEngelleyen = await SosyalServis.beniEngelleyenKullanicilariGetir(uid);
    if (!mounted) return;
    setState(() {
      _engelIdleri = {...engelledigim, ...beniEngelleyen};
    });
  }

  void _gonderenleriDogrulaPlanla(Iterable<String> uids) {
    _bekleyenGonderenKontrol.addAll(
      uids.where(
        (uid) =>
            uid.isNotEmpty &&
            !_gonderenKontrolEdilen.contains(uid) &&
            !_gonderenYukleniyor.contains(uid),
      ),
    );
    if (_gonderenKontrolPlanlandi || _bekleyenGonderenKontrol.isEmpty) return;
    _gonderenKontrolPlanlandi = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _gonderenKontrolPlanlandi = false;
      if (!mounted || _bekleyenGonderenKontrol.isEmpty) return;
      final batch = _bekleyenGonderenKontrol.toList();
      _bekleyenGonderenKontrol.clear();
      await _gonderenleriDogrula(batch);
    });
  }

  Future<void> _gonderenleriDogrula(List<String> uids) async {
    _gonderenYukleniyor.addAll(uids);
    var degisti = false;
    for (final uid in uids) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection("users")
            .doc(uid)
            .get();
        if (!doc.exists) {
          _silinenGonderenler.add(uid);
          degisti = true;
        }
      } catch (_) {}
      _gonderenKontrolEdilen.add(uid);
      _gonderenYukleniyor.remove(uid);
    }
    if (mounted && degisti) setState(() {});
  }

  // Bildirimi okundu işaretle
  Future<void> _bildirimiOkunduIsaretle(String uid, String bildirimId) async {
    await SosyalServis.bildirimOkunduYap(uid, bildirimId);
  }

  // Kullanıcı adından sonraki cümle
  String _bildirimEki(Map<String, dynamic> data) {
    switch (data["tip"]) {
      case "like":
        return " gönderini beğendi";
      case "comment":
        return " gönderine yorum yaptı";
      case "comment_reply":
        return " yorumuna yanıt verdi";
      case "follow":
        return " seni takip etmeye başladı";
      case "follow_request":
        return " sana takip isteği gönderdi";
      case "follow_accepted":
        return " takip isteğini kabul etti";
      case "message":
        return " sana mesaj gönderdi";
      case "mention":
        return " senden bahsetti";
      case "maskot_yemek":
        return " Vibel'ine yemek verdi";
      default:
        final metin = (data["metin"] ?? "").toString();
        return metin.isNotEmpty ? " $metin" : "";
    }
  }

  bool _gonderiOnizlemeTipi(String tip) {
    return tip == "like" ||
        tip == "comment" ||
        tip == "comment_reply" ||
        tip == "mention";
  }

  String _postOnizleme(String postId, String kayitli) {
    final metin = kayitli.trim();
    if (metin.isNotEmpty) return metin;
    return _postOzetOnbellek[postId] ?? "";
  }

  void _postOzetiGetir(String postId) {
    if (postId.isEmpty ||
        _postOzetOnbellek.containsKey(postId) ||
        _postOzetIstendi.contains(postId)) {
      return;
    }
    _postOzetIstendi.add(postId);
    unawaited(() async {
      try {
        final snap =
            await SosyalCore.gonderiRef(postId).get();
        final ham = (snap.data()?["metin"] ?? "")
            .toString()
            .trim()
            .replaceAll(RegExp(r"\s+"), " ");
        final ozet = ham.length > 60 ? "${ham.substring(0, 60)}..." : ham;
        if (!mounted) return;
        setState(() => _postOzetOnbellek[postId] = ozet);
      } catch (_) {
        if (!mounted) return;
        setState(() => _postOzetOnbellek[postId] = "");
      }
    }());
  }

  // Bildirim tipine göre ikon
  IconData _bildirimIkonu(String tip) {
    // tip/durum seçimi
    switch (tip) {
      case "like":
        return VibeIkon.begeni;
      case "comment":
      case "comment_reply":
        return VibeIkon.yorum;
      case "follow":
      case "follow_accepted":
        return VibeIkon.takip;
      case "follow_request":
        return VibeIkon.takip;
      case "message":
        return VibeIkon.mail;
      case "mention":
        return VibeIkon.bahset;
      case "maskot_yemek":
        return VibeIkon.yemek;
      default:
        return VibeIkon.bildirim;
    }
  }

  // Gönderi bildirimi mi
  bool _gonderiBildirimiMi(String tip) {
    return tip == "like" || tip == "comment" || tip == "comment_reply";
  }

  // Takip bildirimi mi
  bool _takipBildirimiMi(String tip) {
    return tip == "follow" ||
        tip == "follow_request" ||
        tip == "follow_accepted" ||
        tip == "maskot_yemek";
  }

  // Bahsetme bildirimi mi
  bool _bahsetmeBildirimiMi(String tip) {
    return tip == "mention";
  }

  // Kategori temizleme modunu aç/kapat
  void _temizleModunuDegistir(String kategori) {
    setState(() {
      if (_temizlemeKategorisi == kategori) {
        _temizlemeKategorisi = null;
        _seciliBildirimIdleri.clear();
      } else {
        _kapaliKategoriler.remove(kategori);
        _temizlemeKategorisi = kategori;
        _seciliBildirimIdleri.clear();
      }
    });
  }

  void _kategoriAcKapa(String kategori) {
    setState(() {
      if (_kapaliKategoriler.contains(kategori)) {
        _kapaliKategoriler.remove(kategori);
      } else {
        _kapaliKategoriler.add(kategori);
        if (_temizlemeKategorisi == kategori) {
          _temizlemeKategorisi = null;
          _seciliBildirimIdleri.clear();
        }
      }
    });
  }

  // Kategorideki tüm bildirimleri seç / kaldır
  void _kategoriTumunuSec(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    bool sec,
  ) {
    setState(() {
      if (sec) {
        _seciliBildirimIdleri.addAll(docs.map((d) => d.id));
      } else {
        for (final doc in docs) {
          _seciliBildirimIdleri.remove(doc.id);
        }
      }
    });
  }

  bool? _kategoriSecimDurumu(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    if (docs.isEmpty) return false;
    final secili =
        docs.where((d) => _seciliBildirimIdleri.contains(d.id)).length;
    if (secili == 0) return false;
    if (secili == docs.length) return true;
    return null;
  }

  void _bildirimSeciminiDegistir(String bildirimId, bool sec) {
    setState(() {
      if (sec) {
        _seciliBildirimIdleri.add(bildirimId);
      } else {
        _seciliBildirimIdleri.remove(bildirimId);
      }
    });
  }

  void _bildirimleriAnindaGizle(Iterable<String> bildirimIdleri) {
    setState(() => _gizliBildirimIdleri.addAll(bildirimIdleri));
  }

  void _bildirimGizlemeyiGeriAl(Iterable<String> bildirimIdleri) {
    setState(() => _gizliBildirimIdleri.removeAll(bildirimIdleri));
  }

  Future<void> _bildirimSilArkaPlan(String uid, String bildirimId) async {
    _bildirimleriAnindaGizle([bildirimId]);
    try {
      await SosyalServis.bildirimSil(uid, bildirimId);
    } catch (e) {
      if (!mounted) return;
      _bildirimGizlemeyiGeriAl([bildirimId]);
      _mesajGoster(
        internetAwareErrorMessage(
          error: e,
          fallback: 'Bildirim silinemedi.',
        ),
      );
    }
  }

  Future<void> _secilenleriSil(String uid) async {
    if (_seciliBildirimIdleri.isEmpty) return;

    final silinecek = Set<String>.from(_seciliBildirimIdleri);
    setState(() {
      _gizliBildirimIdleri.addAll(silinecek);
      _seciliBildirimIdleri.clear();
      _temizlemeKategorisi = null;
    });

    unawaited(_topluSilmeArkaPlan(uid, silinecek));
  }

  Future<void> _topluSilmeArkaPlan(String uid, Set<String> silinecek) async {
    try {
      await SosyalServis.bildirimleriSil(uid, silinecek);
    } catch (e) {
      if (!mounted) return;
      _bildirimGizlemeyiGeriAl(silinecek);
      _mesajGoster(
        internetAwareErrorMessage(
          error: e,
          fallback: 'Bildirimler silinemedi.',
        ),
      );
    }
  }

  // Bildirim bölüm başlığı
  Widget _bolumBasligi({
    required BuildContext context,
    required String kategori,
    required String baslik,
    required String aciklama,
    required bool ilkBolum,
    required bool acik,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    required String uid,
  }) {
    final theme = Theme.of(context);
    final vibe = context.vibe;
    final temizlemeModu = _temizlemeKategorisi == kategori;
    final kategoriSecili = docs
        .where((d) => _seciliBildirimIdleri.contains(d.id))
        .length;
    final okunmamis = docs.where((d) => !_okunduMu(d)).length;

    return Padding(
      padding: EdgeInsets.fromLTRB(4, ilkBolum ? 4 : 22, 4, acik ? 10 : 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _kategoriAcKapa(kategori),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 6,
                        horizontal: 2,
                      ),
                      child: Row(
                        children: [
                          AnimatedRotation(
                            turns: acik ? 0.25 : 0,
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOutCubic,
                            child: Icon(
                              Icons.chevron_right_rounded,
                              color: vibe.mutedText,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Flexible(
                            child: Text(
                              baslik,
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${docs.length}',
                            style: TextStyle(
                              color: vibe.mutedText,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (okunmamis > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$okunmamis',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (temizlemeModu) ...[
                SizedBox(
                  height: 28,
                  width: 28,
                  child: Checkbox(
                    value: _kategoriSecimDurumu(docs),
                    tristate: true,
                    activeColor: theme.colorScheme.primary,
                    onChanged: (_) {
                      final hepsiSecili = _kategoriSecimDurumu(docs) == true;
                      _kategoriTumunuSec(docs, !hepsiSecili);
                    },
                  ),
                ),
                if (kategoriSecili > 0)
                  TextButton(
                    onPressed: () => _secilenleriSil(uid),
                    child: Text('Sil ($kategoriSecili)'),
                  ),
              ],
              TextButton(
                onPressed: () => _temizleModunuDegistir(kategori),
                child: Text(temizlemeModu ? 'İptal' : 'Temizle'),
              ),
            ],
          ),
          if (acik) ...[
            const SizedBox(height: 4),
            Text(
              aciklama,
              style: TextStyle(
                color: vibe.mutedText,
                fontSize: 13,
                height: 1.3,
              ),
            ),
            if (temizlemeModu)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Silmek istediklerini seç. Tümünü seçmek için kutucuğa dokun.',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  // Tek bildirim kartı
  Widget _bildirimKarti({
    required BuildContext context,
    required User user,
    required QueryDocumentSnapshot<Map<String, dynamic>> doc,
    required bool secimModu,
    required bool secili,
    required ValueChanged<bool> onSecimDegisti,
  }) {
    final theme = Theme.of(context);
    final vibe = context.vibe;
    final data = doc.data();
    final tip = data["tip"] ?? "";
    final okundu = _okunduMu(doc);
    final gonderenUid = data["gonderenUid"] ?? "";
    final postId = data["postId"]?.toString() ?? "";
    final chatId = data["chatId"]?.toString() ?? "";
    final postMetin = data["postMetin"]?.toString() ?? "";
    final yorumMetin = data["yorumMetin"]?.toString().trim() ?? "";
    final gonderiOnizleme = _postOnizleme(postId, postMetin);
    if (!secimModu &&
        _gonderiOnizlemeTipi(tip) &&
        postMetin.trim().isEmpty &&
        postId.isNotEmpty) {
      _postOzetiGetir(postId);
    }

    final kartIcerigi = Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: secimModu && secili
            ? theme.colorScheme.primary.withOpacity(vibe.isDark ? 0.18 : 0.12)
            : okundu
                ? vibe.cardColor
                : theme.colorScheme.primary.withOpacity(
                    vibe.isDark ? 0.12 : 0.08,
                  ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: secimModu && secili
              ? theme.colorScheme.primary
              : okundu
                  ? vibe.cardBorder
                  : theme.colorScheme.primary.withOpacity(0.55),
        ),
        boxShadow: vibe.isDark
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (secimModu)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, top: 6),
                    child: Checkbox(
                      value: secili,
                      activeColor: theme.colorScheme.primary,
                      onChanged: (v) => onSecimDegisti(v == true),
                    ),
                  ),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: secimModu ? () => onSecimDegisti(!secili) : null,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 10, 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            _bildirimIkonu(tip),
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _BildirimBaslik(
                              ad: (data["gonderenKullaniciAdi"] ??
                                      "Bir kullanıcı")
                                  .toString(),
                              ek: _bildirimEki(data),
                              kalin: !okundu,
                              yaziRengi: theme.colorScheme.onSurface,
                              adRengi: theme.colorScheme.primary,
                              onAd: secimModu || gonderenUid.isEmpty
                                  ? null
                                  : () => _profilAc(
                                        gonderenUid: gonderenUid,
                                        uid: user.uid,
                                        bildirimId: doc.id,
                                      ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (!secimModu &&
                    (tip == "like" || tip == "comment" || tip == "mention"))
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      color: vibe.mutedText,
                      size: 20,
                    ),
                    onPressed: () =>
                        unawaited(_bildirimSilArkaPlan(user.uid, doc.id)),
                  ),
              ],
            ),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: secimModu
                ? () => onSecimDegisti(!secili)
                : tip == "mention"
                    ? () {
                        if (postId.isNotEmpty) {
                          _gonderiDetayinaGit(
                            postId: postId,
                            currentUserId: user.uid,
                            uid: user.uid,
                            bildirimId: doc.id,
                          );
                        } else if (chatId.isNotEmpty) {
                          _sohbeteGit(
                            chatId: chatId,
                            gonderenUid: gonderenUid,
                            uid: user.uid,
                            bildirimId: doc.id,
                          );
                        } else {
                          _profilAc(
                            gonderenUid: gonderenUid,
                            uid: user.uid,
                            bildirimId: doc.id,
                          );
                        }
                      }
                    : (tip == "like" ||
                            tip == "comment" ||
                            tip == "comment_reply")
                        ? () => _gonderiDetayinaGit(
                              postId: postId,
                              currentUserId: user.uid,
                              uid: user.uid,
                              bildirimId: doc.id,
                            )
                        : tip == "message"
                            ? () {
                                if (YasHesapKontrol.maybeOf(context)
                                        ?.mesajAcik ==
                                    false) {
                                  return;
                                }
                                _sohbeteGit(
                                  chatId: chatId,
                                  gonderenUid: gonderenUid,
                                  uid: user.uid,
                                  bildirimId: doc.id,
                                );
                              }
                            : (tip == "follow" ||
                                    tip == "follow_accepted" ||
                                    tip == "follow_request" ||
                                    tip == "maskot_yemek")
                                ? () => _profilAc(
                                      gonderenUid: gonderenUid,
                                      uid: user.uid,
                                      bildirimId: doc.id,
                                    )
                                : null,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if ((tip == "comment" || tip == "comment_reply") &&
                      yorumMetin.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2, bottom: 2),
                      child: Text(
                        '"$yorumMetin"',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: vibe.mutedText,
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  if (gonderiOnizleme.isNotEmpty && _gonderiOnizlemeTipi(tip))
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Material(
                        color: vibe.inputFill,
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: secimModu || postId.isEmpty
                              ? null
                              : () => _gonderiDetayinaGit(
                                    postId: postId,
                                    currentUserId: user.uid,
                                    uid: user.uid,
                                    bildirimId: doc.id,
                                  ),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: vibe.cardBorder),
                            ),
                            child: Text(
                              gonderiOnizleme,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    tarihSaatYaz(data["createdAt"]),
                    style: TextStyle(
                      color: vibe.faintText,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (tip == "follow_request" &&
              gonderenUid.isNotEmpty &&
              !secimModu)
            _TakipIstegiAksiyonlari(
              hedefUid: user.uid,
              istekciUid: gonderenUid,
              bildirimId: doc.id,
              mesajGoster: _mesajGoster,
              bildirimiOkunduIsaretle: (id) =>
                  _bildirimiOkunduIsaretle(user.uid, id),
            ),
        ],
      ),
    );

    return kartIcerigi;
  }

  // Bildirimleri bölümlere ayır
  List<Widget> _bildirimListesiOlustur({
    required BuildContext context,
    required User user,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> filtreli,
  }) {
    final gonderiBildirimleri = filtreli
        .where((d) => _gonderiBildirimiMi((d.data()["tip"] ?? "").toString()))
        .toList();
    final takipBildirimleri = filtreli
        .where((d) => _takipBildirimiMi((d.data()["tip"] ?? "").toString()))
        .toList();
    final bahsetmeBildirimleri = filtreli
        .where((d) => _bahsetmeBildirimiMi((d.data()["tip"] ?? "").toString()))
        .toList();

    final bolumler = <({
      String kategori,
      String baslik,
      String aciklama,
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    })>[
      (
        kategori: 'gonderi',
        baslik: "Gönderi",
        aciklama: "Paylaştığın gönderiye yapılan etkileşimler",
        docs: gonderiBildirimleri,
      ),
      (
        kategori: 'takip',
        baslik: "Takip",
        aciklama: "Takip istekleri ve takip isteği kabul bildirimleri",
        docs: takipBildirimleri,
      ),
      (
        kategori: 'bahsetme',
        baslik: "Bahsetmeler",
        aciklama: "Senden bahsedilen gönderiler ve yorumlar",
        docs: bahsetmeBildirimleri,
      ),
    ];

    final ogeler = <Widget>[];
    var ilkBolum = true;

    for (final bolum in bolumler) {
      if (bolum.docs.isEmpty) continue;

      final secimModu = _temizlemeKategorisi == bolum.kategori;
      final acik = !_kapaliKategoriler.contains(bolum.kategori);

      ogeler.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _bolumBasligi(
              context: context,
              kategori: bolum.kategori,
              baslik: bolum.baslik,
              aciklama: bolum.aciklama,
              ilkBolum: ilkBolum,
              acik: acik,
              docs: bolum.docs,
              uid: user.uid,
            ),
            ClipRect(
              child: AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: acik
                    ? LayoutBuilder(
                        builder: (context, constraints) {
                          final ikiKolon = webMasaustuMu(context) &&
                              constraints.maxWidth >= 640;
                          final kartlar = [
                            for (final doc in bolum.docs)
                              _bildirimKarti(
                                context: context,
                                user: user,
                                doc: doc,
                                secimModu: secimModu,
                                secili:
                                    _seciliBildirimIdleri.contains(doc.id),
                                onSecimDegisti: (sec) =>
                                    _bildirimSeciminiDegistir(doc.id, sec),
                              ),
                          ];
                          if (!ikiKolon) {
                            return Column(children: kartlar);
                          }
                          final w = (constraints.maxWidth - 12) / 2;
                          return Wrap(
                            spacing: 12,
                            runSpacing: 4,
                            children: [
                              for (final kart in kartlar)
                                SizedBox(width: w, child: kart),
                            ],
                          );
                        },
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ),
          ],
        ),
      );
      ilkBolum = false;
    }

    return ogeler;
  }

  // Bilgi snackbar göster
  void _mesajGoster(String mesaj, {bool basarili = false}) {
    vibeSnackbarGoster(
      context,
      mesaj,
      tip: basarili ? VibeMesajTipi.basari : VibeMesajTipi.hata,
    );
  }

  // Gönderi detay sayfasına git
  Future<void> _gonderiDetayinaGit({
    required String postId,
    required String currentUserId,
    required String uid,
    required String bildirimId,
  }) async {
    if (postId.isEmpty) {
      _mesajGoster("Bu bildirim için gönderi bulunamadı.");
      return;
    }
    unawaited(_bildirimiOkunduIsaretle(uid, bildirimId));
    if (!mounted) return;
    await gonderiDetayiniAc(
      context,
      postId: postId,
      currentUserId: currentUserId,
    );
  }

  // Sohbet ekranına git
  Future<void> _sohbeteGit({
    required String chatId,
    required String gonderenUid,
    required String uid,
    required String bildirimId,
  }) async {
    if (chatId.isEmpty || gonderenUid.isEmpty) {
      _mesajGoster("Sohbet bulunamadı.");
      return;
    }
    final bilet = tekSeferGecisAl();
    if (bilet == null) return;

    await _bildirimiOkunduIsaretle(uid, bildirimId);
    final gonderen = await FirebaseFirestore.instance
        .collection("users")
        .doc(gonderenUid)
        .get();
    final data = gonderen.data() ?? {};

    if (!mounted) {
      tekSeferGecisIptal(bilet);
      return;
    }
    final sohbet = WebSohbetKapsayici.maybeOf(context);
    if (sohbet != null && webMasaustuMu(context)) {
      sohbet.sohbetiAc(
        WebSohbetHedef(
          chatId: chatId,
          otherUid: gonderenUid,
          otherDisplayName: (data["adSoyad"] ?? "Vibe Kullanıcısı").toString(),
          otherUsername: (data["kullaniciAdi"] ?? "kullanici").toString(),
          otherPhotoUrl: (data["photoUrl"] ?? "").toString(),
          otherAvatarKey: (data["avatarKey"] ?? "").toString(),
        ),
      );
      tekSeferGecisBirak(bilet);
      return;
    }
    final acilis = Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatPage(
          chatId: chatId,
          otherUid: gonderenUid,
          otherDisplayName: (data["adSoyad"] ?? "Vibe Kullanıcısı").toString(),
          otherUsername: (data["kullaniciAdi"] ?? "kullanici").toString(),
          otherPhotoUrl: (data["photoUrl"] ?? "").toString(),
          otherAvatarKey: (data["avatarKey"] ?? "").toString(),
        ),
      ),
    );
    tekSeferGecisBirak(bilet);
    await acilis;
  }

  // Kullanıcı profiline git
  Future<void> _profilAc({
    required String gonderenUid,
    required String uid,
    required String bildirimId,
  }) async {
    if (gonderenUid.isEmpty) return;
    unawaited(_bildirimiOkunduIsaretle(uid, bildirimId));
    if (!mounted) return;
    await profiliAc(context, gonderenUid);
  }

  Widget _bildirimListesiGovdesi({
    required BuildContext context,
    required User user,
    required ThemeData theme,
    required VibeThemeExtension vibe,
  }) {
    if (_bildirimHatasi != null && _bildirimSnap == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            internetAwareErrorMessage(
              error: _bildirimHatasi ?? "Bildirimler yüklenemedi.",
              fallback: "Bildirimler yüklenemedi.",
            ),
            textAlign: TextAlign.center,
            style: TextStyle(color: vibe.subtleText),
          ),
        ),
      );
    }

    if (_bildirimSnap == null) {
      return Center(
        child: VibeYukleniyor(renk: theme.colorScheme.primary),
      );
    }

    final docs = _bildirimSnap!.docs;
    final gonderenUids = docs
        .map((d) => (d.data()["gonderenUid"] ?? "").toString())
        .where((uid) => uid.isNotEmpty)
        .toSet();
    _gonderenleriDogrulaPlanla(gonderenUids);

    final filtreli = docs
        .where((d) {
          if (_gizliBildirimIdleri.contains(d.id)) return false;
          final data = d.data();
          final tip = (data["tip"] ?? "").toString();
          if (tip == "message") return false;
          final gonderenUid = (data["gonderenUid"] ?? "").toString();
          if (_silinenGonderenler.contains(gonderenUid)) {
            return false;
          }
          return !_engelIdleri.contains(gonderenUid);
        })
        .toList();

    if (filtreli.isEmpty) {
      return Center(
        child: Text(
          "Henüz bildirim yok.",
          style: TextStyle(color: vibe.mutedText),
        ),
      );
    }

    final listeOgeleri = _bildirimListesiOlustur(
      context: context,
      user: user,
      filtreli: filtreli,
    );

    return ListView(
      padding: EdgeInsets.fromLTRB(
        webMasaustuMu(context) ? 24 : 16,
        8,
        webMasaustuMu(context) ? 24 : 16,
        24,
      ),
      children: listeOgeleri,
    );
  }

  // Arayüzü oluştur
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);
    final vibe = context.vibe;

    if (user == null) {
      return SafeArea(
        child: Center(
          child: Text(
            "Bildirimler için giriş yapmalısın.",
            style: TextStyle(color: vibe.subtleText),
          ),
        ),
      );
    }

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              webMasaustuMu(context) ? 28 : 20,
              12,
              webMasaustuMu(context) ? 28 : 20,
              8,
            ),
            child: Row(
              children: [
                Expanded(
            child: Text(
              "Bildirimler",
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: webMasaustuMu(context) ? 30 : 26,
                fontWeight: FontWeight.bold,
              ),
                  ),
                ),
                Semantics(
                  label: MaestroSemantics.tumunuOkundu,
                  button: true,
                  child: TextButton(
                    onPressed: () => SosyalServis.tumBildirimleriOkunduYap(user.uid),
                    child: const Text("Tümünü okundu işaretle"),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _bildirimListesiGovdesi(
              context: context,
              user: user,
              theme: theme,
              vibe: vibe,
            ),
          ),
                              ],
                            ),
    );
  }
}

// Takip isteği kabul/red butonları
class _TakipIstegiAksiyonlari extends StatefulWidget {
  const _TakipIstegiAksiyonlari({
    required this.hedefUid,
    required this.istekciUid,
    required this.bildirimId,
    required this.mesajGoster,
    required this.bildirimiOkunduIsaretle,
  });

  final String hedefUid; // hedef kullanıcı uid
  final String istekciUid; // istek gönderen uid
  final String bildirimId; // bildirim kimliği
  final void Function(String mesaj, {bool basarili}) mesajGoster;
  final Future<void> Function(String bildirimId) bildirimiOkunduIsaretle;

  @override

  State<_TakipIstegiAksiyonlari> createState() =>
      _TakipIstegiAksiyonlariState();
}

// Takip isteği aksiyon durumu
class _TakipIstegiAksiyonlariState extends State<_TakipIstegiAksiyonlari> {
  bool _islemYapiliyor = false; // takip isteği işlemi sürüyor mu

  // Bildirimi okundu yap ve sil
  Future<void> _bildirimiTemizle() async {
    await widget.bildirimiOkunduIsaretle(widget.bildirimId);
    await SosyalServis.bildirimSil(widget.hedefUid, widget.bildirimId);
  }

  // Bildirim temizliği; servis zaten silebilir — başarısızlık ana işlemi bozmaz
  Future<void> _bildirimiTemizleGuvenli() async {
    try {
      await _bildirimiTemizle();
    } catch (e) {
      debugPrint("takip isteği bildirim temizliği atlandı: $e");
    }
  }

  // Takip isteğini reddet
  Future<void> _reddet() async {
    if (_islemYapiliyor) return;
    setState(() => _islemYapiliyor = true);
   
    // hata yakalamalı blok
    try {
      final sonuc =
          await SosyalServis.takipIstegiRed(widget.istekciUid);
      if (mounted) {
        widget.mesajGoster(sonuc.mesaj, basarili: sonuc.basarili);
      }
      if (sonuc.bildirimiTemizle) {
        await _bildirimiTemizleGuvenli();
      }
    // hata yakala
    } catch (e) {
      if (mounted) {
        widget.mesajGoster(
          internetAwareErrorMessage(
            error: e,
            fallback: "Takip isteği reddedilemedi.",
          ),
        );
      }
    // temizlik
    } finally {
      if (mounted) setState(() => _islemYapiliyor = false);
    }
  }

  // Takip isteğini kabul et
  Future<void> _kabulEt() async {
    if (_islemYapiliyor) return;
    setState(() => _islemYapiliyor = true);
   
    // hata yakalamalı blok
    try {
      final sonuc =
          await SosyalServis.takipIstegiKabul(widget.istekciUid);
      if (mounted) {
        widget.mesajGoster(sonuc.mesaj, basarili: sonuc.basarili);
      }
      if (sonuc.bildirimiTemizle) {
        await _bildirimiTemizleGuvenli();
      }
    // hata yakala
    } catch (e) {
      if (mounted) {
        widget.mesajGoster(
          internetAwareErrorMessage(
            error: e,
            fallback: "Takip isteği kabul edilemedi.",
          ),
        );
      }
    // temizlik
    } finally {
      if (mounted) setState(() => _islemYapiliyor = false);
    }
  }

  // Arayüzü oluştur
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vibe = context.vibe;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection("users")
          .doc(widget.hedefUid)
          .collection("followRequests")
          .doc(widget.istekciUid)
          .snapshots(),
      builder: (context, snapshot) {
        final istekVar = snapshot.data?.exists == true;

        if (!istekVar) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              "Bu istek artık geçerli değil. Kabul etmek için karşı tarafın yeniden istek göndermesi gerekir.",
              style: TextStyle(color: vibe.mutedText, fontSize: 12),
                                  ),
                                );
                              }

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                  onPressed: _islemYapiliyor ? null : _reddet,
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: vibe.subtleText,
                                        side: BorderSide(color: vibe.cardBorder),
                                      ),
                                      child: const Text("Reddet"),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: ElevatedButton(
                  onPressed: _islemYapiliyor ? null : _kabulEt,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: vibe.primaryButton,
                                        foregroundColor: Colors.white,
                                      ),
                  child: _islemYapiliyor
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.colorScheme.onPrimary,
                          ),
                        )
                      : const Text("Kabul Et"),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                );
  }
}

class _BildirimBaslik extends StatelessWidget {
  const _BildirimBaslik({
    required this.ad,
    required this.ek,
    required this.kalin,
    required this.yaziRengi,
    required this.adRengi,
    required this.onAd,
  });

  final String ad;
  final String ek;
  final bool kalin;
  final Color yaziRengi;
  final Color adRengi;
  final VoidCallback? onAd;

  @override
  Widget build(BuildContext context) {
    final agirlik = kalin ? FontWeight.bold : FontWeight.normal;
    final adStili = TextStyle(
      color: adRengi,
      fontWeight: FontWeight.w700,
      fontSize: 14,
    );
    return Text.rich(
      TextSpan(
        style: TextStyle(
          color: yaziRengi,
          fontWeight: agirlik,
          fontSize: 14,
        ),
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: GestureDetector(
              onTap: onAd,
              behavior: HitTestBehavior.opaque,
              child: Text('@$ad', style: adStili),
            ),
          ),
          TextSpan(text: ek),
        ],
      ),
    );
  }
}
