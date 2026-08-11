// Kendi profil sayfası: bilgi kartı, maskot gelişimi, gönderiler, ayarlar ve moderasyon
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibe_life/app_check_config.dart';
import 'package:vibe_life/app_check_debug.dart';
import 'package:vibe_life/app_theme.dart';
import 'package:vibe_life/error_messages.dart';
import 'package:vibe_life/hesap_sil_servis.dart';
import 'package:vibe_life/auth_eposta.dart' as auth_eposta;
import 'package:vibe_life/sifre_degistir_servis.dart';
import 'package:vibe_life/follow_list_page.dart';
import 'package:vibe_life/leaderboard_page.dart';
import 'package:vibe_life/maestro_semantics.dart';
import 'package:vibe_life/puan_animasyon.dart';
import 'package:vibe_life/sosyal_servis.dart';
import 'package:vibe_life/destek_talepleri_panel_page.dart';
import 'package:vibe_life/etiket_navigasyon.dart';
import 'package:vibe_life/widgets/hashtag_metin.dart';
import 'package:vibe_life/robot_page.dart';
import 'package:vibe_life/robot_servis.dart';
import 'package:vibe_life/legal_pages.dart';
import 'package:vibe_life/widgets/robot_durum_bari.dart';
import 'package:vibe_life/widgets/robot_lottie_view.dart';
import 'package:vibe_life/widgets/post_begeni_yardimci.dart';
import 'package:vibe_life/widgets/theme_mode_segment.dart';
import 'package:vibe_life/widgets/vibe_avatar.dart';
import 'package:vibe_life/vibe_snackbar.dart';

// Firestore Timestamp'i okunabilir tarihe çevir
String tarihSaatYaz(dynamic value) {
  if (value is! Timestamp) return "Tarih yok";

  final tarih = value.toDate();
  final gun = tarih.day.toString().padLeft(2, "0");
  final ay = tarih.month.toString().padLeft(2, "0");
  final yil = tarih.year.toString();
  final saat = tarih.hour.toString().padLeft(2, "0");
  final dakika = tarih.minute.toString().padLeft(2, "0");

  return "$gun.$ay.$yil $saat:$dakika";
}

// Kendi profil sayfası widget'ı
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

// Profil sayfası durumu ve iş mantığı
class _ProfilePageState extends State<ProfilePage> {
  int seciliSekme = 0; // seçili profil sekmesi
  final Set<String> _silinenPostIdleri =
      {}; // optimistik silinen gönderi id'leri
  QuerySnapshot<Map<String, dynamic>>?
      _sunucuGonderiSnap; // sunucudan gelen gönderi snapshot'ı
  QuerySnapshot<Map<String, dynamic>>?
      _bekleyenOnbellekGonderiSnap; // önbellekten bekleyen gönderi snapshot'ı
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _gonderiAbonelik; // gönderi stream aboneliği
  Timer? _gonderiOnbellekZamanAsimi; // önbellek gecikme zamanlayıcısı

