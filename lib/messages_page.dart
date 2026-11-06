// DM sohbet listesi, yeni sohbet başlatma ve birebir mesajlaşma ekranı
import 'dart:async';

import 'package:myvibel/tek_sefer_navigasyon.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myvibel/app_theme.dart';
import 'package:myvibel/widgets/vibe_yukleniyor.dart';
import 'package:myvibel/error_messages.dart';
import 'package:myvibel/maestro_semantics.dart';
import 'package:myvibel/sosyal_servis.dart';
import 'package:myvibel/vibe_snackbar.dart';
import 'package:myvibel/widgets/vibe_avatar.dart';
import 'package:myvibel/widgets/vibe_ikonlar.dart';
import 'package:myvibel/widgets/hashtag_metin.dart';
import 'package:myvibel/widgets/bahsetme_metin_alani.dart';
import 'package:myvibel/widgets/vibe_gradient_scaffold.dart';
import 'package:myvibel/widgets/web_shell.dart';
import 'package:myvibel/yas_hesap_kontrol.dart';

class _MasaustuSeciliSohbet {
  const _MasaustuSeciliSohbet({
    required this.chatId,
    required this.otherUid,
    required this.otherDisplayName,
    required this.otherUsername,
    required this.otherPhotoUrl,
    required this.otherAvatarKey,
  });

  final String chatId;
  final String otherUid;
  final String otherDisplayName;
  final String otherUsername;
  final String otherPhotoUrl;
  final String otherAvatarKey;
}
String _saatYaz(dynamic value) {
  if (value is! Timestamp) return "";
  final dt = value.toDate();
  final saat = dt.hour.toString().padLeft(2, "0");
  final dakika = dt.minute.toString().padLeft(2, "0");
  return "$saat:$dakika";
}

// Sohbet gün başlığı (Bugün, Dün veya gg.aa.yyyy)
String _sohbetTarihBasligi(dynamic value) {
  if (value is! Timestamp) return "";
  final dt = value.toDate();
  final now = DateTime.now();
  final bugun = DateTime(now.year, now.month, now.day);
  final mesajGunu = DateTime(dt.year, dt.month, dt.day);
  if (mesajGunu == bugun) return "Bugün";
  if (mesajGunu == bugun.subtract(const Duration(days: 1))) return "Dün";
  final gun = dt.day.toString().padLeft(2, "0");
  final ay = dt.month.toString().padLeft(2, "0");
  return "$gun.$ay.${dt.year}";
}

// İki mesaj farklı güne mi ait
bool _sohbetGunDegisti(
  List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  int index,
) {
  if (index == 0) return true;
  final onceki = docs[index - 1].data()["createdAt"];
  final simdiki = docs[index].data()["createdAt"];
  if (onceki is! Timestamp || simdiki is! Timestamp) return index == 0;
  final o = onceki.toDate();
  final s = simdiki.toDate();
  return o.year != s.year || o.month != s.month || o.day != s.day;
}

// DM okundu anahtarı üret
String _dmReadKey(String uid, String chatId) => "dm_last_read_${uid}_$chatId";
// Gizli sohbet anahtarı üret
String _dmHiddenChatKey(String uid, String chatId) =>
    "dm_hidden_chat_${uid}_$chatId";

// Sohbet okunmamış mı kontrol et (yerel okuma zamanı ile)
bool _chatOkunmamisMi({
  required String uid,
  required Map<String, dynamic> chat,
  int? localReadAtMs,
}) {
  return SosyalServis.sohbetOkunmamisMi(
    uid: uid,
    chat: chat,
    localReadAtMs: localReadAtMs,
  );
}

// Sohbet listesi sayfası
class MessagesPage extends StatefulWidget {
  const MessagesPage({
    super.key,
    this.gomulu = false,
    this.onKapat,
    this.ilkHedef,
  });

  /// Masaüstü sağ panelde gömülü kullanım (Scaffold AppBar yok).
  final bool gomulu;
  final VoidCallback? onKapat;
  final WebSohbetHedef? ilkHedef;

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

// Sohbet listesi durumu
class _MessagesPageState extends State<MessagesPage> {
  final TextEditingController _aramaController = TextEditingController();
  final Map<String, int> _gizliSohbetlerMs = {}; // yerel gizli sohbet zaman damgaları
  final Map<String, int> _yerelOkumaMs = {}; // yerel okundu zaman damgaları
  final Map<String, Map<String, dynamic>> _kullaniciOnbellegi = {}; // sohbet karşı taraf önbelleği
  final Set<String> _kullaniciYukleniyor = {}; // yüklenen kullanıcı uid'leri
  final Set<String> _kullaniciYuklenemedi = {}; // yüklenemeyen uid'ler (tekrar deneme yok)
  final Set<String> _bekleyenUidYukleme = {}; // build döngüsünü önlemek için
  bool _uidYuklemePlanlandi = false;
  _MasaustuSeciliSohbet? _masaustuSecili;
  String? _sohbetAkisiUid;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sohbetAbonelik;
  StreamController<QuerySnapshot<Map<String, dynamic>>>? _sohbetYayin;
  QuerySnapshot<Map<String, dynamic>>? _sonSohbetSnap;

  // build her çalıştığında yeni abonelik açılmasın (liste spinner'a dönmesin)
  Stream<QuerySnapshot<Map<String, dynamic>>> _sohbetlerimAkisi(String uid) {
    if (_sohbetYayin == null || _sohbetAkisiUid != uid) {
      _sohbetAbonelik?.cancel();
      _sohbetYayin?.close();
      _sohbetAkisiUid = uid;
      _sonSohbetSnap = null;
      final yayin = StreamController<QuerySnapshot<Map<String, dynamic>>>.broadcast();
      _sohbetYayin = yayin;
      _sohbetAbonelik = SosyalServis.sohbetlerim(uid).listen(
        (snap) {
          _sonSohbetSnap = snap;
          yayin.add(snap);
        },
        onError: yayin.addError,
      );
    }
    return _sohbetYayin!.stream;
  }

