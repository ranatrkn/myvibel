// Kendi profil sayfası: bilgi kartı, maskot gelişimi, gönderiler, ayarlar ve moderasyon
import 'package:myvibel/tek_sefer_navigasyon.dart';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myvibel/alinti_gonderi.dart';
import 'package:myvibel/app_check_config.dart';
import 'package:myvibel/app_check_debug.dart';
import 'package:myvibel/app_theme.dart';
import 'package:myvibel/widgets/vibe_yukleniyor.dart';
import 'package:myvibel/error_messages.dart';
import 'package:myvibel/hesap_sil_servis.dart';
import 'package:myvibel/auth_eposta.dart' as auth_eposta;
import 'package:myvibel/sifre_degistir_servis.dart';
import 'package:myvibel/follow_list_page.dart';
import 'package:myvibel/apple_giris_servis.dart';
import 'package:myvibel/google_giris_servis.dart';
import 'package:myvibel/leaderboard_page.dart';
import 'package:myvibel/maestro_semantics.dart';
import 'package:myvibel/sosyal/lider_tac_servis.dart';
import 'package:myvibel/sosyal_oauth.dart';
import 'package:myvibel/sosyal/sosyal_core.dart';
import 'package:myvibel/sosyal/takip_sayac_onbellek.dart';
import 'package:myvibel/sosyal_servis.dart';
import 'package:myvibel/yas_hesap_kontrol.dart';
import 'package:myvibel/ebeveyn_kontrol.dart';
import 'package:myvibel/moderator_konsol_page.dart';
import 'package:myvibel/etiket_navigasyon.dart';
import 'package:myvibel/widgets/alinti_gonderi_onizleme.dart';
import 'package:myvibel/widgets/hashtag_metin.dart';
import 'package:myvibel/maskot_page.dart';
import 'package:myvibel/maskot_bakim_sozleri.dart';
import 'package:myvibel/maskot_servis.dart';
import 'package:myvibel/widgets/mascot_ruh_hali_metni.dart';
import 'package:myvibel/legal_pages.dart';
import 'package:myvibel/widgets/maskot_durum_bari.dart';
import 'package:myvibel/widgets/isim_yan_rozet.dart';
import 'package:myvibel/widgets/maskot_gelisim_cercevesi.dart';
import 'package:myvibel/widgets/maskot_lottie_view.dart';
import 'package:myvibel/rety_renk.dart';
import 'package:myvibel/widgets/post_begeni_yardimci.dart';
import 'package:myvibel/widgets/profil_gonderi_gorunumu.dart';
import 'package:myvibel/widgets/theme_mode_segment.dart';
import 'package:myvibel/widgets/rety_bag_rozeti.dart';
import 'package:myvibel/widgets/vil_harcama_uyarisi.dart';
import 'package:myvibel/widgets/vil_rozeti.dart';
import 'package:myvibel/widgets/vibe_avatar.dart';
import 'package:myvibel/widgets/vibe_ikonlar.dart';
import 'package:myvibel/widgets/web_shell.dart';
import 'package:myvibel/widgets/vibe_gradient_scaffold.dart';
import 'package:myvibel/vibe_snackbar.dart';
import 'package:myvibel/widgets/begenenler_paneli.dart';
import 'package:myvibel/widgets/yorum_paneli.dart';

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
  const ProfilePage({super.key, this.aktif = true});

  final bool aktif;

  @override
  State<ProfilePage> createState() => ProfilePageState();
}

// Profil sayfası durumu ve iş mantığı
class ProfilePageState extends State<ProfilePage> {
  int seciliSekme = 0; // seçili profil sekmesi
  ProfilGonderiGorunumu _gonderiGorunumu = ProfilGonderiGorunumu.liste;
  final Set<String> _silinenPostIdleri =
      {}; // optimistik silinen gönderi id'leri
  QuerySnapshot<Map<String, dynamic>>?
      _sunucuGonderiSnap; // sunucudan gelen gönderi snapshot'ı
  QuerySnapshot<Map<String, dynamic>>?
      _bekleyenOnbellekGonderiSnap; // önbellekten bekleyen gönderi snapshot'ı
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _gonderiAbonelik; // gönderi stream aboneliği
  Timer? _gonderiOnbellekZamanAsimi; // önbellek gecikme zamanlayıcısı
  bool _begeniTemizligiYapildi = false;

