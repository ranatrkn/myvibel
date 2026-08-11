// Tek gönderi kartı: beğeni, yorum, iletme, şikayet ve engelleme
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:vibe_life/app_theme.dart';
import 'package:vibe_life/error_messages.dart';
import 'package:vibe_life/etiket_navigasyon.dart';
import 'package:vibe_life/profile_page.dart' hide tarihSaatYaz;
import 'package:vibe_life/sosyal_servis.dart';
import 'package:vibe_life/user_profile_page.dart';
import 'package:vibe_life/utils/tarih_saat.dart';
import 'package:vibe_life/vibe_snackbar.dart';
import 'package:vibe_life/widgets/gonderi_ilet_paneli.dart';
import 'package:vibe_life/widgets/hashtag_metin.dart';
import 'package:vibe_life/widgets/post_begeni_yardimci.dart';
import 'package:vibe_life/widgets/vibe_avatar.dart';
import 'package:vibe_life/widgets/yorum_paneli.dart';

// Gönderi kartı widget'ı
class PostCard extends StatefulWidget {
  final String postId; // Gönderi kimliği
  final String postOwnerId; // Gönderi sahibi uid
  final String kullaniciAdi; // Görünen kullanıcı adı
  final String metin; // Gönderi metni
  final Map<String, String> mentionUidleri; // @bahsetme uid haritası
  final String photoUrl; // Profil fotoğrafı url
  final String avatarKey; // Avatar anahtarı
  final int baslangicBegeniSayisi; // İlk beğeni sayısı
  final int baslangicYorumSayisi; // İlk yorum sayısı
  final String userId; // Oturum açmış kullanıcı uid
  final dynamic createdAt; // Oluşturulma zamanı
  final VoidCallback? onKendiProfilineGit; // Kendi profiline geçiş callback

