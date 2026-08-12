// DM sohbet listesi, yeni sohbet başlatma ve birebir mesajlaşma ekranı
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibe_life/app_theme.dart';
import 'package:vibe_life/error_messages.dart';
import 'package:vibe_life/gonderi_detay_sayfasi.dart';
import 'package:vibe_life/sosyal_servis.dart';
import 'package:vibe_life/vibe_snackbar.dart';
import 'package:vibe_life/widgets/vibe_avatar.dart';
import 'package:vibe_life/widgets/hashtag_metin.dart';
import 'package:vibe_life/widgets/bahsetme_metin_alani.dart';

// Timestamp'ten saat:dakika üret
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
  const MessagesPage({super.key});

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

  // Widget ilk yüklendiğinde çalışır
  @override
  void initState() {
    super.initState();
    _yerelDmDurumlariniYukle();
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

            final publicSnap = await firestore
                .collection("users")
                .where("hesapGizli", isEqualTo: false)
                .limit(genelKullaniciLimiti)
                .get();

            final kullanicilarMap = <String, Map<String, dynamic>>{};
            for (final doc in publicSnap.docs) {
              if (doc.id == current.uid) continue;
              kullanicilarMap[doc.id] = doc.data();
            }

            final takipEdilenIdler =
                await SosyalServis.takipEdilenIdleriGetir(current.uid);
            final takipliOrnek = takipEdilenIdler
                .where((id) => id.isNotEmpty && id != current.uid)
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
                  .get();
              for (final doc in snap.docs) {
                if (doc.id == current.uid) continue;
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
                              child: CircularProgressIndicator(
                                color: theme.colorScheme.primary,
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
                                          final navigator = Navigator.of(context);
                                         
                                          // hata yakalamalı blok
                                          try {
                                            final chatId = await SosyalServis
                                                .sohbetIdGetirVeyaOlustur(uid);
                                            if (!mounted) return;
                                            navigator.pop();
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
                                          // hata yakala
                                          } catch (e) {
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

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
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
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: SosyalServis.sohbetlerim(user.uid),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child:
                          CircularProgressIndicator(color: theme.colorScheme.primary),
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

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 20),
                    itemCount: gorunenDocs.length,
                    itemBuilder: (context, index) {
                      final chatDoc = gorunenDocs[index];
                      final chat = chatDoc.data();
                      final participants = List<String>.from(chat["participants"] ?? []);
                      final otherUid = participants.firstWhere(
                        (id) => id != user.uid,
                        orElse: () => "",
                      );
                      if (otherUid.isEmpty) return const SizedBox.shrink();

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

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: vibe.cardDecoration(radius: 18),
                        child: ListTile(
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatPage(
                                  chatId: chatDoc.id,
                                  otherUid: otherUid,
                                  otherDisplayName: adSoyad,
                                  otherUsername: kullaniciAdi,
                                  otherPhotoUrl: photoUrl,
                                  otherAvatarKey: avatarKey,
                                ),
                              ),
                            );
                            await _yerelDmDurumlariniYukle();
                          },
                          onLongPress: () =>
                              _sohbetSecenekleriAc(chatId: chatDoc.id, chat: chat),
                          leading: vibeAvatar(
                            radius: 22,
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
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
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
  });

  final String chatId; // sohbet kimliği
  final String otherUid; // karşı taraf uid
  final String otherDisplayName; // karşı taraf görünen adı
  final String otherUsername; // karşı taraf kullanıcı adı
  final String otherPhotoUrl; // karşı taraf foto url
  final String otherAvatarKey; // karşı taraf avatar anahtarı

  @override

  State<ChatPage> createState() => _ChatPageState();
}

// Sohbet ekranı durumu
class _ChatPageState extends State<ChatPage> {
  final TextEditingController _mesajController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _gonderiliyor = false; // mesaj gönderiliyor mu
  bool _sessiz = false; // sohbet sessize alınmış mı
  int _oncekiMesajSayisi = 0; // önceki mesaj sayısı (kaydırma için)
  bool _otomatikKaydir = true; // alta otomatik kaydır mı
  int _sonOkunduMs = 0; // son okundu zaman damgası (ms)
  String? _sonOkunduIsaretlenenMesajId; // okundu işaretlenen son mesaj

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
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GonderiDetaySayfasi(
          postId: postId,
          currentUserId: myUid,
        ),
      ),
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
    if (_gonderiliyor) return;
    setState(() => _gonderiliyor = true);
   
    // hata yakalamalı blok
    try {
      await SosyalServis.mesajGonder(
        chatId: widget.chatId,
        hedefUid: widget.otherUid,
        metin: _mesajController.text,
      );
      _mesajController.clear();
    // hata yakala
    } catch (e) {
      if (!mounted) return;
      vibeSnackbarGoster(
        context,
        internetAwareErrorMessage(
          error: e,
          fallback: "Mesaj gönderilemedi.",
        ),
      );
    // temizlik
    } finally {
      if (mounted) setState(() => _gonderiliyor = false);
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

  // Arayüzü oluştur
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vibe = context.vibe;
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? "";

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
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
              photoUrl: widget.otherPhotoUrl,
              avatarKey: widget.otherAvatarKey,
              fallbackText: widget.otherUsername,
              emojiSize: 14,
            ),
            const SizedBox(width: 10),
            Text(widget.otherDisplayName),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection("chats")
                  .doc(widget.chatId)
                  .snapshots(),
              builder: (context, chatSnapshot) {
                final sohbetVerisi =
                    chatSnapshot.data?.data() ?? const <String, dynamic>{};
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: SosyalServis.sohbetMesajlari(widget.chatId),
                  builder: (context, snapshot) {
                    final docs = snapshot.data?.docs ?? [];
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

                    return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
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
                            GestureDetector(
                              onLongPress: benden
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
                  IconButton(
                    onPressed: _gonderiliyor ? null : _mesajGonder,
                    style: IconButton.styleFrom(
                      backgroundColor: vibe.primaryButton,
                      foregroundColor: Colors.white,
                    ),
                    icon: _gonderiliyor
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send, color: Colors.white),
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
