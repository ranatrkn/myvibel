// Başka kullanıcının profili: takip, engel, mesaj ve gönderi listesi
import 'package:myvibel/tek_sefer_navigasyon.dart';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:myvibel/alinti_gonderi.dart';
import 'package:myvibel/app_theme.dart';
import 'package:myvibel/widgets/vibe_yukleniyor.dart';
import 'package:myvibel/error_messages.dart';
import 'package:myvibel/follow_list_page.dart';
import 'package:myvibel/messages_page.dart';
import 'package:myvibel/maestro_semantics.dart';
import 'package:myvibel/puan_animasyon.dart';
import 'package:myvibel/sosyal/lider_tac_servis.dart';
import 'package:myvibel/sosyal_servis.dart';
import 'package:myvibel/etiket_navigasyon.dart';
import 'package:myvibel/yas_hesap_kontrol.dart';
import 'package:myvibel/widgets/alinti_gonderi_onizleme.dart';
import 'package:myvibel/widgets/hashtag_metin.dart';
import 'package:myvibel/widgets/isim_yan_rozet.dart';
import 'package:myvibel/widgets/post_begeni_yardimci.dart';
import 'package:myvibel/widgets/profil_gonderi_gorunumu.dart';
import 'package:myvibel/maskot_servis.dart';
import 'package:myvibel/widgets/mascot_ruh_hali_metni.dart';
import 'package:myvibel/widgets/maskot_durum_bari.dart';
import 'package:myvibel/widgets/maskot_gelisim_cercevesi.dart';
import 'package:myvibel/widgets/maskot_lottie_view.dart';
import 'package:myvibel/widgets/rety_bag_rozeti.dart';
import 'package:myvibel/widgets/vil_harcama_uyarisi.dart';
import 'package:myvibel/widgets/vibe_avatar.dart';
import 'package:myvibel/widgets/vibe_ikonlar.dart';
import 'package:myvibel/widgets/vibe_gradient_scaffold.dart';
import 'package:myvibel/widgets/web_shell.dart';
import 'package:myvibel/vibe_snackbar.dart';
import 'package:myvibel/widgets/begenenler_paneli.dart';
import 'package:myvibel/widgets/yorum_paneli.dart';

// Firestore Timestamp'i okunabilir tarihe çevir
String _tarihSaatYaz(dynamic value) {
  if (value is! Timestamp) return "Tarih yok";

  final tarih = value.toDate();
  final gun = tarih.day.toString().padLeft(2, "0");
  final ay = tarih.month.toString().padLeft(2, "0");
  final yil = tarih.year.toString();
  final saat = tarih.hour.toString().padLeft(2, "0");
  final dakika = tarih.minute.toString().padLeft(2, "0");
  return "$gun.$ay.$yil $saat:$dakika";
}

// Başka kullanıcı profil sayfası
class UserProfilePage extends StatefulWidget {
  const UserProfilePage({super.key, required this.userId});

  final String userId; // oturum açmış kullanıcı uid

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

// Kullanıcı profil sayfası durumu
class _UserProfilePageState extends State<UserProfilePage> {
  bool _takipYukleniyor = true; // takip durumu yükleniyor mu
  bool _takipIslemiSuruyor = false; // takip işlemi sürüyor mu
  bool _islemSuruyor = false; // işlem devam ediyor mu
  bool _engelledim = false; // bu kullanıcıyı engelledim mi
  bool _beniEngelledi = false; // karşı taraf beni engelledi mi
  TakipDurumu _takipDurumu = TakipDurumu.takipEtmiyor; // takip durumu enum'u
  bool _karsilikliTakip = false;
  bool _yerelBugunYemek = false;
  int? _iyimserTokluk;
  int? _iyimserMutluluk;
  ProfilGonderiGorunumu _gonderiGorunumu = ProfilGonderiGorunumu.liste;
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _kullaniciAkisi =
      FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .snapshots();
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _kullaniciGovdeAkisi =
      FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .snapshots();

  // Dinamik değeri int'e çevir
  int _intDeger(dynamic value, int varsayilan) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return varsayilan;
  }

  // Widget ilk yüklendiğinde çalışır
  @override
  void initState() {
    super.initState();
    unawaited(LiderTacServis.instance.baslat());
    unawaited(HaftaRozetServis.instance.yenile());
    _takipDurumunuYukle();
    _engelDurumunuYukle();
  }

