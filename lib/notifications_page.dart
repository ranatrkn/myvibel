// Sosyal bildirimler: beğeni, yorum, takip, bahsetme ve takip isteği aksiyonları
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:vibe_life/app_theme.dart';
import 'package:vibe_life/error_messages.dart';
import 'package:vibe_life/feed_page.dart';
import 'package:vibe_life/messages_page.dart';
import 'package:vibe_life/sosyal_servis.dart';
import 'package:vibe_life/utils/tarih_saat.dart';
import 'package:vibe_life/user_profile_page.dart';
import 'package:vibe_life/vibe_snackbar.dart';
import 'package:vibe_life/widgets/vibe_gradient_scaffold.dart';

// Bildirimler sayfası
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override

  State<NotificationsPage> createState() => NotificationsPageState();
}

// Bildirimler sayfası durumu
class NotificationsPageState extends State<NotificationsPage>
    with WidgetsBindingObserver {
  Set<String> _engelIdleri = {}; // engelli kullanıcı uid kümesi

  // Widget ilk yüklendiğinde çalışır
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _engelleriYukle();
  }

  // Abonelik ve kontrolcüleri temizle
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Uygulama ön plana gelince engelleri yenile
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _engelleriYukle();
    }
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

  // Bildirimi okundu işaretle
  Future<void> _bildirimiOkunduIsaretle(String uid, String bildirimId) async {
    await SosyalServis.bildirimOkunduYap(uid, bildirimId);
  }

  // Bildirim başlığı metni
  String _bildirimBasligi(Map<String, dynamic> data) {
    final kullaniciAdi = data["gonderenKullaniciAdi"] ?? "Bir kullanıcı";

    // tip/durum seçimi
    switch (data["tip"]) {
      case "like":
        return "@$kullaniciAdi gönderini beğendi";
      case "comment":
        return "@$kullaniciAdi gönderine yorum yaptı";
      case "follow":
        return "@$kullaniciAdi seni takip etmeye başladı";
      case "follow_request":
        return "@$kullaniciAdi sana takip isteği gönderdi";
      case "follow_accepted":
        return "@$kullaniciAdi takip isteğini kabul etti";
      case "message":
        return "@$kullaniciAdi sana mesaj gönderdi";
      case "mention":
        return "@$kullaniciAdi senden bahsetti";
      default:
        final metin = data["metin"] ?? "";
        return metin.isNotEmpty ? "@$kullaniciAdi $metin" : "@$kullaniciAdi";
    }
  }

  // Bildirim tipine göre ikon
  IconData _bildirimIkonu(String tip) {
    // tip/durum seçimi
    switch (tip) {
      case "like":
        return Icons.favorite;
      case "comment":
        return Icons.chat_bubble_outline;
      case "follow":
      case "follow_accepted":
        return Icons.person_add_alt_1;
      case "follow_request":
        return Icons.person_add;
      case "message":
        return Icons.mail_outline;
      case "mention":
        return Icons.alternate_email;
      default:
        return Icons.notifications_none;
    }
  }

  // Gönderi bildirimi mi
  bool _gonderiBildirimiMi(String tip) {
    return tip == "like" || tip == "comment";
  }

  // Takip bildirimi mi
  bool _takipBildirimiMi(String tip) {
    return tip == "follow" ||
        tip == "follow_request" ||
        tip == "follow_accepted";
  }

  // Bahsetme bildirimi mi
  bool _bahsetmeBildirimiMi(String tip) {
    return tip == "mention";
  }

  // Bildirim bölüm başlığı
  Widget _bolumBasligi({
    required BuildContext context,
    required String baslik,
    required String aciklama,
    required bool ilkBolum,
  }) {
    final theme = Theme.of(context);
    final vibe = context.vibe;

    return Padding(
      padding: EdgeInsets.fromLTRB(4, ilkBolum ? 4 : 22, 4, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            baslik,
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            aciklama,
            style: TextStyle(
              color: vibe.mutedText,
              fontSize: 13,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  // Tek bildirim kartı
  Widget _bildirimKarti({
    required BuildContext context,
    required User user,
    required QueryDocumentSnapshot<Map<String, dynamic>> doc,
  }) {
    final theme = Theme.of(context);
    final vibe = context.vibe;
    final data = doc.data();
    final tip = data["tip"] ?? "";
    final okundu = data["okundu"] == true;
    final gonderenUid = data["gonderenUid"] ?? "";
    final postId = data["postId"]?.toString() ?? "";
    final chatId = data["chatId"]?.toString() ?? "";
    final postMetin = data["postMetin"]?.toString() ?? "";

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: okundu
            ? vibe.cardColor
            : theme.colorScheme.primary.withOpacity(
                vibe.isDark ? 0.12 : 0.08,
              ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: okundu
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
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _profilAc(
                    gonderenUid: gonderenUid,
                    uid: user.uid,
                    bildirimId: doc.id,
                  ),
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
                        SizedBox(
                          width: MediaQuery.of(context).size.width - 150,
                          child: Text(
                            _bildirimBasligi(data),
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                              fontWeight:
                                  okundu ? FontWeight.normal : FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                if (tip == "like" || tip == "comment" || tip == "mention")
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      color: vibe.mutedText,
                      size: 20,
                    ),
                    onPressed: () async {
                      await SosyalServis.bildirimSil(
                        user.uid,
                        doc.id,
                      );
                    },
                  ),
              ],
            ),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: tip == "mention"
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
                : (tip == "like" || tip == "comment")
                    ? () => _gonderiDetayinaGit(
                          postId: postId,
                          currentUserId: user.uid,
                          uid: user.uid,
                          bildirimId: doc.id,
                        )
                    : tip == "message"
                        ? () => _sohbeteGit(
                              chatId: chatId,
                              gonderenUid: gonderenUid,
                              uid: user.uid,
                              bildirimId: doc.id,
                            )
                        : (tip == "follow" ||
                                tip == "follow_accepted" ||
                                tip == "follow_request")
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
                  if (postMetin.isNotEmpty &&
                      (tip == "like" ||
                          tip == "comment" ||
                          tip == "mention" ||
                          tip == "message"))
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: vibe.inputFill,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: vibe.cardBorder),
                        ),
                        child: Text(
                          postMetin,
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
          if (tip == "follow_request" && gonderenUid.isNotEmpty)
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

    final bolumler = <({String baslik, String aciklama, List docs})>[
      (
        baslik: "Gönderi",
        aciklama: "Paylaştığın gönderiye yapılan etkileşimler",
        docs: gonderiBildirimleri,
      ),
      (
        baslik: "Takip",
        aciklama: "Takip istekleri ve takip isteği kabul bildirimleri",
        docs: takipBildirimleri,
      ),
      (
        baslik: "Bahsetmeler",
        aciklama: "Senden bahsedilen gönderiler ve yorumlar",
        docs: bahsetmeBildirimleri,
      ),
    ];

    final ogeler = <Widget>[];
    var ilkBolum = true;

    for (final bolum in bolumler) {
      if (bolum.docs.isEmpty) continue;

      ogeler.add(
        _bolumBasligi(
          context: context,
          baslik: bolum.baslik,
          aciklama: bolum.aciklama,
          ilkBolum: ilkBolum,
        ),
      );
      ilkBolum = false;

      for (final doc in bolum.docs) {
        ogeler.add(
          _bildirimKarti(
            context: context,
            user: user,
            doc: doc,
          ),
        );
      }
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

    await _bildirimiOkunduIsaretle(uid, bildirimId);

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _BildirimPostSayfasi(
          postId: postId,
          currentUserId: currentUserId,
        ),
      ),
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

    await _bildirimiOkunduIsaretle(uid, bildirimId);
    final gonderen = await FirebaseFirestore.instance
        .collection("users")
        .doc(gonderenUid)
        .get();
    final data = gonderen.data() ?? {};

    if (!mounted) return;
    await Navigator.push(
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
  }

  // Kullanıcı profiline git
  Future<void> _profilAc({
    required String gonderenUid,
    required String uid,
    required String bildirimId,
  }) async {
    if (gonderenUid.isEmpty) return;
    await _bildirimiOkunduIsaretle(uid, bildirimId);
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserProfilePage(userId: gonderenUid),
      ),
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
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    "Bildirimler",
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => SosyalServis.tumBildirimleriOkunduYap(user.uid),
                  child: const Text("Tümünü okundu işaretle"),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection("users")
                  .doc(user.uid)
                  .collection("notifications")
                  .orderBy("createdAt", descending: true)
                  .limit(80)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: theme.colorScheme.primary,
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        internetAwareErrorMessage(
                          error: snapshot.error ?? "Bildirimler yüklenemedi.",
                          fallback: "Bildirimler yüklenemedi.",
                        ),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: vibe.subtleText),
                      ),
                    ),
                  );
                }

                final docs = snapshot.data?.docs ?? [];
                final filtreli = docs
                    .where((d) {
                      final data = d.data();
                      final tip = (data["tip"] ?? "").toString();
                      if (tip == "message") return false;
                      return !_engelIdleri.contains(data["gonderenUid"] ?? "");
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
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: listeOgeleri,
                );
              },
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

