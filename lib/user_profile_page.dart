// Başka kullanıcının profili: takip, engel, mesaj ve gönderi listesi
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:vibe_life/app_theme.dart';
import 'package:vibe_life/error_messages.dart';
import 'package:vibe_life/follow_list_page.dart';
import 'package:vibe_life/messages_page.dart';
import 'package:vibe_life/puan_animasyon.dart';
import 'package:vibe_life/sosyal_servis.dart';
import 'package:vibe_life/etiket_navigasyon.dart';
import 'package:vibe_life/widgets/hashtag_metin.dart';
import 'package:vibe_life/widgets/post_begeni_yardimci.dart';
import 'package:vibe_life/robot_servis.dart';
import 'package:vibe_life/widgets/robot_durum_bari.dart';
import 'package:vibe_life/widgets/robot_lottie_view.dart';
import 'package:vibe_life/widgets/vibe_avatar.dart';
import 'package:vibe_life/vibe_snackbar.dart';

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
    final durum = await SosyalServis.takipDurumuGetir(widget.userId);
    if (!mounted) return;
    setState(() {
      _takipDurumu = durum;
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

    setState(() => _takipIslemiSuruyor = true);

    final mesaj =
        await SosyalServis.takipButonunaBas(widget.userId, _takipDurumu);
    final yeniDurum = await SosyalServis.takipDurumuGetir(widget.userId);

    if (!mounted) return;

    setState(() {
      _takipDurumu = yeniDurum;
      _takipIslemiSuruyor = false;
    });

    if (mesaj.contains('+5')) {
      puanAnimasyonuGoster(context, 5);
    }

    if (mounted && mesaj.isNotEmpty) {
      vibeSnackbarGoster(context, mesaj, tip: VibeMesajTipi.bilgi);
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

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(widget.userId)
              .snapshots(),
          builder: (context, snapshot) {
            final kullaniciAdi =
                snapshot.data?.data()?['kullaniciAdi'] ?? 'Profil';
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
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return Center(
              child: CircularProgressIndicator(
                color: theme.colorScheme.primary,
              ),
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

          final mascotData = data['robot'];
          final mascotDurum = MascotServis.parse(mascotData);

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: vibeAvatar(
                    radius: 48,
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
                      Text(
                        '@$kullaniciAdi',
                        style: TextStyle(
                          color: vibe.mutedText,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _mascotKarti(mascotDurum),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _takipSayacKutusu(
                        'Takipçi',
                        FirebaseFirestore.instance
                            .collection('users')
                            .doc(widget.userId)
                            .collection('followers')
                            .snapshots(),
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
                          Navigator.push(
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
                            .collection('following')
                            .snapshots(),
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
                          Navigator.push(
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
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final navigator = Navigator.of(context);

                        // hata yakalamalı blok
                        try {
                          final chatId =
                              await SosyalServis.sohbetIdGetirVeyaOlustur(
                                  widget.userId);
                          if (!mounted) return;
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
                          // hata yakala
                        } catch (e) {
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
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: const Text("Mesaj Gönder"),
                    ),
                  ),
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

  // Maskot durum kartı
  Widget _mascotKarti(MascotDurum mascot) {
    final theme = Theme.of(context);
    final vibe = context.vibe;
    final odaAcik = MascotServis.odaAcik(mascot.seviye);
    final mesaj = MascotServis.ruhHaliMesaji(mascot);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: vibe.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 86,
                height: 86,
                child: MascotLottieView(
                  seviye: mascot.seviye,
                  gorselDurum: mascot.gorselDurum,
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
                    if (odaAcik)
                      Text(
                        mesaj,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: VibeAppTheme.accent,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      )
                    else
                      Text(
                        '${MascotServis.odaAcilisSeviyesi}. seviyede maskot sistemi açılır.',
                        style: TextStyle(color: vibe.mutedText, fontSize: 12),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (odaAcik) ...[
            MascotDurumBari(
              etiket: 'Enerji',
              deger: mascot.enerji,
              renk: Colors.amber,
              compact: true,
            ),
            MascotDurumBari(
              etiket: 'Mutluluk',
              deger: mascot.mutluluk,
              renk: Colors.pinkAccent,
              compact: true,
            ),
          ],
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: mascot.gelisimOrani,
              backgroundColor: vibe.inputFill,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(VibeAppTheme.accent),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Gelişim: ${mascot.gelisimPuani} / ${mascot.gerekliGelisim}',
            style: TextStyle(color: vibe.faintText, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // Takipçi/takip sayaç kutusu
  Widget _takipSayacKutusu(
    String baslik,
    Stream<QuerySnapshot<Map<String, dynamic>>> stream, {
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final vibe = context.vibe;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        final sayi = snap.data?.docs.length ?? 0;
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
                  fontSize: 17,
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
        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: kutu,
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

    if (_takipYukleniyor) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: CircularProgressIndicator(color: theme.colorScheme.primary),
        ),
      );
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
            child: CircularProgressIndicator(
              color: theme.colorScheme.primary,
            ),
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
          children: docs.map((doc) {
            final post = doc.data();
            return _UserProfilePostCard(
              key: ValueKey(doc.id),
              postId: doc.id,
              postOwnerId: widget.userId,
              currentUserId: currentUserId,
              kullaniciAdi: post['kullaniciAdi'] ?? 'Vibe Kullanıcısı',
              photoUrl: (post['photoUrl'] ?? '').toString(),
              avatarKey: (post['avatarKey'] ?? '').toString(),
              metin: post['metin'] ?? '',
              mentionUidleri: SosyalServis.bahsetmeUidHaritasiParse(
                post['mentionUidleri'],
              ),
              baslangicBegeniSayisi: _intDeger(post['begeniSayisi'], 0),
              baslangicYorumSayisi: _intDeger(post['yorumSayisi'], 0),
              createdAt: post['createdAt'],
            );
          }).toList(),
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
        return _UserProfileYorumPaneli(
          postId: widget.postId,
          postOwnerId: widget.postOwnerId,
          userId: widget.currentUserId,
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
              _tarihSaatYaz(widget.createdAt),
              style: TextStyle(color: vibe.faintText, fontSize: 12),
            ),
          ),
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
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(28),
                  onTap: begeniyiDegistir,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        Icon(
                          _begeni.begenildi
                              ? Icons.favorite
                              : Icons.favorite_border,
                          color: Colors.redAccent,
                          size: 26,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "${_begeni.begeniSayisi}",
                          style: TextStyle(color: vibe.mutedText, fontSize: 14),
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
                        horizontal: 14, vertical: 10),
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

// Kullanıcı profil yorum paneli
class _UserProfileYorumPaneli extends StatefulWidget {
  const _UserProfileYorumPaneli({
    required this.postId,
    required this.postOwnerId,
    required this.userId,
    required this.onYorumEklendi,
  });

  final String postId; // gönderi kimliği
  final String postOwnerId; // gönderi sahibi uid
  final String userId; // oturum açmış kullanıcı uid
  final VoidCallback onYorumEklendi; // yorum eklendi geri çağrısı

  @override
  State<_UserProfileYorumPaneli> createState() =>
      _UserProfileYorumPaneliState();
}

// Yorum paneli durumu
class _UserProfileYorumPaneliState extends State<_UserProfileYorumPaneli> {
  final TextEditingController yorumController = TextEditingController();
  bool isLoading = false; // yükleme durumu

  // Abonelik ve kontrolcüleri temizle
  @override
  void dispose() {
    yorumController.dispose();
    super.dispose();
  }

  // Yorum ekle
  Future<void> yorumEkle() async {
    final metin = yorumController.text.trim();
    if (metin.isEmpty) return;

    setState(() => isLoading = true);

    // hata yakalamalı blok
    try {
      await SosyalServis.yorumEkle(
        postId: widget.postId,
        postOwnerId: widget.postOwnerId,
        currentUserId: widget.userId,
        metin: metin,
      );
      yorumController.clear();
      widget.onYorumEklendi();
      if (mounted && widget.userId != widget.postOwnerId) {
        puanAnimasyonuGoster(context, 3);
      }
      // hata yakala
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
      // temizlik
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // Arayüzü oluştur
  @override
  Widget build(BuildContext context) {
    final altBosluk = MediaQuery.of(context).viewInsets.bottom;
    final vibe = context.vibe;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Padding(
      padding: EdgeInsets.only(bottom: altBosluk),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.72,
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
            const SizedBox(height: 14),
            Text(
              "Yorumlar",
              style: TextStyle(
                color: onSurface,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Divider(color: vibe.cardBorder),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection("posts")
                    .doc(widget.postId)
                    .collection("comments")
                    .orderBy("createdAt", descending: false)
                    .snapshots(),
                builder: (context, snapshot) {
                  final comments = snapshot.data?.docs ?? [];
                  if (comments.isEmpty) {
                    return Center(
                      child: Text(
                        "Henüz yorum yok.",
                        style: TextStyle(color: onSurface),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: comments.length,
                    itemBuilder: (context, index) {
                      final yorum = comments[index].data();
                      if (yorum["raporNedeniyleGizli"] == true) {
                        return const SizedBox.shrink();
                      }
                      return ListTile(
                        leading: vibeAvatar(
                          radius: 18,
                          photoUrl: "",
                          avatarKey: "",
                          fallbackText: yorum["kullaniciAdi"]?.toString() ??
                              "Vibe Kullanıcısı",
                          emojiSize: 16,
                          fallbackIconSize: 18,
                        ),
                        title: Text(
                          yorum["kullaniciAdi"] ?? "Vibe Kullanıcısı",
                          style: TextStyle(
                            color: onSurface,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              yorum["metin"] ?? "",
                              style: TextStyle(
                                color: onSurface,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _tarihSaatYaz(yorum["createdAt"]),
                              style: TextStyle(
                                color: vibe.faintText,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: yorumController,
                      style: TextStyle(color: onSurface),
                      decoration: InputDecoration(
                        hintText: "Yorum yaz...",
                        hintStyle: TextStyle(color: vibe.faintText),
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
                        ? CircularProgressIndicator(color: onSurface)
                        : const Icon(Icons.send, color: Colors.redAccent),
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