  // Engel durumunu sunucudan yükle
  Future<void> _engelDurumunuYukle() async {
    final durum = await SosyalServis.engelDurumuGetir(widget.userId);
    if (!mounted) return;
    setState(() {
      _engelledim = durum["engelledim"] ?? false;
      _beniEngelledi = durum["beniEngelledi"] ?? false;
    });
  }

  // Takip durumunu sunucudan yükle
  Future<void> _takipDurumunuYukle() async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final sonuc = await Future.wait<Object?>([
      SosyalServis.takipDurumuGetir(widget.userId),
      (currentUid != null && currentUid != widget.userId)
          ? MascotServis.karsilikliTakipVarMi(
              uid1: currentUid,
              uid2: widget.userId,
            ).then((v) => v, onError: (_) => false)
          : Future<bool>.value(false),
    ]);
    final durum = sonuc[0] as TakipDurumu;
    var karsilikli = sonuc[1] as bool;
    if (!karsilikli &&
        currentUid != null &&
        durum == TakipDurumu.takipEdiliyor) {
      try {
        karsilikli = await SosyalServis.takipciMi(
          izleyiciUid: widget.userId,
          hedefUid: currentUid,
        );
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _takipDurumu = durum;
      _karsilikliTakip = karsilikli;
      _takipYukleniyor = false;
    });
  }

  // Takip et / takipten çık
  Future<void> _takibiDegistir() async {
    if (_engelledim || _beniEngelledi) {
      vibeSnackbarGoster(
        context,
        "Bu kullanıcı ile etkileşim kuramazsın.",
        tip: VibeMesajTipi.uyari,
      );
      return;
    }
    if (_takipIslemiSuruyor) return;

    if (_takipDurumu == TakipDurumu.takipEdiliyor) {
      final vilHarcanacak =
          await TakipServis.takipCikisVilHarcanacak(widget.userId);
      if (vilHarcanacak) {
        if (!mounted) return;
        final devam = await VilHarcamaUyarisi.onayla(
          context: context,
          islem: VilHarcamaUyarisi.takipCik,
          maliyet: MascotServis.vilTakipGeriAlMaliyeti,
        );
        if (!devam || !mounted) return;
      }
    }

    setState(() => _takipIslemiSuruyor = true);

    final mesaj =
        await SosyalServis.takipButonunaBas(widget.userId, _takipDurumu);
    final yeniDurum = await SosyalServis.takipDurumuGetir(widget.userId);

    if (!mounted) return;

    setState(() {
      _takipDurumu = yeniDurum;
      _takipIslemiSuruyor = false;
    });
    unawaited(_takipDurumunuYukle());

    if (mesaj.contains('+5')) {
      puanAnimasyonuGoster(context, 5);
    }

    if (mounted && mesaj.isNotEmpty) {
      vibeSnackbarGoster(context, mesaj, tip: VibeMesajTipi.bilgi);
    }
  }

  Future<void> _arkadasYemekVer(MascotDurum mascot) async {
    if (!_karsilikliTakip || _yerelBugunYemek) return;
    final devam = await VilHarcamaUyarisi.onayla(
      context: context,
      islem: VilHarcamaUyarisi.arkadasYemek,
      maliyet: MascotServis.arkadasYemekVilMaliyeti,
      vilHarcanacak: true,
    );
    if (!devam || !mounted) return;
    if (!_karsilikliTakip || _yerelBugunYemek) return;
    setState(() {
      _yerelBugunYemek = true;
      _iyimserTokluk =
          (mascot.tokluk + MascotServis.yemekToklukArtisi).clamp(0, 100);
      _iyimserMutluluk = (mascot.mutluluk + 3).clamp(0, 100);
    });
    unawaited(_arkadasYemekArkaPlan());
  }

  Future<void> _arkadasYemekArkaPlan() async {
    try {
      final mesaj = await MascotServis.arkadasYemekVer(widget.userId);
      final current = FirebaseAuth.instance.currentUser;
      if (current != null) {
        unawaited(
          SosyalServis.bildirimEkle(
            hedefUid: widget.userId,
            tip: 'maskot_yemek',
            gonderenUid: current.uid,
            metin: 'Vibel\'ine yemek verdi',
          ),
        );
      }
      if (!mounted) return;
      vibeSnackbarGoster(context, mesaj, tip: VibeMesajTipi.basari);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _yerelBugunYemek = false;
        _iyimserTokluk = null;
        _iyimserMutluluk = null;
      });
      vibeSnackbarGoster(
        context,
        internetAwareErrorMessage(
          error: e,
          fallback: 'Yemek verilemedi.',
        ),
        tip: VibeMesajTipi.uyari,
      );
    }
  }

  // Engelle veya engeli kaldır
  Future<void> _engellemeDegistir() async {
    if (_islemSuruyor) return;
    final onceEngelliydi = _engelledim;
    final onay = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(onceEngelliydi ? "Engeli Kaldır" : "Kullanıcıyı Engelle"),
        content: Text(
          onceEngelliydi
              ? "Bu kullanıcının engelini kaldırmak istiyor musun?"
              : "Bu kullanıcıyı engellersen profiline ve içeriklerine erişemezsin. Devam edilsin mi?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Vazgeç"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(onceEngelliydi ? "Engeli Kaldır" : "Engelle"),
          ),
        ],
      ),
    );
    if (onay != true) return;

    setState(() => _islemSuruyor = true);

    // hata yakalamalı blok
    try {
      if (onceEngelliydi) {
        await SosyalServis.engeliKaldir(widget.userId);
      } else {
        await SosyalServis.engelleKullanici(widget.userId);
      }
      await _engelDurumunuYukle();
      await _takipDurumunuYukle();
      if (!mounted) return;
      vibeSnackbarGoster(
        context,
        onceEngelliydi
            ? "Kullanıcı engelden çıkarıldı."
            : "Kullanıcı engellendi.",
        tip: VibeMesajTipi.basari,
      );
      // hata yakala
    } catch (e) {
      if (!mounted) return;
      vibeSnackbarGoster(
        context,
        internetAwareErrorMessage(
          error: e,
          fallback: "Kullanıcı engellenemedi.",
        ),
      );
      // temizlik
    } finally {
      if (mounted) setState(() => _islemSuruyor = false);
    }
  }

  // Kullanıcı şikayet akışı
  Future<void> _kullaniciyiSikayetEt() async {
    if (!mounted) return;
    final sebep = await _sikayetSebebiSec();
    if (sebep == null) return;
    if (!mounted) return;
    final aciklamaController = TextEditingController();
    final onay = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Kullanıcıyı Şikayet Et"),
          content: TextField(
            controller: aciklamaController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: "İsteğe bağlı açıklama",
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Vazgeç"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Gönder"),
            ),
          ],
        );
      },
    );
    if (onay != true) return;

    // hata yakalamalı blok
    try {
      await SosyalServis.kullaniciSikayetEt(
        hedefUid: widget.userId,
        sebep: sebep,
        aciklama: aciklamaController.text,
      );
      if (!mounted) return;
      vibeSnackbarGoster(
        context,
        "Şikayet alındı. Teşekkür ederiz.",
        tip: VibeMesajTipi.basari,
      );
      // hata yakala
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

  // Şikayet sebebi seçim diyaloğu
  Future<String?> _sikayetSebebiSec() async {
    String? secim;
    await showDialog<void>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: const Text("Şikayet Sebebi"),
          children: [
            _sikayetSecenek("Spam", (v) => secim = v),
            _sikayetSecenek("Hakaret/Nefret", (v) => secim = v),
            _sikayetSecenek("Uygunsuz İçerik", (v) => secim = v),
            _sikayetSecenek("Sahte Hesap", (v) => secim = v),
            _sikayetSecenek("Diğer", (v) => secim = v),
          ],
        );
      },
    );
    return secim;
  }

  // Tek şikayet sebebi satırı
  Widget _sikayetSecenek(String metin, ValueChanged<String> sec) {
    return SimpleDialogOption(
      onPressed: () {
        sec(metin);
        Navigator.pop(context);
      },
      child: Text(metin),
    );
  }

  // Arayüzü oluştur
  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final kendiProfil = currentUid == widget.userId;

    final theme = Theme.of(context);
    final vibe = context.vibe;

    return VibeGradientScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _kullaniciAkisi,
          builder: (context, snapshot) {
            final kullaniciAdi = snapshot.data?.data()?['kullaniciAdi'];
            if (kullaniciAdi == null) return const SizedBox.shrink();
            return Text(
              '@$kullaniciAdi',
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            );
          },
        ),
        actions: [
          if (!kendiProfil)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == "block") {
                  _engellemeDegistir();
                } else if (value == "report") {
                  _kullaniciyiSikayetEt();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: "block",
                  child: Text(
                      _engelledim ? "Engeli Kaldır" : "Kullanıcıyı Engelle"),
                ),
                const PopupMenuItem(
                  value: "report",
                  child: Text("Kullanıcıyı Şikayet Et"),
                ),
              ],
            ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _kullaniciGovdeAkisi,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return Center(
              child: VibeYukleniyor(renk: theme.colorScheme.primary),
            );
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(
              child: Text(
                'Kullanıcı bulunamadı',
                style: TextStyle(color: vibe.subtleText),
              ),
            );
          }

          final data = snapshot.data!.data() ?? {};
          final adSoyad = data['adSoyad'] ?? 'Vibe Kullanıcısı';
          final kullaniciAdi = data['kullaniciAdi'] ?? 'kullanici';
          final photoUrl = (data['photoUrl'] ?? '').toString();
          final avatarKey = (data['avatarKey'] ?? '').toString();
          final hesapGizli = data['hesapGizli'] == true;
          final hedefCocukHesabi = data['cocukHesabi'] == true;
          final mesajButonuAcik =
              YasHesapKontrol.maybeOf(context)?.mesajAcik == true &&
                  !hedefCocukHesabi;

          final mascotData = data['robot'];
          final mascotDurum = MascotServis.tryParse(mascotData);

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: vibeAvatar(
                    radius: 48,
                    userId: widget.userId,
                    liderTaciGoster: true,
                    photoUrl: photoUrl,
                    avatarKey: avatarKey,
                    fallbackText: kullaniciAdi,
                    emojiSize: 42,
                    fallbackIconSize: 48,
                  ),
                ),
                const SizedBox(height: 14),
                Center(
                  child: Column(
                    children: [
                      Text(
                        adSoyad,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '@$kullaniciAdi',
                            style: TextStyle(
                              color: vibe.mutedText,
                              fontSize: 14,
                            ),
                          ),
                          IsimYanRozet(uid: widget.userId),
                          if (!kendiProfil)
                            RetyBagProfilRozeti(otherUid: widget.userId),
                        ],
                      ),
                      RozetSayacSatiri(
                        data: Map<String, dynamic>.from(data),
                        seviye: mascotDurum?.seviye ?? 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                mascotDurum != null
                    ? _mascotKarti(mascotDurum, kendiProfil: kendiProfil)
                    : _mascotKartiYukleniyor(),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _takipSayacKutusu(
                        'Takipçi',
                        FirebaseFirestore.instance
                            .collection('users')
                            .doc(widget.userId)
                            .collection('followers'),
                        onTap: () {
                          if (hesapGizli &&
                              !kendiProfil &&
                              _takipDurumu != TakipDurumu.takipEdiliyor) {
                            vibeSnackbarGoster(
                              context,
                              "Bu hesap gizli. Takipçi listesi görüntülenemiyor.",
                              tip: VibeMesajTipi.uyari,
                            );
                            return;
                          }
                          tekSeferPush(
                            context,
                            MaterialPageRoute(
                              builder: (_) => FollowListPage(
                                userId: widget.userId,
                                initialTab: 0,
                                kullaniciAdi: kullaniciAdi,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _takipSayacKutusu(
                        'Takip Edilen',
                        FirebaseFirestore.instance
                            .collection('users')
                            .doc(widget.userId)
                            .collection('following'),
                        onTap: () {
                          if (hesapGizli &&
                              !kendiProfil &&
                              _takipDurumu != TakipDurumu.takipEdiliyor) {
                            vibeSnackbarGoster(
                              context,
                              "Bu hesap gizli. Takip edilen listesi görüntülenemiyor.",
                              tip: VibeMesajTipi.uyari,
                            );
                            return;
                          }
                          tekSeferPush(
                            context,
                            MaterialPageRoute(
                              builder: (_) => FollowListPage(
                                userId: widget.userId,
                                initialTab: 1,
                                kullaniciAdi: kullaniciAdi,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                if (!kendiProfil && !_engelledim && !_beniEngelledi) ...[
                  if (mesajButonuAcik) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final bilet = tekSeferGecisAl();
                        if (bilet == null) return;
                        final sohbet = WebSohbetKapsayici.maybeOf(context);
                        final masaustu = webMasaustuMu(context);
                        final navigator = Navigator.of(context);

                        // hata yakalamalı blok
                        try {
                          final chatId =
                              await SosyalServis.sohbetIdGetirVeyaOlustur(
                                  widget.userId);
                          if (!mounted) {
                            tekSeferGecisIptal(bilet);
                            return;
                          }
                          if (sohbet != null && masaustu) {
                            sohbet.sohbetiAc(
                              WebSohbetHedef(
                                chatId: chatId,
                                otherUid: widget.userId,
                                otherDisplayName: adSoyad,
                                otherUsername: kullaniciAdi,
                                otherPhotoUrl: photoUrl,
                                otherAvatarKey: avatarKey,
                              ),
                            );
                            tekSeferGecisBirak(bilet);
                            return;
                          }
                          navigator.push(
                            MaterialPageRoute(
                              builder: (_) => ChatPage(
                                chatId: chatId,
                                otherUid: widget.userId,
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
                              fallback: "Sohbet açılamadı.",
                            ),
                          );
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: vibe.cardBorder),
                        foregroundColor: theme.colorScheme.onSurface,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      icon: const Icon(VibeIkon.mesajBos),
                      label: const Text("Mesaj Gönder"),
                    ),
                  ),
                  ],
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _takipYukleniyor || _takipIslemiSuruyor
                          ? null
                          : _takibiDegistir,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _takipDurumu == TakipDurumu.takipEdiliyor
                                ? vibe.inputFill
                                : vibe.primaryButton,
                        foregroundColor:
                            _takipDurumu == TakipDurumu.takipEdiliyor
                                ? vibe.mutedText
                                : Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: _takipYukleniyor
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              SosyalServis.takipButonMetni(_takipDurumu),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _takipDurumu == TakipDurumu.takipEdiliyor
                                    ? vibe.mutedText
                                    : Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                if (_engelledim || _beniEngelledi)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(14),
                    decoration: vibe.cardDecoration(radius: 14),
                    child: Text(
                      _engelledim
                          ? "Bu kullanıcıyı engelledin."
                          : "Bu kullanıcı seni engelledi.",
                      style: TextStyle(color: vibe.mutedText),
                    ),
                  ),
                Text(
                  'Gönderiler',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                _gonderilerBolumu(
                  hesapGizli: hesapGizli,
                  kendiProfil: kendiProfil,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _mascotKartiYukleniyor() {
    final vibe = context.vibe;
    return Container(
      width: double.infinity,
      height: 140,
      padding: const EdgeInsets.all(18),
      decoration: vibe.kahramanKart(),
      alignment: Alignment.center,
      child: const VibeYukleniyor(renk: VibeAppTheme.accent),
    );
  }

  // Maskot durum kartı
  Widget _mascotKarti(MascotDurum mascot, {required bool kendiProfil}) {
    final theme = Theme.of(context);
    final vibe = context.vibe;
    final odaAcik = MascotServis.odaAcik(mascot.seviye);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: vibe.kahramanKart(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              MascotGelisimCercevesi(
                progress: mascot.gelisimOrani,
                size: 100,
                strokeWidth: 3.5,
                innerPadding: 3.5,
                borderRadius: 20,
                child: MascotLottieView(
                  seviye: mascot.seviye,
                  gorselDurum: mascot.gorselDurum,
                  renk: mascot.renk,
                  width: 86,
                  height: 86,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 16),
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
                      'Seviye ${mascot.seviye}',
                      style: TextStyle(color: vibe.mutedText, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
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
            ],
          ),
          const SizedBox(height: 12),
          if (odaAcik) ...[
            if (MascotServis.toklukAktif(mascot.seviye))
              MascotDurumBari(
                etiket: 'Tokluk',
                deger: (_iyimserTokluk ?? mascot.tokluk).clamp(0, 100),
                renk: Colors.orange,
                compact: true,
              ),
            if (MascotServis.enerjiAktif(mascot.seviye))
              MascotDurumBari(
                etiket: 'Enerji',
                deger: mascot.enerji,
                renk: Colors.amber,
                compact: true,
                sayiGoster: false,
              ),
            if (MascotServis.mutlulukAktif(mascot.seviye))
              MascotDurumBari(
                etiket: 'Mutluluk',
                deger: (_iyimserMutluluk ?? mascot.mutluluk).clamp(0, 100),
                renk: Colors.redAccent,
                compact: true,
              ),
          ],
          if (!kendiProfil) ...[
            const SizedBox(height: 12),
            _arkadasYemekButonu(mascot),
          ],
        ],
      ),
    );
  }

  Widget _arkadasYemekButonu(MascotDurum mascot) {
    final vibe = context.vibe;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final yemekAcik = MascotServis.yemekSistemiAcik(mascot.seviye);
    const maliyet = MascotServis.arkadasYemekVilMaliyeti;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: uid == null
          ? null
          : FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snap) {
        final vil =
            MascotServis.tryParse(snap.data?.data()?['robot'])?.vil ?? 0;
        final vilYeter = vil >= maliyet;
        final feederMap = snap.data?.data()?['robot'];
        final kalanMs = MascotServis.arkadasYemekKalanMs(
          feederRobot: feederMap is Map
              ? Map<String, dynamic>.from(feederMap)
              : const {},
          hedefUid: widget.userId,
        );
        final bugunVerildi = _yerelBugunYemek || kalanMs > 0;

        String? kilit;
        if (!yemekAcik) {
          kilit = 'Bu Vibel henüz yumurta; yemek 6. seviyede açılır.';
        } else if (mascot.uyuyor) {
          kilit = '${mascot.isim} uyuyor. Uyanınca yemek verebilirsin.';
        } else if (!_karsilikliTakip) {
          kilit = 'Karşılıklı takip gerekli.';
        } else if (bugunVerildi) {
          kilit = MascotServis.arkadasYemekBeklemeMetni(
            kalanMs > 0 ? kalanMs : MascotServis.utcGeceYarisiKalanMs(),
          );
        } else if (!vilYeter) {
          kilit = 'Vil yetersiz.';
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              label: MaestroSemantics.maskotYemekVer,
              button: true,
              child: ElevatedButton.icon(
                onPressed:
                    kilit == null ? () => _arkadasYemekVer(mascot) : null,
                icon: const Icon(Icons.restaurant, size: 18),
                label: const Text('Yemek ver'),
              ),
            ),
            if (kilit != null) ...[
              const SizedBox(height: 6),
              Text(
                kilit,
                style: TextStyle(color: vibe.mutedText, fontSize: 12),
              ),
            ],
          ],
        );
      },
    );
  }

  // Takipçi/takip sayaç kutusu
  Widget _takipSayacKutusu(
    String baslik,
    CollectionReference<Map<String, dynamic>> koleksiyon, {
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final vibe = context.vibe;

    return FutureBuilder<AggregateQuerySnapshot>(
      future: koleksiyon.count().get(),
      builder: (context, snap) {
        final sayi = snap.data?.count ?? 0;
        final kutu = Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: vibe.inputFill,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: vibe.cardBorder),
          ),
          child: Column(
            children: [
              Text(
                '$sayi',
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                baslik,
                style: TextStyle(color: vibe.mutedText, fontSize: 11),
              ),
            ],
          ),
        );

        if (onTap == null) return kutu;
        return Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: kutu,
          ),
        );
      },
    );
  }

  // Gönderi listesi bölümü
  Widget _gonderilerBolumu({
    required bool hesapGizli,
    required bool kendiProfil,
  }) {
    if (_engelledim || _beniEngelledi) {
      final vibe = context.vibe;
      final theme = Theme.of(context);
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: vibe.cardDecoration(radius: 16),
        child: Text(
          "Engelleme nedeniyle gönderiler görüntülenemiyor.",
          style: TextStyle(color: theme.colorScheme.onSurface),
        ),
      );
    }

    if (kendiProfil) {
      return _gonderiListesi(hesapGizli: hesapGizli);
    }

    final theme = Theme.of(context);
    final vibe = context.vibe;

    if (hesapGizli && _takipYukleniyor) {
      return const SizedBox.shrink();
    }

    final gonderilerGorunur =
        !hesapGizli || _takipDurumu == TakipDurumu.takipEdiliyor;

    if (!gonderilerGorunur) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: vibe.cardDecoration(radius: 20),
        child: Column(
          children: [
            Icon(Icons.lock_outline, color: vibe.mutedText, size: 40),
            const SizedBox(height: 12),
            Text(
              'Bu hesap gizli',
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Gönderileri görmek için takip et veya istek gönder.',
              textAlign: TextAlign.center,
              style: TextStyle(color: vibe.mutedText, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return _gonderiListesi(hesapGizli: hesapGizli);
  }

  /// Firestore kurallarıyla uyumlu profil gönderi sorgusu.
  Query<Map<String, dynamic>> _profilGonderiSorgusu(
      {required bool hesapGizli}) {
    return FirebaseFirestore.instance
        .collection('posts')
        .where('userId', isEqualTo: widget.userId)
        .where('raporNedeniyleGizli', isEqualTo: false)
        .where('ownerHesapGizli', isEqualTo: hesapGizli);
  }

  // Gönderi stream listesi
  Widget _gonderiListesi({required bool hesapGizli}) {
    final theme = Theme.of(context);
    final vibe = context.vibe;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? "";

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _profilGonderiSorgusu(hesapGizli: hesapGizli).snapshots(),
      builder: (context, postSnapshot) {
        if (postSnapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'Gönderiler yüklenemedi. Bağlantını veya takip durumunu kontrol et.',
                textAlign: TextAlign.center,
                style: TextStyle(color: vibe.mutedText),
              ),
            ),
          );
        }

        if (postSnapshot.connectionState == ConnectionState.waiting &&
            !postSnapshot.hasData) {
          return Center(
            child: VibeYukleniyor(renk: theme.colorScheme.primary),
          );
        }

        final docs = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
          postSnapshot.data?.docs ?? [],
        );

        docs.sort((a, b) {
          final aT = a.data()['createdAt'];
          final bT = b.data()['createdAt'];
          if (aT is Timestamp && bT is Timestamp) {
            return bT.compareTo(aT);
          }
          return 0;
        });

        if (docs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'Henüz gönderi yok',
                style: TextStyle(color: vibe.mutedText),
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _gonderiBolumBasligi(),
            const SizedBox(height: 12),
            _gonderiGorunumu == ProfilGonderiGorunumu.liste
                ? Column(
                    children: docs.map((doc) {
                      final post = doc.data();
                      return _UserProfilePostCard(
                        key: ValueKey(doc.id),
                        postId: doc.id,
                        postOwnerId: widget.userId,
                        currentUserId: currentUserId,
                        kullaniciAdi:
                            post['kullaniciAdi'] ?? 'Vibe Kullanıcısı',
                        photoUrl: (post['photoUrl'] ?? '').toString(),
                        avatarKey: (post['avatarKey'] ?? '').toString(),
                        metin: post['metin'] ?? '',
                        mentionUidleri: SosyalServis.bahsetmeUidHaritasiParse(
                          post['mentionUidleri'],
                        ),
                        baslangicBegeniSayisi:
                            _intDeger(post['begeniSayisi'], 0),
                        baslangicYorumSayisi: _intDeger(post['yorumSayisi'], 0),
                        createdAt: post['createdAt'],
                        alintiSnapshot: AlintiGonderiSnapshot.haritadan(
                          post['alintiSnapshot'],
                          postId: post['alintiPostId']?.toString(),
                          icAlintiDahilEt: false,
                        ),
                      );
                    }).toList(),
                  )
                : _profilIzgarasi(
                    docs: docs,
                    currentUserId: currentUserId,
                  ),
          ],
        );
      },
    );
  }

  Widget _gonderiBolumBasligi() {
    return Row(
      children: [
        Text(
          _gonderiGorunumu == ProfilGonderiGorunumu.liste
              ? 'Liste görünümü'
              : 'Izgara görünümü',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        ProfilGorunumAnahtari(
          gorunum: _gonderiGorunumu,
          onChanged: (gorunum) => setState(() => _gonderiGorunumu = gorunum),
        ),
      ],
    );
  }

  Widget _profilIzgarasi({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    required String currentUserId,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final sutunSayisi = constraints.maxWidth >= 760 ? 3 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: sutunSayisi,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            mainAxisExtent: 190,
          ),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final post = doc.data();
            return ProfilGonderiIzgaraKarti(
              key: ValueKey('grid_${doc.id}'),
              postId: doc.id,
              currentUserId: currentUserId,
              kullaniciAdi:
                  (post['kullaniciAdi'] ?? 'Vibe Kullanıcısı').toString(),
              createdAt: post['createdAt'],
              metin: (post['metin'] ?? '').toString(),
              begeniSayisi: _intDeger(post['begeniSayisi'], 0),
              yorumSayisi: _intDeger(post['yorumSayisi'], 0),
              alintiSnapshot: AlintiGonderiSnapshot.haritadan(
                post['alintiSnapshot'],
                postId: post['alintiPostId']?.toString(),
                icAlintiDahilEt: false,
              ),
            );
          },
        );
      },
    );
  }
}

