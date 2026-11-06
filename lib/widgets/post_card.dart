// Tek gönderi kartı: beğeni, yorum, iletme, şikayet ve engelleme
import 'package:myvibel/ana_kabuk.dart';
import 'package:myvibel/tek_sefer_navigasyon.dart';
import 'package:flutter/material.dart';
import 'package:myvibel/alinti_gonderi.dart';
import 'package:myvibel/app_theme.dart';
import 'package:myvibel/error_messages.dart';
import 'package:myvibel/etiket_navigasyon.dart';
import 'package:myvibel/newpost_page.dart';
import 'package:myvibel/sosyal_servis.dart';
import 'package:myvibel/utils/tarih_saat.dart';
import 'package:myvibel/yas_hesap_kontrol.dart';
import 'package:myvibel/vibe_snackbar.dart';
import 'package:myvibel/widgets/alinti_gonderi_onizleme.dart';
import 'package:myvibel/widgets/gonderi_ilet_paneli.dart';
import 'package:myvibel/widgets/hashtag_metin.dart';
import 'package:myvibel/widgets/isim_yan_rozet.dart';
import 'package:myvibel/widgets/post_begeni_yardimci.dart';
import 'package:myvibel/widgets/vibe_avatar.dart';
import 'package:myvibel/widgets/vibe_ikonlar.dart';
import 'package:myvibel/maestro_semantics.dart';
import 'package:myvibel/widgets/begenenler_paneli.dart';
import 'package:myvibel/widgets/yorum_paneli.dart';

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
  final bool? baslangicBegenildi; // Önbellekten beğeni durumu
  final String userId; // Oturum açmış kullanıcı uid
  final dynamic createdAt; // Oluşturulma zamanı
  final bool ownerHesapGizli; // Gizli hesap gönderisi mi
  final AlintiGonderiSnapshot? alintiSnapshot; // Alıntılanan gönderi
  final Set<String>? engellenenKullanicilar;
  final Set<String>? beniEngelleyenler;
  final VoidCallback? onKendiProfilineGit; // Kendi profiline geçiş callback
  final ValueChanged<bool>? onBegeniDegisti; // Beğeni durumu değişince
  final ValueChanged<AlintiGonderiBaglam>? onAlintiYap; // Alıntıla
  final bool yorumlariAcikBaslat; // Bildirimden gelince yorum paneli

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
    this.baslangicBegenildi,
    required this.userId,
    required this.createdAt,
    this.ownerHesapGizli = false,
    this.alintiSnapshot,
    this.engellenenKullanicilar,
    this.beniEngelleyenler,
    this.onKendiProfilineGit,
    this.onBegeniDegisti,
    this.onAlintiYap,
    this.yorumlariAcikBaslat = false,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  // Liste kartı ekrandan çıkınca yeniden kurulur ve feed'deki eski belge
  // sayısını alır; yerel değişiklik, taban sayı aynı kaldıkça korunur.
  static final Map<String, ({int taban, int deger})> _yerelYorumSayilari = {};

  bool gizleKart = false; // Engelleme sonrası kartı gizle
  late int yorumSayisi; // Güncel yorum sayısı
  late int _yorumTabani;
  late PostBegeniDurumuYonetici _begeni;

  void _yorumSayisiniBaslat() {
    final yerel = _yerelYorumSayilari[widget.postId];
    if (yerel != null && yerel.taban == widget.baslangicYorumSayisi) {
      _yorumTabani = yerel.taban;
      yorumSayisi = yerel.deger;
    } else {
      _yerelYorumSayilari.remove(widget.postId);
      _yorumTabani = widget.baslangicYorumSayisi;
      yorumSayisi = widget.baslangicYorumSayisi;
    }
  }

  // Panel açıkken kart listeden atılmış olabilir; sayı yine haritaya yazılır.
  void _yorumSayisiniDegistir(int fark) {
    final yeni = yorumSayisi + fark;
    yorumSayisi = yeni < 0 ? 0 : yeni;
    _yerelYorumSayilari[widget.postId] =
        (taban: _yorumTabani, deger: yorumSayisi);
    if (mounted) setState(() {});
  }

  void _begeniYoneticiOlustur() {
    _begeni = PostBegeniDurumuYonetici(
      postId: widget.postId,
      userId: widget.userId,
      postOwnerId: widget.postOwnerId,
      baslangicBegeniSayisi: widget.baslangicBegeniSayisi,
      baslangicBegenildi: widget.baslangicBegenildi,
    );
    _begeni.baslat(
      yenile: () {
        if (mounted) setState(() {});
      },
      baslangicBegenildi: widget.baslangicBegenildi,
    );
  }

  @override
  void initState() {
    super.initState();
    _yorumSayisiniBaslat();
    _begeniYoneticiOlustur();
    if (widget.yorumlariAcikBaslat) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) yorumPaneliniAc();
      });
    }
  }

  @override
  void didUpdateWidget(covariant PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.postId != widget.postId ||
        oldWidget.userId != widget.userId ||
        oldWidget.postOwnerId != widget.postOwnerId) {
      _begeniYoneticiOlustur();
    }
    if (oldWidget.baslangicBegenildi != widget.baslangicBegenildi) {
      _begeni.begeniDurumunuUygula(widget.baslangicBegenildi);
    }
    if (oldWidget.baslangicBegeniSayisi != widget.baslangicBegeniSayisi) {
      _begeni.guncelle(yeniBaslangicBegeni: widget.baslangicBegeniSayisi);
    }
    if (oldWidget.postId != widget.postId ||
        oldWidget.baslangicYorumSayisi != widget.baslangicYorumSayisi) {
      setState(_yorumSayisiniBaslat);
    }
  }

  @override
  void dispose() {
    _begeni.durdur();
    super.dispose();
  }

  // Gönderi sahibinin profiline git
  void kullaniciProfilineGit() {
    if (widget.postOwnerId.isEmpty) return;

    if (widget.postOwnerId == widget.userId) {
      if (AnaKabuk.kendiProfilineGit()) return;
      widget.onKendiProfilineGit?.call();
      return;
    }

    profiliAc(context, widget.postOwnerId);
  }

  // Beğeni ekle/kaldır (optimistik UI)
  Future<void> begeniyiDegistir() async {
    await _begeni.degistir(
      context,
      onBasari: widget.onBegeniDegisti,
    );
  }

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
          onYorumEklendi: () => _yorumSayisiniDegistir(1),
          onYorumSilindi: () => _yorumSayisiniDegistir(-1),
        );
      },
    );
  }

  // Şikayet sebebi seçim diyaloğu
  Future<String?> _sikayetSebebiSec() async {
    String? secim;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text("Şikayet Sebebi"),
        children: [
          for (final metin in const [
            "Spam",
            "Hakaret/Nefret",
            "Uygunsuz İçerik",
            "Diğer",
          ])
            _sikayetSecenek(dialogContext, metin, (v) => secim = v),
        ],
      ),
    );
    return secim;
  }

  Widget _sikayetSecenek(
    BuildContext dialogContext,
    String metin,
    ValueChanged<String> sec,
  ) {
    return SimpleDialogOption(
      onPressed: () {
        sec(metin);
        Navigator.pop(dialogContext);
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
    if (!onay || !mounted) return;
    vibeIyimserIslem(
      context,
      islem: () => SosyalServis.gonderiSikayetEt(
        postId: widget.postId,
        postOwnerId: widget.postOwnerId,
        sebep: sebep,
      ),
      basariMesaji: "Gönderi şikayet edildi.",
      hataMesaji: "Şikayet gönderilemedi.",
    );
  }

  // Gönderiyi alıntıla (yalnızca açık hesap gönderileri)
  void _gonderiyiAlintila() {
    if (!_alintiYapilabilir) return;
    final baglam = AlintiGonderiBaglam(
      postId: widget.postId,
      snapshot: AlintiGonderiSnapshot(
        postId: widget.postId,
        userId: widget.postOwnerId,
        kullaniciAdi: widget.kullaniciAdi,
        metin: widget.metin,
        photoUrl: widget.photoUrl,
        avatarKey: widget.avatarKey,
        createdAt: widget.createdAt,
      ),
    );
    if (widget.onAlintiYap != null) {
      widget.onAlintiYap!(baglam);
      return;
    }
    tekSeferPush(
      context,
      MaterialPageRoute(
        builder: (_) => NewPostPage(
          alintiBaglam: baglam,
          onPostCreated: () => Navigator.pop(context),
        ),
      ),
    );
  }

  bool get _alintiYapilabilir =>
      !widget.ownerHesapGizli && widget.userId.isNotEmpty;

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
              userId: widget.postOwnerId,
              liderTaciGoster: true,
              photoUrl: widget.photoUrl,
              avatarKey: widget.avatarKey,
              fallbackText: widget.kullaniciAdi,
              emojiSize: 18,
              fallbackIconSize: 20,
              fallbackForegroundColor: theme.colorScheme.onPrimary,
            ),
            title: Row(
              children: [
                Flexible(
                  child: Text(
                    widget.kullaniciAdi,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IsimYanRozet(uid: widget.postOwnerId),
              ],
            ),
            subtitle: Text(
              tarihSaatYaz(widget.createdAt),
              style: TextStyle(color: vibe.faintText, fontSize: 12),
            ),
            trailing: maestroButton(
              label: MaestroSemantics.gonderiMenusu,
              child: PopupMenuButton<String>(
                    tooltip: MaestroSemantics.gonderiMenusu,
                    padding: const EdgeInsets.all(8),
                    icon: Icon(VibeIkon.menu, color: vibe.mutedText),
                    onSelected: (value) {
                      if (value == "report_post") {
                        _postuSikayetEt();
                      } else if (value == "block_user") {
                        _kullaniciyiEngelle();
                      } else if (value == "share_post") {
                        _gonderiyiIlet();
                      } else if (value == "quote_post") {
                        _gonderiyiAlintila();
                      }
                    },
                    itemBuilder: (context) => [
                      if (_alintiYapilabilir)
                        const PopupMenuItem(
                          value: "quote_post",
                          child: Text("Alıntıla"),
                        ),
                      if (YasHesapKontrol.maybeOf(context)?.mesajAcik == true)
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
          ),
          // Gönderi metni (hashtag ve mention destekli)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.metin.isNotEmpty)
                  HashtagMetin(
                    metin: widget.metin,
                    mentionUidleri: widget.mentionUidleri,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
                      fontSize: 17,
                    ),
                    onHashtagTap: (tag) => etiketSayfasinaGit(context, tag),
                  ),
                if (widget.alintiSnapshot != null) ...[
                  if (widget.metin.isNotEmpty) const SizedBox(height: 10),
                  AlintiGonderiOnizleme(
                    snapshot: widget.alintiSnapshot!,
                    currentUserId: widget.userId,
                    onKendiProfilineGit: widget.onKendiProfilineGit,
                    onAlintiYap: widget.onAlintiYap,
                    engellenenKullanicilar: widget.engellenenKullanicilar,
                    beniEngelleyenler: widget.beniEngelleyenler,
                    compact: true,
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                maestroButton(
                  label: MaestroSemantics.gonderiyiBegen,
                  onTap: begeniyiDegistir,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(28),
                    onTap: begeniyiDegistir,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 10,
                      ),
                      child: Icon(
                        _begeni.begenildi ? VibeIkon.begeni : VibeIkon.begeniBos,
                        color: VibeAppTheme.accent,
                        size: 26,
                      ),
                    ),
                  ),
                ),
                maestroButton(
                  label: widget.userId == widget.postOwnerId
                      ? MaestroSemantics.begenenleriGoster
                      : MaestroSemantics.gonderiyiBegen,
                  onTap: widget.userId == widget.postOwnerId
                      ? () => begenenlerPaneliniAc(
                            context,
                            postId: widget.postId,
                          )
                      : begeniyiDegistir,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(28),
                    onTap: widget.userId == widget.postOwnerId
                        ? () => begenenlerPaneliniAc(
                              context,
                              postId: widget.postId,
                            )
                        : begeniyiDegistir,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 10,
                      ),
                      child: Text(
                        "${_begeni.begeniSayisi}",
                        style: TextStyle(
                          color: vibe.mutedText,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 18),
                maestroButton(
                  label: MaestroSemantics.yorumlariAc,
                  onTap: yorumPaneliniAc,
                  child: InkWell(
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
                            VibeIkon.yorum,
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
                ),
                if (_alintiYapilabilir) ...[
                  const SizedBox(width: 8),
                  maestroButton(
                    label: MaestroSemantics.gonderiyiAlintila,
                    onTap: _gonderiyiAlintila,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(28),
                      onTap: _gonderiyiAlintila,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                        child: Icon(
                          VibeIkon.alinti,
                          color: vibe.mutedText,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ],
                maestroButton(
                  label: MaestroSemantics.gonderiyiIlet,
                  onTap: _gonderiyiIlet,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(28),
                    onTap: _gonderiyiIlet,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                      child: Icon(
                        VibeIkon.ilet,
                        color: vibe.mutedText,
                        size: 24,
                      ),
                    ),
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