  // Tek kullanıcıyı Firestore'dan getir
  Future<MapEntry<String, Map<String, dynamic>>?> _kullaniciOnbellekVerisiniGetir(
    String uid,
  ) async {
   
    // hata yakalamalı blok
    try {
      final doc = await FirebaseFirestore.instance
          .collection("users")
          .doc(uid)
          .get();
      final data = doc.data();
      if (data == null) return null;
      return MapEntry(uid, data);
    // hata yakala
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _yerelDmDurumlariniYukle();
    _hedefiUygula(widget.ilkHedef);
  }

  @override
  void didUpdateWidget(covariant MessagesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final yeni = widget.ilkHedef;
    if (yeni != null && yeni.chatId != oldWidget.ilkHedef?.chatId) {
      setState(() => _hedefiUygula(yeni));
    }
  }

  void _hedefiUygula(WebSohbetHedef? hedef) {
    if (hedef == null) return;
    _masaustuSecili = _MasaustuSeciliSohbet(
      chatId: hedef.chatId,
      otherUid: hedef.otherUid,
      otherDisplayName: hedef.otherDisplayName,
      otherUsername: hedef.otherUsername,
      otherPhotoUrl: hedef.otherPhotoUrl,
      otherAvatarKey: hedef.otherAvatarKey,
    );
  }

  bool get _panelSohbetiKullan => widget.gomulu || webMasaustuMu(context);

  void _sohbetiPaneleAl(_MasaustuSeciliSohbet secili) {
    setState(() => _masaustuSecili = secili);
  }

  // Gizli sohbet ve okundu bilgilerini SharedPreferences'tan yükle
  Future<void> _yerelDmDurumlariniYukle() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final prefs = await SharedPreferences.getInstance();
    final hiddenPrefix = "dm_hidden_chat_${user.uid}_";
    final readPrefix = "dm_last_read_${user.uid}_";
    final gizliMap = <String, int>{};
    final okumaMap = <String, int>{};
    for (final key in prefs.getKeys()) {
      if (key.startsWith(hiddenPrefix)) {
        final chatId = key.substring(hiddenPrefix.length);
        gizliMap[chatId] = prefs.getInt(key) ?? 0;
      } else if (key.startsWith(readPrefix)) {
        final chatId = key.substring(readPrefix.length);
        okumaMap[chatId] = prefs.getInt(key) ?? 0;
      }
    }
    if (!mounted) return;
    setState(() {
      _gizliSohbetlerMs
        ..clear()
        ..addAll(gizliMap);
      _yerelOkumaMs
        ..clear()
        ..addAll(okumaMap);
    });
  }

