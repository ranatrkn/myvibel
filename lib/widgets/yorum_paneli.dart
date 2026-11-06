// Gönderi yorumları alt paneli: listeleme, yanıt, ekleme, şikayet ve engelleme
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:myvibel/app_theme.dart';
import 'package:myvibel/widgets/vibe_yukleniyor.dart';
import 'package:myvibel/error_messages.dart';
import 'package:myvibel/etiket_navigasyon.dart';
import 'package:myvibel/maskot_servis.dart';
import 'package:myvibel/puan_animasyon.dart';
import 'package:myvibel/sosyal/sosyal_core.dart';
import 'package:myvibel/sosyal_servis.dart';
import 'package:myvibel/utils/tarih_saat.dart';
import 'package:myvibel/vibe_snackbar.dart';
import 'package:myvibel/widgets/bahsetme_metin_alani.dart';
import 'package:myvibel/maestro_semantics.dart';
import 'package:myvibel/widgets/hashtag_metin.dart';
import 'package:myvibel/widgets/isim_yan_rozet.dart';
import 'package:myvibel/widgets/vibe_avatar.dart';
import 'package:myvibel/widgets/vibe_ikonlar.dart';
import 'package:myvibel/widgets/vil_harcama_uyarisi.dart';
import 'package:myvibel/widgets/web_shell.dart';

class _YanitHedefi {
  final String commentId;
  final String kokId;
  final String userId;
  final String kullaniciAdi;

  const _YanitHedefi({
    required this.commentId,
    required this.kokId,
    required this.userId,
    required this.kullaniciAdi,
  });
}

class _BekleyenYorum {
  final String id;
  final String metin;
  final String yanitKullaniciAdi;

  const _BekleyenYorum({
    required this.id,
    required this.metin,
    required this.yanitKullaniciAdi,
  });
}

class _YorumGrubu {
  final QueryDocumentSnapshot<Map<String, dynamic>> kok;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> yanitlar;
  final bool orphanYanit;

  const _YorumGrubu({
    required this.kok,
    required this.yanitlar,
    required this.orphanYanit,
  });
}

// Yorum paneli widget'ı
class YorumPaneli extends StatefulWidget {
  final String postId; // Hedef gönderi kimliği
  final String postOwnerId; // Gönderi sahibi uid
  final String userId; // Oturum açmış kullanıcı uid
  final VoidCallback onYorumEklendi; // Yorum eklendiğinde üst bileşene bildir
  final VoidCallback? onYorumSilindi;

  const YorumPaneli({
    super.key,
    required this.postId,
    required this.postOwnerId,
    required this.userId,
    required this.onYorumEklendi,
    this.onYorumSilindi,
  });

  @override
  State<YorumPaneli> createState() => _YorumPaneliState();
}