  const PostCard({
    super.key,
    required this.postId,
    required this.postOwnerId,
    required this.kullaniciAdi,
    required this.metin,
    this.mentionUidleri = const {},
    required this.photoUrl,
    required this.avatarKey,
    required this.baslangicBegeniSayisi,
    required this.baslangicYorumSayisi,
    required this.userId,
    required this.createdAt,
    this.onKendiProfilineGit,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool gizleKart = false; // Engelleme sonrası kartı gizle
  late int yorumSayisi; // Güncel yorum sayısı
  late PostBegeniDurumuYonetici _begeni;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _postAbonelik;

  void _begeniYoneticiOlustur() {
    _begeni.durdur();
    _begeni = PostBegeniDurumuYonetici(
      postId: widget.postId,
      userId: widget.userId,
      postOwnerId: widget.postOwnerId,
      baslangicBegeniSayisi: widget.baslangicBegeniSayisi,
    );
    _begeni.baslat(yenile: () {
      if (mounted) setState(() {});
    });
  }

  @override
  void initState() {
    super.initState();
    yorumSayisi = widget.baslangicYorumSayisi;
    _begeni = PostBegeniDurumuYonetici(
      postId: widget.postId,
      userId: widget.userId,
      postOwnerId: widget.postOwnerId,
      baslangicBegeniSayisi: widget.baslangicBegeniSayisi,
    );
    _begeni.baslat(yenile: () {
      if (mounted) setState(() {});
    });
    _postSayaclariniDinle();
  }

  @override
  void didUpdateWidget(covariant PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.postId != widget.postId ||
        oldWidget.userId != widget.userId ||
        oldWidget.postOwnerId != widget.postOwnerId) {
      _begeniYoneticiOlustur();
      _postSayaclariniDinle();
    }
    if (oldWidget.baslangicBegeniSayisi != widget.baslangicBegeniSayisi) {
      _begeni.guncelle(yeniBaslangicBegeni: widget.baslangicBegeniSayisi);
    }
    if (oldWidget.baslangicYorumSayisi != widget.baslangicYorumSayisi) {
      setState(() {
        yorumSayisi = widget.baslangicYorumSayisi;
      });
    }
  }

  void _postSayaclariniDinle() {
    _postAbonelik?.cancel();
    _postAbonelik = FirebaseFirestore.instance
        .collection("posts")
        .doc(widget.postId)
        .snapshots()
        .listen(
      (postDoc) {
        if (!mounted) return;
        final data = postDoc.data();
        if (data == null) return;

        final yeniBegeni = PostBegeniDurumuYonetici.sayacDeger(
          data["begeniSayisi"],
          _begeni.begeniSayisi,
        );
        final yeniYorum = PostBegeniDurumuYonetici.sayacDeger(
          data["yorumSayisi"],
          yorumSayisi,
        );
        if (yeniBegeni == _begeni.begeniSayisi && yeniYorum == yorumSayisi) {
          return;
        }

        _begeni.sayacSenkronizeEt(yeniBegeni);
        if (mounted && yeniYorum != yorumSayisi) {
          setState(() {
            yorumSayisi = yeniYorum;
          });
        }
      },
      onError: (Object e) {
        debugPrint("post sayac dinleyici hatasi (${widget.postId}): $e");
      },
    );
  }

  @override
  void dispose() {
    _begeni.durdur();
    _postAbonelik?.cancel();
    super.dispose();
  }

  // Gönderi sahibinin profiline git
  void kullaniciProfilineGit() {
    if (widget.postOwnerId.isEmpty) return;

    if (widget.postOwnerId == widget.userId) {
      if (widget.onKendiProfilineGit != null) {
        widget.onKendiProfilineGit!();
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const ProfilePage(),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserProfilePage(userId: widget.postOwnerId),
      ),
    );
  }

  // Beğeni ekle/kaldır (optimistik UI)
  Future<void> begeniyiDegistir() => _begeni.degistir(context);

  // Yorum panelini alt sayfa olarak aç
  void yorumPaneliniAc() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.vibe.sheetBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (context) {
        return YorumPaneli(
          postId: widget.postId,
          postOwnerId: widget.postOwnerId,
          userId: widget.userId,
          onYorumEklendi: () {
            if (!mounted) return;
            setState(() {
              yorumSayisi += 1;
            });
          },
        );
      },
    );
  }

  // Şikayet sebebi seçim diyaloğu
  Future<String?> _sikayetSebebiSec() async {
    String? secim;
    await showDialog<void>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text("Şikayet Sebebi"),
        children: [
          _sikayetSecenek("Spam", (v) => secim = v),
          _sikayetSecenek("Hakaret/Nefret", (v) => secim = v),
          _sikayetSecenek("Uygunsuz İçerik", (v) => secim = v),
          _sikayetSecenek("Diğer", (v) => secim = v),
        ],
      ),
    );
    return secim;
  }

  Widget _sikayetSecenek(String metin, ValueChanged<String> sec) {
    return SimpleDialogOption(
      onPressed: () {
        sec(metin);
        Navigator.pop(context);
      },
      child: Text(metin),
    );
  }

  // Onay diyaloğu
  Future<bool> _onayDialogu({
    required String baslik,
    required String mesaj,
    required String onayMetni,
  }) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(baslik),
        content: Text(mesaj),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Vazgeç"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(onayMetni),
          ),
        ],
      ),
    );
    return onay == true;
  }

  // Gönderiyi şikayet et
  Future<void> _postuSikayetEt() async {
    final sebep = await _sikayetSebebiSec();
    if (sebep == null) return;
    final onay = await _onayDialogu(
      baslik: "Gönderiyi Şikayet Et",
      mesaj: "Bu gönderiyi '$sebep' sebebiyle şikayet etmek istiyor musun?",
      onayMetni: "Şikayet Et",
    );
    if (!onay) return;
    try {
      await SosyalServis.gonderiSikayetEt(
        postId: widget.postId,
        postOwnerId: widget.postOwnerId,
        sebep: sebep,
      );
      if (!mounted) return;
      vibeSnackbarGoster(
        context,
        "Gönderi şikayet edildi.",
        tip: VibeMesajTipi.basari,
      );
    } catch (e) {
      if (!mounted) return;
      vibeSnackbarGoster(
        context,
        internetAwareErrorMessage(
          error: e,
          fallback: "Şikayet gönderilemedi.",
        ),
      );
    }
  }

  // Gönderiyi DM ile ilet
  Future<void> _gonderiyiIlet() async {
    await gonderiIletPaneliniGoster(
      context: context,
      postId: widget.postId,
      postMetin: widget.metin,
      postKullaniciAdi: widget.kullaniciAdi,
    );
  }

  // Gönderi sahibini engelle
  Future<void> _kullaniciyiEngelle() async {
    final onay = await _onayDialogu(
      baslik: "Kullanıcıyı Engelle",
      mesaj:
          "Bu kullanıcıyı engellersen gönderileri ve yorumları sana görünmez. Devam edilsin mi?",
      onayMetni: "Engelle",
    );
    if (!onay) return;

    try {
      await SosyalServis.engelleKullanici(widget.postOwnerId);
      if (!mounted) return;
      setState(() {
        gizleKart = true;
      });
      vibeSnackbarGoster(
        context,
        "Kullanıcı engellendi.",
        tip: VibeMesajTipi.basari,
      );
    } catch (e) {
      if (!mounted) return;
      vibeSnackbarGoster(
        context,
        internetAwareErrorMessage(
          error: e,
          fallback: "Engelleme başarısız.",
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (gizleKart) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final vibe = context.vibe;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      decoration: vibe.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Kullanıcı başlığı ve menü
          ListTile(
            onTap: kullaniciProfilineGit,
            leading: vibeAvatar(
              radius: 20,
              photoUrl: widget.photoUrl,
              avatarKey: widget.avatarKey,
              fallbackText: widget.kullaniciAdi,
              emojiSize: 18,
              fallbackIconSize: 20,
              fallbackForegroundColor: theme.colorScheme.onPrimary,
            ),
            title: Text(
              widget.kullaniciAdi,
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              tarihSaatYaz(widget.createdAt),
              style: TextStyle(color: vibe.faintText, fontSize: 12),
            ),
            trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == "report_post") {
                        _postuSikayetEt();
                      } else if (value == "block_user") {
                        _kullaniciyiEngelle();
                      } else if (value == "share_post") {
                        _gonderiyiIlet();
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: "share_post",
                        child: Text("Gönderiyi İlet"),
                      ),
                      // Başkasının gönderisinde şikayet/engel seçenekleri
                      if (widget.postOwnerId != widget.userId) ...[
                        const PopupMenuItem(
                          value: "report_post",
                          child: Text("Gönderiyi Şikayet Et"),
                        ),
                        const PopupMenuItem(
                          value: "block_user",
                          child: Text("Kullanıcıyı Engelle"),
                        ),
                      ],
                    ],
                  ),
          ),
          // Gönderi metni (hashtag ve mention destekli)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
            child: HashtagMetin(
              metin: widget.metin,
              mentionUidleri: widget.mentionUidleri,
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
              onHashtagTap: (tag) => etiketSayfasinaGit(context, tag),
            ),
          ),
          // Beğeni, yorum ve ilet butonları
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(28),
                  onTap: begeniyiDegistir,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _begeni.begenildi ? Icons.favorite : Icons.favorite_border,
                          color: Colors.redAccent,
                          size: 26,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "${_begeni.begeniSayisi}",
                          style: TextStyle(
                            color: vibe.mutedText,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 18),
                InkWell(
                  borderRadius: BorderRadius.circular(28),
                  onTap: yorumPaneliniAc,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          color: vibe.mutedText,
                          size: 24,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "$yorumSayisi",
                          style: TextStyle(
                            color: vibe.mutedText,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                InkWell(
                  borderRadius: BorderRadius.circular(28),
                  onTap: _gonderiyiIlet,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    child: Icon(
                      Icons.send_outlined,
                      color: vibe.mutedText,
                      size: 24,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
