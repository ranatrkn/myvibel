// Gönderi yorumları alt paneli: listeleme, ekleme, şikayet ve engelleme
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:vibe_life/app_theme.dart';
import 'package:vibe_life/error_messages.dart';
import 'package:vibe_life/etiket_navigasyon.dart';
import 'package:vibe_life/puan_animasyon.dart';
import 'package:vibe_life/sosyal_servis.dart';
import 'package:vibe_life/utils/tarih_saat.dart';
import 'package:vibe_life/vibe_snackbar.dart';
import 'package:vibe_life/widgets/bahsetme_metin_alani.dart';
import 'package:vibe_life/widgets/hashtag_metin.dart';
import 'package:vibe_life/widgets/vibe_avatar.dart';

// Yorum paneli widget'ı
class YorumPaneli extends StatefulWidget {
  final String postId; // Hedef gönderi kimliği
  final String postOwnerId; // Gönderi sahibi uid
  final String userId; // Oturum açmış kullanıcı uid
  final VoidCallback onYorumEklendi; // Yorum eklendiğinde üst bileşene bildir

  const YorumPaneli({
    super.key,
    required this.postId,
    required this.postOwnerId,
    required this.userId,
    required this.onYorumEklendi,
  });

  @override
  State<YorumPaneli> createState() => _YorumPaneliState();
}

class _YorumPaneliState extends State<YorumPaneli> {
  final TextEditingController yorumController = TextEditingController(); // Yorum girişi
  bool isLoading = false; // Gönderim devam ediyor mu

  @override
  void dispose() {
    yorumController.dispose();
    super.dispose();
  }