class _YorumPaneliState extends State<YorumPaneli>
    with WidgetsBindingObserver {
  final TextEditingController yorumController = TextEditingController();
  final FocusNode _yorumFocus = FocusNode();
  final ScrollController _listeKontrol = ScrollController();
  bool isLoading = false;
  final Set<String> _gizliYorumIdleri = {};
  final Set<String> _acikYanitlar = {};
  final List<_BekleyenYorum> _bekleyenYorumlar = [];
  Map<String, dynamic> _benimProfil = const {};
  _YanitHedefi? _yanitHedefi;
  bool _yorumMenuAcik = false;
  double _sonKlavyeInset = 0;
  // build içinde oluşturulursa her setState yeniden abone olur ve liste kaydırması sıfırlanır.
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _yorumAkisi =
      SosyalCore.gonderiRef(widget.postId)
          .collection('comments')
          .orderBy('createdAt', descending: true)
          .limit(80)
          .snapshots();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _benimProfiliYukle();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && webMasaustuMu(context)) _alanaOdaklan();
    });
  }

  // Web'de tıklamanın ardından tarayıcı odağı geri alır; kısa gecikme gerekli.
  void _alanaOdaklan() {
    _yorumFocus.requestFocus();
    if (!kIsWeb) return;
    Future.delayed(const Duration(milliseconds: 320), () {
      if (mounted) _yorumFocus.requestFocus();
    });
  }

  Future<void> _benimProfiliYukle() async {
    final ref =
        FirebaseFirestore.instance.collection('users').doc(widget.userId);
    try {
      var snap = await ref.get(const GetOptions(source: Source.cache));
      if (!snap.exists) snap = await ref.get();
      if (mounted) setState(() => _benimProfil = snap.data() ?? const {});
    } catch (_) {
      try {
        final snap = await ref.get();
        if (mounted) setState(() => _benimProfil = snap.data() ?? const {});
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    yorumController.dispose();
    _yorumFocus.dispose();
    _listeKontrol.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    _klavyeDegisinceMenuyuKapat();
  }

  void _klavyeDegisinceMenuyuKapat() {
    if (!mounted || !_yorumMenuAcik) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_yorumMenuAcik) return;
      final klavye = MediaQuery.viewInsetsOf(context).bottom;
      if ((klavye - _sonKlavyeInset).abs() < 1) return;
      _sonKlavyeInset = klavye;
      _yorumMenuAcik = false;
      final nav = Navigator.of(context);
      if (nav.canPop()) nav.pop();
    });
  }

  void _yanitla({
    required String commentId,
    required String kokId,
    required String userId,
    required String kullaniciAdi,
  }) {
    setState(() {
      _yanitHedefi = _YanitHedefi(
        commentId: commentId,
        kokId: kokId,
        userId: userId,
        kullaniciAdi: kullaniciAdi,
      );
      if (kokId.isNotEmpty) _acikYanitlar.add(kokId);
    });
    _alanaOdaklan();
  }

  void _yanitlariAcKapa(String kokId) {
    setState(() {
      if (_acikYanitlar.contains(kokId)) {
        _acikYanitlar.remove(kokId);
      } else {
        _acikYanitlar.add(kokId);
      }
    });
  }

  Future<void> _yorumMenusunuAc({
    required BuildContext buttonContext,
    required String yorumId,
    required String yorumSahibiUid,
    required bool kendiYorumu,
    required bool gonderiSahibi,
    required bool menuGoster,
    required bool yanit,
    required List<String> yanitIdleri,
  }) async {
    // Klavye açıkken menü global konumda kalır; önce klavyeyi kapat.
    _yorumFocus.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
    if (_yorumMenuAcik) return;

    final oncekiInset = MediaQuery.viewInsetsOf(context).bottom;
    if (oncekiInset > 0) {
      final bitis = DateTime.now().add(const Duration(milliseconds: 450));
      while (mounted &&
          MediaQuery.viewInsetsOf(context).bottom > 0 &&
          DateTime.now().isBefore(bitis)) {
        await Future<void>.delayed(const Duration(milliseconds: 40));
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    if (!mounted || !buttonContext.mounted) return;

    final box = buttonContext.findRenderObject() as RenderBox?;
    final overlay =
        Navigator.of(context).overlay?.context.findRenderObject() as RenderBox?;
    if (box == null || overlay == null) return;

    final topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
    final bottomRight =
        box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay);
    final position = RelativeRect.fromRect(
      Rect.fromPoints(topLeft, bottomRight),
      Offset.zero & overlay.size,
    );

    final items = <PopupMenuEntry<String>>[];
    if (kendiYorumu || gonderiSahibi) {
      items.add(
        PopupMenuItem(
          value: 'delete_comment',
          child: Semantics(
            label: MaestroSemantics.yorumuSil,
            button: true,
            child: const Text('Yorumu Sil'),
          ),
        ),
      );
    }
    if (menuGoster) {
      items.add(
        const PopupMenuItem(
          value: 'report_comment',
          child: Text('Yorumu Şikayet Et'),
        ),
      );
      items.add(
        const PopupMenuItem(
          value: 'block_user',
          child: Text('Kullanıcıyı Engelle'),
        ),
      );
    }
    if (items.isEmpty) return;

    _yorumMenuAcik = true;
    _sonKlavyeInset = MediaQuery.viewInsetsOf(context).bottom;
    final secim = await showMenu<String>(
      context: context,
      position: position,
      items: items,
    );
    _yorumMenuAcik = false;
    if (!mounted || secim == null) return;

    if (secim == 'delete_comment') {
      await _yorumuSil(
        yorumId: yorumId,
        odulAlindi: kendiYorumu && widget.userId != widget.postOwnerId,
        yanitIdleri: yanit ? const [] : yanitIdleri,
      );
    } else if (secim == 'report_comment') {
      await _yorumuSikayetEt(
        yorumId: yorumId,
        yorumSahibiUid: yorumSahibiUid,
      );
    } else if (secim == 'block_user') {
      await _kullaniciyiEngelle(yorumSahibiUid);
    }
  }

  // ListView.builder sonu tahminle hesaplar; gerçek sona oturana kadar tekrarla.
  void _enAltaKaydir() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      for (var i = 0; i < 4; i++) {
        if (!mounted || !_listeKontrol.hasClients) return;
        final konum = _listeKontrol.position;
        if (konum.maxScrollExtent - konum.pixels < 1) return;
        await _listeKontrol.animateTo(
          konum.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // Yeni yorumu Firestore'a kaydet
  Future<void> yorumEkle() async {
    final metin = yorumController.text.trim();
    if (metin.isEmpty || isLoading) return;
    isLoading = true;

    final yanit = _yanitHedefi;
    final bekleyen = _BekleyenYorum(
      id: SosyalCore.gonderiRef(widget.postId).collection('comments').doc().id,
      metin: metin,
      yanitKullaniciAdi: yanit?.kullaniciAdi ?? '',
    );
    yorumController.clear();
    setState(() {
      _yanitHedefi = null;
      _bekleyenYorumlar.add(bekleyen);
      if (yanit != null && yanit.kokId.isNotEmpty) {
        _acikYanitlar.add(yanit.kokId);
      }
    });
    if (yanit == null) _enAltaKaydir();
    widget.onYorumEklendi();

    try {
      await SosyalServis.yorumEkle(
        postId: widget.postId,
        postOwnerId: widget.postOwnerId,
        currentUserId: widget.userId,
        metin: metin,
        parentId: yanit?.commentId,
        commentId: bekleyen.id,
      );

      if (mounted) setState(() => _bekleyenYorumlar.remove(bekleyen));
      if (mounted && widget.userId != widget.postOwnerId) {
        puanAnimasyonuGoster(context, 3);
      }
    } catch (e) {
      if (!mounted) return;
      yorumController.text = metin;
      setState(() {
        _yanitHedefi = yanit;
        _bekleyenYorumlar.remove(bekleyen);
      });
      widget.onYorumSilindi?.call();
      vibeSnackbarGoster(
        context,
        internetAwareErrorMessage(
          error: e,
          fallback: "Yorum eklenemedi.",
        ),
      );
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

  // Tek şikayet seçeneği satırı
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

  Future<void> _yorumuSil({
    required String yorumId,
    required bool odulAlindi,
    List<String> yanitIdleri = const [],
  }) async {
    await vibeYorumSil(
      context: context,
      postId: widget.postId,
      commentId: yorumId,
      currentUserId: widget.userId,
      odulAlindi: odulAlindi,
      yanitSayisi: yanitIdleri.length,
      onBasladi: () {
        if (!mounted) return;
        setState(() {
          _gizliYorumIdleri.add(yorumId);
          _gizliYorumIdleri.addAll(yanitIdleri);
        });
        for (var i = 0; i < 1 + yanitIdleri.length; i++) {
          widget.onYorumSilindi?.call();
        }
      },
      onGeriAl: () {
        if (!mounted) return;
        setState(() {
          _gizliYorumIdleri.remove(yorumId);
          for (final id in yanitIdleri) {
            _gizliYorumIdleri.remove(id);
          }
        });
        for (var i = 0; i < 1 + yanitIdleri.length; i++) {
          widget.onYorumEklendi();
        }
      },
    );
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
    if (!onay || !mounted) return;
    vibeIyimserIslem(
      context,
      islem: () => SosyalServis.yorumSikayetEt(
        postId: widget.postId,
        yorumId: yorumId,
        yorumSahibiUid: yorumSahibiUid,
        sebep: sebep,
      ),
      basariMesaji: "Yorum şikayet edildi.",
      hataMesaji: "Şikayet gönderilemedi.",
    );
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

  bool _yorumGizliMi(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final yorum = doc.data();
    if (yorum['raporNedeniyleGizli'] == true) return true;
    return _gizliYorumIdleri.contains(doc.id);
  }

  List<_YorumGrubu> _yorumlariGrupla(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final byId = {for (final doc in docs) doc.id: doc};
    final yanitlar = <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
    final kokler = <QueryDocumentSnapshot<Map<String, dynamic>>>[];

    for (final doc in docs) {
      final parentId = (doc.data()['parentId'] ?? '').toString().trim();
      if (parentId.isEmpty) {
        kokler.add(doc);
        continue;
      }
      var kokId = parentId;
      var koruma = 0;
      while (koruma < 20) {
        koruma++;
        final parent = byId[kokId];
        if (parent == null) break;
        final ust = (parent.data()['parentId'] ?? '').toString().trim();
        if (ust.isEmpty) break;
        kokId = ust;
      }
      final kok = byId[kokId];
      if (kok == null || _yorumGizliMi(kok)) {
        kokler.add(doc);
      } else {
        yanitlar.putIfAbsent(kokId, () => []).add(doc);
      }
    }

    final gruplar = <_YorumGrubu>[];
    for (final kok in kokler) {
      if (_yorumGizliMi(kok)) continue;
      final gorunenYanitlar = (yanitlar[kok.id] ?? const [])
          .where((yanit) => !_yorumGizliMi(yanit))
          .toList();
      gruplar.add(
        _YorumGrubu(
          kok: kok,
          yanitlar: gorunenYanitlar,
          orphanYanit:
              (kok.data()['parentId'] ?? '').toString().trim().isNotEmpty,
        ),
      );
    }
    return gruplar;
  }

  Widget _yorumKarti({
    required QueryDocumentSnapshot<Map<String, dynamic>> doc,
    required bool yanit,
    required ThemeData theme,
    required VibeThemeExtension vibe,
    String kokId = '',
    int yanitSayisi = 0,
    bool yanitlarAcik = false,
    VoidCallback? onYanitlariAcKapa,
    List<String> yanitIdleri = const [],
  }) {
    final yorum = doc.data();
    final yorumId = doc.id;
    final yorumSahibiUid = (yorum['userId'] ?? '').toString();
    final kullaniciAdi =
        (yorum['kullaniciAdi'] ?? 'Vibe Kullanıcısı').toString();
    final yanitKullaniciAdi = (yorum['yanitKullaniciAdi'] ?? '').toString();
    final kendiYorumu =
        yorumSahibiUid.isNotEmpty && yorumSahibiUid == widget.userId;
    final gonderiSahibi = widget.postOwnerId.isNotEmpty &&
        widget.postOwnerId == widget.userId;
    final menuGoster =
        yorumSahibiUid.isNotEmpty && yorumSahibiUid != widget.userId;
    final threadKokId = kokId.isNotEmpty ? kokId : yorumId;

    return Padding(
      padding: EdgeInsets.only(left: yanit ? 36 : 0),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: vibeAvatar(
          radius: yanit ? 15 : 18,
          userId: yorumSahibiUid,
          photoUrl: (yorum['photoUrl'] ?? '').toString(),
          avatarKey: (yorum['avatarKey'] ?? '').toString(),
          fallbackText: kullaniciAdi,
          emojiSize: 16,
          fallbackIconSize: 18,
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                kullaniciAdi,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: yanit ? 13.5 : 14.5,
                ),
              ),
            ),
            IsimYanRozet(uid: yorumSahibiUid, boy: yanit ? 13 : 14),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (yanit && yanitKullaniciAdi.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  '↳ @$yanitKullaniciAdi',
                  style: TextStyle(
                    color: vibe.mutedText,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            HashtagMetin(
              metin: yorum['metin'] ?? '',
              mentionUidleri: SosyalServis.bahsetmeUidHaritasiParse(
                yorum['mentionUidleri'],
              ),
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
              onHashtagTap: (tag) => etiketSayfasinaGit(context, tag),
            ),
            const SizedBox(height: 3),
            Wrap(
              spacing: 12,
              runSpacing: 2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  yorum['createdAt'] == null
                      ? 'Şimdi'
                      : tarihSaatYaz(yorum['createdAt']),
                  style: TextStyle(
                    color: vibe.faintText,
                    fontSize: 11,
                  ),
                ),
                maestroButton(
                  label: MaestroSemantics.yorumuYanitla,
                  onTap: () => _yanitla(
                    commentId: yorumId,
                    kokId: threadKokId,
                    userId: yorumSahibiUid,
                    kullaniciAdi: kullaniciAdi,
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => _yanitla(
                      commentId: yorumId,
                      kokId: threadKokId,
                      userId: yorumSahibiUid,
                      kullaniciAdi: kullaniciAdi,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      child: Text(
                        'Yanıtla',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                if (!yanit && yanitSayisi > 0)
                  Semantics(
                    label: yanitlarAcik
                        ? MaestroSemantics.yorumYanitlariniGizle
                        : MaestroSemantics.yorumYanitlariniAc,
                    button: true,
                    child: GestureDetector(
                      onTap: onYanitlariAcKapa,
                      child: Text(
                        yanitlarAcik
                            ? 'Yanıtları gizle'
                            : yanitSayisi == 1
                                ? '1 yanıtı gör'
                                : '$yanitSayisi yanıtı gör',
                        style: TextStyle(
                          color: vibe.mutedText,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        trailing: (kendiYorumu || gonderiSahibi || menuGoster)
            ? Builder(
                builder: (buttonContext) => IconButton(
                  tooltip: 'Yorum menüsü',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _yorumMenusunuAc(
                    buttonContext: buttonContext,
                    yorumId: yorumId,
                    yorumSahibiUid: yorumSahibiUid,
                    kendiYorumu: kendiYorumu,
                    gonderiSahibi: gonderiSahibi,
                    menuGoster: menuGoster,
                    yanit: yanit,
                    yanitIdleri: yanitIdleri,
                  ),
                  icon: Icon(
                    Icons.more_vert_rounded,
                    color: vibe.mutedText,
                  ),
                ),
              )
            : null,
      ),
    );
  }

  Widget _bekleyenYorumKarti(
    _BekleyenYorum bekleyen, {
    required ThemeData theme,
    required VibeThemeExtension vibe,
  }) {
    final kullaniciAdi =
        (_benimProfil['kullaniciAdi'] ?? 'Sen').toString();
    final yanit = bekleyen.yanitKullaniciAdi.isNotEmpty;
    return Opacity(
      opacity: 0.6,
      child: Padding(
        padding: EdgeInsets.only(left: yanit ? 36 : 0),
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: vibeAvatar(
            radius: yanit ? 15 : 18,
            userId: widget.userId,
            photoUrl: (_benimProfil['photoUrl'] ?? '').toString(),
            avatarKey: (_benimProfil['avatarKey'] ?? '').toString(),
            fallbackText: kullaniciAdi,
            emojiSize: 16,
            fallbackIconSize: 18,
          ),
          title: Text(
            kullaniciAdi,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: yanit ? 13.5 : 14.5,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (yanit)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    '↳ @${bekleyen.yanitKullaniciAdi}',
                    style: TextStyle(
                      color: vibe.mutedText,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              Text(
                bekleyen.metin,
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Şimdi',
                style: TextStyle(color: vibe.faintText, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final altBosluk = MediaQuery.of(context).viewInsets.bottom;
    final theme = Theme.of(context);
    final vibe = context.vibe;

    final mq = MediaQuery.of(context);
    final normalYukseklik = mq.size.height * 0.72;
    final klavyeAcikYukseklik =
        (mq.size.height - altBosluk).clamp(300.0, normalYukseklik).toDouble();

    return Padding(
      padding: EdgeInsets.only(bottom: altBosluk),
      child: SizedBox(
        height: altBosluk > 0 ? klavyeAcikYukseklik : normalYukseklik,
        child: Column(
          children: [
            const SizedBox(height: 10),
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
              'Yorumlar',
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Divider(color: theme.dividerColor),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _yorumAkisi,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const Center(child: VibeYukleniyor());
                  }

                  final comments =
                      (snapshot.data?.docs ?? []).reversed.toList();
                  final gruplar = _yorumlariGrupla(comments);
                  final gelenIdler = {for (final doc in comments) doc.id};
                  final bekleyenler = _bekleyenYorumlar
                      .where((b) => !gelenIdler.contains(b.id))
                      .toList();

                  if (gruplar.isEmpty && bekleyenler.isEmpty) {
                    return Center(
                      child: Text(
                        'Henüz yorum yok.',
                        style: TextStyle(color: theme.colorScheme.onSurface),
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: _listeKontrol,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: gruplar.length + bekleyenler.length,
                    itemBuilder: (context, index) {
                      if (index >= gruplar.length) {
                        return _bekleyenYorumKarti(
                          bekleyenler[index - gruplar.length],
                          theme: theme,
                          vibe: vibe,
                        );
                      }
                      final grup = gruplar[index];
                      final acik = _acikYanitlar.contains(grup.kok.id);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _yorumKarti(
                            doc: grup.kok,
                            yanit: grup.orphanYanit,
                            theme: theme,
                            vibe: vibe,
                            kokId: grup.kok.id,
                            yanitSayisi: grup.yanitlar.length,
                            yanitlarAcik: acik,
                            yanitIdleri:
                                grup.yanitlar.map((yanit) => yanit.id).toList(),
                            onYanitlariAcKapa: grup.yanitlar.isEmpty
                                ? null
                                : () => _yanitlariAcKapa(grup.kok.id),
                          ),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOut,
                            alignment: Alignment.topCenter,
                            child: acik && grup.yanitlar.isNotEmpty
                                ? Column(
                                    children: [
                                      for (final yanit in grup.yanitlar)
                                        _yorumKarti(
                                          doc: yanit,
                                          yanit: true,
                                          theme: theme,
                                          vibe: vibe,
                                          kokId: grup.kok.id,
                                        ),
                                    ],
                                  )
                                : const SizedBox(width: double.infinity),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
            if (_yanitHedefi != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '@${_yanitHedefi!.kullaniciAdi} kullanıcısına yanıt',
                        style: TextStyle(
                          color: vibe.mutedText,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    maestroButton(
                      label: MaestroSemantics.yanitiIptal,
                      onTap: () => setState(() => _yanitHedefi = null),
                      child: IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () => setState(() => _yanitHedefi = null),
                        icon: Icon(Icons.close, size: 18, color: vibe.mutedText),
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Row(
                children: [
                  Expanded(
                    child: BahsetmeMetinAlani(
                      controller: yorumController,
                      focusNode: _yorumFocus,
                      haricUid: widget.userId,
                      maxLength: 1000,
                      enterIleGonder: yorumEkle,
                      style: TextStyle(color: theme.colorScheme.onSurface),
                      decoration: InputDecoration(
                        hintText: _yanitHedefi == null
                            ? 'Yorum yaz...'
                            : '@${_yanitHedefi!.kullaniciAdi} yanıtla...',
                        hintStyle: TextStyle(color: vibe.mutedText),
                        filled: true,
                        fillColor: vibe.inputFill,
                        counterText: '',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(26),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Semantics(
                    label: MaestroSemantics.yorumGonder,
                    button: true,
                    onTap: isLoading ? null : yorumEkle,
                    child: ExcludeSemantics(
                      child: IconButton(
                        onPressed: isLoading ? null : yorumEkle,
                        icon: const Icon(VibeIkon.gonder, color: VibeAppTheme.accent),
                      ),
                    ),
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

Future<bool> vibeYorumSil({
  required BuildContext context,
  required String postId,
  required String commentId,
  required String currentUserId,
  required bool odulAlindi,
  required VoidCallback onBasladi,
  required VoidCallback onGeriAl,
  int yanitSayisi = 0,
}) async {
  MascotDurum? mascot;
  if (odulAlindi && currentUserId.isNotEmpty) {
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .get();
    if (!context.mounted) return false;
    mascot = MascotServis.tryParse(userDoc.data()?['robot']);
  }

  final vilGerekir = odulAlindi &&
      mascot != null &&
      MascotServis.sosyalGeriAlVilGerekir(mascot.seviye);
  if (vilGerekir &&
      !MascotServis.sosyalGeriAlVilYeterli(mascot, MascotServis.sosyalGeriAlVilMaliyeti)) {
    vibeSnackbarGoster(
      context,
      MascotServis.sosyalGeriAlVilYetersizMesaji(
        'Yorum silmek',
        MascotServis.sosyalGeriAlVilMaliyeti,
      ),
    );
    return false;
  }

  final tekPencere = vilGerekir && webMasaustuMu(context);
  final onay = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: context.vibe.dialogBackground,
      title: Text(
        'Yorum silinsin mi?',
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
      ),
      content: Text(
        (yanitSayisi > 0
                ? 'Bu yorum ve yanıtları silinecek. Bu işlem geri alınamaz.'
                : 'Bu işlem geri alınamaz.') +
            (tekPencere
                ? '\nBu işlem ${MascotServis.sosyalGeriAlVilMaliyeti} vil harcar.'
                : ''),
        style: TextStyle(color: context.vibe.mutedText, height: 1.35),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Vazgeç'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Sil'),
        ),
      ],
    ),
  );
  if (onay != true) return false;
  if (!context.mounted) return false;

  if (vilGerekir && !tekPencere) {
    final vilOnay = await VilHarcamaUyarisi.onayla(
      context: context,
      islem: VilHarcamaUyarisi.yorumSil,
      maliyet: MascotServis.sosyalGeriAlVilMaliyeti,
      vilHarcanacak: true,
    );
    if (!vilOnay || !context.mounted) return false;
  }

  onBasladi();
  try {
    await SosyalServis.yorumSil(postId: postId, commentId: commentId);
    return true;
  } catch (e) {
    onGeriAl();
    if (context.mounted) {
      vibeSnackbarGoster(
        context,
        internetAwareErrorMessage(
          error: e,
          fallback: 'Yorum silinemedi.',
        ),
      );
    }
    return false;
  }
}