// Profildeki gönderi kartı (başka kullanıcı)
class _UserProfilePostCard extends StatefulWidget {
  const _UserProfilePostCard({
    super.key,
    required this.postId,
    required this.postOwnerId,
    required this.currentUserId,
    required this.kullaniciAdi,
    required this.photoUrl,
    required this.avatarKey,
    required this.metin,
    this.mentionUidleri = const {},
    required this.baslangicBegeniSayisi,
    required this.baslangicYorumSayisi,
    required this.createdAt,
    this.alintiSnapshot,
  });

  final String postId; // gönderi kimliği
  final String postOwnerId; // gönderi sahibi uid
  final String currentUserId; // giriş yapmış kullanıcı uid
  final String kullaniciAdi; // gönderi sahibi kullanıcı adı
  final String photoUrl; // profil fotoğraf url'si
  final String avatarKey; // avatar anahtarı
  final String metin; // gönderi metni
  final Map<String, String> mentionUidleri; // bahsetme uid haritası
  final int baslangicBegeniSayisi; // başlangıç beğeni sayısı
  final int baslangicYorumSayisi; // başlangıç yorum sayısı
  final dynamic createdAt; // oluşturulma zamanı
  final AlintiGonderiSnapshot? alintiSnapshot;

  @override
  State<_UserProfilePostCard> createState() => _UserProfilePostCardState();
}