  // Yeni yorumu Firestore'a kaydet
  Future<void> yorumEkle() async {
    final metin = yorumController.text.trim();

    if (metin.isEmpty) return;

    setState(() {
      isLoading = true;
    });

    try {
      await SosyalServis.yorumEkle(
        postId: widget.postId,
        postOwnerId: widget.postOwnerId,
        currentUserId: widget.userId,
        metin: metin,
      );

      yorumController.clear();
      widget.onYorumEklendi(); // Sayaç güncelle

      // Başkasının gönderisine yorumda puan animasyonu
      if (mounted && widget.userId != widget.postOwnerId) {
        puanAnimasyonuGoster(context, 3);
      }
    } catch (e) {
      if (mounted) {
        vibeSnackbarGoster(
          context,
          internetAwareErrorMessage(
            error: e,
            fallback: "Yorum eklenemedi.",
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
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

  // Tek şikayet seçeneği satırı
  Widget _sikayetSecenek(String metin, ValueChanged<String> sec) {
    return SimpleDialogOption(
      onPressed: () {
        sec(metin);
        Navigator.pop(context);
      },
      child: Text(metin),
    );
  }

  // Onay diyaloğu (evet/hayır)
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

  // Yorumu şikayet et
  Future<void> _yorumuSikayetEt({
    required String yorumId,
    required String yorumSahibiUid,
  }) async {
    final sebep = await _sikayetSebebiSec();
    if (sebep == null) return;
    final onay = await _onayDialogu(
      baslik: "Yorumu Şikayet Et",
      mesaj: "Bu yorumu '$sebep' sebebiyle şikayet etmek istiyor musun?",
      onayMetni: "Şikayet Et",
    );
    if (!onay) return;
    try {
      await SosyalServis.yorumSikayetEt(
        postId: widget.postId,
        yorumId: yorumId,
        yorumSahibiUid: yorumSahibiUid,
        sebep: sebep,
      );
      if (!mounted) return;
      vibeSnackbarGoster(
        context,
        "Yorum şikayet edildi.",
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

  // Yorum sahibini engelle ve paneli kapat
  Future<void> _kullaniciyiEngelle(String hedefUid) async {
    final onay = await _onayDialogu(
      baslik: "Kullanıcıyı Engelle",
      mesaj:
          "Bu kullanıcıyı engellersen yorum paneli kapanır ve bu kullanıcı sana görünmez. Devam edilsin mi?",
      onayMetni: "Engelle",
    );
    if (!onay) return;

    try {
      await SosyalServis.engelleKullanici(hedefUid);
      if (!mounted) return;
      vibeSnackbarGoster(
        context,
        "Kullanıcı engellendi.",
        tip: VibeMesajTipi.basari,
      );
      Navigator.pop(context);
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
    final altBosluk = MediaQuery.of(context).viewInsets.bottom; // Klavye yüksekliği
    final theme = Theme.of(context);
    final vibe = context.vibe;

    final mq = MediaQuery.of(context);
    final normalYukseklik = mq.size.height * 0.72;
    // Klavye açıkken panel yüksekliğini ayarla
    final klavyeAcikYukseklik =
        (mq.size.height - altBosluk).clamp(300.0, normalYukseklik).toDouble();

    return Padding(
      padding: EdgeInsets.only(bottom: altBosluk),
      child: SizedBox(
        height: altBosluk > 0 ? klavyeAcikYukseklik : normalYukseklik,
        child: Column(
          children: [
            const SizedBox(height: 10),
            // Sürükleme tutamacı
            Container(
              width: 42,
              height: 5,
              decoration: BoxDecoration(
                color: vibe.cardBorder,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              "Yorumlar",
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Divider(color: theme.dividerColor),
            // Canlı yorum listesi
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection("posts")
                    .doc(widget.postId)
                    .collection("comments")
                    .orderBy("createdAt", descending: false)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(
                        color: theme.colorScheme.primary,
                      ),
                    );
                  }

                  final comments = snapshot.data?.docs ?? [];

                  if (comments.isEmpty) {
                    return Center(
                      child: Text(
                        "Henüz yorum yok.",
                        style: TextStyle(color: theme.colorScheme.onSurface),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: comments.length,
                    itemBuilder: (context, index) {
                      final yorum = comments[index].data();
                      // Raporlanmış yorumları gizle
                      if (yorum["raporNedeniyleGizli"] == true) {
                        return const SizedBox.shrink();
                      }
                      final yorumId = comments[index].id;
                      final yorumSahibiUid = (yorum["userId"] ?? "").toString();
                      // Kendi yorumunda menü gösterme
                      final menuGoster = yorumSahibiUid.isNotEmpty &&
                          yorumSahibiUid != widget.userId;

                      return ListTile(
                        leading: vibeAvatar(
                          radius: 18,
                          photoUrl: (yorum["photoUrl"] ?? "").toString(),
                          avatarKey: (yorum["avatarKey"] ?? "").toString(),
                          fallbackText: yorum["kullaniciAdi"]?.toString() ??
                              "Vibe Kullanıcısı",
                          emojiSize: 16,
                          fallbackIconSize: 18,
                        ),
                        title: Text(
                          yorum["kullaniciAdi"] ?? "Vibe Kullanıcısı",
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            HashtagMetin(
                              metin: yorum["metin"] ?? "",
                              mentionUidleri: SosyalServis.bahsetmeUidHaritasiParse(
                                yorum["mentionUidleri"],
                              ),
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                                fontWeight: FontWeight.w500,
                              ),
                              onHashtagTap: (tag) =>
                                  etiketSayfasinaGit(context, tag),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              tarihSaatYaz(yorum["createdAt"]),
                              style: TextStyle(
                                color: vibe.faintText,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        trailing: menuGoster
                            ? PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == "report_comment") {
                                    _yorumuSikayetEt(
                                      yorumId: yorumId,
                                      yorumSahibiUid: yorumSahibiUid,
                                    );
                                  } else if (value == "block_user") {
                                    _kullaniciyiEngelle(yorumSahibiUid);
                                  }
                                },
                                itemBuilder: (context) => const [
                                  PopupMenuItem(
                                    value: "report_comment",
                                    child: Text("Yorumu Şikayet Et"),
                                  ),
                                  PopupMenuItem(
                                    value: "block_user",
                                    child: Text("Kullanıcıyı Engelle"),
                                  ),
                                ],
                              )
                            : null,
                      );
                    },
                  );
                },
              ),
            ),
            // Yorum yazma alanı
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Row(
                children: [
                  Expanded(
                    child: BahsetmeMetinAlani(
                      controller: yorumController,
                      haricUid: widget.userId,
                      style: TextStyle(color: theme.colorScheme.onSurface),
                      decoration: InputDecoration(
                        hintText: "Yorum yaz...",
                        hintStyle: TextStyle(color: vibe.mutedText),
                        filled: true,
                        fillColor: vibe.inputFill,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(26),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    onPressed: isLoading ? null : yorumEkle,
                    icon: isLoading
                        ? CircularProgressIndicator(
                            color: theme.colorScheme.onSurface,
                          )
                        : const Icon(Icons.send, color: VibeAppTheme.accent),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