  // Widget ilk yüklendiğinde çalışır
  @override
  void initState() {
    super.initState();
    unawaited(LiderTacServis.instance.baslat());
    unawaited(HaftaRozetServis.instance.yenile());
    _gonderiDinlemeyiAyarla();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _gecersizBegeniKayitlariniTemizle();
    });
  }

  @override
  void didUpdateWidget(covariant ProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.aktif != widget.aktif) {
      _gonderiDinlemeyiAyarla();
    }
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

  Query<Map<String, dynamic>>? _kendiGonderiSorgusu() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance
        .collection("posts")
        .where("userId", isEqualTo: uid)
        .orderBy("createdAt", descending: true)
        .limit(40);
  }

  // Kullanıcının gönderilerini dinlemeye başla
  void _gonderiDinlemeyiAyarla() {
    // Sekme kapalıyken dinlemeyi kesme: yeni paylaşım profilde gecikmesin.
    if (_gonderiAbonelik == null) {
      _gonderiDinlemeyiBaslat();
    }
    unawaited(_gonderileriSunucudanYenile());
  }

  Future<void> _gonderileriSunucudanYenile() async {
    final sorgu = _kendiGonderiSorgusu();
    if (sorgu == null) return;
    try {
      final snap = await sorgu.get(const GetOptions(source: Source.server));
      if (!mounted) return;
      _gonderiSnapIsle(snap);
    } catch (_) {
      // Ağ yoksa stream günceller.
    }
  }

  void gonderileriYenile() {
    unawaited(_gonderileriSunucudanYenile());
  }

  // Kullanıcının gönderilerini dinlemeye başla
  void _gonderiDinlemeyiBaslat() {
    final sorgu = _kendiGonderiSorgusu();
    if (sorgu == null) return;

    _gonderiAbonelik?.cancel();
    _gonderiOnbellekZamanAsimi?.cancel();
    _gonderiAbonelik = sorgu
        .snapshots(includeMetadataChanges: true)
        .listen(_gonderiSnapIsle);
  }

  // Gönderi snapshot'ını işle
  void _gonderiSnapIsle(QuerySnapshot<Map<String, dynamic>> snap) {
    if (!mounted) return;

    final yeniIdler = snap.docs.map((d) => d.id).toSet();
    final eskiIdler =
        _sunucuGonderiSnap?.docs.map((d) => d.id).toSet() ?? <String>{};
    final yeniGonderiVar = yeniIdler.difference(eskiIdler).isNotEmpty;

    if (snap.metadata.isFromCache &&
        _sunucuGonderiSnap != null &&
        eskiIdler.difference(yeniIdler).isNotEmpty) {
      return;
    }

    if (!snap.metadata.isFromCache ||
        _sunucuGonderiSnap == null ||
        yeniGonderiVar) {
      _gonderiOnbellekZamanAsimi?.cancel();
      _gonderiOnbellekZamanAsimi = null;
      _bekleyenOnbellekGonderiSnap = null;
      _silinenPostIdleri.removeWhere((id) => !yeniIdler.contains(id));
      setState(() => _sunucuGonderiSnap = snap);
      return;
    }

    _bekleyenOnbellekGonderiSnap = snap;
    _gonderiOnbellekZamanAsimi ??= Timer(
      const Duration(milliseconds: 1500),
      () {
        if (!mounted) return;
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
        child: VibeYukleniyor(renk: Colors.redAccent),
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

  // Beğendiklerim: likedPosts yalnız postId/sahip tutar; içerik gönderiden okunur.
  final Map<String, Map<String, dynamic>> _begenilenPostOnbellek = {};
  final Set<String> _begenilenPostIstendi = {};

  void _begenilenPostlariGetir(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> likedDocs,
  ) {
    final eksik = likedDocs
        .map((d) => d.id)
        .where((id) => !_begenilenPostIstendi.contains(id))
        .toList();
    if (eksik.isEmpty) return;
    _begenilenPostIstendi.addAll(eksik);
    unawaited(Future.wait(eksik.map((id) async {
      try {
        final snap = await SosyalCore.gonderiRef(id).get();
        final data = snap.data();
        if (data != null) _begenilenPostOnbellek[id] = data;
      } catch (_) {}
    })).then((_) {
      if (mounted) setState(() {});
    }));
  }

  Map<String, dynamic> _begenilenPostVerisi(
    QueryDocumentSnapshot<Map<String, dynamic>> liked,
  ) {
    final likedData = liked.data();
    final post = _begenilenPostOnbellek[liked.id] ?? const <String, dynamic>{};
    return {
      'userId': post['userId'] ?? likedData['postOwnerId'] ?? '',
      'kullaniciAdi':
          post['kullaniciAdi'] ?? likedData['kullaniciAdi'] ?? 'Vibe Kullanıcısı',
      'metin': post['metin'] ?? likedData['metin'] ?? '',
      'photoUrl': post['photoUrl'] ?? likedData['photoUrl'] ?? '',
      'avatarKey': post['avatarKey'] ?? likedData['avatarKey'] ?? '',
      'mentionUidleri': post['mentionUidleri'],
      'alintiSnapshot': post['alintiSnapshot'],
      'alintiPostId': post['alintiPostId'],
      'ownerHesapGizli': likedData['ownerHesapGizli'] == true,
      'raporNedeniyleGizli': post['raporNedeniyleGizli'] == true ||
          likedData['raporNedeniyleGizli'] == true,
      'begeniSayisi':
          _intDeger(post['begeniSayisi'] ?? likedData['begeniSayisi'], 0),
      'yorumSayisi':
          _intDeger(post['yorumSayisi'] ?? likedData['yorumSayisi'], 0),
      'createdAt': post['createdAt'] ?? likedData['createdAt'],
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
      mesajGoster("Vibel ismi güncellendi.", tip: VibeMesajTipi.basari);
      // hata yakala
    } catch (e) {
      mesajGoster(
        internetAwareErrorMessage(
          error: e,
          fallback: "Vibel ismi güncellenemedi.",
        ),
      );
    }
  }

  Future<String?> _mevcutSifreSor() async {
    final kontrol = TextEditingController();
    final vibe = context.vibe;
    final sonuc = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: vibe.dialogBackground,
        title: Text(
          'E-postayı değiştir',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        content: TextField(
          controller: kontrol,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Mevcut şifre',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, kontrol.text),
            child: const Text('Gönder'),
          ),
        ],
      ),
    );
    kontrol.dispose();
    return sonuc;
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

      if (sonuc.email.trim().toLowerCase() !=
          (user.email ?? email).trim().toLowerCase()) {
        if (!mounted) return;
        final sifre = await _mevcutSifreSor();
        if (sifre == null || sifre.isEmpty) return;
        try {
          await auth_eposta.epostaDegisikligiBaslat(
            user: user,
            yeniEmail: sonuc.email,
            mevcutSifre: sifre,
          );
          emailGuncellendi = false;
          mesajGoster(
            "Yeni adrese doğrulama maili gitti. Linke basınca giriş adresin değişir. Gönderen: destek@myvibel.com",
            tip: VibeMesajTipi.basari,
          );
        } on FirebaseAuthException catch (e) {
          mesajGoster(auth_eposta.epostaDegistirmeHataMesaji(e));
          return;
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

      // Public profilde e-posta tutulmaz (rules reddeder). Avatar/ad güncellemesi
      // email alanına takılmasın diye asla users/{uid}.email yazma.
      await userRef.update({
        "adSoyad": sonuc.adSoyad,
        "kullaniciAdi": sonuc.kullaniciAdi,
        "kullaniciAdiKucuk": yeniKullaniciAdiKucuk,
        "avatarKey": sonuc.avatarKey,
        "photoUrl": "",
        if (mevcutData.containsKey('email')) "email": FieldValue.delete(),
        if (mevcutData.containsKey('dogumTarihi'))
          "dogumTarihi": FieldValue.delete(),
      });

      if (emailGuncellendi || sonuc.email.trim().isNotEmpty) {
        final emailNorm = (emailGuncellendi
                ? sonuc.email
                : (user.email ?? sonuc.email))
            .trim()
            .toLowerCase();
        if (emailNorm.contains('@')) {
          try {
            await userRef.collection('private').doc('account').set({
              'email': emailNorm,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
            await userRef.collection('private').doc('loginEmail').set({
              'email': emailNorm,
            });
          } catch (e) {
            debugPrint('profil private email: $e');
          }
        }
      }

      try {
        final avatarAlanlari = {
          "kullaniciAdi": sonuc.kullaniciAdi,
          "avatarKey": sonuc.avatarKey,
          "photoUrl": "",
        };

        final posts = await firestore
            .collection("posts")
            .where("userId", isEqualTo: user.uid)
            .get();

        if (posts.docs.isNotEmpty) {
          var batch = firestore.batch();
          var sayac = 0;

          for (final doc in posts.docs) {
            batch.update(doc.reference, avatarAlanlari);
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

        // Kendi yorumlarındaki avatar/ad senkronu
        try {
          final yorumlar = await firestore
              .collectionGroup('comments')
              .where('userId', isEqualTo: user.uid)
              .limit(400)
              .get();
          if (yorumlar.docs.isNotEmpty) {
            var batch = firestore.batch();
            var sayac = 0;
            for (final doc in yorumlar.docs) {
              batch.update(doc.reference, avatarAlanlari);
              sayac++;
              if (sayac >= 400) {
                await batch.commit();
                batch = firestore.batch();
                sayac = 0;
              }
            }
            if (sayac > 0) await batch.commit();
          }
        } catch (e) {
          debugPrint('profil yorum avatar senkron: $e');
        }

        // Beğenilenler anlık görüntüsü (gönderi sahibi alanları)
        try {
          final liked = await firestore
              .collectionGroup('likedPosts')
              .where('postOwnerId', isEqualTo: user.uid)
              .limit(400)
              .get();
          if (liked.docs.isNotEmpty) {
            var batch = firestore.batch();
            var sayac = 0;
            for (final doc in liked.docs) {
              batch.update(doc.reference, avatarAlanlari);
              sayac++;
              if (sayac >= 400) {
                await batch.commit();
                batch = firestore.batch();
                sayac = 0;
              }
            }
            if (sayac > 0) await batch.commit();
          }
        } catch (e) {
          debugPrint('profil likedPosts avatar senkron: $e');
        }
      } catch (e) {
        debugPrint('profil gonderi avatar senkron: $e');
        mesajGoster(
          "Profil güncellendi; bazı eski gönderilerde fotoğraf biraz gecikebilir.",
          tip: VibeMesajTipi.uyari,
        );
      }

      if (emailGuncellendi) {
        mesajGoster("Profil güncellendi.", tip: VibeMesajTipi.basari);
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

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    if (!mounted) return;
    final mascot = MascotServis.tryParse(userDoc.data()?['robot']);
    final vilGerekir =
        mascot != null && MascotServis.gonderiSilVilGerekir(mascot.seviye);
    if (vilGerekir && !MascotServis.gonderiSilVilYeterli(mascot)) {
      mesajGoster(
        'Gönderi silmek için ${MascotServis.gonderiSilVilMaliyeti} vil gerekli.',
      );
      return;
    }

    final onay = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.vibe.dialogBackground,
        title: Text(
          "Gönderi silinsin mi?",
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        content: Text(
          'Bu işlem geri alınamaz.',
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
    if (!mounted) return;

    if (vilGerekir) {
      final vilOnay = await VilHarcamaUyarisi.onayla(
        context: context,
        islem: VilHarcamaUyarisi.gonderiSil,
        maliyet: MascotServis.gonderiSilVilMaliyeti,
        vilHarcanacak: true,
      );
      if (!vilOnay || !mounted) return;
    }

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
    try {
      await GoogleGirisServis.oturumuKapat();
    } catch (e) {
      debugPrint('cikisYap: $e');
      try {
        await FirebaseAuth.instance.signOut();
      } catch (_) {}
    }
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
                                    userId: hedefUid,
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
    if (YasHesapKontrol.maybeOf(context)?.cocukHesabi == true) return;
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
    int? seviye,
    bool isModerator, {
    RetyRenk renk = RetyRenk.varsayilan,
  }) {
    bool hesapGizli = baslangicHesapGizli;

    // Arka plan builder içinde: sayfadaki tema anahtarı açıkken de renk güncellensin.
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => Material(
        color: sheetContext.vibe.sheetBackground,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Builder(builder: (sheetContext) {
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
                      maestroButton(
                        label: MaestroSemantics.arkadaslaraOner,
                        onTap: () {
                          Navigator.pop(sheetContext);
                          unawaited(arkadaslaraOner(context));
                        },
                        child: ListTile(
                          leading: Icon(Icons.person_add_alt_1_outlined,
                              color: sheetVibe.mutedText),
                          title: Text(
                            "Arkadaşlarına öner",
                            style: TextStyle(color: onSurface),
                          ),
                          subtitle: Text(
                            "WhatsApp, SMS veya başka bir yerden davet et",
                            style: TextStyle(
                                color: sheetVibe.mutedText, fontSize: 12),
                          ),
                          onTap: () {
                            Navigator.pop(sheetContext);
                            unawaited(arkadaslaraOner(context));
                          },
                        ),
                      ),
                      if (YasHesapKontrol.maybeOf(context)?.cocukHesabi !=
                          true)
                        SwitchListTile(
                          secondary: Icon(Icons.lock_outline,
                              color: sheetVibe.mutedText),
                          title: Text(
                            "Gizli Hesap",
                            style: TextStyle(color: onSurface),
                          ),
                          subtitle: Text(
                            "Profilin ve gönderilerin yalnızca onaylı takipçilerine görünür",
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
                      if (YasHesapKontrol.maybeOf(context)?.cocukHesabi ==
                          true)
                        ListTile(
                          leading: Icon(Icons.family_restroom,
                              color: sheetVibe.mutedText),
                          title: Text(
                            "Ebeveyn kontrolleri",
                            style: TextStyle(color: onSurface),
                          ),
                          subtitle: Text(
                            "Günlük süre ve PIN",
                            style: TextStyle(
                                color: sheetVibe.mutedText, fontSize: 12),
                          ),
                          onTap: () {
                            Navigator.pop(sheetContext);
                            unawaited(ebeveynAyarPaneliniAc(context));
                          },
                        ),
                      if (seviye != null && seviye >= 5)
                        Semantics(
                          label: "Vibel İsmini Değiştir",
                          button: true,
                          child: ListTile(
                            leading: MascotLottieView(
                              seviye: seviye,
                              renk: renk,
                              width: 24,
                              height: 24,
                              fit: BoxFit.contain,
                              tamEkranAc: false,
                            ),
                            title: Text(
                              "Vibel İsmini Değiştir",
                              style: TextStyle(color: onSurface),
                            ),
                            onTap: () {
                              Navigator.pop(sheetContext);
                              mascotIsminiDegistir(mascotIsim);
                            },
                          ),
                        ),
                      if (isModerator) ...[
                        ListTile(
                          leading: Icon(Icons.admin_panel_settings,
                              color: sheetVibe.mutedText),
                          title: Text(
                            "Moderatör Konsolu",
                            style: TextStyle(color: onSurface),
                          ),
                          subtitle: Text(
                            "Şikayetler, destek, hesap silme",
                            style: TextStyle(
                              color: sheetVibe.mutedText,
                              fontSize: 12,
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(sheetContext);
                            tekSeferPush(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ModeratorKonsolPage(),
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
                        leading: Icon(Icons.description_outlined,
                            color: sheetVibe.mutedText),
                        title: Text(
                          "Kullanım Koşulları",
                          style: TextStyle(color: onSurface),
                        ),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          tekSeferPush(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const TermsOfUsePage(),
                            ),
                          );
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
                          tekSeferPush(
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
                          yasalLinkiAc(context, VibeLegal.kvkkPolicyUrl);
                        },
                      ),
                      ListTile(
                        leading: Icon(Icons.child_care_outlined,
                            color: sheetVibe.mutedText),
                        title: Text(
                          "Çocuk Güvenliği",
                          style: TextStyle(color: onSurface),
                        ),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          tekSeferPush(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const CocukGuvenligiPage(),
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
                          tekSeferPush(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const HelpFaqPage(),
                            ),
                          );
                        },
                      ),
                      if (isModerator)
                        ListTile(
                        leading: Icon(Icons.new_releases_outlined,
                            color: sheetVibe.mutedText),
                        title: Text(
                          "Sürüm Notları",
                          style: TextStyle(color: onSurface),
                        ),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          tekSeferPush(
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
                          tekSeferPush(
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
                      maestroButton(
                        label: MaestroSemantics.cikisYap,
                        onTap: () {
                          Navigator.pop(sheetContext);
                          cikisYap();
                        },
                        child: ListTile(
                          leading: const Icon(Icons.logout,
                              color: Colors.redAccent),
                          title: const Text(
                            "Çıkış Yap",
                            style: TextStyle(color: Colors.redAccent),
                          ),
                          onTap: () {
                            Navigator.pop(sheetContext);
                            cikisYap();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
        }),
      ),
    );
  }

  // Arayüzü oluştur
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return _profilSayfaKabugu(
        context,
        const Center(
          child: Text(
            "Kullanıcı bulunamadı.",
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    return _profilSayfaKabugu(
      context,
      SafeArea(
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection("users")
            .doc(user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          final data = snapshot.data?.data();

          final adSoyad = data?["adSoyad"] ?? "Vibe Kullanıcısı";
          final kullaniciAdi = data?["kullaniciAdi"] ?? "kullanici";
          final email = user.email ?? ""; // Auth; public profilde e-posta tutulmaz
          final avatarKey = data?["avatarKey"]?.toString() ?? "";
          final firestorePhoto = (data?["photoUrl"] ?? "").toString();
          final photoUrl = vibeAvatarByKey(avatarKey) != null
              ? ""
              : (firestorePhoto.isNotEmpty
                  ? firestorePhoto
                  : (user.photoURL ?? ""));

          final mascotData = data?["robot"];
          final mascotDurum = MascotServis.tryParse(mascotData);
          final mascotIsim = mascotDurum?.isim ?? MascotServis.varsayilanIsim;
          final seviye = mascotDurum?.seviye;
          final hesapGizli = data?["hesapGizli"] == true;
          final isModerator = data?["isModerator"] == true;
          final masaustu = webMasaustuMu(context);
          final vibe = context.vibe;
          final onSurface = Theme.of(context).colorScheme.onSurface;

          final aracCubugu = Row(
            children: [
              Text(
                "Profil",
                style: TextStyle(
                  color: onSurface,
                  fontSize: masaustu ? 28 : 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              maestroButton(
                label: MaestroSemantics.liderlikTablosu,
                onTap: () {
                  tekSeferPush(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LeaderboardPage(),
                    ),
                  );
                },
                child: IconButton(
                  onPressed: () {
                    tekSeferPush(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LeaderboardPage(),
                      ),
                    );
                  },
                  icon: Icon(Icons.emoji_events_outlined,
                      color: vibe.mutedText),
                  tooltip: "Liderlik tablosu",
                ),
              ),
              Semantics(
                label: MaestroSemantics.ayarlar,
                button: true,
                onTap: () => ayarlarPaneliniAc(
                  mascotIsim,
                  hesapGizli,
                  seviye,
                  isModerator,
                  renk: mascotDurum?.renk ?? RetyRenk.varsayilan,
                ),
                child: ExcludeSemantics(
                  child: IconButton(
                    onPressed: () => ayarlarPaneliniAc(
                      mascotIsim,
                      hesapGizli,
                      seviye,
                      isModerator,
                      renk: mascotDurum?.renk ?? RetyRenk.varsayilan,
                    ),
                    icon: Icon(Icons.settings, color: vibe.mutedText),
                  ),
                ),
              ),
              maestroButton(
                label: MaestroSemantics.cikisYap,
                onTap: cikisYap,
                child: IconButton(
                  onPressed: cikisYap,
                  tooltip: MaestroSemantics.cikisYap,
                  icon: Icon(Icons.logout, color: vibe.mutedText),
                ),
              ),
            ],
          );

          final profilKarti = _profilKarti(
            sayacVerisi: data,
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
          );

          final mascotBolumu = mascotDurum != null
              ? _mascotKarti(mascotDurum)
              : _mascotKartiYukleniyor();

          if (masaustu) {
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(28, 28, 28, 36),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          vibe.gradientStart.withOpacity(0.85),
                          vibe.gradientEnd.withOpacity(0.55),
                          vibe.gradientEnd.withOpacity(0),
                        ],
                      ),
                    ),
                    child: aracCubugu,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: Column(
                      children: [
                        Transform.translate(
                          offset: const Offset(0, -18),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 11, child: profilKarti),
                              const SizedBox(width: 18),
                              Expanded(flex: 9, child: mascotBolumu),
                            ],
                          ),
                        ),
                        _sekmeSecici(user.uid),
                        const SizedBox(height: 12),
                        seciliSekme == 0
                            ? _kendiGonderilerBolumu(user.uid)
                            : _begenilenGonderilerBolumu(user.uid),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Column(
              children: [
                const SizedBox(height: 38),
                aracCubugu,
                const SizedBox(height: 12),
                profilKarti,
                const SizedBox(height: 18),
                mascotBolumu,
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
    ),
    );
  }

  // InkWell web'de iç içe Navigator overlay'inde dış Scaffold Material'ını
  // kaçırabiliyor; şeffaf Material her zaman verilir. Rota olarak açılınca
  // ayrıca kendi iskeleti de eklenir.
  Widget _profilSayfaKabugu(BuildContext context, Widget icerik) {
    final govde = Material(
      type: MaterialType.transparency,
      child: icerik,
    );
    if (Scaffold.maybeOf(context) != null) return govde;
    return VibeGradientScaffold(body: govde);
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
    Map<String, dynamic>? sayacVerisi,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: context.vibe.kahramanKart(),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: onDuzenle,
                child: _avatar(
                  photoUrl,
                  userId: userId,
                  avatarKey: avatarKey,
                  fallbackText: kullaniciAdi,
                  radius: 34,
                  iconSize: 34,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            "@$kullaniciAdi",
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IsimYanRozet(uid: userId, boy: 26),
                      ],
                    ),
                    RozetSayacSatiri(
                      data: sayacVerisi,
                      seviye: sayacVerisi == null
                          ? 1
                          : (MascotServis.tryParse(sayacVerisi['robot'])
                                  ?.seviye ??
                              1),
                    ),
                    Text(adSoyad,
                        style: TextStyle(color: context.vibe.mutedText)),
                    if (webMasaustuMu(context))
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          email,
                          maxLines: 1,
                          style: TextStyle(
                              color: context.vibe.faintText, fontSize: 12),
                        ),
                      )
                    else
                      Text(
                        email,
                        style: TextStyle(
                            color: context.vibe.faintText, fontSize: 12),
                      ),
                  ],
                ),
              ),
              Semantics(
                label: MaestroSemantics.profilDuzenle,
                button: true,
                child: IconButton(
                  onPressed: onDuzenle,
                  icon:
                      Icon(Icons.edit, color: context.vibe.mutedText, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FutureBuilder<int>(
                  future: TakipSayacOnbellek.tazele(userId, takipci: true),
                  builder: (context, countSnap) {
                    final sayi = countSnap.data ??
                        TakipSayacOnbellek.oku(userId, takipci: true);
                    return _miniSayacKutusu(
                      "Takipçi",
                      sayi,
                      erisimEtiketi: MaestroSemantics.takipciSayaci,
                      onTap: () {
                        tekSeferPush(
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
                child: FutureBuilder<int>(
                  future: TakipSayacOnbellek.tazele(userId, takipci: false),
                  builder: (context, countSnap) {
                    final sayi = countSnap.data ??
                        TakipSayacOnbellek.oku(userId, takipci: false);
                    return _miniSayacKutusu(
                      "Takip Edilen",
                      sayi,
                      erisimEtiketi: MaestroSemantics.takipEdilenSayaci,
                      onTap: () {
                        tekSeferPush(
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
          const SizedBox(height: 12),
          _arkadaslikBaglariButonu(),
        ],
      ),
    );
  }

  void _arkadaslikBaglariniAc() {
    tekSeferPush(
      context,
      MaterialPageRoute(
        builder: (_) => RetyBaglarPage(
          onKullaniciAc: (uid) {
            profiliAc(context, uid);
          },
        ),
      ),
    );
  }

  Widget _arkadaslikBaglariButonu() {
    return maestroButton(
      label: MaestroSemantics.arkadaslikBaglari,
      onTap: _arkadaslikBaglariniAc,
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _arkadaslikBaglariniAc,
          icon: Image.asset(
            RetyBagRozeti.assetYolu,
            width: 26,
            height: 26,
            fit: BoxFit.contain,
          ),
          label: const Text(
            'Arkadaşlık bağları',
            maxLines: 2,
            textAlign: TextAlign.center,
          ),
          style: _butonStili(),
        ),
      ),
    );
  }

  // Mini sayaç kutusu
  // Profil açılışında sayaçlar «0» diye yanıp sönmesin: son bilinen değer.
  Widget _miniSayacKutusu(
    String baslik,
    int? sayi, {
    VoidCallback? onTap,
    String? erisimEtiketi,
  }) {
    final vibe = context.vibe;
    final kutu = Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: vibe.isDark ? Colors.white.withOpacity(0.06) : vibe.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: vibe.isDark ? Colors.white10 : vibe.cardBorder,
        ),
      ),
      child: Column(
        children: [
          Text(
            sayi == null ? "–" : "$sayi",
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 16,
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
    final tiklanabilir = Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: kutu,
      ),
    );
    if (erisimEtiketi == null) return tiklanabilir;
    return Semantics(
      label: erisimEtiketi,
      button: true,
      onTap: onTap,
      child: tiklanabilir,
    );
  }

  Widget _mascotKartiYukleniyor() {
    return Container(
      width: double.infinity,
      height: 160,
      padding: const EdgeInsets.all(18),
      decoration: _kartDekorasyonu(),
      alignment: Alignment.center,
      child: const VibeYukleniyor(renk: VibeAppTheme.accent),
    );
  }

  // Maskot durum kartı
  Widget _mascotKarti(MascotDurum mascot) {
    final odaAcik = MascotServis.odaAcik(mascot.seviye);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
      onTap: odaAcik
          ? () {
              tekSeferPush(
                context,
                MaterialPageRoute(builder: (_) => const MascotPage()),
              );
            }
          : null,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: context.vibe.kahramanKart(),
        child: Column(
          children: [
            Row(
              children: [
                MascotGelisimCercevesi(
                  progress: mascot.gelisimOrani,
                  size: 100,
                  strokeWidth: 3.5,
                  innerPadding: 3.5,
                  borderRadius: 22,
                  child: MascotLottieView(
                    seviye: mascot.seviye,
                    gorselDurum: mascot.gorselDurum,
                    renk: mascot.renk,
                    width: 86,
                    height: 86,
                    fit: BoxFit.contain,
                    tamEkranAc: false,
                    renkSecilebilir:
                        mascot.seviye >= MascotServis.odaAcilisSeviyesi,
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
                      mascot.uyuyor
                          ? Text(
                              MascotServis.erkenUyandirabilir(mascot)
                                  ? '${mascot.isim} uyuyor. Odasına girip uyandırabilirsin.'
                                  : MaskotBakimSozleri.donen(
                                      MaskotBakimSozleri.uyuyorKutuCumleleri(
                                        mascot.isim,
                                      ),
                                    ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.amberAccent,
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                            )
                          : MascotRuhHaliMetni(
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
                if (odaAcik)
                  Icon(Icons.chevron_right, color: context.vibe.mutedText),
              ],
            ),
            const SizedBox(height: 14),
            if (odaAcik) ...[
              if (MascotServis.vilCuzdaniAcik(mascot.seviye))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Semantics(
                        label: MaestroSemantics.vilBakiyesi(mascot.vil),
                        child: VilRozeti(miktar: mascot.vil),
                      ),
                    ],
                  ),
                ),
              if (MascotServis.toklukAktif(mascot.seviye))
                MascotDurumBari(
                  etiket: 'Tokluk',
                  deger: mascot.tokluk,
                  renk: Colors.orangeAccent,
                  compact: true,
                  sayiGoster: false,
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
                  deger: mascot.mutluluk,
                  renk: Colors.redAccent,
                  compact: true,
                ),
            ],
            const SizedBox(height: 14),
            if (odaAcik)
              maestroButton(
                label: MaestroSemantics.maskotOdasi,
                onTap: () {
                  tekSeferPush(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MascotPage(),
                    ),
                  );
                },
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      tekSeferPush(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MascotPage(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.auto_awesome, size: 18),
                    label: Text('${mascot.isim} odası'),
                    style: _butonStili(),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
    );
  }

  // Gönderilerim / Beğendiklerim sekmeleri
  Widget _sekmeSecici(String userId) {
    final gonderiSayisi = _gorunenProfilGonderileri()
        .where((doc) => doc.data()["raporNedeniyleGizli"] != true)
        .length;
    final vibe = context.vibe;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: vibe.isDark ? Colors.white.withOpacity(0.07) : vibe.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: vibe.isDark ? Colors.white12 : vibe.cardBorder,
        ),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _gonderiBolumBasligi(),
                const SizedBox(height: 12),
                _gonderiGorunumu == ProfilGonderiGorunumu.liste
                    ? Column(
                        children: gorunenDocs.map((doc) {
                          final post = doc.data();
                          return _ProfilPostCard(
                            key: ValueKey(doc.id),
                            postId: doc.id,
                            postOwnerId: userId,
                            userId: userId,
                            kullaniciAdi:
                                post["kullaniciAdi"] ?? "Vibe Kullanıcısı",
                            metin: post["metin"] ?? "",
                            mentionUidleri:
                                SosyalServis.bahsetmeUidHaritasiParse(
                              post["mentionUidleri"],
                            ),
                            photoUrl: post["photoUrl"] ?? "",
                            avatarKey: post["avatarKey"] ?? "",
                            baslangicBegeniSayisi:
                                _intDeger(post["begeniSayisi"], 0),
                            baslangicYorumSayisi:
                                _intDeger(post["yorumSayisi"], 0),
                            silmeButonuGoster: true,
                            onSil: () => gonderiSil(doc.id),
                            createdAt: post["createdAt"],
                            alintiSnapshot: AlintiGonderiSnapshot.haritadan(
                              post["alintiSnapshot"],
                              postId: post["alintiPostId"]?.toString(),
                              icAlintiDahilEt: false,
                            ),
                          );
                        }).toList(),
                      )
                    : _profilIzgarasi(
                        docs: gorunenDocs,
                        currentUserId: userId,
                        postOwnerId: userId,
                      ),
              ],
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
          if (!_begeniTemizligiYapildi) {
            _begeniTemizligiYapildi = true;
            unawaited(SosyalServis.gecersizBegeniKayitlariniTemizle(userId));
          }

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

          if (likedSnap.connectionState == ConnectionState.waiting &&
              !likedSnap.hasData) {
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

          _begenilenPostlariGetir(likedDocs);
          final gorunenLikedDocs = likedDocs
              .where((liked) =>
                  _begenilenPostVerisi(liked)["raporNedeniyleGizli"] != true)
              .toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _gonderiBolumBasligi(),
              const SizedBox(height: 12),
              _gonderiGorunumu == ProfilGonderiGorunumu.liste
                  ? Column(
                      children: gorunenLikedDocs.map((liked) {
                        final post = _begenilenPostVerisi(liked);
                        return _ProfilPostCard(
                          key: ValueKey(liked.id),
                          postId: liked.id,
                          postOwnerId: post["userId"] ?? "",
                          userId: userId,
                          kullaniciAdi:
                              post["kullaniciAdi"] ?? "Vibe Kullanıcısı",
                          metin: post["metin"] ?? "",
                          mentionUidleri:
                              SosyalServis.bahsetmeUidHaritasiParse(
                            post["mentionUidleri"],
                          ),
                          alintiSnapshot: AlintiGonderiSnapshot.haritadan(
                            post["alintiSnapshot"],
                            postId: post["alintiPostId"]?.toString(),
                            icAlintiDahilEt: false,
                          ),
                          photoUrl: post["photoUrl"] ?? "",
                          avatarKey: post["avatarKey"] ?? "",
                          baslangicBegeniSayisi:
                              _intDeger(post["begeniSayisi"], 0),
                          baslangicYorumSayisi:
                              _intDeger(post["yorumSayisi"], 0),
                          baslangicBegenildi: true,
                          silmeButonuGoster: false,
                          erisilemezseGizle: true,
                          createdAt: post["createdAt"],
                        );
                      }).toList(),
                    )
                  : _profilIzgarasi(
                      docs: gorunenLikedDocs,
                      currentUserId: userId,
                      postOwnerId: null,
                      begeniBilgisiDokumandan: true,
                    ),
            ],
          );
        },
      ),
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
    required String? postOwnerId,
    bool begeniBilgisiDokumandan = false,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final sutunSayisi =
            (webMasaustuMu(context) || constraints.maxWidth >= 760) ? 3 : 2;
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
            final post = begeniBilgisiDokumandan
                ? _begenilenPostVerisi(doc)
                : doc.data();
            final silinebilir =
                !begeniBilgisiDokumandan && postOwnerId == currentUserId;
            return ProfilGonderiIzgaraKarti(
              key: ValueKey('grid_${doc.id}'),
              postId: doc.id,
              currentUserId: currentUserId,
              kullaniciAdi:
                  (post["kullaniciAdi"] ?? "Vibe Kullanıcısı").toString(),
              createdAt: post["createdAt"],
              metin: (post["metin"] ?? "").toString(),
              begeniSayisi: _intDeger(post["begeniSayisi"], 0),
              yorumSayisi: _intDeger(post["yorumSayisi"], 0),
              alintiSnapshot: AlintiGonderiSnapshot.haritadan(
                post["alintiSnapshot"],
                postId: post["alintiPostId"]?.toString(),
                icAlintiDahilEt: false,
              ),
              onSil: silinebilir ? () => gonderiSil(doc.id) : null,
            );
          },
        );
      },
    );
  }

  // İçerik sarmalayan kart
  Widget _bolumKarti({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: context.vibe.satirKart(),
      child: child,
    );
  }

  // Profil avatar widget'ı
  Widget _avatar(
    String photoUrl, {
    required String userId,
    required String avatarKey,
    required String fallbackText,
    required double radius,
    required double iconSize,
  }) {
    return vibeAvatar(
      radius: radius,
      userId: userId,
      liderTaciGoster: true,
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
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
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
  final bool erisilemezseGizle;
  final VoidCallback? onSil; // silme geri çağrısı
  final dynamic createdAt; // oluşturulma zamanı
  final AlintiGonderiSnapshot? alintiSnapshot;

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
    this.erisilemezseGizle = false,
    this.onSil,
    required this.createdAt,
    this.alintiSnapshot,
  });

  @override
  State<_ProfilPostCard> createState() => _ProfilPostCardState();
}

// Gönderi kartı beğeni/yorum durumu
class _ProfilPostCardState extends State<_ProfilPostCard> {
  late int yorumSayisi; // yorum sayısı
  late PostBegeniDurumuYonetici _begeni;
  bool _erisilemez = false;
  // Beğendiklerim kaydı yalnız postId/sahip tutar; metin ve sahip bilgisi gönderiden gelir.
  Map<String, dynamic>? _gonderi;

  String get _kullaniciAdi {
    final w = widget.kullaniciAdi;
    if (w.isNotEmpty && w != 'Vibe Kullanıcısı') return w;
    final g = _gonderi?['kullaniciAdi']?.toString() ?? '';
    return g.isNotEmpty ? g : w;
  }

  String get _metin => widget.metin.isNotEmpty
      ? widget.metin
      : (_gonderi?['metin']?.toString() ?? '');

  String get _photoUrl => widget.photoUrl.isNotEmpty
      ? widget.photoUrl
      : (_gonderi?['photoUrl']?.toString() ?? '');

  String get _avatarKey => widget.avatarKey.isNotEmpty
      ? widget.avatarKey
      : (_gonderi?['avatarKey']?.toString() ?? '');

  Map<String, String> get _mentionUidleri => widget.mentionUidleri.isNotEmpty
      ? widget.mentionUidleri
      : SosyalServis.bahsetmeUidHaritasiParse(_gonderi?['mentionUidleri']);

  dynamic get _createdAt => _gonderi?['createdAt'] ?? widget.createdAt;

  AlintiGonderiSnapshot? get _alintiSnapshot {
    if (widget.alintiSnapshot != null) return widget.alintiSnapshot;
    final g = _gonderi;
    if (g == null) return null;
    return AlintiGonderiSnapshot.haritadan(
      g['alintiSnapshot'],
      postId: g['alintiPostId']?.toString(),
      icAlintiDahilEt: false,
    );
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

  // Widget ilk yüklendiğinde çalışır
  @override
  void initState() {
    super.initState();
    yorumSayisi = widget.baslangicYorumSayisi;
    _begeniYoneticiOlustur();
    _eksikSayaclariDoldur();
  }

  Future<void> _eksikSayaclariDoldur() async {
    final ozetEksik = widget.metin.isEmpty && widget.alintiSnapshot == null;
    if (!ozetEksik &&
        widget.baslangicBegeniSayisi > 0 &&
        widget.baslangicYorumSayisi > 0) {
      return;
    }
    try {
      final snap = await SosyalCore.gonderiRef(widget.postId)
          .get();
      if (!mounted) return;
      if (!snap.exists) {
        if (widget.erisilemezseGizle) {
          setState(() => _erisilemez = true);
          unawaited(
            SosyalServis.erisilemeyenBegeniKaydiniSil(
              uid: widget.userId,
              postId: widget.postId,
            ),
          );
        }
        return;
      }
      final data = snap.data() ?? {};
      setState(() {
        if (ozetEksik) {
          _gonderi = data;
          if (widget.erisilemezseGizle &&
              data['raporNedeniyleGizli'] == true) {
            _erisilemez = true;
          }
        }
        if (widget.baslangicBegeniSayisi == 0) {
          _begeni.guncelle(
            yeniBaslangicBegeni: _intDeger(data['begeniSayisi'], 0),
          );
        }
        if (widget.baslangicYorumSayisi == 0) {
          yorumSayisi = _intDeger(data['yorumSayisi'], 0);
        }
      });
    } on FirebaseException catch (e) {
      if (widget.erisilemezseGizle && e.code == 'permission-denied') {
        if (mounted) setState(() => _erisilemez = true);
        unawaited(
          SosyalServis.erisilemeyenBegeniKaydiniSil(
            uid: widget.userId,
            postId: widget.postId,
          ),
        );
        return;
      }
      debugPrint('begendiklerim sayac senkron ($widget.postId): $e');
    } catch (e) {
      debugPrint('begendiklerim sayac senkron ($widget.postId): $e');
    }
  }

  int _intDeger(dynamic value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return fallback;
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

    if (oldWidget.baslangicBegenildi != widget.baslangicBegenildi) {
      _begeni.begeniDurumunuUygula(widget.baslangicBegenildi);
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
        return YorumPaneli(
          postId: widget.postId,
          postOwnerId: widget.postOwnerId,
          userId: widget.userId,
          onYorumEklendi: () {
            setState(() {
              yorumSayisi += 1;
            });
          },
          onYorumSilindi: () {
            setState(() {
              if (yorumSayisi > 0) yorumSayisi -= 1;
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
      userId: widget.postOwnerId,
      photoUrl: _photoUrl,
      avatarKey: _avatarKey,
      fallbackText: _kullaniciAdi,
      emojiSize: 18,
      fallbackIconSize: 20,
    );
  }

  // Arayüzü oluştur
  @override
  Widget build(BuildContext context) {
    if (_erisilemez) return const SizedBox.shrink();

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
            title: Row(
              children: [
                Flexible(
                  child: Text(
                    _kullaniciAdi,
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
            trailing: widget.silmeButonuGoster
                ? Semantics(
                    container: true,
                    button: true,
                    label: MaestroSemantics.gonderiyiSil,
                    child: IconButton(
                      tooltip: MaestroSemantics.gonderiyiSil,
                      onPressed: widget.onSil,
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.redAccent,
                      ),
                    ),
                  )
                : null,
            subtitle: Text(
              tarihSaatYaz(_createdAt),
              style: TextStyle(color: context.vibe.faintText, fontSize: 12),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_metin.isNotEmpty)
                  HashtagMetin(
                    metin: _metin,
                    mentionUidleri: _mentionUidleri,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                    onHashtagTap: (tag) => etiketSayfasinaGit(context, tag),
                  ),
                if (_alintiSnapshot != null) ...[
                  if (_metin.isNotEmpty) const SizedBox(height: 10),
                  AlintiGonderiOnizleme(
                    snapshot: _alintiSnapshot!,
                    currentUserId: widget.userId,
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
                        color: context.vibe.mutedText,
                        fontSize: 14,
                      ),
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

// Hesap silme onay diyaloğu
class _HesapSilDialog extends StatefulWidget {
  const _HesapSilDialog();

  @override
  State<_HesapSilDialog> createState() => _HesapSilDialogState();
}

// Hesap silme diyaloğu durumu
class _HesapSilDialogState extends State<_HesapSilDialog> {
  final _sifreController = TextEditingController();
  final _digerController = TextEditingController();
  final _sorunController = TextEditingController();
  bool _gizli = true;
  bool _siliniyor = false;
  String? _hataMesaji;
  bool _sosyalOnaylandi = false;
  int _adim = 0;
  String? _neden;

  bool get _sifreGerekli {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    return auth_eposta.epostaSifreKullanicisiMi(user);
  }

  /// Şifre bağlı hesaplarda yeniden doğrulama şifreyle yapılır; sosyal onay
  /// yalnızca şifresi olmayan Google/Apple hesaplarında istenir.
  bool get _sosyalHesabi {
    final user = FirebaseAuth.instance.currentUser;
    return user != null &&
        SosyalOAuth.oauthMu(user) &&
        !auth_eposta.epostaSifreKullanicisiMi(user);
  }

  bool get _appleHesabi {
    final user = FirebaseAuth.instance.currentUser;
    return user != null && SosyalOAuth.appleMu(user);
  }

  String get _sosyalSaglayiciAdi => _appleHesabi ? 'Apple' : 'Google';

  @override
  void dispose() {
    _sifreController.dispose();
    _digerController.dispose();
    _sorunController.dispose();
    super.dispose();
  }

  Future<void> _nedenDevam() async {
    if (_neden == null) {
      setState(() => _hataMesaji = 'Bir neden seç.');
      return;
    }
    if (_neden == 'Diğer...' && _digerController.text.trim().isEmpty) {
      setState(() => _hataMesaji = 'Diğer nedeni yaz.');
      return;
    }
    setState(() {
      _hataMesaji = null;
      _adim = 1;
    });
  }

  Future<void> _sorunAdiminaDevam({required bool atla}) async {
    if (atla) _sorunController.clear();
    setState(() => _siliniyor = true);
    try {
      await HesapSilServis.silmeGeriBildirimiKaydet(
        neden: _neden ?? '',
        digerMetin: _neden == 'Diğer...' ? _digerController.text : '',
        sorunMetin: _sorunController.text,
      );
    } catch (e) {
      debugPrint('Silme geri bildirimi kaydedilemedi: $e');
    }
    if (!mounted) return;
    setState(() {
      _siliniyor = false;
      _hataMesaji = null;
      _adim = 2;
    });
  }

  Future<void> _hesabiSil() async {
    final sifre = _sifreController.text.trim();
    if (_sifreGerekli && sifre.isEmpty) {
      setState(() => _hataMesaji = "Şifre boş olamaz.");
      return;
    }

    setState(() {
      _siliniyor = true;
      _hataMesaji = null;
    });

    try {
      if (_sosyalHesabi && !_sosyalOnaylandi) {
        if (_appleHesabi) {
          await AppleGirisServis.yenidenDogrula();
        } else {
          await GoogleGirisServis.yenidenDogrula();
        }
        if (!mounted) return;
        setState(() {
          _siliniyor = false;
          _sosyalOnaylandi = true;
        });
        return;
      }
      await HesapSilServis.hesabiSil(
        sifre: _sifreController.text.trim(),
        googleOnayiYapildi: !_appleHesabi && _sosyalOnaylandi,
        appleOnayiYapildi: _appleHesabi && _sosyalOnaylandi,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      if (e is FirebaseAuthException &&
          (e.code == 'canceled' ||
              e.code == 'sign_in_canceled' ||
              e.code == 'popup-closed-by-user' ||
              e.code == 'cancelled-popup-request')) {
        setState(() => _siliniyor = false);
        return;
      }
      String mesaj = '';
      if (e is FirebaseAuthException) {
        if (_sifreGerekli &&
            (e.code == 'wrong-password' || e.code == 'invalid-credential')) {
          mesaj = 'Şifre hatalı.';
        } else {
          mesaj = _appleHesabi
              ? AppleGirisServis.hataMesaji(e)
              : GoogleGirisServis.hataMesaji(e);
        }
      }
      setState(() {
        _siliniyor = false;
        _hataMesaji = mesaj.isNotEmpty
            ? mesaj
            : internetAwareErrorMessage(
                error: e,
                fallback: "Hesap silinemedi.",
              );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final vibe = context.vibe;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final googleOnayi = _sosyalHesabi && !_sosyalOnaylandi;

    String baslik;
    if (_adim == 0) {
      baslik = 'Neden ayrılıyorsun?';
    } else if (_adim == 1) {
      baslik = 'Bir sorun var mı?';
    } else {
      baslik = 'Hesabı Sil';
    }

    return AlertDialog(
      backgroundColor: vibe.dialogBackground,
      title: Text(baslik, style: TextStyle(color: onSurface)),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_adim == 0) ...[
                  Text(
                    'Hesabını silmeden önce bir neden seç.',
                    style: TextStyle(color: vibe.mutedText, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  for (final neden in HesapSilServis.silmeNedenleri)
                    RadioListTile<String>(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: neden,
                      groupValue: _neden,
                      onChanged: _siliniyor
                          ? null
                          : (v) => setState(() {
                                _neden = v;
                                _hataMesaji = null;
                              }),
                      title: Text(
                        neden,
                        style: TextStyle(color: onSurface, fontSize: 14),
                      ),
                    ),
                  if (_neden == 'Diğer...') ...[
                    const SizedBox(height: 4),
                    TextField(
                      controller: _digerController,
                      maxLines: 3,
                      maxLength: 400,
                      enabled: !_siliniyor,
                      style: TextStyle(color: onSurface),
                      decoration: InputDecoration(
                        hintText: 'Nedenini yaz...',
                        hintStyle: TextStyle(color: vibe.faintText),
                        filled: true,
                        fillColor: vibe.inputFill,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ],
                ] else if (_adim == 1) ...[
                  Text(
                    'Uygulamada belirtmek istediğin bir sorun varsa yazabilirsin. İstersen atla.',
                    style: TextStyle(color: vibe.mutedText, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _sorunController,
                    maxLines: 5,
                    maxLength: 1000,
                    enabled: !_siliniyor,
                    style: TextStyle(color: onSurface),
                    decoration: InputDecoration(
                      hintText: 'Sorununu yaz (isteğe bağlı)',
                      hintStyle: TextStyle(color: vibe.faintText),
                      filled: true,
                      fillColor: vibe.inputFill,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ] else ...[
                  Text(
                    googleOnayi
                        ? 'Bu işlem geri alınamaz. Silmek için önce $_sosyalSaglayiciAdi hesabınla onayla.'
                        : _sosyalHesabi
                            ? '$_sosyalSaglayiciAdi onayın alındı. Silmeyi tamamlamak için Hesabı Sil\'e dokun.'
                            : 'Bu işlem geri alınamaz. Gönderilerin, yorumların, beğenilerin, mesajların, bildirimlerin ve profil bilgilerin kalıcı olarak silinir.',
                    style: TextStyle(color: vibe.mutedText, fontSize: 13),
                  ),
                  if (_sifreGerekli) ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: _sifreController,
                      obscureText: _gizli,
                      enabled: !_siliniyor,
                      style: TextStyle(color: onSurface),
                      decoration: InputDecoration(
                        hintText: 'Şifreni gir',
                        hintStyle: TextStyle(color: vibe.faintText),
                        filled: true,
                        fillColor: vibe.inputFill,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _gizli ? Icons.visibility_off : Icons.visibility,
                            color: vibe.mutedText,
                          ),
                          onPressed: _siliniyor
                              ? null
                              : () => setState(() => _gizli = !_gizli),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ],
                ],
                if (_hataMesaji != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _hataMesaji!,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _siliniyor ? null : () => Navigator.pop(context),
          child: const Text('Vazgeç'),
        ),
        if (_adim == 1)
          TextButton(
            onPressed: _siliniyor
                ? null
                : () => _sorunAdiminaDevam(atla: true),
            child: const Text('Atla'),
          ),
        TextButton(
          onPressed: _siliniyor
              ? null
              : () {
                  if (_adim == 0) {
                    _nedenDevam();
                  } else if (_adim == 1) {
                    _sorunAdiminaDevam(atla: false);
                  } else {
                    _hesabiSil();
                  }
                },
          child: _siliniyor
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  _adim < 2
                      ? 'Devam'
                      : (googleOnayi
                          ? '$_sosyalSaglayiciAdi ile onayla'
                          : 'Hesabı Sil'),
                  style: TextStyle(
                    color: _adim == 2 ? Colors.redAccent : null,
                  ),
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
        _hataMesaji =
            e is FirebaseAuthException && e.code != 'network-request-failed'
            ? sifreDegistirHataMesaji(e)
            : internetAwareErrorMessage(
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
    final masaustu = webMasaustuMu(context);

    return AlertDialog(
      backgroundColor: vibe.dialogBackground,
      title: Text("Vibel İsmi", style: TextStyle(color: onSurface)),
      content: TextField(
        controller: controller,
        autofocus: masaustu,
        onSubmitted: masaustu
            ? (deger) => Navigator.pop(context, deger.trim())
            : null,
        maxLength: 20,
        style: TextStyle(color: onSurface),
        decoration: InputDecoration(
          hintText: "Vibel'ine isim ver",
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
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Birini seç, sonra Kaydet'e bas.",
                style: TextStyle(
                  color: vibe.mutedText,
                  fontSize: 12,
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
                      liderTaciGoster: false,
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