  // Kullanıcı önbelleğini build içinde değil, tek seferlik planla
  void _kullanicilariOnbellegeAlPlanla(List<String> uids) {
    _bekleyenUidYukleme.addAll(uids.where((uid) => uid.isNotEmpty));
    if (_uidYuklemePlanlandi) return;
    _uidYuklemePlanlandi = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _uidYuklemePlanlandi = false;
      if (!mounted || _bekleyenUidYukleme.isEmpty) return;
      final batch = _bekleyenUidYukleme.toList();
      _bekleyenUidYukleme.clear();
      await _kullanicilariOnbellegeAl(batch);
    });
  }

  // Sohbet gizli mi
  bool _sohbetGizliMi({
    required String chatId,
    required Map<String, dynamic> chat,
  }) {
    return SosyalServis.sohbetGizliMi(
      uid: FirebaseAuth.instance.currentUser?.uid ?? "",
      chat: chat,
      localHiddenAtMs: _gizliSohbetlerMs[chatId],
    );
  }

  // Karşı taraf kullanıcıları önbelleğe al
  Future<void> _kullanicilariOnbellegeAl(List<String> uids) async {
    final eksik = uids
        .where((uid) =>
            uid.isNotEmpty &&
            !_kullaniciOnbellegi.containsKey(uid) &&
            !_kullaniciYukleniyor.contains(uid) &&
            !_kullaniciYuklenemedi.contains(uid))
        .toList();
    if (eksik.isEmpty) return;

    _kullaniciYukleniyor.addAll(eksik);
    for (var i = 0; i < eksik.length; i += 10) {
      final parca = eksik.sublist(i, i + 10 > eksik.length ? eksik.length : i + 10);
      final sonuc = await Future.wait(
        parca.map(_kullaniciOnbellekVerisiniGetir),
      );
      for (var j = 0; j < parca.length; j++) {
        final uid = parca[j];
        final entry = sonuc[j];
        if (entry != null) {
          _kullaniciOnbellegi[entry.key] = entry.value;
        } else {
          _kullaniciYuklenemedi.add(uid);
        }
      }
    }

    if (!mounted) return;
    setState(() {
      for (final uid in eksik) {
        _kullaniciYukleniyor.remove(uid);
      }
    });
  }

  // Sohbeti gizle/sil
  Future<void> _sohbetSil({
    required String chatId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_dmHiddenChatKey(user.uid, chatId), nowMs);
    await prefs.setInt(_dmReadKey(user.uid, chatId), nowMs);
   
    // hata yakalamalı blok
    try {
      await SosyalServis.sohbetiGizle(chatId: chatId, uid: user.uid);
    // hata yakala
    } catch (e) {
      await prefs.remove(_dmHiddenChatKey(user.uid, chatId));
      if (!mounted) return;
      vibeSnackbarGoster(
        context,
        internetAwareErrorMessage(
          error: e,
          fallback: "Sohbet silinemedi.",
        ),
      );
      return;
    }
    if (!mounted) return;
    setState(() {
      _gizliSohbetlerMs[chatId] = nowMs;
      _yerelOkumaMs[chatId] = nowMs;
    });
    vibeSnackbarGoster(context, "Sohbet silindi.", tip: VibeMesajTipi.basari);
  }

  // Sohbet menü seçenekleri
  Future<void> _sohbetSecenekleriAc({
    required String chatId,
    required Map<String, dynamic> chat,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final sessiz = SosyalServis.sohbetSessizMi(uid: user.uid, chat: chat);

    final secim = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: context.vibe.sheetBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  onTap: () => Navigator.pop(ctx, sessiz ? "unmute" : "mute"),
                  leading: Icon(sessiz ? Icons.notifications : Icons.notifications_off),
                  title: Text(sessiz ? "Sessize almayı kaldır" : "Sessize al"),
                  subtitle: Text(
                    sessiz
                        ? "Bu sohbetten bildirim almaya devam et."
                        : "Bu sohbetten bildirim alma.",
                  ),
                ),
                ListTile(
                  onTap: () => Navigator.pop(ctx, "delete"),
                  leading: const Icon(Icons.delete_outline),
                  title: const Text("Sohbeti sil"),
                ),
                ListTile(
                  onTap: () => Navigator.pop(ctx, "cancel"),
                  leading: const Icon(Icons.close),
                  title: const Text("Vazgeç"),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (secim == "mute" || secim == "unmute") {
     
      // hata yakalamalı blok
      try {
        await SosyalServis.sohbetSessizliginiDegistir(
          chatId: chatId,
          uid: user.uid,
          sessiz: secim == "mute",
        );
        if (!mounted) return;
        vibeSnackbarGoster(
          context,
          secim == "mute" ? "Sohbet sessize alındı." : "Sessize alma kaldırıldı.",
          tip: VibeMesajTipi.basari,
        );
        setState(() {});
      // hata yakala
      } catch (e) {
        if (!mounted) return;
        vibeSnackbarGoster(
          context,
          internetAwareErrorMessage(
            error: e,
            fallback: "İşlem başarısız.",
          ),
        );
      }
      return;
    }

    if (secim == "delete") {
      await _sohbetSil(chatId: chatId);
    }
  }

  // Abonelik ve kontrolcüleri temizle
  @override
  void dispose() {
    _sohbetAbonelik?.cancel();
    _sohbetYayin?.close();
    _aramaController.dispose();
    super.dispose();
  }

  // Yeni sohbet paneli
  Future<void> _yeniSohbetPaneliAc() async {
    final current = FirebaseAuth.instance.currentUser;
    if (current == null) return;

    final aramaController = TextEditingController();
    List<Map<String, dynamic>> tumKullanicilar = [];
    List<Map<String, dynamic>> filtreli = [];
    bool yukleniyor = true;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.vibe.sheetBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final vibe = sheetContext.vibe;
        final theme = Theme.of(sheetContext);

       
        // verileriYukle metodu
        Future<void> verileriYukle(StateSetter setModalState) async {
         
          // hata yakalamalı blok
          try {
            const genelKullaniciLimiti = 90;
            const takipliProfilLimiti = 30;
            final firestore = FirebaseFirestore.instance;

            final ilkYuklemeler = await Future.wait([
              firestore
                  .collection("users")
                  .where("hesapGizli", isEqualTo: false)
                  .limit(genelKullaniciLimiti)
                  .get(),
              SosyalServis.engellenenKullanicilariGetir(current.uid),
              SosyalServis.beniEngelleyenKullanicilariGetir(current.uid),
              SosyalServis.takipEdilenIdleriGetir(current.uid),
            ]);
            final publicSnap =
                ilkYuklemeler[0] as QuerySnapshot<Map<String, dynamic>>;
            final engelIdleri = {
              ...(ilkYuklemeler[1] as Set<String>),
              ...(ilkYuklemeler[2] as Set<String>),
            };
            final takipEdilenIdler = ilkYuklemeler[3] as Set<String>;

            final kullanicilarMap = <String, Map<String, dynamic>>{};
            for (final doc in publicSnap.docs) {
              if (doc.id == current.uid || engelIdleri.contains(doc.id)) {
                continue;
              }
              kullanicilarMap[doc.id] = doc.data();
            }
            final takipliOrnek = takipEdilenIdler
                .where(
                  (id) =>
                      id.isNotEmpty &&
                      id != current.uid &&
                      !engelIdleri.contains(id),
                )
                .take(takipliProfilLimiti)
                .toList();

            for (var i = 0; i < takipliOrnek.length; i += 10) {
              final part = takipliOrnek.sublist(
                i,
                i + 10 > takipliOrnek.length ? takipliOrnek.length : i + 10,
              );
              final snap = await firestore
                  .collection("users")
                  .where(FieldPath.documentId, whereIn: part)
                  .limit(10)
                  .get();
              for (final doc in snap.docs) {
                if (doc.id == current.uid || engelIdleri.contains(doc.id)) {
                  continue;
                }
                kullanicilarMap[doc.id] = doc.data();
              }
            }

            final list = kullanicilarMap.entries
                .map((entry) {
                  final data = entry.value;
                  return {
                    "uid": entry.key,
                    "adSoyad": (data["adSoyad"] ?? "Vibe Kullanıcısı").toString(),
                    "kullaniciAdi": (data["kullaniciAdi"] ?? "kullanici").toString(),
                    "photoUrl": (data["photoUrl"] ?? "").toString(),
                    "avatarKey": (data["avatarKey"] ?? "").toString(),
                  };
                })
                .toList()
              ..sort((a, b) => (a["adSoyad"] as String)
                  .toLowerCase()
                  .compareTo((b["adSoyad"] as String).toLowerCase()));

            if (!sheetContext.mounted) return;
            setModalState(() {
              tumKullanicilar = list;
              filtreli = list;
              yukleniyor = false;
            });
          // hata yakala
          } catch (e) {
            if (!sheetContext.mounted) return;
            setModalState(() {
              tumKullanicilar = [];
              filtreli = [];
              yukleniyor = false;
            });
            vibeSnackbarGoster(
              sheetContext,
              internetAwareErrorMessage(
                error: e,
                fallback: "Kullanıcılar yüklenemedi.",
              ),
            );
          }
        }

        return StatefulBuilder(
          builder: (context, setModalState) {
            if (yukleniyor && tumKullanicilar.isEmpty) {
              verileriYukle(setModalState);
            }

           
            // filtrele metodu
            void filtrele(String sorgu) {
              final q = sorgu.trim().toLowerCase();
              setModalState(() {
                if (q.isEmpty) {
                  filtreli = tumKullanicilar;
                } else {
                  filtreli = tumKullanicilar.where((k) {
                    final ad = (k["adSoyad"] ?? "").toString().toLowerCase();
                    final ka = (k["kullaniciAdi"] ?? "").toString().toLowerCase();
                    return ad.contains(q) || ka.contains(q);
                  }).toList();
                }
              });
            }

            return SafeArea(
              child: SizedBox(
                height: MediaQuery.of(sheetContext).size.height * 0.78,
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 42,
                      height: 5,
                      decoration: BoxDecoration(
                        color: vibe.faintText,
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Yeni Sohbet",
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                      child: TextField(
                        controller: aramaController,
                        onChanged: filtrele,
                        style: TextStyle(color: theme.colorScheme.onSurface),
                        decoration: InputDecoration(
                          hintText: "Kullanıcı ara...",
                          hintStyle: TextStyle(color: vibe.mutedText),
                          prefixIcon: Icon(Icons.search, color: vibe.mutedText),
                          filled: true,
                          fillColor: vibe.inputFill,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: yukleniyor
                          ? Center(
                              child: VibeYukleniyor(
                                renk: theme.colorScheme.primary,
                              ),
                            )
                          : filtreli.isEmpty
                              ? Center(
                                  child: Text(
                                    "Kullanıcı bulunamadı.",
                                    style: TextStyle(color: vibe.mutedText),
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 14),
                                  itemCount: filtreli.length,
                                  itemBuilder: (context, index) {
                                    final k = filtreli[index];
                                    final uid = (k["uid"] ?? "").toString();
                                    final adSoyad =
                                        (k["adSoyad"] ?? "Vibe Kullanıcısı").toString();
                                    final kullaniciAdi =
                                        (k["kullaniciAdi"] ?? "kullanici").toString();
                                    final photoUrl = (k["photoUrl"] ?? "").toString();
                                    final avatarKey = (k["avatarKey"] ?? "").toString();

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      decoration: vibe.cardDecoration(radius: 14),
                                      child: ListTile(
                                        onTap: () async {
                                          final bilet = tekSeferGecisAl();
                                          if (bilet == null) return;
                                          final navigator = Navigator.of(context);
                                         
                                          // hata yakalamalı blok
                                          try {
                                            final chatId = await SosyalServis
                                                .sohbetIdGetirVeyaOlustur(uid);
                                            if (!mounted) {
                                              tekSeferGecisIptal(bilet);
                                              return;
                                            }
                                            navigator.pop();
                                            final secili = _MasaustuSeciliSohbet(
                                              chatId: chatId,
                                              otherUid: uid,
                                              otherDisplayName: adSoyad,
                                              otherUsername: kullaniciAdi,
                                              otherPhotoUrl: photoUrl,
                                              otherAvatarKey: avatarKey,
                                            );
                                            if (_panelSohbetiKullan) {
                                              _sohbetiPaneleAl(secili);
                                              tekSeferGecisBirak(bilet);
                                              return;
                                            }
                                            navigator.push(
                                              MaterialPageRoute(
                                                builder: (_) => ChatPage(
                                                  chatId: chatId,
                                                  otherUid: uid,
                                                  otherDisplayName: adSoyad,
                                                  otherUsername: kullaniciAdi,
                                                  otherPhotoUrl: photoUrl,
                                                  otherAvatarKey: avatarKey,
                                                ),
                                              ),
                                            );
                                            tekSeferGecisBirak(bilet);
                                          // hata yakala
                                          } catch (e) {
                                            tekSeferGecisIptal(bilet);
                                            if (!context.mounted) return;
                                            vibeSnackbarGoster(
                                              context,
                                              internetAwareErrorMessage(
                                                error: e,
                                                fallback: "Sohbet başlatılamadı.",
                                              ),
                                            );
                                          }
                                        },
                                        leading: vibeAvatar(
                                          radius: 20,
                                          userId: uid,
                                          photoUrl: photoUrl,
                                          avatarKey: avatarKey,
                                          fallbackText: kullaniciAdi,
                                          emojiSize: 16,
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
                                          style: TextStyle(color: vibe.mutedText),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Arayüzü oluştur
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);
    final vibe = context.vibe;

    if (user == null) {
      return Center(
        child: Text(
          "Mesajlar için giriş yapmalısın.",
          style: TextStyle(color: vibe.subtleText),
        ),
      );
    }

    if (YasHesapKontrol.maybeOf(context)?.mesajAcik == false) {
      return const SizedBox.shrink();
    }

    final masaustu = webMasaustuMu(context);
    final listeGenislik =
        widget.gomulu ? 260.0 : kWebMesajListeGenislik;

    final govde = masaustu
        ? Row(
            children: [
              SizedBox(
                width: listeGenislik,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.cardColor.withOpacity(0.25),
                    border: Border(
                      right: BorderSide(
                        color: vibe.cardBorder,
                        width: 1,
                      ),
                    ),
                  ),
                  child: _mesajListeKolonu(user, theme, vibe),
                ),
              ),
              Expanded(
                child: _masaustuSecili == null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.forum_outlined,
                              size: 56,
                              color: vibe.faintText,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Bir sohbet seç',
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Soldaki listeden devam et veya yeni sohbet başlat.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: vibe.mutedText),
                            ),
                          ],
                        ),
                      )
                    : ChatPage(
                        key: ValueKey(_masaustuSecili!.chatId),
                        chatId: _masaustuSecili!.chatId,
                        otherUid: _masaustuSecili!.otherUid,
                        otherDisplayName: _masaustuSecili!.otherDisplayName,
                        otherUsername: _masaustuSecili!.otherUsername,
                        otherPhotoUrl: _masaustuSecili!.otherPhotoUrl,
                        otherAvatarKey: _masaustuSecili!.otherAvatarKey,
                        gomulu: widget.gomulu,
                      ),
              ),
            ],
          )
        : _mesajListeKolonu(user, theme, vibe);

    if (widget.gomulu) {
      return Material(
        color: Colors.transparent,
        child: DecoratedBox(
          decoration: vibe.gradientDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                  child: Row(
                    children: [
                      Icon(VibeIkon.mesajBos, color: vibe.mutedText, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Sohbetler',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Kapat',
                        onPressed: widget.onKapat,
                        icon: Icon(Icons.close, color: vibe.mutedText),
                      ),
                    ],
                  ),
                ),
              ),
              Divider(height: 1, color: vibe.cardBorder),
              Expanded(child: govde),
            ],
          ),
        ),
      );
    }

    return VibeGradientScaffold(
      body: SafeArea(
        child: govde,
      ),
    );
  }

  Widget _mesajListeKolonu(
    User user,
    ThemeData theme,
    VibeThemeExtension vibe,
  ) {
    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    decoration: vibe.cardDecoration(radius: 18),
                    child: TextField(
                      controller: _aramaController,
                      onChanged: (_) => setState(() {}),
                      style: TextStyle(color: theme.colorScheme.onSurface),
                      decoration: InputDecoration(
                        hintText: "Sohbetlerde ara...",
                        hintStyle: TextStyle(color: vibe.mutedText),
                        prefixIcon: Icon(Icons.search, color: vibe.mutedText),
                        filled: true,
                        fillColor: vibe.inputFill,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: maestroButton(
                      label: MaestroSemantics.yeniSohbet,
                      onTap: _yeniSohbetPaneliAc,
                      child: FilledButton(
                        onPressed: _yeniSohbetPaneliAc,
                        style: FilledButton.styleFrom(
                          backgroundColor: vibe.primaryButton,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(44, 40),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Icon(Icons.add),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _sohbetlerimAkisi(user.uid),
                initialData: _sonSohbetSnap,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Sohbetler yüklenemedi.",
                            style: TextStyle(color: vibe.mutedText),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () => setState(() {}),
                            child: const Text("Tekrar dene"),
                          ),
                        ],
                      ),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return Center(
                      child: VibeYukleniyor(renk: theme.colorScheme.primary),
                    );
                  }

                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return Center(
                      child: Text(
                        "Henüz sohbet yok.",
                        style: TextStyle(color: vibe.mutedText),
                      ),
                    );
                  }

                  docs.sort((a, b) {
                    final aTs = a.data()["lastMessageAt"];
                    final bTs = b.data()["lastMessageAt"];
                    if (aTs is Timestamp && bTs is Timestamp) {
                      return bTs.compareTo(aTs);
                    }
                    return 0;
                  });
                  final gorunenDocs = docs
                      .where(
                        (d) => !_sohbetGizliMi(chatId: d.id, chat: d.data()),
                      )
                      .toList();

                  if (gorunenDocs.isEmpty) {
                    return Center(
                      child: Text(
                        "Henüz sohbet yok.",
                        style: TextStyle(color: vibe.mutedText),
                      ),
                    );
                  }

                  final otherUids = gorunenDocs.map((chatDoc) {
                    final participants =
                        List<String>.from(chatDoc.data()["participants"] ?? []);
                    return participants.firstWhere(
                      (id) => id != user.uid,
                      orElse: () => "",
                    );
                  }).where((uid) => uid.isNotEmpty).toList();
                  _kullanicilariOnbellegeAlPlanla(otherUids);

                  final canliDocs = gorunenDocs.where((chatDoc) {
                    final participants =
                        List<String>.from(chatDoc.data()["participants"] ?? []);
                    final otherUid = participants.firstWhere(
                      (id) => id != user.uid,
                      orElse: () => "",
                    );
                    return otherUid.isNotEmpty &&
                        !_kullaniciYuklenemedi.contains(otherUid);
                  }).toList();

                  if (canliDocs.isEmpty) {
                    final henuzYukleniyor = otherUids.any(
                      (uid) =>
                          !_kullaniciOnbellegi.containsKey(uid) &&
                          !_kullaniciYuklenemedi.contains(uid),
                    );
                    if (!henuzYukleniyor) {
                      return Center(
                        child: Text(
                          "Henüz sohbet yok.",
                          style: TextStyle(color: vibe.mutedText),
                        ),
                      );
                    }
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 20),
                    itemCount: canliDocs.length,
                    itemBuilder: (context, index) {
                      final chatDoc = canliDocs[index];
                      final chat = chatDoc.data();
                      final participants = List<String>.from(chat["participants"] ?? []);
                      final otherUid = participants.firstWhere(
                        (id) => id != user.uid,
                        orElse: () => "",
                      );
                      if (otherUid.isEmpty) return const SizedBox.shrink();
                      if (_kullaniciYuklenemedi.contains(otherUid)) {
                        return const SizedBox.shrink();
                      }

                      final u = _kullaniciOnbellegi[otherUid] ?? {};
                      final adSoyad =
                          (u["adSoyad"] ?? "Vibe Kullanıcısı").toString();
                      final kullaniciAdi =
                          (u["kullaniciAdi"] ?? "kullanici").toString();
                      final photoUrl = (u["photoUrl"] ?? "").toString();
                      final avatarKey = (u["avatarKey"] ?? "").toString();
                      final sessiz =
                          SosyalServis.sohbetSessizMi(uid: user.uid, chat: chat);
                      final lastMessage =
                          (chat["lastMessage"] ?? "").toString().isEmpty
                              ? "@$kullaniciAdi"
                              : (chat["lastMessage"] ?? "").toString();
                      final arama = _aramaController.text.trim().toLowerCase();
                      final eslesme = arama.isEmpty ||
                          adSoyad.toLowerCase().contains(arama) ||
                          kullaniciAdi.toLowerCase().contains(arama) ||
                          lastMessage.toLowerCase().contains(arama);
                      if (!eslesme) return const SizedBox.shrink();

                      final masaustuSecili = webMasaustuMu(context) &&
                          _masaustuSecili?.chatId == chatDoc.id;

                      return Semantics(
                        label: '$adSoyad $kullaniciAdi',
                        button: true,
                        child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: vibe.cardDecoration(radius: 18).copyWith(
                          color: masaustuSecili
                              ? theme.colorScheme.primary.withOpacity(0.14)
                              : null,
                          border: Border.all(
                            color: masaustuSecili
                                ? theme.colorScheme.primary.withOpacity(0.55)
                                : vibe.cardBorder,
                            width: masaustuSecili ? 1.5 : 1,
                          ),
                        ),
                        child: ListTile(
                          onTap: () async {
                            final secili = _MasaustuSeciliSohbet(
                              chatId: chatDoc.id,
                              otherUid: otherUid,
                              otherDisplayName: adSoyad,
                              otherUsername: kullaniciAdi,
                              otherPhotoUrl: photoUrl,
                              otherAvatarKey: avatarKey,
                            );
                            if (webMasaustuMu(context) || widget.gomulu) {
                              _sohbetiPaneleAl(secili);
                              return;
                            }
                            await tekSeferPush(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatPage(
                                  chatId: secili.chatId,
                                  otherUid: secili.otherUid,
                                  otherDisplayName: secili.otherDisplayName,
                                  otherUsername: secili.otherUsername,
                                  otherPhotoUrl: secili.otherPhotoUrl,
                                  otherAvatarKey: secili.otherAvatarKey,
                                ),
                              ),
                            );
                            await _yerelDmDurumlariniYukle();
                          },
                          onLongPress: () =>
                              _sohbetSecenekleriAc(chatId: chatDoc.id, chat: chat),
                          leading: vibeAvatar(
                            radius: 22,
                            userId: otherUid,
                            photoUrl: photoUrl,
                            avatarKey: avatarKey,
                            fallbackText: kullaniciAdi,
                            emojiSize: 18,
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  adSoyad,
                                  maxLines: _panelSohbetiKullan ? 1 : null,
                                  overflow: _panelSohbetiKullan
                                      ? TextOverflow.ellipsis
                                      : null,
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurface,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (sessiz)
                                Icon(
                                  Icons.notifications_off,
                                  size: 16,
                                  color: vibe.faintText,
                                ),
                            ],
                          ),
                          subtitle: Text(
                            lastMessage,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: vibe.mutedText),
                          ),
                          trailing: Builder(
                            builder: (context) {
                              final okunmamis = _chatOkunmamisMi(
                                uid: user.uid,
                                chat: chat,
                                localReadAtMs: _yerelOkumaMs[chatDoc.id],
                              );
                              return Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    _saatYaz(chat["lastMessageAt"]),
                                    style: TextStyle(
                                      color: vibe.faintText,
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (okunmamis)
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(
                                            color: Colors.redAccent,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      if (okunmamis) const SizedBox(width: 4),
                                      Icon(
                                        Icons.chevron_right,
                                        color: vibe.faintText,
                                      ),
                                    ],
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
    );
  }
}

// Tek sohbet (DM) ekranı
class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    required this.chatId,
    required this.otherUid,
    required this.otherDisplayName,
    required this.otherUsername,
    required this.otherPhotoUrl,
    required this.otherAvatarKey,
    this.gomulu = false,
  });

  final String chatId; // sohbet kimliği
  final String otherUid; // karşı taraf uid
  final String otherDisplayName; // karşı taraf görünen adı
  final String otherUsername; // karşı taraf kullanıcı adı
  final String otherPhotoUrl; // karşı taraf foto url
  final String otherAvatarKey; // karşı taraf avatar anahtarı
  final bool gomulu; // sağ panelde gömülü (geri butonu gizle)

  @override
  State<ChatPage> createState() => _ChatPageState();
}