// Kullanıcı profil gönderi kartı durumu
class _UserProfilePostCardState extends State<_UserProfilePostCard> {
  late int yorumSayisi; // yorum sayısı
  late PostBegeniDurumuYonetici _begeni;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _postAbonelik; // gönderi sayaç aboneliği

  void _begeniYoneticiOlustur() {
    _begeni.durdur();
    _begeni = PostBegeniDurumuYonetici(
      postId: widget.postId,
      userId: widget.currentUserId,
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
      userId: widget.currentUserId,
      postOwnerId: widget.postOwnerId,
      baslangicBegeniSayisi: widget.baslangicBegeniSayisi,
    );
    _begeni.baslat(yenile: () {
      if (mounted) setState(() {});
    });
    _postSayaclariniDinle();
  }

  @override
  void didUpdateWidget(covariant _UserProfilePostCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.postId != widget.postId ||
        oldWidget.currentUserId != widget.currentUserId ||
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

  Future<void> begeniyiDegistir() => _begeni.degistir(context);

  // Yorum panelini aç
  void yorumPaneliniAc() {
    if (widget.currentUserId.isEmpty) return;
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
          userId: widget.currentUserId,
          onYorumEklendi: () {
            if (!mounted) return;
            setState(() {
              yorumSayisi += 1;
            });
          },
          onYorumSilindi: () {
            if (!mounted) return;
            setState(() {
              if (yorumSayisi > 0) yorumSayisi -= 1;
            });
          },
        );
      },
    );
  }

  // Arayüzü oluştur
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vibe = context.vibe;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: vibe.cardDecoration(radius: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: vibeAvatar(
              radius: 20,
              userId: widget.postOwnerId,
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
              _tarihSaatYaz(widget.createdAt),
              style: TextStyle(color: vibe.faintText, fontSize: 12),
            ),
          ),
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
                    ),
                    onHashtagTap: (tag) => etiketSayfasinaGit(context, tag),
                  ),
                if (widget.alintiSnapshot != null) ...[
                  if (widget.metin.isNotEmpty) const SizedBox(height: 10),
                  AlintiGonderiOnizleme(
                    snapshot: widget.alintiSnapshot!,
                    currentUserId: widget.currentUserId,
                    compact: true,
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                InkWell(
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
                InkWell(
                  borderRadius: BorderRadius.circular(28),
                  onTap: widget.currentUserId == widget.postOwnerId
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
                      style: TextStyle(color: vibe.mutedText, fontSize: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 18),
                InkWell(
                  borderRadius: BorderRadius.circular(28),
                  onTap: yorumPaneliniAc,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
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
                          style: TextStyle(color: vibe.mutedText, fontSize: 14),
                        ),
                      ],
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