  // Widget ilk yüklendiğinde çalışır
  @override
  void initState() {
    super.initState();
    _gonderiDinlemeyiBaslat();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _gecersizBegeniKayitlariniTemizle();
    });
  }

  void _gecersizBegeniKayitlariniTemizle() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final prefs = await SharedPreferences.getInstance();
    const key = 'begeni_temizlik_ts';
    final last = prefs.getInt(key) ?? 0;
    if (DateTime.now().millisecondsSinceEpoch - last <
        const Duration(days: 1).inMilliseconds) {
      return;
    }
    await prefs.setInt(key, DateTime.now().millisecondsSinceEpoch);
    unawaited(SosyalServis.gecersizBegeniKayitlariniTemizle(uid));
  }

  // Abonelik ve kontrolcüleri temizle
  @override
  void dispose() {
    _gonderiAbonelik?.cancel();
    _gonderiOnbellekZamanAsimi?.cancel();
    super.dispose();
  }

  // Kullanıcının gönderilerini dinlemeye başla
  void _gonderiDinlemeyiBaslat() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _gonderiAbonelik?.cancel();
    _gonderiOnbellekZamanAsimi?.cancel();
    _gonderiAbonelik = FirebaseFirestore.instance
        .collection("posts")
        .where("userId", isEqualTo: uid)
        .orderBy("createdAt", descending: true)
        .limit(40)
        .snapshots()
        .listen(_gonderiSnapIsle);
  }

  // Gönderi snapshot'ını işle
  void _gonderiSnapIsle(QuerySnapshot<Map<String, dynamic>> snap) {
    if (!mounted) return;

    if (!snap.metadata.isFromCache) {
      _gonderiOnbellekZamanAsimi?.cancel();
      _gonderiOnbellekZamanAsimi = null;
      _bekleyenOnbellekGonderiSnap = null;
      final mevcutIdler = snap.docs.map((d) => d.id).toSet();
      _silinenPostIdleri.removeWhere((id) => !mevcutIdler.contains(id));
      setState(() => _sunucuGonderiSnap = snap);
      return;
    }

    if (_sunucuGonderiSnap != null) return;

    _bekleyenOnbellekGonderiSnap = snap;
    _gonderiOnbellekZamanAsimi ??= Timer(
      const Duration(milliseconds: 1500),
      () {
        if (!mounted || _sunucuGonderiSnap != null) return;
        final onbellek = _bekleyenOnbellekGonderiSnap;
        if (onbellek == null) return;
        setState(() => _sunucuGonderiSnap = onbellek);
      },
    );
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>>
      _gorunenProfilGonderileri() {
    final snap = _sunucuGonderiSnap;
    if (snap == null) return [];

    final docs =
        snap.docs.where((doc) => !_silinenPostIdleri.contains(doc.id)).toList()
          ..sort(
            (a, b) => _tarihAl(b.data()).compareTo(_tarihAl(a.data())),
          );
    return docs;
  }

  // Gönderi yükleniyor göstergesi
  Widget _profilGonderiYukleniyor() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 18),
      child: Center(
        child: CircularProgressIndicator(
          color: Colors.redAccent,
          strokeWidth: 2,
        ),
      ),
    );
  }

  // Dinamik değeri int'e çevir
  int _intDeger(dynamic value, int varsayilan) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return varsayilan;
  }

  DateTime _tarihAl(Map<String, dynamic>? data) {
    final createdAt = data?["createdAt"];
    if (createdAt is Timestamp) return createdAt.toDate();
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  Map<String, dynamic> _begenilenPostVerisi(
    QueryDocumentSnapshot<Map<String, dynamic>> liked,
  ) {
    final likedData = liked.data();
    return {
      'userId': likedData['postOwnerId'] ?? '',
      'kullaniciAdi': likedData['kullaniciAdi'] ?? 'Vibe Kullanıcısı',
      'metin': likedData['metin'] ?? '',
      'photoUrl': likedData['photoUrl'] ?? '',
      'avatarKey': likedData['avatarKey'] ?? '',
      'ownerHesapGizli': likedData['ownerHesapGizli'] == true,
      'raporNedeniyleGizli': likedData['raporNedeniyleGizli'] == true,
      'begeniSayisi': 0,
      'yorumSayisi': 0,
      'createdAt': likedData['createdAt'],
    };
  }

  // Snackbar ile mesaj göster
  void mesajGoster(String mesaj, {VibeMesajTipi tip = VibeMesajTipi.hata}) {
    if (!mounted) return;
    vibeSnackbarGoster(context, mesaj, tip: tip);
  }

  // Maskot ismini değiştir
  Future<void> mascotIsminiDegistir(String mevcutIsim) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final yeniIsim = await showDialog<String>(
      context: context,
      builder: (context) => _MascotIsimDialog(mevcutIsim: mevcutIsim),
    );

    if (!mounted || yeniIsim == null || yeniIsim.isEmpty) return;

    // hata yakalamalı blok
    try {
      await MascotServis.isimGuncelle(user.uid, yeniIsim);
      mesajGoster("Maskot ismi güncellendi.", tip: VibeMesajTipi.basari);
      // hata yakala
    } catch (e) {
      mesajGoster(
        internetAwareErrorMessage(
          error: e,
          fallback: "Maskot ismi güncellenemedi.",
        ),
      );
    }
  }

  // Profili düzenle
  Future<void> profiliDuzenle({
    required String adSoyad,
    required String kullaniciAdi,
    required String email,
    required String avatarKey,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final sonuc = await showDialog<_ProfilDuzenleSonucu>(
      context: context,
      builder: (context) => _ProfilDuzenleDialog(
        adSoyad: adSoyad,
        kullaniciAdi: kullaniciAdi,
        email: email,
        avatarKey: avatarKey,
      ),
    );

    if (sonuc == null) return;

    if (sonuc.adSoyad.isEmpty ||
        sonuc.kullaniciAdi.isEmpty ||
        sonuc.email.isEmpty) {
      mesajGoster("Ad soyad, kullanıcı adı ve e-posta boş olamaz.");
      return;
    }

    // hata yakalamalı blok
    try {
      bool emailGuncellendi = true;

      if (sonuc.email != (user.email ?? email)) {
        // hata yakalamalı blok
        try {
          await user.verifyBeforeUpdateEmail(sonuc.email);
          emailGuncellendi = false;
          mesajGoster(
            "Doğrulama maili gönderildi. E-postanı onayladıktan sonra güncellenecek.",
          );
        } on FirebaseAuthException catch (_) {
          emailGuncellendi = false;
        }
      }

      await user.updateDisplayName(sonuc.kullaniciAdi);

      final firestore = FirebaseFirestore.instance;
      final userRef = firestore.collection("users").doc(user.uid);
      final mevcutDoc = await userRef.get();
      final mevcutData = mevcutDoc.data() ?? {};
      final eskiKullaniciAdiKucuk =
          (mevcutData["kullaniciAdiKucuk"] ?? kullaniciAdi.toLowerCase())
              .toString();
      final yeniKullaniciAdiKucuk =
          SosyalServis.etiketNormalize(sonuc.kullaniciAdi);

      if (yeniKullaniciAdiKucuk.length < 3) {
        mesajGoster("Kullanıcı adı en az 3 karakter olmalı.");
        return;
      }
      final kullaniciAdiRegex = RegExp(r'^[a-z0-9_\.]+$');
      if (!kullaniciAdiRegex.hasMatch(yeniKullaniciAdiKucuk)) {
        mesajGoster(
          "Kullanıcı adında sadece harf, sayı, nokta ve alt çizgi kullan.",
        );
        return;
      }

      await SosyalServis.kullaniciAdiGuncelle(
        uid: user.uid,
        eskiKullaniciAdiKucuk: eskiKullaniciAdiKucuk,
        yeniKullaniciAdi: sonuc.kullaniciAdi,
        yeniKullaniciAdiKucuk: yeniKullaniciAdiKucuk,
      );

      await userRef.update({
        "adSoyad": sonuc.adSoyad,
        "kullaniciAdi": sonuc.kullaniciAdi,
        "kullaniciAdiKucuk": yeniKullaniciAdiKucuk,
        "avatarKey": sonuc.avatarKey,
        if (emailGuncellendi) "email": sonuc.email,
      });

      final posts = await firestore
          .collection("posts")
          .where("userId", isEqualTo: user.uid)
          .get();

      if (posts.docs.isNotEmpty) {
        var batch = firestore.batch();
        var sayac = 0;

        for (final doc in posts.docs) {
          batch.update(doc.reference, {
            "kullaniciAdi": sonuc.kullaniciAdi,
            "avatarKey": sonuc.avatarKey,
          });
          sayac++;
          if (sayac >= 400) {
            await batch.commit();
            batch = firestore.batch();
            sayac = 0;
          }
        }

        if (sayac > 0) {
          await batch.commit();
        }
      }

      if (emailGuncellendi) {
        mesajGoster("Profil güncellendi.", tip: VibeMesajTipi.basari);
      } else {
        mesajGoster(
          "Profil güncellendi. E-posta değiştirmek için tekrar giriş gerekebilir.",
        );
      }
      // hata yakala
    } catch (e) {
      mesajGoster(
        internetAwareErrorMessage(
          error: e,
          fallback: "Profil güncellenemedi.",
        ),
      );
    }
  }

  // Gönderiyi sil
  Future<void> gonderiSil(String postId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final onay = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.vibe.dialogBackground,
        title: Text(
          "Gönderi silinsin mi?",
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        content: Text(
          "Bu işlem geri alınamaz.",
          style: TextStyle(color: context.vibe.mutedText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Vazgeç"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Sil"),
          ),
        ],
      ),
    );

    if (onay != true) return;

    setState(() => _silinenPostIdleri.add(postId));

    // hata yakalamalı blok
    try {
      await SosyalServis.gonderiSil(postId);
      mesajGoster("Gönderi silindi.", tip: VibeMesajTipi.basari);
      // hata yakala
    } catch (e) {
      if (mounted) {
        setState(() => _silinenPostIdleri.remove(postId));
      }
      mesajGoster(
        internetAwareErrorMessage(
          error: e,
          fallback: "Gönderi silinemedi.",
        ),
      );
    }
  }

  // Şifre değiştirme paneli
  Future<void> sifreDegistirPaneliniAc() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => const _SifreDegistirDialog(),
    );
  }

  // Şifre sıfırlama maili gönder
  Future<void> sifreSifirlamaMailiGonder() async {
    final email = FirebaseAuth.instance.currentUser?.email;

    if (email == null || email.isEmpty) {
      mesajGoster("E-posta adresi bulunamadı.");
      return;
    }

    try {
      await auth_eposta.sifreSifirlamaMailiGonder(email);
      mesajGoster(
        "Şifre sıfırlama maili gönderildi.",
        tip: VibeMesajTipi.bilgi,
      );
    } on FirebaseAuthException catch (e) {
      mesajGoster(auth_eposta.sifreSifirlamaHataMesaji(e));
    } catch (e) {
      mesajGoster(
        internetAwareErrorMessage(
          error: e,
          fallback: "Şifre sıfırlama maili gönderilemedi.",
        ),
      );
    }
  }

  // Çıkış yap
  Future<void> cikisYap() async {
    await FirebaseAuth.instance.signOut();
  }

  // Hesap silme paneli
  Future<void> hesapSilPaneliniAc() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => const _HesapSilDialog(),
    );
  }

  // Engellenenler paneli
  Future<void> engellenenlerPaneliniAc() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await showModalBottomSheet(
      context: context,
      backgroundColor: context.vibe.sheetBackground,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final vibe = sheetContext.vibe;
        final theme = Theme.of(sheetContext);
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(sheetContext).size.height * 0.72,
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
                  "Engellenenler",
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection("users")
                        .doc(user.uid)
                        .collection("blocked")
                        .orderBy("createdAt", descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      final docs = snapshot.data?.docs ?? [];
                      if (docs.isEmpty) {
                        return Center(
                          child: Text(
                            "Engellediğin kullanıcı yok.",
                            style: TextStyle(color: vibe.mutedText),
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final hedefUid = docs[index].id;
                          return FutureBuilder<
                              DocumentSnapshot<Map<String, dynamic>>>(
                            future: FirebaseFirestore.instance
                                .collection("users")
                                .doc(hedefUid)
                                .get(),
                            builder: (context, userSnap) {
                              final userData = userSnap.data?.data() ?? {};
                              final adSoyad =
                                  (userData["adSoyad"] ?? "Vibe Kullanıcısı")
                                      .toString();
                              final kullaniciAdi =
                                  (userData["kullaniciAdi"] ?? "kullanici")
                                      .toString();
                              final photoUrl =
                                  (userData["photoUrl"] ?? "").toString();
                              final avatarKey =
                                  (userData["avatarKey"] ?? "").toString();

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: vibe.cardDecoration(radius: 14),
                                child: ListTile(
                                  leading: vibeAvatar(
                                    radius: 20,
                                    photoUrl: photoUrl,
                                    avatarKey: avatarKey,
                                    fallbackText: kullaniciAdi,
                                    emojiSize: 18,
                                    fallbackIconSize: 20,
                                    fallbackForegroundColor:
                                        theme.colorScheme.onPrimary,
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
                                  trailing: TextButton(
                                    onPressed: () async {
                                      // hata yakalamalı blok
                                      try {
                                        await SosyalServis.engeliKaldir(
                                            hedefUid);
                                        if (context.mounted) {
                                          vibeSnackbarGoster(
                                            context,
                                            "Kullanıcı engelden çıkarıldı.",
                                            tip: VibeMesajTipi.basari,
                                          );
                                        }
                                        // hata yakala
                                      } catch (e) {
                                        if (context.mounted) {
                                          vibeSnackbarGoster(
                                            context,
                                            internetAwareErrorMessage(
                                              error: e,
                                              fallback: "Engel kaldırılamadı.",
                                            ),
                                          );
                                        }
                                      }
                                    },
                                    child: const Text("Engeli Kaldır"),
                                  ),
                                ),
                              );
                            },
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
      },
    );
  }

  // Hesap gizliliğini değiştir
  Future<void> hesapGizliliginiDegistir(bool yeniDeger) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // hata yakalamalı blok
    try {
      await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .update({"hesapGizli": yeniDeger});

      await SosyalServis.kullaniciGonderilerindeGizlilikGuncelle(
        user.uid,
        yeniDeger,
      );

      mesajGoster(
        yeniDeger
            ? "Hesabın gizli yapıldı. Gönderilerin başkalarına görünmez."
            : "Hesabın herkese açık yapıldı.",
      );
      // hata yakala
    } catch (e) {
      mesajGoster(
        internetAwareErrorMessage(
          error: e,
          fallback: "Gizlilik ayarı güncellenemedi.",
        ),
      );
    }
  }

  // Ayarlar paneli
  void ayarlarPaneliniAc(
    String mascotIsim,
    bool baslangicHesapGizli,
    int seviye,
    bool isModerator,
  ) {
    bool hesapGizli = baslangicHesapGizli;

    final vibe = context.vibe;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: vibe.sheetBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final sheetVibe = sheetContext.vibe;
        final onSurface = Theme.of(sheetContext).colorScheme.onSurface;
        final maxSheetHeight = MediaQuery.of(sheetContext).size.height * 0.9;
        final user = FirebaseAuth.instance.currentUser;
        final sifreHesabi =
            user != null && auth_eposta.epostaSifreKullanicisiMi(user);

        return StatefulBuilder(
          builder: (context, sheetSetState) {
            return SafeArea(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxSheetHeight),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 10),
                      Container(
                        width: 42,
                        height: 5,
                        decoration: BoxDecoration(
                          color: sheetVibe.faintText,
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      const ThemeModeSegment(),
                      SwitchListTile(
                        secondary: Icon(Icons.lock_outline,
                            color: sheetVibe.mutedText),
                        title: Text(
                          "Gizli Hesap",
                          style: TextStyle(color: onSurface),
                        ),
                        subtitle: Text(
                          "Gönderilerin başkalarına görünmez",
                          style: TextStyle(
                              color: sheetVibe.mutedText, fontSize: 12),
                        ),
                        value: hesapGizli,
                        activeColor: Colors.redAccent,
                        onChanged: (value) async {
                          sheetSetState(() => hesapGizli = value);
                          await hesapGizliliginiDegistir(value);
                        },
                      ),
                      ListTile(
                        leading: MascotLottieView(
                          seviye: seviye,
                          width: 24,
                          height: 24,
                          fit: BoxFit.contain,
                          tamEkranAc: false,
                        ),
                        title: Text(
                          "Maskot İsmini Değiştir",
                          style: TextStyle(color: onSurface),
                        ),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          mascotIsminiDegistir(mascotIsim);
                        },
                      ),
                      if (isModerator) ...[
                        ListTile(
                          leading: Icon(Icons.admin_panel_settings,
                              color: sheetVibe.mutedText),
                          title: Text(
                            "Moderasyon Paneli",
                            style: TextStyle(color: onSurface),
                          ),
                          onTap: () {
                            Navigator.pop(sheetContext);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const _ModerasyonPanelPage(),
                              ),
                            );
                          },
                        ),
                        ListTile(
                          leading: Icon(Icons.inbox_outlined,
                              color: sheetVibe.mutedText),
                          title: Text(
                            "Destek Talepleri",
                            style: TextStyle(color: onSurface),
                          ),
                          onTap: () {
                            Navigator.pop(sheetContext);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const DestekTalepleriPanelPage(),
                              ),
                            );
                          },
                        ),
                      ],
                      ListTile(
                        leading: Icon(Icons.block, color: sheetVibe.mutedText),
                        title: Text(
                          "Engellenenler",
                          style: TextStyle(color: onSurface),
                        ),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          engellenenlerPaneliniAc();
                        },
                      ),
                      if (sifreHesabi)
                        ListTile(
                          leading: Icon(Icons.lock, color: sheetVibe.mutedText),
                          title: Text(
                            "Şifre Değiştir",
                            style: TextStyle(color: onSurface),
                          ),
                          subtitle: Text(
                            "Mevcut şifreni girerek güncelle",
                            style: TextStyle(
                                color: sheetVibe.mutedText, fontSize: 12),
                          ),
                          onTap: () {
                            Navigator.pop(sheetContext);
                            sifreDegistirPaneliniAc();
                          },
                        ),
                      if (sifreHesabi)
                        ListTile(
                          leading: Icon(Icons.lock_reset,
                              color: sheetVibe.mutedText),
                          title: Text(
                            "Şifre Sıfırlama Maili Gönder",
                            style: TextStyle(color: onSurface),
                          ),
                          onTap: () async {
                            Navigator.pop(sheetContext);
                            await sifreSifirlamaMailiGonder();
                          },
                        ),
                      if (appCheckBetaModu)
                        ListTile(
                          leading:
                              Icon(Icons.security, color: sheetVibe.mutedText),
                          title: Text(
                            "App Check Token (Firebase)",
                            style: TextStyle(color: onSurface),
                          ),
                          subtitle: Text(
                            "Test cihazı için Firebase Console'a eklenecek kod",
                            style: TextStyle(
                                color: sheetVibe.mutedText, fontSize: 12),
                          ),
                          onTap: () {
                            Navigator.pop(sheetContext);
                            appCheckDebugTokenGoster(context);
                          },
                        ),
                      ListTile(
                        leading: Icon(Icons.privacy_tip_outlined,
                            color: sheetVibe.mutedText),
                        title: Text(
                          "Gizlilik Politikası",
                          style: TextStyle(color: onSurface),
                        ),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const PrivacyPolicyPage(),
                            ),
                          );
                        },
                      ),
                      ListTile(
                        leading: Icon(Icons.gavel_outlined,
                            color: sheetVibe.mutedText),
                        title: Text(
                          "KVKK Aydınlatma Metni",
                          style: TextStyle(color: onSurface),
                        ),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const KvkkPage(),
                            ),
                          );
                        },
                      ),
                      ListTile(
                        leading: Icon(Icons.help_outline,
                            color: sheetVibe.mutedText),
                        title: Text(
                          "Yardım / SSS",
                          style: TextStyle(color: onSurface),
                        ),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const HelpFaqPage(),
                            ),
                          );
                        },
                      ),
                      ListTile(
                        leading: Icon(Icons.new_releases_outlined,
                            color: sheetVibe.mutedText),
                        title: Text(
                          "Sürüm Notları",
                          style: TextStyle(color: onSurface),
                        ),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ChangelogPage(),
                            ),
                          );
                        },
                      ),
                      ListTile(
                        leading: Icon(Icons.support_agent,
                            color: sheetVibe.mutedText),
                        title: Text(
                          "Destek ve Geri Bildirim",
                          style: TextStyle(color: onSurface),
                        ),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ContactPage(),
                            ),
                          );
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.delete_forever,
                            color: Colors.redAccent),
                        title: const Text(
                          "Hesabı Sil",
                          style: TextStyle(color: Colors.redAccent),
                        ),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          hesapSilPaneliniAc();
                        },
                      ),
                      ListTile(
                        leading:
                            const Icon(Icons.logout, color: Colors.redAccent),
                        title: const Text(
                          "Çıkış Yap",
                          style: TextStyle(color: Colors.redAccent),
                        ),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          cikisYap();
                        },
                      ),
                    ],
                  ),
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

    if (user == null) {
      return const Center(
        child: Text(
          "Kullanıcı bulunamadı.",
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    return SafeArea(
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection("users")
            .doc(user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          final data = snapshot.data?.data();

          final adSoyad = data?["adSoyad"] ?? "Vibe Kullanıcısı";
          final kullaniciAdi = data?["kullaniciAdi"] ?? "kullanici";
          final email = data?["email"] ?? user.email ?? ""; // e-posta
          final photoUrl = data?["photoUrl"] ??
              user.photoURL ??
              ""; // profil fotoğraf url'si
          final avatarKey = data?["avatarKey"]?.toString() ?? "";
          final puan = _intDeger(data?["puan"], 0);

          final mascotData = data?["robot"];
          final mascotDurum = MascotServis.parse(mascotData);
          final mascotIsim = mascotDurum.isim;
          final seviye = mascotDurum.seviye;
          final hesapGizli = data?["hesapGizli"] == true;
          final isModerator = data?["isModerator"] == true;

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Column(
              children: [
                const SizedBox(height: 38),
                Row(
                  children: [
                    Text(
                      "Profil",
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LeaderboardPage(),
                          ),
                        );
                      },
                      icon: Icon(Icons.emoji_events_outlined,
                          color: context.vibe.mutedText),
                      tooltip: "Liderlik tablosu",
                    ),
                    Semantics(
                      label: MaestroSemantics.ayarlar,
                      button: true,
                      onTap: () => ayarlarPaneliniAc(
                        mascotIsim,
                        hesapGizli,
                        seviye,
                        isModerator,
                      ),
                      child: ExcludeSemantics(
                        child: IconButton(
                          onPressed: () => ayarlarPaneliniAc(
                            mascotIsim,
                            hesapGizli,
                            seviye,
                            isModerator,
                          ),
                          icon: Icon(Icons.settings,
                              color: context.vibe.mutedText),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: cikisYap,
                      icon: Icon(Icons.logout, color: context.vibe.mutedText),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _profilKarti(
                  userId: user.uid,
                  adSoyad: adSoyad,
                  kullaniciAdi: kullaniciAdi,
                  email: email,
                  photoUrl: photoUrl,
                  avatarKey: avatarKey,
                  onDuzenle: () => profiliDuzenle(
                    adSoyad: adSoyad,
                    kullaniciAdi: kullaniciAdi,
                    email: email,
                    avatarKey: avatarKey,
                  ),
                ),
                const SizedBox(height: 18),
                _mascotKarti(mascotDurum, puan),
                const SizedBox(height: 18),
                _sekmeSecici(user.uid),
                const SizedBox(height: 12),
                seciliSekme == 0
                    ? _kendiGonderilerBolumu(user.uid)
                    : _begenilenGonderilerBolumu(user.uid),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  // Profil bilgi kartı
  Widget _profilKarti({
    required String userId,
    required String adSoyad,
    required String kullaniciAdi,
    required String email,
    required String photoUrl,
    required String avatarKey,
    required VoidCallback onDuzenle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _kartDekorasyonu(),
      child: Column(
        children: [
          Row(
            children: [
              _avatar(
                photoUrl,
                avatarKey: avatarKey,
                fallbackText: kullaniciAdi,
                radius: 34,
                iconSize: 34,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "@$kullaniciAdi",
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(adSoyad,
                        style: TextStyle(color: context.vibe.mutedText)),
                    Text(
                      email,
                      style: TextStyle(
                          color: context.vibe.faintText, fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onDuzenle,
                icon: Icon(Icons.edit, color: context.vibe.mutedText, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FutureBuilder<AggregateQuerySnapshot>(
                  future: FirebaseFirestore.instance
                      .collection("users")
                      .doc(userId)
                      .collection("followers")
                      .count()
                      .get(),
                  builder: (context, countSnap) {
                    final sayi = countSnap.data?.count ?? 0;
                    return _miniSayacKutusu(
                      "Takipçi",
                      sayi,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FollowListPage(
                              userId: userId,
                              initialTab: 0,
                              kullaniciAdi: kullaniciAdi,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FutureBuilder<AggregateQuerySnapshot>(
                  future: FirebaseFirestore.instance
                      .collection("users")
                      .doc(userId)
                      .collection("following")
                      .count()
                      .get(),
                  builder: (context, countSnap) {
                    final sayi = countSnap.data?.count ?? 0;
                    return _miniSayacKutusu(
                      "Takip Edilen",
                      sayi,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FollowListPage(
                              userId: userId,
                              initialTab: 1,
                              kullaniciAdi: kullaniciAdi,
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
        ],
      ),
    );
  }

  // Mini sayaç kutusu
  Widget _miniSayacKutusu(String baslik, int sayi, {VoidCallback? onTap}) {
    final kutu = Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Text(
            "$sayi",
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            baslik,
            style: TextStyle(color: context.vibe.faintText, fontSize: 11),
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
  }

  // Maskot durum kartı
  Widget _mascotKarti(MascotDurum mascot, int kullanilabilirPuan) {
    final odaAcik = MascotServis.odaAcik(mascot.seviye);
    final mesaj = MascotServis.ruhHaliMesaji(mascot);

    return InkWell(
      onTap: odaAcik
          ? () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MascotPage()),
              );
            }
          : null,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: _kartDekorasyonu(),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 86,
                  height: 86,
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: MascotLottieView(
                      seviye: mascot.seviye,
                      gorselDurum: mascot.gorselDurum,
                      width: 86,
                      height: 86,
                      fit: BoxFit.contain,
                      repeat: false,
                    ),
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
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "Seviye ${mascot.seviye}",
                        style: TextStyle(color: context.vibe.mutedText),
                      ),
                      const SizedBox(height: 6),
                      if (odaAcik)
                        Text(
                          mascot.uyuyor
                              ? '${mascot.isim} dinleniyor — uyandırmak için odaya gir'
                              : mesaj,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: mascot.uyuyor
                                ? Colors.amberAccent
                                : VibeAppTheme.accent,
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ),
                ),
                if (odaAcik)
                  Icon(Icons.chevron_right, color: context.vibe.mutedText),
              ],
            ),
            const SizedBox(height: 14),
            if (odaAcik) ...[
              if (MascotServis.toklukAktif(mascot.seviye))
                MascotDurumBari(
                  etiket: 'Tokluk',
                  deger: mascot.tokluk,
                  renk: Colors.orangeAccent,
                  compact: true,
                ),
              if (MascotServis.enerjiAktif(mascot.seviye))
                MascotDurumBari(
                  etiket: 'Enerji',
                  deger: mascot.enerji,
                  renk: Colors.amber,
                  compact: true,
                ),
              if (MascotServis.mutlulukAktif(mascot.seviye))
                MascotDurumBari(
                  etiket: 'Mutluluk',
                  deger: mascot.mutluluk,
                  renk: Colors.pinkAccent,
                  compact: true,
                ),
            ] else
              Text(
                '1–5: Etkileşimlerle otomatik büyür. '
                '${MascotServis.toklukAcilisSeviyesi}. seviyede tokluk, '
                '${MascotServis.enerjiAcilisSeviyesi}. seviyede enerji, '
                '${MascotServis.mutlulukAcilisSeviyesi}. seviyede mutluluk açılır.',
                style: TextStyle(
                  color: context.vibe.mutedText,
                  fontSize: 12,
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  "Gelişim: ${mascot.gelisimPuani} / ${mascot.gerekliGelisim}",
                  style: TextStyle(color: context.vibe.mutedText, fontSize: 13),
                ),
                const Spacer(),
                Text(
                  "Puan: $kullanilabilirPuan",
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: mascot.gelisimOrani,
                backgroundColor: Colors.white10,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: odaAcik
                  ? Semantics(
                      label: MaestroSemantics.maskotOdasi,
                      button: true,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const MascotPage()),
                        );
                      },
                      child: ExcludeSemantics(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const MascotPage()),
                            );
                          },
                          icon: const Icon(Icons.auto_awesome),
                          label: Text('${mascot.isim} odası'),
                          style: _butonStili(),
                        ),
                      ),
                    )
                  : Text(
                      '1–5: Etkileşimlerle otomatik büyür. '
                      '6. seviyede maskot odası açılır.',
                      style: TextStyle(
                        color: context.vibe.mutedText,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // Gönderilerim / Beğendiklerim sekmeleri
  Widget _sekmeSecici(String userId) {
    final gonderiSayisi = _gorunenProfilGonderileri()
        .where((doc) => doc.data()["raporNedeniyleGizli"] != true)
        .length;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          _sekmeButonu("Gönderilerim ($gonderiSayisi)", 0),
          _sekmeButonu("Beğendiklerim", 1),
        ],
      ),
    );
  }

  // Tek sekme butonu
  Widget _sekmeButonu(String baslik, int indeks) {
    final secili = seciliSekme == indeks;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            seciliSekme = indeks;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: secili
                ? const Color.fromARGB(255, 120, 0, 0)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            baslik,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: secili
                  ? Colors.white
                  : Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  // Kendi gönderiler listesi
  Widget _kendiGonderilerBolumu(String userId) {
    if (_sunucuGonderiSnap == null) {
      return _bolumKarti(child: _profilGonderiYukleniyor());
    }

    final docs = _gorunenProfilGonderileri();
    final gorunenDocs =
        docs.where((doc) => doc.data()["raporNedeniyleGizli"] != true).toList();

    return _bolumKarti(
      child: gorunenDocs.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Text(
                "Henüz gönderin yok.",
                style: TextStyle(color: context.vibe.mutedText),
              ),
            )
          : Column(
              children: gorunenDocs.map((doc) {
                final post = doc.data();
                return _ProfilPostCard(
                  key: ValueKey(doc.id),
                  postId: doc.id,
                  postOwnerId: userId,
                  userId: userId,
                  kullaniciAdi: post["kullaniciAdi"] ?? "Vibe Kullanıcısı",
                  metin: post["metin"] ?? "",
                  mentionUidleri: SosyalServis.bahsetmeUidHaritasiParse(
                    post["mentionUidleri"],
                  ),
                  photoUrl: post["photoUrl"] ?? "",
                  avatarKey: post["avatarKey"] ?? "",
                  baslangicBegeniSayisi: _intDeger(post["begeniSayisi"], 0),
                  baslangicYorumSayisi: _intDeger(post["yorumSayisi"], 0),
                  silmeButonuGoster: true,
                  onSil: () => gonderiSil(doc.id),
                  createdAt: post["createdAt"],
                );
              }).toList(),
            ),
    );
  }

  // Beğendiklerim listesi
  Widget _begenilenGonderilerBolumu(String userId) {
    return _bolumKarti(
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection("users")
            .doc(userId)
            .collection("likedPosts")
            .orderBy("createdAt", descending: true)
            .limit(50)
            .snapshots(),
        builder: (context, likedSnap) {
          if (likedSnap.hasError) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Text(
                internetAwareErrorMessage(
                  error: likedSnap.error!,
                  fallback: "Beğenilen gönderiler yüklenemedi.",
                ),
                style: TextStyle(color: context.vibe.mutedText),
              ),
            );
          }

          if (likedSnap.connectionState == ConnectionState.waiting) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Text(
                "Beğenilen gönderiler yükleniyor...",
                style: TextStyle(color: context.vibe.mutedText),
              ),
            );
          }

          final likedDocs =
              List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
            likedSnap.data?.docs ?? [],
          )..sort(
                  (a, b) => _tarihAl(b.data()).compareTo(_tarihAl(a.data())),
                );

          if (likedDocs.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Text(
                "Henüz beğendiğin gönderi yok.",
                style: TextStyle(color: context.vibe.mutedText),
              ),
            );
          }

          return Column(
            children: likedDocs.map((liked) {
              final post = _begenilenPostVerisi(liked);
              if (post["raporNedeniyleGizli"] == true) {
                return const SizedBox.shrink();
              }

              return _ProfilPostCard(
                key: ValueKey(liked.id),
                postId: liked.id,
                postOwnerId: post["userId"] ?? "",
                userId: userId,
                kullaniciAdi: post["kullaniciAdi"] ?? "Vibe Kullanıcısı",
                metin: post["metin"] ?? "",
                mentionUidleri: const {},
                photoUrl: post["photoUrl"] ?? "",
                avatarKey: post["avatarKey"] ?? "",
                baslangicBegeniSayisi: 0,
                baslangicYorumSayisi: 0,
                baslangicBegenildi: true,
                silmeButonuGoster: false,
                createdAt: post["createdAt"],
              );
            }).toList(),
          );
        },
      ),
    );
  }

  // İçerik sarmalayan kart
  Widget _bolumKarti({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: _kartDekorasyonu(),
      child: child,
    );
  }

  // Profil avatar widget'ı
  Widget _avatar(
    String photoUrl, {
    required String avatarKey,
    required String fallbackText,
    required double radius,
    required double iconSize,
  }) {
    return vibeAvatar(
      radius: radius,
      photoUrl: photoUrl,
      avatarKey: avatarKey,
      fallbackText: fallbackText,
      emojiSize: iconSize,
      fallbackIconSize: iconSize,
    );
  }

  // kart Dekorasyonu işlemi
  BoxDecoration _kartDekorasyonu() {
    return context.vibe.cardDecoration();
  }

  // buton Stili işlemi
  ButtonStyle _butonStili() {
    return ElevatedButton.styleFrom(
      backgroundColor: context.vibe.primaryButton,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
      padding: const EdgeInsets.symmetric(vertical: 13),
    );
  }
}

// Profildeki tek gönderi kartı
class _ProfilPostCard extends StatefulWidget {
  final String postId; // gönderi kimliği
  final String postOwnerId; // gönderi sahibi uid
  final String userId; // oturum açmış kullanıcı uid
  final String kullaniciAdi; // gönderi sahibi kullanıcı adı
  final String metin; // gönderi metni
  final Map<String, String> mentionUidleri; // bahsetme uid haritası
  final String photoUrl; // profil fotoğraf url'si
  final String avatarKey; // avatar anahtarı
  final int baslangicBegeniSayisi; // başlangıç beğeni sayısı
  final int baslangicYorumSayisi; // başlangıç yorum sayısı
  final bool? baslangicBegenildi;
  final bool silmeButonuGoster; // silme butonu gösterilsin mi
  final VoidCallback? onSil; // silme geri çağrısı
  final dynamic createdAt; // oluşturulma zamanı

  const _ProfilPostCard({
    super.key,
    required this.postId,
    required this.postOwnerId,
    required this.userId,
    required this.kullaniciAdi,
    required this.metin,
    this.mentionUidleri = const {},
    required this.photoUrl,
    required this.avatarKey,
    required this.baslangicBegeniSayisi,
    required this.baslangicYorumSayisi,
    this.baslangicBegenildi,
    required this.silmeButonuGoster,
    this.onSil,
    required this.createdAt,
  });

  @override
  State<_ProfilPostCard> createState() => _ProfilPostCardState();
}

// Gönderi kartı beğeni/yorum durumu
class _ProfilPostCardState extends State<_ProfilPostCard> {
  late int yorumSayisi; // yorum sayısı
  late PostBegeniDurumuYonetici _begeni;

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

  // Widget ilk yüklendiğinde çalışır
  @override
  void initState() {
    super.initState();
    yorumSayisi = widget.baslangicYorumSayisi;
    _begeniYoneticiOlustur();
  }

  // Widget güncellendiğinde dinleyicileri yenile
  @override
  void didUpdateWidget(covariant _ProfilPostCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.postId != widget.postId ||
        oldWidget.userId != widget.userId ||
        oldWidget.postOwnerId != widget.postOwnerId) {
      _begeniYoneticiOlustur();
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

  // Abonelik ve kontrolcüleri temizle
  @override
  void dispose() {
    _begeni.durdur();
    super.dispose();
  }

  // Beğeniyi değiştir
  Future<void> begeniyiDegistir() => _begeni.degistir(context);

  // Yorum panelini aç
  void yorumPaneliniAc() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.vibe.sheetBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (context) {
        return _ProfilYorumPaneli(
          postId: widget.postId,
          postOwnerId: widget.postOwnerId,
          userId: widget.userId,
          onYorumEklendi: () {
            setState(() {
              yorumSayisi += 1;
            });
          },
        );
      },
    );
  }

  // Gönderi kartı avatarı
  Widget _postAvatar() {
    return vibeAvatar(
      radius: 20,
      photoUrl: widget.photoUrl,
      avatarKey: widget.avatarKey,
      fallbackText: widget.kullaniciAdi,
      emojiSize: 18,
      fallbackIconSize: 20,
    );
  }

  // Arayüzü oluştur
  @override
  Widget build(BuildContext context) {
    final vibe = context.vibe;
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: vibe.cardDecoration(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: _postAvatar(),
            title: Text(
              widget.kullaniciAdi,
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
            trailing: widget.silmeButonuGoster
                ? IconButton(
                    onPressed: widget.onSil,
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.redAccent,
                    ),
                  )
                : null,
            subtitle: Text(
              tarihSaatYaz(widget.createdAt),
              style: TextStyle(color: context.vibe.faintText, fontSize: 12),
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
                          style: TextStyle(
                            color: context.vibe.mutedText,
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
                        horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          color: context.vibe.mutedText,
                          size: 24,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "$yorumSayisi",
                          style: TextStyle(
                            color: context.vibe.mutedText,
                            fontSize: 14,
                          ),
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

// Gönderi yorum paneli (alt sayfa)
class _ProfilYorumPaneli extends StatefulWidget {
  final String postId; // gönderi kimliği
  final String postOwnerId; // gönderi sahibi uid
  final String userId; // oturum açmış kullanıcı uid
  final VoidCallback onYorumEklendi; // yorum eklendi geri çağrısı

  const _ProfilYorumPaneli({
    required this.postId,
    required this.postOwnerId,
    required this.userId,
    required this.onYorumEklendi,
  });

  @override
  State<_ProfilYorumPaneli> createState() => _ProfilYorumPaneliState();
}

// Yorum paneli durumu
class _ProfilYorumPaneliState extends State<_ProfilYorumPaneli> {
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
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

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
            Divider(color: theme.dividerColor),
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
                              tarihSaatYaz(yorum["createdAt"]),
                              style: TextStyle(
                                  color: vibe.faintText, fontSize: 11),
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
                        ? CircularProgressIndicator(color: onSurface)
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

// Hesap silme onay diyaloğu
class _HesapSilDialog extends StatefulWidget {
  const _HesapSilDialog();

  @override
  State<_HesapSilDialog> createState() => _HesapSilDialogState();
}

// Hesap silme diyaloğu durumu
class _HesapSilDialogState extends State<_HesapSilDialog> {
  final _sifreController = TextEditingController();
  bool _gizli = true; // şifre gizli mi
  bool _siliniyor = false; // hesap siliniyor mu
  String? _hataMesaji; // hata mesajı

  // Abonelik ve kontrolcüleri temizle
  @override
  void dispose() {
    _sifreController.dispose();
    super.dispose();
  }

  // Şifre doğrulayıp hesabı sil
  Future<void> _hesabiSil() async {
    final sifre = _sifreController.text.trim();
    if (sifre.isEmpty) {
      setState(() => _hataMesaji = "Şifre boş olamaz.");
      return;
    }

    setState(() {
      _siliniyor = true;
      _hataMesaji = null;
    });

    // hata yakalamalı blok
    try {
      await HesapSilServis.hesabiSil(sifre);
      if (!mounted) return;
      Navigator.of(context).pop();
      // hata yakala
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _siliniyor = false;
        _hataMesaji = internetAwareErrorMessage(
          error: e,
          fallback: "Hesap silinemedi.",
        );
      });
    }
  }

  // Arayüzü oluştur
  @override
  Widget build(BuildContext context) {
    final vibe = context.vibe;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return AlertDialog(
      backgroundColor: vibe.dialogBackground,
      title: Text("Hesabı Sil", style: TextStyle(color: onSurface)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Bu işlem geri alınamaz. Gönderilerin, yorumların, beğenilerin, mesajların, bildirimlerin ve profil bilgilerin kalıcı olarak silinir.",
            style: TextStyle(color: vibe.mutedText, fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _sifreController,
            obscureText: _gizli,
            enabled: !_siliniyor,
            style: TextStyle(color: onSurface),
            decoration: InputDecoration(
              hintText: "Şifreni gir",
              hintStyle: TextStyle(color: vibe.faintText),
              filled: true,
              fillColor: vibe.inputFill,
              suffixIcon: IconButton(
                icon: Icon(
                  _gizli ? Icons.visibility_off : Icons.visibility,
                  color: vibe.mutedText,
                ),
                onPressed:
                    _siliniyor ? null : () => setState(() => _gizli = !_gizli),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          if (_hataMesaji != null) ...[
            const SizedBox(height: 12),
            Text(
              _hataMesaji!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _siliniyor ? null : () => Navigator.pop(context),
          child: const Text("Vazgeç"),
        ),
        TextButton(
          onPressed: _siliniyor ? null : _hesabiSil,
          child: _siliniyor
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text(
                  "Hesabı Sil",
                  style: TextStyle(color: Colors.redAccent),
                ),
        ),
      ],
    );
  }
}

// Şifre değiştirme diyaloğu
class _SifreDegistirDialog extends StatefulWidget {
  const _SifreDegistirDialog();

  @override
  State<_SifreDegistirDialog> createState() => _SifreDegistirDialogState();
}

class _SifreDegistirDialogState extends State<_SifreDegistirDialog> {
  final _mevcutController = TextEditingController();
  final _yeniController = TextEditingController();
  final _tekrarController = TextEditingController();
  bool _mevcutGizli = true;
  bool _yeniGizli = true;
  bool _tekrarGizli = true;
  bool _kaydediliyor = false;
  String? _hataMesaji;

  @override
  void dispose() {
    _mevcutController.dispose();
    _yeniController.dispose();
    _tekrarController.dispose();
    super.dispose();
  }

  Future<void> _sifreyiDegistir() async {
    final mevcut = _mevcutController.text;
    final yeni = _yeniController.text;
    final tekrar = _tekrarController.text;

    if (mevcut.isEmpty) {
      setState(() => _hataMesaji = "Mevcut şifreni gir.");
      return;
    }
    if (yeni.length < 6) {
      setState(() => _hataMesaji = "Yeni şifre en az 6 karakter olmalı.");
      return;
    }
    if (yeni != tekrar) {
      setState(() => _hataMesaji = "Yeni şifreler eşleşmiyor.");
      return;
    }
    if (mevcut == yeni) {
      setState(() => _hataMesaji = "Yeni şifre mevcut şifreyle aynı olamaz.");
      return;
    }

    setState(() {
      _kaydediliyor = true;
      _hataMesaji = null;
    });

    try {
      await SifreDegistirServis.sifreDegistir(
        mevcutSifre: mevcut,
        yeniSifre: yeni,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      vibeSnackbarGoster(
        context,
        "Şifren güncellendi.",
        tip: VibeMesajTipi.basari,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _kaydediliyor = false;
        _hataMesaji = internetAwareErrorMessage(
          error: e,
          fallback: sifreDegistirHataMesaji(e),
        );
      });
    }
  }

  Widget _sifreAlani({
    required TextEditingController controller,
    required String hint,
    required bool gizli,
    required VoidCallback gizliligiDegistir,
  }) {
    final vibe = context.vibe;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return TextField(
      controller: controller,
      obscureText: gizli,
      enabled: !_kaydediliyor,
      style: TextStyle(color: onSurface),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: vibe.faintText),
        filled: true,
        fillColor: vibe.inputFill,
        suffixIcon: IconButton(
          icon: Icon(
            gizli ? Icons.visibility_off : Icons.visibility,
            color: vibe.mutedText,
          ),
          onPressed: _kaydediliyor ? null : gizliligiDegistir,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vibe = context.vibe;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return AlertDialog(
      backgroundColor: vibe.dialogBackground,
      title: Text("Şifre Değiştir", style: TextStyle(color: onSurface)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Güvenlik için önce mevcut şifreni, ardından yeni şifreni gir.",
              style: TextStyle(color: vibe.mutedText, fontSize: 13),
            ),
            const SizedBox(height: 16),
            _sifreAlani(
              controller: _mevcutController,
              hint: "Mevcut şifre",
              gizli: _mevcutGizli,
              gizliligiDegistir: () =>
                  setState(() => _mevcutGizli = !_mevcutGizli),
            ),
            const SizedBox(height: 12),
            _sifreAlani(
              controller: _yeniController,
              hint: "Yeni şifre",
              gizli: _yeniGizli,
              gizliligiDegistir: () => setState(() => _yeniGizli = !_yeniGizli),
            ),
            const SizedBox(height: 12),
            _sifreAlani(
              controller: _tekrarController,
              hint: "Yeni şifre tekrar",
              gizli: _tekrarGizli,
              gizliligiDegistir: () =>
                  setState(() => _tekrarGizli = !_tekrarGizli),
            ),
            if (_hataMesaji != null) ...[
              const SizedBox(height: 12),
              Text(
                _hataMesaji!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _kaydediliyor ? null : () => Navigator.pop(context),
          child: const Text("Vazgeç"),
        ),
        TextButton(
          onPressed: _kaydediliyor ? null : _sifreyiDegistir,
          child: _kaydediliyor
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text("Kaydet"),
        ),
      ],
    );
  }
}

// Maskot ismi düzenleme diyaloğu
class _MascotIsimDialog extends StatefulWidget {
  final String mevcutIsim; // mevcut maskot ismi

  const _MascotIsimDialog({required this.mevcutIsim});

  @override
  State<_MascotIsimDialog> createState() => _MascotIsimDialogState();
}

// Maskot isim diyaloğu durumu
class _MascotIsimDialogState extends State<_MascotIsimDialog> {
  late final TextEditingController controller; // metin kontrolcüsü

  // Widget ilk yüklendiğinde çalışır
  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.mevcutIsim);
  }

  // Abonelik ve kontrolcüleri temizle
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  // Arayüzü oluştur
  @override
  Widget build(BuildContext context) {
    final vibe = context.vibe;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return AlertDialog(
      backgroundColor: vibe.dialogBackground,
      title: Text("Maskot İsmi", style: TextStyle(color: onSurface)),
      content: TextField(
        controller: controller,
        maxLength: 20,
        style: TextStyle(color: onSurface),
        decoration: InputDecoration(
          hintText: "Maskotuna isim ver",
          hintStyle: TextStyle(color: vibe.faintText),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Vazgeç"),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          child: const Text("Kaydet"),
        ),
      ],
    );
  }
}

// Profil düzenleme form sonucu
class _ProfilDuzenleSonucu {
  final String adSoyad; // ad soyad
  final String kullaniciAdi; // gönderi sahibi kullanıcı adı
  final String email; // e-posta
  final String avatarKey; // avatar anahtarı

  const _ProfilDuzenleSonucu({
    required this.adSoyad,
    required this.kullaniciAdi,
    required this.email,
    required this.avatarKey,
  });
}

// Profil düzenleme diyaloğu
class _ProfilDuzenleDialog extends StatefulWidget {
  final String adSoyad; // ad soyad
  final String kullaniciAdi; // gönderi sahibi kullanıcı adı
  final String email; // e-posta
  final String avatarKey; // avatar anahtarı

  const _ProfilDuzenleDialog({
    required this.adSoyad,
    required this.kullaniciAdi,
    required this.email,
    required this.avatarKey,
  });

  @override
  State<_ProfilDuzenleDialog> createState() => _ProfilDuzenleDialogState();
}

// Profil düzenleme form durumu
class _ProfilDuzenleDialogState extends State<_ProfilDuzenleDialog> {
  late final TextEditingController adSoyadController; // ad soyad alanı
  late final TextEditingController
      kullaniciAdiController; // kullanıcı adı alanı
  late final TextEditingController emailController; // e-posta alanı
  late String seciliAvatarKey; // seçili avatar anahtarı

  // Widget ilk yüklendiğinde çalışır
  @override
  void initState() {
    super.initState();
    adSoyadController = TextEditingController(text: widget.adSoyad);
    kullaniciAdiController = TextEditingController(text: widget.kullaniciAdi);
    emailController = TextEditingController(text: widget.email);
    seciliAvatarKey = widget.avatarKey;
  }

  // Abonelik ve kontrolcüleri temizle
  @override
  void dispose() {
    adSoyadController.dispose();
    kullaniciAdiController.dispose();
    emailController.dispose();
    super.dispose();
  }

  // Arayüzü oluştur
  @override
  Widget build(BuildContext context) {
    final vibe = context.vibe;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return AlertDialog(
      backgroundColor: vibe.dialogBackground,
      title: Text("Profili Düzenle", style: TextStyle(color: onSurface)),
      content: SingleChildScrollView(
        child: Column(
          children: [
            _alan(adSoyadController, "Ad Soyad"),
            _alan(kullaniciAdiController, "Kullanıcı Adı"),
            _alan(emailController, "E-posta",
                keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Hazır avatar galerisi",
                style: TextStyle(
                  color: onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: vibeAvatarOptions.map((option) {
                final secili = seciliAvatarKey == option.key;
                return InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () {
                    setState(() {
                      seciliAvatarKey = option.key;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: secili
                            ? Theme.of(context).colorScheme.primary
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: vibeAvatar(
                      radius: 20,
                      avatarKey: option.key,
                      emojiSize: 18,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Vazgeç"),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(
              context,
              _ProfilDuzenleSonucu(
                adSoyad: adSoyadController.text.trim(),
                kullaniciAdi: kullaniciAdiController.text.trim(),
                email: emailController.text.trim(),
                avatarKey: seciliAvatarKey,
              ),
            );
          },
          child: const Text("Kaydet"),
        ),
      ],
    );
  }

  // Profil düzenleme metin alanı
  Widget _alan(
    TextEditingController controller,
    String hint, {
    TextInputType? keyboardType,
  }) {
    final vibe = context.vibe;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: TextStyle(color: onSurface),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: vibe.faintText),
        ),
      ),
    );
  }
}

// Moderatör rapor inceleme sayfası
class _ModerasyonPanelPage extends StatefulWidget {
  const _ModerasyonPanelPage();

  @override
  State<_ModerasyonPanelPage> createState() => _ModerasyonPanelPageState();
}

// Moderasyon paneli durumu
class _ModerasyonPanelPageState extends State<_ModerasyonPanelPage> {
  String _turFiltresi = 'tumu';
  String _durumFiltresi = 'tumu';

  static const _turEtiketleri = <String, String>{
    'post': 'Gönderi',
    'comment': 'Yorum',
    'user': 'Hesap',
  };

  static const _durumEtiketleri = <String, String>{
    'pending': 'Bekliyor',
    'reviewed': 'İncelendi',
    'action_taken': 'İşlem uygulandı',
    'rejected': 'Reddedildi',
  };

  String _turMetni(String tur) => _turEtiketleri[tur] ?? tur;

  String _durumMetni(String durum) => _durumEtiketleri[durum] ?? durum;

  Color _durumRengi(String durum) {
    switch (durum) {
      case 'pending':
        return Colors.orangeAccent;
      case 'action_taken':
        return Colors.greenAccent;
      case 'rejected':
        return Colors.redAccent;
      default:
        return Colors.blueAccent;
    }
  }

  bool _filtreyeUyuyor(Map<String, dynamic> data) {
    final tur = (data['type'] ?? '').toString();
    final durum = (data['status'] ?? 'pending').toString();
    if (_turFiltresi != 'tumu' && tur != _turFiltresi) return false;
    if (_durumFiltresi != 'tumu' && durum != _durumFiltresi) return false;
    return true;
  }

  Widget _filtreChip({
    required String deger,
    required String etiket,
    required String secili,
    required ValueChanged<String> sec,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(etiket),
        selected: secili == deger,
        onSelected: (_) => sec(deger),
      ),
    );
  }

  // Rapor durumunu güncelle
  Future<void> _raporDurumuGuncelle(
    QueryDocumentSnapshot<Map<String, dynamic>> raporDoc,
    String durum,
  ) async {
    // hata yakalamalı blok
    try {
      await raporDoc.reference.update({
        "status": durum,
        "reviewedAt": FieldValue.serverTimestamp(),
        "reviewedBy": FirebaseAuth.instance.currentUser?.uid ?? "",
      });
      if (!mounted) return;
      vibeSnackbarGoster(
        context,
        "Rapor durumu güncellendi.",
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

  // Rapor için içerik gizle
  Future<void> _islemUygula(
    QueryDocumentSnapshot<Map<String, dynamic>> raporDoc,
  ) async {
    final data = raporDoc.data();
    final type = (data["type"] ?? "").toString();

    // hata yakalamalı blok
    try {
      if (type == "post") {
        final postId = (data["postId"] ?? "").toString();
        if (postId.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection("posts")
              .doc(postId)
              .update({
            "raporNedeniyleGizli": true,
            "raporGuncellenmeTarihi": FieldValue.serverTimestamp(),
          });
        }
      } else if (type == "comment") {
        final postId = (data["postId"] ?? "").toString();
        final commentId = (data["commentId"] ?? "").toString();
        if (postId.isNotEmpty && commentId.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection("posts")
              .doc(postId)
              .collection("comments")
              .doc(commentId)
              .update({
            "raporNedeniyleGizli": true,
            "raporGuncellenmeTarihi": FieldValue.serverTimestamp(),
          });
        }
      } else if (type == "user") {
        final targetUid = (data["targetUid"] ?? "").toString();
        if (targetUid.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection("users")
              .doc(targetUid)
              .update({
            "raporNedeniyleGizli": true,
            "raporGuncellenmeTarihi": FieldValue.serverTimestamp(),
          });
        }
      }

      await _raporDurumuGuncelle(raporDoc, "action_taken");
      // hata yakala
    } catch (e) {
      if (!mounted) return;
      vibeSnackbarGoster(
        context,
        internetAwareErrorMessage(
          error: e,
          fallback: "Aksiyon uygulanamadı.",
        ),
      );
    }
  }

  // Arayüzü oluştur
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vibe = context.vibe;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Moderasyon Paneli"),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Text(
              'Tür',
              style: TextStyle(color: vibe.mutedText, fontSize: 12),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
            child: Row(
              children: [
                _filtreChip(
                  deger: 'tumu',
                  etiket: 'Tümü',
                  secili: _turFiltresi,
                  sec: (v) => setState(() => _turFiltresi = v),
                ),
                _filtreChip(
                  deger: 'post',
                  etiket: 'Gönderi',
                  secili: _turFiltresi,
                  sec: (v) => setState(() => _turFiltresi = v),
                ),
                _filtreChip(
                  deger: 'comment',
                  etiket: 'Yorum',
                  secili: _turFiltresi,
                  sec: (v) => setState(() => _turFiltresi = v),
                ),
                _filtreChip(
                  deger: 'user',
                  etiket: 'Hesap',
                  secili: _turFiltresi,
                  sec: (v) => setState(() => _turFiltresi = v),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
            child: Text(
              'Durum',
              style: TextStyle(color: vibe.mutedText, fontSize: 12),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
            child: Row(
              children: [
                _filtreChip(
                  deger: 'tumu',
                  etiket: 'Tümü',
                  secili: _durumFiltresi,
                  sec: (v) => setState(() => _durumFiltresi = v),
                ),
                _filtreChip(
                  deger: 'pending',
                  etiket: 'Bekleyen',
                  secili: _durumFiltresi,
                  sec: (v) => setState(() => _durumFiltresi = v),
                ),
                _filtreChip(
                  deger: 'reviewed',
                  etiket: 'İncelenen',
                  secili: _durumFiltresi,
                  sec: (v) => setState(() => _durumFiltresi = v),
                ),
                _filtreChip(
                  deger: 'action_taken',
                  etiket: 'İşlem uygulanan',
                  secili: _durumFiltresi,
                  sec: (v) => setState(() => _durumFiltresi = v),
                ),
                _filtreChip(
                  deger: 'rejected',
                  etiket: 'Reddedilen',
                  secili: _durumFiltresi,
                  sec: (v) => setState(() => _durumFiltresi = v),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection("reports")
                  .orderBy("createdAt", descending: true)
                  .limit(200)
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
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        internetAwareErrorMessage(
                          error: snapshot.error!,
                          fallback: "Raporlar yüklenemedi.",
                        ),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: vibe.mutedText),
                      ),
                    ),
                  );
                }

                final docs = (snapshot.data?.docs ?? [])
                    .where((doc) => _filtreyeUyuyor(doc.data()))
                    .toList();

                if (docs.isEmpty) {
                  return Center(
                    child: Text(
                      "Bu filtrede rapor bulunamadı.",
                      style: TextStyle(color: vibe.mutedText),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 20),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data();
                    final type = (data["type"] ?? "").toString();
                    final status = (data["status"] ?? "pending").toString();
                    final reason = (data["reason"] ?? "").toString();
                    final details = (data["details"] ?? "").toString();
                    final targetUid = (data["targetUid"] ?? "").toString();
                    final postId = (data["postId"] ?? "").toString();
                    final commentId = (data["commentId"] ?? "").toString();
                    final reporterUid = (data["reporterUid"] ?? "").toString();

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: vibe.cardDecoration(radius: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: vibe.inputFill,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    _turMetni(type).toUpperCase(),
                                    style: TextStyle(
                                      color: theme.colorScheme.onSurface,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _durumMetni(status),
                                  style: TextStyle(
                                    color: _durumRengi(status),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  tarihSaatYaz(data["createdAt"]),
                                  style: TextStyle(
                                    color: vibe.faintText,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Sebep: $reason",
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (details.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                details,
                                style: TextStyle(color: vibe.mutedText),
                              ),
                            ],
                            const SizedBox(height: 8),
                            Text(
                              "Raporlayan: $reporterUid",
                              style: TextStyle(
                                  color: vibe.faintText, fontSize: 12),
                            ),
                            if (targetUid.isNotEmpty)
                              Text(
                                "Hedef UID: $targetUid",
                                style: TextStyle(
                                    color: vibe.faintText, fontSize: 12),
                              ),
                            if (postId.isNotEmpty)
                              Text(
                                "Post ID: $postId",
                                style: TextStyle(
                                    color: vibe.faintText, fontSize: 12),
                              ),
                            if (commentId.isNotEmpty)
                              Text(
                                "Yorum ID: $commentId",
                                style: TextStyle(
                                    color: vibe.faintText, fontSize: 12),
                              ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (status != "reviewed")
                                  OutlinedButton(
                                    onPressed: () =>
                                        _raporDurumuGuncelle(doc, "reviewed"),
                                    child: const Text("İncelendi"),
                                  ),
                                if (status != "rejected")
                                  OutlinedButton(
                                    onPressed: () =>
                                        _raporDurumuGuncelle(doc, "rejected"),
                                    child: const Text("Reddet"),
                                  ),
                                if (status != "action_taken")
                                  ElevatedButton(
                                    onPressed: () => _islemUygula(doc),
                                    child: const Text("İşlem Uygula"),
                                  ),
                                if (status != "pending")
                                  TextButton(
                                    onPressed: () =>
                                        _raporDurumuGuncelle(doc, "pending"),
                                    child: const Text("Beklemeye al"),
                                  ),
                              ],
                            ),
                          ],
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
    );
  }
}