// Sohbet ekranı durumu
class _ChatPageState extends State<ChatPage> {
  final TextEditingController _mesajController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _sessiz = false; // sohbet sessize alınmış mı
  int _oncekiMesajSayisi = 0; // önceki mesaj sayısı (kaydırma için)
  bool _otomatikKaydir = true; // alta otomatik kaydır mı
  int _sonOkunduMs = 0; // son okundu zaman damgası (ms)
  String? _sonOkunduIsaretlenenMesajId; // okundu işaretlenen son mesaj
  String? _akisChatId;
  late Stream<DocumentSnapshot<Map<String, dynamic>>> _sohbetDocAkisi;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _mesajAkisi;
  final List<({String id, String metin})> _bekleyenMesajlar = [];
  Set<String> _gelenMesajIdleri = const {};

  // build her çalıştığında yeniden abone olunmasın (mesajlar boş flaş yapmasın)
  void _akislariHazirla() {
    if (_akisChatId == widget.chatId) return;
    _akisChatId = widget.chatId;
    _bekleyenMesajlar.clear();
    _gelenMesajIdleri = const {};
    _sohbetDocAkisi = FirebaseFirestore.instance
        .collection("chats")
        .doc(widget.chatId)
        .snapshots();
    _mesajAkisi = SosyalServis.sohbetMesajlari(widget.chatId);
  }