// Bildirimden açılan gönderi detayı
class _BildirimPostSayfasi extends StatelessWidget {
  const _BildirimPostSayfasi({
    required this.postId,
    required this.currentUserId,
  });

  final String postId; // gönderi kimliği
  final String currentUserId; // giriş yapmış kullanıcı uid

  // Dinamik değeri int'e çevir
  int _intDeger(dynamic value, int varsayilan) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return varsayilan;
  }

  // Arayüzü oluştur
  @override
  Widget build(BuildContext context) {
    return VibeGradientScaffold(
      appBar: AppBar(title: const Text("Gönderi")),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection("posts").doc(postId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final post = snapshot.data?.data();
          if (post == null) {
            return const Center(child: Text("Gönderi bulunamadı."));
          }

          return ListView(
            padding: const EdgeInsets.only(top: 8, bottom: 20),
            children: [
              PostCard(
                key: ValueKey(postId),
                postId: postId,
                postOwnerId: post["userId"] ?? "",
                kullaniciAdi: post["kullaniciAdi"] ?? "Vibe Kullanıcısı",
                metin: post["metin"] ?? "",
                mentionUidleri: SosyalServis.bahsetmeUidHaritasiParse(
                  post["mentionUidleri"],
                ),
                photoUrl: post["photoUrl"] ?? "",
                avatarKey: post["avatarKey"] ?? "",
                baslangicBegeniSayisi: _intDeger(post["begeniSayisi"], 0),
                baslangicYorumSayisi: _intDeger(post["yorumSayisi"], 0),
                userId: currentUserId,
                createdAt: post["createdAt"],
                onKendiProfilineGit: () => Navigator.pop(context),
              ),
            ],
          );
        },
      ),
    );
  }
}