  // Widget ilk yüklendiğinde çalışır
  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_kaydirmaDinleyici);
    _sohbetiOkunduIsaretle();
    _sessizDurumunuYukle();
  }

  // Sessiz durumunu yükle
  Future<void> _sessizDurumunuYukle() async {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return;
    final snap = await FirebaseFirestore.instance
        .collection("chats")
        .doc(widget.chatId)
        .get();
    if (!mounted) return;
    setState(() {
      _sessiz = SosyalServis.sohbetSessizMi(
        uid: myUid,
        chat: snap.data() ?? {},
      );
    });
  }

  // Sessize almayı aç/kapat
  Future<void> _sessizligiDegistir() async {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return;
    final yeniDeger = !_sessiz;
   
    // hata yakalamalı blok
    try {
      await SosyalServis.sohbetSessizliginiDegistir(
        chatId: widget.chatId,
        uid: myUid,
        sessiz: yeniDeger,
      );
      if (!mounted) return;
      setState(() => _sessiz = yeniDeger);
      vibeSnackbarGoster(
        context,
        yeniDeger ? "Sohbet sessize alındı." : "Sessize alma kaldırıldı.",
        tip: VibeMesajTipi.basari,
      );
    // hata yakala
    } catch (e) {
      if (!mounted) return;
      vibeSnackbarGoster(
        context,
        internetAwareErrorMessage(
          error: e,
          fallback: "İşlem başarısız.",
        ),
      );
    }
  }

  // Gönderi detay sayfasına git
  Future<void> _gonderiDetayinaGit(String postId) async {
    if (postId.isEmpty) return;
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? "";
    await gonderiDetayiniAc(
      context,
      postId: postId,
      currentUserId: myUid,
    );
  }

  // Kaydırma dinleyicisi
  void _kaydirmaDinleyici() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    _otomatikKaydir = pos.pixels >= pos.maxScrollExtent - 96;
  }

  // Gerekirse alta kaydır
  void _gerekirseAltaKaydir(int mesajSayisi, {required bool bendenYeniMesaj}) {
    final yeniMesajGeldi = mesajSayisi > _oncekiMesajSayisi;
    _oncekiMesajSayisi = mesajSayisi;
    if (!yeniMesajGeldi) return;
    if (!_otomatikKaydir && !bendenYeniMesaj) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
  }

  // Sohbeti okundu işaretle
  Future<void> _sohbetiOkunduIsaretle({Timestamp? timestamp}) async {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return;
    final ms = (timestamp?.millisecondsSinceEpoch ??
            DateTime.now().millisecondsSinceEpoch)
        .toInt();
    if (ms <= _sonOkunduMs) return;
    _sonOkunduMs = ms;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_dmReadKey(myUid, widget.chatId), ms);
    await SosyalServis.sohbetiGorulduIsaretle(
      chatId: widget.chatId,
      seenAt: timestamp,
    );
  }

  // Yeni mesaj gelince okundu işaretle (build döngüsü yok)
  void _yeniMesajlariOkunduIsaretle(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    if (docs.isEmpty) return;
    final sonDoc = docs.last;
    if (_sonOkunduIsaretlenenMesajId == sonDoc.id) return;
    final ts = sonDoc.data()["createdAt"];
    if (ts is! Timestamp) return;
    if (ts.millisecondsSinceEpoch <= _sonOkunduMs) return;
    _sonOkunduIsaretlenenMesajId = sonDoc.id;
    _sohbetiOkunduIsaretle(timestamp: ts);
  }

  bool _mesajGorulduMu(
    Map<String, dynamic> mesaj,
    Map<String, dynamic> sohbetVerisi,
  ) {
    final dynamic seenRaw = sohbetVerisi["lastSeenBy"];
    final seenMap = seenRaw is Map
        ? Map<String, dynamic>.from(seenRaw)
        : <String, dynamic>{};
    final otherSeen = seenMap[widget.otherUid];
    final myMsgTs = mesaj["createdAt"];
    if (otherSeen is Timestamp && myMsgTs is Timestamp) {
      return otherSeen.millisecondsSinceEpoch >= myMsgTs.millisecondsSinceEpoch;
    }
    return false;
  }

  // Abonelik ve kontrolcüleri temizle
  @override
  void dispose() {
    _mesajController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Mesaj gönder
  Future<void> _mesajGonder() async {
    final metin = _mesajController.text;
    if (metin.trim().isEmpty) return;
    _mesajController.clear();

    final bekleyen = (
      id: FirebaseFirestore.instance
          .collection("chats")
          .doc(widget.chatId)
          .collection("messages")
          .doc()
          .id,
      metin: metin.trim(),
    );
    setState(() {
      _bekleyenMesajlar
        ..removeWhere((b) => _gelenMesajIdleri.contains(b.id))
        ..add(bekleyen);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });

    try {
      await SosyalServis.mesajGonder(
        chatId: widget.chatId,
        hedefUid: widget.otherUid,
        metin: metin,
        messageId: bekleyen.id,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _bekleyenMesajlar.remove(bekleyen));
      if (_mesajController.text.isEmpty) {
        _mesajController.text = metin;
        _mesajController.selection =
            TextSelection.collapsed(offset: metin.length);
      }
      final mesaj = e is FirebaseException && e.code == 'permission-denied'
          ? 'Mesaj yazılamadı. E-postan doğrulanmamış olabilir veya bu sohbet kapalı.'
          : internetAwareErrorMessage(
              error: e,
              fallback: "Mesaj gönderilemedi.",
            );
      vibeSnackbarGoster(context, mesaj);
    }
  }

  // Mesaj silme onay menüsü
  Future<void> _mesajSilOnayiAc({
    required String messageId,
    required String mevcutMetin,
  }) async {
    final secim = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: context.vibe.sheetBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final vibe = ctx.vibe;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: vibe.cardBorder,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 14),
                ListTile(
                  onTap: () => Navigator.pop(ctx, "delete"),
                  leading: const Icon(Icons.delete_outline),
                  title: const Text("Mesajı sil"),
                  subtitle: const Text("Bu mesaj sohbette silinmiş olarak görünür."),
                ),
                ListTile(
                  onTap: () => Navigator.pop(ctx, "cancel"),
                  leading: const Icon(Icons.close),
                  title: const Text("Vazgeç"),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (secim != "delete" || !mounted) return;
   
    // hata yakalamalı blok
    try {
      await SosyalServis.mesajSil(
        chatId: widget.chatId,
        messageId: messageId,
        mevcutMetin: mevcutMetin,
      );
      if (!mounted) return;
      vibeSnackbarGoster(context, "Mesaj silindi.", tip: VibeMesajTipi.basari);
    // hata yakala
    } catch (e) {
      if (!mounted) return;
      vibeSnackbarGoster(
        context,
        internetAwareErrorMessage(
          error: e,
          fallback: "Mesaj silinemedi.",
        ),
      );
    }
  }

  Widget _bekleyenMesajBalonu(String metin) {
    final vibe = context.vibe;
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Opacity(
              opacity: 0.7,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: vibe.primaryButton,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(14),
                    topRight: Radius.circular(14),
                    bottomLeft: Radius.circular(14),
                    bottomRight: Radius.circular(4),
                  ),
                  border: Border.all(color: vibe.cardBorder),
                ),
                child: Text(
                  metin,
                  softWrap: true,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: Text(
                "Gönderiliyor",
                style: TextStyle(
                  color: vibe.faintText,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Arayüzü oluştur
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vibe = context.vibe;
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? "";
    _akislariHazirla();

    return VibeGradientScaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.gomulu,
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 0,
        actions: [
          IconButton(
            onPressed: _sessizligiDegistir,
            icon: Icon(
              _sessiz ? Icons.notifications_off : Icons.notifications_none,
            ),
            tooltip: _sessiz ? "Sessize almayı kaldır" : "Sessize al",
          ),
        ],
        title: Row(
          children: [
            vibeAvatar(
              radius: 16,
              userId: widget.otherUid,
              photoUrl: widget.otherPhotoUrl,
              avatarKey: widget.otherAvatarKey,
              fallbackText: widget.otherUsername,
              emojiSize: 14,
            ),
            const SizedBox(width: 10),
            if (widget.gomulu)
              Flexible(
                child: Text(
                  widget.otherDisplayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            else
              Text(widget.otherDisplayName),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: _sohbetDocAkisi,
              builder: (context, chatSnapshot) {
                final sohbetVerisi =
                    chatSnapshot.data?.data() ?? const <String, dynamic>{};
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _mesajAkisi,
                  builder: (context, snapshot) {
                    final docs =
                        (snapshot.data?.docs ?? []).reversed.toList();
                    _gelenMesajIdleri = {for (final d in docs) d.id};
                    final bekleyenler = _bekleyenMesajlar
                        .where((b) => !_gelenMesajIdleri.contains(b.id))
                        .toList();
                    _yeniMesajlariOkunduIsaretle(docs);
                    final sonBendenMesaj = docs
                        .where((d) => (d.data()["senderUid"] ?? "") == myUid)
                        .lastOrNull;
                    final sonBendenMesajId = sonBendenMesaj?.id;

                    final bendenYeniMesaj = docs.isNotEmpty &&
                        docs.length > _oncekiMesajSayisi &&
                        (docs.last.data()["senderUid"] ?? "") == myUid;
                    _gerekirseAltaKaydir(
                      docs.length,
                      bendenYeniMesaj: bendenYeniMesaj,
                    );

                    if (docs.isEmpty && bekleyenler.isEmpty && snapshot.hasData) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            "Henüz mesaj yok.\nİlk mesajı sen gönder.",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: vibe.mutedText),
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  itemCount: docs.length + bekleyenler.length,
                  itemBuilder: (context, index) {
                    if (index >= docs.length) {
                      return _bekleyenMesajBalonu(
                        bekleyenler[index - docs.length].metin,
                      );
                    }
                    final m = docs[index].data();
                    final benden = (m["senderUid"] ?? "") == myUid;
                    final mesajId = docs[index].id;
                    final silinmis = m["deleted"] == true;
                    final mesajTipi = (m["mesajTipi"] ?? "text").toString();
                    final postId = (m["postId"] ?? "").toString();
                    final metin = silinmis
                        ? "Mesaj silindi"
                        : (m["metin"] ?? "").toString();
                    final icerik = mesajTipi == "post_forward" && !silinmis
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.article_outlined,
                                    size: 16,
                                    color: benden ? Colors.white70 : vibe.mutedText,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    "İletilen gönderi",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: benden
                                          ? Colors.white
                                          : theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                metin,
                                softWrap: true,
                                style: TextStyle(
                                  color: benden
                                      ? Colors.white
                                      : theme.colorScheme.onSurface,
                                ),
                              ),
                              if (postId.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: () => _gonderiDetayinaGit(postId),
                                  style: TextButton.styleFrom(
                                    foregroundColor:
                                        benden ? Colors.white : theme.colorScheme.primary,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 8,
                                    ),
                                    minimumSize: const Size(48, 48),
                                  ),
                                  child: const Text("Gönderiyi aç"),
                                ),
                              ],
                            ],
                          )
                        : silinmis
                            ? Text(
                                metin,
                                softWrap: true,
                                style: TextStyle(
                                  color: benden ? Colors.white70 : vibe.mutedText,
                                  fontStyle: FontStyle.italic,
                                ),
                              )
                            : HashtagMetin(
                                metin: metin,
                                mentionUidleri:
                                    SosyalServis.bahsetmeUidHaritasiParse(
                                  m["mentionUidleri"],
                                ),
                                style: TextStyle(
                                  color: benden
                                      ? Colors.white
                                      : theme.colorScheme.onSurface,
                                ),
                              );
                    final mesajSatiri = Align(
                      alignment:
                          benden ? Alignment.centerRight : Alignment.centerLeft,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        child: Column(
                          crossAxisAlignment: benden
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            _TarayiciMenusuKapali(
                              aktif: benden && !silinmis,
                              child: GestureDetector(
                              onLongPress: benden
                                  ? () => _mesajSilOnayiAc(
                                        messageId: mesajId,
                                        mevcutMetin:
                                            (m["metin"] ?? "").toString(),
                                      )
                                  : null,
                              onSecondaryTap: benden && !silinmis
                                  ? () => _mesajSilOnayiAc(
                                        messageId: mesajId,
                                        mevcutMetin:
                                            (m["metin"] ?? "").toString(),
                                      )
                                  : null,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                clipBehavior: Clip.antiAlias,
                                decoration: BoxDecoration(
                                  color: benden
                                      ? vibe.primaryButton
                                      : vibe.cardColor,
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(14),
                                    topRight: const Radius.circular(14),
                                    bottomLeft:
                                        Radius.circular(benden ? 14 : 4),
                                    bottomRight:
                                        Radius.circular(benden ? 4 : 14),
                                  ),
                                  border: Border.all(color: vibe.cardBorder),
                                ),
                                child: icerik,
                              ),
                            ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 4, bottom: 8),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (benden &&
                                      sonBendenMesajId == mesajId) ...[
                                    Text(
                                      _mesajGorulduMu(m, sohbetVerisi)
                                          ? "Görüldü"
                                          : "Gönderildi",
                                      style: TextStyle(
                                        color: vibe.faintText,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                  Text(
                                    _saatYaz(m["createdAt"]),
                                    style: TextStyle(
                                      color: vibe.faintText,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );

                    if (!_sohbetGunDegisti(docs, index)) {
                      return mesajSatiri;
                    }

                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8, top: 4),
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: vibe.inputFill,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: vibe.cardBorder),
                              ),
                              child: Text(
                                _sohbetTarihBasligi(m["createdAt"]),
                                style: TextStyle(
                                  color: vibe.subtleText,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                        mesajSatiri,
                      ],
                    );
                  },
                );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              margin: const EdgeInsets.fromLTRB(10, 6, 10, 10),
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
              decoration: BoxDecoration(
                color: vibe.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: vibe.cardBorder),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: BahsetmeMetinAlani(
                      controller: _mesajController,
                      haricUid: myUid,
                      maxLines: 2,
                      enterIleGonder: _mesajGonder,
                      style: TextStyle(color: theme.colorScheme.onSurface),
                      decoration: InputDecoration(
                        hintText: "Mesaj yaz...",
                        hintStyle: TextStyle(color: vibe.mutedText),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        filled: true,
                        fillColor: vibe.inputFill,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  maestroButton(
                    label: MaestroSemantics.mesajGonder,
                    onTap: _mesajGonder,
                    child: IconButton(
                    onPressed: _mesajGonder,
                    style: IconButton.styleFrom(
                      backgroundColor: vibe.primaryButton,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(VibeIkon.gonder, color: Colors.white),
                  ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Web'de sağ tık kendi menümüzü açarken tarayıcı menüsü üstüne açılmasın.
class _TarayiciMenusuKapali extends StatefulWidget {
  const _TarayiciMenusuKapali({required this.aktif, required this.child});

  final bool aktif;
  final Widget child;

  @override
  State<_TarayiciMenusuKapali> createState() => _TarayiciMenusuKapaliState();
}

class _TarayiciMenusuKapaliState extends State<_TarayiciMenusuKapali> {
  bool _kapali = false;

  void _kapat() {
    if (_kapali) return;
    _kapali = true;
    unawaited(BrowserContextMenu.disableContextMenu());
  }

  void _ac() {
    if (!_kapali) return;
    _kapali = false;
    unawaited(BrowserContextMenu.enableContextMenu());
  }

  @override
  void didUpdateWidget(covariant _TarayiciMenusuKapali oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.aktif) _ac();
  }

  @override
  void dispose() {
    _ac();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb || !widget.aktif) return widget.child;
    return MouseRegion(
      onEnter: (_) => _kapat(),
      onExit: (_) => _ac(),
      child: widget.child,
    );
  }
}
